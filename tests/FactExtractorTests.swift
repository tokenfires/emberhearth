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

    /// Records the last maxTokens value received.
    var lastMaxTokens: Int?

    /// How many times sendMessage was called.
    var sendMessageCallCount: Int = 0

    var isAvailable: Bool = true

    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?, maxTokens: Int?) async throws -> LLMResponse {
        sendMessageCallCount += 1
        lastMessages = messages
        lastSystemPrompt = systemPrompt
        lastMaxTokens = maxTokens

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

    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?, maxTokens: Int?) -> AsyncThrowingStream<String, Error> {
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

        try store.insert(Fact.create(
            content: "User likes coffee",
            category: .preference,
            confidence: 0.7
        ))

        mockLLM.responseContent = """
            [{"content": "User likes coffee a lot", "category": "preference", "importance": 0.5, "confidence": 0.9}]
            """

        let facts = try await extractor.extractFacts(
            from: "I really love my morning coffee",
            assistantResponse: "Coffee is great!",
            existingFacts: try store.getAll()
        )

        XCTAssertEqual(facts.count, 1)

        let allFacts = try store.getAll()
        XCTAssertEqual(allFacts.count, 1, "Should merge duplicate, not create second fact")

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
