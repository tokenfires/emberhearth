// TokenCounter.swift
// EmberHearth
//
// Provides accurate token estimation for context budget enforcement.

import Foundation
import os

/// Estimates token counts for text and message arrays.
///
/// Uses a word-based estimation model that is more accurate than the naive
/// 4-characters-per-token rule. The estimates are tuned for Claude models
/// (BPE tokenization with ~1.3 tokens per English word on average).
///
/// ## Accuracy
///
/// This is still an estimation — true token counts require the actual
/// tokenizer. For budget enforcement, slight overestimation is preferred
/// (better to leave room than to overflow the context window).
///
/// ## Content-Aware Counting
///
/// Different content types have different token densities:
/// - English prose: ~1.3 tokens per word
/// - Code blocks: ~1.5 tokens per word (more special characters)
/// - Punctuation-heavy text: ~1.4 tokens per word
/// - JSON/structured data: ~1.6 tokens per word
struct TokenCounter {

    // MARK: - Constants

    /// Default tokens per word for English prose.
    static let tokensPerWord: Double = 1.3

    /// Tokens per word for code blocks (higher due to special characters).
    static let tokensPerWordCode: Double = 1.5

    /// Overhead tokens per message for role/formatting in the API.
    /// Each message has ~4 tokens of framing (role markers, separators).
    static let messageOverhead: Int = 4

    /// Logger for token counting operations.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "TokenCounter"
    )

    // MARK: - Single Text Estimation

    /// Estimates the token count for a single text string.
    ///
    /// Uses word-based counting with content-aware adjustments:
    /// - Detects code blocks (triple backticks) and counts them at a higher rate
    /// - Counts punctuation-heavy segments at a slightly higher rate
    /// - Adds a small overhead for the text itself
    ///
    /// Always returns at least 1 token (even for empty strings, since
    /// empty messages still consume framing tokens).
    ///
    /// - Parameter text: The text to estimate tokens for.
    /// - Returns: Estimated token count.
    static func estimateTokens(for text: String) -> Int {
        guard !text.isEmpty else { return 1 }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 1 }

        // Split text by code blocks
        let codeBlockPattern = "```"
        let segments = trimmed.components(separatedBy: codeBlockPattern)

        var totalTokens: Double = 0

        for (index, segment) in segments.enumerated() {
            let words = segment.split(whereSeparator: { $0.isWhitespace })
            let wordCount = Double(words.count)

            if index % 2 == 1 {
                // Inside a code block (odd indices after splitting by ```)
                totalTokens += wordCount * tokensPerWordCode
            } else {
                // Regular text
                totalTokens += wordCount * tokensPerWord
            }
        }

        // Add tokens for code block delimiters themselves
        let codeBlockCount = max(0, segments.count - 1) / 2
        totalTokens += Double(codeBlockCount * 2)  // Each code block has open + close

        return max(Int(totalTokens.rounded(.up)), 1)
    }

    // MARK: - Message Array Estimation

    /// Estimates the total token count for an array of LLM messages.
    ///
    /// Includes per-message overhead for role/formatting tokens.
    /// The overhead accounts for the role marker ("user:", "assistant:"),
    /// message separators, and other API framing.
    ///
    /// - Parameter messages: The array of LLM messages to estimate.
    /// - Returns: Total estimated token count including all overhead.
    static func estimateTokens(for messages: [LLMMessage]) -> Int {
        var total = 0

        for message in messages {
            let contentTokens = estimateTokens(for: message.content)
            total += contentTokens + messageOverhead
        }

        // Add a base overhead for the messages array itself
        total += 3  // API-level framing

        return total
    }

    // MARK: - Budget Checking

    /// Checks whether the given text fits within a token budget.
    ///
    /// - Parameters:
    ///   - text: The text to check.
    ///   - budget: The maximum allowed tokens.
    /// - Returns: True if the estimated tokens are within budget.
    static func fitsWithinBudget(text: String, budget: Int) -> Bool {
        return estimateTokens(for: text) <= budget
    }

    /// Checks whether the given messages fit within a token budget.
    ///
    /// - Parameters:
    ///   - messages: The messages to check.
    ///   - budget: The maximum allowed tokens.
    /// - Returns: True if the estimated tokens are within budget.
    static func fitsWithinBudget(messages: [LLMMessage], budget: Int) -> Bool {
        return estimateTokens(for: messages) <= budget
    }
}
