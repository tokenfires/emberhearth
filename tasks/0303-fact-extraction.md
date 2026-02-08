# Task 0303: LLM-Based Fact Extraction from Conversations

**Milestone:** M4 - Memory System
**Unit:** 4.4 - Fact Extraction Prompt Design
**Phase:** 2
**Depends On:** 0301 (FactStore), 0201 (ClaudeAPIClient)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, core principles
2. `src/Memory/Fact.swift` — Read entirely; understand Fact struct, FactCategory enum (7 cases), FactSource enum (2 cases), and Fact.create() factory method
3. `src/Memory/FactStore.swift` — Read entirely; understand insert(), search(), findSimilar(), insertOrUpdate() methods
4. `src/LLM/LLMProviderProtocol.swift` — Read entirely; understand the `sendMessage(_:systemPrompt:)` method signature and return type
5. `src/LLM/LLMTypes.swift` — Read entirely; understand LLMMessage, LLMResponse, LLMMessageRole types
6. `src/LLM/ClaudeAPIClient.swift` — Skim lines 260-340; understand the constructor takes KeychainManager, model, and maxTokens parameters
7. `docs/research/memory-learning.md` — Focus on Section 1 (lines 17-180) for extraction approach, fact taxonomy, and the extraction prompt design pattern

> **Context Budget Note:** memory-learning.md is 800+ lines. Focus ONLY on Section 1 (lines 17-180). Skip everything after the extraction architecture diagram. ClaudeAPIClient.swift is long — you only need to know it conforms to `LLMProviderProtocol` and the `sendMessage` signature. Read Fact.swift and FactStore.swift in full.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the FactExtractor for EmberHearth, a native macOS personal AI assistant. The FactExtractor uses the LLM to analyze conversation exchanges and extract new facts about the user. This is the "learning" part of the memory system — after each conversation turn, the FactExtractor identifies facts worth remembering.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., FactExtractor.swift)
- Security first: NEVER log API keys, request bodies, or response bodies
- NEVER implement shell execution
- All source files go under src/, all test files go under tests/

WHAT EXISTS (from prior tasks):
- src/Memory/Fact.swift — Fact struct with:
  - static func create(content:category:source:confidence:importance:) -> Fact
  - FactCategory enum: .preference, .relationship, .biographical, .event, .opinion, .contextual, .secret
  - FactSource enum: .extracted, .explicit
- src/Memory/FactStore.swift — CRUD operations with:
  - func insert(_ fact: Fact) throws -> Int64
  - func search(query: String) throws -> [Fact]
  - func findSimilar(to content: String) throws -> Fact?
  - func insertOrUpdate(_ fact: Fact) throws -> Int64
  - func update(_ fact: Fact) throws
- src/LLM/LLMProviderProtocol.swift — Protocol with:
  - func sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse
- src/LLM/LLMTypes.swift — Types:
  - LLMMessage: has .role (LLMMessageRole) and .content (String)
  - LLMMessage.user(_ content:) and LLMMessage.assistant(_ content:) factory methods
  - LLMResponse: has .content (String), .usage (LLMTokenUsage), .model (String), .stopReason (LLMStopReason)
- src/LLM/ClaudeAPIClient.swift — Concrete implementation:
  - init(keychainManager:urlSession:model:maxTokens:)
  - Conforms to LLMProviderProtocol
  - Static constant: ClaudeAPIClient.defaultModel = "claude-sonnet-4-20250514"

YOU WILL CREATE:
1. src/Memory/FactExtractor.swift — LLM-based fact extraction
2. tests/FactExtractorTests.swift — Unit tests with mocked LLM responses

STEP 1: Create src/Memory/FactExtractor.swift

File: src/Memory/FactExtractor.swift
```swift
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

    /// Maximum tokens for the extraction LLM response.
    /// Extraction responses are JSON arrays, which are compact.
    /// 512 tokens is sufficient for extracting ~10 facts.
    static let extractionMaxTokens = 512

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
        // Build the user message for the extraction call
        let extractionUserMessage = buildExtractionMessage(
            userMessage: userMessage,
            assistantResponse: assistantResponse,
            existingFacts: existingFacts
        )

        // Call the LLM for fact extraction
        let response = try await llmProvider.sendMessage(
            [.user(extractionUserMessage)],
            systemPrompt: FactExtractor.extractionSystemPrompt
        )

        // Parse the JSON response into raw fact data
        let rawFacts = parseExtractionResponse(response.content)

        guard !rawFacts.isEmpty else {
            Self.logger.info("No facts extracted from conversation turn")
            return []
        }

        Self.logger.info("Extracted \(rawFacts.count) candidate facts from conversation turn")

        // Convert raw facts to Fact models and insert/update them
        var insertedFacts: [Fact] = []
        for rawFact in rawFacts {
            guard let category = FactCategory(rawValue: rawFact.category) else {
                Self.logger.warning("Skipping fact with invalid category: \(rawFact.category)")
                continue
            }

            // Validate confidence and importance ranges
            let confidence = max(0.0, min(1.0, rawFact.confidence))
            let importance = max(0.0, min(1.0, rawFact.importance))

            // Skip very low confidence facts
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

            // Use insertOrUpdate to handle duplicates
            let id = try factStore.insertOrUpdate(fact)

            // Retrieve the inserted/updated fact with its database ID
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
        // Clean up the response — the LLM might wrap JSON in markdown code fences
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
```

STEP 2: Create tests/FactExtractorTests.swift

The tests use a mock LLM provider to return predictable JSON responses. This avoids making real API calls during testing.

File: tests/FactExtractorTests.swift
```swift
// FactExtractorTests.swift
// EmberHearth
//
// Unit tests for FactExtractor with mocked LLM responses.

import XCTest
@testable import EmberHearth

// MARK: - Mock LLM Provider

/// A mock LLM provider that returns pre-configured responses.
/// Used for testing FactExtractor without making real API calls.
final class MockLLMProvider: LLMProviderProtocol, @unchecked Sendable {

    /// The response content to return from sendMessage.
    var responseContent: String = "[]"

    /// Whether the mock should throw an error instead of returning a response.
    var shouldThrowError: Bool = false

    /// The error to throw when shouldThrowError is true.
    var errorToThrow: Error = NSError(domain: "MockError", code: 1, userInfo: nil)

    /// Records the last system prompt received.
    var lastSystemPrompt: String?

    /// Records the last messages received.
    var lastMessages: [LLMMessage] = []

    /// How many times sendMessage was called.
    var sendMessageCallCount: Int = 0

    var isAvailable: Bool = true

    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse {
        sendMessageCallCount += 1
        lastMessages = messages
        lastSystemPrompt = systemPrompt

        if shouldThrowError {
            throw errorToThrow
        }

        return LLMResponse(
            content: responseContent,
            usage: LLMTokenUsage(inputTokens: 100, outputTokens: 50),
            model: "mock-model",
            stopReason: .endTurn
        )
    }

    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        // Not needed for FactExtractor tests
        return AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

// MARK: - Tests

final class FactExtractorTests: XCTestCase {

    // MARK: - Helpers

    private func makeExtractor() throws -> (MockLLMProvider, FactStore, FactExtractor) {
        let mockLLM = MockLLMProvider()
        let db = try DatabaseManager(path: ":memory:")
        let store = FactStore(database: db)
        let extractor = FactExtractor(llmProvider: mockLLM, factStore: store)
        return (mockLLM, store, extractor)
    }

    // MARK: - Successful Extraction Tests

    func testExtractFactsFromValidJSON() async throws {
        let (mockLLM, store, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [
                {
                    "content": "User has a sister named Sarah",
                    "category": "relationship",
                    "importance": 0.8,
                    "confidence": 0.95
                },
                {
                    "content": "Sarah is vegan",
                    "category": "preference",
                    "importance": 0.6,
                    "confidence": 0.9
                }
            ]
            """

        let facts = try await extractor.extractFacts(
            from: "My sister Sarah is visiting next week, she's vegan",
            assistantResponse: "That sounds lovely! I'll keep in mind that Sarah is vegan.",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 2, "Should extract 2 facts")
        XCTAssertEqual(facts[0].content, "User has a sister named Sarah")
        XCTAssertEqual(facts[0].category, .relationship)
        XCTAssertEqual(facts[0].confidence, 0.95)
        XCTAssertEqual(facts[0].importance, 0.8)
        XCTAssertEqual(facts[0].source, .extracted)

        XCTAssertEqual(facts[1].content, "Sarah is vegan")
        XCTAssertEqual(facts[1].category, .preference)

        // Verify facts are stored in the database
        let storedFacts = try store.getAll()
        XCTAssertEqual(storedFacts.count, 2)
    }

    func testExtractFactsEmptyArray() async throws {
        let (mockLLM, store, extractor) = try makeExtractor()

        mockLLM.responseContent = "[]"

        let facts = try await extractor.extractFacts(
            from: "Hello, how are you?",
            assistantResponse: "I'm doing well, thank you! How can I help you today?",
            existingFacts: []
        )

        XCTAssertTrue(facts.isEmpty, "Should return empty for trivial conversation")

        let storedFacts = try store.getAll()
        XCTAssertEqual(storedFacts.count, 0)
    }

    func testExtractFactsSingleFact() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [
                {
                    "content": "User works as a software engineer",
                    "category": "biographical",
                    "importance": 0.8,
                    "confidence": 0.9
                }
            ]
            """

        let facts = try await extractor.extractFacts(
            from: "I'm a software engineer at Acme Corp",
            assistantResponse: "Nice! What kind of software do you work on?",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts[0].category, .biographical)
    }

    func testExtractFactsAllCategories() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [
                {"content": "User prefers dark mode", "category": "preference", "importance": 0.4, "confidence": 0.9},
                {"content": "User has a dog named Max", "category": "relationship", "importance": 0.7, "confidence": 0.85},
                {"content": "User lives in Portland", "category": "biographical", "importance": 0.7, "confidence": 0.9},
                {"content": "User has a dentist appointment Friday", "category": "event", "importance": 0.5, "confidence": 0.8},
                {"content": "User thinks remote work is better", "category": "opinion", "importance": 0.4, "confidence": 0.75},
                {"content": "User is working on a machine learning project", "category": "contextual", "importance": 0.6, "confidence": 0.85},
                {"content": "User is going through a divorce", "category": "secret", "importance": 0.9, "confidence": 0.7}
            ]
            """

        let facts = try await extractor.extractFacts(
            from: "test message",
            assistantResponse: "test response",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 7, "Should extract all 7 categories")

        let categories = Set(facts.map { $0.category })
        XCTAssertTrue(categories.contains(.preference))
        XCTAssertTrue(categories.contains(.relationship))
        XCTAssertTrue(categories.contains(.biographical))
        XCTAssertTrue(categories.contains(.event))
        XCTAssertTrue(categories.contains(.opinion))
        XCTAssertTrue(categories.contains(.contextual))
        XCTAssertTrue(categories.contains(.secret))
    }

    // MARK: - JSON Parsing Robustness Tests

    func testHandlesMarkdownCodeFences() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            ```json
            [
                {
                    "content": "User likes hiking",
                    "category": "preference",
                    "importance": 0.5,
                    "confidence": 0.8
                }
            ]
            ```
            """

        let facts = try await extractor.extractFacts(
            from: "I love hiking",
            assistantResponse: "Hiking is great!",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1, "Should parse JSON wrapped in markdown code fences")
        XCTAssertEqual(facts[0].content, "User likes hiking")
    }

    func testHandlesCodeFencesWithoutLanguage() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            ```
            [{"content": "User likes tea", "category": "preference", "importance": 0.4, "confidence": 0.8}]
            ```
            """

        let facts = try await extractor.extractFacts(
            from: "I like tea",
            assistantResponse: "Tea is wonderful!",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1)
    }

    func testHandlesInvalidJSON() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = "This is not valid JSON at all"

        let facts = try await extractor.extractFacts(
            from: "Hello",
            assistantResponse: "Hi there",
            existingFacts: []
        )

        XCTAssertTrue(facts.isEmpty, "Should return empty for invalid JSON, not crash")
    }

    func testHandlesSingleObjectInsteadOfArray() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        // LLM sometimes returns a single object instead of an array
        mockLLM.responseContent = """
            {
                "content": "User likes running",
                "category": "preference",
                "importance": 0.5,
                "confidence": 0.85
            }
            """

        let facts = try await extractor.extractFacts(
            from: "I went for a run this morning",
            assistantResponse: "That's great!",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1, "Should handle single object response")
        XCTAssertEqual(facts[0].content, "User likes running")
    }

    // MARK: - Confidence Filtering Tests

    func testFiltersLowConfidenceFacts() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [
                {"content": "User might like jazz", "category": "preference", "importance": 0.3, "confidence": 0.2},
                {"content": "User definitely likes coffee", "category": "preference", "importance": 0.5, "confidence": 0.9}
            ]
            """

        let facts = try await extractor.extractFacts(
            from: "test",
            assistantResponse: "test",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1, "Should filter out facts with confidence < 0.3")
        XCTAssertEqual(facts[0].content, "User definitely likes coffee")
    }

    func testClampsConfidenceAndImportance() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [
                {"content": "User likes X", "category": "preference", "importance": 1.5, "confidence": 2.0}
            ]
            """

        let facts = try await extractor.extractFacts(
            from: "test",
            assistantResponse: "test",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1)
        XCTAssertLessThanOrEqual(facts[0].confidence, 1.0, "Confidence should be clamped to 1.0")
        XCTAssertLessThanOrEqual(facts[0].importance, 1.0, "Importance should be clamped to 1.0")
    }

    // MARK: - Invalid Category Tests

    func testSkipsInvalidCategory() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [
                {"content": "Valid fact", "category": "preference", "importance": 0.5, "confidence": 0.8},
                {"content": "Invalid category fact", "category": "nonexistent_category", "importance": 0.5, "confidence": 0.8}
            ]
            """

        let facts = try await extractor.extractFacts(
            from: "test",
            assistantResponse: "test",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1, "Should skip facts with invalid categories")
        XCTAssertEqual(facts[0].content, "Valid fact")
    }

    // MARK: - Duplicate Handling Tests

    func testDuplicateFactsAreMerged() async throws {
        let (mockLLM, store, extractor) = try makeExtractor()

        // First: insert an existing fact
        try store.insert(Fact.create(
            content: "User likes coffee",
            category: .preference,
            confidence: 0.7
        ))

        // LLM extracts a similar fact
        mockLLM.responseContent = """
            [{"content": "User likes coffee a lot", "category": "preference", "importance": 0.5, "confidence": 0.9}]
            """

        let facts = try await extractor.extractFacts(
            from: "I really love my morning coffee",
            assistantResponse: "Coffee is great!",
            existingFacts: try store.getAll()
        )

        // Should still return 1 fact (merged)
        XCTAssertEqual(facts.count, 1)

        // Database should have only 1 fact (not 2)
        let allFacts = try store.getAll()
        XCTAssertEqual(allFacts.count, 1, "Should merge duplicate, not create second fact")

        // The merged fact should have higher confidence
        XCTAssertGreaterThanOrEqual(allFacts[0].confidence, 0.7)
    }

    // MARK: - LLM Call Verification Tests

    func testSendsCorrectSystemPrompt() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = "[]"

        _ = try await extractor.extractFacts(
            from: "Hello",
            assistantResponse: "Hi there",
            existingFacts: []
        )

        XCTAssertNotNil(mockLLM.lastSystemPrompt, "Should send a system prompt")
        XCTAssertTrue(
            mockLLM.lastSystemPrompt?.contains("fact extraction") ?? false,
            "System prompt should mention fact extraction"
        )
    }

    func testIncludesConversationInMessage() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = "[]"

        _ = try await extractor.extractFacts(
            from: "I love pizza",
            assistantResponse: "Pizza is delicious!",
            existingFacts: []
        )

        XCTAssertEqual(mockLLM.lastMessages.count, 1, "Should send exactly 1 user message")
        let messageContent = mockLLM.lastMessages[0].content
        XCTAssertTrue(messageContent.contains("I love pizza"), "Should include user message")
        XCTAssertTrue(messageContent.contains("Pizza is delicious"), "Should include assistant response")
    }

    func testIncludesExistingFactsInPrompt() async throws {
        let (mockLLM, store, extractor) = try makeExtractor()

        // Add existing facts
        try store.insert(Fact.create(content: "User likes coffee", category: .preference))
        try store.insert(Fact.create(content: "User lives in Portland", category: .biographical))

        mockLLM.responseContent = "[]"

        _ = try await extractor.extractFacts(
            from: "test",
            assistantResponse: "test",
            existingFacts: try store.getAll()
        )

        let messageContent = mockLLM.lastMessages[0].content
        XCTAssertTrue(
            messageContent.contains("User likes coffee"),
            "Should include existing facts in prompt"
        )
        XCTAssertTrue(
            messageContent.contains("User lives in Portland"),
            "Should include all existing facts"
        )
    }

    func testHandlesEmptyExistingFacts() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = "[]"

        _ = try await extractor.extractFacts(
            from: "test",
            assistantResponse: "test",
            existingFacts: []
        )

        let messageContent = mockLLM.lastMessages[0].content
        XCTAssertTrue(
            messageContent.contains("Previously known facts: None") ||
            messageContent.contains("Previously known facts"),
            "Should handle empty existing facts gracefully"
        )
    }

    // MARK: - Error Handling Tests

    func testLLMErrorPropagates() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.shouldThrowError = true
        mockLLM.errorToThrow = NSError(domain: "TestError", code: 500, userInfo: nil)

        do {
            _ = try await extractor.extractFacts(
                from: "test",
                assistantResponse: "test",
                existingFacts: []
            )
            XCTFail("Should throw when LLM call fails")
        } catch {
            // Expected — LLM errors should propagate
        }
    }

    // MARK: - Source Tests

    func testExtractedFactsHaveExtractedSource() async throws {
        let (mockLLM, _, extractor) = try makeExtractor()

        mockLLM.responseContent = """
            [{"content": "User likes music", "category": "preference", "importance": 0.5, "confidence": 0.8}]
            """

        let facts = try await extractor.extractFacts(
            from: "I listen to music all day",
            assistantResponse: "What genres do you enjoy?",
            existingFacts: []
        )

        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts[0].source, .extracted, "LLM-extracted facts should have source = .extracted")
    }
}
```

STEP 3: Verify the build

After creating both files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. Common issues:
- The MockLLMProvider must conform to `LLMProviderProtocol` which requires both `sendMessage` and `streamMessage`. Even though FactExtractor doesn't use streaming, the mock must implement both methods.
- The `@unchecked Sendable` conformance on MockLLMProvider is needed because it has mutable state (var properties). This is safe for tests since they are single-threaded.
- If `Logger` is not available (it requires macOS 11+), the import `os` should work since the target is macOS 13+.
- The async test methods use `async throws` — this requires Xcode 14+ / Swift 5.7+ which is available since the project targets macOS 13+.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify any existing files (DatabaseManager, FactStore, Fact, LLM types, etc.).
- Do NOT modify any module placeholder files.
- FactExtractor uses dependency injection for both the LLM provider and the fact store.
- The extraction prompt instructs the LLM to return JSON only — no markdown, no explanation.
- The `cleanJSONResponse()` method handles the common case where the LLM wraps JSON in markdown code fences despite being told not to.
- The mock LLM provider records all calls for test assertions (lastSystemPrompt, lastMessages, sendMessageCallCount).
- NEVER log user message content, assistant response content, or API keys in production. The logger in FactExtractor only logs counts and error descriptions.
- The extraction adds an extra API call per conversation turn. For MVP, this is an acceptable cost/benefit tradeoff. Optimization (batching, combined extraction) is planned for v1.2.
```

---

## Acceptance Criteria

- [ ] `src/Memory/FactExtractor.swift` exists and compiles
- [ ] Uses `LLMProviderProtocol` (not `ClaudeAPIClient` directly) for LLM calls
- [ ] Extraction system prompt clearly instructs LLM to return JSON array only
- [ ] Extraction prompt includes the conversation (user message + assistant response)
- [ ] Extraction prompt includes existing facts for duplicate avoidance
- [ ] JSON parsing handles: valid arrays, empty arrays, markdown code fences, single objects, invalid JSON
- [ ] Invalid JSON does NOT crash — returns empty array and logs warning
- [ ] Facts with invalid categories are skipped (not crash)
- [ ] Facts with confidence < 0.3 are filtered out
- [ ] Confidence and importance values are clamped to 0.0-1.0
- [ ] All extracted facts have `source = .extracted`
- [ ] Duplicate facts are merged via `insertOrUpdate()` (not duplicated)
- [ ] LLM errors propagate (not swallowed)
- [ ] MockLLMProvider conforms to `LLMProviderProtocol` with both `sendMessage` and `streamMessage`
- [ ] Logger NEVER logs message content or API keys
- [ ] All unit tests pass
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Memory/FactExtractor.swift && echo "FactExtractor.swift exists" || echo "MISSING: FactExtractor.swift"
test -f tests/FactExtractorTests.swift && echo "FactExtractorTests.swift exists" || echo "MISSING: FactExtractorTests.swift"

# Verify uses protocol (not concrete class)
grep "LLMProviderProtocol" src/Memory/FactExtractor.swift

# Verify extraction system prompt exists
grep "extractionSystemPrompt" src/Memory/FactExtractor.swift

# Verify JSON parsing handles code fences
grep "cleanJSONResponse" src/Memory/FactExtractor.swift

# Verify confidence filtering
grep "confidence >= 0.3" src/Memory/FactExtractor.swift || grep "confidence < 0.3" src/Memory/FactExtractor.swift

# Verify source is .extracted
grep "\.extracted" src/Memory/FactExtractor.swift

# Verify mock LLM exists in tests
grep "MockLLMProvider" tests/FactExtractorTests.swift

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the FactExtractor created in task 0303 for EmberHearth. Check for these common issues:

1. EXTRACTION PROMPT QUALITY:
   - Verify the system prompt clearly instructs the LLM to return JSON only
   - Verify category definitions match FactCategory enum values exactly: preference, relationship, biographical, event, opinion, contextual, secret
   - Verify the prompt includes guidance on importance and confidence scoring
   - Verify the prompt tells the LLM to extract facts about the USER only
   - Verify the prompt tells the LLM to avoid trivial facts
   - Verify the prompt tells the LLM to avoid duplicating existing facts

2. PROMPT BUILDING:
   - Verify buildExtractionMessage() includes the user message and assistant response
   - Verify it includes existing facts (when provided) with their categories
   - Verify it handles empty existing facts gracefully
   - Verify existing facts are limited to maxExistingFactsInPrompt (30)

3. JSON PARSING ROBUSTNESS:
   - Verify parseExtractionResponse() handles: valid JSON arrays, empty arrays, single objects, invalid JSON, markdown code fences
   - Verify cleanJSONResponse() removes ```json and ``` markers
   - Verify it also removes plain ``` markers (without "json" language tag)
   - Verify JSONDecoder is used (not manual string parsing)
   - Verify parse failures return empty array (not throw)

4. FACT VALIDATION:
   - Verify invalid categories are skipped (not crash)
   - Verify confidence < 0.3 facts are filtered out
   - Verify confidence and importance are clamped to 0.0-1.0 range
   - Verify all facts get source = .extracted

5. DUPLICATE HANDLING:
   - Verify insertOrUpdate() is used (not plain insert())
   - Verify this delegates duplicate detection to FactStore

6. DEPENDENCY INJECTION:
   - Verify FactExtractor takes LLMProviderProtocol (protocol, not concrete class)
   - Verify it takes FactStore via constructor
   - Verify it does NOT create its own instances

7. SECURITY:
   - Verify Logger NEVER logs message content or API keys
   - Verify logger only logs counts, error descriptions, and status
   - Verify no print() statements exist

8. MOCK LLM PROVIDER:
   - Verify MockLLMProvider conforms to LLMProviderProtocol
   - Verify it implements BOTH sendMessage and streamMessage
   - Verify it records lastSystemPrompt and lastMessages for assertions
   - Verify it supports configurable responses and error injection

9. TEST COVERAGE:
   - Verify tests cover: valid extraction, empty array, single fact, all categories, markdown fences, invalid JSON, single object response, low confidence filtering, clamping, invalid category, duplicate merging, system prompt verification, conversation in prompt, existing facts in prompt, error propagation, source verification

10. BUILD VERIFICATION:
    - Run `swift build` and verify success
    - Run `swift test` and verify all FactExtractorTests pass

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m4): add LLM-based fact extraction from conversations
```

---

## Notes for Next Task

- The FactExtractor is now available at `src/Memory/FactExtractor.swift`. It operates after each conversation turn: user message in, assistant response out, then extract facts.
- The MockLLMProvider in `tests/FactExtractorTests.swift` is defined inside the test file. If future tasks need it, it should be moved to a shared test utilities file.
- Task 0304 (SessionManager) does NOT depend on FactExtractor. SessionManager handles conversation sessions and message history. Fact extraction happens at a higher level (in the message processing pipeline, which will be wired up in M5).
- The extraction prompt design is in `FactExtractor.extractionSystemPrompt`. If the personality system (M5) needs to modify this prompt, it can be made configurable.
- The `extractionMaxTokens` constant (512) is set in FactExtractor but is NOT passed to the LLM provider in this implementation — the LLMProviderProtocol's `sendMessage` does not accept maxTokens as a parameter. If the extraction needs a different maxTokens than the default, the calling code should create a separate ClaudeAPIClient instance with `maxTokens: 512`. This will be wired up in the integration milestone.
