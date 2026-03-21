// SSEParserTests.swift
// EmberHearthTests
//
// Tests for SSEParser — SSE parsing and Claude event extraction.

import XCTest
@testable import EmberHearth

final class SSEParserTests: XCTestCase {

    // MARK: - parseText Tests

    func testParseText_singleEvent() {
        let raw = """
        event: ping
        data: {}

        """
        let events = SSEParser.parseText(raw)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "ping")
        XCTAssertEqual(events[0].data, "{}")
    }

    func testParseText_multipleEvents() {
        let raw = """
        event: message_start
        data: {"type":"message_start"}

        event: content_block_delta
        data: {"delta":{"text":"Hello"}}

        event: message_stop
        data: {}

        """
        let events = SSEParser.parseText(raw)
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].eventType, "message_start")
        XCTAssertEqual(events[1].eventType, "content_block_delta")
        XCTAssertEqual(events[2].eventType, "message_stop")
    }

    func testParseText_emptyInput() {
        let events = SSEParser.parseText("")
        XCTAssertEqual(events.count, 0)
    }

    func testParseText_commentLinesIgnored() {
        let raw = """
        : this is a comment
        event: ping
        data: {}

        """
        let events = SSEParser.parseText(raw)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "ping")
    }

    func testParseText_multipleDataLinesAreConcatenated() {
        let raw = """
        event: content_block_delta
        data: {"part1":
        data: "value"}

        """
        let events = SSEParser.parseText(raw)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].data, "{\"part1\":\n\"value\"}")
    }

    func testParseText_incompleteEventWithoutEmptyLineAtEnd_isFlushed() {
        // No trailing empty line — the parser should still flush
        let raw = "event: message_stop\ndata: {}"
        let events = SSEParser.parseText(raw)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "message_stop")
    }

    func testParseText_onlyDataNoEventType_notEmitted() {
        // An event requires both event type and data
        let raw = """
        data: {"orphan":"data"}

        """
        let events = SSEParser.parseText(raw)
        XCTAssertEqual(events.count, 0)
    }

    func testSSEEvent_equatable() {
        let a = SSEParser.SSEEvent(eventType: "ping", data: "{}")
        let b = SSEParser.SSEEvent(eventType: "ping", data: "{}")
        let c = SSEParser.SSEEvent(eventType: "ping", data: "{\"x\":1}")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - extractChunk Tests

    func testExtractChunk_pingReturnsNil() {
        let event = SSEParser.SSEEvent(eventType: "ping", data: "{}")
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNil(chunk)
    }

    func testExtractChunk_unknownEventTypeReturnsNil() {
        let event = SSEParser.SSEEvent(eventType: "some_future_event", data: "{}")
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNil(chunk)
    }

    func testExtractChunk_invalidJSONReturnsNil() {
        let event = SSEParser.SSEEvent(eventType: "content_block_delta", data: "not-json")
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNil(chunk)
    }

    func testExtractChunk_messageStart() {
        let event = SSEParser.SSEEvent(
            eventType: "message_start",
            data: #"{"type":"message_start","message":{"id":"msg_123"}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.eventType, "message_start")
        XCTAssertNil(chunk?.usage)
        XCTAssertNil(chunk?.stopReason)
    }

    func testExtractChunk_contentBlockStart() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_start",
            data: #"{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.eventType, "content_block_start")
    }

    func testExtractChunk_contentBlockDelta_extractsDeltaText() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_delta",
            data: #"{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hello, world!"}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "Hello, world!")
        XCTAssertEqual(chunk?.eventType, "content_block_delta")
        XCTAssertNil(chunk?.usage)
        XCTAssertNil(chunk?.stopReason)
    }

    func testExtractChunk_contentBlockDelta_missingDeltaText_returnsEmptyString() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_delta",
            data: #"{"type":"content_block_delta","index":0,"delta":{"type":"input_json_delta"}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
    }

    func testExtractChunk_contentBlockStop() {
        let event = SSEParser.SSEEvent(
            eventType: "content_block_stop",
            data: #"{"type":"content_block_stop","index":0}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.eventType, "content_block_stop")
    }

    func testExtractChunk_messageDelta_endTurn() {
        let event = SSEParser.SSEEvent(
            eventType: "message_delta",
            data: #"{"type":"message_delta","delta":{"stop_reason":"end_turn","stop_sequence":null},"usage":{"output_tokens":42}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.eventType, "message_delta")
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertEqual(chunk?.stopReason, .endTurn)
        XCTAssertEqual(chunk?.usage?.outputTokens, 42)
        XCTAssertEqual(chunk?.usage?.inputTokens, 0)
    }

    func testExtractChunk_messageDelta_maxTokens() {
        let event = SSEParser.SSEEvent(
            eventType: "message_delta",
            data: #"{"type":"message_delta","delta":{"stop_reason":"max_tokens"},"usage":{"output_tokens":100}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertEqual(chunk?.stopReason, .maxTokens)
    }

    func testExtractChunk_messageDelta_unknownStopReason() {
        let event = SSEParser.SSEEvent(
            eventType: "message_delta",
            data: #"{"type":"message_delta","delta":{"stop_reason":"tool_use"},"usage":{"output_tokens":10}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertEqual(chunk?.stopReason, .unknown)
    }

    func testExtractChunk_messageDelta_noUsage() {
        let event = SSEParser.SSEEvent(
            eventType: "message_delta",
            data: #"{"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.stopReason, .endTurn)
        XCTAssertNil(chunk?.usage)
    }

    func testExtractChunk_messageStop() {
        let event = SSEParser.SSEEvent(
            eventType: "message_stop",
            data: #"{"type":"message_stop"}"#
        )
        let chunk = SSEParser.extractChunk(from: event)
        XCTAssertNotNil(chunk)
        XCTAssertEqual(chunk?.eventType, "message_stop")
        XCTAssertEqual(chunk?.deltaText, "")
        XCTAssertNil(chunk?.stopReason)
        XCTAssertNil(chunk?.usage)
    }

    // MARK: - Async parse(lines:) Tests

    func testParseLines_basicEvent() async throws {
        let lines = ["event: ping", "data: {}", ""]
        let stream = SSEParser.parse(lines: lines.async)

        var events: [SSEParser.SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "ping")
        XCTAssertEqual(events[0].data, "{}")
    }

    func testParseLines_multipleEvents() async throws {
        let lines = [
            "event: message_start",
            "data: {\"type\":\"message_start\"}",
            "",
            "event: content_block_delta",
            "data: {\"delta\":{\"text\":\"Hi\"}}",
            "",
            "event: message_stop",
            "data: {}",
            ""
        ]
        let stream = SSEParser.parse(lines: lines.async)

        var events: [SSEParser.SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events[0].eventType, "message_start")
        XCTAssertEqual(events[1].eventType, "content_block_delta")
        XCTAssertEqual(events[2].eventType, "message_stop")
    }

    func testParseLines_commentLinesIgnored() async throws {
        let lines = [": keepalive", "event: ping", "data: {}", ""]
        let stream = SSEParser.parse(lines: lines.async)

        var events: [SSEParser.SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "ping")
    }

    func testParseLines_flushesRemainingEventAtEnd() async throws {
        // No trailing empty line
        let lines = ["event: message_stop", "data: {}"]
        let stream = SSEParser.parse(lines: lines.async)

        var events: [SSEParser.SSEEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, "message_stop")
    }
}

// MARK: - Helpers

extension Array where Element == String {
    /// Wraps a string array as an AsyncSequence for use in tests.
    var async: AsyncArray<String> { AsyncArray(self) }
}

struct AsyncArray<T>: AsyncSequence {
    typealias Element = T
    let items: [T]

    init(_ items: [T]) { self.items = items }

    func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(items: items)
    }

    struct AsyncIterator: AsyncIteratorProtocol {
        var items: [T]
        var index = 0

        mutating func next() async -> T? {
            guard index < items.count else { return nil }
            defer { index += 1 }
            return items[index]
        }
    }
}