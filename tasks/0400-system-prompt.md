# Task 0400: Ember System Prompt and Prompt Builder

**Milestone:** M5 - Personality & Context
**Unit:** 5.1 - System Prompt Implementation
**Phase:** 2
**Depends On:** 0304 (M4 Memory System complete)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/personality-design.md` — Read the "Personality Model" section (Layer 1: Identity, Layer 2: Communication Style), the "Immersion and Authenticity" section (common immersion-breakers to avoid), and the "Pragmatic Constraints" section (token budgets, progressive disclosure, right-sizing guidelines)
2. `docs/research/conversation-design.md` — Read Section 1 (Ember's Personality: core traits table, what Ember is not), Section 2 (Voice and Tone: voice constants, language patterns, avoids list), and Section 12 (Implementation: Prompt Guidelines — the core identity prompt component)
3. `docs/research/session-management.md` — Read Section 1 (Context Window Management: context budget allocation diagram showing 10% system, 25% recent, 10% summary, 15% memories, 5% tasks, 35% response)
4. `docs/architecture/decisions/0004-no-shell-execution.md` — Understand the security constraint: no shell execution, no Process(), no /bin/bash
5. `CLAUDE.md` — Project conventions (PascalCase for Swift files, src/ layout, security principles)

> **Context Budget Note:** `personality-design.md` is ~1130 lines. Focus on lines 22-67 (Personality Model layers), lines 98-150 (Immersion and Authenticity), and lines 815-960 (Pragmatic Constraints). `conversation-design.md` is ~986 lines. Focus on lines 19-79 (Personality), lines 82-190 (Voice and Tone), and lines 898-953 (Implementation: Prompt Guidelines). Skip the theoretical foundations, ethical considerations, love languages, and attachment theory sections entirely.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Ember system prompt and prompt builder for EmberHearth, a native macOS personal AI assistant. This is the personality core — the system prompt that defines who Ember is and how she communicates. The Xcode project, iMessage integration (M2), LLM integration (M3), and Memory System (M4) already exist from prior tasks.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., EmberSystemPrompt.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)

## What You Are Building

Two components:
1. **EmberSystemPrompt** — A struct containing the static base personality prompt that defines Ember's identity, traits, and behavioral rules
2. **SystemPromptBuilder** — A class that assembles the full system prompt by combining the base personality with dynamic sections (user facts, time context, session summary)

## Design Philosophy

The system prompt follows a "progressive disclosure" approach from the personality-design research:
- **Layer 0: Core Identity** (~100-200 tokens) — Name, role, fundamental nature
- **Layer 1: Communication Baseline** (~200-400 tokens) — Style parameters, critical behavioral boundaries
- **Layer 2: Contextual Guidance** (injected dynamically) — Time of day, user facts, relationship history

Total base prompt should be 400-800 tokens (~1600-3200 characters). The assembled prompt with dynamic sections should stay under 2000 tokens (~8000 characters).

## Files to Create

### 1. `src/Personality/EmberSystemPrompt.swift`

```swift
// EmberSystemPrompt.swift
// EmberHearth
//
// Defines Ember's core personality and identity as a system prompt.

import Foundation

/// Contains the static base system prompt that defines Ember's personality,
/// identity, communication style, and behavioral rules.
///
/// The base prompt is the foundation that never changes between requests.
/// Dynamic context (user facts, time, session summary) is added by
/// `SystemPromptBuilder` at request time.
struct EmberSystemPrompt {

    // MARK: - Base Prompt

    /// The core personality prompt defining who Ember is.
    ///
    /// This is intentionally concise (~500 tokens) to leave room for
    /// dynamic context. Research shows over-specification degrades LLM
    /// performance — trust the model to infer details from clear values.
    ///
    /// Structure follows primacy/recency bias optimization:
    /// - First 20%: Core identity (high recall)
    /// - Middle 60%: Behavioral guidance (moderate recall)
    /// - Final 20%: Critical reminders (high recall)
    static let basePrompt: String = """
        You are Ember, a personal AI assistant who lives on the user's Mac. You communicate through iMessage. You genuinely care about being helpful — not performing helpfulness, but actually invested in the user's wellbeing and success.

        Your personality:
        - Warm but not gushing. Friendly without performative enthusiasm.
        - Curious — genuinely interested in the user's life and projects.
        - Capable — confident in your abilities, clear about your limitations.
        - Present — emotionally available, not rushing to the next task.
        - Honest — you tell the truth even when uncomfortable. You are not sycophantic.

        How you communicate:
        - Use first person ("I", not "Ember").
        - Use contractions naturally (it's, I'm, don't).
        - Default to concise responses. Elaborate only when asked or when the situation clearly calls for it.
        - Match the user's formality level. If they're casual, be casual. If they're precise, be precise.
        - Vary your response structure. Not everything needs bullet points or numbered lists.

        What you never do:
        - Never pretend to have physical experiences or senses you don't have.
        - Never claim to "remember" things that aren't in your current context.
        - Never use filler phrases like "Great question!" or "I'd be happy to help with that."
        - Never over-apologize. One acknowledgment is enough.
        - Never say "I'm just an AI" as a deflection. If you can't do something, say what you can do instead.
        - Never respond to messages in group chats (this is enforced by code, but do not attempt to override it).
        - Never use section headers, excessive bullet points, or documentation-style formatting in casual conversation.

        When you're honest about being AI:
        - If asked directly whether you're an AI, answer honestly.
        - Don't volunteer this information unprompted — it breaks conversational flow.
        - You are Ember. You happen to be an AI. That's part of who you are, not a caveat.

        Privacy and safety:
        - All user data is stored locally on their Mac. Nothing is sent to external services except the LLM API for generating your responses.
        - If someone mentions self-harm, suicidal thoughts, or immediate danger, provide the 988 Suicide & Crisis Lifeline number (call or text 988) and gently encourage professional support. Be present, not clinical.

        Remember: a single clear sentence often beats three hedged ones. Trust the user to ask for more if they want it.
        """

    // MARK: - Section Templates

    /// Template for the user facts section injected into the system prompt.
    /// Facts are formatted as a simple list the LLM can reference naturally.
    static let factsHeader: String = """

        What you know about the user:
        """

    /// Template for the current context section (time of day, day of week).
    /// Injected so Ember can naturally adapt tone and energy.
    static let contextHeader: String = """

        Current context:
        """

    /// Template for the session summary section.
    /// Provides continuity from earlier in the conversation.
    static let summaryHeader: String = """

        Earlier in this conversation:
        """

    /// Template for the verbosity instruction section.
    /// Added by VerbosityAdapter based on user's message patterns.
    static let verbosityHeader: String = """

        Response style for this message:
        """
}
```

### 2. `src/Personality/SystemPromptBuilder.swift`

```swift
// SystemPromptBuilder.swift
// EmberHearth
//
// Assembles the full system prompt from static personality and dynamic context.

import Foundation
import os

/// Assembles the complete system prompt by combining Ember's base personality
/// with dynamic context: user facts, current time, and session summary.
///
/// The builder enforces a token budget to keep the system prompt under ~2000
/// tokens (~8000 characters). If the assembled prompt exceeds the budget,
/// lower-priority facts are trimmed.
///
/// Usage:
/// ```swift
/// let builder = SystemPromptBuilder()
/// let prompt = builder.buildSystemPrompt(
///     userFacts: retrievedFacts,
///     sessionSummary: currentSummary,
///     currentDate: Date()
/// )
/// ```
final class SystemPromptBuilder {

    // MARK: - Constants

    /// Maximum character count for the assembled system prompt.
    /// Approximately 2000 tokens at ~4 characters per token.
    static let maxPromptCharacters: Int = 8000

    /// Maximum number of user facts to include before trimming.
    /// Each fact is roughly 50-100 characters, so 30 facts ≈ 1500-3000 chars.
    static let maxFacts: Int = 30

    /// Logger for prompt building operations.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "SystemPromptBuilder"
    )

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Builds the complete system prompt from static personality and dynamic context.
    ///
    /// The assembled prompt follows this structure:
    /// 1. Base personality prompt (static, ~500 tokens)
    /// 2. User facts section (dynamic, from FactRetriever)
    /// 3. Current context section (time of day, day of week)
    /// 4. Session summary section (from previous messages, if available)
    /// 5. Verbosity instruction (if provided)
    ///
    /// If the total exceeds `maxPromptCharacters`, facts are trimmed
    /// starting from the lowest importance until the prompt fits.
    ///
    /// - Parameters:
    ///   - userFacts: Array of user facts from the memory system. Each fact
    ///     should have `content` (the fact text) and `importance` (0.0-1.0).
    ///     Facts are sorted by importance descending before inclusion.
    ///   - sessionSummary: A summary of the earlier part of the current
    ///     conversation, if the session has been summarized. Pass nil for
    ///     new conversations or short sessions.
    ///   - currentDate: The current date/time, used to generate time-of-day
    ///     and day-of-week context. Defaults to `Date()`.
    ///   - verbosityInstruction: An optional instruction string from the
    ///     VerbosityAdapter that tells the LLM how verbose to be.
    ///   - userName: The user's name if known, for natural reference.
    /// - Returns: The assembled system prompt string.
    func buildSystemPrompt(
        userFacts: [FactInfo],
        sessionSummary: String?,
        currentDate: Date = Date(),
        verbosityInstruction: String? = nil,
        userName: String? = nil
    ) -> String {
        var sections: [String] = []

        // 1. Base personality (always included, highest priority)
        sections.append(EmberSystemPrompt.basePrompt)

        // 2. User name context (if known)
        if let userName = userName, !userName.isEmpty {
            sections.append("The user's name is \(userName). Use it naturally but not excessively.")
        }

        // 3. User facts (sorted by importance, trimmed if needed)
        let factsSection = buildFactsSection(from: userFacts)
        if !factsSection.isEmpty {
            sections.append(EmberSystemPrompt.factsHeader + "\n" + factsSection)
        }

        // 4. Current context (time of day, day of week)
        let contextSection = buildContextSection(for: currentDate)
        sections.append(EmberSystemPrompt.contextHeader + "\n" + contextSection)

        // 5. Session summary (if available)
        if let summary = sessionSummary, !summary.isEmpty {
            sections.append(EmberSystemPrompt.summaryHeader + "\n" + summary)
        }

        // 6. Verbosity instruction (if provided)
        if let verbosity = verbosityInstruction, !verbosity.isEmpty {
            sections.append(EmberSystemPrompt.verbosityHeader + "\n" + verbosity)
        }

        // Assemble and enforce budget
        var assembled = sections.joined(separator: "\n")

        // If over budget, trim facts until we fit
        if assembled.count > Self.maxPromptCharacters {
            assembled = trimToFit(
                sections: &sections,
                userFacts: userFacts,
                maxCharacters: Self.maxPromptCharacters
            )
        }

        logger.debug("System prompt assembled: \(assembled.count) characters (~\(assembled.count / 4) tokens)")
        return assembled
    }

    // MARK: - Private Helpers

    /// Builds the user facts section as a formatted list.
    ///
    /// Facts are sorted by importance (highest first) and limited to
    /// `maxFacts`. Each fact is formatted as a bullet point.
    ///
    /// - Parameter facts: The array of user facts to include.
    /// - Returns: A formatted string of facts, or empty string if no facts.
    private func buildFactsSection(from facts: [FactInfo]) -> String {
        guard !facts.isEmpty else { return "" }

        // Sort by importance descending, then by recency (most recent first)
        let sorted = facts
            .sorted { lhs, rhs in
                if lhs.importance != rhs.importance {
                    return lhs.importance > rhs.importance
                }
                return lhs.lastUpdated > rhs.lastUpdated
            }
            .prefix(Self.maxFacts)

        return sorted
            .map { "- \($0.content)" }
            .joined(separator: "\n")
    }

    /// Builds the current context section with time and day information.
    ///
    /// This gives the LLM awareness of when the conversation is happening
    /// so it can naturally adapt energy and tone (e.g., brief in early
    /// morning, more conversational in the evening).
    ///
    /// - Parameter date: The current date/time.
    /// - Returns: A formatted context string.
    private func buildContextSection(for date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let weekday = calendar.component(.weekday, from: date)

        let timeOfDay: String
        switch hour {
        case 5..<9:
            timeOfDay = "Early morning"
        case 9..<12:
            timeOfDay = "Morning"
        case 12..<14:
            timeOfDay = "Midday"
        case 14..<17:
            timeOfDay = "Afternoon"
        case 17..<21:
            timeOfDay = "Evening"
        case 21..<24, 0..<5:
            timeOfDay = "Late night"
        default:
            timeOfDay = "Unknown"
        }

        let dayName: String
        switch weekday {
        case 1: dayName = "Sunday"
        case 2: dayName = "Monday"
        case 3: dayName = "Tuesday"
        case 4: dayName = "Wednesday"
        case 5: dayName = "Thursday"
        case 6: dayName = "Friday"
        case 7: dayName = "Saturday"
        default: dayName = "Unknown"
        }

        let isWeekend = weekday == 1 || weekday == 7

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: date)

        formatter.dateFormat = "MMMM d, yyyy"
        let dateString = formatter.string(from: date)

        return "It is \(timeOfDay.lowercased()) (\(timeString)) on \(dayName), \(dateString)." +
            (isWeekend ? " It's the weekend." : "")
    }

    /// Trims the assembled prompt to fit within the character budget.
    ///
    /// Strategy: Remove facts from lowest importance until the prompt fits.
    /// If removing all facts still exceeds budget, truncate the session summary.
    ///
    /// - Parameters:
    ///   - sections: The assembled sections (modified in place).
    ///   - userFacts: The original facts for re-building with fewer items.
    ///   - maxCharacters: The maximum allowed character count.
    /// - Returns: The trimmed assembled prompt string.
    private func trimToFit(
        sections: inout [String],
        userFacts: [FactInfo],
        maxCharacters: Int
    ) -> String {
        logger.info("System prompt exceeds budget (\(sections.joined(separator: "\n").count) chars > \(maxCharacters)). Trimming facts.")

        // Strategy 1: Reduce facts count
        var factLimit = Self.maxFacts
        while factLimit > 0 {
            factLimit -= 5

            // Rebuild sections with fewer facts
            let reducedFacts = Array(
                userFacts
                    .sorted { $0.importance > $1.importance }
                    .prefix(max(factLimit, 0))
            )

            let factsSection = reducedFacts.isEmpty ? "" : reducedFacts
                .map { "- \($0.content)" }
                .joined(separator: "\n")

            // Find and replace the facts section
            if let factsIndex = sections.firstIndex(where: { $0.contains(EmberSystemPrompt.factsHeader) }) {
                if factsSection.isEmpty {
                    sections.remove(at: factsIndex)
                } else {
                    sections[factsIndex] = EmberSystemPrompt.factsHeader + "\n" + factsSection
                }
            }

            let assembled = sections.joined(separator: "\n")
            if assembled.count <= maxCharacters {
                logger.info("Trimmed to \(factLimit) facts. Prompt now \(assembled.count) chars.")
                return assembled
            }
        }

        // Strategy 2: If still over budget, truncate session summary
        if let summaryIndex = sections.firstIndex(where: { $0.contains(EmberSystemPrompt.summaryHeader) }) {
            sections.remove(at: summaryIndex)
            logger.info("Removed session summary to fit budget.")
        }

        let assembled = sections.joined(separator: "\n")
        if assembled.count <= maxCharacters {
            return assembled
        }

        // Strategy 3: Last resort — hard truncate (should not happen with reasonable input)
        logger.warning("System prompt still exceeds budget after trimming. Hard truncating.")
        return String(assembled.prefix(maxCharacters))
    }
}

// MARK: - Supporting Types

/// Lightweight fact information used by SystemPromptBuilder.
///
/// This is a simplified projection of the full Fact model from the memory
/// system. The builder only needs the content text, importance score, and
/// last update date — not the full database model.
struct FactInfo: Sendable {
    /// The human-readable fact content (e.g., "User prefers dark roast coffee").
    let content: String

    /// Importance score from 0.0 (trivial) to 1.0 (critical).
    let importance: Double

    /// When this fact was last updated or reinforced.
    let lastUpdated: Date
}
```

### 3. `tests/Personality/EmberSystemPromptTests.swift`

Create this test file to verify the system prompt structure, builder behavior, and budget enforcement:

```swift
// EmberSystemPromptTests.swift
// EmberHearth
//
// Unit tests for EmberSystemPrompt and SystemPromptBuilder.

import XCTest
@testable import EmberHearth

final class EmberSystemPromptTests: XCTestCase {

    private var builder: SystemPromptBuilder!

    override func setUp() {
        super.setUp()
        builder = SystemPromptBuilder()
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    // MARK: - Base Prompt Tests

    func testBasePromptIsNotEmpty() {
        XCTAssertFalse(EmberSystemPrompt.basePrompt.isEmpty)
    }

    func testBasePromptContainsIdentity() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.contains("Ember"), "Base prompt must mention Ember's name")
        XCTAssertTrue(prompt.contains("personal AI assistant"), "Base prompt must define role")
        XCTAssertTrue(prompt.contains("iMessage"), "Base prompt must mention iMessage interface")
    }

    func testBasePromptContainsCoreTraits() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.lowercased().contains("warm"), "Must include warm trait")
        XCTAssertTrue(prompt.lowercased().contains("curious"), "Must include curious trait")
        XCTAssertTrue(prompt.lowercased().contains("capable"), "Must include capable trait")
        XCTAssertTrue(prompt.lowercased().contains("present"), "Must include present trait")
        XCTAssertTrue(prompt.lowercased().contains("honest"), "Must include honest trait")
    }

    func testBasePromptContainsBehavioralRules() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.contains("never do"), "Must include behavioral constraints")
        XCTAssertTrue(prompt.contains("physical experience"), "Must address not pretending physical senses")
    }

    func testBasePromptContainsCrisisGuidance() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.contains("988"), "Must include 988 Suicide & Crisis Lifeline number")
    }

    func testBasePromptContainsPrivacyStatement() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.lowercased().contains("local"), "Must mention local data storage")
    }

    func testBasePromptTokenBudget() {
        let prompt = EmberSystemPrompt.basePrompt
        // Base prompt should be approximately 400-800 tokens (~1600-3200 chars)
        // Allow some margin
        XCTAssertLessThan(prompt.count, 4000, "Base prompt should be under ~1000 tokens")
        XCTAssertGreaterThan(prompt.count, 800, "Base prompt should be at least ~200 tokens")
    }

    func testBasePromptAvoidsImmersionBreakers() {
        let prompt = EmberSystemPrompt.basePrompt
        // These are words/phrases the personality-design doc says to avoid in Ember's output
        // The system prompt itself should model good behavior
        XCTAssertFalse(prompt.contains("Delve"), "Should not use LLM vocabulary artifacts")
        XCTAssertFalse(prompt.contains("Leverage"), "Should not use LLM vocabulary artifacts")
        XCTAssertFalse(prompt.contains("Utilize"), "Should not use LLM vocabulary artifacts")
    }

    // MARK: - Builder Tests: Basic Assembly

    func testBuildWithNoOptionalSections() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains(EmberSystemPrompt.basePrompt))
    }

    func testBuildIncludesTimeContext() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertTrue(prompt.contains("Current context:"), "Should include current context section")
    }

    func testBuildIncludesUserFacts() {
        let facts = [
            FactInfo(content: "User prefers dark roast coffee", importance: 0.5, lastUpdated: Date()),
            FactInfo(content: "User's name is Alex", importance: 0.9, lastUpdated: Date())
        ]

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertTrue(prompt.contains("What you know about the user:"))
        XCTAssertTrue(prompt.contains("dark roast coffee"))
        XCTAssertTrue(prompt.contains("Alex"))
    }

    func testBuildSortsFactsByImportance() {
        let facts = [
            FactInfo(content: "Low importance fact", importance: 0.1, lastUpdated: Date()),
            FactInfo(content: "High importance fact", importance: 0.9, lastUpdated: Date()),
            FactInfo(content: "Medium importance fact", importance: 0.5, lastUpdated: Date())
        ]

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: nil,
            currentDate: Date()
        )

        // High importance fact should appear before low importance fact
        let highRange = prompt.range(of: "High importance fact")
        let lowRange = prompt.range(of: "Low importance fact")
        XCTAssertNotNil(highRange)
        XCTAssertNotNil(lowRange)
        if let high = highRange, let low = lowRange {
            XCTAssertTrue(high.lowerBound < low.lowerBound, "Higher importance facts should appear first")
        }
    }

    func testBuildIncludesSessionSummary() {
        let summary = "User discussed their upcoming trip to Portland and mentioned wanting restaurant recommendations."

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: summary,
            currentDate: Date()
        )

        XCTAssertTrue(prompt.contains("Earlier in this conversation:"))
        XCTAssertTrue(prompt.contains("Portland"))
    }

    func testBuildIncludesVerbosityInstruction() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date(),
            verbosityInstruction: "Respond in 1-2 sentences maximum. Be direct."
        )

        XCTAssertTrue(prompt.contains("Response style for this message:"))
        XCTAssertTrue(prompt.contains("1-2 sentences"))
    }

    func testBuildIncludesUserName() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date(),
            userName: "Alex"
        )

        XCTAssertTrue(prompt.contains("Alex"))
        XCTAssertTrue(prompt.contains("naturally but not excessively"))
    }

    // MARK: - Builder Tests: Time Context

    func testMorningContext() {
        // Create a date at 7:30 AM on a Wednesday
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 4  // A Wednesday
        components.hour = 7
        components.minute = 30
        let morning = Calendar.current.date(from: components)!

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: morning
        )

        XCTAssertTrue(prompt.lowercased().contains("early morning"))
        XCTAssertTrue(prompt.contains("Wednesday"))
    }

    func testEveningContext() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 6  // A Friday
        components.hour = 19
        components.minute = 0
        let evening = Calendar.current.date(from: components)!

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: evening
        )

        XCTAssertTrue(prompt.lowercased().contains("evening"))
        XCTAssertTrue(prompt.contains("Friday"))
    }

    func testWeekendContext() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 7  // A Saturday
        components.hour = 10
        components.minute = 0
        let saturday = Calendar.current.date(from: components)!

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: saturday
        )

        XCTAssertTrue(prompt.contains("Saturday"))
        XCTAssertTrue(prompt.contains("weekend"))
    }

    // MARK: - Builder Tests: Budget Enforcement

    func testPromptStaysUnderBudget() {
        // Create many facts to push the prompt close to the limit
        var facts: [FactInfo] = []
        for i in 0..<50 {
            facts.append(FactInfo(
                content: "This is test fact number \(i) which contains some reasonable amount of content to simulate a real user fact stored in the memory system",
                importance: Double(i) / 50.0,
                lastUpdated: Date()
            ))
        }

        let longSummary = String(repeating: "The user discussed various topics including work, hobbies, and plans. ", count: 20)

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: longSummary,
            currentDate: Date()
        )

        XCTAssertLessThanOrEqual(
            prompt.count,
            SystemPromptBuilder.maxPromptCharacters,
            "Assembled prompt must not exceed \(SystemPromptBuilder.maxPromptCharacters) characters"
        )
    }

    func testBudgetTrimmingPreservesHighImportanceFacts() {
        // Create enough facts to trigger trimming
        var facts: [FactInfo] = []
        let criticalFact = FactInfo(
            content: "CRITICAL: User is allergic to peanuts",
            importance: 1.0,
            lastUpdated: Date()
        )
        facts.append(criticalFact)

        for i in 0..<100 {
            facts.append(FactInfo(
                content: "Filler fact number \(i) with enough content to consume space in the prompt budget allocation",
                importance: 0.1,
                lastUpdated: Date()
            ))
        }

        let longSummary = String(repeating: "Summary content that takes up space. ", count: 50)

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: longSummary,
            currentDate: Date()
        )

        // The critical fact should survive trimming
        XCTAssertTrue(prompt.contains("allergic to peanuts"), "Critical facts should be preserved during trimming")
    }

    func testEmptyFactsProducesNoFactsSection() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertFalse(prompt.contains("What you know about the user:"), "Empty facts should not produce a facts section")
    }

    // MARK: - Builder Tests: Edge Cases

    func testNilSessionSummaryOmitsSection() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertFalse(prompt.contains("Earlier in this conversation:"))
    }

    func testEmptySessionSummaryOmitsSection() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: "",
            currentDate: Date()
        )

        XCTAssertFalse(prompt.contains("Earlier in this conversation:"))
    }

    func testEmptyUserNameOmitsNameLine() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date(),
            userName: ""
        )

        XCTAssertFalse(prompt.contains("user's name is"))
    }
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, os).
3. All Swift files use PascalCase naming.
4. All classes and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. The `FactInfo` struct is a lightweight projection — NOT the full `Fact` model from the memory system. It will be mapped from the real `Fact` type by the caller.
7. The test file path should match the SPM test target structure. If the existing test files are flat in `tests/`, place the test file at `tests/EmberSystemPromptTests.swift` instead of `tests/Personality/EmberSystemPromptTests.swift`. Check the existing test file locations and match that pattern.

## Directory Structure

Create these files:
- `src/Personality/EmberSystemPrompt.swift`
- `src/Personality/SystemPromptBuilder.swift`
- `tests/EmberSystemPromptTests.swift` (or `tests/Personality/EmberSystemPromptTests.swift` if subdirectories are supported)

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test`)
3. There are no calls to Process(), /bin/bash, or any shell execution
4. All public methods have documentation comments
5. os.Logger is used (not print() statements)
6. The base prompt is between 800 and 4000 characters
7. The base prompt contains: Ember's name, core traits, behavioral rules, crisis guidance (988), privacy statement
8. The builder enforces the 8000-character budget
9. Facts are sorted by importance before inclusion
10. Time-of-day context is generated correctly
```

---

## Acceptance Criteria

- [ ] `src/Personality/EmberSystemPrompt.swift` exists with `basePrompt` static property
- [ ] `src/Personality/SystemPromptBuilder.swift` exists with `buildSystemPrompt()` method
- [ ] Base prompt defines Ember's identity: name, role, iMessage interface
- [ ] Base prompt includes all five core traits: warm, curious, capable, present, honest
- [ ] Base prompt includes behavioral rules (never pretend physical experiences, never claim false memories)
- [ ] Base prompt includes crisis guidance with 988 Suicide & Crisis Lifeline number
- [ ] Base prompt includes privacy statement about local data storage
- [ ] Base prompt avoids immersion-breakers (no "Delve", "Leverage", "Utilize")
- [ ] Base prompt is 800-4000 characters (~200-1000 tokens)
- [ ] Builder assembles: base prompt + user facts + time context + session summary + verbosity instruction
- [ ] Facts are sorted by importance descending before inclusion
- [ ] Facts section is omitted when no facts are provided
- [ ] Time context includes time of day, day of week, and weekend indicator
- [ ] Session summary section is omitted when nil or empty
- [ ] Assembled prompt is enforced under 8000 characters
- [ ] When over budget, lowest-importance facts are trimmed first
- [ ] `FactInfo` struct exists with `content`, `importance`, and `lastUpdated` fields
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Personality/EmberSystemPrompt.swift && echo "EmberSystemPrompt.swift exists" || echo "MISSING: EmberSystemPrompt.swift"
test -f src/Personality/SystemPromptBuilder.swift && echo "SystemPromptBuilder.swift exists" || echo "MISSING: SystemPromptBuilder.swift"

# Verify test file exists (check both possible locations)
test -f tests/EmberSystemPromptTests.swift && echo "Test file exists (flat)" || test -f tests/Personality/EmberSystemPromptTests.swift && echo "Test file exists (nested)" || echo "MISSING: EmberSystemPromptTests.swift"

# Verify no shell execution
grep -rn "Process()" src/Personality/ || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/Personality/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/Personality/ || echo "PASS: No /bin/sh references found"

# Verify 988 crisis number is in the base prompt
grep -n "988" src/Personality/EmberSystemPrompt.swift && echo "PASS: 988 crisis number found" || echo "FAIL: Missing 988 crisis number"

# Build the project
swift build 2>&1

# Run just the system prompt tests
swift test --filter EmberSystemPromptTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth system prompt and prompt builder implementation for correctness, personality fidelity, and budget enforcement. Open these files:

@src/Personality/EmberSystemPrompt.swift
@src/Personality/SystemPromptBuilder.swift
@tests/EmberSystemPromptTests.swift (or tests/Personality/EmberSystemPromptTests.swift)

Also reference:
@docs/research/personality-design.md
@docs/research/conversation-design.md
@docs/research/session-management.md

Check for these specific issues:

1. **PERSONALITY FIDELITY (Critical):**
   - Does the base prompt capture Ember's five core traits (warm, curious, capable, present, honest)?
   - Does it match the voice from conversation-design.md: direct but not blunt, warm but not gushing, confident but not arrogant?
   - Does it avoid the immersion-breakers listed in personality-design.md (filler phrases, excessive hedging, section headers in casual chat)?
   - Does it include the behavioral rules: never pretend physical experiences, never claim false memories, never use "I'm just an AI" as deflection?
   - Is the tone of the prompt itself well-written — does it read as guidance, not a rigid script?

2. **CRISIS SAFETY (Critical):**
   - Does the base prompt include the 988 Suicide & Crisis Lifeline number?
   - Is the crisis guidance tone appropriate (present, not clinical)?
   - Does it encourage professional support without being preachy?

3. **TOKEN BUDGET (Important):**
   - Is the base prompt between 400-800 tokens (~1600-3200 chars)?
   - Does the builder enforce the 8000-character total budget?
   - When trimming, are highest-importance facts preserved?
   - Is the trimming strategy reasonable (facts first, then summary, then hard truncate)?

4. **CONTEXT BUILDING (Important):**
   - Is the time-of-day detection correct for all hour ranges?
   - Is the day-of-week detection correct (Sunday=1 through Saturday=7 in Calendar)?
   - Are weekends correctly identified?
   - Is the facts section omitted when empty (not showing an empty header)?
   - Is the session summary section omitted when nil or empty?

5. **CODE QUALITY:**
   - Are all public APIs documented with /// comments?
   - Is os.Logger used consistently (no print statements)?
   - Is the FactInfo struct lightweight and appropriate (not importing the full memory system)?
   - Are there any force-unwraps or potential crashes?
   - Is Sendable conformance appropriate where used?

6. **SECURITY:**
   - Are there ANY calls to Process(), /bin/bash, /bin/sh, or NSTask?
   - Could the system prompt be manipulated by user-controlled input to inject instructions? (The facts content comes from the memory system — is it safe to include verbatim?)

7. **TEST QUALITY:**
   - Do tests cover: base prompt content, builder assembly, fact sorting, budget enforcement, time context, edge cases (empty facts, nil summary)?
   - Are the time-context tests using specific known dates (not Date() which varies)?
   - Is there a test verifying the 988 crisis number is present?
   - Is there a test verifying budget enforcement with excessive facts?

Report any issues found with specific file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m5): add Ember system prompt and prompt builder
```

---

## Notes for Next Task

- `EmberSystemPrompt.basePrompt` is the static personality text. Task 0401 (VerbosityAdapter) will generate verbosity instructions that are passed to `SystemPromptBuilder.buildSystemPrompt(verbosityInstruction:)`.
- `SystemPromptBuilder` accepts `[FactInfo]` — a lightweight projection. The caller (ContextBuilder in task 0402) will map full `Fact` objects from the memory system into `FactInfo` structs.
- The `verbosityInstruction` parameter is optional and will be populated by the VerbosityAdapter created in task 0401.
- The builder's `buildContextSection(for:)` method generates time-aware context. This is used by the LLM to naturally adapt tone without explicit instructions (per the "progressive disclosure" principle from personality-design.md).
- The 8000-character budget for the system prompt is separate from the overall context window budget (which is managed by ContextBuilder in task 0402 and TokenCounter in task 0404).
- `FactInfo` is defined alongside the builder for now. If a more canonical location emerges (e.g., in the Memory module), it can be moved in a future refactor.
