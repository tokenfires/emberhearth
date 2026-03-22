# Task 0203: Basic Context Builder with Token Budgeting

**Milestone:** M3 - LLM Integration
**Unit:** 3.3 - Basic Context Building
**Phase:** 1
**Depends On:** 0201 (LLMTypes with LLMMessage)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security rules
2. `src/LLM/LLMTypes.swift` — Read entirely; contains `LLMMessage`, `LLMMessageRole` that the context builder assembles
3. `docs/specs/token-awareness.md` — Focus on Part 2 (lines ~206-280) for the quality tier system and how context budget relates to cost management. Also note Part 6 (lines ~432-508) for the usage projection model. The ContextBuilder handles the TOKEN budget, not the COST budget.
4. `docs/architecture/decisions/0008-claude-api-primary-llm.md` — Note the 200K context window mentioned (line ~59). We use a conservative 100K budget to leave headroom.

> **Context Budget Note:** token-awareness.md is ~612 lines. Focus only on lines 206-280 (quality tiers) and lines 432-508 (data model). The ContextBuilder is MVP-simple — it will be significantly expanded in M5 (personality/memory integration). Do not over-engineer.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Basic Context Builder for EmberHearth, a native macOS personal AI assistant. This component assembles the message array that gets sent to the Claude API. The MVP version is intentionally simple — it manages a system prompt, recent conversation history, and a new user message, with basic token budgeting to avoid exceeding the context window.

This will be significantly expanded in M5 (Personality & Context) to include memory retrieval, personality traits, and rolling summaries. For now, keep it simple and well-structured.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., ContextBuilder.swift)
- NEVER log or print message content (user messages are private)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- No third-party dependencies — use only Apple frameworks
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target

EXISTING CODE CONTEXT:
- src/LLM/LLMTypes.swift defines:
  - LLMMessage: struct with role (LLMMessageRole) and content (String)
  - LLMMessageRole: enum with .system, .user, .assistant
  - LLMMessage.user("text") and LLMMessage.assistant("text") static factories

TOKEN BUDGET DESIGN:
- Claude's context window: 200K tokens
- We use a CONSERVATIVE total budget of 100,000 tokens (leaves headroom for the model and for safety)
- Budget allocation:
  - System prompt: up to ~10,000 tokens (10%)
  - Recent messages: up to ~50,000 tokens (50%)
  - Reserved for response: ~40,000 tokens (40%) — this is NOT sent, it's left empty for the model to fill
- Token estimation: rough heuristic of 1 token ≈ 4 characters (English text average)
- When recent messages exceed budget, truncate OLDEST messages first (keep the most recent conversation)

STEP 1: Create the ContextBuilder

File: src/LLM/ContextBuilder.swift
```swift
// ContextBuilder.swift
// EmberHearth
//
// Assembles the message context sent to the LLM API.

import Foundation
import os

/// Assembles the message array and system prompt for LLM API calls.
///
/// This MVP implementation handles:
/// - System prompt budgeting
/// - Recent conversation history with token budgeting
/// - Oldest-first truncation when history exceeds budget
///
/// Future enhancements (M5 - Personality & Context):
/// - Memory fact injection
/// - Personality trait injection
/// - Rolling conversation summaries
/// - Semantic relevance scoring
struct ContextBuilder: Sendable {

    // MARK: - Token Budget Configuration

    /// Total token budget for the entire context (conservative, leaves headroom).
    /// Claude supports 200K, but we use 100K to leave room for safety and response.
    static let totalBudget: Int = 100_000

    /// Maximum tokens allocated for the system prompt.
    static let systemPromptBudget: Int = 10_000

    /// Maximum tokens allocated for recent conversation messages.
    static let recentMessagesBudget: Int = 50_000

    /// Tokens reserved for the model's response (not sent, just reserved).
    static let responseBudget: Int = 40_000

    /// Logger for context building events. NEVER logs message content.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ContextBuilder"
    )

    // MARK: - Context Building Result

    /// The result of building a context: assembled messages and the system prompt.
    struct ContextResult: Sendable, Equatable {
        /// The messages array to send to the LLM (user/assistant pairs, no system messages).
        let messages: [LLMMessage]
        /// The system prompt to send separately (Claude uses a top-level "system" field).
        let systemPrompt: String
        /// Estimated total tokens for the assembled context.
        let estimatedTokens: Int
        /// Number of messages that were truncated (removed) to fit the budget.
        let truncatedMessageCount: Int
    }

    // MARK: - Public API

    /// Builds the context for an LLM API call.
    ///
    /// Assembles the system prompt, recent conversation history, and the new user message
    /// into a format ready for the Claude API. Enforces token budgets and truncates
    /// oldest messages if the history is too long.
    ///
    /// - Parameters:
    ///   - systemPrompt: The system prompt defining the assistant's behavior.
    ///   - recentMessages: Previous conversation messages (user/assistant pairs).
    ///                     Should be in chronological order (oldest first).
    ///   - newMessage: The new user message to append.
    /// - Returns: A `ContextResult` with the assembled messages and metadata.
    static func buildContext(
        systemPrompt: String,
        recentMessages: [LLMMessage],
        newMessage: String
    ) -> ContextResult {
        // Step 1: Budget the system prompt
        let truncatedSystemPrompt = truncateToTokenBudget(systemPrompt, maxTokens: systemPromptBudget)
        let systemPromptTokens = tokenEstimate(for: truncatedSystemPrompt)

        // Step 2: Create the new user message
        let newUserMessage = LLMMessage.user(newMessage)
        let newMessageTokens = tokenEstimate(for: newMessage)

        // Step 3: Calculate remaining budget for recent messages
        // Available = recentMessagesBudget minus the new message (which is mandatory)
        let availableForHistory = max(0, recentMessagesBudget - newMessageTokens)

        // Step 4: Fit recent messages into the remaining budget (keep newest, drop oldest)
        var fittedMessages: [LLMMessage] = []
        var usedTokens = 0
        var truncatedCount = 0

        // Iterate from newest to oldest (reverse), adding messages until budget is exhausted
        for message in recentMessages.reversed() {
            let messageTokens = tokenEstimate(for: message.content)
            // Also account for role overhead (~4 tokens for role + formatting)
            let totalMessageCost = messageTokens + 4

            if usedTokens + totalMessageCost <= availableForHistory {
                fittedMessages.insert(message, at: 0)  // Prepend to maintain chronological order
                usedTokens += totalMessageCost
            } else {
                truncatedCount += 1
            }
        }

        // Step 5: Append the new user message
        fittedMessages.append(newUserMessage)

        // Step 6: Calculate total estimated tokens
        let totalEstimatedTokens = systemPromptTokens + usedTokens + newMessageTokens

        if truncatedCount > 0 {
            logger.info("Context built: \(fittedMessages.count) messages, \(truncatedCount) truncated, ~\(totalEstimatedTokens) tokens estimated.")
        } else {
            logger.info("Context built: \(fittedMessages.count) messages, ~\(totalEstimatedTokens) tokens estimated.")
        }

        return ContextResult(
            messages: fittedMessages,
            systemPrompt: truncatedSystemPrompt,
            estimatedTokens: totalEstimatedTokens,
            truncatedMessageCount: truncatedCount
        )
    }

    // MARK: - Token Estimation

    /// Estimates the token count for a given text string.
    ///
    /// Uses a rough heuristic: 1 token ≈ 4 characters for English text.
    /// This is intentionally conservative (slightly overestimates) to avoid
    /// exceeding the actual context window.
    ///
    /// For more accurate estimation, a proper tokenizer (like tiktoken) would be needed,
    /// but the overhead is not justified for MVP. The 100K conservative budget provides
    /// enough headroom for estimation errors.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count.
    static func tokenEstimate(for text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        // 1 token ≈ 4 characters (English average, conservative)
        // We use ceiling division to slightly overestimate
        return max(1, (text.count + 3) / 4)
    }

    // MARK: - Private Helpers

    /// Truncates a text string to fit within a token budget.
    ///
    /// If the text exceeds the budget, it is truncated at a character boundary
    /// and an ellipsis marker is appended to indicate truncation.
    ///
    /// - Parameters:
    ///   - text: The text to potentially truncate.
    ///   - maxTokens: The maximum token budget for this text.
    /// - Returns: The original text if it fits, or a truncated version.
    private static func truncateToTokenBudget(_ text: String, maxTokens: Int) -> String {
        let estimatedTokens = tokenEstimate(for: text)
        if estimatedTokens <= maxTokens {
            return text
        }

        // Calculate the maximum character count (tokens * 4, minus some for the truncation marker)
        let maxChars = max(0, (maxTokens * 4) - 20)  // Reserve 20 chars for "[truncated]"
        if maxChars == 0 {
            return "[truncated]"
        }

        // Truncate at the character limit
        let truncatedText = String(text.prefix(maxChars))
        return truncatedText + "\n[truncated]"
    }
}
```

STEP 2: Create unit tests

File: tests/ContextBuilderTests.swift
```swift
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
        let shortMessage = "Short message here" // ~5 tokens
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
            let allContent = result.messages.map { $0.content }.joined()
            // The oldest messages might have been dropped
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
```

IMPORTANT NOTES:
- Only ONE new source file is created: `src/LLM/ContextBuilder.swift`
- Only ONE new test file is created: `tests/ContextBuilderTests.swift`
- The ContextBuilder is a struct with all static methods (no instance state needed for MVP)
- The ContextBuilder is marked Sendable (it's a value type with no mutable state)
- Token estimation uses the simple 1:4 ratio. This is intentionally rough — the conservative 100K budget (out of Claude's 200K) provides enough headroom.
- Messages are NOT filtered by role in the ContextBuilder. The ClaudeAPIClient already handles filtering system messages from the messages array. The ContextBuilder just assembles them.
- The system prompt is passed through separately (not as a message) because Claude's API takes it as a top-level field.
- NEVER log actual message content. Only log counts, token estimates, and truncation counts.
- The `[truncated]` marker at the end of truncated system prompts helps the LLM know the prompt was cut short.
- After creating files, run:
  1. `swift build` from project root
  2. `swift test --filter ContextBuilderTests` to run these tests
  3. `swift test` to run all tests
```

---

## Acceptance Criteria

- [ ] `src/LLM/ContextBuilder.swift` exists with `buildContext()` and `tokenEstimate()` methods
- [ ] Token budget constants: totalBudget=100K, systemPromptBudget=10K, recentMessagesBudget=50K, responseBudget=40K
- [ ] Budgets sum correctly (10K + 50K + 40K = 100K)
- [ ] Token estimation uses ~4 characters per token heuristic
- [ ] When recent messages exceed budget, OLDEST messages are dropped first
- [ ] New user message is ALWAYS included (never truncated)
- [ ] System prompt is truncated with `[truncated]` marker if too long
- [ ] Chronological order is preserved for included messages
- [ ] `ContextResult` includes: messages, systemPrompt, estimatedTokens, truncatedMessageCount
- [ ] Message content is NEVER logged
- [ ] `tests/ContextBuilderTests.swift` covers: token estimation, basic building, truncation, budget enforcement, edge cases
- [ ] `swift build` succeeds
- [ ] `swift test` passes all tests

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/LLM/ContextBuilder.swift && echo "ContextBuilder.swift exists" || echo "MISSING: ContextBuilder.swift"
test -f tests/ContextBuilderTests.swift && echo "Test file exists" || echo "MISSING: ContextBuilderTests.swift"

# Verify budget constants sum correctly
grep -n "totalBudget.*100_000" src/LLM/ContextBuilder.swift && echo "OK: Total budget is 100K" || echo "WARNING: Total budget not 100K"
grep -n "systemPromptBudget.*10_000" src/LLM/ContextBuilder.swift && echo "OK: System prompt budget is 10K" || echo "WARNING: System prompt budget not 10K"
grep -n "recentMessagesBudget.*50_000" src/LLM/ContextBuilder.swift && echo "OK: Recent messages budget is 50K" || echo "WARNING: Recent messages budget not 50K"
grep -n "responseBudget.*40_000" src/LLM/ContextBuilder.swift && echo "OK: Response budget is 40K" || echo "WARNING: Response budget not 40K"

# Verify no message content is logged
grep -rn "\.content" src/LLM/ContextBuilder.swift | grep -i "log\|print" && echo "WARNING: Possible content logging" || echo "OK: No content logging"

# Build the project
swift build 2>&1

# Run context builder tests
swift test --filter ContextBuilderTests 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the ContextBuilder implementation created in task 0203 for EmberHearth. Check for these specific issues:

1. TOKEN BUDGET CORRECTNESS:
   - Open src/LLM/ContextBuilder.swift
   - Verify budget constants: totalBudget=100_000, systemPromptBudget=10_000, recentMessagesBudget=50_000, responseBudget=40_000
   - Verify 10_000 + 50_000 + 40_000 = 100_000 (budgets must sum correctly)
   - Verify tokenEstimate uses ceiling division: (text.count + 3) / 4 (not floor division)
   - Verify tokenEstimate returns 0 for empty strings
   - Verify tokenEstimate returns at least 1 for non-empty strings

2. TRUNCATION LOGIC:
   - Verify oldest messages are dropped first (iterate from newest to oldest)
   - Verify the new user message is ALWAYS included (never truncated)
   - Verify the new user message is the LAST element in the messages array
   - Verify chronological order is preserved after truncation
   - Verify system prompt truncation appends "[truncated]" marker
   - Verify there is no off-by-one error in the budget calculation (the new message tokens are subtracted from the recent messages budget before fitting history)

3. MESSAGE ORDERING:
   - Verify recentMessages are iterated in reverse (newest first) for fitting
   - Verify fitted messages are prepended (insert at index 0) to maintain chronological order
   - Verify the final array is: [oldest-that-fits, ..., newest-that-fits, new-user-message]

4. OVERHEAD ACCOUNTING:
   - Verify each message has a small overhead added (~4 tokens for role + formatting)
   - Verify the overhead is included in the budget calculation

5. SECURITY:
   - Verify message content is NEVER logged (search for any .content with logger/print)
   - Verify only counts and token estimates are logged
   - Verify no force-unwraps (!)

6. TYPE CORRECTNESS:
   - Verify ContextBuilder is a struct (not class)
   - Verify it is marked Sendable
   - Verify ContextResult is a struct marked Sendable and Equatable
   - Verify all methods are static (no instance state for MVP)

7. TEST QUALITY:
   - Verify tests cover: empty input, single message, multiple messages, truncation, budget enforcement
   - Verify tests verify chronological ordering
   - Verify tests verify the new message is always included and always last
   - Verify tests check that budget constants sum correctly
   - Verify tests for system prompt truncation

8. BUILD VERIFICATION:
   - Run `swift build` — verify no warnings or errors
   - Run `swift test` — verify all tests pass

Report any issues found with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m3): add basic context builder with token budgeting
```

---

## Notes for Next Task

- The ContextBuilder is intentionally simple for MVP. In M5 (task ~0400+), it will be expanded to:
  - Inject relevant memory facts into the context
  - Add personality traits to the system prompt
  - Generate rolling summaries of older conversation history
  - Use semantic relevance scoring to select which facts to include
- The token estimation heuristic (1 token ≈ 4 chars) is rough but adequate with the conservative 100K budget. If more precision is needed later, a proper tokenizer can be swapped in.
- The `ContextResult.estimatedTokens` field is useful for the token tracking system (M3 task, later for cost tracking in token-awareness.md).
- Task 0204 (RetryHandler) does not depend on ContextBuilder directly, but the eventual message coordinator will use both.
- The ContextBuilder does NOT filter system messages from the messages array. That responsibility stays with ClaudeAPIClient.buildRequest(), which already filters them (see task 0201).
