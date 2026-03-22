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
        if let activeSession = try getActiveSession(for: phoneNumber) {
            if try isSessionStale(activeSession) {
                Self.logger.info("Session \(activeSession.id) is stale, ending and creating new")
                try endSession(activeSession)
                return try createNewSession(for: phoneNumber)
            }
            return activeSession
        }

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
    ///   - role: The message role. Use `MessageRole.user` or `MessageRole.assistant`.
    ///   - content: The text content of the message.
    ///   - tokenCount: Optional estimated token count. Pass nil if unknown.
    /// - Returns: The database-assigned message ID.
    /// - Throws: `DatabaseError` if the insert or update fails.
    @discardableResult
    func addMessage(to session: Session, role: LLMRole, content: String, tokenCount: Int? = nil) throws -> Int64 {
        let now = SessionManager.dateFormatter.string(from: Date())

        let messageId: Int64 = try database.transaction {
            let id = try database.insertAndReturnId(
                sql: """
                    INSERT INTO messages (session_id, role, content, timestamp, token_count)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                parameters: [session.id, role.rawValue, content, now, tokenCount]
            )

            try database.execute(
                sql: "UPDATE sessions SET message_count = message_count + 1 WHERE id = ?",
                parameters: [session.id]
            )

            return id
        }

        Self.logger.info("Added \(role.rawValue) message to session \(session.id)")
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
        let sql = """
            SELECT * FROM (
                SELECT * FROM messages
                WHERE session_id = ?
                ORDER BY timestamp DESC, id DESC
                LIMIT ?
            ) ORDER BY timestamp ASC, id ASC
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
            ORDER BY started_at DESC, id DESC
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
    /// - Throws: `DatabaseError` if the last-message lookup fails.
    func isSessionStale(_ session: Session) throws -> Bool {
        guard session.isActive else { return false }

        let now = Date()
        let timeout = staleTimeoutSeconds
        let lastActivity = try lastMessageTimestamp(for: session) ?? session.startedAt

        return now.timeIntervalSince(lastActivity) > timeout
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
            let roleStr = row["role"] as? String,
            let role = LLMRole(rawValue: roleStr),
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
