// LLMProvider.swift
// EmberHearth
//
// Enumeration of supported LLM providers used as Keychain account identifiers.

import Foundation

/// Identifies an LLM provider for Keychain storage purposes.
public enum LLMProvider: String, CaseIterable {
    case claude = "claude"
    case openAI = "openai"
}