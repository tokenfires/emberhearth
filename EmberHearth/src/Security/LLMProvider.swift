// LLMProvider.swift
// EmberHearth
//
// Enumeration of supported LLM providers used as Keychain account identifiers.

import Foundation

/// Identifies an LLM provider for Keychain storage purposes.
public enum LLMProvider: String, CaseIterable {
    case claude = "claude"
    case openai = "openai"

    /// The Keychain account identifier for this provider.
    public var keychainAccount: String {
        "api-key-\(rawValue)"
    }

    /// The expected API key prefix for format validation.
    public var apiKeyPrefix: String {
        switch self {
        case .claude: return "sk-ant-"
        case .openai: return "sk-"
        }
    }

    /// Human-readable display name.
    public var displayName: String {
        switch self {
        case .claude: return "Claude (Anthropic)"
        case .openai: return "OpenAI"
        }
    }
}
