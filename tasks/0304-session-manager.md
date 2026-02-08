# Task 0304: Session State Management

**Milestone:** M4 - Memory System
**Unit:** 4.5 - Session State Management
**Phase:** 2
**Depends On:** 0300 (DatabaseManager), 0301 (FactStore)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions (PascalCase for Swift), security boundaries, core principles
2. `src/Database/DatabaseManager.swift` — Read entirely; understand execute(), insertAndReturnId(), query(), queryScalar() methods and their parameter/return types
3. `src/Database/DatabaseError.swift` — Read entirely; understand available error types
4. `src/Memory/Fact.swift` — Skim for reference; understand the date formatting pattern used in FactStore
5. `src/Memory/FactStore.swift` — Focus on the `dateFormatter` static property (lines ~30-37) — you will reuse the same date format for consistency

> **Context Budget Note:** DatabaseManager.swift is the most important context file — read it in full. FactStore.swift: focus only on the dateFormatter definition and the rowToFact pattern for how database rows are mapped to models. Skip all CRUD method implementations.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the SessionManager for EmberHearth, a native macOS personal AI assistant. The SessionManager tracks conversation sessions — which conversations are active, their message history, and when sessions start and end.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., SessionManager.swift)
- Security first: never store API keys or credentials in the database
- NEVER implement shell execution
- All source files go under src/, all test files go under tests/

WHAT EXISTS (from Tasks 0300-0301):
- src/Database/DatabaseManager.swift — SQLite database manager with these methods:
  - func execute(sql: String, parameters: [Any?]) throws
  - func insertAndReturnId(sql: String, parameters: [Any?]) throws -> Int64
  - func query(sql: String, parameters: [Any?]) throws -> [[String: Any?]]
  - func queryScalar(sql: String, parameters: [Any?]) throws -> Any?
  - func transaction(_ block: () throws -> Void) throws
  - Integer columns return as Int64, Real/Float as Double, Text as String, NULL as nil
- src/Database/DatabaseError.swift — Error types
- The sessions table exists with these exact columns:
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - phone_number TEXT NOT NULL
  - started_at TEXT NOT NULL DEFAULT (datetime('now'))
  - ended_at TEXT
  - summary TEXT
  - message_count INTEGER NOT NULL DEFAULT 0
  - is_active INTEGER NOT NULL DEFAULT 1
- The messages table exists with these exact columns:
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - session_id INTEGER NOT NULL (FOREIGN KEY to sessions.id)
  - role TEXT NOT NULL ('user' or 'assistant')
  - content TEXT NOT NULL
  - timestamp TEXT NOT NULL DEFAULT (datetime('now'))
  - token_count INTEGER

DATE FORMAT: The project uses "yyyy-MM-dd HH:mm:ss" format with UTC timezone and "en_US_POSIX" locale for all SQLite date storage. This matches FactStore's dateFormatter. You must use the SAME format for consistency.

YOU WILL CREATE:
1. src/Core/Session.swift — Session and SessionMessage models
2. src/Core/SessionManager.swift — Session lifecycle management
3. tests/SessionManagerTests.swift — Comprehensive unit tests

STEP 1: Create src/Core/Session.swift

File: src/Core/Session.swift
```swift
// Session.swift
// EmberHearth
//
// Data models for conversation sessions and messages.

import Foundation

/// Represents a conversation session with a user.
///
/// A session starts when a user sends a message and no active session exists.
/// Sessions become "stale" after a configurable inactivity period (default: 4 hours).
/// Stale sessions are automatically ended and a new session is started.
struct Session: Identifiable, Equatable {

    /// Unique database identifier.
    let id: Int64

    /// The phone number of the user (E.164 format, e.g., "+15551234567").
    let phoneNumber: String

    /// When this session started.
    let startedAt: Date

    /// When this session ended. nil if the session is still active.
    var endedAt: Date?

    /// A brief summary of the conversation. Generated when the session ends.
    /// nil for active sessions (summary generation is added in M5).
    var summary: String?

    /// Number of messages in this session (user + assistant combined).
    var messageCount: Int

    /// Whether this session is currently active.
    var isActive: Bool
}

/// Represents a single message within a conversation session.
struct SessionMessage: Identifiable, Equatable {

    /// Unique database identifier.
    let id: Int64

    /// The session this message belongs to.
    let sessionId: Int64

    /// The role of the message sender: "user" or "assistant".
    let role: String

    /// The text content of the message.
    let content: String

    /// When this message was sent/received.
    let timestamp: Date

    /// Estimated token count for this message (used for context window management).
    /// nil if not yet calculated.
    var tokenCount: Int?
}

/// Role constants for session messages.
/// These match the values stored in the database `role` column.
enum MessageRole {
    static let user = "user"
    static let assistant = "assistant"
}
```

STEP 2: Create src/Core/SessionManager.swift

File: src/Core/SessionManager.swift
```swift
// SessionManager.swift
// EmberHearth
//
// Manages conversation sessions — tracking which conversations are active,
// their message history, and when sessions start and end.
// All database operations go through DatabaseManager for thread safety.

import Foundation
import os

/// Manages the lifecycle of conversation sessions.
///
/// Usage:
/// ```swift
/// let manager = SessionManager(database: db)
/// let session = try manager.getOrCreateSession(for: "+15551234567")
/// try manager.addMessage(to: session, role: MessageRole.user, content: "Hello!")
/// let history = try manager.getRecentMessages(for: session, limit: 20)
/// ```
final class SessionManager {

    // MARK: - Properties

    /// The database manager used for all operations.
    private let database: DatabaseManager

    /// Logger for session events. NEVER logs message content.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "SessionManager"
    )

    // MARK: - Configuration

    /// Default session stale timeout in seconds (4 hours).
    /// A session is considered "stale" if no message has been added for this duration.
    /// When a stale session is detected, it is ended and a new session is started.
    static let defaultStaleTimeoutSeconds: TimeInterval = 4 * 60 * 60  // 4 hours

    /// UserDefaults key for the configurable stale timeout.
    static let staleTimeoutDefaultsKey = "com.emberhearth.session.staleTimeoutSeconds"

    /// The stale timeout to use. Reads from UserDefaults, falls back to default.
    var staleTimeoutSeconds: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: SessionManager.staleTimeoutDefaultsKey)
        return stored > 0 ? stored : SessionManager.defaultStaleTimeoutSeconds
    }

    // MARK: - Date Formatting

    /// ISO 8601 date formatter matching SQLite's datetime('now') format.
    /// MUST match the format used in FactStore for consistency.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Initialization

    /// Creates a SessionManager backed by the given database manager.
    ///
    /// - Parameter database: The DatabaseManager to use for all operations.
    init(database: DatabaseManager) {
        self.database = database
    }

    // MARK: - Session Lifecycle

    /// Gets the active session for a phone number, or creates a new one.
    ///
    /// If an active session exists but is stale (no activity for staleTimeoutSeconds),
    /// it is automatically ended and a new session is started.
    ///
    /// - Parameter phoneNumber: The user's phone number (E.164 format).
    /// - Returns: An active session for the given phone number.
    /// - Throws: `DatabaseError` if a database operation fails.
    func getOrCreateSession(for phoneNumber: String) throws -> Session {
        // Check for an existing active session
        if let activeSession = try getActiveSession(for: phoneNumber) {
            // Check if the session is stale
            if isSessionStale(activeSession) {
                Self.logger.info("Session \(activeSession.id) is stale, ending and creating new")
                try endSession(activeSession)
                return try createNewSession(for: phoneNumber)
            }
            return activeSession
        }

        // No active session — create a new one
        return try createNewSession(for: phoneNumber)
    }

    /// Gets the currently active session for a phone number, if one exists.
    ///
    /// - Parameter phoneNumber: The user's phone number.
    /// - Returns: The active session, or nil if no active session exists.
    /// - Throws: `DatabaseError` if the query fails.
    func getActiveSession(for phoneNumber: String) throws -> Session? {
        let sql = """
            SELECT * FROM sessions
            WHERE phone_number = ? AND is_active = 1
            ORDER BY started_at DESC
            LIMIT 1
            """
        let rows = try database.query(sql: sql, parameters: [phoneNumber])
        return rows.first.flatMap { rowToSession($0) }
    }

    /// Ends an active session.
    ///
    /// Sets ended_at to the current time and is_active to 0.
    /// Does NOT generate a summary (that requires LLM and will be added in M5).
    ///
    /// - Parameter session: The session to end.
    /// - Throws: `DatabaseError` if the update fails.
    func endSession(_ session: Session) throws {
        let now = SessionManager.dateFormatter.string(from: Date())
        let sql = "UPDATE sessions SET is_active = 0, ended_at = ? WHERE id = ?"
        try database.execute(sql: sql, parameters: [now, session.id])
        Self.logger.info("Ended session \(session.id)")
    }

    // MARK: - Message Management

    /// Adds a message to a session.
    ///
    /// Also increments the session's message_count.
    ///
    /// - Parameters:
    ///   - session: The session to add the message to.
    ///   - role: The message role: "user" or "assistant". Use MessageRole constants.
    ///   - content: The text content of the message.
    ///   - tokenCount: Optional estimated token count. Pass nil if unknown.
    /// - Returns: The database-assigned message ID.
    /// - Throws: `DatabaseError` if the insert or update fails.
    @discardableResult
    func addMessage(to session: Session, role: String, content: String, tokenCount: Int? = nil) throws -> Int64 {
        let now = SessionManager.dateFormatter.string(from: Date())

        // Insert the message
        let messageId = try database.insertAndReturnId(
            sql: """
                INSERT INTO messages (session_id, role, content, timestamp, token_count)
                VALUES (?, ?, ?, ?, ?)
                """,
            parameters: [session.id, role, content, now, tokenCount]
        )

        // Increment the session's message count
        try database.execute(
            sql: "UPDATE sessions SET message_count = message_count + 1 WHERE id = ?",
            parameters: [session.id]
        )

        Self.logger.info("Added \(role) message to session \(session.id)")
        return messageId
    }

    /// Retrieves recent messages from a session, ordered oldest to newest.
    ///
    /// This is used to build the conversation history for LLM context.
    /// Messages are returned in chronological order (oldest first) because
    /// the LLM expects conversation history in order.
    ///
    /// - Parameters:
    ///   - session: The session to get messages from.
    ///   - limit: Maximum number of messages to return (default: 20).
    /// - Returns: An array of messages, ordered by timestamp ascending (oldest first).
    /// - Throws: `DatabaseError` if the query fails.
    func getRecentMessages(for session: Session, limit: Int = 20) throws -> [SessionMessage] {
        // Use a subquery to get the latest N messages, then order them chronologically
        let sql = """
            SELECT * FROM (
                SELECT * FROM messages
                WHERE session_id = ?
                ORDER BY timestamp DESC
                LIMIT ?
            ) ORDER BY timestamp ASC
            """
        let rows = try database.query(sql: sql, parameters: [session.id, limit])
        return rows.compactMap { rowToSessionMessage($0) }
    }

    /// Returns the total number of messages in a session.
    ///
    /// - Parameter session: The session to count messages for.
    /// - Returns: The number of messages.
    /// - Throws: `DatabaseError` if the query fails.
    func messageCount(for session: Session) throws -> Int {
        let result = try database.queryScalar(
            sql: "SELECT COUNT(*) FROM messages WHERE session_id = ?",
            parameters: [session.id]
        )
        return Int(result as? Int64 ?? 0)
    }

    /// Gets the timestamp of the most recent message in a session.
    ///
    /// - Parameter session: The session to check.
    /// - Returns: The timestamp of the latest message, or nil if no messages exist.
    /// - Throws: `DatabaseError` if the query fails.
    func lastMessageTimestamp(for session: Session) throws -> Date? {
        let result = try database.query(
            sql: "SELECT MAX(timestamp) as latest FROM messages WHERE session_id = ?",
            parameters: [session.id]
        )
        guard let row = result.first,
              let timestampStr = row["latest"] as? String else {
            return nil
        }
        return SessionManager.dateFormatter.date(from: timestampStr)
    }

    // MARK: - Session History

    /// Gets all sessions for a phone number, ordered by most recent first.
    ///
    /// - Parameters:
    ///   - phoneNumber: The user's phone number.
    ///   - limit: Maximum number of sessions to return (default: 50).
    /// - Returns: An array of sessions, ordered by started_at descending.
    /// - Throws: `DatabaseError` if the query fails.
    func getSessionHistory(for phoneNumber: String, limit: Int = 50) throws -> [Session] {
        let sql = """
            SELECT * FROM sessions
            WHERE phone_number = ?
            ORDER BY started_at DESC
            LIMIT ?
            """
        let rows = try database.query(sql: sql, parameters: [phoneNumber, limit])
        return rows.compactMap { rowToSession($0) }
    }

    // MARK: - Staleness Detection

    /// Checks if a session is stale (inactive for longer than the timeout).
    ///
    /// A session is stale if:
    /// - It has messages, and the most recent message is older than staleTimeoutSeconds
    /// - It has no messages, and the session started more than staleTimeoutSeconds ago
    ///
    /// - Parameter session: The session to check.
    /// - Returns: true if the session is stale.
    func isSessionStale(_ session: Session) -> Bool {
        guard session.isActive else {
            return false  // Already ended sessions are not "stale"
        }

        let now = Date()
        let timeout = staleTimeoutSeconds

        // Try to get the last message timestamp
        if let lastMessage = try? lastMessageTimestamp(for: session) {
            return now.timeIntervalSince(lastMessage) > timeout
        }

        // No messages — check session start time
        return now.timeIntervalSince(session.startedAt) > timeout
    }

    // MARK: - Private Helpers

    /// Creates a new session in the database.
    private func createNewSession(for phoneNumber: String) throws -> Session {
        let now = SessionManager.dateFormatter.string(from: Date())
        let id = try database.insertAndReturnId(
            sql: "INSERT INTO sessions (phone_number, started_at) VALUES (?, ?)",
            parameters: [phoneNumber, now]
        )

        Self.logger.info("Created new session \(id) for phone number")

        // Query back the full session to get all defaults
        let rows = try database.query(
            sql: "SELECT * FROM sessions WHERE id = ?",
            parameters: [id]
        )
        guard let session = rows.first.flatMap({ rowToSession($0) }) else {
            throw DatabaseError.queryFailed(
                sql: "SELECT session",
                reason: "Failed to retrieve newly created session"
            )
        }
        return session
    }

    /// Converts a database row to a Session model.
    private func rowToSession(_ row: [String: Any?]) -> Session? {
        guard
            let id = row["id"] as? Int64,
            let phoneNumber = row["phone_number"] as? String,
            let startedAtStr = row["started_at"] as? String,
            let startedAt = SessionManager.dateFormatter.date(from: startedAtStr),
            let messageCount = row["message_count"] as? Int64,
            let isActiveInt = row["is_active"] as? Int64
        else {
            return nil
        }

        var endedAt: Date? = nil
        if let endedAtStr = row["ended_at"] as? String {
            endedAt = SessionManager.dateFormatter.date(from: endedAtStr)
        }

        let summary = row["summary"] as? String

        return Session(
            id: id,
            phoneNumber: phoneNumber,
            startedAt: startedAt,
            endedAt: endedAt,
            summary: summary,
            messageCount: Int(messageCount),
            isActive: isActiveInt != 0
        )
    }

    /// Converts a database row to a SessionMessage model.
    private func rowToSessionMessage(_ row: [String: Any?]) -> SessionMessage? {
        guard
            let id = row["id"] as? Int64,
            let sessionId = row["session_id"] as? Int64,
            let role = row["role"] as? String,
            let content = row["content"] as? String,
            let timestampStr = row["timestamp"] as? String,
            let timestamp = SessionManager.dateFormatter.date(from: timestampStr)
        else {
            return nil
        }

        var tokenCount: Int? = nil
        if let tokenCountInt64 = row["token_count"] as? Int64 {
            tokenCount = Int(tokenCountInt64)
        }

        return SessionMessage(
            id: id,
            sessionId: sessionId,
            role: role,
            content: content,
            timestamp: timestamp,
            tokenCount: tokenCount
        )
    }
}
```

STEP 3: Create tests/SessionManagerTests.swift

File: tests/SessionManagerTests.swift
```swift
// SessionManagerTests.swift
// EmberHearth
//
// Unit tests for Session, SessionMessage, and SessionManager.

import XCTest
@testable import EmberHearth

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
        // Should return the MOST RECENT 5, in chronological order
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
        XCTAssertFalse(manager.isSessionStale(session), "New session should not be stale")
    }

    func testEndedSessionIsNotStale() throws {
        let (_, manager) = try makeManager()

        var session = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session)

        // Manually create an ended session for testing
        session.isActive = false
        XCTAssertFalse(manager.isSessionStale(session), "Ended session should not be considered stale")
    }

    func testStaleSessionDetection() throws {
        let (db, manager) = try makeManager()

        // Create a session with a timestamp far in the past (6 hours ago)
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

        // Add a message also 6 hours ago
        try db.execute(
            sql: "INSERT INTO messages (session_id, role, content, timestamp) VALUES (?, ?, ?, ?)",
            parameters: [sessionId, "user", "Old message", pastTimestamp]
        )

        let session = try manager.getActiveSession(for: testPhoneNumber)
        XCTAssertNotNil(session)
        XCTAssertTrue(
            manager.isSessionStale(session!),
            "Session with 6-hour-old last message should be stale (default timeout is 4 hours)"
        )
    }

    func testStaleSessionAutoEndsOnGetOrCreate() throws {
        let (db, manager) = try makeManager()

        // Create a stale session (started 6 hours ago)
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

        // getOrCreateSession should detect the stale session, end it, and create a new one
        let newSession = try manager.getOrCreateSession(for: testPhoneNumber)

        XCTAssertNotEqual(newSession.id, oldSessionId, "Should create a new session")
        XCTAssertTrue(newSession.isActive)

        // The old session should be ended
        let history = try manager.getSessionHistory(for: testPhoneNumber)
        let oldSession = history.first { $0.id == oldSessionId }
        XCTAssertNotNil(oldSession)
        XCTAssertFalse(oldSession!.isActive, "Old stale session should be ended")
        XCTAssertNotNil(oldSession!.endedAt, "Old stale session should have ended_at set")
    }

    // MARK: - Session History Tests

    func testGetSessionHistory() throws {
        let (_, manager) = try makeManager()

        // Create and end multiple sessions
        let session1 = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session1)

        let session2 = try manager.getOrCreateSession(for: testPhoneNumber)
        try manager.endSession(session2)

        let session3 = try manager.getOrCreateSession(for: testPhoneNumber)

        let history = try manager.getSessionHistory(for: testPhoneNumber)
        XCTAssertEqual(history.count, 3)
        // Most recent first
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

        // No messages yet
        let noTimestamp = try manager.lastMessageTimestamp(for: session)
        XCTAssertNil(noTimestamp)

        // Add a message
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

        // Set a custom timeout (1 hour)
        UserDefaults.standard.set(3600.0, forKey: SessionManager.staleTimeoutDefaultsKey)

        XCTAssertEqual(manager.staleTimeoutSeconds, 3600.0)

        // Clean up
        UserDefaults.standard.removeObject(forKey: SessionManager.staleTimeoutDefaultsKey)
    }
}
```

STEP 4: Verify the build

After creating all files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. Common issues:
- Date formatting: Make sure the dateFormatter exactly matches "yyyy-MM-dd HH:mm:ss" with UTC timezone and "en_US_POSIX" locale. This MUST match the format in FactStore.
- Int64 vs Int: Database returns Int64 for integer columns. Convert with `Int(int64Value)` for model properties that use Int.
- isSessionStale uses `try?` for the database call inside it — this is intentional because staleness check should not throw. If the database call fails, we assume the session is not stale.
- The getRecentMessages query uses a subquery: SELECT * FROM (SELECT ... ORDER BY DESC LIMIT N) ORDER BY ASC. This gets the N most recent messages but returns them in chronological order.
- UserDefaults tests: The test sets and clears UserDefaults. Make sure the cleanup runs even if the test fails.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify DatabaseManager.swift, DatabaseError.swift, Fact.swift, or FactStore.swift.
- Do NOT modify any module placeholder files.
- SessionManager uses dependency injection — it receives DatabaseManager via constructor.
- Session summaries are NOT generated in this task. The endSession method does NOT call the LLM. Summary generation will be added in M5 (Personality & Context).
- Logger NEVER logs message content. It only logs session IDs, phone number presence, and event types.
- The stale timeout is stored in UserDefaults with key "com.emberhearth.session.staleTimeoutSeconds". The Settings UI (M7) will provide a way to change this.
- MessageRole is an enum with static constants (not cases) for type-safe role strings.
```

---

## Acceptance Criteria

- [ ] `src/Core/Session.swift` exists with `Session` and `SessionMessage` structs and `MessageRole` constants
- [ ] `Session` has properties: id (Int64), phoneNumber, startedAt, endedAt (optional), summary (optional), messageCount, isActive
- [ ] `SessionMessage` has properties: id (Int64), sessionId, role, content, timestamp, tokenCount (optional)
- [ ] `src/Core/SessionManager.swift` exists and compiles
- [ ] `getOrCreateSession(for:)` returns existing active session or creates new one
- [ ] `getOrCreateSession(for:)` detects stale sessions and auto-ends them before creating new
- [ ] `getActiveSession(for:)` returns the active session or nil
- [ ] `endSession(_:)` sets is_active = 0 and ended_at to current time
- [ ] `endSession(_:)` does NOT generate a summary (deferred to M5)
- [ ] `addMessage(to:role:content:tokenCount:)` inserts message and increments session message_count
- [ ] `getRecentMessages(for:limit:)` returns messages in chronological order (oldest first)
- [ ] `getRecentMessages(for:limit:)` returns the N most recent messages when limit is reached
- [ ] Default stale timeout is 4 hours (14400 seconds)
- [ ] Stale timeout is configurable via UserDefaults
- [ ] `isSessionStale(_:)` checks last message timestamp against timeout
- [ ] `getSessionHistory(for:limit:)` returns sessions ordered newest first
- [ ] Date formatting uses "yyyy-MM-dd HH:mm:ss", UTC, "en_US_POSIX" (matching FactStore)
- [ ] SessionManager uses DatabaseManager via dependency injection
- [ ] Logger NEVER logs message content
- [ ] All unit tests pass
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Core/Session.swift && echo "Session.swift exists" || echo "MISSING: Session.swift"
test -f src/Core/SessionManager.swift && echo "SessionManager.swift exists" || echo "MISSING: SessionManager.swift"
test -f tests/SessionManagerTests.swift && echo "SessionManagerTests.swift exists" || echo "MISSING: SessionManagerTests.swift"

# Verify Session model properties
grep "let id: Int64" src/Core/Session.swift
grep "let phoneNumber: String" src/Core/Session.swift
grep "var isActive: Bool" src/Core/Session.swift

# Verify stale timeout
grep "defaultStaleTimeoutSeconds" src/Core/SessionManager.swift
grep "4 \* 60 \* 60\|14400" src/Core/SessionManager.swift

# Verify UserDefaults key
grep "staleTimeoutDefaultsKey" src/Core/SessionManager.swift

# Verify date formatting matches FactStore
grep "yyyy-MM-dd HH:mm:ss" src/Core/SessionManager.swift

# Verify dependency injection
grep "private let database: DatabaseManager" src/Core/SessionManager.swift

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the SessionManager created in task 0304 for EmberHearth. Check for these common issues:

1. SESSION LIFECYCLE:
   - Verify getOrCreateSession() checks for existing active session first
   - Verify it detects stale sessions and auto-ends them before creating new
   - Verify endSession() sets is_active = 0 AND ended_at to current time
   - Verify endSession() does NOT generate a summary (that's for M5)
   - Verify createNewSession() inserts into the database and returns the full Session model

2. STALENESS DETECTION:
   - Verify isSessionStale() checks the LAST MESSAGE timestamp (not session start)
   - Verify it falls back to session start time if no messages exist
   - Verify it returns false for already-ended sessions
   - Verify the default timeout is 4 hours (14400 seconds)
   - Verify the timeout is read from UserDefaults with fallback to default
   - Verify the UserDefaults key is "com.emberhearth.session.staleTimeoutSeconds"

3. MESSAGE MANAGEMENT:
   - Verify addMessage() inserts into the messages table with correct columns
   - Verify addMessage() increments the session's message_count
   - Verify addMessage() handles nil tokenCount (binds NULL)
   - Verify getRecentMessages() returns messages in CHRONOLOGICAL order (oldest first)
   - Verify getRecentMessages() limit returns the N MOST RECENT messages (not just first N)
   - Verify the subquery pattern: SELECT * FROM (SELECT ... ORDER BY DESC LIMIT N) ORDER BY ASC

4. DATE FORMATTING:
   - Verify dateFormatter format is "yyyy-MM-dd HH:mm:ss"
   - Verify timezone is UTC
   - Verify locale is "en_US_POSIX"
   - Verify this matches the format used in FactStore.swift (must be identical)

5. ROW MAPPING:
   - Verify rowToSession() maps ALL columns correctly
   - Verify Int64 from database is converted to Int for messageCount
   - Verify is_active (Int64) is converted to Bool
   - Verify ended_at and summary handle NULL (nil)
   - Verify rowToSessionMessage() maps ALL columns correctly
   - Verify token_count handles NULL (nil → optional Int)

6. DEPENDENCY INJECTION:
   - Verify SessionManager takes DatabaseManager via constructor
   - Verify it does NOT create its own DatabaseManager

7. SECURITY:
   - Verify Logger NEVER logs message content or phone numbers in plain text
   - Verify all SQL uses parameterized queries (? placeholders)

8. MODEL CORRECTNESS:
   - Verify Session conforms to Identifiable and Equatable
   - Verify SessionMessage conforms to Identifiable and Equatable
   - Verify MessageRole constants are "user" and "assistant"

9. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test` and verify all SessionManagerTests pass
   - Check for any new warnings

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m4): add session manager for conversation state tracking
```

---

## Notes for Next Task

- The SessionManager is now available at `src/Core/SessionManager.swift`. It will be used by the message processing pipeline (M5) to manage conversation state.
- Session summaries are NOT generated yet. When M5 (Personality & Context) is implemented, the `endSession()` method should be extended to call the LLM for summary generation, or a separate summarization step should be added.
- The stale timeout is configurable via UserDefaults. The Settings UI (M7) should provide a slider or text field for "Session timeout (hours)" that writes to `com.emberhearth.session.staleTimeoutSeconds`.
- The `getRecentMessages()` method returns messages in chronological order (oldest first), which is the correct format for building LLM conversation history context.
- MessageRole constants ("user" and "assistant") match the `role` values used in the LLM message types (LLMMessageRole in src/LLM/LLMTypes.swift). The integration code in M5 will map between these.
- M4 is now complete after this task. The memory system provides: DatabaseManager (0300), FactStore (0301), FactRetriever (0302), FactExtractor (0303), and SessionManager (0304). The next milestone (M5) will wire these together with the personality system and message processing pipeline.
