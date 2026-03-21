// SummaryGeneratorTests.swift
// EmberHearth
//
// Unit tests for SummaryGenerator.

import XCTest
@testable import EmberHearth

final class SummaryGeneratorTests: XCTestCase {

    private var generator: SummaryGenerator!

    override func setUp() {
        super.setUp()
        // Use lower thresholds for testing
        generator = SummaryGenerator(
            messageCountThreshold: 10,
            messagesToSummarize: 5,
            recentMessagesToKeep: 3,
            tokenThreshold: 100,
            maxSummaryTokens: 512
        )
    }

    override func tearDown() {
        generator = nil
        super.tearDown()
    }

    // MARK: - ShouldSummarize Tests

    func testShouldNotSummarizeWhenBelowMessageThreshold() {
        // 5 messages, threshold is 10
        let result = generator.shouldSummarize(
            totalMessageCount: 5,
            oldestMessagesTokenCount: 500
        )
        XCTAssertFalse(result, "Should not summarize when message count is below threshold")
    }

    func testShouldNotSummarizeWhenBelowTokenThreshold() {
        // 15 messages but only 50 tokens
        let result = generator.shouldSummarize(
            totalMessageCount: 15,
            oldestMessagesTokenCount: 50
        )
        XCTAssertFalse(result, "Should not summarize when token count is below threshold")
    }

    func testShouldSummarizeWhenBothThresholdsMet() {
        let result = generator.shouldSummarize(
            totalMessageCount: 15,
            oldestMessagesTokenCount: 500
        )
        XCTAssertTrue(result, "Should summarize when both thresholds are met")
    }

    func testShouldNotSummarizeAtExactThreshold() {
        // Exactly at threshold (not above)
        let result = generator.shouldSummarize(
            totalMessageCount: 10,
            oldestMessagesTokenCount: 100
        )
        XCTAssertFalse(result, "Should not summarize at exact threshold (must exceed)")
    }

    func testShouldSummarizeJustAboveThreshold() {
        let result = generator.shouldSummarize(
            totalMessageCount: 11,
            oldestMessagesTokenCount: 101
        )
        XCTAssertTrue(result, "Should summarize just above threshold")
    }

    // MARK: - Default Configuration Tests

    func testDefaultThresholds() {
        let defaultGenerator = SummaryGenerator()
        XCTAssertEqual(defaultGenerator.messageCountThreshold, 30)
        XCTAssertEqual(defaultGenerator.messagesToSummarize, 20)
        XCTAssertEqual(defaultGenerator.recentMessagesToKeep, 10)
        XCTAssertEqual(defaultGenerator.tokenThreshold, 15_000)
        XCTAssertEqual(defaultGenerator.maxSummaryTokens, 1024)
    }

    func testCustomThresholds() {
        let custom = SummaryGenerator(
            messageCountThreshold: 50,
            messagesToSummarize: 30,
            recentMessagesToKeep: 15,
            tokenThreshold: 20_000,
            maxSummaryTokens: 2048
        )
        XCTAssertEqual(custom.messageCountThreshold, 50)
        XCTAssertEqual(custom.messagesToSummarize, 30)
        XCTAssertEqual(custom.recentMessagesToKeep, 15)
        XCTAssertEqual(custom.tokenThreshold, 20_000)
        XCTAssertEqual(custom.maxSummaryTokens, 2048)
    }

    // MARK: - Summarization Prompt Tests

    func testSummarizationPromptIsNotEmpty() {
        XCTAssertFalse(SummaryGenerator.summarizationPrompt.isEmpty)
    }

    func testSummarizationPromptContainsRequiredElements() {
        let prompt = SummaryGenerator.summarizationPrompt
        XCTAssertTrue(prompt.contains("Key topics"), "Prompt should mention key topics")
        XCTAssertTrue(prompt.contains("decisions"), "Prompt should mention decisions")
        XCTAssertTrue(
            prompt.contains("Action items") || prompt.contains("action items"),
            "Prompt should mention action items"
        )
        XCTAssertTrue(prompt.contains("emotional tone"), "Prompt should mention emotional tone")
        XCTAssertTrue(prompt.contains("third person"), "Prompt should instruct third-person writing")
        XCTAssertTrue(prompt.contains("500 words"), "Prompt should specify word limit")
    }

    func testSummarizationPromptMentionsPreviousSummary() {
        let prompt = SummaryGenerator.summarizationPrompt
        XCTAssertTrue(
            prompt.lowercased().contains("previous summary"),
            "Prompt should mention incorporating previous summary"
        )
    }

    // MARK: - SummaryMessage Tests

    func testSummaryMessageCreation() {
        let msg = SummaryMessage(
            id: 42,
            content: "Hello, how are you?",
            isFromUser: true,
            timestamp: Date()
        )
        XCTAssertEqual(msg.id, 42)
        XCTAssertEqual(msg.content, "Hello, how are you?")
        XCTAssertTrue(msg.isFromUser)
    }

    func testSummaryMessageWithNilId() {
        let msg = SummaryMessage(
            id: nil,
            content: "Test message",
            isFromUser: false,
            timestamp: Date()
        )
        XCTAssertNil(msg.id)
    }

    // MARK: - SummarizationResult Tests

    func testSummarizationResultFields() {
        let result = SummarizationResult(
            summary: "The user discussed their work schedule.",
            summarizedMessageCount: 15,
            summarizedMessageIds: [1, 2, 3, 4, 5]
        )
        XCTAssertEqual(result.summary, "The user discussed their work schedule.")
        XCTAssertEqual(result.summarizedMessageCount, 15)
        XCTAssertEqual(result.summarizedMessageIds, [1, 2, 3, 4, 5])
    }

    // MARK: - generateSummary Tests

    func testGenerateSummaryWithEmptyMessagesReturnsNil() async {
        let mockClient = SummaryMockLLMProvider(response: "Should not be called")
        let result = await generator.generateSummary(
            for: [],
            previousSummary: nil,
            apiClient: mockClient
        )
        XCTAssertNil(result, "generateSummary should return nil for empty message list")
        XCTAssertFalse(mockClient.wasCalled, "API should not be called for empty messages")
    }

    func testGenerateSummaryCallsAPIAndReturnsContent() async {
        let expectedSummary = "The user discussed their plans for the week."
        let mockClient = SummaryMockLLMProvider(response: expectedSummary)
        let messages = createTestMessages(count: 3)

        let result = await generator.generateSummary(
            for: messages,
            previousSummary: nil,
            apiClient: mockClient
        )

        XCTAssertEqual(result, expectedSummary, "generateSummary should return the LLM's response content")
        XCTAssertTrue(mockClient.wasCalled, "API should have been called")
    }

    func testGenerateSummaryIncludesPreviousSummaryInPrompt() async {
        let previousSummary = "The user had previously discussed work deadlines."
        let mockClient = SummaryMockLLMProvider(response: "Updated summary.")
        let messages = createTestMessages(count: 3)

        _ = await generator.generateSummary(
            for: messages,
            previousSummary: previousSummary,
            apiClient: mockClient
        )

        XCTAssertTrue(
            mockClient.lastPrompt?.contains(previousSummary) ?? false,
            "The previous summary should be included in the prompt sent to the LLM"
        )
    }

    func testGenerateSummaryReturnsNilOnAPIFailure() async {
        let mockClient = SummaryMockLLMProvider(shouldFail: true)
        let messages = createTestMessages(count: 3)

        let result = await generator.generateSummary(
            for: messages,
            previousSummary: nil,
            apiClient: mockClient
        )

        XCTAssertNil(result, "generateSummary should return nil on API failure (graceful degradation)")
    }

    func testGenerateSummaryReturnsNilForEmptyLLMResponse() async {
        let mockClient = SummaryMockLLMProvider(response: "   \n  ")
        let messages = createTestMessages(count: 3)

        let result = await generator.generateSummary(
            for: messages,
            previousSummary: nil,
            apiClient: mockClient
        )

        XCTAssertNil(result, "generateSummary should return nil when LLM returns only whitespace")
    }

    func testGenerateSummaryPassesMaxTokensToAPI() async {
        let mockClient = SummaryMockLLMProvider(response: "Summary text.")
        let messages = createTestMessages(count: 3)

        _ = await generator.generateSummary(
            for: messages,
            previousSummary: nil,
            apiClient: mockClient
        )

        XCTAssertEqual(
            mockClient.lastMaxTokens,
            generator.maxSummaryTokens,
            "maxSummaryTokens should be passed through to the API call"
        )
    }

    func testGenerateSummaryPassesSystemPromptToAPI() async {
        let mockClient = SummaryMockLLMProvider(response: "Summary text.")
        let messages = createTestMessages(count: 3)

        _ = await generator.generateSummary(
            for: messages,
            previousSummary: nil,
            apiClient: mockClient
        )

        XCTAssertNotNil(mockClient.lastSystemPrompt, "A system prompt should be passed to the LLM")
        XCTAssertTrue(
            mockClient.lastSystemPrompt?.contains("summarizer") ?? false,
            "System prompt should identify this as a summarization task"
        )
    }

    // MARK: - SummarizeIfNeeded Logic Tests

    func testSummarizeIfNeededWithTooFewMessages() async {
        // Create only 5 messages — below the threshold of 10
        let messages = createTestMessages(count: 5)
        let mockClient = SummaryMockLLMProvider(response: "Should not be called")

        let result = await generator.summarizeIfNeeded(
            allMessages: messages,
            previousSummary: nil,
            apiClient: mockClient,
            tokenEstimator: { text in text.count / 4 }
        )

        XCTAssertNil(result, "Should not summarize when below message threshold")
        XCTAssertFalse(mockClient.wasCalled, "API should not be called when threshold not met")
    }

    func testSummarizeIfNeededWithEmptyMessages() async {
        let mockClient = SummaryMockLLMProvider(response: "Should not be called")

        let result = await generator.summarizeIfNeeded(
            allMessages: [],
            previousSummary: nil,
            apiClient: mockClient,
            tokenEstimator: { text in text.count / 4 }
        )

        XCTAssertNil(result, "Should not summarize empty message list")
    }

    func testSummarizeIfNeededTriggersWhenThresholdsMet() async {
        // 15 messages with high token count — above both thresholds
        let messages = createTestMessages(count: 15, contentLength: 200)
        let mockClient = SummaryMockLLMProvider(response: "The user discussed various topics.")

        let result = await generator.summarizeIfNeeded(
            allMessages: messages,
            previousSummary: nil,
            apiClient: mockClient,
            // Token estimator that will exceed the 100-token threshold
            tokenEstimator: { text in text.count / 2 }
        )

        XCTAssertNotNil(result, "Should return a result when thresholds are met")
        XCTAssertEqual(result?.summary, "The user discussed various topics.")
    }

    func testSummarizeIfNeededKeepsRecentMessages() async {
        // 15 messages, recentMessagesToKeep=3, so only the oldest messages are candidates
        let messages = createTestMessages(count: 15, contentLength: 200)
        let mockClient = SummaryMockLLMProvider(response: "Summary of older messages.")

        let result = await generator.summarizeIfNeeded(
            allMessages: messages,
            previousSummary: nil,
            apiClient: mockClient,
            tokenEstimator: { text in text.count / 2 }
        )

        // messagesToSummarize=5, so at most 5 messages should be summarized
        XCTAssertNotNil(result)
        XCTAssertLessThanOrEqual(
            result?.summarizedMessageCount ?? 0,
            generator.messagesToSummarize,
            "Should not summarize more than messagesToSummarize messages"
        )
    }

    func testSummarizeIfNeededResultContainsMessageIds() async {
        let messages = createTestMessages(count: 15, contentLength: 200)
        let mockClient = SummaryMockLLMProvider(response: "Summary.")

        let result = await generator.summarizeIfNeeded(
            allMessages: messages,
            previousSummary: nil,
            apiClient: mockClient,
            tokenEstimator: { text in text.count / 2 }
        )

        XCTAssertNotNil(result)
        XCTAssertFalse(
            result?.summarizedMessageIds.isEmpty ?? true,
            "Result should contain IDs of summarized messages"
        )
    }

    // MARK: - Edge Case Tests

    func testShouldSummarizeWithVeryHighMessageCount() {
        let result = generator.shouldSummarize(
            totalMessageCount: 1000,
            oldestMessagesTokenCount: 50_000
        )
        XCTAssertTrue(result, "Should summarize with very high message count")
    }

    func testShouldSummarizeWithZeroMessages() {
        let result = generator.shouldSummarize(
            totalMessageCount: 0,
            oldestMessagesTokenCount: 0
        )
        XCTAssertFalse(result, "Should not summarize with zero messages")
    }

    // MARK: - Helpers

    /// Creates test messages for summarization tests.
    private func createTestMessages(count: Int, contentLength: Int = 60) -> [SummaryMessage] {
        var messages: [SummaryMessage] = []
        let baseDate = Date()
        let content = String(repeating: "x", count: contentLength)
        for i in 0..<count {
            messages.append(SummaryMessage(
                id: Int64(i + 1),
                content: "\(content) message \(i + 1)",
                isFromUser: i % 2 == 0,
                timestamp: baseDate.addingTimeInterval(TimeInterval(i * 60))
            ))
        }
        return messages
    }
}

// MARK: - MockLLMProvider

/// A test double for LLMProviderProtocol used exclusively by SummaryGeneratorTests.
private final class SummaryMockLLMProvider: LLMProviderProtocol {

    var isAvailable: Bool { true }

    /// The canned response content to return.
    private let responseContent: String

    /// Whether to simulate an API failure.
    private let shouldFail: Bool

    /// Tracks whether sendMessage was called.
    private(set) var wasCalled = false

    /// The last prompt passed to sendMessage (first message content).
    private(set) var lastPrompt: String?

    /// The last system prompt passed to sendMessage.
    private(set) var lastSystemPrompt: String?

    /// The last maxTokens value passed to sendMessage.
    private(set) var lastMaxTokens: Int?

    init(response: String = "Mock summary.", shouldFail: Bool = false) {
        self.responseContent = response
        self.shouldFail = shouldFail
    }

    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?, maxTokens: Int?) async throws -> LLMResponse {
        wasCalled = true
        lastPrompt = messages.first?.content
        lastSystemPrompt = systemPrompt
        lastMaxTokens = maxTokens

        if shouldFail {
            throw SummaryMockLLMError.simulatedFailure
        }

        return LLMResponse(
            content: responseContent,
            usage: LLMTokenUsage(inputTokens: 100, outputTokens: 50),
            model: "mock-model",
            stopReason: .endTurn
        )
    }

    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?, maxTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }
}

private enum SummaryMockLLMError: Error {
    case simulatedFailure
}
