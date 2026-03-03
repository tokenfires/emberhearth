// LLMTypes.swift
// EmberHearth
//
// Core LLM message and role types.

import Foundation

/// The role of a participant in an LLM conversation.
public enum MessageRole: String, Codable, Equatable {
    case user
    case assistant
    case system
}

/// A single message in an LLM conversation.
public struct LLMMessage: Equatable {
    public let role: MessageRole
    public let content: String

    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }

    /// Convenience factory for a user message.
    public static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }

    /// Convenience factory for an assistant message.
    public static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }

    /// Convenience factory for a system message.
    public static func system(_ content: String) -> LLMMessage {
        LLMMessage(role: .system, content: content)
    }
}

/// The result of building a context window for an LLM request.
public struct BuiltContext {
    /// The (possibly truncated) system prompt.
    public let systemPrompt: String

    /// Ordered messages to send (oldest first, new message last).
    public let messages: [LLMMessage]

    /// How many recent messages were dropped due to token budget constraints.
    public let truncatedMessageCount: Int

    /// Rough token estimate for the entire context (system + messages).
    public let estimatedTokens: Int

    public init(
        systemPrompt: String,
        messages: [LLMMessage],
        truncatedMessageCount: Int,
        estimatedTokens: Int
    ) {
        self.systemPrompt = systemPrompt
        self.messages = messages
        self.truncatedMessageCount = truncatedMessageCount
        self.estimatedTokens = estimatedTokens
    }
}