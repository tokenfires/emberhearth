// ContextBuilder.swift
// EmberHearth
//
// Builds a token-budgeted context window for LLM requests.

import Foundation
import os

/// Assembles the complete context for LLM requests by integrating
/// the personality system, memory system, and session history.
///
/// The context builder serves two roles:
/// 1. **Static context building** — `buildContext()` assembles a pre-built system
///    prompt with existing message arrays (backward-compatible with earlier callers).
/// 2. **Integrated context building** — `buildIntegratedContext()` assembles
///    the full context by calling into SessionManager, FactRetriever,
///    SystemPromptBuilder, and VerbosityAdapter.
///
/// ## Context Budget
///
/// For a 100K token context window:
/// - System prompt (personality + facts + context): ~10,000 tokens
/// - Recent conversation messages: ~25,000 tokens
/// - Session summary: ~10,000 tokens
/// - Response reserve: ~35,000 tokens
final class ContextBuilder {

    // MARK: - Static Budget Constants (Legacy — used only by buildContext())
    //
    // These constants back the static `buildContext()` API, which predates
    // the Hybrid Adaptive budget design in session-management.md §1.
    //
    // The architecture specifies:
    //   System prompt     ~10%  (10 000 tokens)
    //   Recent messages   ~25%  (25 000 tokens)  ← this constant
    //   Conversation summary ~10% (10 000 tokens)
    //   Retrieved memories ~15% (15 000 tokens)
    //   Active task state   ~5%  ( 5 000 tokens)
    //   Response reserve   ~35%  (35 000 tokens)  ← this constant
    //
    // `buildIntegratedContext()` computes all budgets inline as percentages
    // and does not use these constants.

    /// Total token budget for a single LLM request.
    public static let totalBudget: Int = 100_000

    /// Token budget reserved for the system prompt (~10%).
    public static let systemPromptBudget: Int = 10_000

    /// Token budget reserved for recent conversation messages (~25%).
    /// Used only by the legacy static `buildContext()` method.
    public static let recentMessagesBudget: Int = 25_000

    /// Token budget reserved for the model's response (~35%).
    /// Used only by the legacy static `buildContext()` method.
    public static let responseBudget: Int = 35_000

    /// Overhead tokens estimated per message (role label, formatting, etc.).
    static let perMessageOverhead: Int = 4

    // MARK: - Instance Properties

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
    /// 5. Formats everything as LLM messages, respecting the token budget
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
    ) throws -> ContextBuildResult {

        // 1. Load session state
        let session = try sessionManager.getOrCreateSession(for: phoneNumber)
        let recentMessages = try sessionManager.getRecentMessages(
            for: session,
            limit: 50  // Load more than we'll use; budget trimming happens below
        )
        let sessionSummary = session.summary

        // 2. Retrieve relevant facts
        let relevantFacts = try factRetriever.retrieveRelevantFacts(
            for: newMessage,
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
            .filter { $0.role == .user }
            .map { $0.content }
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
        let responseBudgetTokens = Int(Double(defaultTotalTokens) * 0.35)
        let summaryBudgetTokens = Int(Double(defaultTotalTokens) * 0.10)
        let availableForMessages = defaultTotalTokens
            - responseBudgetTokens
            - estimateTokens(for: systemPrompt)

        // 7. Format recent messages as LLM messages, respecting budget
        var llmMessages: [LLMMessage] = []
        var messageTokensUsed = 0

        // Include session summary as an early assistant message if available
        if let summary = sessionSummary, !summary.isEmpty {
            let summaryTokens = estimateTokens(for: summary)
            if summaryTokens <= summaryBudgetTokens {
                llmMessages.append(LLMMessage(
                    role: .assistant,
                    content: "[Conversation summary from earlier: \(summary)]"
                ))
                messageTokensUsed += summaryTokens
            }
        }

        // Add recent messages from newest to oldest to prefer recency,
        // then reverse to restore chronological order for the LLM.
        var includedMessages: [LLMMessage] = []
        for message in recentMessages.reversed() {
            let tokens = estimateTokens(for: message.content)
            if messageTokensUsed + tokens > availableForMessages {
                break  // Stop adding older messages when budget is reached
            }
            includedMessages.insert(
                LLMMessage(role: message.role, content: message.content),
                at: 0
            )
            messageTokensUsed += tokens
        }
        llmMessages.append(contentsOf: includedMessages)

        // 8. Add the new user message (always included)
        llmMessages.append(LLMMessage(role: .user, content: newMessage))

        let totalTokenEstimate = estimateTokens(for: systemPrompt)
            + messageTokensUsed
            + estimateTokens(for: newMessage)

        logger.info(
            "Context built: \(llmMessages.count) messages, ~\(totalTokenEstimate) tokens, \(factInfos.count) facts, verbosity=\(verbosityLevel.rawValue)"
        )

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

    // MARK: - Simple Context Building (Backward Compatible Instance API)

    /// Builds a simple context from raw messages without the full integration.
    ///
    /// This preserves backward compatibility with callers that don't use the
    /// full session/memory system. New code should use `buildIntegratedContext()`
    /// instead.
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

    // MARK: - Instance Token Estimation

    /// Estimates the number of tokens in a text string.
    ///
    /// Uses a word-based estimate: ~1.3 tokens per word for English text,
    /// plus 4 tokens of per-message framing overhead. Returns at least 1
    /// for any input, including empty strings (framing overhead still exists).
    ///
    /// This is intentionally different from the static `tokenEstimate(for:)`
    /// method below, which uses a character-based heuristic (ceiling of n/4)
    /// and returns 0 for empty strings. The two estimators serve different
    /// contexts:
    /// - This instance method is used by `buildIntegratedContext()` for
    ///   natural-language messages where word count is a better proxy.
    /// - The static method is used by the legacy `buildContext()` path and
    ///   the system prompt truncation logic, where byte-level accuracy matters.
    ///
    /// Both will be replaced by task 0404's `TokenCounter`, which will use
    /// the model's actual tokenizer via the Anthropic API.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count (at least 1 for any input).
    func estimateTokens(for text: String) -> Int {
        let wordCount = text.split(separator: " ").count
        return max(Int(Double(wordCount) * 1.3) + 4, 1)
    }

    // MARK: - Static API (Backward Compatible with Prior Callers)

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

    /// Returns a rough token estimate for a string using the heuristic of 4 characters per token.
    ///
    /// Uses ceiling division so that any non-zero string is at least 1 token.
    /// Returns 0 for empty strings (no content, no framing).
    ///
    /// This is intentionally different from the instance `estimateTokens(for:)`
    /// method above, which uses a word-based heuristic and includes framing
    /// overhead. See that method's documentation for the rationale behind
    /// having two estimators. Both will be replaced by task 0404's `TokenCounter`.
    public static func tokenEstimate(for text: String) -> Int {
        let charCount = text.count
        guard charCount > 0 else { return 0 }
        return (charCount + 3) / 4  // ceiling division by 4
    }

    /// Returns the estimated token count for a single message (content + per-message overhead).
    static func tokenEstimate(for message: LLMMessage) -> Int {
        return tokenEstimate(for: message.content) + perMessageOverhead
    }

    // MARK: - Private Static Helpers

    /// Truncates `text` to fit within `budget` tokens, appending "[truncated]" when cut.
    private static func fit(_ text: String, toBudget budget: Int) -> String {
        guard tokenEstimate(for: text) > budget else {
            return text
        }
        // Maximum characters that fit the budget (leaving room for "[truncated]" suffix).
        let suffix = "\n[truncated]"
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

// MARK: - ContextBuildResult

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
