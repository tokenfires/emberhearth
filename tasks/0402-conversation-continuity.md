# Task 0402: Conversation Continuity via Enhanced Context Builder

**Milestone:** M5 - Personality & Context
**Unit:** 5.3 - Conversation Continuity
**Phase:** 2
**Depends On:** 0304 (SessionManager from M4), 0203 (ContextBuilder from M3), 0400 (SystemPromptBuilder), 0401 (VerbosityAdapter)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/session-management.md` — Read Section 1 (Context Window Management: context budget allocation, context building flow steps 1-6) and Section 2 (Session Continuity: ConversationSession struct, state persistence)
2. `src/LLM/ContextBuilder.swift` — The existing context builder from task 0203. This file will be significantly updated. Read it entirely to understand the current API.
3. `src/Personality/SystemPromptBuilder.swift` — The prompt builder from task 0400. Understand the `buildSystemPrompt()` method signature and its parameters.
4. `src/Personality/VerbosityAdapter.swift` — The verbosity adapter from task 0401. Understand how `detectVerbosity()` and `instruction(for:)` work.
5. `src/Memory/FactRetriever.swift` — The fact retriever from task 0302 (M4). Understand how facts are retrieved by relevance.
6. `src/Core/SessionManager.swift` — The session manager from task 0304 (M4). Understand how sessions and messages are managed.
7. `CLAUDE.md` — Project conventions (PascalCase for Swift files, src/ layout, security principles)

> **Context Budget Note:** `session-management.md` is ~590 lines. Focus on lines 24-116 (Context Budget and Building Flow) and lines 118-240 (Session Continuity and ConversationSession struct). Skip group chat, identity verification, and multi-user sections. The source files from prior tasks should be read entirely but they are small.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are significantly updating the ContextBuilder for EmberHearth, a native macOS personal AI assistant. The existing ContextBuilder from task 0203 (M3) was a simple implementation that just assembled messages for the LLM. You are now integrating it with the personality system (SystemPromptBuilder, VerbosityAdapter) and the memory system (FactRetriever, SessionManager) to create full conversation continuity.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., ContextBuilder.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)

## What You Are Building

An enhanced ContextBuilder that assembles the complete context for each LLM request by:
1. Building the system prompt (via SystemPromptBuilder) with personality, user facts, time context, and session summary
2. Detecting appropriate verbosity (via VerbosityAdapter) from the current message and recent history
3. Retrieving relevant user facts (via FactRetriever) for the current conversation
4. Loading recent messages (via SessionManager) for conversation continuity
5. Enforcing context budget allocations so each section stays within its token share

## Context Budget (from session-management.md)

```
System prompt          ~10%  of total context window
Recent messages        ~25%  of total context window
Conversation summary   ~10%  of total context window
Retrieved memories     ~15%  of total context window (included in system prompt)
Active task state      ~5%   of total context window
Reserve for response   ~35%  of total context window
```

For a 100K token context window (Claude), this means:
- System prompt: ~10,000 tokens
- Recent messages: ~25,000 tokens
- Summary: ~10,000 tokens
- Memories/facts: ~15,000 tokens (part of system prompt budget)
- Task state: ~5,000 tokens
- Response reserve: ~35,000 tokens

For MVP, the system prompt budget (10%) includes the personality base prompt AND the user facts (15% is combined into the system prompt section). So effectively the system prompt gets ~25% of the non-response budget.

## Prior Work: Existing Types

The following types should already exist from prior tasks. Reference them by name. If any are missing, create minimal protocol stubs so the code compiles (but note it in comments).

From M3 (LLM Integration):
- `LLMMessage` — A message with `role: LLMRole` and `content: String`
- `LLMRole` — Enum with `.system`, `.user`, `.assistant`
- `ContextBuilder` — The file you are updating (src/LLM/ContextBuilder.swift)

From M4 (Memory System):
- `SessionManager` — Manages conversation sessions and messages
- `SessionMessage` — A message in a session (has `content: String`, `role: String`, `timestamp: Date`)
- `FactRetriever` — Retrieves relevant facts by query
- `Fact` — A stored fact (has `content: String`, `importance: Double`, `updatedAt: Date`)

From M5 (this milestone):
- `SystemPromptBuilder` — Builds system prompt from personality + dynamic context
- `FactInfo` — Lightweight fact projection for SystemPromptBuilder
- `VerbosityAdapter` — Detects verbosity level and generates instructions
- `VerbosityLevel` — Enum (terse, concise, moderate, detailed)

## Files to Update/Create

### 1. Update `src/LLM/ContextBuilder.swift`

Keep the existing file but significantly enhance it. Preserve any backward-compatible simple methods if callers still use them. Add the new integrated context building flow.

The enhanced ContextBuilder should have:

```swift
// ContextBuilder.swift
// EmberHearth
//
// Assembles complete LLM context from personality, memory, and session systems.

import Foundation
import os

/// Assembles the complete context for LLM requests by integrating
/// the personality system, memory system, and session history.
///
/// The context builder is the central integration point that:
/// 1. Retrieves relevant user facts from the memory system
/// 2. Loads recent messages from the session history
/// 3. Builds the system prompt with personality and dynamic context
/// 4. Detects appropriate verbosity from user message patterns
/// 5. Enforces context budget to keep within the token window
///
/// ## Context Budget
///
/// For a 100K token context window:
/// - System prompt (personality + facts + context): ~10,000 tokens
/// - Recent conversation messages: ~25,000 tokens
/// - Session summary: ~10,000 tokens
/// - Response reserve: ~35,000 tokens
final class ContextBuilder {

    // MARK: - Properties

    /// The system prompt builder for assembling personality context.
    private let promptBuilder: SystemPromptBuilder

    /// The verbosity adapter for detecting response length preferences.
    private let verbosityAdapter: VerbosityAdapter

    /// Default total token budget for the context window.
    /// This is the model's maximum context minus a safety margin.
    let defaultTotalTokens: Int

    /// Logger for context building operations.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ContextBuilder"
    )

    // MARK: - Initialization

    /// Creates a new ContextBuilder with the specified components.
    ///
    /// - Parameters:
    ///   - promptBuilder: The system prompt builder. Defaults to a new instance.
    ///   - verbosityAdapter: The verbosity adapter. Defaults to a new instance.
    ///   - defaultTotalTokens: The default context window budget. Defaults to 100,000.
    init(
        promptBuilder: SystemPromptBuilder = SystemPromptBuilder(),
        verbosityAdapter: VerbosityAdapter = VerbosityAdapter(),
        defaultTotalTokens: Int = 100_000
    ) {
        self.promptBuilder = promptBuilder
        self.verbosityAdapter = verbosityAdapter
        self.defaultTotalTokens = defaultTotalTokens
    }

    // MARK: - Enhanced Context Building

    /// Builds the complete context for an LLM request, integrating all systems.
    ///
    /// This is the primary method for assembling context. It:
    /// 1. Retrieves relevant facts via the fact retriever
    /// 2. Loads recent session messages
    /// 3. Builds the system prompt with personality, facts, time, and summary
    /// 4. Detects verbosity from user message patterns
    /// 5. Formats everything as LLM messages
    ///
    /// - Parameters:
    ///   - factRetriever: The memory system's fact retriever for loading user facts.
    ///   - sessionManager: The session manager for loading conversation history.
    ///   - phoneNumber: The phone number identifying this conversation.
    ///   - newMessage: The new user message to respond to.
    ///   - userName: The user's name if known.
    /// - Returns: A `ContextBuildResult` containing assembled messages and metadata.
    /// - Throws: If fact retrieval or session loading fails.
    func buildIntegratedContext(
        factRetriever: FactRetriever,
        sessionManager: SessionManager,
        phoneNumber: String,
        newMessage: String,
        userName: String? = nil
    ) async throws -> ContextBuildResult {

        // 1. Load session state
        let session = try await sessionManager.getOrCreateSession(for: phoneNumber)
        let recentMessages = try await sessionManager.getRecentMessages(
            for: session.id,
            limit: 50  // Load more than we'll use; trimming happens below
        )
        let sessionSummary = session.rollingSummary

        // 2. Retrieve relevant facts
        let relevantFacts = try await factRetriever.retrieveRelevantFacts(
            query: newMessage,
            limit: SystemPromptBuilder.maxFacts
        )

        // 3. Map facts to FactInfo for the prompt builder
        let factInfos: [FactInfo] = relevantFacts.map { fact in
            FactInfo(
                content: fact.content,
                importance: fact.importance,
                lastUpdated: fact.updatedAt
            )
        }

        // 4. Detect verbosity from user message patterns
        let userMessages = recentMessages
            .filter { $0.role == "user" }
            .compactMap { $0.content }
        let verbosityLevel = verbosityAdapter.detectVerbosity(
            from: newMessage,
            recentUserMessages: userMessages
        )
        let verbosityInstruction = verbosityAdapter.instruction(for: verbosityLevel)

        // 5. Build the system prompt
        let systemPrompt = promptBuilder.buildSystemPrompt(
            userFacts: factInfos,
            sessionSummary: sessionSummary,
            currentDate: Date(),
            verbosityInstruction: verbosityInstruction,
            userName: userName
        )

        // 6. Calculate token budgets
        let responseBudget = Int(Double(defaultTotalTokens) * 0.35)
        let systemPromptBudget = Int(Double(defaultTotalTokens) * 0.10)
        let recentMessagesBudget = Int(Double(defaultTotalTokens) * 0.25)
        let summaryBudget = Int(Double(defaultTotalTokens) * 0.10)
        let availableForMessages = defaultTotalTokens - responseBudget - estimateTokens(for: systemPrompt)

        // 7. Format recent messages as LLM messages, respecting budget
        var llmMessages: [LLMMessage] = []
        var messageTokensUsed = 0

        // Include session summary as an early assistant message if available
        if let summary = sessionSummary, !summary.isEmpty {
            let summaryTokens = estimateTokens(for: summary)
            if summaryTokens <= summaryBudget {
                llmMessages.append(LLMMessage(
                    role: .assistant,
                    content: "[Conversation summary from earlier: \(summary)]"
                ))
                messageTokensUsed += summaryTokens
            }
        }

        // Add recent messages, newest first, then reverse for chronological order
        var includedMessages: [LLMMessage] = []
        for message in recentMessages.reversed() {
            let role: LLMRole = message.role == "user" ? .user : .assistant
            let tokens = estimateTokens(for: message.content ?? "")
            if messageTokensUsed + tokens > availableForMessages {
                break  // Stop adding older messages when budget is reached
            }
            includedMessages.insert(
                LLMMessage(role: role, content: message.content ?? ""),
                at: 0
            )
            messageTokensUsed += tokens
        }
        llmMessages.append(contentsOf: includedMessages)

        // 8. Add the new user message
        llmMessages.append(LLMMessage(role: .user, content: newMessage))

        let totalTokenEstimate = estimateTokens(for: systemPrompt) + messageTokensUsed + estimateTokens(for: newMessage)

        logger.info("Context built: \(llmMessages.count) messages, ~\(totalTokenEstimate) tokens, \(factInfos.count) facts, verbosity=\(verbosityLevel.rawValue)")

        return ContextBuildResult(
            messages: llmMessages,
            systemPrompt: systemPrompt,
            tokenEstimate: totalTokenEstimate,
            factsIncluded: factInfos.count,
            messagesIncluded: includedMessages.count,
            verbosityLevel: verbosityLevel,
            wasTruncated: includedMessages.count < recentMessages.count
        )
    }

    // MARK: - Simple Context Building (Backward Compatible)

    /// Builds a simple context from raw messages without the full integration.
    ///
    /// This preserves backward compatibility with earlier callers that don't
    /// use the full session/memory system. New code should use
    /// `buildIntegratedContext()` instead.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages to include.
    ///   - systemPrompt: An optional system prompt string.
    /// - Returns: An array of LLM messages ready for the API.
    func buildSimpleContext(
        messages: [LLMMessage],
        systemPrompt: String? = nil
    ) -> [LLMMessage] {
        var result: [LLMMessage] = []

        if let prompt = systemPrompt {
            result.append(LLMMessage(role: .system, content: prompt))
        }

        result.append(contentsOf: messages)
        return result
    }

    // MARK: - Token Estimation

    /// Estimates the number of tokens in a text string.
    ///
    /// Uses a word-based estimate: ~1.3 tokens per word for English text.
    /// This is more accurate than the naive 4-chars-per-token estimate.
    /// A more precise TokenCounter will be implemented in task 0404.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count.
    func estimateTokens(for text: String) -> Int {
        let wordCount = text.split(separator: " ").count
        // ~1.3 tokens per word for English text
        // Add 4 tokens overhead for message framing
        return max(Int(Double(wordCount) * 1.3) + 4, 1)
    }
}

// MARK: - Result Type

/// The result of building an integrated context, including assembled
/// messages and metadata about what was included.
struct ContextBuildResult: Sendable {
    /// The assembled LLM messages (not including system prompt, which is separate).
    let messages: [LLMMessage]

    /// The assembled system prompt string.
    let systemPrompt: String

    /// Estimated total tokens across system prompt and messages.
    let tokenEstimate: Int

    /// How many user facts were included in the system prompt.
    let factsIncluded: Int

    /// How many conversation messages were included (not counting the new message).
    let messagesIncluded: Int

    /// The detected verbosity level for this request.
    let verbosityLevel: VerbosityLevel

    /// Whether older messages were dropped to fit within the token budget.
    let wasTruncated: Bool
}
```

### 2. Create or Update `tests/ContextBuilderTests.swift`

Create comprehensive tests for the enhanced ContextBuilder. If a test file for ContextBuilder already exists from task 0203, add to it. Otherwise create a new one.

```swift
// ContextBuilderTests.swift
// EmberHearth
//
// Unit tests for the enhanced ContextBuilder.

import XCTest
@testable import EmberHearth

final class ContextBuilderTests: XCTestCase {

    private var builder: ContextBuilder!

    override func setUp() {
        super.setUp()
        builder = ContextBuilder(defaultTotalTokens: 10_000)
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    // MARK: - Simple Context Building (Backward Compatible)

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
        let messages = [
            LLMMessage(role: .user, content: "Hello")
        ]

        let result = builder.buildSimpleContext(messages: messages, systemPrompt: nil)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].role, .user)
    }

    // MARK: - Token Estimation

    func testTokenEstimationShortText() {
        let tokens = builder.estimateTokens(for: "Hello world")
        // 2 words * 1.3 + 4 overhead = ~6-7
        XCTAssertGreaterThan(tokens, 0)
        XCTAssertLessThan(tokens, 20)
    }

    func testTokenEstimationLongerText() {
        let text = "This is a longer piece of text that should result in a higher token count than the short one"
        let tokens = builder.estimateTokens(for: text)
        let shortTokens = builder.estimateTokens(for: "Hi")
        XCTAssertGreaterThan(tokens, shortTokens, "Longer text should have more tokens")
    }

    func testTokenEstimationEmptyText() {
        let tokens = builder.estimateTokens(for: "")
        XCTAssertGreaterThanOrEqual(tokens, 1, "Even empty text should return at least 1 token")
    }

    func testTokenEstimationWordBased() {
        // 100 words should be roughly 130-140 tokens + overhead
        let words = (0..<100).map { "word\($0)" }.joined(separator: " ")
        let tokens = builder.estimateTokens(for: words)
        XCTAssertGreaterThan(tokens, 100, "100 words should be more than 100 tokens")
        XCTAssertLessThan(tokens, 200, "100 words should be less than 200 tokens")
    }

    // MARK: - ContextBuildResult Tests

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

    // MARK: - Default Configuration

    func testDefaultTotalTokens() {
        let defaultBuilder = ContextBuilder()
        XCTAssertEqual(defaultBuilder.defaultTotalTokens, 100_000)
    }

    func testCustomTotalTokens() {
        let customBuilder = ContextBuilder(defaultTotalTokens: 50_000)
        XCTAssertEqual(customBuilder.defaultTotalTokens, 50_000)
    }
}
```

**Note:** The `buildIntegratedContext` method is async and depends on `FactRetriever` and `SessionManager` which may require database setup for testing. The tests above focus on the synchronous parts of ContextBuilder. Integration testing of `buildIntegratedContext` should use mock implementations of FactRetriever and SessionManager. If creating mocks is straightforward with existing code, add integration tests. If not, document that integration tests are needed as a follow-up.

## Implementation Notes

1. The `buildIntegratedContext` method is `async throws` because it calls into the memory and session systems which are database-backed.
2. The method signature uses concrete types (FactRetriever, SessionManager) rather than protocols for MVP simplicity. If these types are protocol-based from their respective tasks, use the protocols instead.
3. If `FactRetriever`, `SessionManager`, `SessionMessage`, or `Fact` types from prior tasks have different method names or signatures, adjust the code to match. The intent matters more than the exact API — adapt to what exists.
4. The `estimateTokens(for:)` method is a temporary implementation. Task 0404 will create a more accurate `TokenCounter`. For now, the word-based estimate is sufficient.
5. The session summary is included as an assistant message wrapped in brackets to distinguish it from actual conversation. The LLM should treat it as context, not as a previous response.
6. Messages are added newest-first during budget calculation (so recent messages are preserved), then reversed to chronological order for the LLM.

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, os).
3. All Swift files use PascalCase naming.
4. All classes and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. Preserve backward compatibility — the simple `buildSimpleContext` method must still work for existing callers.
7. If referenced types from prior tasks have different APIs than assumed here, adapt. Add comments explaining adaptations.
8. The test file path should match the existing test file pattern.

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test`)
3. There are no calls to Process(), /bin/bash, or any shell execution
4. All public methods have documentation comments
5. os.Logger is used (not print() statements)
6. The existing simple context builder method still exists and works
7. The new buildIntegratedContext method compiles (even if integration tests are deferred)
8. ContextBuildResult contains all metadata fields
9. Token estimation produces reasonable numbers (not zero, not absurd)
```

---

## Acceptance Criteria

- [ ] `src/LLM/ContextBuilder.swift` is updated with enhanced context building
- [ ] `buildIntegratedContext()` method exists with correct parameter types
- [ ] `buildSimpleContext()` backward-compatible method still exists
- [ ] Context building integrates: SystemPromptBuilder, VerbosityAdapter, FactRetriever, SessionManager
- [ ] System prompt is built with personality, facts, time context, summary, and verbosity instruction
- [ ] Verbosity is detected from the current message and recent user messages
- [ ] Facts are mapped from full `Fact` objects to `FactInfo` projections
- [ ] Recent messages respect token budget (oldest messages dropped first)
- [ ] New user message is always included as the final message
- [ ] Session summary is included as a bracketed assistant message when available
- [ ] `ContextBuildResult` struct exists with: messages, systemPrompt, tokenEstimate, factsIncluded, messagesIncluded, verbosityLevel, wasTruncated
- [ ] Token estimation uses word-based calculation (~1.3 tokens per word)
- [ ] Logging reports context assembly details (message count, token estimate, fact count, verbosity level)
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify the updated file exists
test -f src/LLM/ContextBuilder.swift && echo "ContextBuilder.swift exists" || echo "MISSING: ContextBuilder.swift"

# Verify test file exists
test -f tests/ContextBuilderTests.swift && echo "Test file exists (flat)" || test -f tests/LLM/ContextBuilderTests.swift && echo "Test file exists (nested)" || echo "MISSING: ContextBuilderTests.swift"

# Verify no shell execution
grep -rn "Process()" src/LLM/ContextBuilder.swift || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/LLM/ || echo "PASS: No /bin/bash references found"

# Verify backward-compatible method still exists
grep -n "buildSimpleContext" src/LLM/ContextBuilder.swift && echo "PASS: Backward-compatible method exists" || echo "FAIL: Missing buildSimpleContext"

# Verify new integrated method exists
grep -n "buildIntegratedContext" src/LLM/ContextBuilder.swift && echo "PASS: Integrated method exists" || echo "FAIL: Missing buildIntegratedContext"

# Verify ContextBuildResult exists
grep -n "struct ContextBuildResult" src/LLM/ContextBuilder.swift && echo "PASS: ContextBuildResult exists" || echo "FAIL: Missing ContextBuildResult"

# Build the project
swift build 2>&1

# Run context builder tests
swift test --filter ContextBuilderTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the enhanced ContextBuilder implementation for EmberHearth created in task 0402. Check for these specific issues:

@src/LLM/ContextBuilder.swift
@tests/ContextBuilderTests.swift (or tests/LLM/ContextBuilderTests.swift)

Also reference:
@src/Personality/SystemPromptBuilder.swift
@src/Personality/VerbosityAdapter.swift
@docs/research/session-management.md (Section 1: Context Budget)

1. **INTEGRATION CORRECTNESS (Critical):**
   - Does buildIntegratedContext correctly call SystemPromptBuilder.buildSystemPrompt with all parameters (userFacts, sessionSummary, currentDate, verbosityInstruction, userName)?
   - Does it correctly call VerbosityAdapter.detectVerbosity with the current message and recent user-only messages?
   - Does it correctly map Fact objects to FactInfo projections?
   - Does it correctly load session messages from SessionManager?
   - Are the method signatures compatible with the actual types from prior tasks? If there are mismatches, are they documented?

2. **CONTEXT BUDGET (Critical):**
   - Does the budget allocation match session-management.md? (10% system, 25% recent, 10% summary, 35% response)
   - When recent messages exceed their budget, are the OLDEST messages dropped (preserving recency)?
   - Is the new user message always included regardless of budget?
   - Is the session summary included within the summary budget?

3. **MESSAGE ORDERING (Important):**
   - Are messages in chronological order (oldest first) when sent to the LLM?
   - Is the session summary placed before the conversation messages?
   - Is the new user message always the last message?
   - Is there a system message, or is the system prompt separate from the messages array?

4. **BACKWARD COMPATIBILITY (Important):**
   - Does buildSimpleContext still exist and work?
   - Are there any breaking changes to the existing API that would affect M3 callers?

5. **TOKEN ESTIMATION:**
   - Is the word-based token estimate reasonable? (~1.3 tokens per word)
   - Does it handle empty strings without crashing?
   - Does it include message framing overhead?
   - Is it documented as temporary (to be replaced by task 0404's TokenCounter)?

6. **RESULT METADATA:**
   - Does ContextBuildResult contain all documented fields?
   - Is wasTruncated correctly set when messages are dropped?
   - Is the token estimate calculated across all sections?
   - Is ContextBuildResult marked Sendable?

7. **CODE QUALITY:**
   - Are all public APIs documented with /// comments?
   - Is os.Logger used consistently?
   - Are there any force-unwraps or potential crashes?
   - No Process(), /bin/bash, or shell execution?
   - Are async/throws used correctly?

8. **TEST QUALITY:**
   - Do tests cover: simple context building, token estimation, result struct, default configuration?
   - Is the lack of async integration tests documented?
   - Are edge cases tested (empty text, nil system prompt)?

Report any issues found with specific file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m5): integrate memory and session context into context builder
```

---

## Notes for Next Task

- `ContextBuilder.buildIntegratedContext()` is the primary context assembly method. Task 0403 (SummaryGenerator) will produce the `sessionSummary` that feeds into this method.
- The `estimateTokens(for:)` method is a temporary implementation using word-based estimation. Task 0404 (TokenCounter) will replace it with a more accurate implementation.
- `ContextBuildResult` provides metadata about what was included. Task 0404 will add per-section token breakdowns via a `TokenEstimates` sub-struct.
- The `buildSimpleContext()` method remains for backward compatibility. Once all callers are migrated to `buildIntegratedContext()`, it can be deprecated.
- If `FactRetriever` or `SessionManager` APIs don't exactly match what was assumed here, the Sonnet session should adapt. The key principle is: load facts, load messages, build system prompt, detect verbosity, format for LLM.
- The session summary is wrapped in brackets `[Conversation summary from earlier: ...]` to help the LLM distinguish it from actual conversation messages. This formatting may need adjustment based on testing.
