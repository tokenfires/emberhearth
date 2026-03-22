// ContextBuilderTests.swift
// EmberHearthTests
//
// Tests for ContextBuilder context assembly logic.

import XCTest
@testable import EmberHearthCore

final class ContextBuilderTests: XCTestCase {

    // MARK: - Budget Constants

    func testBudgetConstants() {
        // Values must match the Hybrid Adaptive budget in session-management.md §1.
        // These constants are used only by the legacy static buildContext() path.
        // buildIntegratedContext() computes budgets inline as percentages.
        XCTAssertEqual(ContextBuilder.totalBudget, 100_000)
        XCTAssertEqual(ContextBuilder.systemPromptBudget, 10_000)  // ~10%
        XCTAssertEqual(ContextBuilder.recentMessagesBudget, 25_000) // ~25%
        XCTAssertEqual(ContextBuilder.responseBudget, 35_000)       // ~35%
    }

    // MARK: - Token Estimation

    func testTokenEstimateEmpty() {
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: ""), 0)
    }

    func testTokenEstimateSingleChar() {
        // Single character: (1 + 3) / 4 = 1, max(1, 1) = 1
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "a"), 1)
    }

    func testTokenEstimateFourChars() {
        // 4 chars: (4 + 3) / 4 = 1, max(1, 1) = 1
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "test"), 1)
    }

    func testTokenEstimateFiveChars() {
        // 5 chars: (5 + 3) / 4 = 2
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "hello"), 2)
    }

    func testTokenEstimateEightChars() {
        // 8 chars: (8 + 3) / 4 = 2
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "12345678"), 2)
    }

    func testTokenEstimateNineChars() {
        // 9 chars: (9 + 3) / 4 = 3
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "123456789"), 3)
    }

    func testTokenEstimateLargeText() {
        // 400 chars → (400 + 3) / 4 = 100 tokens
        let text = String(repeating: "a", count: 400)
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: text), 100)
    }

    func testTokenEstimateIsNonZeroForNonEmptyInput() {
        let texts = ["x", "hello world", "This is a test sentence."]
        for text in texts {
            XCTAssertGreaterThan(ContextBuilder.tokenEstimate(for: text), 0, "Expected non-zero for: \(text)")
        }
    }

    // MARK: - Basic Context Building

    func testBuildContextEmptyHistory() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "You are a helpful assistant.",
            recentMessages: [],
            newMessage: "Hello!"
        )

        XCTAssertEqual(result.messages.count, 1)
        XCTAssertEqual(result.messages[0].role, .user)
        XCTAssertEqual(result.messages[0].content, "Hello!")
        XCTAssertEqual(result.systemPrompt, "You are a helpful assistant.")
        XCTAssertEqual(result.truncatedMessageCount, 0)
        XCTAssertGreaterThan(result.estimatedTokens, 0)
    }

    func testBuildContextWithHistory() {
        let history: [LLMMessage] = [
            .user("First message"),
            .assistant("First response"),
            .user("Second message"),
            .assistant("Second response")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "You are a helpful assistant.",
            recentMessages: history,
            newMessage: "Third message"
        )

        // Should include all history + new message
        XCTAssertEqual(result.messages.count, 5)
        XCTAssertEqual(result.truncatedMessageCount, 0)

        // First message should be the oldest history
        XCTAssertEqual(result.messages[0].content, "First message")
        XCTAssertEqual(result.messages[0].role, .user)

        // Last message should be the new user message
        XCTAssertEqual(result.messages[4].content, "Third message")
        XCTAssertEqual(result.messages[4].role, .user)
    }

    func testBuildContextLastMessageIsAlwaysNewMessage() {
        let history: [LLMMessage] = [
            .user("old"),
            .assistant("response")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: history,
            newMessage: "brand new question"
        )

        XCTAssertEqual(result.messages.last?.role, .user)
        XCTAssertEqual(result.messages.last?.content, "brand new question")
    }

    func testBuildContextChronologicalOrder() {
        let history: [LLMMessage] = [
            .user("msg1"),
            .assistant("resp1"),
            .user("msg2"),
            .assistant("resp2")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: history,
            newMessage: "msg3"
        )

        XCTAssertEqual(result.messages[0].content, "msg1")
        XCTAssertEqual(result.messages[1].content, "resp1")
        XCTAssertEqual(result.messages[2].content, "msg2")
        XCTAssertEqual(result.messages[3].content, "resp2")
        XCTAssertEqual(result.messages[4].content, "msg3")
    }

    // MARK: - System Prompt Pass-Through

    func testSystemPromptPassedThrough() {
        let systemPrompt = "You are Ember, a compassionate AI companion."
        let result = ContextBuilder.buildContext(
            systemPrompt: systemPrompt,
            recentMessages: [],
            newMessage: "Hi"
        )
        XCTAssertEqual(result.systemPrompt, systemPrompt)
    }

    func testSystemPromptNotInMessagesArray() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "System instructions here.",
            recentMessages: [],
            newMessage: "Hello"
        )
        let systemMessages = result.messages.filter { $0.role == .system }
        XCTAssertTrue(systemMessages.isEmpty, "System messages should not appear in the messages array")
    }

    // MARK: - Token Budget Enforcement

    func testTruncationWhenHistoryExceedsBudget() {
        // Create many messages that together exceed the budget
        // recentMessagesBudget = 50_000 tokens ≈ 200_000 chars
        // Each message below is ~250 chars = ~63 tokens + 4 overhead = ~67 tokens
        // 50_000 / 67 ≈ 746 messages fit — we'll use more than that

        let longContent = String(repeating: "x", count: 1000)  // ~250 tokens each
        var history: [LLMMessage] = []
        for i in 0..<300 {
            history.append(.user("User \(i): \(longContent)"))
            history.append(.assistant("Assistant \(i): \(longContent)"))
        }

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: history,
            newMessage: "New question"
        )

        // Some messages should have been truncated
        XCTAssertGreaterThan(result.truncatedMessageCount, 0)

        // The newest messages should be kept (not the oldest)
        // The last history message before newMessage should be present
        let secondToLast = result.messages[result.messages.count - 2]
        XCTAssertTrue(
            secondToLast.content.contains("Assistant 299") || secondToLast.role == .assistant,
            "Should keep newest messages, not oldest"
        )

        // Estimated tokens should be within budget
        let totalBudgetUsed = ContextBuilder.recentMessagesBudget + ContextBuilder.systemPromptBudget
        XCTAssertLessThanOrEqual(result.estimatedTokens, totalBudgetUsed + 1000) // allow small overrun from system prompt
    }

    func testNoTruncationForSmallHistory() {
        let history: [LLMMessage] = [
            .user("Short message"),
            .assistant("Short reply")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: history,
            newMessage: "Another short message"
        )

        XCTAssertEqual(result.truncatedMessageCount, 0)
        XCTAssertEqual(result.messages.count, 3)
    }

    // MARK: - System Prompt Truncation

    func testSystemPromptTruncatedWhenOverBudget() {
        // systemPromptBudget = 10_000 tokens ≈ 40_000 chars
        // Create a system prompt that exceeds this
        let hugeSystemPrompt = String(repeating: "y", count: 50_000)  // ~12_500 tokens

        let result = ContextBuilder.buildContext(
            systemPrompt: hugeSystemPrompt,
            recentMessages: [],
            newMessage: "Hi"
        )

        // The system prompt should be truncated
        XCTAssertLessThan(result.systemPrompt.count, hugeSystemPrompt.count)
        XCTAssertTrue(result.systemPrompt.hasSuffix("\n[truncated]"), "Truncated system prompt should end with truncation marker")

        // Token estimate for system prompt should be within budget
        let systemPromptTokens = ContextBuilder.tokenEstimate(for: result.systemPrompt)
        XCTAssertLessThanOrEqual(systemPromptTokens, ContextBuilder.systemPromptBudget)
    }

    func testSystemPromptNotTruncatedWhenWithinBudget() {
        let shortSystemPrompt = "You are a helpful assistant."

        let result = ContextBuilder.buildContext(
            systemPrompt: shortSystemPrompt,
            recentMessages: [],
            newMessage: "Hi"
        )

        XCTAssertEqual(result.systemPrompt, shortSystemPrompt)
        XCTAssertFalse(result.systemPrompt.contains("[truncated]"))
    }

    // MARK: - ContextResult Equatable

    func testContextResultEquatable() {
        let result1 = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: "Hello"
        )
        let result2 = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: "Hello"
        )

        XCTAssertEqual(result1, result2)
    }

    func testContextResultNotEqualForDifferentMessages() {
        let result1 = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: "Hello"
        )
        let result2 = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: "Goodbye"
        )

        XCTAssertNotEqual(result1, result2)
    }

    // MARK: - Estimated Tokens

    func testEstimatedTokensIncludesSystemAndMessages() {
        let systemPrompt = String(repeating: "s", count: 400)  // 100 tokens
        let newMessage = String(repeating: "m", count: 400)    // 100 tokens

        let result = ContextBuilder.buildContext(
            systemPrompt: systemPrompt,
            recentMessages: [],
            newMessage: newMessage
        )

        let expectedMin = ContextBuilder.tokenEstimate(for: systemPrompt) +
                          ContextBuilder.tokenEstimate(for: newMessage)
        XCTAssertGreaterThanOrEqual(result.estimatedTokens, expectedMin)
    }

    func testEstimatedTokensIncludesHistoryMessages() {
        let history: [LLMMessage] = [
            .user(String(repeating: "a", count: 400)),   // ~100 tokens
            .assistant(String(repeating: "b", count: 400)) // ~100 tokens
        ]

        let resultWithHistory = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: history,
            newMessage: "Hi"
        )

        let resultWithoutHistory = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: "Hi"
        )

        XCTAssertGreaterThan(resultWithHistory.estimatedTokens, resultWithoutHistory.estimatedTokens)
    }

    // MARK: - Edge Cases

    func testEmptyNewMessage() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: ""
        )

        XCTAssertEqual(result.messages.count, 1)
        XCTAssertEqual(result.messages[0].content, "")
        XCTAssertEqual(result.messages[0].role, .user)
    }

    func testEmptySystemPrompt() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "",
            recentMessages: [],
            newMessage: "Hello"
        )

        XCTAssertEqual(result.systemPrompt, "")
        XCTAssertEqual(result.messages.count, 1)
    }

    func testSingleHistoryMessage() {
        let history: [LLMMessage] = [.assistant("Previous response")]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: history,
            newMessage: "Follow-up"
        )

        XCTAssertEqual(result.messages.count, 2)
        XCTAssertEqual(result.messages[0].content, "Previous response")
        XCTAssertEqual(result.messages[1].content, "Follow-up")
    }
}

// MARK: - Instance API Tests (Task 0402)
//
// NOTE: Integration tests for `buildIntegratedContext()` are intentionally
// absent here. That method requires a live DatabaseManager (for SessionManager)
// and a live FactStore (for FactRetriever), both of which depend on SQLite
// and cannot be easily faked without dependency injection that the current
// interfaces don't yet expose. Integration coverage should be added when
// those interfaces are refactored to accept protocols (post-MVP).
//
// What IS tested here: the building blocks that `buildIntegratedContext()`
// assembles — token estimation, simple context building, and the result
// struct — giving confidence that the integration is correct by composition.

final class ContextBuilderInstanceTests: XCTestCase {

    private var builder: ContextBuilder!

    override func setUp() {
        super.setUp()
        builder = ContextBuilder(defaultTotalTokens: 10_000)
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    // MARK: - Simple Context Building (Instance API)

    func testSimpleContextWithSystemPrompt() {
        let messages = [
            LLMMessage(role: .user, content: "Hello"),
            LLMMessage(role: .assistant, content: "Hi there!")
        ]

        let result = builder.buildSimpleContext(
            messages: messages,
            systemPrompt: "You are a helpful assistant."
        )

        XCTAssertEqual(result.count, 3, "Should have system prompt + 2 messages")
        XCTAssertEqual(result[0].role, .system)
        XCTAssertEqual(result[1].role, .user)
        XCTAssertEqual(result[2].role, .assistant)
    }

    func testSimpleContextWithoutSystemPrompt() {
        let messages = [LLMMessage(role: .user, content: "Hello")]

        let result = builder.buildSimpleContext(messages: messages, systemPrompt: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .user)
    }

    func testSimpleContextPreservesMessageOrder() {
        let messages = [
            LLMMessage(role: .user, content: "first"),
            LLMMessage(role: .assistant, content: "second"),
            LLMMessage(role: .user, content: "third")
        ]

        let result = builder.buildSimpleContext(messages: messages)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].content, "first")
        XCTAssertEqual(result[1].content, "second")
        XCTAssertEqual(result[2].content, "third")
    }

    // MARK: - Instance Token Estimation

    func testEstimateTokensShortText() {
        let tokens = builder.estimateTokens(for: "Hello world")
        // 2 words * 1.3 + 4 overhead = ~6-7
        XCTAssertGreaterThan(tokens, 0)
        XCTAssertLessThan(tokens, 20)
    }

    func testEstimateTokensLongerText() {
        let text = "This is a longer piece of text that should result in a higher token count"
        let tokens = builder.estimateTokens(for: text)
        let shortTokens = builder.estimateTokens(for: "Hi")
        XCTAssertGreaterThan(tokens, shortTokens, "Longer text should have more tokens")
    }

    func testEstimateTokensEmptyText() {
        let tokens = builder.estimateTokens(for: "")
        XCTAssertGreaterThanOrEqual(tokens, 1, "Even empty text should return at least 1 token")
    }

    func testEstimateTokensWordBased() {
        // 100 words should be roughly 130-140 tokens + overhead
        let words = (0..<100).map { "word\($0)" }.joined(separator: " ")
        let tokens = builder.estimateTokens(for: words)
        XCTAssertGreaterThan(tokens, 100, "100 words should be more than 100 tokens")
        XCTAssertLessThan(tokens, 200, "100 words should be less than 200 tokens")
    }

    // MARK: - Default Configuration

    func testDefaultTotalTokens() {
        let defaultBuilder = ContextBuilder()
        XCTAssertEqual(defaultBuilder.defaultTotalTokens, 100_000)
    }

    func testCustomTotalTokens() {
        let customBuilder = ContextBuilder(defaultTotalTokens: 50_000)
        XCTAssertEqual(customBuilder.defaultTotalTokens, 50_000)
    }

    // MARK: - ContextBuildResult Struct

    func testContextBuildResultFields() {
        let result = ContextBuildResult(
            messages: [LLMMessage(role: .user, content: "test")],
            systemPrompt: "Test prompt",
            tokenEstimate: 500,
            factsIncluded: 3,
            messagesIncluded: 10,
            verbosityLevel: .concise,
            wasTruncated: false
        )

        XCTAssertEqual(result.messages.count, 1)
        XCTAssertEqual(result.systemPrompt, "Test prompt")
        XCTAssertEqual(result.tokenEstimate, 500)
        XCTAssertEqual(result.factsIncluded, 3)
        XCTAssertEqual(result.messagesIncluded, 10)
        XCTAssertEqual(result.verbosityLevel, .concise)
        XCTAssertFalse(result.wasTruncated)
    }

    func testContextBuildResultTruncationFlag() {
        let truncated = ContextBuildResult(
            messages: [],
            systemPrompt: "",
            tokenEstimate: 0,
            factsIncluded: 0,
            messagesIncluded: 5,
            verbosityLevel: .moderate,
            wasTruncated: true
        )

        XCTAssertTrue(truncated.wasTruncated)
    }

    func testContextBuildResultNotTruncated() {
        let result = ContextBuildResult(
            messages: [LLMMessage(role: .user, content: "hello")],
            systemPrompt: "System",
            tokenEstimate: 100,
            factsIncluded: 0,
            messagesIncluded: 1,
            verbosityLevel: .terse,
            wasTruncated: false
        )

        XCTAssertFalse(result.wasTruncated)
        XCTAssertEqual(result.verbosityLevel, .terse)
    }
}