// ClaudeAPIClient.swift
// EmberHearth
//
// Concrete implementation of LLMProviderProtocol for Anthropic's Claude API.

import Foundation

// MARK: - ClaudeAPIClient

/// Sends requests to Anthropic's Messages API.
/// Requires a valid API key stored in the Keychain under the `.claude` provider key.
public final class ClaudeAPIClient: LLMProviderProtocol {

    // MARK: - Private types

    /// The request body sent to the Claude Messages API.
    private struct RequestBody: Encodable {
        let model: String
        let maxTokens: Int
        let stream: Bool
        let system: String?
        let messages: [MessagePayload]

        struct MessagePayload: Encodable {
            let role: String
            let content: String
        }

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case stream
            case system
            case messages
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(model, forKey: .model)
            try container.encode(maxTokens, forKey: .maxTokens)
            try container.encode(stream, forKey: .stream)
            // Only encode `system` when it has a value
            if let system = system {
                try container.encode(system, forKey: .system)
            }
            try container.encode(messages, forKey: .messages)
        }
    }

    /// The response body from the Claude Messages API.
    private struct ResponseBody: Decodable {
        let id: String
        let model: String
        let stopReason: String
        let content: [ContentBlock]
        let usage: UsagePayload

        struct ContentBlock: Decodable {
            let type: String
            let text: String
        }

        struct UsagePayload: Decodable {
            let inputTokens: Int
            let outputTokens: Int

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }

        enum CodingKeys: String, CodingKey {
            case id
            case model
            case stopReason = "stop_reason"
            case content
            case usage
        }
    }

    /// The error body returned by the Claude API on failure.
    private struct APIErrorBody: Decodable {
        let error: ErrorDetail

        struct ErrorDetail: Decodable {
            let type: String
            let message: String
        }
    }

    // MARK: - Properties

    private let keychainManager: KeychainManager
    private let urlSession: URLSession
    private let model: String
    private let maxTokens: Int

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let anthropicVersion = "2023-06-01"

    // MARK: - LLMProviderProtocol

    public var isAvailable: Bool {
        (try? keychainManager.retrieve(for: .claude)) != nil
    }

    // MARK: - Init

    /// Creates a new ClaudeAPIClient.
    /// - Parameters:
    ///   - keychainManager: The Keychain manager used to retrieve the API key.
    ///   - urlSession: The URLSession to use for network requests (injectable for testing).
    ///   - model: The Claude model identifier to use.
    ///   - maxTokens: Maximum number of tokens to generate.
    public init(
        keychainManager: KeychainManager,
        urlSession: URLSession = .shared,
        model: String = "claude-sonnet-4-20250514",
        maxTokens: Int = 4096
    ) {
        self.keychainManager = keychainManager
        self.urlSession = urlSession
        self.model = model
        self.maxTokens = maxTokens
    }

    // MARK: - sendMessage

    public func sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse {
        // Retrieve API key — never log it
        guard let apiKey = try? keychainManager.retrieve(for: .claude) else {
            throw ClaudeAPIError.noAPIKey
        }

        // Build request body — filter out system-role messages
        let payloadMessages = messages
            .filter { $0.role != .system }
            .map { RequestBody.MessagePayload(role: $0.role.rawValue, content: $0.content) }

        let body = RequestBody(
            model: model,
            maxTokens: maxTokens,
            stream: false,
            system: systemPrompt,
            messages: payloadMessages
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, urlResponse) = try await urlSession.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw ClaudeAPIError.unexpectedStatusCode(-1)
        }

        switch httpResponse.statusCode {
        case 200:
            return try decodeSuccess(data: data, httpResponse: httpResponse)
        case 400:
            let message = (try? decodeErrorBody(data: data))?.error.message ?? "Bad request"
            throw ClaudeAPIError.badRequest(message)
        case 401:
            throw ClaudeAPIError.unauthorized
        case 429:
            let retryAfter = retryAfterValue(from: httpResponse)
            throw ClaudeAPIError.rateLimited(retryAfter: retryAfter)
        case 529:
            throw ClaudeAPIError.overloaded
        case 500...599:
            throw ClaudeAPIError.serverError(httpResponse.statusCode)
        default:
            throw ClaudeAPIError.unexpectedStatusCode(httpResponse.statusCode)
        }
    }

    // MARK: - streamMessage

    public func streamMessage(_ messages: [LLMMessage], systemPrompt: String?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ClaudeAPIError.notImplemented)
        }
    }

    // MARK: - Private helpers

    private func decodeSuccess(data: Data, httpResponse: HTTPURLResponse) throws -> LLMResponse {
        let decoder = JSONDecoder()
        guard let body = try? decoder.decode(ResponseBody.self, from: data) else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            throw ClaudeAPIError.decodingFailed(raw)
        }

        let text = body.content
            .filter { $0.type == "text" }
            .map(\.text)
            .joined()

        let stopReason = LLMStopReason(rawValue: body.stopReason) ?? .endTurn
        let usage = LLMTokenUsage(
            inputTokens: body.usage.inputTokens,
            outputTokens: body.usage.outputTokens
        )
        return LLMResponse(content: text, usage: usage, model: body.model, stopReason: stopReason)
    }

    private func decodeErrorBody(data: Data) throws -> APIErrorBody {
        try JSONDecoder().decode(APIErrorBody.self, from: data)
    }

    private func retryAfterValue(from response: HTTPURLResponse) -> Double? {
        guard let headerValue = response.value(forHTTPHeaderField: "Retry-After"),
              let seconds = Double(headerValue) else {
            return nil
        }
        return seconds
    }
}