// ContextBuilder.swift
// EmberHearth
//
// Builds a token-budgeted context window for LLM requests.

import Foundation

/// Builds a context window from a system prompt, recent conversation history,
/// and a new incoming message, respecting token budgets.
public enum ContextBuilder {

    // MARK: - Budget Constants

    /// Total token budget for a single LLM request.
    public static let totalBudget: Int = 100_000

    /// Token budget reserved for the system prompt.
    public static let systemPromptBudget: Int = 10_000

    /// Token budget reserved for recent conversation messages.
    public static let recentMessagesBudget: Int = 50_000

    /// Token budget reserved for the model's response.
    public static let responseBudget: Int = 40_000

    /// Overhead tokens estimated per message (role label, formatting, etc.).
    static let perMessageOverhead: Int = 4

    // MARK: - Token Estimation

    /// Returns a rough token estimate for a string using the heuristic of 4 characters per token.
    /// Uses ceiling division so that any non-zero string is at least 1 token.
    public static func tokenEstimate(for text: String) -> Int {
        let charCount = text.count
        guard charCount > 0 else { return 0 }
        return (charCount + 3) / 4  // ceiling division by 4
    }

    /// Returns the estimated token count for a single message (content + per-message overhead).
    static func tokenEstimate(for message: LLMMessage) -> Int {
        return tokenEstimate(for: message.content) + perMessageOverhead
    }

    // MARK: - Context Building

    /// Builds a `BuiltContext` that fits within token budgets.
    ///
    /// - Parameters:
    ///   - systemPrompt: The system-level instructions for the model.
    ///   - recentMessages: Ordered conversation history (oldest first).
    ///   - newMessage: The new user message to append.
    /// - Returns: A `BuiltContext` with budgeted content, message list, truncation count,
    ///            and estimated token total.
    public static func buildContext(
        systemPrompt: String,
        recentMessages: [LLMMessage],
        newMessage: String
    ) -> BuiltContext {

        // 1. Truncate system prompt to its budget.
        let fittedSystemPrompt = fit(systemPrompt, toBudget: systemPromptBudget)

        // 2. The new user message is always included.
        let newUserMessage = LLMMessage(role: .user, content: newMessage)

        // 3. Fit recent messages into the recent-messages budget, dropping oldest first.
        //    We work from the newest message backwards and keep what fits.
        let newMessageTokens = tokenEstimate(for: newUserMessage)
        let availableForRecent = recentMessagesBudget - newMessageTokens

        var keptMessages: [LLMMessage] = []
        var usedTokens = 0
        var truncatedCount = 0

        // Iterate from newest to oldest so we keep the most recent context.
        for message in recentMessages.reversed() {
            let cost = tokenEstimate(for: message)
            if usedTokens + cost <= availableForRecent {
                keptMessages.insert(message, at: 0)
                usedTokens += cost
            } else {
                truncatedCount += 1
            }
        }

        // 4. Append the new user message.
        keptMessages.append(newUserMessage)

        // 5. Compute total estimated tokens.
        let systemTokens = tokenEstimate(for: fittedSystemPrompt)
        let messageTokens = keptMessages.reduce(0) { $0 + tokenEstimate(for: $1) }
        let totalEstimated = systemTokens + messageTokens

        return BuiltContext(
            systemPrompt: fittedSystemPrompt,
            messages: keptMessages,
            truncatedMessageCount: truncatedCount,
            estimatedTokens: totalEstimated
        )
    }

    // MARK: - Private Helpers

    /// Truncates `text` to fit within `budget` tokens, appending "[truncated]" when cut.
    private static func fit(_ text: String, toBudget budget: Int) -> String {
        guard tokenEstimate(for: text) > budget else {
            return text
        }
        // Maximum characters that fit the budget (leaving room for "[truncated]" suffix).
        let suffix = "[truncated]"
        let suffixTokens = tokenEstimate(for: suffix)
        let contentBudget = budget - suffixTokens
        let maxChars = contentBudget * 4  // inverse of ceil(n/4) heuristic

        guard maxChars > 0 else {
            return suffix
        }

        let truncatedText = String(text.prefix(maxChars))
        return truncatedText + suffix
    }
}