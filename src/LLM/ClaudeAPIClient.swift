// ClaudeAPIClient.swift
// EmberHearth
//
// HTTP client for the Claude streaming API.

import Foundation
import os

/// Client for interacting with the Claude API over HTTP with SSE streaming.
///
/// Conforms to `LLMProviderProtocol` using the Anthropic Messages API.
/// All requests use streaming (`stream: true`) and accumulate the full
/// response before returning it from `sendMessage`.
final class ClaudeAPIClient: LLMProviderProtocol, Sendable {

    // MARK: - Constants

    private static let messagesPath = "/v1/messages"
    private static let defaultModel = "claude-sonnet-4-6"
    private static let defaultMaxTokens = 1024
    private static let anthropicVersion = "2023-06-01"

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ClaudeAPIClient"
    )

    // MARK: - Properties

    private let apiKey: String
    private let session: URLSession
    private let baseURL: URL

    // MARK: - LLMProviderProtocol

    var isAvailable: Bool { !apiKey.isEmpty }

    // MARK: - Initialization

    /// The default base URL for the Anthropic API.
    static let defaultBaseURL = URL(string: "https://api.anthropic.com")
        ?? URL(fileURLWithPath: "/")

    init(
        apiKey: String,
        session: URLSession = .shared,
        baseURL: URL = ClaudeAPIClient.defaultBaseURL
    ) {
        self.apiKey = apiKey
        self.session = session
        self.baseURL = baseURL
    }

    // MARK: - LLMProviderProtocol: sendMessage

    /// Sends a message batch and returns the complete response.
    ///
    /// Uses the streaming API internally and accumulates all `content_block_delta`
    /// events to produce the full text response.
    func sendMessage(
        _ messages: [LLMMessage],
        systemPrompt: String?,
        maxTokens: Int?
    ) async throws -> LLMResponse {
        var fullText = ""

        let stream = streamMessage(messages, systemPrompt: systemPrompt, maxTokens: maxTokens)
        for try await chunk in stream {
            fullText += chunk
        }

        // Token counts are not tracked in the streaming accumulation path for MVP.
        // The text content is what matters for message routing.
        return LLMResponse(
            content: fullText,
            usage: LLMTokenUsage(inputTokens: 0, outputTokens: 0),
            model: Self.defaultModel,
            stopReason: .endTurn
        )
    }

    // MARK: - LLMProviderProtocol: streamMessage

    /// Streams a response token-by-token.
    ///
    /// Opens a streaming SSE connection to the Claude Messages API and
    /// yields each `content_block_delta` text chunk as it arrives.
    func streamMessage(
        _ messages: [LLMMessage],
        systemPrompt: String?,
        maxTokens: Int?
    ) -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try self.buildRequest(
                        messages: messages,
                        systemPrompt: systemPrompt,
                        maxTokens: maxTokens ?? Self.defaultMaxTokens
                    )

                    let (asyncBytes, response) = try await self.session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw ClaudeAPIError.networkError("Non-HTTP response")
                    }

                    try Self.validateStatus(httpResponse)

                    // Read bytes into lines manually instead of using
                    // asyncBytes.lines, which skips empty lines on macOS 26.
                    // SSE requires empty lines as event delimiters.
                    let sseLines = Self.linesPreservingEmpty(from: asyncBytes)
                    let events = SSEParser.parse(lines: sseLines)

                    for try await event in events {
                        if let chunk = SSEParser.extractChunk(from: event) {
                            if !chunk.deltaText.isEmpty {
                                continuation.yield(chunk.deltaText)
                            }
                            if chunk.stopReason != nil {
                                break
                            }
                        }
                    }

                    continuation.finish()
                } catch let error as ClaudeAPIError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: ClaudeAPIError.networkError(error.localizedDescription))
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private Helpers

    /// Reads bytes from a URLSession async stream and yields lines as strings,
    /// **including empty lines**. This replaces `asyncBytes.lines` which skips
    /// empty lines — a problem for SSE parsing where empty lines delimit events.
    private static func linesPreservingEmpty(
        from asyncBytes: URLSession.AsyncBytes
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var buffer = Data()
                let newline = UInt8(ascii: "\n")
                let cr = UInt8(ascii: "\r")
                do {
                    for try await byte in asyncBytes {
                        if byte == newline {
                            // Yield the line (strip trailing \r if present)
                            if buffer.last == cr {
                                buffer.removeLast()
                            }
                            let line = String(data: buffer, encoding: .utf8) ?? ""
                            continuation.yield(line)
                            buffer.removeAll(keepingCapacity: true)
                        } else {
                            buffer.append(byte)
                        }
                    }
                    // Flush remaining bytes
                    if !buffer.isEmpty {
                        let line = String(data: buffer, encoding: .utf8) ?? ""
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    /// Builds the HTTP request for the Messages API.
    private func buildRequest(
        messages: [LLMMessage],
        systemPrompt: String?,
        maxTokens: Int
    ) throws -> URLRequest {
        guard !apiKey.isEmpty else {
            throw ClaudeAPIError.noAPIKey
        }

        let url = baseURL.appendingPathComponent(Self.messagesPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        var body: [String: Any] = [
            "model": Self.defaultModel,
            "max_tokens": maxTokens,
            "stream": true,
            "messages": messages.map { msg in
                ["role": msg.role.rawValue, "content": msg.content]
            }
        ]

        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Validates the HTTP status code and throws the appropriate error.
    private static func validateStatus(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw ClaudeAPIError.unauthorized
        case 400:
            throw ClaudeAPIError.badRequest("HTTP 400")
        case 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw ClaudeAPIError.rateLimited(retryAfter: retryAfter)
        case 500, 502, 503:
            throw ClaudeAPIError.serverError(statusCode: response.statusCode)
        case 529:
            throw ClaudeAPIError.overloaded
        default:
            throw ClaudeAPIError.unknown("HTTP \(response.statusCode)")
        }
    }
}