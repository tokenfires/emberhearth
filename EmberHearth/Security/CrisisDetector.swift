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
    /// The crisis tier detected.
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
// TODO: v1.1 — Add multi-language crisis detection support
final class CrisisDetector: Sendable {

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
        let normalized = Self.normalizeMessage(message)

        guard !normalized.isEmpty else { return nil }

        // Step 1: Check false positive patterns first
        if matchesFalsePositive(normalized) {
            logger.debug("Crisis detector: false positive filter matched, skipping")
            return nil
        }

        // Step 2: Check Tier 1 (most severe)
        let tier1Matches = findMatches(in: normalized, patterns: Self.tier1Patterns)
        if !tier1Matches.isEmpty {
            // Tier 1 is never de-escalated by context — always take explicit crisis language seriously
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

    // MARK: - Text Normalization

    /// Normalizes a message for pattern matching: lowercases, trims whitespace,
    /// and converts smart/curly quotes to straight quotes. iMessage on iOS/macOS
    /// auto-corrects apostrophes to U+2019 (RIGHT SINGLE QUOTATION MARK), which
    /// would cause regex patterns using U+0027 (APOSTROPHE) to silently fail.
    private static func normalizeMessage(_ message: String) -> String {
        message
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")
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
        ("i was (hospitalized|in the hospital) for", "crisis hospitalization history"),
        ("last time i (tried|attempted)", "references past attempt")
    ]

    // Tier 3: Potential Concern — Vague references, indirect signals
    private static let tier3Patterns: [(pattern: String, description: String)] = [
        // General hopelessness
        ("nothing matters( anymore)?", "nihilistic statement"),
        ("what's the point of (anything|living|going on)", "questioning purpose"),
        ("i don't (care|matter)", "self-devaluation"),
        ("everything feels (pointless|hopeless|meaningless)", "pervasive hopelessness"),

        // Isolation signals
        ("no one (would (care|notice|miss me)|cares|loves me)", "perceived isolation"),
        ("i('m| am) (all )?alone", "loneliness expression"),
        ("nobody (loves|wants|needs) me", "perceived rejection"),

        // Indirect mentions
        ("thinking about ending", "indirect ending reference"),
        ("don't want to wake up", "doesn't want to wake up"),
        ("wouldn't mind (if i|not waking)", "passive death wish"),
        ("(want to|wish i could|need to|going to) disappear", "desire to disappear"),
        ("i('m| am) really struggling", "struggling expression"),
        ("i can't cope", "can't cope"),

        // Resource awareness (user mentioning crisis resources may be an indirect signal)
        ("suicide (hotline|prevention|lifeline)", "mentions suicide resources"),
        ("crisis (line|center|help)", "mentions crisis resources")
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

        // If the message is predominantly about non-crisis topics, it's likely a false positive.
        // Be more aggressive for Tier 3 (vague signals).
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
                if tier == .tier3 { return true }
                // For Tier 2, only de-escalate on very explicit fiction signals
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
