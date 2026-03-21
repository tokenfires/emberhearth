// TokenCounterTests.swift
// EmberHearthTests
//
// Unit tests for TokenCounter, ContextBudget, TokenEstimates, and budget enforcement.

import XCTest
@testable import EmberHearth

final class TokenCounterTests: XCTestCase {

    // MARK: - Token Estimation: Single Text

    func testEmptyStringReturnsMinimumTokens() {
        let tokens = TokenCounter.estimateTokens(for: "")
        XCTAssertGreaterThanOrEqual(tokens, 1, "Empty string should return at least 1 token")
    }

    func testWhitespaceOnlyReturnsMinimumTokens() {
        let tokens = TokenCounter.estimateTokens(for: "   \n\t  ")
        XCTAssertGreaterThanOrEqual(tokens, 1)
    }

    func testSingleWordEstimate() {
        let tokens = TokenCounter.estimateTokens(for: "Hello")
        XCTAssertGreaterThan(tokens, 0)
        XCTAssertLessThan(tokens, 10, "Single word should be just a few tokens")
    }

    func testShortSentenceEstimate() {
        let tokens = TokenCounter.estimateTokens(for: "Hello, how are you today?")
        // 5 words * ~1.3 = ~7 tokens
        XCTAssertGreaterThan(tokens, 3)
        XCTAssertLessThan(tokens, 20)
    }

    func testLongerTextEstimate() {
        let text = "This is a longer piece of text that contains multiple sentences. It should produce a higher token estimate than the shorter examples. We want to verify that the word-based estimation scales linearly."
        let tokens = TokenCounter.estimateTokens(for: text)
        let shortTokens = TokenCounter.estimateTokens(for: "Short text.")
        XCTAssertGreaterThan(tokens, shortTokens, "Longer text should have more tokens")
    }

    func testHundredWordsEstimate() {
        let words = (0..<100).map { "word\($0)" }.joined(separator: " ")
        let tokens = TokenCounter.estimateTokens(for: words)
        // 100 words * ~1.3 = ~130 tokens
        XCTAssertGreaterThan(tokens, 100)
        XCTAssertLessThan(tokens, 200)
    }

    func testCodeBlockHigherTokenRate() {
        let codeText = "```swift\nlet x = 42\nfunc hello() { print(\"world\") }\n```"
        let proseText = "let x equals forty two func hello print world"
        let codeTokens = TokenCounter.estimateTokens(for: codeText)
        let proseTokens = TokenCounter.estimateTokens(for: proseText)
        // Code should have a higher token count per word
        XCTAssertGreaterThan(codeTokens, 0, "Code blocks should produce tokens")
        XCTAssertGreaterThan(codeTokens, proseTokens, "Code should estimate higher than equivalent prose")
    }

    func testMixedContentEstimate() {
        let text = """
        Here is some regular text.

        ```python
        def hello():
            print("world")
        ```

        And some more regular text after the code.
        """
        let tokens = TokenCounter.estimateTokens(for: text)
        XCTAssertGreaterThan(tokens, 10)
    }

    // MARK: - Token Estimation: Message Array

    func testMessageArrayEstimate() {
        let messages = [
            LLMMessage(role: .user, content: "Hello"),
            LLMMessage(role: .assistant, content: "Hi there! How can I help?"),
            LLMMessage(role: .user, content: "What's the weather?")
        ]

        let tokens = TokenCounter.estimateTokens(for: messages)
        XCTAssertGreaterThan(tokens, 0)
        // Should be more than just the text tokens (includes overhead)
        let textOnlyTokens = messages.reduce(0) { $0 + TokenCounter.estimateTokens(for: $1.content) }
        XCTAssertGreaterThan(tokens, textOnlyTokens, "Message estimate should include overhead")
    }

    func testEmptyMessageArrayEstimate() {
        let tokens = TokenCounter.estimateTokens(for: [LLMMessage]())
        // Should have at least the base overhead
        XCTAssertGreaterThanOrEqual(tokens, 1)
    }

    func testSingleMessageIncludesOverhead() {
        let message = [LLMMessage(role: .user, content: "Hello")]
        let tokens = TokenCounter.estimateTokens(for: message)
        let textTokens = TokenCounter.estimateTokens(for: "Hello")
        XCTAssertGreaterThan(tokens, textTokens, "Message tokens should exceed raw text tokens")
    }

    // MARK: - Budget Checking

    func testFitsWithinBudgetText() {
        XCTAssertTrue(TokenCounter.fitsWithinBudget(text: "Hello", budget: 100))
        XCTAssertFalse(TokenCounter.fitsWithinBudget(text: "Hello", budget: 0))
    }

    func testFitsWithinBudgetMessages() {
        let messages = [LLMMessage(role: .user, content: "Hello")]
        XCTAssertTrue(TokenCounter.fitsWithinBudget(messages: messages, budget: 100))
        XCTAssertFalse(TokenCounter.fitsWithinBudget(messages: messages, budget: 0))
    }

    // MARK: - ContextBudget Tests

    func testDefaultBudgetValues() {
        let budget = ContextBudget.default
        XCTAssertEqual(budget.totalTokens, 100_000)
        XCTAssertEqual(budget.systemPromptPercent, 0.10)
        XCTAssertEqual(budget.recentMessagesPercent, 0.25)
        XCTAssertEqual(budget.summaryPercent, 0.10)
        XCTAssertEqual(budget.factsPercent, 0.15)
        XCTAssertEqual(budget.taskStatePercent, 0.05)
        XCTAssertEqual(budget.responseReservePercent, 0.35)
    }

    func testDefaultBudgetIsValid() {
        XCTAssertTrue(ContextBudget.default.isValid, "Default budget percentages should sum to 1.0")
    }

    func testLocalSmallBudgetIsValid() {
        XCTAssertTrue(ContextBudget.localSmall.isValid, "Local small budget percentages should sum to 1.0")
    }

    func testMediumBudgetIsValid() {
        XCTAssertTrue(ContextBudget.medium.isValid, "Medium budget percentages should sum to 1.0")
    }

    func testBudgetComputedValues() {
        let budget = ContextBudget.default
        XCTAssertEqual(budget.systemPromptBudget, 10_000)
        XCTAssertEqual(budget.recentMessagesBudget, 25_000)
        XCTAssertEqual(budget.summaryBudget, 10_000)
        XCTAssertEqual(budget.factsBudget, 15_000)
        XCTAssertEqual(budget.taskStateBudget, 5_000)
        XCTAssertEqual(budget.responseBudget, 35_000)
    }

    func testBudgetTotalInputBudget() {
        let budget = ContextBudget.default
        XCTAssertEqual(budget.totalInputBudget, 65_000, "Input budget should be total minus response reserve")
    }

    func testCustomBudget() {
        let custom = ContextBudget(
            totalTokens: 50_000,
            systemPromptPercent: 0.15,
            recentMessagesPercent: 0.30,
            summaryPercent: 0.05,
            factsPercent: 0.10,
            taskStatePercent: 0.00,
            responseReservePercent: 0.40
        )
        XCTAssertTrue(custom.isValid)
        XCTAssertEqual(custom.systemPromptBudget, 7_500)
        XCTAssertEqual(custom.recentMessagesBudget, 15_000)
        XCTAssertEqual(custom.responseBudget, 20_000)
    }

    func testConvenienceInitUsesDefaultPercentages() {
        let budget = ContextBudget(totalTokens: 50_000)
        XCTAssertTrue(budget.isValid)
        XCTAssertEqual(budget.totalTokens, 50_000)
        XCTAssertEqual(budget.systemPromptPercent, 0.10)
        XCTAssertEqual(budget.recentMessagesPercent, 0.25)
    }

    func testInvalidBudget() {
        let invalid = ContextBudget(
            totalTokens: 100_000,
            systemPromptPercent: 0.50,
            recentMessagesPercent: 0.50,
            summaryPercent: 0.50,
            factsPercent: 0.50,
            taskStatePercent: 0.50,
            responseReservePercent: 0.50
        )
        XCTAssertFalse(invalid.isValid, "Budget with percentages summing to 3.0 should be invalid")
    }

    // MARK: - TokenEstimates Tests

    func testTokenEstimatesDebugDescription() {
        let estimates = TokenEstimates(
            systemPrompt: 500,
            recentMessages: 2000,
            summary: 300,
            facts: 200,
            budget: .default
        )

        let description = estimates.debugDescription
        XCTAssertTrue(description.contains("500"), "Should contain system prompt usage")
        XCTAssertTrue(description.contains("2000"), "Should contain recent messages usage")
        XCTAssertTrue(description.contains("300"), "Should contain summary usage")
    }

    func testTokenEstimatesTotalInput() {
        let estimates = TokenEstimates(
            systemPrompt: 500,
            recentMessages: 2000,
            summary: 300,
            facts: 200,
            budget: .default
        )
        XCTAssertEqual(estimates.totalInput, 2800, "Total should be system + messages + summary")
    }

    func testTokenEstimatesOverBudget() {
        let estimates = TokenEstimates(
            systemPrompt: 50_000,  // Way over the 10K+15K budget
            recentMessages: 2000,
            summary: 300,
            facts: 200,
            budget: .default
        )
        XCTAssertTrue(estimates.anyOverBudget)
    }

    func testTokenEstimatesWithinBudget() {
        let estimates = TokenEstimates(
            systemPrompt: 5_000,
            recentMessages: 10_000,
            summary: 3_000,
            facts: 2_000,
            budget: .default
        )
        XCTAssertFalse(estimates.anyOverBudget)
    }

    // MARK: - Scaling Tests

    func testTokenEstimationScalesLinearly() {
        let text10 = (0..<10).map { "word\($0)" }.joined(separator: " ")
        let text100 = (0..<100).map { "word\($0)" }.joined(separator: " ")
        let text1000 = (0..<1000).map { "word\($0)" }.joined(separator: " ")

        let tokens10 = TokenCounter.estimateTokens(for: text10)
        let tokens100 = TokenCounter.estimateTokens(for: text100)
        let tokens1000 = TokenCounter.estimateTokens(for: text1000)

        // Should scale roughly linearly (within 2x tolerance for rounding)
        let ratio100to10 = Double(tokens100) / Double(tokens10)
        let ratio1000to100 = Double(tokens1000) / Double(tokens100)

        XCTAssertGreaterThan(ratio100to10, 5.0, "100 words should be at least 5x more tokens than 10 words")
        XCTAssertLessThan(ratio100to10, 15.0, "100 words should be at most 15x more tokens than 10 words")
        XCTAssertGreaterThan(ratio1000to100, 5.0, "Scaling should be approximately linear")
        XCTAssertLessThan(ratio1000to100, 15.0, "Scaling should be approximately linear")
    }

    // MARK: - Edge Cases

    func testVeryLongTextDoesNotCrash() {
        let longText = String(repeating: "This is a very long sentence with many words. ", count: 10_000)
        let tokens = TokenCounter.estimateTokens(for: longText)
        XCTAssertGreaterThan(tokens, 50_000, "Very long text should have many tokens")
    }

    func testUnicodeTextEstimate() {
        let unicodeText = "Hello 你好 こんにちは مرحبا 🌍🌎🌏"
        let tokens = TokenCounter.estimateTokens(for: unicodeText)
        XCTAssertGreaterThan(tokens, 0, "Unicode text should produce tokens")
    }

    func testOnlyEmojiEstimate() {
        let emojis = "😀😃😄😁😆😅🤣😂"
        let tokens = TokenCounter.estimateTokens(for: emojis)
        // Emojis are single "words" when split by whitespace, so this will be low
        // But should still produce at least 1 token
        XCTAssertGreaterThanOrEqual(tokens, 1)
    }

    // MARK: - ContextBudget Equatable

    func testContextBudgetEquatable() {
        let a = ContextBudget.default
        let b = ContextBudget.default
        XCTAssertEqual(a, b)
    }

    func testContextBudgetNotEqual() {
        XCTAssertNotEqual(ContextBudget.default, ContextBudget.localSmall)
        XCTAssertNotEqual(ContextBudget.default, ContextBudget.medium)
    }

    // MARK: - TokenEstimates Equatable

    func testTokenEstimatesEquatable() {
        let a = TokenEstimates(systemPrompt: 100, recentMessages: 200, summary: 50, facts: 30, budget: .default)
        let b = TokenEstimates(systemPrompt: 100, recentMessages: 200, summary: 50, facts: 30, budget: .default)
        XCTAssertEqual(a, b)
    }

    func testTokenEstimatesNotEqual() {
        let a = TokenEstimates(systemPrompt: 100, recentMessages: 200, summary: 50, facts: 30, budget: .default)
        let b = TokenEstimates(systemPrompt: 999, recentMessages: 200, summary: 50, facts: 30, budget: .default)
        XCTAssertNotEqual(a, b)
    }
}
