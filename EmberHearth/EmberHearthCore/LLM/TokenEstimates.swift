// TokenEstimates.swift
// EmberHearth
//
// Per-section token breakdown for context build results.

import Foundation

/// Per-section token breakdown from a context build operation.
///
/// This provides transparency into how the context window budget was used,
/// which is useful for debugging, monitoring, and the token-awareness UI.
struct TokenEstimates: Sendable, Equatable, CustomDebugStringConvertible {

    /// Tokens used by the system prompt (personality + facts + context).
    let systemPrompt: Int

    /// Tokens used by recent conversation messages.
    let recentMessages: Int

    /// Tokens used by the conversation summary.
    let summary: Int

    /// Tokens used by user facts (included in system prompt).
    let facts: Int

    /// Total estimated tokens for all input sections.
    var totalInput: Int {
        systemPrompt + recentMessages + summary
    }

    /// The budget that was allocated for each section.
    let budget: ContextBudget

    /// Whether any section exceeded its allocated budget.
    var anyOverBudget: Bool {
        systemPrompt > budget.systemPromptBudget + budget.factsBudget ||
        recentMessages > budget.recentMessagesBudget ||
        summary > budget.summaryBudget
    }

    /// Summary of usage vs budget for logging.
    var debugDescription: String {
        """
        Token Usage:
          System prompt: \(systemPrompt)/\(budget.systemPromptBudget + budget.factsBudget) tokens
          Recent messages: \(recentMessages)/\(budget.recentMessagesBudget) tokens
          Summary: \(summary)/\(budget.summaryBudget) tokens
          Total input: \(totalInput)/\(budget.totalInputBudget) tokens
        """
    }
}
