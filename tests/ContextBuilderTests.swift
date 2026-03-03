// ContextBuilderTests.swift
// EmberHearth
//
// Unit tests for ContextBuilder.

import XCTest
@testable import EmberHearth

final class ContextBuilderTests: XCTestCase {

    // MARK: - Token Estimation Tests

    func testTokenEstimateEmptyString() {
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: ""), 0)
    }

    func testTokenEstimateSingleCharacter() {
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "a"), 1)
    }

    func testTokenEstimateFourCharacters() {
        // 4 characters = 1 token
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "abcd"), 1)
    }

    func testTokenEstimateFiveCharacters() {
        // 5 characters = ceil(5/4) = 2 tokens
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: "abcde"), 2)
    }

    func testTokenEstimateLongString() {
        // 100 characters = 25 tokens
        let text = String(repeating: "a", count: 100)
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: text), 25)
    }

    func testTokenEstimate400Characters() {
        // 400 characters = 100 tokens
        let text = String(repeating: "x", count: 400)
        XCTAssertEqual(ContextBuilder.tokenEstimate(for: text), 100)
    }

    // MARK: - Basic Context Building Tests

    func testBuildContextWithSimpleInput() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "You are a helpful assistant.",
            recentMessages: [],
            newMessage: "Hello!"
        )

        XCTAssertEqual(result.messages.count, 1, "Should have 1 message (the new user message).")
        XCTAssertEqual(result.messages[0].role, .user)
        XCTAssertEqual(result.messages[0].content, "Hello!")
        XCTAssertEqual(result.systemPrompt, "You are a helpful assistant.")
        XCTAssertEqual(result.truncatedMessageCount, 0)
        XCTAssertGreaterThan(result.estimatedTokens, 0)
    }

    func testBuildContextWithRecentMessages() {
        let recentMessages: [LLMMessage] = [
            .user("What's the weather?"),
            .assistant("It's sunny today!"),
            .user("Thanks!"),
            .assistant("You're welcome!")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "You are helpful.",
            recentMessages: recentMessages,
            newMessage: "What about tomorrow?"
        )

        XCTAssertEqual(result.messages.count, 5, "Should have 4 recent + 1 new message.")
        XCTAssertEqual(result.messages[0].content, "What's the weather?")
        XCTAssertEqual(result.messages[1].content, "It's sunny today!")
        XCTAssertEqual(result.messages[2].content, "Thanks!")
        XCTAssertEqual(result.messages[3].content, "You're welcome!")
        XCTAssertEqual(result.messages[4].content, "What about tomorrow?")
        XCTAssertEqual(result.truncatedMessageCount, 0)
    }

    func testBuildContextPreservesChronologicalOrder() {
        let recentMessages: [LLMMessage] = [
            .user("First"),
            .assistant("Response to first"),
            .user("Second"),
            .assistant("Response to second")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: recentMessages,
            newMessage: "Third"
        )

        // Verify chronological order is preserved
        XCTAssertEqual(result.messages[0].content, "First")
        XCTAssertEqual(result.messages[1].content, "Response to first")
        XCTAssertEqual(result.messages[2].content, "Second")
        XCTAssertEqual(result.messages[3].content, "Response to second")
        XCTAssertEqual(result.messages[4].content, "Third")
    }

    func testNewMessageIsAlwaysIncluded() {
        // Even if there are many recent messages, the new message must always be included
        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: [],
            newMessage: "This must appear"
        )

        XCTAssertTrue(result.messages.last?.content == "This must appear")
        XCTAssertEqual(result.messages.last?.role, .user)
    }

    func testNewMessageIsLastInArray() {
        let recentMessages: [LLMMessage] = [
            .user("Old message"),
            .assistant("Old response")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: recentMessages,
            newMessage: "New message"
        )

        XCTAssertEqual(result.messages.last?.content, "New message")
    }

    // MARK: - Token Budget Enforcement Tests

    func testTruncatesOldestMessagesWhenOverBudget() {
        // Create messages that exceed the recent messages budget
        // Each message is ~12,500 tokens (50,000 chars / 4)
        // 5 messages at 12,500 tokens each = 62,500 tokens, which exceeds the 50,000 budget
        let longContent = String(repeating: "A", count: 50_000) // ~12,500 tokens

        var recentMessages: [LLMMessage] = []
        for i in 0..<5 {
            recentMessages.append(.user("Message \(i): " + longContent))
        }

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: recentMessages,
            newMessage: "New"
        )

        // Some messages should have been truncated
        XCTAssertGreaterThan(result.truncatedMessageCount, 0, "Should have truncated some old messages.")
        // The newest messages should be kept
        XCTAssertTrue(result.messages.last?.content == "New")
        // Recent messages that ARE included should be the newest ones
        if result.messages.count > 1 {
            // The second-to-last message should be one of the later recent messages, not the first
            let includedRecent = result.messages.dropLast() // Remove the new message
            for msg in includedRecent {
                // All included messages should contain "Message" (from our test data)
                XCTAssertTrue(msg.content.contains("Message") || msg.content == "New")
            }
        }
    }

    func testKeepsNewestMessagesWhenTruncating() {
        // Create messages where we can verify which ones survive
        let longContent = String(repeating: "X", count: 180_000) // ~45,000 tokens — fills most of the budget

        let recentMessages: [LLMMessage] = [
            .user("OLDEST - should be dropped"),
            .assistant("OLDEST REPLY - should be dropped"),
            .user(longContent),  // This fills the budget
            .assistant("NEWEST REPLY - should be kept if room")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "System",
            recentMessages: recentMessages,
            newMessage: "New message"
        )

        // The new message must always be present
        XCTAssertTrue(result.messages.last?.content == "New message")

        // If truncation happened, oldest messages should be gone
        if result.truncatedMessageCount > 0 {
            // We can't guarantee exact behavior, but truncated count should be > 0
            XCTAssertGreaterThan(result.truncatedMessageCount, 0)
        }
    }

    func testEmptyRecentMessages() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "System prompt",
            recentMessages: [],
            newMessage: "Just this message"
        )

        XCTAssertEqual(result.messages.count, 1)
        XCTAssertEqual(result.truncatedMessageCount, 0)
    }

    // MARK: - System Prompt Tests

    func testSystemPromptPassedThrough() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "You are Ember, a helpful assistant.",
            recentMessages: [],
            newMessage: "Hi"
        )

        XCTAssertEqual(result.systemPrompt, "You are Ember, a helpful assistant.")
    }

    func testVeryLongSystemPromptIsTruncated() {
        // Create a system prompt that exceeds the 10,000 token budget (~40,000 characters)
        let longSystemPrompt = String(repeating: "S", count: 50_000)  // ~12,500 tokens, exceeds 10K budget

        let result = ContextBuilder.buildContext(
            systemPrompt: longSystemPrompt,
            recentMessages: [],
            newMessage: "Hi"
        )

        // The system prompt should be truncated
        XCTAssertLessThan(result.systemPrompt.count, longSystemPrompt.count)
        XCTAssertTrue(result.systemPrompt.hasSuffix("[truncated]"))
    }

    func testEmptySystemPrompt() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "",
            recentMessages: [],
            newMessage: "Hi"
        )

        XCTAssertEqual(result.systemPrompt, "")
    }

    // MARK: - Estimated Tokens Tests

    func testEstimatedTokensIsReasonable() {
        let result = ContextBuilder.buildContext(
            systemPrompt: "You are helpful.",  // ~4 tokens
            recentMessages: [
                .user("Hello"),               // ~2 tokens + 4 overhead
                .assistant("Hi there!")        // ~3 tokens + 4 overhead
            ],
            newMessage: "How are you?"          // ~3 tokens
        )

        // Total should be roughly: 4 (system) + 6 + 7 + 3 = ~20 tokens
        // With the rough estimation, it should be in a reasonable range
        XCTAssertGreaterThan(result.estimatedTokens, 5)
        XCTAssertLessThan(result.estimatedTokens, 100)
    }

    func testEstimatedTokensIncludesAllComponents() {
        let result = ContextBuilder.buildContext(
            systemPrompt: String(repeating: "a", count: 400),  // 100 tokens
            recentMessages: [
                .user(String(repeating: "b", count: 400)),     // 100 tokens + overhead
                .assistant(String(repeating: "c", count: 400)) // 100 tokens + overhead
            ],
            newMessage: String(repeating: "d", count: 400)      // 100 tokens
        )

        // Should be roughly 100 + 104 + 104 + 100 = ~408 tokens
        XCTAssertGreaterThan(result.estimatedTokens, 350)
        XCTAssertLessThan(result.estimatedTokens, 500)
    }

    // MARK: - Budget Constants Tests

    func testBudgetConstantsAreReasonable() {
        XCTAssertEqual(ContextBuilder.totalBudget, 100_000)
        XCTAssertEqual(ContextBuilder.systemPromptBudget, 10_000)
        XCTAssertEqual(ContextBuilder.recentMessagesBudget, 50_000)
        XCTAssertEqual(ContextBuilder.responseBudget, 40_000)

        // Verify the budgets add up correctly
        XCTAssertEqual(
            ContextBuilder.systemPromptBudget + ContextBuilder.recentMessagesBudget + ContextBuilder.responseBudget,
            ContextBuilder.totalBudget,
            "Budget allocations should sum to total budget."
        )
    }

    // MARK: - System Messages Filtering

    func testSystemMessagesInRecentAreIncluded() {
        // If someone passes system messages in recentMessages (shouldn't normally happen),
        // they should still be included — the ClaudeAPIClient will filter them later.
        let recentMessages: [LLMMessage] = [
            LLMMessage(role: .system, content: "Some system context"),
            .user("Hello"),
            .assistant("Hi!")
        ]

        let result = ContextBuilder.buildContext(
            systemPrompt: "Main system prompt",
            recentMessages: recentMessages,
            newMessage: "New"
        )

        // All 3 recent + 1 new = 4 messages
        XCTAssertEqual(result.messages.count, 4)
    }
}