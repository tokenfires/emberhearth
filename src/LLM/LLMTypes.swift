// LLMTypes.swift
// EmberHearth
//
// Core types shared across LLM providers.

import Foundation

// MARK: - LLMMessage

/// A single message in a conversation.
public struct LLMMessage: Equatable {
    public let role: LLMRole
    public let content: String

    public init(role: LLMRole, content: String) {
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
}

// MARK: - LLMRole

/// The role of a participant in a conversation.
public enum LLMRole: String, Equatable {
    case user
    case assistant
    case system
}

// MARK: - LLMTokenUsage

/// Token consumption for a single API call.
public struct LLMTokenUsage: Equatable {
    public let inputTokens: Int
    public let outputTokens: Int

    public var totalTokens: Int {
        inputTokens + outputTokens
    }

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - LLMStopReason

/// Why the model stopped generating tokens.
public enum LLMStopReason: String, Equatable {
    case endTurn      = "end_turn"
    case maxTokens    = "max_tokens"
    case stopSequence = "stop_sequence"
}

// MARK: - LLMResponse

/// The complete response from an LLM provider.
public struct LLMResponse: Equatable {
    public let content: String
    public let usage: LLMTokenUsage
    public let model: String
    public let stopReason: LLMStopReason

    public init(content: String, usage: LLMTokenUsage, model: String, stopReason: LLMStopReason) {
        self.content = content
        self.usage = usage
        self.model = model
        self.stopReason = stopReason
    }
}