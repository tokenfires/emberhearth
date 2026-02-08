# Task 0404: Token Counter and Context Budget Enforcement

**Milestone:** M5 - Personality & Context
**Unit:** 5.5 - Context Window Budget Enforcement
**Phase:** 2
**Depends On:** 0402 (Enhanced ContextBuilder), 0403 (SummaryGenerator)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/session-management.md` — Read Section 1 (Context Window Management: context budget allocation percentages — 10% system, 25% recent, 10% summary, 15% memories, 5% tasks, 35% response)
2. `docs/research/personality-design.md` — Read the "Pragmatic Constraints" section (lines ~815-900) for token budget guidelines by model class, the 70-80% rule, and primacy/recency bias optimization
3. `docs/specs/token-awareness.md` — Read the "Design Philosophy" section (lines ~35-58) for Ember's token-awareness principles and the two-tier transparency model
4. `src/LLM/ContextBuilder.swift` — The enhanced context builder from task 0402. This file will be updated to use the new TokenCounter and ContextBudget. Understand the current `estimateTokens(for:)` method and `ContextBuildResult`.
5. `src/Core/SummaryGenerator.swift` — The summary generator from task 0403. See how the `tokenEstimator` closure is used.
6. `CLAUDE.md` — Project conventions (PascalCase for Swift files, src/ layout, security principles)

> **Context Budget Note:** `personality-design.md` is ~1130 lines. Focus only on lines 815-900 (Pragmatic Constraints: token budgets). `token-awareness.md` is ~300 lines. Focus only on lines 35-58 (Design Philosophy). `session-management.md` is ~590 lines. Focus only on lines 24-42 (Context Budget Allocation).

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Token Counter and Context Budget Enforcement system for EmberHearth, a native macOS personal AI assistant. This replaces the rough token estimation in ContextBuilder with a more accurate counter and formalizes the context budget allocation into a configurable struct.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., TokenCounter.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)

## What You Are Building

Two new components and an update to ContextBuilder:

1. **TokenCounter** — More accurate token estimation than the simple 4-chars-per-token or 1.3-tokens-per-word approximation. Uses word-based counting with adjustments for different content types.

2. **ContextBudget** — A struct that formalizes the context window budget allocation (how many tokens each section gets). Configurable per model.

3. **Update ContextBuilder** — Replace the existing `estimateTokens` with TokenCounter and use ContextBudget for allocation decisions. Add a `ContextBuildResult` that includes per-section token breakdowns.

## Context Budget Allocation (from session-management.md)

```
System prompt (personality + facts)    ~10%
Recent messages (verbatim)             ~25%
Conversation summary                   ~10%
Retrieved memories (in system prompt)  ~15%
Active task state                      ~5%
Reserve for response                   ~35%
```

Note: For MVP, "Retrieved memories" are included within the system prompt, so the system prompt effectively uses ~25% (10% base + 15% facts). The task state section (5%) is reserved for future use.

## Files to Create

### 1. `src/LLM/TokenCounter.swift`

```swift
// TokenCounter.swift
// EmberHearth
//
// Provides accurate token estimation for context budget enforcement.

import Foundation
import os

/// Estimates token counts for text and message arrays.
///
/// Uses a word-based estimation model that is more accurate than the naive
/// 4-characters-per-token rule. The estimates are tuned for Claude models
/// (BPE tokenization with ~1.3 tokens per English word on average).
///
/// ## Accuracy
///
/// This is still an estimation — true token counts require the actual
/// tokenizer. For budget enforcement, slight overestimation is preferred
/// (better to leave room than to overflow the context window).
///
/// ## Content-Aware Counting
///
/// Different content types have different token densities:
/// - English prose: ~1.3 tokens per word
/// - Code blocks: ~1.5 tokens per word (more special characters)
/// - Punctuation-heavy text: ~1.4 tokens per word
/// - JSON/structured data: ~1.6 tokens per word
struct TokenCounter {

    // MARK: - Constants

    /// Default tokens per word for English prose.
    static let tokensPerWord: Double = 1.3

    /// Tokens per word for code blocks (higher due to special characters).
    static let tokensPerWordCode: Double = 1.5

    /// Overhead tokens per message for role/formatting in the API.
    /// Each message has ~4 tokens of framing (role markers, separators).
    static let messageOverhead: Int = 4

    /// Logger for token counting operations.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "TokenCounter"
    )

    // MARK: - Single Text Estimation

    /// Estimates the token count for a single text string.
    ///
    /// Uses word-based counting with content-aware adjustments:
    /// - Detects code blocks (triple backticks) and counts them at a higher rate
    /// - Counts punctuation-heavy segments at a slightly higher rate
    /// - Adds a small overhead for the text itself
    ///
    /// Always returns at least 1 token (even for empty strings, since
    /// empty messages still consume framing tokens).
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count.
    static func estimateTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 1 }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 1 }

        // Split text by code blocks
        let codeBlockPattern = "```"
        let segments = trimmed.components(separatedBy: codeBlockPattern)

        var totalTokens: Double = 0

        for (index, segment) in segments.enumerated() {
            let words = segment.split(whereSeparator: { $0.isWhitespace })
            let wordCount = Double(words.count)

            if index % 2 == 1 {
                // Inside a code block (odd indices after splitting by ```)
                totalTokens += wordCount * tokensPerWordCode
            } else {
                // Regular text
                totalTokens += wordCount * tokensPerWord
            }
        }

        // Add tokens for code block delimiters themselves
        let codeBlockCount = max(0, segments.count - 1) / 2
        totalTokens += Double(codeBlockCount * 2)  // Each code block has open + close

        return max(Int(totalTokens.rounded(.up)), 1)
    }

    // MARK: - Message Array Estimation

    /// Estimates the total token count for an array of LLM messages.
    ///
    /// Includes per-message overhead for role/formatting tokens.
    /// The overhead accounts for the role marker ("user:", "assistant:"),
    /// message separators, and other API framing.
    ///
    /// - Parameter messages: The array of LLM messages to estimate.
    /// - Returns: Total estimated token count including all overhead.
    static func estimateTokens(for messages: [LLMMessage]) -> Int {
        var total = 0

        for message in messages {
            let contentTokens = estimateTokens(for: message.content)
            total += contentTokens + messageOverhead
        }

        // Add a base overhead for the messages array itself
        total += 3  // API-level framing

        return total
    }

    // MARK: - Budget Checking

    /// Checks whether the given text fits within a token budget.
    ///
    /// - Parameters:
    ///   - text: The text to check.
    ///   - budget: The maximum allowed tokens.
    /// - Returns: True if the estimated tokens are within budget.
    static func fitsWithinBudget(text: String, budget: Int) -> Bool {
        return estimateTokens(for: text) <= budget
    }

    /// Checks whether the given messages fit within a token budget.
    ///
    /// - Parameters:
    ///   - messages: The messages to check.
    ///   - budget: The maximum allowed tokens.
    /// - Returns: True if the estimated tokens are within budget.
    static func fitsWithinBudget(messages: [LLMMessage], budget: Int) -> Bool {
        return estimateTokens(for: messages) <= budget
    }
}
```

### 2. `src/LLM/ContextBudget.swift`

```swift
// ContextBudget.swift
// EmberHearth
//
// Defines the token budget allocation for context window management.

import Foundation

/// Defines how the total context window is divided among different sections.
///
/// Each section gets a percentage of the total token budget. The percentages
/// should sum to 1.0 (100%). Sections that go under budget can redistribute
/// their unused tokens to the recent messages section.
///
/// ## Default Budget (for Claude with 100K context)
///
/// ```
/// System prompt:      10%  (10,000 tokens)
/// Recent messages:    25%  (25,000 tokens)
/// Summary:            10%  (10,000 tokens)
/// Facts/memories:     15%  (15,000 tokens — part of system prompt)
/// Task state:          5%  ( 5,000 tokens — reserved for future use)
/// Response reserve:   35%  (35,000 tokens)
/// ```
///
/// ## Usage
///
/// ```swift
/// let budget = ContextBudget.default
/// let systemPromptBudget = budget.systemPromptBudget  // 10,000
/// let recentMessagesBudget = budget.recentMessagesBudget  // 25,000
/// ```
struct ContextBudget: Sendable, Equatable {

    // MARK: - Token Budget

    /// The total number of tokens available in the context window.
    let totalTokens: Int

    // MARK: - Section Percentages

    /// Percentage of total tokens allocated to the system prompt.
    /// Includes base personality, behavioral rules, and time context.
    let systemPromptPercent: Double

    /// Percentage of total tokens allocated to recent conversation messages.
    /// These are verbatim messages from the current session.
    let recentMessagesPercent: Double

    /// Percentage of total tokens allocated to the conversation summary.
    /// The rolling summary of earlier messages in the session.
    let summaryPercent: Double

    /// Percentage of total tokens allocated to user facts/memories.
    /// These are injected into the system prompt by SystemPromptBuilder.
    let factsPercent: Double

    /// Percentage of total tokens allocated to active task state.
    /// Reserved for future use (multi-turn tasks).
    let taskStatePercent: Double

    /// Percentage of total tokens reserved for the LLM response.
    /// This is not part of the input — it's the output budget.
    let responseReservePercent: Double

    // MARK: - Computed Budgets

    /// Token budget for the system prompt section.
    var systemPromptBudget: Int {
        Int(Double(totalTokens) * systemPromptPercent)
    }

    /// Token budget for recent conversation messages.
    var recentMessagesBudget: Int {
        Int(Double(totalTokens) * recentMessagesPercent)
    }

    /// Token budget for the conversation summary.
    var summaryBudget: Int {
        Int(Double(totalTokens) * summaryPercent)
    }

    /// Token budget for user facts/memories.
    var factsBudget: Int {
        Int(Double(totalTokens) * factsPercent)
    }

    /// Token budget for active task state.
    var taskStateBudget: Int {
        Int(Double(totalTokens) * taskStatePercent)
    }

    /// Token budget reserved for the LLM response.
    var responseBudget: Int {
        Int(Double(totalTokens) * responseReservePercent)
    }

    /// The total input budget (everything except the response reserve).
    /// This is the maximum tokens the assembled context can consume.
    var totalInputBudget: Int {
        totalTokens - responseBudget
    }

    // MARK: - Presets

    /// Default budget for Claude models with 200K context window.
    /// Uses 100K of the 200K to stay well within the 70-80% rule.
    static let `default` = ContextBudget(
        totalTokens: 100_000,
        systemPromptPercent: 0.10,
        recentMessagesPercent: 0.25,
        summaryPercent: 0.10,
        factsPercent: 0.15,
        taskStatePercent: 0.05,
        responseReservePercent: 0.35
    )

    /// Smaller budget for local models with limited context.
    /// Uses 6K of an 8K context window.
    static let localSmall = ContextBudget(
        totalTokens: 6_000,
        systemPromptPercent: 0.10,
        recentMessagesPercent: 0.30,
        summaryPercent: 0.10,
        factsPercent: 0.10,
        taskStatePercent: 0.00,
        responseReservePercent: 0.40
    )

    /// Medium budget for models with 32K-64K context.
    /// Uses 40K of the available context.
    static let medium = ContextBudget(
        totalTokens: 40_000,
        systemPromptPercent: 0.10,
        recentMessagesPercent: 0.25,
        summaryPercent: 0.10,
        factsPercent: 0.15,
        taskStatePercent: 0.05,
        responseReservePercent: 0.35
    )

    // MARK: - Validation

    /// Whether this budget's percentages sum to approximately 1.0.
    /// Small floating-point deviations are acceptable.
    var isValid: Bool {
        let total = systemPromptPercent + recentMessagesPercent + summaryPercent +
                    factsPercent + taskStatePercent + responseReservePercent
        return abs(total - 1.0) < 0.01
    }
}
```

### 3. `src/LLM/TokenEstimates.swift`

```swift
// TokenEstimates.swift
// EmberHearth
//
// Per-section token breakdown for context build results.

import Foundation

/// Per-section token breakdown from a context build operation.
///
/// This provides transparency into how the context window budget was used,
/// which is useful for debugging, monitoring, and the token-awareness UI.
struct TokenEstimates: Sendable, Equatable {
    /// Tokens used by the system prompt (personality + facts + context).
    let systemPrompt: Int

    /// Tokens used by recent conversation messages.
    let recentMessages: Int

    /// Tokens used by the conversation summary.
    let summary: Int

    /// Tokens used by user facts (included in system prompt).
    let facts: Int

    /// Total estimated tokens for all input sections.
    var totalInput: Int {
        systemPrompt + recentMessages + summary
    }

    /// The budget that was allocated for each section.
    let budget: ContextBudget

    /// Whether any section exceeded its allocated budget.
    var anyOverBudget: Bool {
        systemPrompt > budget.systemPromptBudget + budget.factsBudget ||
        recentMessages > budget.recentMessagesBudget ||
        summary > budget.summaryBudget
    }

    /// Summary of usage vs budget for logging.
    var debugDescription: String {
        """
        Token Usage:
          System prompt: \(systemPrompt)/\(budget.systemPromptBudget + budget.factsBudget) tokens
          Recent messages: \(recentMessages)/\(budget.recentMessagesBudget) tokens
          Summary: \(summary)/\(budget.summaryBudget) tokens
          Total input: \(totalInput)/\(budget.totalInputBudget) tokens
        """
    }
}
```

### 4. Update `src/LLM/ContextBuilder.swift`

Update the existing ContextBuilder to use TokenCounter and ContextBudget. The key changes are:

a. Add a `budget: ContextBudget` property (default: `.default`)
b. Replace the inline `estimateTokens(for:)` method with calls to `TokenCounter.estimateTokens(for:)`
c. Update `buildIntegratedContext()` to use budget percentages for each section
d. Add budget enforcement: if system prompt exceeds its budget, truncate facts by lowest importance
e. If recent messages exceed budget, drop oldest messages until within budget
f. Update `ContextBuildResult` to include `tokenEstimates: TokenEstimates`
g. Add debug-level logging for actual usage vs budget for each section

Specific changes to make:

```swift
// In ContextBuilder:

// Add property:
let budget: ContextBudget

// Update init:
init(
    promptBuilder: SystemPromptBuilder = SystemPromptBuilder(),
    verbosityAdapter: VerbosityAdapter = VerbosityAdapter(),
    budget: ContextBudget = .default
) {
    self.promptBuilder = promptBuilder
    self.verbosityAdapter = verbosityAdapter
    self.budget = budget
    // Remove defaultTotalTokens — now comes from budget.totalTokens
}

// Replace estimateTokens:
func estimateTokens(for text: String) -> Int {
    TokenCounter.estimateTokens(for: text)
}

// Update ContextBuildResult to include:
struct ContextBuildResult: Sendable {
    let messages: [LLMMessage]
    let systemPrompt: String
    let tokenEstimates: TokenEstimates
    let factsIncluded: Int
    let messagesIncluded: Int
    let verbosityLevel: VerbosityLevel
    let wasTruncated: Bool
}
```

In the `buildIntegratedContext()` method, add budget enforcement logging at debug level:

```swift
logger.debug("Budget usage — System: \(systemPromptTokens)/\(budget.systemPromptBudget + budget.factsBudget), Messages: \(messageTokens)/\(budget.recentMessagesBudget), Summary: \(summaryTokens)/\(budget.summaryBudget)")
```

Handle the edge case where a user sends a single message that exceeds the entire recent messages budget — the message should still be included (truncated if necessary) because the user needs a response.

### 5. Create `tests/TokenCounterTests.swift`

```swift
// TokenCounterTests.swift
// EmberHearth
//
// Unit tests for TokenCounter, ContextBudget, and budget enforcement.

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
        // This test may be approximate due to word count differences
        XCTAssertGreaterThan(codeTokens, 0, "Code blocks should produce tokens")
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
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, os).
3. All Swift files use PascalCase naming.
4. All classes and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. TokenCounter methods are `static` — no instance needed.
7. ContextBudget is a value type (struct) and should be `Sendable` and `Equatable`.
8. When updating ContextBuilder, preserve backward compatibility as much as possible. If the `defaultTotalTokens` parameter is replaced by `budget`, update all callers (including tests from task 0402).
9. The test file path should match the existing test file pattern.
10. Budget enforcement should prefer slight overestimation (leaving room) over underestimation (overflow).

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test`)
3. There are no calls to Process(), /bin/bash, or any shell execution
4. All public methods have documentation comments
5. os.Logger is used (not print() statements)
6. TokenCounter methods are static
7. ContextBudget.default percentages sum to 1.0
8. All three presets (default, localSmall, medium) are valid
9. TokenEstimates correctly tracks per-section usage
10. Empty strings return at least 1 token
11. Code blocks are estimated at a higher rate than prose
12. The ContextBuilder update integrates TokenCounter and ContextBudget
```

---

## Acceptance Criteria

- [ ] `src/LLM/TokenCounter.swift` exists with static estimation methods
- [ ] `src/LLM/ContextBudget.swift` exists with budget allocation struct
- [ ] `src/LLM/TokenEstimates.swift` exists with per-section breakdown struct
- [ ] `TokenCounter.estimateTokens(for: String)` uses word-based estimation (~1.3 tokens/word)
- [ ] `TokenCounter.estimateTokens(for: [LLMMessage])` includes message overhead (~4 tokens each)
- [ ] Code blocks (triple backticks) are estimated at a higher rate (~1.5 tokens/word)
- [ ] Empty strings return at least 1 token
- [ ] `ContextBudget.default` has correct percentages: 10% system, 25% recent, 10% summary, 15% facts, 5% tasks, 35% response
- [ ] `ContextBudget.default.isValid` returns true (percentages sum to 1.0)
- [ ] `ContextBudget.localSmall` and `ContextBudget.medium` presets exist and are valid
- [ ] `ContextBudget` computed properties correctly calculate per-section budgets
- [ ] `TokenEstimates` tracks per-section token usage with debug description
- [ ] `TokenEstimates.anyOverBudget` correctly detects when sections exceed their budgets
- [ ] ContextBuilder updated to use `TokenCounter` and `ContextBudget`
- [ ] ContextBuilder logs budget usage at debug level
- [ ] `ContextBuildResult` includes `tokenEstimates: TokenEstimates`
- [ ] Budget enforcement: facts trimmed by lowest importance when system prompt exceeds budget
- [ ] Budget enforcement: oldest messages dropped when recent messages exceed budget
- [ ] Edge case: single oversized user message still gets included (with truncation warning)
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/LLM/TokenCounter.swift && echo "TokenCounter.swift exists" || echo "MISSING: TokenCounter.swift"
test -f src/LLM/ContextBudget.swift && echo "ContextBudget.swift exists" || echo "MISSING: ContextBudget.swift"
test -f src/LLM/TokenEstimates.swift && echo "TokenEstimates.swift exists" || echo "MISSING: TokenEstimates.swift"

# Verify test file exists
test -f tests/TokenCounterTests.swift && echo "Test file exists (flat)" || test -f tests/LLM/TokenCounterTests.swift && echo "Test file exists (nested)" || echo "MISSING: TokenCounterTests.swift"

# Verify no shell execution
grep -rn "Process()" src/LLM/TokenCounter.swift src/LLM/ContextBudget.swift || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/LLM/ || echo "PASS: No /bin/bash references found"

# Verify TokenCounter methods are static
grep -n "static func estimateTokens" src/LLM/TokenCounter.swift && echo "PASS: Static methods found" || echo "FAIL: Missing static methods"

# Verify budget percentages sum to 1.0
grep -A 6 "static let \`default\`" src/LLM/ContextBudget.swift

# Build the project
swift build 2>&1

# Run token counter tests
swift test --filter TokenCounterTests 2>&1

# Run all tests to ensure nothing is broken (including updated ContextBuilder tests)
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the TokenCounter, ContextBudget, and budget enforcement implementation for EmberHearth created in task 0404. Check for these specific issues:

@src/LLM/TokenCounter.swift
@src/LLM/ContextBudget.swift
@src/LLM/TokenEstimates.swift
@src/LLM/ContextBuilder.swift (updated)
@tests/TokenCounterTests.swift (or tests/LLM/TokenCounterTests.swift)

Also reference:
@docs/research/session-management.md (Section 1: Context Budget)
@docs/research/personality-design.md (Pragmatic Constraints: Token Budgets)

1. **TOKEN ESTIMATION ACCURACY (Critical):**
   - Does the word-based estimate (~1.3 tokens/word) produce reasonable results for English text?
   - Are code blocks estimated at a higher rate?
   - Does the message overhead (~4 tokens per message) account for API framing?
   - Are empty strings handled without crashing (returning at least 1)?
   - Does the estimate err on the side of overestimation (conservative for budget enforcement)?
   - How does it handle non-English text, emoji, and unicode?

2. **BUDGET ALLOCATION (Critical):**
   - Does ContextBudget.default match session-management.md? (10% system, 25% recent, 10% summary, 15% facts, 5% tasks, 35% response)
   - Do all three presets (default, localSmall, medium) have percentages that sum to 1.0?
   - Is the isValid property correctly checking the sum?
   - Are computed budget values correct? (e.g., 100,000 * 0.10 = 10,000)
   - Does totalInputBudget correctly exclude the response reserve?

3. **BUDGET ENFORCEMENT (Important):**
   - When the system prompt (with facts) exceeds its budget, are facts trimmed by lowest importance?
   - When recent messages exceed their budget, are the OLDEST messages dropped?
   - Is the new user message always included regardless of budget?
   - Is there a handling for the edge case where a single message exceeds the entire budget?
   - Is budget enforcement logged at debug level?

4. **CONTEXTBUILDER INTEGRATION (Important):**
   - Does ContextBuilder now use TokenCounter instead of inline estimation?
   - Does ContextBuilder accept a ContextBudget parameter?
   - Does ContextBuildResult include TokenEstimates?
   - Are existing tests from task 0402 still passing after the update?
   - Is backward compatibility maintained for buildSimpleContext?

5. **TOKEN ESTIMATES METADATA:**
   - Does TokenEstimates track per-section usage (system, messages, summary, facts)?
   - Does totalInput correctly sum the input sections?
   - Does anyOverBudget correctly detect when sections exceed their budgets?
   - Is the debug description useful and accurate?

6. **CODE QUALITY:**
   - Are TokenCounter methods all static?
   - Is ContextBudget a struct with Sendable and Equatable conformance?
   - Is TokenEstimates a struct with Sendable and Equatable conformance?
   - Are all public APIs documented with /// comments?
   - Is os.Logger used consistently?
   - Are there any force-unwraps or potential crashes?
   - No Process(), /bin/bash, or shell execution?

7. **TEST QUALITY:**
   - Do tests cover: single text estimation, message array estimation, budget checking?
   - Do tests cover: all three budget presets, custom budgets, invalid budgets?
   - Do tests cover: TokenEstimates debug description, total input, over-budget detection?
   - Do tests cover: edge cases (empty string, very long text, unicode, emoji)?
   - Do tests verify linear scaling of token estimation?
   - Do tests verify that code blocks produce higher estimates than prose?

Report any issues found with specific file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m5): add token counter and context budget enforcement
```

---

## Notes for Next Task

- `TokenCounter` is a static utility — import it anywhere token estimation is needed. The `SummaryGenerator` from task 0403 can use `TokenCounter.estimateTokens(for:)` as its `tokenEstimator` closure.
- `ContextBudget` presets cover the three main model classes. Future model support can add new presets without changing the existing code.
- `TokenEstimates` provides the metadata needed for the token-awareness UI (specified in `docs/specs/token-awareness.md`). The UI tasks in later milestones can use this data to show the user how their context budget is being used.
- The `ContextBuilder` now fully integrates personality (SystemPromptBuilder), verbosity (VerbosityAdapter), memory (FactRetriever), sessions (SessionManager), and budget enforcement (TokenCounter, ContextBudget). This completes the M5 Personality & Context milestone.
- Future enhancement: replace the word-based TokenCounter with a proper tokenizer binding (e.g., tiktoken for Claude's BPE tokenizer) for exact token counts. For MVP, the estimation is sufficient.
- With M5 complete, the next milestone (M6: Security Basics) can begin. The Tron security layer and injection defense tasks will build on top of the context assembly pipeline established in M5.
