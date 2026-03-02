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