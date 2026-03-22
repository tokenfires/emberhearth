// FactRetriever.swift
// EmberHearth
//
// Retrieves relevant user facts for inclusion in LLM context.
// Uses keyword-based search for MVP. Semantic search planned for v1.2.

import Foundation

/// Retrieves relevant facts from the memory database to include in LLM context.
///
/// Usage:
/// ```swift
/// let retriever = FactRetriever(factStore: store)
/// let relevantFacts = try retriever.retrieveRelevantFacts(for: "What should I get my sister for her birthday?")
/// ```
final class FactRetriever {

    // MARK: - Properties

    /// The fact store used for database operations.
    private let factStore: FactStore

    // MARK: - Configuration

    /// Default maximum number of facts to return.
    static let defaultLimit = 10

    /// Weight for keyword match count in relevance scoring (0.0-1.0).
    /// Higher values prioritize facts that match more keywords.
    static let keywordMatchWeight: Double = 0.40

    /// Weight for recency in relevance scoring (0.0-1.0).
    /// Higher values prioritize recently created facts.
    static let recencyWeight: Double = 0.15

    /// Weight for access frequency in relevance scoring (0.0-1.0).
    /// Higher values prioritize frequently accessed facts.
    static let accessFrequencyWeight: Double = 0.10

    /// Weight for importance in relevance scoring (0.0-1.0).
    /// Higher values prioritize facts marked as important.
    static let importanceWeight: Double = 0.20

    /// Weight for confidence in relevance scoring (0.0-1.0).
    /// Higher values prioritize high-confidence facts.
    static let confidenceWeight: Double = 0.15

    // MARK: - Stop Words

    /// Common English words to exclude from keyword extraction.
    /// These words appear so frequently they don't help identify relevant facts.
    static let stopWords: Set<String> = [
        // Articles
        "a", "an", "the",
        // Pronouns
        "i", "me", "my", "mine", "myself",
        "you", "your", "yours", "yourself",
        "he", "him", "his", "himself",
        "she", "her", "hers", "herself",
        "it", "its", "itself",
        "we", "us", "our", "ours", "ourselves",
        "they", "them", "their", "theirs", "themselves",
        // Prepositions
        "in", "on", "at", "to", "for", "with", "from", "by", "about",
        "into", "through", "during", "before", "after", "above", "below",
        "between", "under", "over", "of", "up", "down", "out", "off",
        // Conjunctions
        "and", "but", "or", "nor", "so", "yet", "both", "either", "neither",
        // Verbs (common/auxiliary)
        "is", "am", "are", "was", "were", "be", "been", "being",
        "have", "has", "had", "having",
        "do", "does", "did", "doing",
        "will", "would", "shall", "should",
        "may", "might", "must", "can", "could",
        // Other common words
        "not", "no", "yes", "if", "then", "else", "when", "where",
        "how", "what", "which", "who", "whom", "whose", "why",
        "one", "two", "three",
        "this", "that", "these", "those",
        "here", "there", "all", "each", "every", "some", "any",
        "few", "more", "most", "other", "such",
        "just", "also", "very", "too", "quite", "rather",
        "than", "as", "like", "even", "still", "already",
        "now", "then", "again", "once",
        // Question starters and filler
        "please", "thanks", "thank", "hey", "hi", "hello",
        "okay", "ok", "sure", "well", "oh", "um", "uh",
        // EmberHearth-specific (users might address the assistant)
        "ember", "emberhearth",
    ]

    // MARK: - Initialization

    /// Creates a FactRetriever backed by the given FactStore.
    ///
    /// - Parameter factStore: The FactStore to search for facts.
    init(factStore: FactStore) {
        self.factStore = factStore
    }

    // MARK: - Retrieval

    /// Retrieves the most relevant facts for a given user message.
    ///
    /// This is the primary method used when building LLM context. It:
    /// 1. Extracts keywords from the user's message
    /// 2. Searches for facts matching those keywords
    /// 3. Scores each fact by relevance (keyword matches, recency, importance, etc.)
    /// 4. Updates access tracking for returned facts
    /// 5. Returns the top N facts sorted by relevance
    ///
    /// - Parameters:
    ///   - message: The user's message to find relevant facts for.
    ///   - limit: Maximum number of facts to return (default: 10).
    /// - Returns: An array of relevant facts, sorted by relevance score (highest first).
    /// - Throws: `DatabaseError` if a database operation fails.
    func retrieveRelevantFacts(for message: String, limit: Int = FactRetriever.defaultLimit) throws -> [Fact] {
        let keywords = extractKeywords(from: message)

        guard !keywords.isEmpty else {
            return []
        }

        // Search for facts matching each keyword and collect unique results
        var factScores: [Int64: (fact: Fact, matchCount: Int)] = [:]

        for keyword in keywords {
            let matches = try factStore.search(query: keyword)
            for fact in matches {
                if var existing = factScores[fact.id] {
                    existing.matchCount += 1
                    factScores[fact.id] = existing
                } else {
                    factScores[fact.id] = (fact: fact, matchCount: 1)
                }
            }
        }

        guard !factScores.isEmpty else {
            return []
        }

        // Calculate the maximum possible keyword matches (for normalization)
        let maxKeywordMatches = keywords.count

        // Find the maximum access count across all matched facts (for normalization)
        let maxAccessCount = factScores.values.map { $0.fact.accessCount }.max() ?? 1
        let normalizedMaxAccess = max(maxAccessCount, 1) // Avoid division by zero

        // Score each fact
        var scoredFacts: [(fact: Fact, score: Double)] = factScores.values.map { entry in
            let fact = entry.fact
            let matchCount = entry.matchCount

            // Keyword match score: how many of the query keywords appear in this fact
            let keywordScore = Double(matchCount) / Double(max(maxKeywordMatches, 1))

            // Recency score: newer facts score higher
            // Uses a 90-day window: facts created in the last 90 days score 1.0 → 0.0
            let daysSinceCreation = Date().timeIntervalSince(fact.createdAt) / 86400.0
            let recencyScore = max(0.0, 1.0 - (daysSinceCreation / 90.0))

            // Access frequency score: frequently accessed facts are probably important
            let accessScore = Double(fact.accessCount) / Double(normalizedMaxAccess)

            // Importance score: directly from the fact (0.0-1.0)
            let importanceScore = fact.importance

            // Confidence score: directly from the fact (0.0-1.0)
            let confidenceScore = fact.confidence

            // Weighted combination
            let totalScore =
                (keywordScore * FactRetriever.keywordMatchWeight) +
                (recencyScore * FactRetriever.recencyWeight) +
                (accessScore * FactRetriever.accessFrequencyWeight) +
                (importanceScore * FactRetriever.importanceWeight) +
                (confidenceScore * FactRetriever.confidenceWeight)

            return (fact: fact, score: totalScore)
        }

        // Sort by score descending
        scoredFacts.sort { $0.score > $1.score }

        // Take the top N
        let topFacts = Array(scoredFacts.prefix(limit))

        // Update access tracking for all returned facts
        for entry in topFacts {
            try factStore.updateAccessTracking(id: entry.fact.id)
        }

        return topFacts.map { $0.fact }
    }

    /// Retrieves the most recently created facts, regardless of message relevance.
    /// Useful for general context priming at the start of a conversation.
    ///
    /// - Parameter limit: Maximum number of facts to return (default: 5).
    /// - Returns: An array of the most recent non-deleted facts.
    /// - Throws: `DatabaseError` if the query fails.
    func retrieveRecentFacts(limit: Int = 5) throws -> [Fact] {
        let allFacts = try factStore.getAll()
        // getAll() already returns facts sorted by created_at DESC
        let recentFacts = Array(allFacts.prefix(limit))

        // Update access tracking for returned facts
        for fact in recentFacts {
            try factStore.updateAccessTracking(id: fact.id)
        }

        return recentFacts
    }

    // MARK: - Keyword Extraction

    /// Extracts meaningful keywords from a user message.
    /// Removes stop words, punctuation, and very short words.
    ///
    /// - Parameter message: The user's message.
    /// - Returns: An array of unique, lowercase keywords.
    func extractKeywords(from message: String) -> [String] {
        // Convert to lowercase
        let lowercased = message.lowercased()

        // Remove punctuation and special characters, keeping only letters, numbers, and spaces
        let cleaned = lowercased.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " {
                return Character(scalar)
            }
            return " "
        }
        let cleanedString = String(cleaned)

        // Split into words
        let words = cleanedString.split(separator: " ").map { String($0) }

        // Filter out stop words and very short words (< 3 characters)
        let keywords = words.filter { word in
            word.count >= 3 && !FactRetriever.stopWords.contains(word)
        }

        // Remove duplicates while preserving order
        var seen = Set<String>()
        let uniqueKeywords = keywords.filter { word in
            if seen.contains(word) {
                return false
            }
            seen.insert(word)
            return true
        }

        return uniqueKeywords
    }
}
