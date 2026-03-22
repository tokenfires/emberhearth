// SessionManagerTests.swift
// EmberHearth
//
// Unit tests for Session, SessionMessage, and SessionManager.

import XCTest
@testable import EmberHearthCore

final class SessionManagerTests: XCTestCase {

    // MARK: - Helpers

    private let testPhoneNumber = "+15551234567"
    private let altPhoneNumber = "+15559876543"

    /// Creates a fresh in-memory database and SessionManager.
    private func makeManager() throws -> (DatabaseManager, SessionManager) {
        let db = try DatabaseManager(path: ":memory:")
        let manager = SessionManager(database: db)
        return (db, manager)
    }

    // MARK: - Session Creation Tests

    func testGetOrCreateSessionCreatesNew() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)

        XCTAssertGreaterThan(session.id, 0, "Session should have a database ID")
        XCTAssertEqual(session.phoneNumber, testPhoneNumber)
        XCTAssertTrue(session.isActive)
        XCTAssertEqual(session.messageCount, 0)
        XCTAssertNil(session.endedAt)
        XCTAssertNil(session.summary)
    }

    func testGetOrCreateSessionReturnsExisting() throws {
        let (_, manager) = try makeManager()

        let session1 = try manager.getOrCreateSession(for: testPhoneNumber)
        let session2 = try manager.getOrCreateSession(for: testPhoneNumber)

        XCTAssertEqual(session1.id, session2.id, "Should return the same active session")
    }

    func testGetOrCreateSessionDifferentPhoneNumbers() throws {
        let (_, manager) = try makeManager()

        let session1 = try manager.getOrCreateSession(for: testPhoneNumber)
        let session2 = try manager.getOrCreateSession(for: altPhoneNumber)

        XCTAssertNotEqual(session1.id, session2.id, "Different phone numbers should have different sessions")
    }

    // MARK: - Active Session Tests

    func testGetActiveSessionReturnsNilWhenNone() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getActiveSession(for: testPhoneNumber)
        XCTAssertNil(session, "Should return nil when no active session exists")
    }

    func testGetActiveSessionReturnsActive() throws {
        let (_, manager) = try makeManager()

        let created = try manager.getOrCreateSession(for: testPhoneNumber)
        let retrieved = try manager.getActiveSession(for: testPhoneNumber)

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, created.id)
    }

    func testGetActiveSessionExcludesEnded() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session)

        let retrieved = try manager.getActiveSession(for: testPhoneNumber)
        XCTAssertNil(retrieved, "Should not return ended sessions")
    }

    // MARK: - End Session Tests

    func testEndSessionSetsInactive() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session)

        let active = try manager.getActiveSession(for: testPhoneNumber)
        XCTAssertNil(active, "Ended session should not be active")
    }

    func testEndSessionSetsEndedAt() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session)

        let history = try manager.getSessionHistory(for: testPhoneNumber)
        XCTAssertEqual(history.count, 1)
        XCTAssertNotNil(history[0].endedAt, "Ended session should have ended_at set")
        XCTAssertFalse(history[0].isActive)
    }

    func testEndAndCreateNewSession() throws {
        let (_, manager) = try makeManager()

        let session1 = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session1)

        let session2 = try manager.getOrCreateSession(for: testPhoneNumber)
        XCTAssertNotEqual(session1.id, session2.id, "Should create a new session after ending the old one")
        XCTAssertTrue(session2.isActive)
    }

    // MARK: - Message Tests

    func testAddMessage() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        let messageId = try manager.addMessage(
            to: session,
            role: MessageRole.user,
            content: "Hello Ember!"
        )

        XCTAssertGreaterThan(messageId, 0)
    }

    func testAddMessageIncrementsCount() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)

        try manager.addMessage(to: session, role: MessageRole.user, content: "Message 1")
        try manager.addMessage(to: session, role: MessageRole.assistant, content: "Response 1")
        try manager.addMessage(to: session, role: MessageRole.user, content: "Message 2")

        let count = try manager.messageCount(for: session)
        XCTAssertEqual(count, 3)
    }

    func testAddMessageWithTokenCount() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.addMessage(
            to: session,
            role: MessageRole.user,
            content: "Hello Ember!",
            tokenCount: 42
        )

        let messages = try manager.getRecentMessages(for: session)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].tokenCount, 42)
    }

    func testAddMessageWithNilTokenCount() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.addMessage(to: session, role: MessageRole.user, content: "Hello!")

        let messages = try manager.getRecentMessages(for: session)
        XCTAssertNil(messages[0].tokenCount)
    }

    // MARK: - Get Recent Messages Tests

    func testGetRecentMessagesChronologicalOrder() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)

        try manager.addMessage(to: session, role: MessageRole.user, content: "First")
        try manager.addMessage(to: session, role: MessageRole.assistant, content: "Second")
        try manager.addMessage(to: session, role: MessageRole.user, content: "Third")

        let messages = try manager.getRecentMessages(for: session)
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages[0].content, "First", "Messages should be in chronological order")
        XCTAssertEqual(messages[1].content, "Second")
        XCTAssertEqual(messages[2].content, "Third")
    }

    func testGetRecentMessagesRespectsLimit() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)

        for i in 1...10 {
            try manager.addMessage(to: session, role: MessageRole.user, content: "Message \(i)")
        }

        let messages = try manager.getRecentMessages(for: session, limit: 5)
        XCTAssertEqual(messages.count, 5, "Should return only 5 messages")
        XCTAssertEqual(messages[0].content, "Message 6", "Should start from the 6th message")
        XCTAssertEqual(messages[4].content, "Message 10", "Should end with the 10th message")
    }

    func testGetRecentMessagesEmptySession() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        let messages = try manager.getRecentMessages(for: session)
        XCTAssertTrue(messages.isEmpty)
    }

    func testGetRecentMessagesPreservesRoles() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.addMessage(to: session, role: MessageRole.user, content: "Hello")
        try manager.addMessage(to: session, role: MessageRole.assistant, content: "Hi there!")

        let messages = try manager.getRecentMessages(for: session)
        XCTAssertEqual(messages[0].role, MessageRole.user)
        XCTAssertEqual(messages[1].role, MessageRole.assistant)
    }

    // MARK: - Staleness Detection Tests

    func testNewSessionIsNotStale() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        XCTAssertFalse(try manager.isSessionStale(session), "New session should not be stale")
    }

    func testEndedSessionIsNotStale() throws {
        let (_, manager) = try makeManager()

        var session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session)

        session.isActive = false
        XCTAssertFalse(try manager.isSessionStale(session), "Ended session should not be considered stale")
    }

    func testStaleSessionDetection() throws {
        let (db, manager) = try makeManager()

        let sixHoursAgo = Date().addingTimeInterval(-6 * 60 * 60)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let pastTimestamp = dateFormatter.string(from: sixHoursAgo)

        let sessionId = try db.insertAndReturnId(
            sql: "INSERT INTO sessions (phone_number, started_at, is_active) VALUES (?, ?, 1)",
            parameters: [testPhoneNumber, pastTimestamp]
        )

        try db.execute(
            sql: "INSERT INTO messages (session_id, role, content, timestamp) VALUES (?, ?, ?, ?)",
            parameters: [sessionId, "user", "Old message", pastTimestamp]
        )

        let session = try manager.getActiveSession(for: testPhoneNumber)
        XCTAssertNotNil(session)
        XCTAssertTrue(
            try manager.isSessionStale(session!),
            "Session with 6-hour-old last message should be stale (default timeout is 4 hours)"
        )
    }

    func testStaleSessionAutoEndsOnGetOrCreate() throws {
        let (db, manager) = try makeManager()

        let sixHoursAgo = Date().addingTimeInterval(-6 * 60 * 60)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let pastTimestamp = dateFormatter.string(from: sixHoursAgo)

        let oldSessionId = try db.insertAndReturnId(
            sql: "INSERT INTO sessions (phone_number, started_at, is_active) VALUES (?, ?, 1)",
            parameters: [testPhoneNumber, pastTimestamp]
        )

        let newSession = try manager.getOrCreateSession(for: testPhoneNumber)

        XCTAssertNotEqual(newSession.id, oldSessionId, "Should create a new session")
        XCTAssertTrue(newSession.isActive)

        let history = try manager.getSessionHistory(for: testPhoneNumber)
        let oldSession = history.first { $0.id == oldSessionId }
        XCTAssertNotNil(oldSession)
        XCTAssertFalse(oldSession!.isActive, "Old stale session should be ended")
        XCTAssertNotNil(oldSession!.endedAt, "Old stale session should have ended_at set")
    }

    // MARK: - Session History Tests

    func testGetSessionHistory() throws {
        let (_, manager) = try makeManager()

        let session1 = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session1)

        let session2 = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session2)

        let session3 = try manager.getOrCreateSession(for: testPhoneNumber)

        let history = try manager.getSessionHistory(for: testPhoneNumber)
        XCTAssertEqual(history.count, 3)
        XCTAssertEqual(history[0].id, session3.id)
    }

    func testGetSessionHistoryRespectsLimit() throws {
        let (_, manager) = try makeManager()

        for _ in 0..<5 {
            let session = try manager.getOrCreateSession(for: testPhoneNumber)
            try manager.endSession(session)
        }

        let history = try manager.getSessionHistory(for: testPhoneNumber, limit: 3)
        XCTAssertEqual(history.count, 3)
    }

    func testGetSessionHistoryFiltersByPhoneNumber() throws {
        let (_, manager) = try makeManager()

        let _ = try manager.getOrCreateSession(for: testPhoneNumber)
        let _ = try manager.getOrCreateSession(for: altPhoneNumber)

        let history1 = try manager.getSessionHistory(for: testPhoneNumber)
        XCTAssertEqual(history1.count, 1)
        XCTAssertEqual(history1[0].phoneNumber, testPhoneNumber)

        let history2 = try manager.getSessionHistory(for: altPhoneNumber)
        XCTAssertEqual(history2.count, 1)
        XCTAssertEqual(history2[0].phoneNumber, altPhoneNumber)
    }

    // MARK: - Last Message Timestamp Tests

    func testLastMessageTimestamp() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)

        let noTimestamp = try manager.lastMessageTimestamp(for: session)
        XCTAssertNil(noTimestamp)

        try manager.addMessage(to: session, role: MessageRole.user, content: "Hello")
        let timestamp = try manager.lastMessageTimestamp(for: session)
        XCTAssertNotNil(timestamp)
    }

    // MARK: - Message Count Tests

    func testMessageCount() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        XCTAssertEqual(try manager.messageCount(for: session), 0)

        try manager.addMessage(to: session, role: MessageRole.user, content: "Hello")
        XCTAssertEqual(try manager.messageCount(for: session), 1)

        try manager.addMessage(to: session, role: MessageRole.assistant, content: "Hi!")
        XCTAssertEqual(try manager.messageCount(for: session), 2)
    }

    // MARK: - Edge Cases

    func testSpecialCharactersInPhoneNumber() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: "+1 (555) 123-4567")
        XCTAssertEqual(session.phoneNumber, "+1 (555) 123-4567")
    }

    func testLongMessageContent() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        let longContent = String(repeating: "A", count: 50_000)
        try manager.addMessage(to: session, role: MessageRole.user, content: longContent)

        let messages = try manager.getRecentMessages(for: session)
        XCTAssertEqual(messages[0].content.count, 50_000)
    }

    func testEmptyMessageContent() throws {
        let (_, manager) = try makeManager()

        let session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.addMessage(to: session, role: MessageRole.user, content: "")

        let messages = try manager.getRecentMessages(for: session)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0].content, "")
    }

    // MARK: - Configurable Stale Timeout Tests

    func testDefaultStaleTimeout() {
        let expectedFourHours: TimeInterval = 4 * 60 * 60
        XCTAssertEqual(
            SessionManager.defaultStaleTimeoutSeconds,
            expectedFourHours,
            "Default stale timeout should be 4 hours"
        )
    }

    func testStaleTimeoutUsesUserDefaults() throws {
        let (_, manager) = try makeManager()

        UserDefaults.standard.set(3600.0, forKey: SessionManager.staleTimeoutDefaultsKey)

        XCTAssertEqual(manager.staleTimeoutSeconds, 3600.0)

        UserDefaults.standard.removeObject(forKey: SessionManager.staleTimeoutDefaultsKey)
    }
}
