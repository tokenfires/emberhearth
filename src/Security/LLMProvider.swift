// LLMProvider.swift
// EmberHearth
//
// Defines supported LLM providers and their associated metadata.

import Foundation

/// Represents a supported Large Language Model provider.
public enum LLMProvider: String, CaseIterable, Hashable {
    case claude
    case openai

    /// The account identifier used when storing the API key in the Keychain.
    public var keychainAccount: String {
        switch self {
        case .claude:
            return "api-key-claude"
        case .openai:
            return "api-key-openai"
        }
    }

    /// The expected prefix for a valid API key from this provider.
    public var apiKeyPrefix: String {
        switch self {
        case .claude:
            return "sk-ant-"
        case .openai:
            return "sk-"
        }
    }

    /// A human-readable display name for the provider.
    public var displayName: String {
        switch self {
        case .claude:
            return "Claude (Anthropic)"
        case .openai:
            return "OpenAI"
        }
    }
}