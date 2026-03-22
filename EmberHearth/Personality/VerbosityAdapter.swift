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
