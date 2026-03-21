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
    // `buildIntegratedContext()` uses ContextBudget for all budget decisions
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

    /// The token budget allocation for this context builder.
    let budget: ContextBudget

    /// Total token budget for the context window.
    /// Derived from `budget.totalTokens`.
    var defaultTotalTokens: Int { budget.totalTokens }

    /// Logger for context building operations.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ContextBuilder"
    )

    // MARK: - Initialization

    /// Creates a new ContextBuilder with the specified budget.
    ///
    /// - Parameters:
    ///   - promptBuilder: The system prompt builder. Defaults to a new instance.
    ///   - verbosityAdapter: The verbosity adapter. Defaults to a new instance.
    ///   - budget: The context window budget allocation. Defaults to `.default`.
    init(
        promptBuilder: SystemPromptBuilder = SystemPromptBuilder(),
        verbosityAdapter: VerbosityAdapter = VerbosityAdapter(),
        budget: ContextBudget = .default
    ) {
        self.promptBuilder = promptBuilder
        self.verbosityAdapter = verbosityAdapter
        self.budget = budget
    }

    /// Creates a new ContextBuilder with a custom token count using default budget percentages.
    ///
    /// Convenience initializer for callers that only need to customize the total
    /// context window size without adjusting section percentages.
    ///
    /// - Parameters:
    ///   - promptBuilder: The system prompt builder. Defaults to a new instance.
    ///   - verbosityAdapter: The verbosity adapter. Defaults to a new instance.
    ///   - defaultTotalTokens: The total token budget. Creates a `ContextBudget` with
    ///     default percentages applied to this total.
    convenience init(
        promptBuilder: SystemPromptBuilder = SystemPromptBuilder(),
        verbosityAdapter: VerbosityAdapter = VerbosityAdapter(),
        defaultTotalTokens: Int
    ) {
        self.init(
            promptBuilder: promptBuilder,
            verbosityAdapter: verbosityAdapter,
            budget: ContextBudget(totalTokens: defaultTotalTokens)
        )
    }

    // MARK: - Enhanced Context Building

    /// Builds the complete context for an LLM request, integrating all systems.
    ///
    /// This is the primary method for assembling context. It:
    /// 1. Retrieves relevant facts via the fact retriever
    /// 2. Loads recent session messages
    /// 3. Builds the system prompt with personality, facts, time, and summary
    /// 4. Enforces system prompt budget by trimming lowest-importance facts
    /// 5. Detects verbosity from user message patterns
    /// 6. Formats everything as LLM messages, respecting the token budget
    /// 7. Drops oldest messages when recent message budget is exceeded
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

        // 3. Map facts to FactInfo, sorted highest importance first
        let factInfos: [FactInfo] = relevantFacts
            .map { fact in
                FactInfo(
                    content: fact.content,
                    importance: fact.importance,
                    lastUpdated: fact.updatedAt
                )
            }
            .sorted { $0.importance > $1.importance }

        // 4. Detect verbosity from user message patterns
        let userMessages = recentMessages
            .filter { $0.role == .user }
            .map { $0.content }
        let verbosityLevel = verbosityAdapter.detectVerbosity(
            from: newMessage,
            recentUserMessages: userMessages
        )
        let verbosityInstruction = verbosityAdapter.instruction(for: verbosityLevel)

        // 5. Build the system prompt, enforcing the combined system+facts budget
        let systemBudgetCombined = budget.systemPromptBudget + budget.factsBudget
        var trimmedFacts = factInfos
        var systemPrompt = promptBuilder.buildSystemPrompt(
            userFacts: trimmedFacts,
            sessionSummary: sessionSummary,
            currentDate: Date(),
            verbosityInstruction: verbosityInstruction,
            userName: userName
        )
        var systemPromptTokens = TokenCounter.estimateTokens(for: systemPrompt)

        // Trim lowest-importance facts until the system prompt fits its budget
        while systemPromptTokens > systemBudgetCombined && !trimmedFacts.isEmpty {
            trimmedFacts.removeLast()  // Facts are sorted high→low, so remove from end
            systemPrompt = promptBuilder.buildSystemPrompt(
                userFacts: trimmedFacts,
                sessionSummary: sessionSummary,
                currentDate: Date(),
                verbosityInstruction: verbosityInstruction,
                userName: userName
            )
            systemPromptTokens = TokenCounter.estimateTokens(for: systemPrompt)
        }

        if systemPromptTokens > systemBudgetCombined {
            logger.warning(
                "System prompt base exceeds budget even with no facts: \(systemPromptTokens) > \(systemBudgetCombined)"
            )
        }

        // 6. Include session summary within its budget
        var llmMessages: [LLMMessage] = []
        var summaryTokensUsed = 0

        if let summary = sessionSummary, !summary.isEmpty {
            let summaryContent = "[Conversation summary from earlier: \(summary)]"
            let summaryTokens = TokenCounter.estimateTokens(for: summaryContent) + TokenCounter.messageOverhead
            if summaryTokens <= budget.summaryBudget {
                llmMessages.append(LLMMessage(role: .assistant, content: summaryContent))
                summaryTokensUsed = summaryTokens
            } else {
                logger.debug(
                    "Summary exceeds budget (\(summaryTokens) > \(self.budget.summaryBudget)), skipping"
                )
            }
        }

        // 7. Add recent messages from newest to oldest (prefer recency),
        //    then reverse to restore chronological order for the LLM.
        let newMessageTokens = TokenCounter.estimateTokens(for: newMessage) + TokenCounter.messageOverhead
        let availableForHistory = max(0, budget.recentMessagesBudget - newMessageTokens)

        if newMessageTokens > budget.recentMessagesBudget {
            logger.warning(
                "New message exceeds recent messages budget: \(newMessageTokens) > \(self.budget.recentMessagesBudget). Including anyway."
            )
        }

        var includedMessages: [LLMMessage] = []
        var historyTokensUsed = 0

        for message in recentMessages.reversed() {
            let tokens = TokenCounter.estimateTokens(for: message.content) + TokenCounter.messageOverhead
            if historyTokensUsed + tokens > availableForHistory {
                break  // Stop adding older messages when budget is reached
            }
            includedMessages.insert(
                LLMMessage(role: message.role, content: message.content),
                at: 0
            )
            historyTokensUsed += tokens
        }
        llmMessages.append(contentsOf: includedMessages)

        // 8. Always include the new user message
        llmMessages.append(LLMMessage(role: .user, content: newMessage))

        let messageTokensUsed = historyTokensUsed + newMessageTokens
        let factsTokensUsed = trimmedFacts.reduce(0) {
            $0 + TokenCounter.estimateTokens(for: $1.content)
        }

        let tokenEstimates = TokenEstimates(
            systemPrompt: systemPromptTokens,
            recentMessages: messageTokensUsed,
            summary: summaryTokensUsed,
            facts: factsTokensUsed,
            budget: budget
        )

        logger.debug(
            "Budget usage — System: \(systemPromptTokens)/\(systemBudgetCombined), Messages: \(messageTokensUsed)/\(self.budget.recentMessagesBudget), Summary: \(summaryTokensUsed)/\(self.budget.summaryBudget)"
        )
        logger.info(
            "Context built: \(llmMessages.count) messages, ~\(tokenEstimates.totalInput) tokens, \(trimmedFacts.count) facts, verbosity=\(verbosityLevel.rawValue)"
        )

        return ContextBuildResult(
            messages: llmMessages,
            systemPrompt: systemPrompt,
            tokenEstimates: tokenEstimates,
            factsIncluded: trimmedFacts.count,
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
    /// Delegates to `TokenCounter.estimateTokens(for:)` for consistent
    /// word-based estimation across all context building operations.
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count (at least 1 for any input).
    func estimateTokens(for text: String) -> Int {
        TokenCounter.estimateTokens(for: text)
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
    /// Used by the legacy static `buildContext()` path. New code should use
    /// `TokenCounter.estimateTokens(for:)` instead.
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

    /// Per-section token breakdown for this context build.
    let tokenEstimates: TokenEstimates

    /// How many user facts were included in the system prompt.
    let factsIncluded: Int

    /// How many conversation messages were included (not counting the new message).
    let messagesIncluded: Int

    /// The detected verbosity level for this request.
    let verbosityLevel: VerbosityLevel

    /// Whether older messages were dropped to fit within the token budget.
    let wasTruncated: Bool

    /// Estimated total tokens (system prompt + messages + summary).
    /// Convenience accessor derived from `tokenEstimates.totalInput`.
    var tokenEstimate: Int { tokenEstimates.totalInput }

    // MARK: - Primary Initialization

    /// Creates a ContextBuildResult with full per-section token tracking.
    ///
    /// - Parameters:
    ///   - messages: The assembled LLM messages.
    ///   - systemPrompt: The assembled system prompt.
    ///   - tokenEstimates: Per-section token breakdown for this context build.
    ///   - factsIncluded: Number of facts in the system prompt.
    ///   - messagesIncluded: Number of history messages included.
    ///   - verbosityLevel: The detected verbosity level.
    ///   - wasTruncated: Whether older messages were dropped.
    init(
        messages: [LLMMessage],
        systemPrompt: String,
        tokenEstimates: TokenEstimates,
        factsIncluded: Int,
        messagesIncluded: Int,
        verbosityLevel: VerbosityLevel,
        wasTruncated: Bool
    ) {
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.tokenEstimates = tokenEstimates
        self.factsIncluded = factsIncluded
        self.messagesIncluded = messagesIncluded
        self.verbosityLevel = verbosityLevel
        self.wasTruncated = wasTruncated
    }

    // MARK: - Legacy Initialization

    /// Creates a ContextBuildResult using a flat token estimate.
    ///
    /// This initializer exists for backward compatibility with tests and callers
    /// written before per-section token tracking was introduced in task 0404.
    /// New code should use the primary memberwise initializer with `tokenEstimates:`.
    ///
    /// - Parameters:
    ///   - messages: The assembled LLM messages.
    ///   - systemPrompt: The assembled system prompt.
    ///   - tokenEstimate: Total estimated tokens (placed in recentMessages for tracking).
    ///   - factsIncluded: Number of facts in the system prompt.
    ///   - messagesIncluded: Number of history messages included.
    ///   - verbosityLevel: The detected verbosity level.
    ///   - wasTruncated: Whether older messages were dropped.
    init(
        messages: [LLMMessage],
        systemPrompt: String,
        tokenEstimate: Int,
        factsIncluded: Int,
        messagesIncluded: Int,
        verbosityLevel: VerbosityLevel,
        wasTruncated: Bool
    ) {
        self.messages = messages
        self.systemPrompt = systemPrompt
        self.tokenEstimates = TokenEstimates(
            systemPrompt: 0,
            recentMessages: tokenEstimate,
            summary: 0,
            facts: 0,
            budget: .default
        )
        self.factsIncluded = factsIncluded
        self.messagesIncluded = messagesIncluded
        self.verbosityLevel = verbosityLevel
        self.wasTruncated = wasTruncated
    }
}
