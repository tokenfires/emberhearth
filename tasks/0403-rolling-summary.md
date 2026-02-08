# Task 0403: Rolling Summary Generation

**Milestone:** M5 - Personality & Context
**Unit:** 5.4 - Rolling Summary Generation
**Phase:** 2
**Depends On:** 0402 (Enhanced ContextBuilder), 0201 (ClaudeAPIClient)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/session-management.md` — Read Section 1 (Context Window Management: summarization strategy, trigger at ~20 messages, dynamic adjustment) and Section 2 (Session Continuity: ConversationSession struct with `rollingSummary` and `summaryMessageCount` fields)
2. `src/LLM/ClaudeAPIClient.swift` — The Claude API client from task 0201. Understand how to make a non-streaming API call. Look for the method that sends messages and returns a response string.
3. `src/Core/SessionManager.swift` — The session manager from task 0304. Understand how sessions store messages and how to update the rolling summary field.
4. `src/LLM/ContextBuilder.swift` — The enhanced context builder from task 0402. See how the session summary is used in context assembly (passed to SystemPromptBuilder and included as a bracketed assistant message).
5. `CLAUDE.md` — Project conventions (PascalCase for Swift files, src/ layout, security principles)

> **Context Budget Note:** `session-management.md` is ~590 lines. Focus on lines 24-82 (Summarization Strategy with the ConversationSummarizer struct) and lines 203-240 (ConversationSession struct showing rollingSummary field). The source files from prior tasks should be read entirely but are small.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Rolling Summary Generator for EmberHearth, a native macOS personal AI assistant. When a conversation accumulates too many messages, older messages are compressed into a concise summary. This summary preserves conversation continuity without consuming the entire context window.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., SummaryGenerator.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)

## What You Are Building

A `SummaryGenerator` that:
1. Determines when summarization should trigger (message count + token threshold)
2. Takes the oldest N messages from a session (leaving the most recent 10 intact)
3. Calls the Claude API with a summarization prompt to compress them into a summary
4. Stores the summary in the session record
5. Removes the summarized messages from active storage (they're now in the summary)

## Design Philosophy

From session-management.md:
- **Trigger at ~20 messages** when the oldest 20 messages exceed ~15,000 tokens
- **Dynamic adjustment** based on user behavior (high-volume users get higher threshold)
- **Summary is incremental** — new summaries build on previous summaries
- The summary preserves: key topics, decisions made, action items, emotional tone
- The summary is written in third person ("The user discussed...")

## Dependencies

This task uses the `ClaudeAPIClient` from M3. The summary generation uses a non-streaming API call (this is a background operation, not real-time). The LLM call should use a small max_tokens value (1024) since summaries should be concise.

## Files to Create

### 1. `src/Core/SummaryGenerator.swift`

```swift
// SummaryGenerator.swift
// EmberHearth
//
// Generates rolling summaries of conversation history to manage context window.

import Foundation
import os

/// Generates concise summaries of conversation segments to maintain context
/// continuity without consuming the entire context window.
///
/// When a session accumulates too many messages, the SummaryGenerator:
/// 1. Takes the oldest batch of messages (leaving recent ones intact)
/// 2. Sends them to the LLM with a summarization prompt
/// 3. Stores the resulting summary in the session
/// 4. Signals that the summarized messages can be removed from active storage
///
/// This is a background operation — it does not block the response to the
/// user's current message.
///
/// ## Trigger Conditions
///
/// Summarization triggers when BOTH conditions are met:
/// - The session has more than `messageCountThreshold` messages (default: 30)
/// - The oldest `messagesToSummarize` messages exceed `tokenThreshold` tokens
///
/// ## Summary Format
///
/// The summary is written in third person and captures:
/// - Key topics discussed
/// - Decisions made
/// - Action items or things the user asked to be remembered
/// - The emotional tone of the conversation
final class SummaryGenerator {

    // MARK: - Configuration

    /// Number of total messages in the session before summarization is considered.
    /// Must exceed this count before the token threshold is checked.
    let messageCountThreshold: Int

    /// The number of oldest messages to include in each summarization batch.
    /// The most recent `recentMessagesToKeep` messages are always left intact.
    let messagesToSummarize: Int

    /// Number of recent messages to always keep verbatim (not summarized).
    /// These provide immediate conversational context.
    let recentMessagesToKeep: Int

    /// Token threshold for the messages being summarized.
    /// Summarization only triggers if the candidate messages exceed this many tokens.
    /// This prevents summarizing a few short messages unnecessarily.
    let tokenThreshold: Int

    /// Maximum tokens for the summary response from the LLM.
    let maxSummaryTokens: Int

    /// Logger for summary generation operations.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "SummaryGenerator"
    )

    // MARK: - Summarization Prompt

    /// The prompt sent to the LLM to generate a conversation summary.
    ///
    /// This is a carefully crafted prompt that produces consistent, useful
    /// summaries. It instructs the LLM to write in third person and focus
    /// on actionable information.
    static let summarizationPrompt: String = """
        Summarize this conversation concisely. Focus on:
        1. Key topics discussed
        2. Any decisions made or conclusions reached
        3. Action items or things the user asked to be remembered
        4. The emotional tone of the conversation

        Keep the summary under 500 words. Write in third person ("The user discussed...", "The user mentioned..."). Focus on what matters for continuing the conversation later — skip small talk and pleasantries unless they reveal something important about the user's state.

        If there is a previous summary provided, incorporate its key points into your new summary rather than repeating it verbatim. The goal is one cohesive summary of the entire conversation so far.
        """

    // MARK: - Initialization

    /// Creates a new SummaryGenerator with configurable thresholds.
    ///
    /// - Parameters:
    ///   - messageCountThreshold: Minimum total messages before summarization triggers.
    ///     Defaults to 30.
    ///   - messagesToSummarize: How many oldest messages to summarize per batch.
    ///     Defaults to 20.
    ///   - recentMessagesToKeep: How many recent messages to always keep verbatim.
    ///     Defaults to 10.
    ///   - tokenThreshold: Minimum tokens in candidate messages before summarization.
    ///     Defaults to 15,000.
    ///   - maxSummaryTokens: Maximum tokens for the LLM's summary response.
    ///     Defaults to 1024.
    init(
        messageCountThreshold: Int = 30,
        messagesToSummarize: Int = 20,
        recentMessagesToKeep: Int = 10,
        tokenThreshold: Int = 15_000,
        maxSummaryTokens: Int = 1024
    ) {
        self.messageCountThreshold = messageCountThreshold
        self.messagesToSummarize = messagesToSummarize
        self.recentMessagesToKeep = recentMessagesToKeep
        self.tokenThreshold = tokenThreshold
        self.maxSummaryTokens = maxSummaryTokens
    }

    // MARK: - Public API

    /// Determines whether the given session should trigger summarization.
    ///
    /// Summarization triggers when:
    /// 1. The session has more than `messageCountThreshold` messages, AND
    /// 2. The oldest messages (excluding the most recent `recentMessagesToKeep`)
    ///    exceed the `tokenThreshold`
    ///
    /// - Parameters:
    ///   - totalMessageCount: The total number of messages in the session.
    ///   - oldestMessagesTokenCount: The estimated token count of the messages
    ///     that would be summarized (the oldest `messagesToSummarize` messages).
    /// - Returns: True if summarization should be triggered.
    func shouldSummarize(
        totalMessageCount: Int,
        oldestMessagesTokenCount: Int
    ) -> Bool {
        guard totalMessageCount > messageCountThreshold else {
            return false
        }

        guard oldestMessagesTokenCount > tokenThreshold else {
            logger.debug("Message count threshold met (\(totalMessageCount) > \(self.messageCountThreshold)) but token threshold not met (\(oldestMessagesTokenCount) <= \(self.tokenThreshold))")
            return false
        }

        logger.info("Summarization triggered: \(totalMessageCount) messages, ~\(oldestMessagesTokenCount) tokens in candidate messages")
        return true
    }

    /// Generates a summary of the provided messages using the LLM.
    ///
    /// This method calls the Claude API with the summarization prompt and the
    /// messages to summarize. It returns the generated summary text.
    ///
    /// If a previous summary exists, it is included in the prompt so the LLM
    /// can produce a cohesive summary that incorporates earlier context.
    ///
    /// This is a background operation — failures are handled gracefully.
    /// If summary generation fails, the method returns nil and the messages
    /// are kept as-is (no data is lost).
    ///
    /// - Parameters:
    ///   - messages: The messages to summarize. Each should have role and content.
    ///     These are the oldest messages in the session, formatted as
    ///     "User: message" or "Ember: message" lines.
    ///   - previousSummary: The existing rolling summary to incorporate, if any.
    ///   - apiClient: The Claude API client for making the LLM call.
    /// - Returns: The generated summary text, or nil if generation failed.
    func generateSummary(
        for messages: [SummaryMessage],
        previousSummary: String?,
        apiClient: ClaudeAPIClient
    ) async -> String? {
        guard !messages.isEmpty else {
            logger.warning("No messages to summarize")
            return nil
        }

        // Format messages for the summarization prompt
        let formattedMessages = messages.map { msg in
            let speaker = msg.isFromUser ? "User" : "Ember"
            return "\(speaker): \(msg.content)"
        }.joined(separator: "\n")

        // Build the full prompt
        var fullPrompt = Self.summarizationPrompt + "\n\n"

        if let previous = previousSummary, !previous.isEmpty {
            fullPrompt += "Previous summary of earlier conversation:\n\(previous)\n\n"
        }

        fullPrompt += "Conversation to summarize:\n\(formattedMessages)"

        // Make the LLM call
        do {
            let llmMessages = [
                LLMMessage(role: .user, content: fullPrompt)
            ]

            let summary = try await apiClient.sendMessage(
                messages: llmMessages,
                systemPrompt: "You are a conversation summarizer. Produce concise, factual summaries.",
                maxTokens: maxSummaryTokens
            )

            let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSummary.isEmpty else {
                logger.error("LLM returned empty summary")
                return nil
            }

            logger.info("Summary generated: \(trimmedSummary.count) characters from \(messages.count) messages")
            return trimmedSummary

        } catch {
            // Graceful failure — keep messages as-is, do not lose data
            logger.error("Summary generation failed: \(error.localizedDescription). Messages will be kept as-is.")
            return nil
        }
    }

    /// Performs the full summarization workflow for a session.
    ///
    /// This is the high-level method that orchestrates the entire process:
    /// 1. Check if summarization should trigger
    /// 2. Select the oldest messages to summarize
    /// 3. Generate the summary via LLM
    /// 4. Return the result for the caller to update the session
    ///
    /// The caller (typically the message processing pipeline) is responsible
    /// for updating the session with the new summary and removing the
    /// summarized messages.
    ///
    /// - Parameters:
    ///   - allMessages: All messages in the session, in chronological order.
    ///   - previousSummary: The existing rolling summary, if any.
    ///   - apiClient: The Claude API client.
    ///   - tokenEstimator: A closure that estimates token count for a string.
    ///     This allows the caller to provide the token estimation method
    ///     from ContextBuilder or TokenCounter.
    /// - Returns: A `SummarizationResult` if summarization was performed,
    ///   or nil if not needed or if generation failed.
    func summarizeIfNeeded(
        allMessages: [SummaryMessage],
        previousSummary: String?,
        apiClient: ClaudeAPIClient,
        tokenEstimator: (String) -> Int
    ) async -> SummarizationResult? {
        let totalCount = allMessages.count

        // Determine which messages would be summarized
        let keepCount = min(recentMessagesToKeep, totalCount)
        let candidateCount = totalCount - keepCount
        guard candidateCount > 0 else { return nil }

        let candidateMessages = Array(allMessages.prefix(min(messagesToSummarize, candidateCount)))

        // Estimate tokens for the candidate messages
        let candidateTokens = candidateMessages.reduce(0) { total, msg in
            total + tokenEstimator(msg.content)
        }

        // Check trigger conditions
        guard shouldSummarize(
            totalMessageCount: totalCount,
            oldestMessagesTokenCount: candidateTokens
        ) else {
            return nil
        }

        // Generate the summary
        guard let summary = await generateSummary(
            for: candidateMessages,
            previousSummary: previousSummary,
            apiClient: apiClient
        ) else {
            return nil
        }

        return SummarizationResult(
            summary: summary,
            summarizedMessageCount: candidateMessages.count,
            summarizedMessageIds: candidateMessages.compactMap { $0.id }
        )
    }
}

// MARK: - Supporting Types

/// A simplified message representation for summarization.
///
/// This is a lightweight type that avoids importing the full session
/// message model. The caller maps from their message type to this one.
struct SummaryMessage: Sendable {
    /// Optional message ID for tracking which messages were summarized.
    let id: Int64?

    /// The message text content.
    let content: String

    /// True if this message was sent by the user, false if by Ember.
    let isFromUser: Bool

    /// When this message was sent.
    let timestamp: Date
}

/// The result of a successful summarization operation.
///
/// The caller uses this to update the session with the new summary
/// and remove the summarized messages from active storage.
struct SummarizationResult: Sendable {
    /// The generated summary text.
    let summary: String

    /// How many messages were compressed into this summary.
    let summarizedMessageCount: Int

    /// The IDs of the messages that were summarized.
    /// The caller should remove these from active message storage.
    let summarizedMessageIds: [Int64]
}
```

### 2. Create `tests/SummaryGeneratorTests.swift`

```swift
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
        XCTAssertTrue(prompt.contains("Action items") || prompt.contains("action items"),
                       "Prompt should mention action items")
        XCTAssertTrue(prompt.contains("emotional tone"), "Prompt should mention emotional tone")
        XCTAssertTrue(prompt.contains("third person"), "Prompt should instruct third-person writing")
        XCTAssertTrue(prompt.contains("500 words"), "Prompt should specify word limit")
    }

    func testSummarizationPromptMentionsPreviousSummary() {
        let prompt = SummaryGenerator.summarizationPrompt
        XCTAssertTrue(prompt.lowercased().contains("previous summary"),
                       "Prompt should mention incorporating previous summary")
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

    // MARK: - SummarizeIfNeeded Logic Tests

    func testSummarizeIfNeededWithTooFewMessages() async {
        // Create only 5 messages — below the threshold of 10
        let messages = createTestMessages(count: 5)

        let result = await generator.summarizeIfNeeded(
            allMessages: messages,
            previousSummary: nil,
            apiClient: createMockAPIClient(),
            tokenEstimator: { text in text.count / 4 }
        )

        XCTAssertNil(result, "Should not summarize when below message threshold")
    }

    func testSummarizeIfNeededWithEmptyMessages() async {
        let result = await generator.summarizeIfNeeded(
            allMessages: [],
            previousSummary: nil,
            apiClient: createMockAPIClient(),
            tokenEstimator: { text in text.count / 4 }
        )

        XCTAssertNil(result, "Should not summarize empty message list")
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
    private func createTestMessages(count: Int) -> [SummaryMessage] {
        var messages: [SummaryMessage] = []
        let baseDate = Date()
        for i in 0..<count {
            messages.append(SummaryMessage(
                id: Int64(i + 1),
                content: "Test message number \(i + 1) with some content to make it reasonable length.",
                isFromUser: i % 2 == 0,
                timestamp: baseDate.addingTimeInterval(TimeInterval(i * 60))
            ))
        }
        return messages
    }

    /// Creates a mock API client for testing.
    /// NOTE: This requires ClaudeAPIClient to be instantiable in tests.
    /// If ClaudeAPIClient requires a real API key, this method should
    /// return a test-specific subclass or mock. Adjust as needed based
    /// on the actual ClaudeAPIClient implementation from task 0201.
    private func createMockAPIClient() -> ClaudeAPIClient {
        // This is a placeholder. If ClaudeAPIClient cannot be easily
        // mocked, the async integration tests should be skipped and
        // documented as needing a mock framework or protocol-based
        // dependency injection. For now, test what can be tested
        // synchronously (shouldSummarize, threshold logic, etc.)
        // and add integration tests when mocking is available.
        fatalError("Mock API client not yet implemented — async integration tests require protocol-based ClaudeAPIClient. Test synchronous methods only.")
    }
}
```

## Implementation Notes

1. **Graceful failure is critical.** If the LLM call fails (network error, API error, etc.), the summary generation returns nil and the messages are kept as-is. No data is ever lost due to a failed summarization.

2. **The caller is responsible for persistence.** `SummaryGenerator` returns a `SummarizationResult` but does NOT update the database directly. The message processing pipeline (or SessionManager) should:
   - Store the new summary in the session's `rollingSummary` field
   - Remove the summarized messages from the active messages table

3. **Non-streaming API call.** Summarization uses a regular (non-streaming) API call because it's a background operation. The user doesn't see this happening.

4. **Token estimation is injected.** The `tokenEstimator` parameter is a closure so the generator doesn't need to import the ContextBuilder or TokenCounter directly. This keeps the dependency graph clean.

5. **Previous summary incorporation.** When a previous summary exists, it's included in the LLM prompt so the new summary can incorporate it. This produces a cohesive rolling summary rather than a chain of separate summaries.

6. **The `SummaryMessage` type is intentionally lightweight.** It avoids coupling to the full session message model. The caller maps from their message type to `SummaryMessage`.

7. If the `ClaudeAPIClient.sendMessage()` method has a different name or signature, adapt accordingly. The key requirement is a non-streaming call that sends messages and returns a response string.

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, os).
3. All Swift files use PascalCase naming.
4. All classes and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. Handle LLM failure gracefully — if summary generation fails, keep messages as-is. Log the error and return nil.
7. The test file path should match the existing test file pattern.

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All synchronous tests pass (`swift test`)
3. There are no calls to Process(), /bin/bash, or any shell execution
4. All public methods have documentation comments
5. os.Logger is used (not print() statements)
6. LLM failure is handled gracefully (returns nil, logs error, no data loss)
7. The summarization prompt is concise and effective
8. `shouldSummarize()` requires BOTH conditions (message count AND token threshold)
9. `SummarizationResult` contains all needed fields for the caller
10. The `SummaryMessage` type is lightweight (not importing full session models)
```

---

## Acceptance Criteria

- [ ] `src/Core/SummaryGenerator.swift` exists with `SummaryGenerator` class
- [ ] `shouldSummarize()` returns true only when BOTH message count AND token threshold are exceeded
- [ ] `shouldSummarize()` returns false at exact threshold (must exceed, not equal)
- [ ] `generateSummary()` calls the Claude API with the summarization prompt
- [ ] `generateSummary()` includes previous summary in the prompt when available
- [ ] `generateSummary()` returns nil on LLM failure (graceful degradation, no data loss)
- [ ] `generateSummary()` returns nil for empty message input
- [ ] `summarizeIfNeeded()` orchestrates the full workflow: check threshold, select messages, generate summary
- [ ] `summarizeIfNeeded()` returns nil when thresholds are not met
- [ ] `SummarizationResult` struct contains: summary text, summarized message count, summarized message IDs
- [ ] `SummaryMessage` struct is lightweight with: id, content, isFromUser, timestamp
- [ ] Summarization prompt instructs third-person writing, 500-word limit, focus on key topics/decisions/actions/tone
- [ ] Default thresholds: 30 messages, 20 to summarize, 10 to keep, 15,000 token threshold, 1024 max summary tokens
- [ ] All thresholds are configurable via initializer
- [ ] Non-streaming LLM call used (background operation)
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All synchronous unit tests pass
- [ ] `os.Logger` used for all logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Core/SummaryGenerator.swift && echo "SummaryGenerator.swift exists" || echo "MISSING: SummaryGenerator.swift"

# Verify test file exists
test -f tests/SummaryGeneratorTests.swift && echo "Test file exists (flat)" || test -f tests/Core/SummaryGeneratorTests.swift && echo "Test file exists (nested)" || echo "MISSING: SummaryGeneratorTests.swift"

# Verify no shell execution
grep -rn "Process()" src/Core/SummaryGenerator.swift || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/Core/SummaryGenerator.swift || echo "PASS: No /bin/bash references found"

# Verify graceful error handling (should catch errors, not crash)
grep -n "catch" src/Core/SummaryGenerator.swift && echo "PASS: Error handling present" || echo "WARNING: Check error handling"

# Verify summarization prompt exists
grep -n "summarizationPrompt" src/Core/SummaryGenerator.swift && echo "PASS: Summarization prompt defined" || echo "FAIL: Missing summarization prompt"

# Build the project
swift build 2>&1

# Run summary generator tests
swift test --filter SummaryGeneratorTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the SummaryGenerator implementation for EmberHearth created in task 0403. Check for these specific issues:

@src/Core/SummaryGenerator.swift
@tests/SummaryGeneratorTests.swift (or tests/Core/SummaryGeneratorTests.swift)

Also reference:
@docs/research/session-management.md (Section 1: Summarization Strategy)
@src/LLM/ContextBuilder.swift (how the session summary is used)

1. **GRACEFUL FAILURE (Critical):**
   - If the LLM API call fails (network error, timeout, API error), does generateSummary return nil?
   - Is the error logged with sufficient detail?
   - Is it absolutely certain that no messages are deleted if summarization fails? (The caller handles deletion, but verify the contract is clear.)
   - What happens if the LLM returns an empty string?

2. **SUMMARIZATION QUALITY (Important):**
   - Does the summarization prompt instruct third-person writing?
   - Does it focus on key topics, decisions, action items, and emotional tone?
   - Does it specify a word limit (500 words)?
   - Does it handle incorporating previous summaries for rolling updates?
   - Is the prompt concise enough to not waste tokens on the prompt itself?

3. **TRIGGER LOGIC (Important):**
   - Does shouldSummarize require BOTH conditions (message count AND token threshold)?
   - Is the comparison strictly greater than (not greater-than-or-equal)?
   - Are the default thresholds reasonable? (30 messages, 15,000 tokens)
   - Does summarizeIfNeeded correctly select the oldest messages and leave recent ones intact?

4. **API INTEGRATION:**
   - Does generateSummary use a non-streaming API call?
   - Is maxTokens set to a reasonable limit for summaries (1024)?
   - Does it pass a minimal system prompt for the summarization call?
   - Is the ClaudeAPIClient method signature compatible with the actual implementation from task 0201?

5. **CODE QUALITY:**
   - Are all public APIs documented with /// comments?
   - Is os.Logger used consistently (no print statements)?
   - Is the SummaryMessage type appropriately lightweight?
   - Is SummarizationResult marked Sendable?
   - Are there any force-unwraps or potential crashes?
   - Is the token estimator injected as a closure (not importing ContextBuilder directly)?

6. **SECURITY:**
   - No Process(), /bin/bash, /bin/sh, or NSTask calls?
   - Does the summarization prompt avoid leaking sensitive instructions into the summary?

7. **TEST QUALITY:**
   - Do tests cover: shouldSummarize trigger logic (below threshold, above threshold, at exact threshold)?
   - Do tests cover: default and custom configuration?
   - Do tests cover: summarization prompt content verification?
   - Do tests cover: SummaryMessage and SummarizationResult struct creation?
   - Is the lack of async integration tests documented with explanation?
   - Are there tests for edge cases (zero messages, very high counts)?

Report any issues found with specific file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m5): add rolling summary generation for context management
```

---

## Notes for Next Task

- `SummaryGenerator` is now available for use by the message processing pipeline. When a new message arrives, the pipeline should call `summarizeIfNeeded()` after processing the response.
- The `SummarizationResult.summarizedMessageIds` array tells the caller which messages to remove from active storage. The SessionManager should handle this deletion.
- The token estimator is passed as a closure. Task 0404 (TokenCounter) will provide a more accurate estimator that can be injected here.
- The `generateSummary()` method uses `ClaudeAPIClient.sendMessage()`. If this method name differs in the actual implementation, it needs to be adapted.
- The summary is stored in the session's `rollingSummary` field, which is then used by `ContextBuilder.buildIntegratedContext()` (from task 0402) when assembling context for the next LLM request.
- Future enhancement: the summarization threshold could be dynamically adjusted based on user behavior (high-volume users get higher thresholds). For MVP, static thresholds are sufficient.
