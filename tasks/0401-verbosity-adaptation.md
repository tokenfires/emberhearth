# Task 0401: Verbosity Adaptation Logic

**Milestone:** M5 - Personality & Context
**Unit:** 5.2 - Verbosity Adaptation Logic
**Phase:** 2
**Depends On:** 0400 (System Prompt and Prompt Builder)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/conversation-design.md` — Read Section 3 (Verbosity: lines ~192-314) for verbosity signals, response length calibration (MICRO/SHORT/MEDIUM/LONG), and the VerbosityModel struct sketch
2. `docs/research/personality-design.md` — Read the "Temporal Dynamics" section (lines ~73-95) for time-of-day communication patterns and the "Pragmatic Constraints" section (lines ~815-870) for why over-specification hurts performance
3. `src/Personality/EmberSystemPrompt.swift` — See the `verbosityHeader` constant and how verbosity instructions slot into the assembled prompt
4. `src/Personality/SystemPromptBuilder.swift` — See the `verbosityInstruction` parameter on `buildSystemPrompt()` which accepts the output of VerbosityAdapter
5. `CLAUDE.md` — Project conventions (PascalCase for Swift files, src/ layout, security principles)

> **Context Budget Note:** `conversation-design.md` is ~986 lines. Focus only on lines 192-314 (Section 3: Verbosity). `personality-design.md` is ~1130 lines. Focus only on lines 73-95 (Temporal Dynamics). Skip all other sections.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Verbosity Adaptation logic for EmberHearth, a native macOS personal AI assistant. This component analyzes user message patterns to determine the appropriate response length, then generates a verbosity instruction that is injected into the system prompt.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., VerbosityAdapter.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)

## What You Are Building

A `VerbosityAdapter` that:
1. Analyzes the current user message and recent message history
2. Determines a `VerbosityLevel` (terse, concise, moderate, detailed)
3. Generates a short instruction string for the LLM telling it how verbose to be

This output is passed to `SystemPromptBuilder.buildSystemPrompt(verbosityInstruction:)` from task 0400.

## Design Philosophy

From the conversation-design research:
- **Default to concise. Expand on signal.**
- Most interactions benefit from brevity. Users are busy.
- But sometimes detail is exactly what's needed — Ember should recognize those moments.
- The verbosity detection should be lightweight — a few heuristics, not a heavy ML model.

## Dependencies

This task uses a `SessionMessage` type that represents a message in the conversation history. Since this type may already exist from M4 (session management), create a minimal version if it doesn't exist yet. The VerbosityAdapter should work with whatever message type provides `text: String?` and `isFromMe: Bool` fields.

## Files to Create

### 1. `src/Personality/VerbosityAdapter.swift`

```swift
// VerbosityAdapter.swift
// EmberHearth
//
// Analyzes user message patterns to determine appropriate response verbosity.

import Foundation
import os

/// Represents the desired verbosity level for Ember's response.
///
/// Each level maps to a different instruction injected into the system prompt,
/// telling the LLM how much detail to include in its response.
enum VerbosityLevel: String, CaseIterable, Sendable {
    /// User sends very short messages ("ok", "yeah", "thanks", "k").
    /// Ember should respond in 1-2 sentences maximum.
    case terse

    /// User sends 1-2 sentence messages.
    /// Ember should keep responses to 2-4 sentences.
    case concise

    /// User sends a paragraph or asks a question requiring explanation.
    /// Ember should provide thorough but focused responses, 1-2 paragraphs.
    case moderate

    /// User asks complex questions, sends multiple paragraphs, or
    /// explicitly requests detail ("explain", "give me details", "walk me through").
    /// Ember should provide comprehensive responses with structure if helpful.
    case detailed
}

/// Analyzes user message patterns and determines the appropriate response
/// verbosity level for the current interaction.
///
/// The adapter uses lightweight heuristics based on:
/// - Current message length (character count)
/// - Current message content (explicit verbosity cues)
/// - Recent message history (pattern detection across last few messages)
///
/// Usage:
/// ```swift
/// let adapter = VerbosityAdapter()
/// let level = adapter.detectVerbosity(
///     from: "Hey what's up",
///     recentUserMessages: recentMessages
/// )
/// let instruction = adapter.instruction(for: level)
/// // Pass instruction to SystemPromptBuilder.buildSystemPrompt(verbosityInstruction:)
/// ```
final class VerbosityAdapter {

    // MARK: - Constants

    /// Character count threshold for "terse" messages.
    /// Messages at or below this length suggest the user wants brief responses.
    static let terseThreshold: Int = 15

    /// Character count threshold for "concise" messages.
    /// Messages between terse and concise thresholds get concise responses.
    static let conciseThreshold: Int = 80

    /// Character count threshold for "moderate" messages.
    /// Messages between concise and moderate get moderate responses.
    static let moderateThreshold: Int = 300

    /// Number of recent messages to consider for pattern detection.
    static let recentHistoryWindow: Int = 5

    /// Logger for verbosity detection.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "VerbosityAdapter"
    )

    // MARK: - Explicit Cue Words

    /// Words/phrases that signal the user wants a brief response.
    private static let brevityCues: Set<String> = [
        "briefly", "brief", "tldr", "tl;dr", "short", "quick",
        "in a word", "one word", "yes or no", "just tell me",
        "bottom line", "sum up", "summarize"
    ]

    /// Words/phrases that signal the user wants a detailed response.
    private static let detailCues: Set<String> = [
        "explain", "details", "detailed", "elaborate", "tell me more",
        "walk me through", "how does", "why does", "in depth",
        "break it down", "step by step", "thoroughly", "comprehensive",
        "everything about", "all about"
    ]

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Detects the appropriate verbosity level for the current message.
    ///
    /// Detection uses three signals, weighted by priority:
    /// 1. **Explicit cues** (highest priority) — Words like "briefly" or "explain"
    ///    directly indicate desired verbosity. These override all other signals.
    /// 2. **Current message length** — Short messages suggest brief responses;
    ///    long messages suggest the user is comfortable with detail.
    /// 3. **Recent pattern** — If the user's last few messages have been
    ///    consistently short, Ember should stay brief even if the current
    ///    message is medium-length.
    ///
    /// - Parameters:
    ///   - message: The current user message text.
    ///   - recentUserMessages: The last N messages from the user (not including
    ///     the current message). Only user messages (not Ember's responses)
    ///     should be included. Pass an empty array for the first message.
    /// - Returns: The detected `VerbosityLevel`.
    func detectVerbosity(
        from message: String,
        recentUserMessages: [String]
    ) -> VerbosityLevel {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Priority 1: Check for explicit verbosity cues
        if let explicitLevel = detectExplicitCues(in: trimmedMessage) {
            logger.debug("Verbosity: explicit cue detected -> \(explicitLevel.rawValue)")
            return explicitLevel
        }

        // Priority 2: Check if the message contains a question
        let hasQuestion = detectQuestionComplexity(in: trimmedMessage)

        // Priority 3: Current message length
        let lengthLevel = detectFromLength(trimmedMessage.count)

        // Priority 4: Recent message pattern
        let patternLevel = detectFromPattern(recentUserMessages)

        // Combine signals
        let finalLevel = combineLevels(
            lengthLevel: lengthLevel,
            patternLevel: patternLevel,
            hasComplexQuestion: hasQuestion
        )

        logger.debug("Verbosity: length=\(lengthLevel.rawValue), pattern=\(patternLevel?.rawValue ?? "none"), question=\(hasQuestion), final=\(finalLevel.rawValue)")
        return finalLevel
    }

    /// Returns the system prompt instruction string for a given verbosity level.
    ///
    /// These instructions are injected into the system prompt by the
    /// SystemPromptBuilder to guide the LLM's response length.
    ///
    /// - Parameter level: The detected verbosity level.
    /// - Returns: An instruction string for the LLM.
    func instruction(for level: VerbosityLevel) -> String {
        switch level {
        case .terse:
            return "Respond in 1-2 sentences maximum. Be direct. No bullet points or lists."
        case .concise:
            return "Keep your response to 2-4 sentences. Be helpful but brief."
        case .moderate:
            return "Provide a thorough but focused response. 1-2 short paragraphs. Use structure only if it genuinely helps."
        case .detailed:
            return "Provide a comprehensive response with explanation. Use structure (short lists or paragraphs) if it helps clarity. Don't pad — be thorough but not redundant."
        }
    }

    // MARK: - Private Detection Methods

    /// Checks for explicit verbosity cue words in the message.
    ///
    /// - Parameter message: The user's message text.
    /// - Returns: A `VerbosityLevel` if explicit cues are found, nil otherwise.
    private func detectExplicitCues(in message: String) -> VerbosityLevel? {
        let lowercased = message.lowercased()

        // Check for brevity cues
        for cue in Self.brevityCues {
            if lowercased.contains(cue) {
                return .terse
            }
        }

        // Check for detail cues
        for cue in Self.detailCues {
            if lowercased.contains(cue) {
                return .detailed
            }
        }

        return nil
    }

    /// Detects whether the message contains complex questions.
    ///
    /// A "complex question" is one that likely requires more than a
    /// one-sentence answer: multiple questions, "why" questions,
    /// "how" questions, or comparison requests.
    ///
    /// - Parameter message: The user's message text.
    /// - Returns: True if the message contains complex question patterns.
    private func detectQuestionComplexity(in message: String) -> Bool {
        let lowercased = message.lowercased()

        // Multiple question marks suggest multiple questions
        let questionMarkCount = message.filter { $0 == "?" }.count
        if questionMarkCount > 1 {
            return true
        }

        // "Why" and "how" questions typically need more explanation
        let complexPatterns = ["why ", "why?", "how do", "how does", "how can",
                               "how would", "what's the difference", "compare",
                               "pros and cons", "advantages", "disadvantages",
                               "what are the", "can you explain"]
        for pattern in complexPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }

        return false
    }

    /// Determines verbosity level from message character count.
    ///
    /// - Parameter characterCount: The length of the current message.
    /// - Returns: The verbosity level based on length alone.
    private func detectFromLength(_ characterCount: Int) -> VerbosityLevel {
        switch characterCount {
        case 0...Self.terseThreshold:
            return .terse
        case (Self.terseThreshold + 1)...Self.conciseThreshold:
            return .concise
        case (Self.conciseThreshold + 1)...Self.moderateThreshold:
            return .moderate
        default:
            return .detailed
        }
    }

    /// Detects verbosity preference from recent message history.
    ///
    /// If the user's recent messages are consistently short, they
    /// prefer brevity even if the current message is longer than usual.
    ///
    /// - Parameter recentMessages: Recent user messages (text only).
    /// - Returns: A pattern-based verbosity level, or nil if no clear pattern.
    private func detectFromPattern(_ recentMessages: [String]) -> VerbosityLevel? {
        let window = recentMessages.suffix(Self.recentHistoryWindow)
        guard window.count >= 3 else { return nil }

        let averageLength = window
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).count }
            .reduce(0, +) / window.count

        // If the last several messages have been very short, the user prefers brevity
        if averageLength <= Self.terseThreshold {
            return .terse
        } else if averageLength <= Self.conciseThreshold {
            return .concise
        }

        return nil
    }

    /// Combines multiple verbosity signals into a final level.
    ///
    /// Rules:
    /// - If there's a complex question, bump up at least to moderate
    /// - If the pattern says terse but the message is longer, trust the message
    /// - If the pattern says terse and the message is short, stay terse
    ///
    /// - Parameters:
    ///   - lengthLevel: Level from message length analysis.
    ///   - patternLevel: Level from recent history pattern (optional).
    ///   - hasComplexQuestion: Whether the message contains complex questions.
    /// - Returns: The combined verbosity level.
    private func combineLevels(
        lengthLevel: VerbosityLevel,
        patternLevel: VerbosityLevel?,
        hasComplexQuestion: Bool
    ) -> VerbosityLevel {
        var level = lengthLevel

        // If user has a consistent pattern, bias toward it
        if let pattern = patternLevel {
            // Average the two signals: if pattern is terse but message is moderate,
            // settle on concise
            let lengthOrdinal = Self.ordinal(for: lengthLevel)
            let patternOrdinal = Self.ordinal(for: pattern)
            let averaged = (lengthOrdinal + patternOrdinal) / 2
            level = Self.level(for: averaged)
        }

        // Complex questions bump up to at least moderate
        if hasComplexQuestion && Self.ordinal(for: level) < Self.ordinal(for: .moderate) {
            level = .moderate
        }

        return level
    }

    /// Maps a VerbosityLevel to an ordinal for numeric comparison.
    private static func ordinal(for level: VerbosityLevel) -> Int {
        switch level {
        case .terse: return 0
        case .concise: return 1
        case .moderate: return 2
        case .detailed: return 3
        }
    }

    /// Maps an ordinal back to a VerbosityLevel.
    private static func level(for ordinal: Int) -> VerbosityLevel {
        switch ordinal {
        case 0: return .terse
        case 1: return .concise
        case 2: return .moderate
        case 3: return .detailed
        default: return ordinal < 0 ? .terse : .detailed
        }
    }
}
```

### 2. `tests/VerbosityAdapterTests.swift`

Create the test file. If existing tests are in `tests/` (flat), place it there. If subdirectories are used, place at `tests/Personality/VerbosityAdapterTests.swift`.

```swift
// VerbosityAdapterTests.swift
// EmberHearth
//
// Unit tests for VerbosityAdapter.

import XCTest
@testable import EmberHearth

final class VerbosityAdapterTests: XCTestCase {

    private var adapter: VerbosityAdapter!

    override func setUp() {
        super.setUp()
        adapter = VerbosityAdapter()
    }

    override func tearDown() {
        adapter = nil
        super.tearDown()
    }

    // MARK: - VerbosityLevel Enum Tests

    func testVerbosityLevelAllCases() {
        XCTAssertEqual(VerbosityLevel.allCases.count, 4)
        XCTAssertTrue(VerbosityLevel.allCases.contains(.terse))
        XCTAssertTrue(VerbosityLevel.allCases.contains(.concise))
        XCTAssertTrue(VerbosityLevel.allCases.contains(.moderate))
        XCTAssertTrue(VerbosityLevel.allCases.contains(.detailed))
    }

    // MARK: - Short Message Detection

    func testVeryShortMessageReturnsTerse() {
        let level = adapter.detectVerbosity(from: "ok", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testSingleWordReturnsTerse() {
        let level = adapter.detectVerbosity(from: "thanks", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testShortAcknowledgmentReturnsTerse() {
        let level = adapter.detectVerbosity(from: "yeah", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testSingleEmojiReturnsTerse() {
        let level = adapter.detectVerbosity(from: "👍", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    // MARK: - Medium Message Detection

    func testOneSentenceReturnsConcise() {
        let level = adapter.detectVerbosity(from: "What time is my dentist appointment?", recentUserMessages: [])
        XCTAssertEqual(level, .concise)
    }

    func testSimpleQuestionReturnsConcise() {
        let level = adapter.detectVerbosity(from: "Can you remind me to call mom tonight?", recentUserMessages: [])
        XCTAssertEqual(level, .concise)
    }

    // MARK: - Longer Message Detection

    func testParagraphReturnsModerate() {
        let message = "I've been thinking about switching jobs. My current role is fine but I feel like I'm stagnating. I don't have any particular leads yet but I wanted to start thinking about what I'd want in a new position."
        let level = adapter.detectVerbosity(from: message, recentUserMessages: [])
        XCTAssertEqual(level, .moderate)
    }

    func testVeryLongMessageReturnsDetailed() {
        let message = String(repeating: "This is a longer message with multiple thoughts and considerations. ", count: 10)
        let level = adapter.detectVerbosity(from: message, recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    // MARK: - Explicit Cue Detection

    func testBriefCueReturnsTerse() {
        let level = adapter.detectVerbosity(from: "Give me a brief summary of what we discussed", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testTldrCueReturnsTerse() {
        let level = adapter.detectVerbosity(from: "What's the tldr on that article?", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testExplainCueReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Can you explain how that works?", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    func testDetailsCueReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Give me the details", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    func testWalkMeThroughReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Walk me through the process", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    func testStepByStepReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Can you give me step by step instructions?", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    // MARK: - Complex Question Detection

    func testMultipleQuestionsReturnsModerate() {
        let level = adapter.detectVerbosity(from: "What should I wear? Is it going to rain?", recentUserMessages: [])
        // Multiple questions bump to at least moderate
        XCTAssertTrue(level == .moderate || level == .detailed)
    }

    func testWhyQuestionBumpsUp() {
        let level = adapter.detectVerbosity(from: "Why does that happen?", recentUserMessages: [])
        XCTAssertTrue(level == .moderate || level == .detailed, "Why questions should be at least moderate")
    }

    func testHowDoesQuestionBumpsUp() {
        let level = adapter.detectVerbosity(from: "How does the memory system work?", recentUserMessages: [])
        XCTAssertTrue(level == .moderate || level == .detailed, "How-does questions should be at least moderate")
    }

    func testCompareQuestionBumpsUp() {
        let level = adapter.detectVerbosity(from: "Compare these two options", recentUserMessages: [])
        XCTAssertTrue(level == .moderate || level == .detailed, "Comparison requests should be at least moderate")
    }

    // MARK: - Recent History Pattern Detection

    func testConsistentlyShortHistoryBiasesToTerse() {
        let recentMessages = ["ok", "yeah", "sure", "k", "got it"]
        let level = adapter.detectVerbosity(from: "sounds good", recentUserMessages: recentMessages)
        XCTAssertEqual(level, .terse, "User with consistently short messages should get terse responses")
    }

    func testConsistentlyShortHistoryWithLongerCurrentMessage() {
        let recentMessages = ["ok", "yeah", "sure", "k", "got it"]
        let level = adapter.detectVerbosity(
            from: "Can you help me plan my schedule for tomorrow afternoon?",
            recentUserMessages: recentMessages
        )
        // Should be somewhere between terse (pattern) and concise (message length)
        XCTAssertTrue(level == .terse || level == .concise,
                       "Should balance between short history pattern and longer current message")
    }

    func testNoHistoryUsesCurrentMessageOnly() {
        let level = adapter.detectVerbosity(from: "What's the weather?", recentUserMessages: [])
        XCTAssertEqual(level, .concise)
    }

    func testInsufficientHistoryIgnoresPattern() {
        // Only 2 messages — below the threshold of 3
        let recentMessages = ["ok", "yeah"]
        let level = adapter.detectVerbosity(
            from: "What's going on this weekend? Any events nearby?",
            recentUserMessages: recentMessages
        )
        // Should rely on message length/content, not pattern
        XCTAssertTrue(level == .concise || level == .moderate)
    }

    // MARK: - Instruction Generation

    func testTerseInstructionContent() {
        let instruction = adapter.instruction(for: .terse)
        XCTAssertTrue(instruction.contains("1-2 sentences"), "Terse instruction should mention 1-2 sentences")
        XCTAssertTrue(instruction.lowercased().contains("direct"), "Terse instruction should mention directness")
    }

    func testConciseInstructionContent() {
        let instruction = adapter.instruction(for: .concise)
        XCTAssertTrue(instruction.contains("2-4 sentences"), "Concise instruction should mention 2-4 sentences")
    }

    func testModerateInstructionContent() {
        let instruction = adapter.instruction(for: .moderate)
        XCTAssertTrue(instruction.lowercased().contains("thorough"), "Moderate instruction should mention thoroughness")
    }

    func testDetailedInstructionContent() {
        let instruction = adapter.instruction(for: .detailed)
        XCTAssertTrue(instruction.lowercased().contains("comprehensive"), "Detailed instruction should mention comprehensiveness")
    }

    func testInstructionsAreReasonablyShort() {
        for level in VerbosityLevel.allCases {
            let instruction = adapter.instruction(for: level)
            XCTAssertLessThan(instruction.count, 200,
                              "Instruction for \(level.rawValue) should be concise (under 200 chars)")
        }
    }

    // MARK: - Edge Cases

    func testEmptyMessageReturnsTerse() {
        let level = adapter.detectVerbosity(from: "", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testWhitespaceOnlyMessageReturnsTerse() {
        let level = adapter.detectVerbosity(from: "   \n\t  ", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testExplicitCueOverridesMessageLength() {
        // Long message but with explicit "briefly" cue
        let longMessage = "I have a lot of thoughts about this topic but can you briefly summarize the key takeaway from our earlier discussion about the project timeline and deliverables?"
        let level = adapter.detectVerbosity(from: longMessage, recentUserMessages: [])
        XCTAssertEqual(level, .terse, "Explicit brevity cue should override message length")
    }

    func testExplicitDetailCueOverridesShortHistory() {
        let recentMessages = ["ok", "yeah", "sure", "k", "got it"]
        let level = adapter.detectVerbosity(from: "explain how that works", recentUserMessages: recentMessages)
        XCTAssertEqual(level, .detailed, "Explicit detail cue should override short message history")
    }
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, os).
3. All Swift files use PascalCase naming.
4. All classes and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. The VerbosityAdapter should be stateless — it does not store conversation history internally. It receives recent messages as a parameter each time.
7. The test file path should match the existing test file pattern. Check where `tests/EmberSystemPromptTests.swift` was placed and match that location pattern.

## Directory Structure

Create these files:
- `src/Personality/VerbosityAdapter.swift`
- `tests/VerbosityAdapterTests.swift` (or `tests/Personality/VerbosityAdapterTests.swift` if subdirectories are used)

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test`)
3. There are no calls to Process(), /bin/bash, or any shell execution
4. All public methods have documentation comments
5. os.Logger is used (not print() statements)
6. VerbosityAdapter is stateless — no stored mutable state
7. Explicit cues override all other signals
8. The `instruction(for:)` method returns concise, clear LLM instructions
9. Edge cases handled: empty string, whitespace-only, single emoji
```

---

## Acceptance Criteria

- [ ] `src/Personality/VerbosityAdapter.swift` exists with `VerbosityAdapter` class
- [ ] `VerbosityLevel` enum exists with four cases: `terse`, `concise`, `moderate`, `detailed`
- [ ] `VerbosityLevel` conforms to `CaseIterable` and `Sendable`
- [ ] `detectVerbosity(from:recentUserMessages:)` method correctly classifies messages
- [ ] Short messages ("ok", "yeah", "thanks") return `terse`
- [ ] One-sentence questions return `concise`
- [ ] Paragraph-length messages return `moderate`
- [ ] Very long messages or multi-paragraph return `detailed`
- [ ] Explicit brevity cues ("briefly", "tldr") override message length and return `terse`
- [ ] Explicit detail cues ("explain", "walk me through") override and return `detailed`
- [ ] Complex questions ("why", "how does", multiple "?") bump level to at least `moderate`
- [ ] Recent message history pattern influences detection (consistently short = bias to terse)
- [ ] Pattern detection requires at least 3 recent messages before activating
- [ ] `instruction(for:)` returns clear, concise LLM instruction strings under 200 characters
- [ ] Empty message and whitespace-only return `terse`
- [ ] VerbosityAdapter is stateless (no mutable stored properties)
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Personality/VerbosityAdapter.swift && echo "VerbosityAdapter.swift exists" || echo "MISSING: VerbosityAdapter.swift"

# Verify test file exists
test -f tests/VerbosityAdapterTests.swift && echo "Test file exists (flat)" || test -f tests/Personality/VerbosityAdapterTests.swift && echo "Test file exists (nested)" || echo "MISSING: VerbosityAdapterTests.swift"

# Verify no shell execution
grep -rn "Process()" src/Personality/VerbosityAdapter.swift || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/Personality/ || echo "PASS: No /bin/bash references found"

# Verify the adapter is stateless (no var stored properties in the class)
grep -n "private var\|var " src/Personality/VerbosityAdapter.swift | grep -v "func\|let\|//\|static\|local" && echo "WARNING: Check for mutable stored properties" || echo "OK: Appears stateless"

# Build the project
swift build 2>&1

# Run just the verbosity tests
swift test --filter VerbosityAdapterTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the VerbosityAdapter implementation created in task 0401 for EmberHearth. Check for these specific issues:

@src/Personality/VerbosityAdapter.swift
@tests/VerbosityAdapterTests.swift (or tests/Personality/VerbosityAdapterTests.swift)

Also reference:
@docs/research/conversation-design.md (Section 3: Verbosity)
@src/Personality/EmberSystemPrompt.swift (the verbosityHeader constant)
@src/Personality/SystemPromptBuilder.swift (the verbosityInstruction parameter)

1. **DETECTION ACCURACY (Critical):**
   - Does "ok" correctly return terse? Does "yeah" return terse? Does "👍" return terse?
   - Does a simple question ("What time is my flight?") return concise?
   - Does a paragraph return moderate?
   - Does a very long multi-paragraph message return detailed?
   - Do explicit cues ("briefly", "tldr") correctly override message length?
   - Do explicit detail cues ("explain", "walk me through", "step by step") correctly return detailed?
   - Do "why" and "how does" questions bump to at least moderate?
   - Do multiple question marks trigger the complex question path?

2. **INTEGRATION WITH SYSTEMPROMPTBUILDER (Important):**
   - Does the `instruction(for:)` output match what `SystemPromptBuilder.buildSystemPrompt(verbosityInstruction:)` expects?
   - Are the instruction strings reasonable LLM directives (not too long, not too vague)?
   - Verify the instruction strings don't contain immersion-breaking language that conflicts with Ember's personality

3. **PATTERN DETECTION (Important):**
   - Does the recent history pattern require at least 3 messages before activating?
   - Does consistently short history bias toward terse?
   - Is the pattern appropriately combined with the current message (not completely overriding it)?
   - Are only user messages considered (not Ember's responses)?

4. **EDGE CASES:**
   - Empty string input returns terse?
   - Whitespace-only input returns terse?
   - Single emoji returns terse?
   - Very long message with "briefly" cue returns terse (explicit cue wins)?
   - Short message with "explain" returns detailed (explicit cue wins)?

5. **CODE QUALITY:**
   - Is VerbosityAdapter stateless? (No mutable stored properties)
   - Is VerbosityLevel marked Sendable and CaseIterable?
   - Are all public APIs documented with /// comments?
   - Is os.Logger used consistently?
   - Are there any force-unwraps or potential crashes?
   - No Process(), /bin/bash, or shell execution?

6. **TEST QUALITY:**
   - Do tests cover all four verbosity levels?
   - Do tests cover all explicit cue paths?
   - Do tests cover the complex question detection?
   - Do tests cover pattern detection with sufficient and insufficient history?
   - Do tests verify that explicit cues override other signals?
   - Do tests verify instruction content is reasonable?
   - Do tests cover edge cases (empty, whitespace, emoji)?

Report any issues found with specific file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m5): add verbosity adaptation for response length matching
```

---

## Notes for Next Task

- `VerbosityAdapter.detectVerbosity(from:recentUserMessages:)` takes raw message strings. The caller (ContextBuilder in task 0402) should extract user message text from the session history and pass it in.
- `VerbosityAdapter.instruction(for:)` returns a string that should be passed to `SystemPromptBuilder.buildSystemPrompt(verbosityInstruction:)`.
- The adapter is intentionally stateless. It does not track state between calls. All state (recent messages) is passed in by the caller.
- The threshold constants (`terseThreshold`, `conciseThreshold`, `moderateThreshold`) are static and may need tuning based on real-world testing. They can be adjusted without changing the API.
- The explicit cue word lists (`brevityCues`, `detailCues`) may need expansion based on user testing. New cues can be added without changing the detection logic.
- Future enhancement: the adapter could learn per-user verbosity preferences over time and store them in the memory system. For MVP, static heuristics are sufficient.
