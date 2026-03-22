// SummaryGenerator.swift
// EmberHearth
//
// Generates rolling summaries of conversation history to manage context window.

import Foundation
import os

/// Generates concise summaries of conversation segments to maintain context
/// continuity without consuming the entire context window.
///
/// When a session accumulates too many messages, the SummaryGenerator:
/// 1. Takes the oldest batch of messages (leaving recent ones intact)
/// 2. Sends them to the LLM with a summarization prompt
/// 3. Stores the resulting summary in the session
/// 4. Signals that the summarized messages can be removed from active storage
///
/// This is a background operation — it does not block the response to the
/// user's current message.
///
/// ## Trigger Conditions
///
/// Summarization triggers when BOTH conditions are met:
/// - The session has more than `messageCountThreshold` messages (default: 30)
/// - The oldest `messagesToSummarize` messages exceed `tokenThreshold` tokens
///
/// ## Summary Format
///
/// The summary is written in third person and captures:
/// - Key topics discussed
/// - Decisions made
/// - Action items or things the user asked to be remembered
/// - The emotional tone of the conversation
final class SummaryGenerator {

    // MARK: - Configuration

    /// Number of total messages in the session before summarization is considered.
    /// Must exceed this count before the token threshold is checked.
    let messageCountThreshold: Int

    /// The number of oldest messages to include in each summarization batch.
    /// The most recent `recentMessagesToKeep` messages are always left intact.
    let messagesToSummarize: Int

    /// Number of recent messages to always keep verbatim (not summarized).
    /// These provide immediate conversational context.
    let recentMessagesToKeep: Int

    /// Token threshold for the messages being summarized.
    /// Summarization only triggers if the candidate messages exceed this many tokens.
    /// This prevents summarizing a few short messages unnecessarily.
    let tokenThreshold: Int

    /// Maximum tokens for the summary response from the LLM.
    let maxSummaryTokens: Int

    /// Logger for summary generation operations.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "SummaryGenerator"
    )

    // MARK: - Summarization Prompt

    /// The prompt sent to the LLM to generate a conversation summary.
    ///
    /// This is a carefully crafted prompt that produces consistent, useful
    /// summaries. It instructs the LLM to write in third person and focus
    /// on actionable information.
    static let summarizationPrompt: String = """
        Summarize this conversation concisely. Focus on:
        1. Key topics discussed
        2. Any decisions made or conclusions reached
        3. Action items or things the user asked to be remembered
        4. The emotional tone of the conversation

        Keep the summary under 500 words. Write in third person ("The user discussed...", "The user mentioned..."). Focus on what matters for continuing the conversation later — skip small talk and pleasantries unless they reveal something important about the user's state.

        If there is a previous summary provided, incorporate its key points into your new summary rather than repeating it verbatim. The goal is one cohesive summary of the entire conversation so far.
        """

    // MARK: - Initialization

    /// Creates a new SummaryGenerator with configurable thresholds.
    ///
    /// - Parameters:
    ///   - messageCountThreshold: Minimum total messages before summarization triggers.
    ///     Defaults to 30.
    ///   - messagesToSummarize: How many oldest messages to summarize per batch.
    ///     Defaults to 20.
    ///   - recentMessagesToKeep: How many recent messages to always keep verbatim.
    ///     Defaults to 10.
    ///   - tokenThreshold: Minimum tokens in candidate messages before summarization.
    ///     Defaults to 15,000.
    ///   - maxSummaryTokens: Maximum tokens for the LLM's summary response.
    ///     Defaults to 1024.
    init(
        messageCountThreshold: Int = 30,
        messagesToSummarize: Int = 20,
        recentMessagesToKeep: Int = 10,
        tokenThreshold: Int = 15_000,
        maxSummaryTokens: Int = 1024
    ) {
        self.messageCountThreshold = messageCountThreshold
        self.messagesToSummarize = messagesToSummarize
        self.recentMessagesToKeep = recentMessagesToKeep
        self.tokenThreshold = tokenThreshold
        self.maxSummaryTokens = maxSummaryTokens
    }

    // MARK: - Public API

    /// Determines whether the given session should trigger summarization.
    ///
    /// Summarization triggers when:
    /// 1. The session has more than `messageCountThreshold` messages, AND
    /// 2. The oldest messages (excluding the most recent `recentMessagesToKeep`)
    ///    exceed the `tokenThreshold`
    ///
    /// - Parameters:
    ///   - totalMessageCount: The total number of messages in the session.
    ///   - oldestMessagesTokenCount: The estimated token count of the messages
    ///     that would be summarized (the oldest `messagesToSummarize` messages).
    /// - Returns: True if summarization should be triggered.
    func shouldSummarize(
        totalMessageCount: Int,
        oldestMessagesTokenCount: Int
    ) -> Bool {
        guard totalMessageCount > messageCountThreshold else {
            return false
        }

        guard oldestMessagesTokenCount > tokenThreshold else {
            logger.debug("Message count threshold met (\(totalMessageCount) > \(self.messageCountThreshold)) but token threshold not met (\(oldestMessagesTokenCount) <= \(self.tokenThreshold))")
            return false
        }

        logger.info("Summarization triggered: \(totalMessageCount) messages, ~\(oldestMessagesTokenCount) tokens in candidate messages")
        return true
    }

    /// Generates a summary of the provided messages using the LLM.
    ///
    /// This method calls the LLM with the summarization prompt and the
    /// messages to summarize. It returns the generated summary text.
    ///
    /// If a previous summary exists, it is included in the prompt so the LLM
    /// can produce a cohesive summary that incorporates earlier context.
    ///
    /// This is a background operation — failures are handled gracefully.
    /// If summary generation fails, the method returns nil and the messages
    /// are kept as-is (no data is lost).
    ///
    /// - Parameters:
    ///   - messages: The messages to summarize. These are the oldest messages
    ///     in the session, formatted as "User: message" or "Ember: message" lines.
    ///   - previousSummary: The existing rolling summary to incorporate, if any.
    ///   - apiClient: The LLM provider for making the API call.
    /// - Returns: The generated summary text, or nil if generation failed.
    func generateSummary(
        for messages: [SummaryMessage],
        previousSummary: String?,
        apiClient: any LLMProviderProtocol
    ) async -> String? {
        guard !messages.isEmpty else {
            logger.warning("No messages to summarize")
            return nil
        }

        // Format messages for the summarization prompt
        let formattedMessages = messages.map { msg in
            let speaker = msg.isFromUser ? "User" : "Ember"
            return "\(speaker): \(msg.content)"
        }.joined(separator: "\n")

        // Build the full prompt
        var fullPrompt = Self.summarizationPrompt + "\n\n"

        if let previous = previousSummary, !previous.isEmpty {
            fullPrompt += "Previous summary of earlier conversation:\n\(previous)\n\n"
        }

        fullPrompt += "Conversation to summarize:\n\(formattedMessages)"

        // Make the LLM call (non-streaming background operation)
        do {
            let llmMessages = [
                LLMMessage(role: .user, content: fullPrompt)
            ]

            let response = try await apiClient.sendMessage(
                llmMessages,
                systemPrompt: "You are a conversation summarizer. Produce concise, factual summaries.",
                maxTokens: maxSummaryTokens
            )

            let trimmedSummary = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedSummary.isEmpty else {
                logger.error("LLM returned empty summary")
                return nil
            }

            logger.info("Summary generated: \(trimmedSummary.count) characters from \(messages.count) messages")
            return trimmedSummary

        } catch {
            // Graceful failure — keep messages as-is, do not lose data
            logger.error("Summary generation failed: \(error.localizedDescription). Messages will be kept as-is.")
            return nil
        }
    }

    /// Performs the full summarization workflow for a session.
    ///
    /// This is the high-level method that orchestrates the entire process:
    /// 1. Check if summarization should trigger
    /// 2. Select the oldest messages to summarize
    /// 3. Generate the summary via LLM
    /// 4. Return the result for the caller to update the session
    ///
    /// The caller (typically the message processing pipeline) is responsible
    /// for updating the session with the new summary and removing the
    /// summarized messages.
    ///
    /// - Parameters:
    ///   - allMessages: All messages in the session, in chronological order.
    ///   - previousSummary: The existing rolling summary, if any.
    ///   - apiClient: The LLM provider for making the API call.
    ///   - tokenEstimator: A closure that estimates token count for a string.
    ///     This allows the caller to provide the token estimation method
    ///     from ContextBuilder or TokenCounter.
    /// - Returns: A `SummarizationResult` if summarization was performed,
    ///   or nil if not needed or if generation failed.
    func summarizeIfNeeded(
        allMessages: [SummaryMessage],
        previousSummary: String?,
        apiClient: any LLMProviderProtocol,
        tokenEstimator: (String) -> Int
    ) async -> SummarizationResult? {
        let totalCount = allMessages.count

        // Determine which messages would be summarized
        let keepCount = min(recentMessagesToKeep, totalCount)
        let candidateCount = totalCount - keepCount
        guard candidateCount > 0 else { return nil }

        let candidateMessages = Array(allMessages.prefix(min(messagesToSummarize, candidateCount)))

        // Estimate tokens for the candidate messages
        let candidateTokens = candidateMessages.reduce(0) { total, msg in
            total + tokenEstimator(msg.content)
        }

        // Check trigger conditions
        guard shouldSummarize(
            totalMessageCount: totalCount,
            oldestMessagesTokenCount: candidateTokens
        ) else {
            return nil
        }

        // Generate the summary
        guard let summary = await generateSummary(
            for: candidateMessages,
            previousSummary: previousSummary,
            apiClient: apiClient
        ) else {
            return nil
        }

        return SummarizationResult(
            summary: summary,
            summarizedMessageCount: candidateMessages.count,
            summarizedMessageIds: candidateMessages.compactMap { $0.id }
        )
    }
}

// MARK: - Supporting Types

/// A simplified message representation for summarization.
///
/// This is a lightweight type that avoids importing the full session
/// message model. The caller maps from their message type to this one.
struct SummaryMessage: Sendable {
    /// Optional message ID for tracking which messages were summarized.
    let id: Int64?

    /// The message text content.
    let content: String

    /// True if this message was sent by the user, false if by Ember.
    let isFromUser: Bool

    /// When this message was sent.
    let timestamp: Date
}

/// The result of a successful summarization operation.
///
/// The caller uses this to update the session with the new summary
/// and remove the summarized messages from active storage.
struct SummarizationResult: Sendable {
    /// The generated summary text.
    let summary: String

    /// How many messages were compressed into this summary.
    let summarizedMessageCount: Int

    /// The IDs of the messages that were summarized.
    /// The caller should remove these from active message storage.
    let summarizedMessageIds: [Int64]
}
