# Task 0302: Keyword-Based Fact Retrieval for Context

**Milestone:** M4 - Memory System
**Unit:** 4.3 - Fact Retrieval for Context
**Phase:** 2
**Depends On:** 0301 (FactStore)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, core principles
2. `src/Memory/Fact.swift` — Read entirely; understand the Fact struct, FactCategory enum, FactSource enum, and all properties (especially confidence, importance, accessCount, createdAt)
3. `src/Memory/FactStore.swift` — Read entirely; understand search(), getAll(), getByCategory(), updateAccessTracking() methods
4. `src/Database/DatabaseManager.swift` — Read the query() and execute() method signatures; understand that query() returns [[String: Any?]]
5. `docs/research/memory-learning.md` — Focus on Section 2: "Confidence, Decay, and Emotional Salience" (lines ~185-270) for confidence thresholds, and Section 3 (lines ~378-382) for expected scale (~10-50 facts/day, 5K-20K facts/year)

> **Context Budget Note:** memory-learning.md is 800+ lines. Focus only on Section 2 (lines 185-303) for scoring inspiration and Section 3 (lines 378-382) for scale. DatabaseManager.swift is long — focus on the query() method signature and return type. Fact.swift and FactStore.swift should be read in full.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the FactRetriever for EmberHearth, a native macOS personal AI assistant. The FactRetriever finds relevant user facts to include in the LLM context when responding to a message. This is an MVP implementation using keyword-based search (semantic/embedding search comes in v1.2).

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., FactRetriever.swift)
- Security first: never expose secrets or credentials
- All source files go under src/, all test files go under tests/

WHAT EXISTS (from Tasks 0300-0301):
- src/Database/DatabaseManager.swift — SQLite database manager
- src/Database/DatabaseError.swift — Error types
- src/Memory/Fact.swift — Fact struct with properties: id (Int64), content (String), category (FactCategory), source (FactSource), confidence (Double), createdAt (Date), updatedAt (Date), lastAccessed (Date?), accessCount (Int), importance (Double), isDeleted (Bool)
- src/Memory/FactStore.swift — CRUD operations with methods: search(query:) -> [Fact], getAll() -> [Fact], getByCategory(_:) -> [Fact], updateAccessTracking(id:), getById(_:) -> Fact?
- src/Memory/MemoryModule.swift — Placeholder (leave alone)

YOU WILL CREATE:
1. src/Memory/FactRetriever.swift — Keyword-based fact retrieval with relevance scoring
2. tests/FactRetrieverTests.swift — Unit tests with pre-populated test data

STEP 1: Create src/Memory/FactRetriever.swift

The FactRetriever extracts keywords from a user message, searches the FactStore for matching facts, scores them by relevance, and returns the top N results.

File: src/Memory/FactRetriever.swift
```swift
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
```

STEP 2: Create tests/FactRetrieverTests.swift

These tests use a pre-populated in-memory database with realistic facts.

File: tests/FactRetrieverTests.swift
```swift
// FactRetrieverTests.swift
// EmberHearth
//
// Unit tests for FactRetriever.

import XCTest
@testable import EmberHearth

final class FactRetrieverTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a fresh in-memory database, FactStore, and FactRetriever.
    /// Optionally pre-populates with test facts.
    private func makeRetriever(populate: Bool = true) throws -> (DatabaseManager, FactStore, FactRetriever) {
        let db = try DatabaseManager(path: ":memory:")
        let store = FactStore(database: db)
        let retriever = FactRetriever(factStore: store)

        if populate {
            try populateTestFacts(store: store)
        }

        return (db, store, retriever)
    }

    /// Populates the database with a realistic set of test facts.
    private func populateTestFacts(store: FactStore) throws {
        // Preferences
        try store.insert(Fact.create(
            content: "User prefers morning meetings before 10am",
            category: .preference, confidence: 0.9, importance: 0.6
        ))
        try store.insert(Fact.create(
            content: "User likes oat milk lattes from the coffee shop",
            category: .preference, confidence: 0.85, importance: 0.4
        ))
        try store.insert(Fact.create(
            content: "User prefers dark mode in all applications",
            category: .preference, confidence: 0.95, importance: 0.3
        ))

        // Relationships
        try store.insert(Fact.create(
            content: "User has a sister named Sarah who is vegan",
            category: .relationship, confidence: 0.95, importance: 0.7
        ))
        try store.insert(Fact.create(
            content: "User's manager at work is named David Chen",
            category: .relationship, confidence: 0.9, importance: 0.6
        ))

        // Biographical
        try store.insert(Fact.create(
            content: "User works as a software engineer at Acme Corp",
            category: .biographical, confidence: 0.95, importance: 0.8
        ))
        try store.insert(Fact.create(
            content: "User lives in Portland Oregon",
            category: .biographical, confidence: 0.9, importance: 0.5
        ))

        // Events
        try store.insert(Fact.create(
            content: "User has a dentist appointment next Tuesday",
            category: .event, confidence: 0.85, importance: 0.6
        ))

        // Opinions
        try store.insert(Fact.create(
            content: "User thinks remote work is more productive than office work",
            category: .opinion, confidence: 0.8, importance: 0.4
        ))

        // Contextual
        try store.insert(Fact.create(
            content: "User is currently working on a machine learning project",
            category: .contextual, confidence: 0.9, importance: 0.7
        ))
    }

    // MARK: - Keyword Extraction Tests

    func testExtractKeywordsBasic() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "What should I get my sister for her birthday?")
        // "what", "should", "i", "get", "my", "sister", "for", "her", "birthday" →
        // After stop word removal and length filter: "sister", "birthday", "get"
        XCTAssertTrue(keywords.contains("sister"), "Should contain 'sister'")
        XCTAssertTrue(keywords.contains("birthday"), "Should contain 'birthday'")
        XCTAssertFalse(keywords.contains("what"), "'what' is a stop word")
        XCTAssertFalse(keywords.contains("my"), "'my' is a stop word")
        XCTAssertFalse(keywords.contains("her"), "'her' is a stop word")
        XCTAssertFalse(keywords.contains("for"), "'for' is a stop word")
    }

    func testExtractKeywordsRemovesPunctuation() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "Hey, what's the coffee shop's name?")
        XCTAssertTrue(keywords.contains("coffee"), "Should contain 'coffee'")
        XCTAssertTrue(keywords.contains("shop"), "Should contain 'shop' (with apostrophe removed)")
        XCTAssertTrue(keywords.contains("name"), "Should contain 'name'")
        XCTAssertFalse(keywords.contains("hey"), "'hey' is a stop word")
    }

    func testExtractKeywordsHandlesEmptyInput() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "")
        XCTAssertTrue(keywords.isEmpty)
    }

    func testExtractKeywordsHandlesOnlyStopWords() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "I am the one who is it")
        XCTAssertTrue(keywords.isEmpty, "All words are stop words or too short")
    }

    func testExtractKeywordsRemovesDuplicates() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "coffee coffee coffee morning morning")
        XCTAssertEqual(keywords.filter { $0 == "coffee" }.count, 1, "Should deduplicate")
        XCTAssertEqual(keywords.filter { $0 == "morning" }.count, 1, "Should deduplicate")
    }

    func testExtractKeywordsLowercases() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "COFFEE Morning PORTLAND")
        XCTAssertTrue(keywords.contains("coffee"))
        XCTAssertTrue(keywords.contains("morning"))
        XCTAssertTrue(keywords.contains("portland"))
    }

    func testExtractKeywordsFiltersShortWords() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "go to NW 5th coffee")
        XCTAssertFalse(keywords.contains("go"), "'go' is too short (< 3 chars)")
        XCTAssertFalse(keywords.contains("nw"), "'nw' is too short (< 3 chars)")
        XCTAssertTrue(keywords.contains("coffee"))
    }

    // MARK: - Retrieval Tests

    func testRetrieveRelevantFactsBasic() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "Tell me about my sister")
        XCTAssertFalse(facts.isEmpty, "Should find facts about sister")

        // The sister fact should be in the results
        let sisterFact = facts.first { $0.content.lowercased().contains("sister") }
        XCTAssertNotNil(sisterFact, "Should find the sister/Sarah fact")
    }

    func testRetrieveRelevantFactsCoffee() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "I want coffee")
        let coffeeFact = facts.first { $0.content.lowercased().contains("coffee") }
        XCTAssertNotNil(coffeeFact, "Should find the coffee preference fact")
    }

    func testRetrieveRelevantFactsWork() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "What do I do for work?")
        let workFact = facts.first { $0.content.lowercased().contains("software engineer") }
        XCTAssertNotNil(workFact, "Should find the work/software engineer fact")
    }

    func testRetrieveRelevantFactsRespectsLimit() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "Tell me everything about my work and meetings and coffee", limit: 3)
        XCTAssertLessThanOrEqual(facts.count, 3, "Should respect the limit")
    }

    func testRetrieveRelevantFactsNoMatchReturnsEmpty() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "quantum physics entanglement")
        XCTAssertTrue(facts.isEmpty, "Should return empty for completely unrelated query")
    }

    func testRetrieveRelevantFactsEmptyMessageReturnsEmpty() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "")
        XCTAssertTrue(facts.isEmpty, "Should return empty for empty message")
    }

    func testRetrieveRelevantFactsOnlyStopWordsReturnsEmpty() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "I am so very")
        XCTAssertTrue(facts.isEmpty, "Should return empty when message contains only stop words")
    }

    func testRetrieveRelevantFactsUpdatesAccessTracking() throws {
        let (_, store, retriever) = try makeRetriever()

        // Get all facts before retrieval
        let before = try store.getAll()
        let allAccessCountsBefore = before.map { $0.accessCount }
        XCTAssertTrue(allAccessCountsBefore.allSatisfy { $0 == 0 }, "All access counts should start at 0")

        // Retrieve facts about sister
        let facts = try retriever.retrieveRelevantFacts(for: "Tell me about my sister Sarah")
        XCTAssertFalse(facts.isEmpty)

        // Check that returned facts now have updated access tracking
        for fact in facts {
            let updated = try store.getById(fact.id)
            XCTAssertEqual(updated?.accessCount, 1, "Returned fact should have access_count = 1")
            XCTAssertNotNil(updated?.lastAccessed, "Returned fact should have last_accessed set")
        }
    }

    func testRetrieveRelevantFactsMultiKeywordScoresHigher() throws {
        let (_, _, retriever) = try makeRetriever()

        // "morning meetings" should rank the morning meetings fact highest
        // because it matches two keywords
        let facts = try retriever.retrieveRelevantFacts(for: "I need to schedule a morning meeting")
        guard let firstFact = facts.first else {
            XCTFail("Should return at least one fact")
            return
        }
        XCTAssertTrue(
            firstFact.content.lowercased().contains("morning") &&
            firstFact.content.lowercased().contains("meeting"),
            "Fact matching multiple keywords should rank first. Got: \(firstFact.content)"
        )
    }

    // MARK: - Retrieve Recent Facts Tests

    func testRetrieveRecentFacts() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRecentFacts(limit: 3)
        XCTAssertEqual(facts.count, 3, "Should return exactly 3 recent facts")
    }

    func testRetrieveRecentFactsRespectsLimit() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRecentFacts(limit: 2)
        XCTAssertEqual(facts.count, 2)
    }

    func testRetrieveRecentFactsUpdatesAccessTracking() throws {
        let (_, store, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRecentFacts(limit: 2)
        for fact in facts {
            let updated = try store.getById(fact.id)
            XCTAssertEqual(updated?.accessCount, 1, "Recent facts should have access tracking updated")
        }
    }

    func testRetrieveRecentFactsEmptyDatabase() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let facts = try retriever.retrieveRecentFacts()
        XCTAssertTrue(facts.isEmpty, "Should return empty for empty database")
    }

    // MARK: - Scoring Tests

    func testHighImportanceFactsRankHigher() throws {
        let (db, store, retriever) = try (
            try DatabaseManager(path: ":memory:"),
            FactStore(database: try DatabaseManager(path: ":memory:")),
            FactRetriever(factStore: FactStore(database: try DatabaseManager(path: ":memory:")))
        )
        // Create fresh instances to control test data precisely
        let freshDb = try DatabaseManager(path: ":memory:")
        let freshStore = FactStore(database: freshDb)
        let freshRetriever = FactRetriever(factStore: freshStore)

        // Insert two facts with the same keyword but different importance
        try freshStore.insert(Fact.create(
            content: "User drinks coffee occasionally",
            category: .preference, confidence: 0.8, importance: 0.2
        ))
        try freshStore.insert(Fact.create(
            content: "User absolutely loves coffee and drinks it every morning",
            category: .preference, confidence: 0.8, importance: 0.9
        ))

        let facts = try freshRetriever.retrieveRelevantFacts(for: "coffee")
        XCTAssertEqual(facts.count, 2)
        // Higher importance fact should rank first
        XCTAssertTrue(
            facts[0].importance > facts[1].importance,
            "Higher importance fact should rank first"
        )
    }

    func testHighConfidenceFactsRankHigher() throws {
        let freshDb = try DatabaseManager(path: ":memory:")
        let freshStore = FactStore(database: freshDb)
        let freshRetriever = FactRetriever(factStore: freshStore)

        try freshStore.insert(Fact.create(
            content: "User might like hiking",
            category: .preference, confidence: 0.3, importance: 0.5
        ))
        try freshStore.insert(Fact.create(
            content: "User definitely enjoys hiking every weekend",
            category: .preference, confidence: 0.95, importance: 0.5
        ))

        let facts = try freshRetriever.retrieveRelevantFacts(for: "hiking")
        XCTAssertEqual(facts.count, 2)
        XCTAssertTrue(
            facts[0].confidence > facts[1].confidence,
            "Higher confidence fact should rank first"
        )
    }

    // MARK: - Performance Test

    func testRetrievalPerformanceWith1000Facts() throws {
        let db = try DatabaseManager(path: ":memory:")
        let store = FactStore(database: db)
        let retriever = FactRetriever(factStore: store)

        // Insert 1000 facts
        let categories = FactCategory.allCases
        for i in 0..<1000 {
            let category = categories[i % categories.count]
            try store.insert(Fact.create(
                content: "Fact number \(i) about topic \(i % 50) related to category \(category.rawValue)",
                category: category,
                confidence: Double.random(in: 0.3...1.0),
                importance: Double.random(in: 0.1...1.0)
            ))
        }

        // Measure retrieval time
        let start = CFAbsoluteTimeGetCurrent()
        let facts = try retriever.retrieveRelevantFacts(for: "topic related category preference")
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertFalse(facts.isEmpty, "Should find matching facts")
        XCTAssertLessThan(elapsed, 0.1, "Retrieval should complete in under 100ms for 1000 facts. Took \(elapsed * 1000)ms")
    }
}
```

STEP 2: Verify the build

After creating both files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. Common issues:
- The test `testHighImportanceFactsRankHigher` creates its own isolated database — do NOT reference the helper variables `db`, `store`, `retriever` from the destructured tuple at the top. The lines with `let (db, store, retriever)` at the top of that function are intentionally overwritten by the fresh instances below. If the compiler complains about unused variables, remove the top destructuring line entirely and just use the `freshDb`/`freshStore`/`freshRetriever` variables.
- The `extractKeywords` method is public (no access modifier, which defaults to `internal`) so tests can call it directly.
- If the performance test fails on a slow machine, increase the threshold from 0.1 to 0.5 seconds.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify DatabaseManager.swift, DatabaseError.swift, Fact.swift, or FactStore.swift.
- Do NOT modify any module placeholder files.
- The FactRetriever does NOT own the FactStore — it receives one via dependency injection.
- The keyword extraction is intentionally simple for MVP. It does NOT do stemming, lemmatization, or n-grams. Semantic search (using embeddings) is planned for v1.2.
- The scoring weights are tunable constants at the class level. They should sum to approximately 1.0.
- The recency score uses a 90-day window. Facts older than 90 days get a recency score of 0.0, but can still rank high via other factors.
- Stop words list includes "ember" and "emberhearth" since users may address the assistant by name.
```

---

## Acceptance Criteria

- [ ] `src/Memory/FactRetriever.swift` exists and compiles
- [ ] `retrieveRelevantFacts(for:limit:)` extracts keywords, searches, scores, and returns top N facts
- [ ] `retrieveRecentFacts(limit:)` returns the most recently created facts
- [ ] `extractKeywords(from:)` removes stop words, punctuation, and short words (<3 chars)
- [ ] Scoring combines: keyword matches (40%), recency (15%), access frequency (10%), importance (20%), confidence (15%)
- [ ] Stop words list includes articles, pronouns, prepositions, conjunctions, auxiliary verbs, and common filler
- [ ] Empty messages and messages with only stop words return empty arrays
- [ ] Access tracking is updated for all returned facts
- [ ] Results are sorted by relevance score descending
- [ ] Facts matching multiple keywords score higher than single-keyword matches
- [ ] Retrieval completes in <100ms for 1,000 facts
- [ ] All unit tests pass
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Memory/FactRetriever.swift && echo "FactRetriever.swift exists" || echo "MISSING: FactRetriever.swift"
test -f tests/FactRetrieverTests.swift && echo "FactRetrieverTests.swift exists" || echo "MISSING: FactRetrieverTests.swift"

# Verify scoring weights exist
grep "keywordMatchWeight" src/Memory/FactRetriever.swift
grep "recencyWeight" src/Memory/FactRetriever.swift
grep "accessFrequencyWeight" src/Memory/FactRetriever.swift
grep "importanceWeight" src/Memory/FactRetriever.swift
grep "confidenceWeight" src/Memory/FactRetriever.swift

# Verify stop words exist
grep "stopWords" src/Memory/FactRetriever.swift

# Verify access tracking
grep "updateAccessTracking" src/Memory/FactRetriever.swift

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the FactRetriever created in task 0302 for EmberHearth. Check for these common issues:

1. KEYWORD EXTRACTION:
   - Verify extractKeywords() lowercases the input
   - Verify it removes punctuation and special characters
   - Verify it removes stop words (check the stop words list is comprehensive)
   - Verify it filters words shorter than 3 characters
   - Verify it removes duplicates
   - Verify it handles empty input gracefully (returns empty array)
   - Verify it handles input with only stop words (returns empty array)

2. RETRIEVAL LOGIC:
   - Verify retrieveRelevantFacts() calls extractKeywords() first
   - Verify it searches for EACH keyword individually via factStore.search()
   - Verify it accumulates match counts per fact (facts matching multiple keywords score higher)
   - Verify it calculates a weighted relevance score
   - Verify scoring weights are: keyword=0.40, recency=0.15, access=0.10, importance=0.20, confidence=0.15
   - Verify weights approximately sum to 1.0
   - Verify results are sorted by score descending
   - Verify it respects the limit parameter
   - Verify it calls updateAccessTracking() for ALL returned facts
   - Verify it returns empty array for empty messages

3. RECENCY SCORING:
   - Verify the recency calculation uses a time window (not just raw time)
   - Verify facts older than the window still get a recency score of 0.0 (not negative)
   - Verify max() or similar clamping is used

4. NORMALIZATION:
   - Verify keyword match count is normalized (divided by max possible matches)
   - Verify access count is normalized (divided by max access count across results)
   - Verify division by zero is handled (when all access counts are 0, etc.)

5. RETRIEVE RECENT FACTS:
   - Verify retrieveRecentFacts() returns facts sorted by creation date (newest first)
   - Verify it respects the limit parameter
   - Verify it updates access tracking

6. DEPENDENCY INJECTION:
   - Verify FactRetriever takes FactStore via constructor (not creating its own)
   - Verify it does NOT directly access DatabaseManager

7. TEST QUALITY:
   - Verify tests cover: basic retrieval, keyword extraction, empty input, stop words, multi-keyword ranking, access tracking, limit, performance
   - Verify tests use in-memory databases
   - Verify the performance test checks <100ms for 1000 facts

8. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test` and verify all FactRetrieverTests pass

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m4): add keyword-based fact retrieval for context
```

---

## Notes for Next Task

- The FactRetriever is now available at `src/Memory/FactRetriever.swift`. Task 0303 (FactExtractor) operates independently — it extracts facts from conversations, while FactRetriever finds relevant facts for context. They both use FactStore.
- The `extractKeywords()` method is internal (accessible within the module). Task 0303 does NOT need it — the LLM handles fact extraction directly.
- Task 0303 will need FactStore's `search()` method to check for duplicate facts before inserting new ones extracted by the LLM.
- Task 0303 depends on the ClaudeAPIClient from M3 (task 0201) for making the extraction LLM call. It should use the same API client but with different parameters (non-streaming, shorter max_tokens).
- The scoring weights in FactRetriever are class-level constants. If they need to become user-configurable, that change would happen in a later milestone.
