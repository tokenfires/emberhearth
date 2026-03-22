# Task 0202: Streaming Response Handling (SSE Parser)

**Milestone:** M3 - LLM Integration
**Unit:** 3.2 - Streaming Response Handling
**Phase:** 1
**Depends On:** 0201 (ClaudeAPIClient, LLMTypes)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; security rules, naming conventions
2. `src/LLM/ClaudeAPIClient.swift` — Read entirely; you will modify this file to replace the `streamMessage()` stub with a real implementation. Note the `buildRequest()` method already accepts a `stream: Bool` parameter.
3. `src/LLM/LLMTypes.swift` — Read entirely; contains `LLMStreamChunk`, `LLMTokenUsage`, `LLMStopReason` types that the streaming implementation must yield
4. `src/LLM/ClaudeAPIError.swift` — Read entirely; error types to use for streaming failures
5. `src/LLM/LLMProviderProtocol.swift` — Read entirely; the `streamMessage()` signature you must implement
6. `tests/ClaudeAPIClientTests.swift` — Read entirely; see the existing MockURLProtocol pattern and test structure

> **Context Budget Note:** All files are short (under 200 lines each). Read them entirely. The key understanding is: ClaudeAPIClient already has a `buildRequest()` method, and you need to replace the `streamMessage()` stub with a real SSE implementation.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing Server-Sent Events (SSE) streaming for the Claude API Client in EmberHearth, a native macOS personal AI assistant. Task 0201 created the ClaudeAPIClient with a stub `streamMessage()` method. You will now create an SSE parser and implement real streaming.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., SSEParser.swift)
- NEVER log or print API keys, request bodies, or response bodies
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- No third-party dependencies — use only Apple frameworks
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target

EXISTING CODE CONTEXT:
- src/LLM/ClaudeAPIClient.swift — Has a `buildRequest(messages:systemPrompt:apiKey:stream:)` method. Has a stub `streamMessage()` that throws "not implemented". You will REPLACE the stub.
- src/LLM/LLMTypes.swift — Defines `LLMStreamChunk` with: deltaText (String), eventType (String), usage (LLMTokenUsage?), stopReason (LLMStopReason?)
- src/LLM/ClaudeAPIError.swift — Error types including .networkError, .invalidResponse, .timeout, .noAPIKey
- tests/ClaudeAPIClientTests.swift — Has MockURLProtocol already defined. Has a `testStreamMessageThrowsNotImplemented()` test that needs to be replaced.

SSE FORMAT REFERENCE:
Server-Sent Events are plain text lines separated by newlines:
```
event: message_start
data: {"type": "message_start", "message": {"id": "msg_...", "model": "claude-sonnet-4-20250514", ...}}

event: content_block_start
data: {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}

event: ping
data: {}

event: content_block_delta
data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

event: content_block_delta
data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "!"}}

event: content_block_stop
data: {"type": "content_block_stop", "index": 0}

event: message_delta
data: {"type": "message_delta", "delta": {"stop_reason": "end_turn"}, "usage": {"output_tokens": 8}}

event: message_stop
data: {"type": "message_stop"}
```

Key rules:
- Lines starting with "event: " contain the event type
- Lines starting with "data: " contain JSON payload
- Empty lines separate events
- The "ping" event should be ignored
- Content text comes from content_block_delta events in delta.text
- Stop reason and final usage come from message_delta event
- message_stop signals end of stream

STEP 1: Create the SSE Parser

File: src/LLM/SSEParser.swift
```swift
// SSEParser.swift
// EmberHearth
//
// Parses Server-Sent Events (SSE) from the Claude streaming API.

import Foundation
import os

/// Parses raw SSE text lines into structured events.
///
/// SSE format:
/// ```
/// event: event_type
/// data: {"json": "payload"}
///
/// ```
///
/// Each event is separated by an empty line. The parser maintains state
/// across multiple lines to assemble complete events.
final class SSEParser: Sendable {

    /// A parsed SSE event with its type and JSON data.
    struct SSEEvent: Sendable, Equatable {
        /// The event type (e.g., "message_start", "content_block_delta", "ping").
        let eventType: String
        /// The raw JSON string from the "data:" line.
        let data: String
    }

    /// Logger for SSE parsing. NEVER logs data content (may contain user messages).
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "SSEParser"
    )

    // MARK: - Stateful Line-by-Line Parsing

    /// Parses a stream of raw text lines into SSE events.
    ///
    /// This method processes lines one at a time, maintaining state to assemble
    /// complete events (an event may span multiple lines: event + data + empty line).
    ///
    /// - Parameter lines: An async sequence of text lines from the HTTP response.
    /// - Returns: An async stream of parsed SSE events.
    static func parse<S: AsyncSequence>(lines: S) -> AsyncThrowingStream<SSEEvent, Error> where S.Element == String {
        return AsyncThrowingStream { continuation in
            let task = Task {
                var currentEventType: String? = nil
                var currentData: String? = nil

                do {
                    for try await line in lines {
                        // Empty line = end of current event
                        if line.isEmpty || line == "\n" || line == "\r\n" || line == "\r" {
                            if let eventType = currentEventType, let data = currentData {
                                let event = SSEEvent(eventType: eventType, data: data)
                                continuation.yield(event)
                            }
                            currentEventType = nil
                            currentData = nil
                            continue
                        }

                        // Parse line prefix
                        if line.hasPrefix("event: ") {
                            currentEventType = String(line.dropFirst("event: ".count))
                        } else if line.hasPrefix("data: ") {
                            let dataValue = String(line.dropFirst("data: ".count))
                            if currentData != nil {
                                // Multiple data lines for the same event — concatenate with newline
                                currentData! += "\n" + dataValue
                            } else {
                                currentData = dataValue
                            }
                        } else if line.hasPrefix(":") {
                            // Comment line — ignore (SSE spec)
                            continue
                        }
                        // Unknown lines are ignored per SSE spec
                    }

                    // Flush any remaining event
                    if let eventType = currentEventType, let data = currentData {
                        let event = SSEEvent(eventType: eventType, data: data)
                        continuation.yield(event)
                    }

                    continuation.finish()
                } catch {
                    Self.logger.error("SSE stream error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Single-Event Parsing (for testing)

    /// Parses a sequence of raw SSE text lines into events synchronously.
    /// Useful for unit testing with known input.
    ///
    /// - Parameter rawText: The complete SSE text (multiple events separated by empty lines).
    /// - Returns: An array of parsed SSE events.
    static func parseText(_ rawText: String) -> [SSEEvent] {
        var events: [SSEEvent] = []
        var currentEventType: String? = nil
        var currentData: String? = nil

        let lines = rawText.components(separatedBy: "\n")

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .init(charactersIn: "\r"))

            if trimmedLine.isEmpty {
                if let eventType = currentEventType, let data = currentData {
                    events.append(SSEEvent(eventType: eventType, data: data))
                }
                currentEventType = nil
                currentData = nil
                continue
            }

            if trimmedLine.hasPrefix("event: ") {
                currentEventType = String(trimmedLine.dropFirst("event: ".count))
            } else if trimmedLine.hasPrefix("data: ") {
                let dataValue = String(trimmedLine.dropFirst("data: ".count))
                if currentData != nil {
                    currentData! += "\n" + dataValue
                } else {
                    currentData = dataValue
                }
            }
            // Ignore comment lines and unknown lines
        }

        // Flush remaining
        if let eventType = currentEventType, let data = currentData {
            events.append(SSEEvent(eventType: eventType, data: data))
        }

        return events
    }

    // MARK: - Claude Event Extraction

    /// Extracts an LLMStreamChunk from a parsed SSE event.
    ///
    /// Maps Claude-specific event types to the generic LLMStreamChunk type.
    ///
    /// - Parameter event: A parsed SSE event.
    /// - Returns: An LLMStreamChunk if the event contains useful data, or `nil` for events like "ping".
    static func extractChunk(from event: SSEEvent) -> LLMStreamChunk? {
        // Skip ping events
        if event.eventType == "ping" {
            return nil
        }

        guard let jsonData = event.data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            Self.logger.warning("Failed to parse JSON for event: \(event.eventType)")
            return nil
        }

        switch event.eventType {
        case "message_start":
            // Contains message metadata — no text content
            return LLMStreamChunk(deltaText: "", eventType: event.eventType, usage: nil, stopReason: nil)

        case "content_block_start":
            // Content block started — no text yet
            return LLMStreamChunk(deltaText: "", eventType: event.eventType, usage: nil, stopReason: nil)

        case "content_block_delta":
            // This is where the actual streamed text lives
            var deltaText = ""
            if let delta = json["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                deltaText = text
            }
            return LLMStreamChunk(deltaText: deltaText, eventType: event.eventType, usage: nil, stopReason: nil)

        case "content_block_stop":
            // Content block ended
            return LLMStreamChunk(deltaText: "", eventType: event.eventType, usage: nil, stopReason: nil)

        case "message_delta":
            // Contains stop_reason and final usage
            var stopReason: LLMStopReason? = nil
            var usage: LLMTokenUsage? = nil

            if let delta = json["delta"] as? [String: Any],
               let reason = delta["stop_reason"] as? String {
                stopReason = LLMStopReason(rawValue: reason) ?? .unknown
            }

            if let usageDict = json["usage"] as? [String: Any],
               let outputTokens = usageDict["output_tokens"] as? Int {
                // message_delta usage only contains output_tokens
                // Input tokens were reported in message_start
                usage = LLMTokenUsage(inputTokens: 0, outputTokens: outputTokens)
            }

            return LLMStreamChunk(deltaText: "", eventType: event.eventType, usage: usage, stopReason: stopReason)

        case "message_stop":
            // End of message
            return LLMStreamChunk(deltaText: "", eventType: event.eventType, usage: nil, stopReason: nil)

        default:
            // Unknown event — log and skip
            Self.logger.info("Unknown SSE event type: \(event.eventType)")
            return nil
        }
    }
}
```

STEP 2: Replace the streamMessage() stub in ClaudeAPIClient

Open `src/LLM/ClaudeAPIClient.swift` and REPLACE the existing `streamMessage()` method with this implementation:

Find this code block:
```swift
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
```

Replace it with:
```swift
    /// Sends a streaming request to the Claude API using Server-Sent Events.
    ///
    /// Yields `LLMStreamChunk` objects as content arrives. The final chunk
    /// will contain usage statistics and the stop reason.
    ///
    /// - Parameters:
    ///   - messages: Conversation messages (user/assistant pairs). Do NOT include system messages.
    ///   - systemPrompt: Optional system prompt.
    /// - Returns: An async stream of response chunks.
    func streamMessage(_ messages: [LLMMessage], systemPrompt: String?) -> AsyncThrowingStream<LLMStreamChunk, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Retrieve the API key from Keychain
                    guard let apiKey = try keychainManager.retrieve(for: .claude) else {
                        Self.logger.error("No Claude API key found in Keychain for streaming.")
                        continuation.finish(throwing: ClaudeAPIError.noAPIKey)
                        return
                    }

                    // Build the request with stream: true
                    let request = try buildRequest(messages: messages, systemPrompt: systemPrompt, apiKey: apiKey, stream: true)

                    Self.logger.info("Starting streaming request to Claude API (model: \(self.model))")

                    // Use URLSession.bytes for streaming
                    let (bytes, response): (URLSession.AsyncBytes, URLResponse)
                    do {
                        (bytes, response) = try await urlSession.bytes(for: request)
                    } catch let error as URLError {
                        if error.code == .timedOut {
                            Self.logger.error("Claude API streaming request timed out.")
                            continuation.finish(throwing: ClaudeAPIError.timeout)
                            return
                        }
                        Self.logger.error("Network error during streaming: \(error.localizedDescription)")
                        continuation.finish(throwing: ClaudeAPIError.networkError(error.localizedDescription))
                        return
                    }

                    // Validate HTTP response
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ClaudeAPIError.invalidResponse("Response is not an HTTP response."))
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        // For error responses, collect the body data
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                            // Limit error body reading to 4KB to prevent memory issues
                            if errorData.count > 4096 { break }
                        }
                        let error = try mapHTTPError(statusCode: httpResponse.statusCode, data: errorData, headers: httpResponse.allHeaderFields)
                        continuation.finish(throwing: error)
                        return
                    }

                    // Parse the SSE stream line by line
                    let lines = bytes.lines
                    let events = SSEParser.parse(lines: lines)

                    for try await event in events {
                        // Check for cancellation
                        if Task.isCancelled {
                            Self.logger.info("Streaming request was cancelled.")
                            continuation.finish()
                            return
                        }

                        // Extract a chunk from the event
                        if let chunk = SSEParser.extractChunk(from: event) {
                            continuation.yield(chunk)

                            // Log final usage if present (metadata only, no content)
                            if let usage = chunk.usage {
                                Self.logger.info("Stream complete. Output tokens: \(usage.outputTokens)")
                            }
                        }
                    }

                    continuation.finish()
                    Self.logger.info("Streaming response completed successfully.")

                } catch {
                    Self.logger.error("Streaming error: \(error.localizedDescription)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
```

Make sure the `mapHTTPError` method is accessible (it should already be private within ClaudeAPIClient from task 0201).

STEP 3: Create unit tests for the SSE Parser

File: tests/SSEParserTests.swift
```swift
// SSEParserTests.swift
// EmberHearth
//
// Unit tests for SSEParser.

import XCTest
@testable import EmberHearth

final class SSEParserTests: XCTestCase {

    // MARK: - parseText Tests (Synchronous)

    func testParseBasicEvent() {
        let rawSSE = """
        event: message_start
        data: {"type": "message_start"}

        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "message_start")
        XCTAssertEqual(events[0].data, "{\"type\": \"message_start\"}")
    }

    func testParseMultipleEvents() {
        let rawSSE = """
        event: message_start
        data: {"type": "message_start"}

        event: content_block_delta
        data: {"type": "content_block_delta", "delta": {"text": "Hello"}}

        event: message_stop
        data: {"type": "message_stop"}

        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].eventType, "message_start")
        XCTAssertEqual(events[1].eventType, "content_block_delta")
        XCTAssertEqual(events[2].eventType, "message_stop")
    }

    func testParsePingEventIncluded() {
        let rawSSE = """
        event: ping
        data: {}

        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "ping")
    }

    func testParseEmptyInputReturnsNoEvents() {
        let events = SSEParser.parseText("")
        XCTAssertEqual(events.count, 0)
    }

    func testParseMultipleDataLines() {
        let rawSSE = """
        event: test_event
        data: {"part1": true}
        data: {"part2": true}

        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "test_event")
        // Multiple data lines should be joined with newline
        XCTAssertTrue(events[0].data.contains("{\"part1\": true}"))
        XCTAssertTrue(events[0].data.contains("{\"part2\": true}"))
    }

    func testParseEventWithoutTrailingNewline() {
        // SSE events at end of stream might not have a trailing empty line
        let rawSSE = """
        event: message_stop
        data: {"type": "message_stop"}
        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "message_stop")
    }

    func testParseIgnoresCommentLines() {
        let rawSSE = """
        : this is a comment
        event: test_event
        data: {"type": "test"}

        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "test_event")
    }

    // MARK: - extractChunk Tests

    func testExtractChunkFromPingReturnsNil() {
        let event = SSEParser.SSEEvent(eventType: "ping", data: "{}")
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNil(chunk, "Ping events should return nil (ignored).")
    }

    func testExtractChunkFromMessageStart() {
        let event = SSEParser.SSEEvent(
            eventType: "message_start",
            data: "{\"type\": \"message_start\", \"message\": {\"id\": \"msg_123\", \"model\": \"claude-sonnet-4-20250514\"}}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.eventType, "message_start")
        XCTAssertNil(chunk?.usage)
        XCTAssertNil(chunk?.stopReason)
    }

    func testExtractChunkFromContentBlockDelta() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_delta",
            data: "{\"type\": \"content_block_delta\", \"index\": 0, \"delta\": {\"type\": \"text_delta\", \"text\": \"Hello, world!\"}}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "Hello, world!")
        XCTAssertEqual(chunk?.eventType, "content_block_delta")
    }

    func testExtractChunkFromContentBlockDeltaEmptyText() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_delta",
            data: "{\"type\": \"content_block_delta\", \"index\": 0, \"delta\": {\"type\": \"text_delta\", \"text\": \"\"}}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
    }

    func testExtractChunkFromMessageDelta() {
        let event = SSEParser.SSEEvent(
            eventType: "message_delta",
            data: "{\"type\": \"message_delta\", \"delta\": {\"stop_reason\": \"end_turn\"}, \"usage\": {\"output_tokens\": 42}}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.stopReason, .endTurn)
        XCTAssertEqual(chunk?.usage?.outputTokens, 42)
    }

    func testExtractChunkFromMessageDeltaMaxTokens() {
        let event = SSEParser.SSEEvent(
            eventType: "message_delta",
            data: "{\"type\": \"message_delta\", \"delta\": {\"stop_reason\": \"max_tokens\"}, \"usage\": {\"output_tokens\": 1024}}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.stopReason, .maxTokens)
        XCTAssertEqual(chunk?.usage?.outputTokens, 1024)
    }

    func testExtractChunkFromMessageStop() {
        let event = SSEParser.SSEEvent(
            eventType: "message_stop",
            data: "{\"type\": \"message_stop\"}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.eventType, "message_stop")
    }

    func testExtractChunkFromContentBlockStart() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_start",
            data: "{\"type\": \"content_block_start\", \"index\": 0, \"content_block\": {\"type\": \"text\", \"text\": \"\"}}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.eventType, "content_block_start")
    }

    func testExtractChunkFromContentBlockStop() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_stop",
            data: "{\"type\": \"content_block_stop\", \"index\": 0}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.eventType, "content_block_stop")
    }

    func testExtractChunkFromUnknownEventReturnsNil() {
        let event = SSEParser.SSEEvent(
            eventType: "some_future_event",
            data: "{\"type\": \"some_future_event\"}"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNil(chunk, "Unknown events should return nil.")
    }

    func testExtractChunkFromMalformedJSONReturnsNil() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_delta",
            data: "this is not json"
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNil(chunk, "Malformed JSON should return nil, not crash.")
    }

    // MARK: - Full Stream Simulation

    func testFullStreamParsing() {
        let rawSSE = """
        event: message_start
        data: {"type": "message_start", "message": {"id": "msg_abc", "model": "claude-sonnet-4-20250514", "usage": {"input_tokens": 10}}}

        event: content_block_start
        data: {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}}

        event: ping
        data: {}

        event: content_block_delta
        data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "Hello"}}

        event: content_block_delta
        data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": ", "}}

        event: content_block_delta
        data: {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": "world!"}}

        event: content_block_stop
        data: {"type": "content_block_stop", "index": 0}

        event: message_delta
        data: {"type": "message_delta", "delta": {"stop_reason": "end_turn"}, "usage": {"output_tokens": 8}}

        event: message_stop
        data: {"type": "message_stop"}

        """

        let events = SSEParser.parseText(rawSSE)
        XCTAssertEqual(events.count, 9, "Should parse all 9 events including ping")

        // Extract chunks from all events
        let chunks = events.compactMap { SSEParser.extractChunk(from: $0) }

        // Ping should be filtered out
        XCTAssertEqual(chunks.count, 8, "Ping event should be filtered out by extractChunk")

        // Verify text content from content_block_delta chunks
        let textContent = chunks
            .filter { $0.eventType == "content_block_delta" }
            .map { $0.deltaText }
            .joined()
        XCTAssertEqual(textContent, "Hello, world!")

        // Verify the message_delta chunk has stop reason and usage
        let messageDeltaChunks = chunks.filter { $0.eventType == "message_delta" }
        XCTAssertEqual(messageDeltaChunks.count, 1)
        XCTAssertEqual(messageDeltaChunks[0].stopReason, .endTurn)
        XCTAssertEqual(messageDeltaChunks[0].usage?.outputTokens, 8)
    }

    // MARK: - Async Stream Tests

    func testParseAsyncStream() async throws {
        let lines = [
            "event: content_block_delta",
            "data: {\"type\": \"content_block_delta\", \"index\": 0, \"delta\": {\"type\": \"text_delta\", \"text\": \"Test\"}}",
            "",
            "event: message_stop",
            "data: {\"type\": \"message_stop\"}",
            ""
        ]

        // Create an async sequence from the lines array
        let asyncLines = AsyncStream<String> { continuation in
            for line in lines {
                continuation.yield(line)
            }
            continuation.finish()
        }

        let events = SSEParser.parse(lines: asyncLines)
        var parsedEvents: [SSEParser.SSEEvent] = []

        for try await event in events {
            parsedEvents.append(event)
        }

        XCTAssertEqual(parsedEvents.count, 2)
        XCTAssertEqual(parsedEvents[0].eventType, "content_block_delta")
        XCTAssertEqual(parsedEvents[1].eventType, "message_stop")
    }
}
```

STEP 4: Update the streaming test in ClaudeAPIClientTests

Open `tests/ClaudeAPIClientTests.swift` and REPLACE the existing `testStreamMessageThrowsNotImplemented` test with:

Find:
```swift
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
```

Replace with:
```swift
    // MARK: - Streaming Tests

    func testStreamMessageNoAPIKey() async {
        // Don't store any API key
        let stream = client.streamMessage([.user("Hi")], systemPrompt: nil)
        do {
            for try await _ in stream {
                XCTFail("Stream should not yield any chunks without an API key.")
            }
            XCTFail("Stream should have thrown an error.")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .noAPIKey)
        } catch {
            XCTFail("Expected ClaudeAPIError.noAPIKey, got \(error)")
        }
    }
```

IMPORTANT NOTES:
- Only ONE new file is created: `src/LLM/SSEParser.swift`
- `src/LLM/ClaudeAPIClient.swift` is MODIFIED (replace the streamMessage stub)
- A new test file is created: `tests/SSEParserTests.swift`
- The existing test in `tests/ClaudeAPIClientTests.swift` is MODIFIED (replace the stub test)
- The SSEParser is a utility class with all static methods — no instance state needed
- `SSEParser.parseText()` is a synchronous convenience for unit testing
- `SSEParser.parse(lines:)` is the async version for real streaming
- NEVER log the actual text content from streaming (it contains user/assistant messages)
- The `ping` event is properly handled: parseText includes it, extractChunk returns nil for it
- After creating/modifying all files, run:
  1. `swift build` from project root
  2. `swift test --filter SSEParserTests` to run SSE parser tests
  3. `swift test --filter ClaudeAPIClientTests` to run updated client tests
  4. `swift test` to run all tests
```

---

## Acceptance Criteria

- [ ] `src/LLM/SSEParser.swift` exists with `parseText()`, `parse(lines:)`, and `extractChunk(from:)` methods
- [ ] `SSEParser.SSEEvent` struct has `eventType` and `data` fields
- [ ] All Claude streaming event types handled: `message_start`, `content_block_start`, `content_block_delta`, `content_block_stop`, `message_delta`, `message_stop`
- [ ] `ping` events are parsed but `extractChunk` returns `nil` for them
- [ ] Comment lines (starting with `:`) are ignored
- [ ] Malformed JSON returns `nil` (does not crash)
- [ ] `content_block_delta` extracts text from `delta.text`
- [ ] `message_delta` extracts `stop_reason` and `usage.output_tokens`
- [ ] `ClaudeAPIClient.streamMessage()` now uses `URLSession.bytes(for:)` and SSEParser
- [ ] Stream properly handles: no API key, HTTP errors, cancellation
- [ ] The old `testStreamMessageThrowsNotImplemented` test is replaced
- [ ] `tests/SSEParserTests.swift` covers all event types and edge cases
- [ ] Message content is NEVER logged
- [ ] `swift build` succeeds
- [ ] `swift test` passes all tests

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new file exists
test -f src/LLM/SSEParser.swift && echo "SSEParser.swift exists" || echo "MISSING: SSEParser.swift"
test -f tests/SSEParserTests.swift && echo "SSEParserTests.swift exists" || echo "MISSING: SSEParserTests.swift"

# Verify the streaming stub has been replaced
grep -n "Streaming not yet implemented" src/LLM/ClaudeAPIClient.swift && echo "WARNING: Stub still present" || echo "OK: Stub replaced"

# Verify the old test has been replaced
grep -n "testStreamMessageThrowsNotImplemented" tests/ClaudeAPIClientTests.swift && echo "WARNING: Old test still present" || echo "OK: Old test replaced"

# Verify no message content is logged
grep -rn "deltaText\|\.content\|\.text" src/LLM/SSEParser.swift | grep -i "log\|print" && echo "WARNING: Possible content logging" || echo "OK: No content logging"

# Build the project
swift build 2>&1

# Run SSE parser tests
swift test --filter SSEParserTests 2>&1

# Run Claude API client tests
swift test --filter ClaudeAPIClientTests 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the SSE streaming implementation created in task 0202 for EmberHearth. Check for these specific issues:

1. SSE PARSER CORRECTNESS:
   - Open src/LLM/SSEParser.swift
   - Verify the parser handles "event: " prefix correctly (exact string matching, including the space)
   - Verify the parser handles "data: " prefix correctly
   - Verify empty lines properly terminate events
   - Verify comment lines (starting with ":") are ignored
   - Verify multiple "data:" lines for the same event are concatenated with newline
   - Verify events without a trailing empty line at end-of-stream are still emitted
   - Verify carriage returns (\r) are handled (some servers send \r\n)

2. CLAUDE EVENT TYPE HANDLING:
   - Verify content_block_delta extracts text from json["delta"]["text"]
   - Verify message_delta extracts stop_reason from json["delta"]["stop_reason"]
   - Verify message_delta extracts usage.output_tokens from json["usage"]["output_tokens"]
   - Verify ping events are filtered out by extractChunk (returns nil)
   - Verify unknown event types return nil from extractChunk (not crash)
   - Verify malformed JSON in data field returns nil (not crash)

3. STREAMING INTEGRATION:
   - Open src/LLM/ClaudeAPIClient.swift
   - Verify streamMessage() retrieves the API key from KeychainManager
   - Verify it calls buildRequest() with stream: true
   - Verify it uses urlSession.bytes(for:) (not urlSession.data(for:))
   - Verify it uses bytes.lines to get line-by-line streaming
   - Verify it feeds lines into SSEParser.parse(lines:)
   - Verify HTTP error responses are handled (non-200 status codes)
   - Verify error body reading is capped (to prevent memory issues on large error responses)
   - Verify Task.isCancelled is checked during streaming
   - Verify continuation.onTermination cancels the task

4. SECURITY:
   - Verify message content (deltaText) is NEVER logged in SSEParser
   - Verify only event type names and metadata (token counts) are logged
   - Verify API keys are not logged
   - Verify no force-unwraps (!) except in test files

5. TEST QUALITY:
   - Verify tests/SSEParserTests.swift covers:
     - Basic single event parsing
     - Multiple events in sequence
     - Ping event handling
     - Empty input
     - Multiple data lines per event
     - Events without trailing newline
     - Comment line filtering
     - Each extractChunk event type (message_start, content_block_start, content_block_delta, content_block_stop, message_delta, message_stop)
     - Unknown event types
     - Malformed JSON
     - Full stream simulation with text accumulation
     - Async stream parsing
   - Verify the old "testStreamMessageThrowsNotImplemented" test has been replaced
   - Verify the new streaming test in ClaudeAPIClientTests tests the no-API-key case

6. BUILD VERIFICATION:
   - Run `swift build` — verify no warnings or errors
   - Run `swift test` — verify all tests pass (including the old tests from task 0200 and 0201)

Report any issues found with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m3): add SSE streaming support for Claude API
```

---

## Notes for Next Task

- The SSEParser is a standalone utility. Task 0203 (ContextBuilder) does not depend on streaming.
- Task 0204 (RetryHandler) should handle streaming errors the same way as non-streaming errors. The circuit breaker should track failures from both paths.
- The `LLMStreamChunk.usage` field in `message_delta` events only contains `output_tokens`. Input tokens are reported in the `message_start` event. For full usage tracking, the caller should accumulate both.
- For future reference, the streaming implementation yields ALL event types as chunks (except ping). The consumer (e.g., the message coordinator in M2) should filter for `content_block_delta` chunks to get the text, and `message_delta` for the final usage/stop reason.
- `URLSession.bytes(for:)` is available on macOS 12+, so it works with our macOS 13.0+ deployment target.
