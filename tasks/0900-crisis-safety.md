# Task 0900: Crisis Detection and Safety Responses

**Milestone:** M10 - Crisis Safety & Compliance
**Unit:** 10.1 - Crisis Detection with Tiered Response System
**Phase:** Final
**Depends On:** 0802 (Security Penetration Tests)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; security boundaries and core principles
2. `docs/specs/crisis-safety-protocols.md` — **Read entirely.** This is the primary specification for this task. It contains detection tiers, response templates, false positive patterns, behavioral rules, and testing requirements. Every section is relevant.
3. `docs/research/legal-ethical-considerations.md` — Read the section on crisis liability (search for "crisis" or "988") for legal context
4. `src/Security/TronPipeline.swift` — Full file; understand how to integrate crisis detection into the pipeline
5. `src/Security/InjectionScanner.swift` — Full file; understand the pattern matching approach used for injection detection (crisis detection should follow a similar pattern)

> **Context Budget Note:** `crisis-safety-protocols.md` is ~950 lines and is the most important reference. Read the entire file. `legal-ethical-considerations.md` may be long; focus only on sections mentioning crisis detection, 988, or liability.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Crisis Detection and Safety Response system for EmberHearth, a native macOS personal AI assistant. This is a legally required safety feature (New York Safeguards Law, California SB 243) that detects when users may be in mental health crisis and provides appropriate crisis resource referrals.

## CRITICAL CONTEXT

This is the most safety-critical code in the entire application. Failure to detect a genuine crisis could have life-or-death consequences. Failure to handle false positives well could make the app annoying or intrusive. Both must be handled carefully.

**What Ember IS:** A personal assistant that cares about its user and bridges them to professional help.
**What Ember is NOT:** A therapist, counselor, or crisis intervention specialist.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., CrisisDetector.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- Security first: log security events but NEVER include user message content in logs

## What You Are Building

Two source files and one test file:
1. `src/Security/CrisisDetector.swift` — Detects crisis signals in user messages with tiered severity
2. `src/Security/CrisisResponseTemplates.swift` — Contains the response text for each crisis tier
3. `tests/SecurityTests/CrisisDetectorTests.swift` — Comprehensive tests including false positive tests

## Files to Create

### 1. src/Security/CrisisDetector.swift

```swift
// CrisisDetector.swift
// EmberHearth
//
// Detects crisis signals (suicidal ideation, self-harm, immediate danger) in user
// messages and classifies them by severity tier. This is a legally required safety
// feature per the New York Safeguards Law and California SB 243.
//
// IMPORTANT: Ember is NOT a therapist. When a crisis is detected, Ember provides
// crisis resources and continues the conversation normally. Ember does NOT attempt
// crisis intervention, therapy, or probing questions.

import Foundation
import os

/// Represents the severity tier of a detected crisis signal.
///
/// Tiers map to different response strategies:
/// - Tier 1: Immediate resource referral with 988 and 911
/// - Tier 2: Empathetic acknowledgment with 988 referral
/// - Tier 3: Gentle check-in with resource awareness
///
/// Reference: docs/specs/crisis-safety-protocols.md, Part 2
enum CrisisTier: Int, Comparable, Sendable {
    /// Immediate crisis: Active suicidal ideation, imminent danger, active self-harm.
    /// Response: Immediate resource referral including 988 and 911.
    case tier1 = 1

    /// Serious concern: Passive suicidal ideation, ongoing self-harm, deep hopelessness.
    /// Response: Empathetic acknowledgment with 988 referral.
    case tier2 = 2

    /// Potential concern: Vague references, indirect signals, general hopelessness.
    /// Response: Gentle check-in with resource awareness.
    case tier3 = 3

    static func < (lhs: CrisisTier, rhs: CrisisTier) -> Bool {
        // Lower rawValue = higher severity
        return lhs.rawValue < rhs.rawValue
    }
}

/// The result of crisis detection analysis on a message.
///
/// Contains the detected tier (if any), the patterns that matched, and a confidence score.
struct CrisisAssessment: Sendable {
    /// The crisis tier detected. nil if no crisis signal was found.
    let tier: CrisisTier

    /// The pattern strings that matched in the message (for logging, NOT for display).
    /// IMPORTANT: These are pattern descriptions, NOT the user's actual words.
    let matchedPatterns: [String]

    /// Confidence score from 0.0 to 1.0.
    /// Higher confidence means more explicit crisis language was detected.
    let confidence: Double
}

/// Detects crisis signals in user messages using pattern matching with context awareness.
///
/// The detector uses three layers:
/// 1. **False positive filtering** — Identifies idiomatic expressions that should NOT
///    trigger crisis detection (e.g., "This meeting is killing me").
/// 2. **Tier-based pattern matching** — Checks message against crisis patterns organized
///    by severity (Tier 1 = most severe, checked first).
/// 3. **Context awareness** — Applies surrounding-word analysis to reduce false positives
///    (e.g., "kill this bug" vs "kill myself").
///
/// Usage:
/// ```swift
/// let detector = CrisisDetector()
/// if let assessment = detector.detectCrisis(in: "I don't want to be alive anymore") {
///     let response = CrisisResponseTemplates.response(for: assessment.tier)
///     // Include response in Ember's reply, log the event
/// }
/// ```
///
/// Reference: docs/specs/crisis-safety-protocols.md
final class CrisisDetector {

    // MARK: - Logger

    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "CrisisDetector"
    )

    // MARK: - Initialization

    init() {}

    // MARK: - Public API

    /// Analyzes a user message for crisis signals.
    ///
    /// Detection runs in this order:
    /// 1. Check false positive patterns (idioms, fiction, news) — if matched, return nil
    /// 2. Check Tier 1 patterns (immediate crisis) — highest severity
    /// 3. Check Tier 2 patterns (serious concern)
    /// 4. Check Tier 3 patterns (potential concern)
    /// 5. Apply context-awareness filters to reduce remaining false positives
    ///
    /// - Parameter message: The user's message text.
    /// - Returns: A `CrisisAssessment` if crisis signals are detected, nil if the
    ///   message is not a crisis signal.
    func detectCrisis(in message: String) -> CrisisAssessment? {
        let normalized = message.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }

        // Step 1: Check false positive patterns first
        if matchesFalsePositive(normalized) {
            logger.debug("Crisis detector: false positive filter matched, skipping")
            return nil
        }

        // Step 2: Check Tier 1 (most severe)
        let tier1Matches = findMatches(in: normalized, patterns: Self.tier1Patterns)
        if !tier1Matches.isEmpty {
            // Apply context filter — "kill this bug" should not trigger
            if !isContextualFalsePositive(normalized, tier: .tier1) {
                logger.info("Crisis detector: Tier 1 signal detected")
                return CrisisAssessment(
                    tier: .tier1,
                    matchedPatterns: tier1Matches,
                    confidence: 0.9
                )
            }
        }

        // Step 3: Check Tier 2
        let tier2Matches = findMatches(in: normalized, patterns: Self.tier2Patterns)
        if !tier2Matches.isEmpty {
            if !isContextualFalsePositive(normalized, tier: .tier2) {
                logger.info("Crisis detector: Tier 2 signal detected")
                return CrisisAssessment(
                    tier: .tier2,
                    matchedPatterns: tier2Matches,
                    confidence: 0.7
                )
            }
        }

        // Step 4: Check Tier 3
        let tier3Matches = findMatches(in: normalized, patterns: Self.tier3Patterns)
        if !tier3Matches.isEmpty {
            if !isContextualFalsePositive(normalized, tier: .tier3) {
                logger.info("Crisis detector: Tier 3 signal detected")
                return CrisisAssessment(
                    tier: .tier3,
                    matchedPatterns: tier3Matches,
                    confidence: 0.5
                )
            }
        }

        return nil
    }

    // MARK: - Pattern Definitions

    // Tier 1: Immediate Crisis — Active suicidal ideation, imminent danger
    private static let tier1Patterns: [(pattern: String, description: String)] = [
        // Explicit suicidal intent
        ("i('m| am) going to kill myself", "explicit suicidal intent"),
        ("i('m| am) going to end (it|my life|everything)", "explicit end-of-life intent"),
        ("i('ve| have) decided to (die|kill myself|end it)", "decided to die"),
        ("i want to kill myself", "wants to kill self"),
        ("i want to die", "wants to die"),
        ("i don't want to be alive", "doesn't want to be alive"),
        ("i('m| am) going to hurt myself tonight", "imminent self-harm"),
        ("tonight('s| is) the night", "imminent intent signal"),
        ("this is (my )?goodbye", "goodbye/farewell signal"),
        ("i won't be here (tomorrow|much longer)", "anticipating own death"),

        // Active self-harm
        ("i('m| am) (cutting|hurting|burning) myself", "active self-harm"),
        ("i just (cut|hurt|burned) myself", "recent self-harm"),

        // Immediate danger signals
        ("i have (a gun|pills|a knife|rope)", "has means for self-harm"),
        ("i('m| am) (standing on|at the edge|on the bridge)", "at dangerous location"),
        ("i('ve| have) (taken|swallowed) (pills|something)", "has taken substances"),

        // Harm to others
        ("i('m| am) going to (hurt|kill) (someone|them|him|her)", "intent to harm others")
    ]

    // Tier 2: Serious Concern — Passive ideation, ongoing self-harm, deep hopelessness
    private static let tier2Patterns: [(pattern: String, description: String)] = [
        // Passive suicidal ideation
        ("i wish i (was|were|wasn't) (dead|alive|born)", "passive suicidal ideation"),
        ("i don't want to (live|be alive|exist)", "doesn't want to live"),
        ("i('d| would) be better off dead", "better off dead"),
        ("everyone would be better off without me", "perceived burden"),
        ("nobody would miss me", "perceived insignificance"),

        // Self-harm mentions (past/ongoing)
        ("i('ve| have) been (cutting|hurting|harming) myself", "ongoing self-harm"),
        ("i (cut|hurt|harm) myself", "self-harm disclosure"),
        ("i started (cutting|self-harming)", "new self-harm behavior"),

        // Hopelessness with intent signals
        ("i can't (do this|go on|take it) anymore", "can't go on"),
        ("i('ve| have) given up", "has given up"),
        ("there's no (point|reason|hope)", "no point/hope"),
        ("nothing will ever (get better|change|improve)", "permanent hopelessness"),

        // Crisis history
        ("i (tried|attempted) to kill myself", "past suicide attempt"),
        ("last time i (tried|attempted)", "references past attempt")
    ]

    // Tier 3: Potential Concern — Vague references, indirect signals
    private static let tier3Patterns: [(pattern: String, description: String)] = [
        // General hopelessness
        ("nothing matters anymore", "nihilistic statement"),
        ("what's the point of (anything|living|going on)", "questioning purpose"),
        ("i don't (care|matter)", "self-devaluation"),
        ("everything feels (pointless|hopeless|meaningless)", "pervasive hopelessness"),

        // Isolation signals
        ("no one (would care|would notice|cares|loves me)", "perceived isolation"),
        ("i('m| am) (all )?alone", "loneliness expression"),
        ("nobody (loves|wants|needs) me", "perceived rejection"),

        // Indirect mentions
        ("thinking about ending", "indirect ending reference"),
        ("don't want to wake up", "doesn't want to wake up"),
        ("i('m| am) really struggling", "struggling expression"),
        ("i can't cope", "can't cope")
    ]

    // MARK: - False Positive Patterns

    // Common idioms and contexts that should NOT trigger crisis detection
    private static let falsePositivePatterns: [String] = [
        // Idioms with "killing" / "dying" / "dead"
        "killing (me|it|time)",
        "dying (to|of|for) (see|know|meet|try|laughter|embarrassment)",
        "dead (tired|serious|wrong|set|weight|end|line|lock|pan|beat)",
        "over my dead body",
        "drop dead gorgeous",
        "dead in the water",

        // Fiction/media context indicators
        "in the (movie|show|book|game|episode|story|series|film|novel)",
        "(character|actor|protagonist|villain|hero) (dies|died|kills|killed)",
        "plot (twist|point|spoiler)",
        "spoiler alert",

        // News/historical
        "in the (news|article|report|headline)",
        "(accident|crash|incident|tragedy) (killed|claimed)",

        // Food/cooking
        "kill the (heat|flame|burner)",
        "dying (to eat|to try|for a taste)",

        // Sports/games
        "(killed|crushed|destroyed|murdered) (it|them|the competition|the game)",
        "dead ball",

        // Technology
        "kill (the process|the app|the server|the task|the thread)",
        "dead (code|link|pixel|battery)"
    ]

    // MARK: - Context-Aware False Positive Detection

    // Words that, when appearing near crisis trigger words, indicate non-crisis context
    private static let contextualNonCrisisWords: [String] = [
        "bug", "code", "software", "app", "process", "server", "game",
        "movie", "show", "book", "story", "character", "episode",
        "traffic", "meeting", "deadline", "email", "homework",
        "restaurant", "food", "recipe", "cooking",
        "joke", "kidding", "lol", "haha", "lmao"
    ]

    // MARK: - Private Methods

    /// Checks if the message matches any false positive pattern.
    private func matchesFalsePositive(_ normalized: String) -> Bool {
        for pattern in Self.falsePositivePatterns {
            if matchesRegex(normalized, pattern: pattern) {
                return true
            }
        }
        return false
    }

    /// Applies context-aware filtering to reduce false positives.
    /// For Tier 3, more aggressive filtering is applied because these patterns
    /// are more likely to overlap with normal conversation.
    private func isContextualFalsePositive(_ normalized: String, tier: CrisisTier) -> Bool {
        // For Tier 1 (most severe), don't filter — always take it seriously
        if tier == .tier1 { return false }

        // Check for contextual non-crisis words near the trigger
        let words = normalized.components(separatedBy: .whitespacesAndNewlines)
        let nonCrisisWordCount = words.filter { word in
            Self.contextualNonCrisisWords.contains(word)
        }.count

        // If the message is predominantly about non-crisis topics, it's likely a false positive
        // Be more aggressive for Tier 3 (vague signals)
        if tier == .tier3 && nonCrisisWordCount >= 2 {
            return true
        }

        // Check for hypothetical/fiction framing
        let hypotheticalIndicators = [
            "what if", "hypothetically", "in a story", "for a book",
            "character", "imagine", "fictional", "in the movie"
        ]
        for indicator in hypotheticalIndicators {
            if normalized.contains(indicator) {
                // For Tier 2, only de-escalate if very clearly fictional
                if tier == .tier3 { return true }
                // For Tier 2, require stronger fiction signals
                if tier == .tier2 && (normalized.contains("fictional") || normalized.contains("in the movie") || normalized.contains("in a story")) {
                    return true
                }
            }
        }

        return false
    }

    /// Finds which patterns match in the normalized message.
    /// Returns the descriptions of matched patterns (NOT the user's text).
    private func findMatches(
        in normalized: String,
        patterns: [(pattern: String, description: String)]
    ) -> [String] {
        var matches: [String] = []
        for (pattern, description) in patterns {
            if matchesRegex(normalized, pattern: pattern) {
                matches.append(description)
            }
        }
        return matches
    }

    /// Checks if a normalized message matches a regex pattern.
    private func matchesRegex(_ text: String, pattern: String) -> Bool {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            logger.error("Invalid regex pattern: \(pattern, privacy: .public)")
            return false
        }

        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
```

### 2. src/Security/CrisisResponseTemplates.swift

```swift
// CrisisResponseTemplates.swift
// EmberHearth
//
// Pre-written response templates for each crisis tier.
// These responses are carefully crafted to:
// - Express care without attempting therapy
// - Provide crisis resources immediately
// - Not probe or ask follow-up questions about the crisis
// - Remain available for normal conversation
//
// Reference: docs/specs/crisis-safety-protocols.md, Part 3

import Foundation

/// Contains pre-written response templates for each crisis tier.
///
/// These responses are NOT generated by the LLM — they are static, reviewed text
/// that is prepended to (or replaces) the LLM's normal response when crisis signals
/// are detected in the user's message.
///
/// IMPORTANT: These templates have been reviewed for:
/// - Compassion without over-engagement
/// - Clear resource information
/// - No probing questions about the crisis
/// - Appropriate boundaries (Ember is not a therapist)
enum CrisisResponseTemplates {

    /// Returns the appropriate crisis response for the given tier.
    ///
    /// - Parameter tier: The detected crisis tier.
    /// - Returns: A pre-written response string to send to the user.
    static func response(for tier: CrisisTier) -> String {
        switch tier {
        case .tier1:
            return tier1Response
        case .tier2:
            return tier2Response
        case .tier3:
            return tier3Response
        }
    }

    // MARK: - Tier 1: Immediate Crisis

    /// Response for Tier 1 (immediate crisis): Active suicidal ideation, imminent danger.
    ///
    /// Behavioral rules:
    /// - Express care without escalating
    /// - Provide resources IMMEDIATELY
    /// - Do NOT engage with crisis content
    /// - Do NOT ask probing questions
    /// - Do NOT offer advice or coping strategies
    /// - Include 988, Crisis Text Line, and 911
    static let tier1Response = """
    I hear you, and I'm really concerned about what you're sharing with me right now.

    Please reach out to someone who can help:

    988 Suicide & Crisis Lifeline -- Call or text 988 (available 24/7)
    Crisis Text Line -- Text HOME to 741741
    Emergency -- Call 911 if you're in immediate danger

    I care about you, and I want you to get support from people who are trained to help. I'm here for everyday things, but right now you deserve real human support.

    Will you reach out to one of these resources?
    """

    // MARK: - Tier 2: Serious Concern

    /// Response for Tier 2 (serious concern): Passive ideation, ongoing self-harm.
    ///
    /// Behavioral rules:
    /// - Acknowledge the difficulty
    /// - Express care without therapeutic engagement
    /// - Provide resources clearly
    /// - Gently encourage professional support
    /// - Remain available for non-crisis conversation
    static let tier2Response = """
    I can hear that you're going through something really hard. That takes courage to share.

    I want to make sure you have support:

    988 Suicide & Crisis Lifeline -- Call or text 988 anytime
    Crisis Text Line -- Text HOME to 741741

    I'm not a counselor, but I do care about you. These folks are experts at helping people through tough times. Would you consider reaching out?

    I'm here for everyday things, and I'll still be here after you talk to someone.
    """

    // MARK: - Tier 3: Potential Concern

    /// Response for Tier 3 (potential concern): Vague references, indirect signals.
    ///
    /// Behavioral rules:
    /// - Acknowledge without over-reacting
    /// - Mention resources casually but clearly
    /// - Normalize seeking help
    /// - Offer to continue with other topics
    /// - Don't push or probe
    static let tier3Response = """
    That sounds really difficult. I want you to know that support is available if you ever need it:

    988 Suicide & Crisis Lifeline -- Call or text 988
    Crisis Text Line -- Text HOME to 741741

    I'm here to help with day-to-day stuff, but if you're ever struggling, these resources are available 24/7 with people who really understand.

    Is there something I can help you with today?
    """

    // MARK: - Follow-Up Response

    /// Response when user continues discussing crisis after initial resource referral.
    ///
    /// Used when the user has already received resources but continues to discuss
    /// crisis topics. Ember gently redirects without being dismissive.
    static let followUpRedirect = """
    I really appreciate you trusting me with this. It means a lot.

    I want to be honest with you: I'm an AI assistant, and I'm not equipped to help with what you're going through right now. The people at 988 are real humans who specialize in exactly this, and they won't judge you.

    Can I help you with anything else right now -- maybe something practical or a distraction?
    """

    /// Response when user has refused resources multiple times.
    ///
    /// Ember backs off the strong referral but leaves the door open.
    /// After this, Ember returns to normal conversation but continues
    /// to include resources if NEW crisis signals are detected.
    static let persistentCrisisResponse = """
    I understand you might not want to reach out right now. That's okay.

    Just know that 988 is always there when you're ready -- no pressure, no judgment. You can call, text, or chat online.

    I'll be here for the everyday stuff whenever you need me.
    """

    // MARK: - Resource Information

    /// The primary crisis phone/text number. Included in every crisis response.
    static let primaryCrisisNumber = "988"

    /// The Crisis Text Line keyword. Included in every crisis response.
    static let crisisTextLineKeyword = "HOME to 741741"
}
```

### 3. tests/SecurityTests/CrisisDetectorTests.swift

```swift
// CrisisDetectorTests.swift
// EmberHearth
//
// Comprehensive tests for crisis detection including:
// - True positive tests for each tier
// - False positive tests for idiomatic speech
// - Context-aware detection tests
// - Response template verification

import XCTest
@testable import EmberHearth

final class CrisisDetectorTests: XCTestCase {

    // MARK: - Properties

    private var detector: CrisisDetector!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        detector = CrisisDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Tier 1: Immediate Crisis Detection

    func test_tier1_explicitSuicidalIntent_detected() {
        let messages = [
            "I'm going to kill myself",
            "I am going to kill myself tonight",
            "I've decided to end it all",
            "I want to kill myself",
            "I want to die",
            "I don't want to be alive anymore",
            "I'm going to end my life",
            "This is my goodbye"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Tier 1 should detect: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier1,
                          "Should be Tier 1 (immediate): \"\(message)\"")
        }
    }

    func test_tier1_activeSelfHarm_detected() {
        let messages = [
            "I'm cutting myself right now",
            "I just hurt myself",
            "I am burning myself"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Active self-harm should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier1)
        }
    }

    func test_tier1_immediateDanger_detected() {
        let messages = [
            "I have a gun and I'm thinking about using it",
            "I have pills and I'm going to take them",
            "I've taken pills",
            "I'm standing on the bridge"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Immediate danger should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier1)
        }
    }

    func test_tier1_highConfidence() {
        let result = detector.detectCrisis(in: "I'm going to kill myself")
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result?.confidence ?? 0, 0.8,
            "Tier 1 detections should have high confidence (>=0.8)")
    }

    // MARK: - Tier 2: Serious Concern Detection

    func test_tier2_passiveIdeation_detected() {
        let messages = [
            "I wish I wasn't alive",
            "I wish I were dead",
            "I don't want to live anymore",
            "I don't want to exist",
            "I'd be better off dead",
            "Everyone would be better off without me",
            "Nobody would miss me"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Tier 2 should detect: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2,
                          "Should be Tier 2 (serious): \"\(message)\"")
        }
    }

    func test_tier2_ongoingSelfHarm_detected() {
        let messages = [
            "I've been cutting myself",
            "I've been hurting myself lately",
            "I started self-harming again"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Ongoing self-harm should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2)
        }
    }

    func test_tier2_hopelessnessWithIntentSignals_detected() {
        let messages = [
            "I can't do this anymore",
            "I can't go on anymore",
            "I've given up on everything",
            "There's no hope",
            "Nothing will ever get better"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Hopelessness should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2)
        }
    }

    // MARK: - Tier 3: Potential Concern Detection

    func test_tier3_generalHopelessness_detected() {
        let messages = [
            "Nothing matters anymore",
            "Everything feels pointless",
            "I don't care about anything anymore"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Tier 3 should detect: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier3,
                          "Should be Tier 3 (potential): \"\(message)\"")
        }
    }

    func test_tier3_isolationSignals_detected() {
        let messages = [
            "No one would care if I was gone",
            "Nobody loves me",
            "Nobody wants me around"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Isolation signals should be detected: \"\(message)\"")
        }
    }

    // MARK: - False Positive Tests (Idiomatic Speech)

    func test_falsePositive_idioms_notDetected() {
        let idioms = [
            "This traffic is killing me",
            "I'm dying to see that new movie",
            "I'm dying of laughter",
            "I could just die of embarrassment",
            "I'm dead tired after today",
            "I'm dead serious about this",
            "Over my dead body will I agree to that",
            "That joke killed me",
            "You're killing it at work!",
            "I'm dying for a cup of coffee"
        ]

        for idiom in idioms {
            let result = detector.detectCrisis(in: idiom)
            XCTAssertNil(result,
                        "Idiomatic speech should NOT trigger crisis detection: \"\(idiom)\"")
        }
    }

    func test_falsePositive_fictionAndMedia_notDetected() {
        let fictionMessages = [
            "The character dies in episode 5",
            "In the movie, the villain kills the hero",
            "I just read a book where the protagonist dies",
            "The plot twist is that she was dead the whole time",
            "In the game, you have to kill the final boss"
        ]

        for message in fictionMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNil(result,
                        "Fiction/media discussion should NOT trigger detection: \"\(message)\"")
        }
    }

    func test_falsePositive_technology_notDetected() {
        let techMessages = [
            "Can you kill the process running on port 8080?",
            "I need to kill the server and restart it",
            "That code is dead, we should remove it",
            "The link is dead, it returns a 404"
        ]

        for message in techMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNil(result,
                        "Technology discussion should NOT trigger detection: \"\(message)\"")
        }
    }

    func test_falsePositive_casualConversation_notDetected() {
        let casualMessages = [
            "What should I make for dinner?",
            "This meeting is killing me with boredom",
            "I'm so exhausted I could drop dead",
            "What's the point of this meeting again?",
            "I'm struggling with this math problem",
            "I feel alone when my roommate travels",
            "Nobody loves Monday mornings"
        ]

        for message in casualMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNil(result,
                        "Casual conversation should NOT trigger detection: \"\(message)\"")
        }
    }

    func test_falsePositive_contextualBugKill_notDetected() {
        // "I want to kill" + context word = not a crisis
        let result = detector.detectCrisis(in: "I want to kill this bug in my code")
        XCTAssertNil(result,
                    "\"Kill this bug\" should not trigger crisis detection")
    }

    // MARK: - Context Awareness Tests

    func test_contextAwareness_hypotheticalTier3_notDetected() {
        let message = "What if someone felt like nothing matters anymore? Hypothetically speaking."
        let result = detector.detectCrisis(in: message)
        // Hypothetical framing should de-escalate Tier 3
        XCTAssertNil(result,
                    "Hypothetical Tier 3 should be de-escalated to not-detected")
    }

    func test_contextAwareness_hypotheticalTier1_stillDetected() {
        // Even with hypothetical framing, Tier 1 should still trigger
        // (better safe than sorry for explicit suicidal language)
        let message = "Hypothetically, what if I said I'm going to kill myself?"
        let result = detector.detectCrisis(in: message)
        // This should still be detected because Tier 1 is never de-escalated
        XCTAssertNotNil(result,
                       "Tier 1 should still detect even with hypothetical framing")
    }

    // MARK: - Response Template Tests

    func test_tier1Response_contains988() {
        let response = CrisisResponseTemplates.response(for: .tier1)
        XCTAssertTrue(response.contains("988"),
                     "Tier 1 response must include 988 number")
    }

    func test_tier1Response_contains911() {
        let response = CrisisResponseTemplates.response(for: .tier1)
        XCTAssertTrue(response.contains("911"),
                     "Tier 1 response must include 911 for immediate danger")
    }

    func test_tier1Response_containsCrisisTextLine() {
        let response = CrisisResponseTemplates.response(for: .tier1)
        XCTAssertTrue(response.contains("741741"),
                     "Tier 1 response must include Crisis Text Line number")
    }

    func test_tier2Response_contains988() {
        let response = CrisisResponseTemplates.response(for: .tier2)
        XCTAssertTrue(response.contains("988"),
                     "Tier 2 response must include 988 number")
    }

    func test_tier3Response_contains988() {
        let response = CrisisResponseTemplates.response(for: .tier3)
        XCTAssertTrue(response.contains("988"),
                     "Tier 3 response must include 988 number")
    }

    func test_responses_doNotContainProbingQuestions() {
        let allResponses = [
            CrisisResponseTemplates.tier1Response,
            CrisisResponseTemplates.tier2Response,
            CrisisResponseTemplates.tier3Response
        ]

        for response in allResponses {
            let lowered = response.lowercased()
            XCTAssertFalse(lowered.contains("why do you feel"),
                          "Response should NOT probe with 'why do you feel'")
            XCTAssertFalse(lowered.contains("tell me more about"),
                          "Response should NOT probe with 'tell me more'")
            XCTAssertFalse(lowered.contains("have you tried"),
                          "Response should NOT offer therapeutic advice")
            XCTAssertFalse(lowered.contains("what method"),
                          "Response should NEVER ask about methods")
            XCTAssertFalse(lowered.contains("how long have you"),
                          "Response should NOT probe for duration")
        }
    }

    func test_responses_expressCareProfessionally() {
        let tier1 = CrisisResponseTemplates.tier1Response.lowercased()
        XCTAssertTrue(tier1.contains("care") || tier1.contains("concerned") || tier1.contains("hear you"),
                     "Tier 1 should express care")
    }

    // MARK: - Edge Cases

    func test_emptyMessage_noDetection() {
        let result = detector.detectCrisis(in: "")
        XCTAssertNil(result, "Empty message should not trigger detection")
    }

    func test_whitespaceOnlyMessage_noDetection() {
        let result = detector.detectCrisis(in: "   \n\t   ")
        XCTAssertNil(result, "Whitespace-only message should not trigger detection")
    }

    func test_caseInsensitive_detection() {
        let result = detector.detectCrisis(in: "I WANT TO KILL MYSELF")
        XCTAssertNotNil(result, "Detection should be case-insensitive")
        XCTAssertEqual(result?.tier, .tier1)
    }

    func test_matchedPatterns_doNotContainUserText() {
        let result = detector.detectCrisis(in: "I want to kill myself because of what happened today")
        XCTAssertNotNil(result)
        // Matched patterns should be descriptions, not the user's actual words
        if let patterns = result?.matchedPatterns {
            for pattern in patterns {
                XCTAssertFalse(pattern.contains("because of what happened"),
                    "Matched patterns should be descriptions, not user text")
            }
        }
    }

    // MARK: - CrisisTier Comparison

    func test_crisisTier_comparison() {
        XCTAssertTrue(CrisisTier.tier1 < CrisisTier.tier2,
                     "Tier 1 should be more severe (lower) than Tier 2")
        XCTAssertTrue(CrisisTier.tier2 < CrisisTier.tier3,
                     "Tier 2 should be more severe (lower) than Tier 3")
    }
}
```

## Integration with TronPipeline

After creating the CrisisDetector and CrisisResponseTemplates, update the TronPipeline to run crisis detection BEFORE injection scanning. This is because:
- A user in crisis might use language that looks like an injection ("I want to end it all — ignore everything else")
- Crisis detection must take priority over security screening

In `src/Security/TronPipeline.swift`, the screenInbound method should be updated to:
```swift
func screenInbound(message: String) -> ScreeningResult {
    // 1. CRISIS DETECTION FIRST (safety priority)
    let crisisDetector = CrisisDetector()
    if let assessment = crisisDetector.detectCrisis(in: message) {
        // Return the crisis response instead of normal processing
        let response = CrisisResponseTemplates.response(for: assessment.tier)
        return ScreeningResult(
            flagged: false,  // Not flagged as malicious — it's a crisis
            crisisDetected: true,
            crisisTier: assessment.tier,
            crisisResponse: response,
            // ... continue with normal LLM processing after prepending crisis response
        )
    }

    // 2. Then injection scanning as before
    // ...existing injection scanning code...
}
```

The exact implementation depends on the existing TronPipeline API. Adapt as needed, but ensure crisis detection runs first.

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.**
2. No third-party dependencies. Use only Apple frameworks (Foundation, os, XCTest).
3. All Swift files use PascalCase naming.
4. All public types and methods must have documentation comments (///).
5. **SECURITY LOGGING:** Log crisis events using SecurityLogger but NEVER include the user's message content in logs. Log the tier, the pattern descriptions, and the timestamp only.
6. Crisis detection runs BEFORE injection scanning in the pipeline.
7. After a crisis detection, Ember ALWAYS includes the resource information in the response. Do NOT stop responding — the user needs support, not silence.
8. Continue normal conversation after providing resources.
9. The CrisisResponseTemplates are static text, NOT LLM-generated. This ensures consistent, reviewed crisis messaging.
10. Add a TODO comment for multi-language support (not required for MVP).

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test --filter CrisisDetectorTests`)
3. No calls to Process(), /bin/bash, or shell execution
4. All Tier 1 messages are correctly detected
5. All false positive idioms are correctly NOT detected
6. All response templates contain 988
7. No response template contains probing questions
8. Matched patterns contain descriptions, not user text
9. Crisis detection integrates with TronPipeline (runs before injection scanning)
10. SecurityLogger does not log user message content
```

---

## Acceptance Criteria

- [ ] `src/Security/CrisisDetector.swift` exists with `CrisisDetector` class
- [ ] `CrisisTier` enum exists with three tiers (tier1, tier2, tier3) and is `Comparable`
- [ ] `CrisisAssessment` struct contains tier, matchedPatterns, and confidence
- [ ] `detectCrisis(in:)` correctly detects Tier 1 messages (explicit suicidal intent, active self-harm, immediate danger)
- [ ] `detectCrisis(in:)` correctly detects Tier 2 messages (passive ideation, ongoing self-harm, deep hopelessness)
- [ ] `detectCrisis(in:)` correctly detects Tier 3 messages (general hopelessness, isolation, indirect mentions)
- [ ] False positives correctly filtered: idioms ("killing me"), fiction ("character dies"), tech ("kill the process")
- [ ] Context awareness reduces false positives (e.g., "kill this bug" not flagged)
- [ ] Detection is case-insensitive
- [ ] `src/Security/CrisisResponseTemplates.swift` exists with all response templates
- [ ] All response templates include 988 and Crisis Text Line (741741)
- [ ] Tier 1 response includes 911
- [ ] No response template contains probing questions or therapeutic advice
- [ ] Responses express care without attempting crisis intervention
- [ ] CrisisDetector integrated into TronPipeline (runs before injection scanning)
- [ ] SecurityLogger logs crisis events WITHOUT user message content
- [ ] Matched patterns contain descriptions, not user text (privacy)
- [ ] All tests pass
- [ ] `swift build` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify source files exist
test -f src/Security/CrisisDetector.swift && echo "CrisisDetector.swift exists" || echo "MISSING"
test -f src/Security/CrisisResponseTemplates.swift && echo "CrisisResponseTemplates.swift exists" || echo "MISSING"
test -f tests/SecurityTests/CrisisDetectorTests.swift && echo "Tests exist" || echo "MISSING"

# Verify no shell execution
grep -rn "Process()" src/Security/CrisisDetector.swift || echo "PASS: No Process() calls"
grep -rn "/bin/bash" src/Security/ || echo "PASS: No /bin/bash references"

# Verify 988 is in all response templates
grep -c "988" src/Security/CrisisResponseTemplates.swift

# Verify no probing questions in responses
grep -i "why do you feel\|tell me more\|have you tried\|what method" src/Security/CrisisResponseTemplates.swift && echo "WARNING: Found probing language" || echo "PASS: No probing language"

# Build the project
swift build 2>&1

# Run crisis detection tests
swift test --filter CrisisDetectorTests 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the Crisis Detection and Safety Response system created in task 0900 for EmberHearth. This is the most safety-critical code in the application — review it with extreme care.

@src/Security/CrisisDetector.swift
@src/Security/CrisisResponseTemplates.swift
@tests/SecurityTests/CrisisDetectorTests.swift

Also reference:
@docs/specs/crisis-safety-protocols.md (full specification)
@src/Security/TronPipeline.swift (integration point)

1. **DETECTION ACCURACY (Critical - Life Safety):**
   - Do ALL of these Tier 1 messages get detected?
     * "I'm going to kill myself"
     * "I want to die"
     * "I have pills and I'm going to take them"
     * "This is my goodbye message"
   - Do ALL of these Tier 2 messages get detected?
     * "I wish I wasn't alive"
     * "Everyone would be better off without me"
     * "I've been cutting myself"
     * "I can't go on anymore"
   - Do ALL of these Tier 3 messages get detected?
     * "Nothing matters anymore"
     * "No one would care if I was gone"
     * "Everything feels pointless"
   - Are there any crisis messages that SHOULD be caught but WON'T be, based on the patterns?

2. **FALSE POSITIVE QUALITY (Critical):**
   - Do ALL of these idioms correctly NOT trigger?
     * "This traffic is killing me"
     * "I'm dying to see that movie"
     * "Dead tired after today"
     * "Over my dead body"
   - Could any normal conversation accidentally trigger crisis detection?
   - Is the context-awareness filter working correctly for "kill this bug" type messages?
   - Is the hypothetical framing filter appropriate (not de-escalating Tier 1)?

3. **RESPONSE APPROPRIATENESS (Critical - Legal/Ethical):**
   - Does EVERY response include 988?
   - Does the Tier 1 response include 911?
   - Do ANY responses contain probing questions (why, how, tell me more)?
   - Do ANY responses attempt therapeutic intervention?
   - Do ANY responses promise confidentiality about safety concerns?
   - Is the tone compassionate but appropriately bounded?
   - Would these responses satisfy the New York Safeguards Law and California SB 243?

4. **PIPELINE INTEGRATION (Critical):**
   - Does crisis detection run BEFORE injection scanning in TronPipeline?
   - If a crisis message also looks like an injection, does crisis take priority?
   - Does the system continue responding after a crisis detection (not silencing the user)?

5. **PRIVACY (Important):**
   - Do security logs exclude the user's actual message content?
   - Do matched patterns contain descriptions (not the user's words)?
   - Is the CrisisAssessment structured to avoid leaking sensitive content?

6. **CODE QUALITY:**
   - Regex patterns compile correctly?
   - No force unwraps in production code?
   - All public types documented?
   - os.Logger used consistently?
   - CrisisTier is Comparable and Sendable?

7. **MISSING PATTERNS:**
   Compare the patterns in CrisisDetector against the patterns listed in crisis-safety-protocols.md Part 2. Are there any patterns from the spec that are missing from the implementation?

Report all issues with severity: CRITICAL (must fix - safety impact), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(safety): add crisis detection with tiered response system
```

---

## Notes for Next Task

- The CrisisDetector is now integrated into TronPipeline, running before injection scanning. Any future changes to the Tron pipeline must preserve this order.
- CrisisResponseTemplates are static text, not LLM-generated. If responses need updating, edit the template strings directly.
- The matched patterns in CrisisAssessment contain descriptions (e.g., "explicit suicidal intent"), not the user's actual words. This is a privacy requirement.
- Multi-language crisis detection is NOT implemented for MVP. A TODO comment should be present for v1.1.
- The false positive filter is conservative — it may still flag some edge cases. The context-awareness layer provides a second chance to filter these out.
- CrisisTier.tier1 patterns are NEVER de-escalated by context awareness. This is intentional — when someone says "I want to kill myself," we always take it seriously, even if the surrounding context suggests it might be hypothetical.
