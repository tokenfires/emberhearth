# Task 0201: Claude API Client with Provider Protocol

**Milestone:** M3 - LLM Integration
**Unit:** 3.1 - Claude API Client
**Phase:** 1
**Depends On:** 0200 (KeychainManager, LLMProvider enum)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; contains naming conventions, security boundaries, no shell execution rule
2. `src/Security/KeychainManager.swift` — Read entirely; you will use this to retrieve API keys. Note the `retrieve(for:)` method returns `String?`
3. `src/Security/LLMProvider.swift` — Read entirely; the `LLMProvider` enum (`.claude`, `.openai`) is already defined here. Your protocol must use a different name.
4. `docs/specs/api-setup-guide.md` — Focus on lines 159-266 for API key format (sk-ant-api03-*) and validation patterns
5. `docs/architecture/decisions/0008-claude-api-primary-llm.md` — Read entirely; contains the `LLMProvider` protocol sketch (lines ~66-78) and model details
6. `docs/specs/error-handling.md` — Focus on lines 60-78 for LLM failure modes table and retry policy; also lines 280-335 for logging strategy (never log request/response bodies)

> **Context Budget Note:** api-setup-guide.md is ~650 lines; focus only on lines 159-266. error-handling.md is ~587 lines; focus on lines 60-78 and 280-335. Skip all UI wireframes, database sections, and XPC sections.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Claude API Client for EmberHearth, a native macOS personal AI assistant. This task creates the LLM provider protocol and the concrete Claude (Anthropic) implementation. Streaming will be added in task 0202 — this task implements only the non-streaming (synchronous) request path and stubs the streaming method.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., ClaudeAPIClient.swift)
- NEVER log or print API keys, request bodies, or response bodies
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- No third-party dependencies — use only Apple frameworks (Foundation, Security, os)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target

DEPENDENCY CONTEXT:
- Task 0200 created these files in src/Security/:
  - LLMProvider.swift — enum with cases .claude and .openai, has .keychainAccount, .displayName, .apiKeyPrefix
  - KeychainError.swift — error enum for Keychain operations
  - KeychainManager.swift — manages Keychain, has retrieve(for: LLMProvider) -> String?

NAMING CONFLICT NOTE:
- The name `LLMProvider` is already taken by the enum in src/Security/LLMProvider.swift.
- The PROTOCOL for LLM provider abstraction must be named `LLMProviderProtocol`.
- This avoids any naming collision.

STEP 1: Create the LLM message and response types

File: src/LLM/LLMTypes.swift
```swift
// LLMTypes.swift
// EmberHearth
//
// Shared types for LLM provider communication.

import Foundation

/// Represents a role in an LLM conversation.
enum LLMMessageRole: String, Codable, Sendable {
    case system = "system"
    case user = "user"
    case assistant = "assistant"
}

/// A single message in an LLM conversation.
struct LLMMessage: Codable, Sendable, Equatable {
    /// The role of the message sender.
    let role: LLMMessageRole
    /// The text content of the message.
    let content: String

    /// Creates a user message.
    static func user(_ content: String) -> LLMMessage {
        LLMMessage(role: .user, content: content)
    }

    /// Creates an assistant message.
    static func assistant(_ content: String) -> LLMMessage {
        LLMMessage(role: .assistant, content: content)
    }
}

/// Token usage information from an LLM response.
struct LLMTokenUsage: Sendable, Equatable {
    /// Number of tokens in the input (prompt).
    let inputTokens: Int
    /// Number of tokens in the output (response).
    let outputTokens: Int
    /// Total tokens used (input + output).
    var totalTokens: Int { inputTokens + outputTokens }
}

/// The reason the LLM stopped generating.
enum LLMStopReason: String, Sendable, Equatable {
    case endTurn = "end_turn"
    case maxTokens = "max_tokens"
    case stopSequence = "stop_sequence"
    case unknown
}

/// A complete (non-streaming) response from an LLM provider.
struct LLMResponse: Sendable, Equatable {
    /// The generated text content.
    let content: String
    /// Token usage statistics.
    let usage: LLMTokenUsage
    /// The model that generated this response.
    let model: String
    /// The reason generation stopped.
    let stopReason: LLMStopReason
}

/// A single chunk from a streaming LLM response.
struct LLMStreamChunk: Sendable {
    /// The incremental text content (may be empty for non-content events).
    let deltaText: String
    /// The type of streaming event that produced this chunk.
    let eventType: String
    /// Final usage statistics (only present on the last chunk).
    let usage: LLMTokenUsage?
    /// The stop reason (only present on the last chunk).
    let stopReason: LLMStopReason?
}
```

STEP 2: Create the LLM provider protocol

File: src/LLM/LLMProviderProtocol.swift
```swift
// LLMProviderProtocol.swift
// EmberHearth
//
// Protocol defining the interface for LLM provider implementations.

import Foundation

/// Protocol that all LLM provider implementations must conform to.
///
/// This abstraction allows EmberHearth to support multiple LLM providers
/// (Claude, OpenAI, local models) through a common interface.
///
/// Note: The name `LLMProviderProtocol` is used because `LLMProvider` is already
/// taken by the enum in src/Security/LLMProvider.swift that identifies providers
/// for Keychain storage.
protocol LLMProviderProtocol: Sendable {
    /// Sends a non-streaming message to the LLM and waits for the complete response.
    ///
    /// - Parameters:
    ///   - messages: The conversation history (user and assistant messages).
    ///              Do NOT include system messages here — use systemPrompt instead.
    ///   - systemPrompt: Optional system prompt to set the LLM's behavior.
    /// - Returns: The complete LLM response.
    /// - Throws: Provider-specific errors (e.g., `ClaudeAPIError`).
    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse

    /// Sends a streaming message to the LLM, yielding chunks as they arrive.
    ///
    /// - Parameters:
    ///   - messages: The conversation history (user and assistant messages).
    ///   - systemPrompt: Optional system prompt to set the LLM's behavior.
    /// - Returns: An async stream of response chunks.
    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?) -> AsyncThrowingStream<LLMStreamChunk, Error>

    /// Whether this provider is currently available (has valid credentials, network, etc.).
    var isAvailable: Bool { get }
}
```

STEP 3: Create the Claude API error type

File: src/LLM/ClaudeAPIError.swift
```swift
// ClaudeAPIError.swift
// EmberHearth
//
// Error types specific to the Claude (Anthropic) API.

import Foundation

/// Errors that can occur when communicating with the Claude API.
enum ClaudeAPIError: Error, Sendable, Equatable {
    /// No API key is configured for Claude. User needs to set one up.
    case noAPIKey

    /// The API key is invalid or has been revoked (HTTP 401).
    case unauthorized

    /// The API rate limit has been exceeded (HTTP 429).
    /// `retryAfter` is the number of seconds to wait before retrying, if provided by the API.
    case rateLimited(retryAfter: TimeInterval?)

    /// The Anthropic API returned a server error (HTTP 5xx).
    /// `statusCode` is the actual HTTP status code.
    case serverError(statusCode: Int)

    /// A network-level error occurred (DNS failure, connection reset, etc.).
    case networkError(String)

    /// The request timed out.
    case timeout

    /// The API response could not be parsed.
    case invalidResponse(String)

    /// The API is temporarily overloaded (HTTP 529).
    case overloaded

    /// The request was malformed (HTTP 400). Usually a programming error.
    case badRequest(String)

    /// Human-readable description for logging. NEVER includes API keys or message content.
    var localizedDescription: String {
        switch self {
        case .noAPIKey:
            return "No API key configured for Claude."
        case .unauthorized:
            return "Claude API key is invalid or revoked (401)."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Claude API rate limited. Retry after \(Int(seconds)) seconds."
            }
            return "Claude API rate limited."
        case .serverError(let statusCode):
            return "Claude API server error (\(statusCode))."
        case .networkError(let message):
            return "Network error communicating with Claude API: \(message)"
        case .timeout:
            return "Claude API request timed out."
        case .invalidResponse(let detail):
            return "Invalid response from Claude API: \(detail)"
        case .overloaded:
            return "Claude API is temporarily overloaded (529)."
        case .badRequest(let detail):
            return "Bad request to Claude API: \(detail)"
        }
    }
}
```

STEP 4: Create the Claude API Client

File: src/LLM/ClaudeAPIClient.swift
```swift
// ClaudeAPIClient.swift
// EmberHearth
//
// Claude (Anthropic) API client implementing LLMProviderProtocol.

import Foundation
import os

/// Client for communicating with the Anthropic Claude API.
///
/// Uses URLSession for HTTP communication. No third-party dependencies.
///
/// Usage:
/// ```swift
/// let client = ClaudeAPIClient(keychainManager: KeychainManager())
/// let response = try await client.sendMessage(
///     [.user("Hello!")],
///     systemPrompt: "You are a helpful assistant."
/// )
/// print(response.content)
/// ```
final class ClaudeAPIClient: LLMProviderProtocol, @unchecked Sendable {

    // MARK: - Constants

    /// The Claude API endpoint for the messages API.
    static let apiEndpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    /// The API version header value. This is the Anthropic API version, not the model version.
    static let apiVersion = "2023-06-01"

    /// Default model to use for requests.
    static let defaultModel = "claude-sonnet-4-20250514"

    /// Default maximum tokens for the response.
    static let defaultMaxTokens = 1024

    /// Request timeout in seconds.
    static let requestTimeout: TimeInterval = 30.0

    // MARK: - Properties

    /// The Keychain manager used to retrieve the API key.
    private let keychainManager: KeychainManager

    /// The URLSession used for HTTP requests.
    /// Injected for testability (tests can provide a mock session).
    private let urlSession: URLSession

    /// The model to use for requests. Can be overridden for testing or configuration.
    let model: String

    /// The maximum tokens for responses. Can be overridden per-request in the future.
    let maxTokens: Int

    /// Logger for API client events. NEVER logs request/response bodies or API keys.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ClaudeAPIClient"
    )

    // MARK: - Initialization

    /// Creates a new Claude API client.
    ///
    /// - Parameters:
    ///   - keychainManager: The Keychain manager to retrieve the API key from.
    ///   - urlSession: The URLSession to use. Defaults to `.shared`. Pass a custom session for testing.
    ///   - model: The Claude model ID. Defaults to `claude-sonnet-4-20250514`.
    ///   - maxTokens: Maximum tokens for responses. Defaults to 1024.
    init(
        keychainManager: KeychainManager,
        urlSession: URLSession = .shared,
        model: String = ClaudeAPIClient.defaultModel,
        maxTokens: Int = ClaudeAPIClient.defaultMaxTokens
    ) {
        self.keychainManager = keychainManager
        self.urlSession = urlSession
        self.model = model
        self.maxTokens = maxTokens
    }

    // MARK: - LLMProviderProtocol

    /// Whether the Claude API is currently available (has a stored API key).
    var isAvailable: Bool {
        return keychainManager.hasKey(for: .claude)
    }

    /// Sends a non-streaming request to the Claude API.
    ///
    /// - Parameters:
    ///   - messages: Conversation messages (user/assistant pairs). Do NOT include system messages.
    ///   - systemPrompt: Optional system prompt.
    /// - Returns: The complete LLM response.
    /// - Throws: `ClaudeAPIError` on failure.
    func sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse {
        // Retrieve the API key from Keychain
        guard let apiKey = try keychainManager.retrieve(for: .claude) else {
            Self.logger.error("No Claude API key found in Keychain.")
            throw ClaudeAPIError.noAPIKey
        }

        // Build the request
        let request = try buildRequest(messages: messages, systemPrompt: systemPrompt, apiKey: apiKey, stream: false)

        Self.logger.info("Sending non-streaming request to Claude API (model: \(self.model), maxTokens: \(self.maxTokens))")

        // Execute the request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let error as URLError {
            if error.code == .timedOut {
                Self.logger.error("Claude API request timed out.")
                throw ClaudeAPIError.timeout
            }
            Self.logger.error("Network error: \(error.localizedDescription)")
            throw ClaudeAPIError.networkError(error.localizedDescription)
        } catch {
            Self.logger.error("Unexpected error during API request: \(error.localizedDescription)")
            throw ClaudeAPIError.networkError(error.localizedDescription)
        }

        // Validate the HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.invalidResponse("Response is not an HTTP response.")
        }

        // Handle non-success status codes
        if httpResponse.statusCode != 200 {
            throw try mapHTTPError(statusCode: httpResponse.statusCode, data: data, headers: httpResponse.allHeaderFields)
        }

        // Parse the successful response
        return try parseResponse(data: data)
    }

    /// Sends a streaming request to the Claude API.
    /// NOTE: Streaming implementation is added in task 0202. This is a stub.
    ///
    /// - Parameters:
    ///   - messages: Conversation messages.
    ///   - systemPrompt: Optional system prompt.
    /// - Returns: An async stream of response chunks.
    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        // Stub — will be implemented in task 0202
        return AsyncThrowingStream { continuation in
            continuation.finish(throwing: ClaudeAPIError.invalidResponse("Streaming not yet implemented. See task 0202."))
        }
    }

    // MARK: - Request Building

    /// Builds an HTTP request for the Claude Messages API.
    ///
    /// - Parameters:
    ///   - messages: The conversation messages.
    ///   - systemPrompt: Optional system prompt.
    ///   - apiKey: The API key (from Keychain).
    ///   - stream: Whether this is a streaming request.
    /// - Returns: A configured URLRequest.
    /// - Throws: `ClaudeAPIError` if the request cannot be constructed.
    private func buildRequest(
        messages: [LLMMessage],
        systemPrompt: String?,
        apiKey: String,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: Self.apiEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.requestTimeout

        // Required headers
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        // Build the request body
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "stream": stream
        ]

        // Add system prompt if provided
        if let systemPrompt = systemPrompt, !systemPrompt.isEmpty {
            body["system"] = systemPrompt
        }

        // Convert messages to the API format
        // Filter out system messages — Claude API uses a separate "system" field
        let apiMessages = messages
            .filter { $0.role != .system }
            .map { message -> [String: String] in
                return [
                    "role": message.role.rawValue,
                    "content": message.content
                ]
            }

        body["messages"] = apiMessages

        // Serialize to JSON
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw ClaudeAPIError.invalidResponse("Failed to serialize request body: \(error.localizedDescription)")
        }

        return request
    }

    // MARK: - Response Parsing

    /// Parses a successful (HTTP 200) response from the Claude API.
    ///
    /// Expected response format:
    /// ```json
    /// {
    ///   "id": "msg_...",
    ///   "type": "message",
    ///   "role": "assistant",
    ///   "content": [{"type": "text", "text": "Hello!"}],
    ///   "model": "claude-sonnet-4-20250514",
    ///   "stop_reason": "end_turn",
    ///   "usage": {"input_tokens": 10, "output_tokens": 25}
    /// }
    /// ```
    private func parseResponse(data: Data) throws -> LLMResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeAPIError.invalidResponse("Response is not valid JSON.")
        }

        // Extract content — it's an array of content blocks
        guard let contentArray = json["content"] as? [[String: Any]] else {
            throw ClaudeAPIError.invalidResponse("Missing 'content' array in response.")
        }

        // Extract text from all text content blocks
        let textContent = contentArray
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()

        // Extract usage
        guard let usageDict = json["usage"] as? [String: Any],
              let inputTokens = usageDict["input_tokens"] as? Int,
              let outputTokens = usageDict["output_tokens"] as? Int else {
            throw ClaudeAPIError.invalidResponse("Missing or invalid 'usage' in response.")
        }

        // Extract model
        let responseModel = json["model"] as? String ?? model

        // Extract stop reason
        let stopReasonString = json["stop_reason"] as? String ?? "unknown"
        let stopReason = LLMStopReason(rawValue: stopReasonString) ?? .unknown

        let usage = LLMTokenUsage(inputTokens: inputTokens, outputTokens: outputTokens)

        Self.logger.info("Claude API response received. Input tokens: \(inputTokens), output tokens: \(outputTokens), stop reason: \(stopReasonString)")

        return LLMResponse(
            content: textContent,
            usage: usage,
            model: responseModel,
            stopReason: stopReason
        )
    }

    // MARK: - Error Mapping

    /// Maps an HTTP error status code to a ClaudeAPIError.
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code.
    ///   - data: The response body (may contain error details).
    ///   - headers: The response headers (may contain Retry-After).
    /// - Returns: The appropriate ClaudeAPIError.
    private func mapHTTPError(statusCode: Int, data: Data, headers: [AnyHashable: Any]) throws -> ClaudeAPIError {
        // Try to extract error message from response body (for logging only — never expose to user)
        let errorMessage: String
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorDict = json["error"] as? [String: Any],
           let message = errorDict["message"] as? String {
            errorMessage = message
        } else {
            errorMessage = "No error details available."
        }

        Self.logger.error("Claude API error. Status: \(statusCode), message: \(errorMessage)")

        switch statusCode {
        case 400:
            return .badRequest(errorMessage)
        case 401:
            return .unauthorized
        case 429:
            // Check for Retry-After header
            let retryAfter: TimeInterval?
            if let retryHeader = headers["retry-after"] as? String,
               let seconds = TimeInterval(retryHeader) {
                retryAfter = seconds
            } else if let retryHeader = headers["Retry-After"] as? String,
                      let seconds = TimeInterval(retryHeader) {
                retryAfter = seconds
            } else {
                retryAfter = nil
            }
            return .rateLimited(retryAfter: retryAfter)
        case 500, 502, 503:
            return .serverError(statusCode: statusCode)
        case 529:
            return .overloaded
        default:
            return .serverError(statusCode: statusCode)
        }
    }
}
```

STEP 5: Create unit tests using URLProtocol for mocking

File: tests/ClaudeAPIClientTests.swift
```swift
// ClaudeAPIClientTests.swift
// EmberHearth
//
// Unit tests for ClaudeAPIClient using URLProtocol-based mocking.

import XCTest
@testable import EmberHearth

// MARK: - Mock URL Protocol

/// A URLProtocol subclass that intercepts HTTP requests and returns mock responses.
/// This avoids making real network calls in tests.
final class MockURLProtocol: URLProtocol {

    /// Handler closure that tests set to define mock behavior.
    /// Receives the request and returns (response, data) or throws an error.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true // Intercept all requests
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("MockURLProtocol.requestHandler is not set.")
            client?.urlProtocolDidFinishLoading(self)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // No-op
    }
}

// MARK: - Tests

final class ClaudeAPIClientTests: XCTestCase {

    private let testKeychainService = "com.emberhearth.api-keys.test-claude-client"
    private var keychainManager: KeychainManager!
    private var urlSession: URLSession!
    private var client: ClaudeAPIClient!

    /// A valid test API key for Claude.
    private let testAPIKey = "sk-ant-api03-test-key-for-claude-api-client-testing-1234567890"

    override func setUp() {
        super.setUp()

        // Set up test Keychain
        keychainManager = KeychainManager(serviceName: testKeychainService)
        try? keychainManager.deleteAll()

        // Set up mock URLSession
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        urlSession = URLSession(configuration: config)

        // Create the client with test dependencies
        client = ClaudeAPIClient(
            keychainManager: keychainManager,
            urlSession: urlSession,
            model: "claude-sonnet-4-20250514",
            maxTokens: 1024
        )
    }

    override func tearDown() {
        try? keychainManager.deleteAll()
        MockURLProtocol.requestHandler = nil
        keychainManager = nil
        urlSession = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Helper: Store Test API Key

    private func storeTestAPIKey() throws {
        try keychainManager.store(apiKey: testAPIKey, for: .claude)
    }

    // MARK: - Helper: Mock Success Response

    /// Returns mock JSON data matching the Claude Messages API response format.
    private func mockSuccessResponseData(
        content: String = "Hello! How can I help you?",
        model: String = "claude-sonnet-4-20250514",
        inputTokens: Int = 12,
        outputTokens: Int = 8,
        stopReason: String = "end_turn"
    ) -> Data {
        let json: [String: Any] = [
            "id": "msg_test123",
            "type": "message",
            "role": "assistant",
            "content": [
                ["type": "text", "text": content]
            ],
            "model": model,
            "stop_reason": stopReason,
            "usage": [
                "input_tokens": inputTokens,
                "output_tokens": outputTokens
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    /// Returns mock JSON data for an API error response.
    private func mockErrorResponseData(message: String = "Invalid API key", type: String = "authentication_error") -> Data {
        let json: [String: Any] = [
            "type": "error",
            "error": [
                "type": type,
                "message": message
            ]
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - isAvailable Tests

    func testIsAvailableReturnsFalseWithNoKey() {
        XCTAssertFalse(client.isAvailable)
    }

    func testIsAvailableReturnsTrueWithKey() throws {
        try storeTestAPIKey()
        XCTAssertTrue(client.isAvailable)
    }

    // MARK: - sendMessage Success Tests

    func testSendMessageSuccess() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            // Verify request properties
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "x-api-key"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockSuccessResponseData())
        }

        let messages = [LLMMessage.user("Hello!")]
        let response = try await client.sendMessage(messages, systemPrompt: "You are helpful.")

        XCTAssertEqual(response.content, "Hello! How can I help you?")
        XCTAssertEqual(response.usage.inputTokens, 12)
        XCTAssertEqual(response.usage.outputTokens, 8)
        XCTAssertEqual(response.usage.totalTokens, 20)
        XCTAssertEqual(response.model, "claude-sonnet-4-20250514")
        XCTAssertEqual(response.stopReason, .endTurn)
    }

    func testSendMessageRequestBodyFormat() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            // Parse and verify the request body
            let bodyData = request.httpBody!
            let body = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]

            XCTAssertEqual(body["model"] as? String, "claude-sonnet-4-20250514")
            XCTAssertEqual(body["max_tokens"] as? Int, 1024)
            XCTAssertEqual(body["stream"] as? Bool, false)
            XCTAssertEqual(body["system"] as? String, "Be helpful.")

            let messages = body["messages"] as! [[String: String]]
            XCTAssertEqual(messages.count, 2)
            XCTAssertEqual(messages[0]["role"], "user")
            XCTAssertEqual(messages[0]["content"], "Hello!")
            XCTAssertEqual(messages[1]["role"], "assistant")
            XCTAssertEqual(messages[1]["content"], "Hi there!")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockSuccessResponseData())
        }

        let messages: [LLMMessage] = [
            .user("Hello!"),
            .assistant("Hi there!")
        ]
        _ = try await client.sendMessage(messages, systemPrompt: "Be helpful.")
    }

    func testSendMessageSystemMessagesFiltered() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let bodyData = request.httpBody!
            let body = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]

            // System messages should be filtered from the messages array
            let messages = body["messages"] as! [[String: String]]
            XCTAssertEqual(messages.count, 1, "System messages should not appear in the messages array.")
            XCTAssertEqual(messages[0]["role"], "user")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockSuccessResponseData())
        }

        let messages: [LLMMessage] = [
            LLMMessage(role: .system, content: "This should be filtered."),
            .user("Hello!")
        ]
        _ = try await client.sendMessage(messages, systemPrompt: nil)
    }

    func testSendMessageWithNoSystemPrompt() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let bodyData = request.httpBody!
            let body = try! JSONSerialization.jsonObject(with: bodyData) as! [String: Any]

            // System field should not be present when no system prompt is given
            XCTAssertNil(body["system"], "System field should not be present when systemPrompt is nil.")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockSuccessResponseData())
        }

        let messages = [LLMMessage.user("Hello!")]
        _ = try await client.sendMessage(messages, systemPrompt: nil)
    }

    func testSendMessageMaxTokensStopReason() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockSuccessResponseData(stopReason: "max_tokens"))
        }

        let messages = [LLMMessage.user("Write a long essay.")]
        let response = try await client.sendMessage(messages, systemPrompt: nil)
        XCTAssertEqual(response.stopReason, .maxTokens)
    }

    // MARK: - sendMessage Error Tests

    func testSendMessageNoAPIKey() async {
        // Don't store any API key
        do {
            let messages = [LLMMessage.user("Hello!")]
            _ = try await client.sendMessage(messages, systemPrompt: nil)
            XCTFail("Should have thrown ClaudeAPIError.noAPIKey")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .noAPIKey)
        } catch {
            XCTFail("Expected ClaudeAPIError.noAPIKey, got \(error)")
        }
    }

    func testSendMessageUnauthorized() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockErrorResponseData())
        }

        do {
            _ = try await client.sendMessage([.user("Hi")], systemPrompt: nil)
            XCTFail("Should have thrown ClaudeAPIError.unauthorized")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func testSendMessageRateLimited() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: "HTTP/1.1",
                headerFields: ["Retry-After": "30"]
            )!
            return (response, self.mockErrorResponseData(message: "Rate limited", type: "rate_limit_error"))
        }

        do {
            _ = try await client.sendMessage([.user("Hi")], systemPrompt: nil)
            XCTFail("Should have thrown ClaudeAPIError.rateLimited")
        } catch let error as ClaudeAPIError {
            if case .rateLimited(let retryAfter) = error {
                XCTAssertEqual(retryAfter, 30.0)
            } else {
                XCTFail("Expected rateLimited error, got \(error)")
            }
        }
    }

    func testSendMessageRateLimitedWithoutRetryAfter() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockErrorResponseData(message: "Rate limited", type: "rate_limit_error"))
        }

        do {
            _ = try await client.sendMessage([.user("Hi")], systemPrompt: nil)
            XCTFail("Should have thrown ClaudeAPIError.rateLimited")
        } catch let error as ClaudeAPIError {
            if case .rateLimited(let retryAfter) = error {
                XCTAssertNil(retryAfter)
            } else {
                XCTFail("Expected rateLimited error, got \(error)")
            }
        }
    }

    func testSendMessageServerError() async throws {
        try storeTestAPIKey()

        for statusCode in [500, 502, 503] {
            MockURLProtocol.requestHandler = { request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: nil
                )!
                return (response, self.mockErrorResponseData(message: "Server error", type: "api_error"))
            }

            do {
                _ = try await client.sendMessage([.user("Hi")], systemPrompt: nil)
                XCTFail("Should have thrown ClaudeAPIError.serverError for status \(statusCode)")
            } catch let error as ClaudeAPIError {
                if case .serverError(let code) = error {
                    XCTAssertEqual(code, statusCode)
                } else {
                    XCTFail("Expected serverError, got \(error)")
                }
            }
        }
    }

    func testSendMessageOverloaded() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 529,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockErrorResponseData(message: "Overloaded", type: "overloaded_error"))
        }

        do {
            _ = try await client.sendMessage([.user("Hi")], systemPrompt: nil)
            XCTFail("Should have thrown ClaudeAPIError.overloaded")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .overloaded)
        }
    }

    func testSendMessageBadRequest() async throws {
        try storeTestAPIKey()

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 400,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            return (response, self.mockErrorResponseData(message: "Invalid model", type: "invalid_request_error"))
        }

        do {
            _ = try await client.sendMessage([.user("Hi")], systemPrompt: nil)
            XCTFail("Should have thrown ClaudeAPIError.badRequest")
        } catch let error as ClaudeAPIError {
            if case .badRequest(let message) = error {
                XCTAssertEqual(message, "Invalid model")
            } else {
                XCTFail("Expected badRequest error, got \(error)")
            }
        }
    }

    // MARK: - Streaming Stub Test

    func testStreamMessageThrowsNotImplemented() async throws {
        let stream = client.streamMessage([.user("Hi")], systemPrompt: nil)
        do {
            for try await _ in stream {
                XCTFail("Stream should not yield any chunks before task 0202 implements it.")
            }
        } catch {
            // Expected — streaming is not yet implemented
        }
    }

    // MARK: - LLMTypes Tests

    func testLLMMessageStaticFactories() {
        let userMsg = LLMMessage.user("Hello")
        XCTAssertEqual(userMsg.role, .user)
        XCTAssertEqual(userMsg.content, "Hello")

        let assistantMsg = LLMMessage.assistant("Hi there")
        XCTAssertEqual(assistantMsg.role, .assistant)
        XCTAssertEqual(assistantMsg.content, "Hi there")
    }

    func testLLMTokenUsageTotalTokens() {
        let usage = LLMTokenUsage(inputTokens: 100, outputTokens: 50)
        XCTAssertEqual(usage.totalTokens, 150)
    }

    func testLLMStopReasonRawValues() {
        XCTAssertEqual(LLMStopReason(rawValue: "end_turn"), .endTurn)
        XCTAssertEqual(LLMStopReason(rawValue: "max_tokens"), .maxTokens)
        XCTAssertEqual(LLMStopReason(rawValue: "stop_sequence"), .stopSequence)
        XCTAssertNil(LLMStopReason(rawValue: "something_else"))
    }
}
```

IMPORTANT NOTES:
- The `src/LLM/` directory already exists with a `LLMModule.swift` placeholder. Place all new files alongside it.
- The test file should go at `tests/ClaudeAPIClientTests.swift` (matching the flat pattern from task 0001's tests/EmberHearthTests.swift).
- The MockURLProtocol class is defined inside the test file, not as a separate file.
- ClaudeAPIClient is marked `@unchecked Sendable` because URLSession is not Sendable but is thread-safe in practice. This is the standard pattern for URLSession-based clients.
- The `streamMessage()` method is a stub that immediately throws. Task 0202 will replace this with the real implementation.
- NEVER log request bodies (which contain user messages) or response bodies (which contain assistant messages). Only log metadata: token counts, model name, status codes.
- After creating all files, run:
  1. `swift build` from project root
  2. `swift test --filter ClaudeAPIClientTests` to run these tests
  3. `swift test` to run all tests
```

---

## Acceptance Criteria

- [ ] `src/LLM/LLMTypes.swift` exists with `LLMMessage`, `LLMMessageRole`, `LLMTokenUsage`, `LLMStopReason`, `LLMResponse`, `LLMStreamChunk`
- [ ] `src/LLM/LLMProviderProtocol.swift` exists with `sendMessage()`, `streamMessage()`, `isAvailable`
- [ ] `src/LLM/ClaudeAPIError.swift` exists with all error cases: `noAPIKey`, `unauthorized`, `rateLimited`, `serverError`, `networkError`, `timeout`, `invalidResponse`, `overloaded`, `badRequest`
- [ ] `src/LLM/ClaudeAPIClient.swift` exists implementing `LLMProviderProtocol`
- [ ] API endpoint is `https://api.anthropic.com/v1/messages`
- [ ] Required headers: `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`
- [ ] Default model is `claude-sonnet-4-20250514`
- [ ] Default max_tokens is 1024
- [ ] Request timeout is 30 seconds
- [ ] API key is retrieved from KeychainManager (not hardcoded)
- [ ] System messages are filtered from the messages array and sent via the `system` field
- [ ] Non-200 HTTP status codes are mapped to appropriate `ClaudeAPIError` cases
- [ ] Retry-After header is parsed for 429 responses
- [ ] `streamMessage()` is a stub that throws (implementation in task 0202)
- [ ] Tests use MockURLProtocol (no real network calls)
- [ ] Tests use a separate Keychain service name
- [ ] API keys and message content are NEVER logged
- [ ] `swift build` succeeds
- [ ] `swift test` passes all tests

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/LLM/LLMTypes.swift && echo "LLMTypes.swift exists" || echo "MISSING: LLMTypes.swift"
test -f src/LLM/LLMProviderProtocol.swift && echo "LLMProviderProtocol.swift exists" || echo "MISSING: LLMProviderProtocol.swift"
test -f src/LLM/ClaudeAPIError.swift && echo "ClaudeAPIError.swift exists" || echo "MISSING: ClaudeAPIError.swift"
test -f src/LLM/ClaudeAPIClient.swift && echo "ClaudeAPIClient.swift exists" || echo "MISSING: ClaudeAPIClient.swift"
test -f tests/ClaudeAPIClientTests.swift && echo "Test file exists" || echo "MISSING: ClaudeAPIClientTests.swift"

# Verify no API keys or message content in logs (search for print with string interpolation)
grep -rn "print(" src/LLM/ | grep -v "logger\|//\|///\|print(response.content)" && echo "WARNING: Found print statements in LLM" || echo "OK: No suspicious prints in LLM"

# Verify the protocol name doesn't conflict with the enum
grep -rn "protocol LLMProvider[^P]" src/ && echo "WARNING: LLMProvider protocol name conflicts with enum" || echo "OK: No naming conflict"

# Build the project
swift build 2>&1

# Run Claude API client tests
swift test --filter ClaudeAPIClientTests 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the Claude API Client implementation created in task 0201 for EmberHearth. Check for these specific issues:

1. NAMING AND ARCHITECTURE:
   - The LLMProvider ENUM is in src/Security/LLMProvider.swift (from task 0200)
   - The LLMProvider PROTOCOL must be named LLMProviderProtocol (different name!) in src/LLM/LLMProviderProtocol.swift
   - Verify there is NO naming collision between the enum and protocol
   - Verify ClaudeAPIClient conforms to LLMProviderProtocol (not some other name)

2. API CORRECTNESS:
   - Verify the API endpoint is exactly "https://api.anthropic.com/v1/messages"
   - Verify the anthropic-version header is "2023-06-01"
   - Verify the content-type header is "application/json"
   - Verify the x-api-key header is set from KeychainManager.retrieve(for: .claude)
   - Verify the request body includes: model, max_tokens, stream, and messages array
   - Verify system prompt is sent as a top-level "system" field (NOT as a message with role "system")
   - Verify system messages in the messages array are filtered out before sending

3. RESPONSE PARSING:
   - Verify the content is extracted from the content array (content[].text), not a top-level text field
   - Verify usage is parsed from usage.input_tokens and usage.output_tokens
   - Verify stop_reason is parsed and mapped to LLMStopReason enum
   - Verify unknown stop reasons default to .unknown (not crash)

4. ERROR HANDLING:
   - Verify HTTP 401 maps to .unauthorized
   - Verify HTTP 429 maps to .rateLimited with optional retryAfter
   - Verify HTTP 500/502/503 maps to .serverError(statusCode:)
   - Verify HTTP 529 maps to .overloaded
   - Verify HTTP 400 maps to .badRequest
   - Verify URLError.timedOut maps to .timeout
   - Verify other network errors map to .networkError

5. SECURITY:
   - Verify API keys are NEVER logged or printed (search all files in src/LLM/)
   - Verify request bodies (containing user messages) are NEVER logged
   - Verify response bodies (containing assistant messages) are NEVER logged
   - Only metadata (token counts, status codes, model name) should be logged
   - Verify no force-unwraps (!) exist except in test files

6. STREAMING STUB:
   - Verify streamMessage() exists and returns an AsyncThrowingStream
   - Verify it immediately finishes with an error (not a crash or hang)

7. TEST QUALITY:
   - Verify MockURLProtocol intercepts all requests (no real network calls)
   - Verify tests use a separate Keychain service name
   - Verify there are tests for: success, no API key, 401, 429, 500, 529, 400
   - Verify tests verify request format (headers, body structure)
   - Verify tests clean up in tearDown

8. BUILD VERIFICATION:
   - Run `swift build` — verify no warnings or errors
   - Run `swift test` — verify all tests pass
   - Verify the LLMModule.swift placeholder doesn't conflict with new files

Report any issues found with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m3): add Claude API client with provider protocol
```

---

## Notes for Next Task

- `ClaudeAPIClient.streamMessage()` is a stub that throws. Task 0202 will implement real SSE streaming.
- The `buildRequest()` method already accepts a `stream: Bool` parameter. Task 0202 should set `stream: true` and use `URLSession.bytes(for:)` instead of `URLSession.data(for:)`.
- `ClaudeAPIClient` accepts a `URLSession` in its initializer for testing. Task 0202 should use the same pattern for streaming tests.
- The `LLMStreamChunk` type is already defined in `LLMTypes.swift`. Task 0202 should yield these from the streaming implementation.
- `ClaudeAPIError` already has all the error cases needed. Task 0202 should reuse them for streaming errors.
- The `MockURLProtocol` in the test file can be extended for streaming tests, or task 0202 may need a different approach for testing byte streams.
- Task 0203 (ContextBuilder) will consume `LLMMessage` from `LLMTypes.swift`.
- Task 0204 (RetryHandler) will wrap `ClaudeAPIClient.sendMessage()` with retry logic, using `ClaudeAPIError` to decide what to retry.
