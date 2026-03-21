// LLMProviderProtocol.swift
// EmberHearth
//
// Protocol that all LLM provider clients must conform to.

import Foundation

/// Protocol defining the interface for LLM provider clients.
public protocol LLMProviderProtocol {

    /// Whether the provider has credentials available and can handle requests.
    var isAvailable: Bool { get }

    /// Send a batch of messages and await the complete response.
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - systemPrompt: An optional system-level instruction.
    ///   - maxTokens: Maximum tokens for the response. Nil uses the provider's default.
    /// - Returns: The model's response.
    /// - Throws: A provider-specific error.
    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?, maxTokens: Int?) async throws -> LLMResponse

    /// Stream a response token-by-token as an AsyncThrowingStream.
    /// - Parameters:
    ///   - messages: The conversation history.
    ///   - systemPrompt: An optional system-level instruction.
    ///   - maxTokens: Maximum tokens for the response. Nil uses the provider's default.
    /// - Returns: An async stream of partial text chunks.
    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?, maxTokens: Int?) -> AsyncThrowingStream<String, Error>
}

// MARK: - Convenience Overloads

extension LLMProviderProtocol {

    /// Convenience overload that omits maxTokens (defaults to provider's default).
    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse {
        try await sendMessage(messages, systemPrompt: systemPrompt, maxTokens: nil)
    }

    /// Convenience overload that omits maxTokens (defaults to provider's default).
    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?) -> AsyncThrowingStream<String, Error> {
        streamMessage(messages, systemPrompt: systemPrompt, maxTokens: nil)
    }
}