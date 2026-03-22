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

// MARK: - Convenience Initialization

extension ContextBudget {

    /// Creates a budget with a custom total token count using the default percentages.
    ///
    /// Useful when testing or configuring a specific context window size
    /// without specifying custom percentages.
    ///
    /// - Parameter totalTokens: The total token count for this budget.
    init(totalTokens: Int) {
        self.init(
            totalTokens: totalTokens,
            systemPromptPercent: 0.10,
            recentMessagesPercent: 0.25,
            summaryPercent: 0.10,
            factsPercent: 0.15,
            taskStatePercent: 0.05,
            responseReservePercent: 0.35
        )
    }
}
