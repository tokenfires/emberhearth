// FactExtractor.swift
// EmberHearth
//
// Uses the LLM to extract new facts from conversation exchanges.
// After each user message + assistant response, this analyzes the
// exchange and identifies facts worth remembering about the user.

import Foundation
import os

/// Extracts user facts from conversation exchanges using the LLM.
///
/// Usage:
/// ```swift
/// let extractor = FactExtractor(llmProvider: claudeClient, factStore: store)
/// let newFacts = try await extractor.extractFacts(
///     from: "My sister Sarah is visiting next week, she's vegan",
///     assistantResponse: "That sounds lovely! I'll remember that Sarah is vegan...",
///     existingFacts: currentFacts
/// )
/// ```
final class FactExtractor {

    // MARK: - Properties

    /// The LLM provider used for extraction calls.
    private let llmProvider: LLMProviderProtocol

    /// The fact store for checking duplicates and inserting new facts.
    private let factStore: FactStore

    /// Logger for extraction events. NEVER logs message content or API keys.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "FactExtractor"
    )

    // MARK: - Constants

    /// Maximum number of existing facts to include in the extraction prompt.
    /// Limits context size while still providing enough for duplicate detection.
    static let maxExistingFactsInPrompt = 30

    // MARK: - Extraction Prompt

    /// The system prompt used for fact extraction.
    /// This is a specialized prompt that instructs the LLM to output JSON only.
    static let extractionSystemPrompt = """
        You are a fact extraction system for a personal AI assistant. Your ONLY job is to identify \
        new facts about the user from the conversation below.

        Return ONLY a valid JSON array of fact objects. If no new facts are found, return an empty array: []

        Each fact object must have exactly these fields:
        - "content": A concise, third-person statement of the fact (e.g., "User prefers morning meetings")
        - "category": One of: "preference", "relationship", "biographical", "event", "opinion", "contextual", "secret"
        - "importance": A number from 0.0 to 1.0 indicating how important this fact seems for future interactions
        - "confidence": A number from 0.0 to 1.0 indicating how confident you are this is a real fact

        CATEGORY DEFINITIONS:
        - "preference": Things the user likes, dislikes, or how they want things done
        - "relationship": People the user mentions (family, friends, colleagues, pets) and their connection
        - "biographical": Facts about the user's life (job, location, hobbies, birthday, etc.)
        - "event": Things that happened, are happening, or will happen
        - "opinion": The user's views, values, or perspectives on topics
        - "contextual": Situational facts (current projects, concerns, goals, what they're working on)
        - "secret": Information the user explicitly asks to keep private or that is clearly sensitive

        RULES:
        - Extract facts about the USER only, not about the assistant
        - Use third person ("User prefers..." not "You prefer..." or "I prefer...")
        - Be concise — each fact should be one clear sentence
        - Do NOT extract trivial facts (e.g., "User said hello", "User asked a question")
        - Do NOT extract facts you're not reasonably confident about
        - Do NOT repeat facts that are already in the "Previously known facts" list
        - If a fact UPDATES an existing known fact, include it with the updated information
        - For relationships, include the person's name and relationship (e.g., "User has a sister named Sarah")
        - For preferences, be specific (e.g., "User prefers oat milk lattes" not just "User likes coffee")
        - Set importance higher (0.7+) for biographical, relationship, and secret facts
        - Set importance lower (0.3-0.5) for contextual and transient facts

        RESPOND WITH ONLY THE JSON ARRAY. No explanation, no markdown, no code fences.
        """

    // MARK: - Initialization

    /// Creates a FactExtractor.
    ///
    /// - Parameters:
    ///   - llmProvider: The LLM provider to use for extraction calls.
    ///   - factStore: The fact store for duplicate checking and insertion.
    init(llmProvider: LLMProviderProtocol, factStore: FactStore) {
        self.llmProvider = llmProvider
        self.factStore = factStore
    }

    // MARK: - Extraction

    /// Extracts new facts from a conversation exchange and stores them.
    ///
    /// This method:
    /// 1. Builds an extraction prompt with the conversation and existing facts
    /// 2. Calls the LLM to identify new facts
    /// 3. Parses the JSON response
    /// 4. Checks for duplicates against existing facts
    /// 5. Inserts or updates facts in the store
    ///
    /// - Parameters:
    ///   - userMessage: The user's message in this conversation turn.
    ///   - assistantResponse: The assistant's response to the user's message.
    ///   - existingFacts: Previously known facts (for duplicate avoidance). Pass an empty array if none.
    /// - Returns: An array of newly extracted Fact objects (with database IDs assigned).
    /// - Throws: Errors from the LLM call. JSON parsing failures are handled gracefully (logged and skipped).
    func extractFacts(
        from userMessage: String,
        assistantResponse: String,
        existingFacts: [Fact]
    ) async throws -> [Fact] {
        let extractionUserMessage = buildExtractionMessage(
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            existingFacts: existingFacts
        )

        let response = try await llmProvider.sendMessage(
            [.user(extractionUserMessage)],
            systemPrompt: FactExtractor.extractionSystemPrompt
        )

        let rawFacts = parseExtractionResponse(response.content)

        guard !rawFacts.isEmpty else {
            Self.logger.info("No facts extracted from conversation turn")
            return []
        }

        Self.logger.info("Extracted \(rawFacts.count) candidate facts from conversation turn")

        var insertedFacts: [Fact] = []
        for rawFact in rawFacts {
            guard let category = FactCategory(rawValue: rawFact.category) else {
                Self.logger.warning("Skipping fact with invalid category: \(rawFact.category)")
                continue
            }

            let confidence = max(0.0, min(1.0, rawFact.confidence))
            let importance = max(0.0, min(1.0, rawFact.importance))

            guard confidence >= 0.3 else {
                Self.logger.info("Skipping low-confidence fact (confidence: \(confidence))")
                continue
            }

            let fact = Fact.create(
                content: rawFact.content,
                category: category,
                source: .extracted,
                confidence: confidence,
                importance: importance
            )

            let id = try factStore.insertOrUpdate(fact)

            if let storedFact = try factStore.getById(id) {
                insertedFacts.append(storedFact)
            }
        }

        Self.logger.info("Stored \(insertedFacts.count) facts from extraction")
        return insertedFacts
    }

    // MARK: - Prompt Building

    /// Builds the user message for the extraction LLM call.
    ///
    /// - Parameters:
    ///   - userMessage: The user's message.
    ///   - assistantResponse: The assistant's response.
    ///   - existingFacts: Known facts to avoid duplicates.
    /// - Returns: The formatted extraction prompt.
    private func buildExtractionMessage(
        userMessage: String,
        assistantResponse: String,
        existingFacts: [Fact]
    ) -> String {
        var prompt = """
            Conversation:
            User: \(userMessage)
            Assistant: \(assistantResponse)
            """

        if !existingFacts.isEmpty {
            let factsToInclude = Array(existingFacts.prefix(FactExtractor.maxExistingFactsInPrompt))
            let factsList = factsToInclude
                .map { "- [\($0.category.rawValue)] \($0.content)" }
                .joined(separator: "\n")

            prompt += """

                Previously known facts (avoid duplicates):
                \(factsList)
                """
        } else {
            prompt += """

                Previously known facts: None
                """
        }

        prompt += """

            Extract new facts as JSON:
            """

        return prompt
    }

    // MARK: - Response Parsing

    /// A raw fact extracted from the LLM's JSON response.
    /// This is an intermediate representation before converting to a Fact model.
    private struct RawExtractedFact: Decodable {
        let content: String
        let category: String
        let importance: Double
        let confidence: Double
    }

    /// Parses the LLM's extraction response into raw fact data.
    /// Handles common JSON parsing issues gracefully.
    ///
    /// - Parameter responseContent: The raw string content from the LLM response.
    /// - Returns: An array of parsed raw facts. Returns empty array on parse failure.
    private func parseExtractionResponse(_ responseContent: String) -> [RawExtractedFact] {
        let cleaned = cleanJSONResponse(responseContent)

        guard let data = cleaned.data(using: .utf8) else {
            Self.logger.warning("Failed to convert extraction response to UTF-8 data")
            return []
        }

        do {
            let facts = try JSONDecoder().decode([RawExtractedFact].self, from: data)
            return facts
        } catch {
            Self.logger.warning("Failed to parse extraction JSON: \(error.localizedDescription)")

            // Try to parse as a single fact (LLM sometimes returns object instead of array)
            do {
                let singleFact = try JSONDecoder().decode(RawExtractedFact.self, from: data)
                return [singleFact]
            } catch {
                Self.logger.warning("Also failed to parse as single fact: \(error.localizedDescription)")
                return []
            }
        }
    }

    /// Cleans up JSON response from the LLM.
    /// Removes common issues like markdown code fences, leading/trailing whitespace,
    /// and other non-JSON artifacts.
    ///
    /// - Parameter response: The raw LLM response string.
    /// - Returns: Cleaned JSON string ready for parsing.
    private func cleanJSONResponse(_ response: String) -> String {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code fences if present
        // Handles: ```json\n...\n``` and ```\n...\n```
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }
}
