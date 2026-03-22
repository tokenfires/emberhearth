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
        let initialCount = sections.joined(separator: "\n").count
        logger.info("System prompt exceeds budget (\(initialCount) chars > \(maxCharacters)). Trimming facts.")

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
