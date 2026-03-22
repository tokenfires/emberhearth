import Foundation
import SQLite3
import os.log

/// Reads messages from the iMessage chat.db SQLite database.
///
/// This class provides read-only access to the iMessage database stored at
/// ~/Library/Messages/chat.db. It uses the raw SQLite3 C API (available via
/// Foundation) rather than a third-party library to minimize dependencies.
///
/// ## Requirements
/// - Full Disk Access permission must be granted in System Settings
/// - The database is opened in SQLITE_OPEN_READONLY mode
/// - This class NEVER writes to chat.db
///
/// ## Thread Safety
/// Each instance maintains its own database connection. Do not share instances
/// across threads. Create separate instances for concurrent access.
final class ChatDatabaseReader {

    // MARK: - Properties

    /// The file path to the chat.db database.
    let databasePath: String

    /// The SQLite database connection handle. Nil if not yet opened.
    private var db: OpaquePointer?

    /// Logger for database operations.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "ChatDatabaseReader")

    /// SQLite destructor constant that tells SQLite to make its own copy of bound data.
    /// Equivalent to SQLITE_TRANSIENT, which is defined as ((sqlite3_destructor_type)-1) in C.
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Expected column count for the standard message query SELECT list.
    /// Used to detect schema mismatches early.
    private static let expectedMessageColumnCount: Int32 = 10

    // MARK: - Initialization

    /// Creates a new ChatDatabaseReader.
    ///
    /// - Parameter databasePath: The path to the chat.db file. Defaults to
    ///   ~/Library/Messages/chat.db. Pass a custom path **only** for testing
    ///   with a mock database — production callers should always use the default.
    init(databasePath: String? = nil) {
        if let databasePath = databasePath {
            self.databasePath = databasePath
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            self.databasePath = "\(home)/Library/Messages/chat.db"
        }
    }

    deinit {
        close()
    }

    // MARK: - Connection Management

    /// Opens the database connection in read-only mode.
    ///
    /// - Throws: `ChatDatabaseError.databaseNotFound` if the file doesn't exist,
    ///           `ChatDatabaseError.databaseOpenFailed` if the connection fails.
    func open() throws {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            logger.error("chat.db not found at path: \(self.databasePath, privacy: .public)")
            throw ChatDatabaseError.databaseNotFound(path: databasePath)
        }

        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        let result = sqlite3_open_v2(databasePath, &db, flags, nil)

        guard result == SQLITE_OK, db != nil else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            logger.error("Failed to open chat.db: \(errorMessage, privacy: .public)")
            sqlite3_close(db)
            db = nil
            throw ChatDatabaseError.databaseOpenFailed(
                underlyingError: NSError(
                    domain: "SQLite",
                    code: Int(result),
                    userInfo: [NSLocalizedDescriptionKey: errorMessage]
                )
            )
        }

        sqlite3_busy_timeout(db, 5000)

        logger.info("Opened chat.db in read-only mode at: \(self.databasePath, privacy: .public)")
    }

    /// Closes the database connection.
    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
            logger.info("Closed chat.db connection")
        }
    }

    // MARK: - Query Methods

    /// Fetches recent messages from the database.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of messages to return. Defaults to 50.
    ///   - since: If provided, only returns messages after this date. If nil, returns the most recent messages.
    /// - Returns: An array of `ChatMessage` sorted by date ascending (oldest first).
    /// - Throws: `ChatDatabaseError` if the query fails.
    func fetchRecentMessages(limit: Int = 50, since: Date? = nil) throws -> [ChatMessage] {
        try ensureOpen()

        let sql: String
        var bindings: [QueryBinding] = []

        if let since = since {
            let nanoseconds = Self.dateToAppleNanoseconds(since)
            sql = """
                \(Self.messageSelectSQL)
                WHERE m.date > ?1
                ORDER BY m.date DESC LIMIT ?2
                """
            bindings = [.int64(nanoseconds, index: 1), .int32(Int32(limit), index: 2)]
        } else {
            sql = """
                \(Self.messageSelectSQL)
                ORDER BY m.date DESC LIMIT ?1
                """
            bindings = [.int32(Int32(limit), index: 1)]
        }

        let messages = try executeMessageQuery(sql: sql, bindings: bindings)
        return messages.reversed()
    }

    /// Fetches messages for a specific phone number or handle identifier.
    ///
    /// - Parameters:
    ///   - handle: The phone number (E.164 format) or email address.
    ///   - limit: Maximum number of messages to return. Defaults to 50.
    /// - Returns: An array of `ChatMessage` sorted by date ascending (oldest first).
    /// - Throws: `ChatDatabaseError` if the query fails.
    func fetchMessages(forHandle handle: String, limit: Int = 50) throws -> [ChatMessage] {
        try ensureOpen()

        let sql = """
            \(Self.messageSelectSQL)
            WHERE h.id = ?1
            ORDER BY m.date DESC
            LIMIT ?2
            """

        let bindings: [QueryBinding] = [
            .text(handle, index: 1),
            .int32(Int32(limit), index: 2)
        ]

        let messages = try executeMessageQuery(sql: sql, bindings: bindings)
        return messages.reversed()
    }

    /// Fetches messages with ROWID greater than the specified value.
    /// Used by MessageWatcher to get only new/unprocessed messages.
    ///
    /// - Parameter lastRowId: Only return messages with ROWID > this value.
    /// - Returns: An array of `ChatMessage` sorted by ROWID ascending.
    /// - Throws: `ChatDatabaseError` if the query fails.
    func fetchMessagesSince(rowId lastRowId: Int64) throws -> [ChatMessage] {
        try ensureOpen()

        let sql = """
            \(Self.messageSelectSQL)
            WHERE m.ROWID > ?1
            ORDER BY m.ROWID ASC
            """

        let bindings: [QueryBinding] = [.int64(lastRowId, index: 1)]
        return try executeMessageQuery(sql: sql, bindings: bindings)
    }

    /// Returns the highest ROWID in the message table.
    /// Used to initialize the MessageWatcher's tracking position.
    ///
    /// - Returns: The maximum ROWID, or 0 if the table is empty.
    /// - Throws: `ChatDatabaseError` if the query fails.
    func getMaxRowId() throws -> Int64 {
        try ensureOpen()

        let sql = "SELECT MAX(ROWID) FROM message"
        var statement: OpaquePointer?

        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw ChatDatabaseError.queryFailed(
                query: "getMaxRowId",
                underlyingError: NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
            )
        }

        let stepResult = sqlite3_step(statement)
        if stepResult == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        }

        try checkStepResult(stepResult, sql: "getMaxRowId")
        return 0
    }

    /// Checks whether a specific chat is a group chat.
    ///
    /// - Parameter chatId: The chat ROWID from the chat table.
    /// - Returns: True if the chat is a group chat.
    /// - Throws: `ChatDatabaseError` if the query fails.
    func isGroupChat(chatId: Int64) throws -> Bool {
        try ensureOpen()

        let sql = """
            SELECT
                c.group_id,
                (SELECT COUNT(*) FROM chat_handle_join chj WHERE chj.chat_id = c.ROWID) AS participant_count
            FROM chat c
            WHERE c.ROWID = ?
            """

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))
            throw ChatDatabaseError.queryFailed(
                query: "isGroupChat",
                underlyingError: NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
            )
        }

        sqlite3_bind_int64(statement, 1, chatId)

        let stepResult = sqlite3_step(statement)
        if stepResult == SQLITE_ROW {
            if sqlite3_column_type(statement, 0) != SQLITE_NULL {
                let groupId = String(cString: sqlite3_column_text(statement, 0))
                if !groupId.isEmpty {
                    return true
                }
            }

            let participantCount = sqlite3_column_int64(statement, 1)
            if participantCount > 1 {
                return true
            }
        }

        try checkStepResult(stepResult, sql: "isGroupChat")
        return false
    }

    // MARK: - Private Helpers

    /// Ensures the database connection is open.
    private func ensureOpen() throws {
        if db == nil {
            try open()
        }
    }

    /// The shared SELECT column list for all message queries.
    /// Joins against chat to get group_id for robust group chat detection.
    private static let messageSelectSQL = """
        SELECT
            m.ROWID,
            m.text,
            m.attributedBody,
            m.date,
            m.is_from_me,
            m.handle_id,
            m.cache_roomnames,
            h.id AS phone_number,
            cmj.chat_id,
            c.group_id
        FROM message m
        LEFT JOIN handle h ON m.handle_id = h.ROWID
        LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
        LEFT JOIN chat c ON cmj.chat_id = c.ROWID
        """

    /// Represents a value to bind to a prepared statement parameter.
    private enum QueryBinding {
        case text(String, index: Int32)
        case int64(Int64, index: Int32)
        case int32(Int32, index: Int32)
    }

    /// Checks an `sqlite3_step` return code for error conditions.
    /// Call after the stepping loop or single-step completes.
    ///
    /// - Parameters:
    ///   - result: The return value from `sqlite3_step`.
    ///   - sql: A label for the query, used in error reporting.
    /// - Throws: `ChatDatabaseError.databaseLocked` or `.queryFailed` on error.
    private func checkStepResult(_ result: Int32, sql: String) throws {
        switch result {
        case SQLITE_DONE, SQLITE_ROW:
            return
        case SQLITE_BUSY, SQLITE_LOCKED:
            logger.warning("Database locked during step for query: \(sql, privacy: .public)")
            throw ChatDatabaseError.databaseLocked
        default:
            let error = String(cString: sqlite3_errmsg(db))
            logger.error("sqlite3_step failed (\(result)) for query: \(sql, privacy: .public)")
            throw ChatDatabaseError.queryFailed(
                query: sql,
                underlyingError: NSError(domain: "SQLite", code: Int(result), userInfo: [NSLocalizedDescriptionKey: error])
            )
        }
    }

    /// Executes a message query and maps results to ChatMessage structs.
    ///
    /// - Parameters:
    ///   - sql: The SQL query string. Must SELECT the columns from `messageSelectSQL`.
    ///   - bindings: Parameter values to bind before execution.
    /// - Returns: An array of ChatMessage.
    private func executeMessageQuery(sql: String, bindings: [QueryBinding] = []) throws -> [ChatMessage] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))

            if error.contains("locked") || error.contains("busy") {
                throw ChatDatabaseError.databaseLocked
            }

            if error.contains("no such column") || error.contains("no such table") {
                throw ChatDatabaseError.schemaMismatch(details: error)
            }

            throw ChatDatabaseError.queryFailed(
                query: sql,
                underlyingError: NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
            )
        }

        let columnCount = sqlite3_column_count(statement)
        if columnCount != Self.expectedMessageColumnCount {
            throw ChatDatabaseError.schemaMismatch(
                details: "Expected \(Self.expectedMessageColumnCount) columns but got \(columnCount)"
            )
        }

        for binding in bindings {
            switch binding {
            case .text(let value, let index):
                value.withCString { cString in
                    sqlite3_bind_text(statement, index, cString, -1, Self.sqliteTransient)
                }
            case .int64(let value, let index):
                sqlite3_bind_int64(statement, index, value)
            case .int32(let value, let index):
                sqlite3_bind_int(statement, index, value)
            }
        }

        var messages: [ChatMessage] = []
        var stepResult = sqlite3_step(statement)

        while stepResult == SQLITE_ROW {
            let rowId = sqlite3_column_int64(statement, 0)

            var text: String? = nil
            if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                text = String(cString: sqlite3_column_text(statement, 1))
            }

            if (text == nil || text?.isEmpty == true), sqlite3_column_type(statement, 2) != SQLITE_NULL {
                let blobPointer = sqlite3_column_blob(statement, 2)
                let blobSize = sqlite3_column_bytes(statement, 2)
                if let blobPointer = blobPointer, blobSize > 0 {
                    let data = Data(bytes: blobPointer, count: Int(blobSize))
                    text = Self.extractTextFromAttributedBody(data)
                }
            }

            let rawDate = sqlite3_column_int64(statement, 3)
            let date = Self.appleNanosecondsToDate(rawDate)

            let isFromMe = sqlite3_column_int(statement, 4) == 1
            let handleId = sqlite3_column_int64(statement, 5)

            // Group chat detection: check cache_roomnames (col 6) OR group_id (col 9)
            var isGroupChat = false
            if sqlite3_column_type(statement, 6) != SQLITE_NULL {
                let roomName = String(cString: sqlite3_column_text(statement, 6))
                if !roomName.isEmpty {
                    isGroupChat = true
                }
            }
            if !isGroupChat, sqlite3_column_type(statement, 9) != SQLITE_NULL {
                let groupId = String(cString: sqlite3_column_text(statement, 9))
                if !groupId.isEmpty {
                    isGroupChat = true
                }
            }

            var phoneNumber: String? = nil
            if sqlite3_column_type(statement, 7) != SQLITE_NULL {
                phoneNumber = String(cString: sqlite3_column_text(statement, 7))
            }

            var chatId: Int64? = nil
            if sqlite3_column_type(statement, 8) != SQLITE_NULL {
                chatId = sqlite3_column_int64(statement, 8)
            }

            let message = ChatMessage(
                id: rowId,
                text: text,
                date: date,
                isFromMe: isFromMe,
                handleId: handleId,
                phoneNumber: phoneNumber,
                isGroupChat: isGroupChat,
                chatId: chatId
            )
            messages.append(message)

            stepResult = sqlite3_step(statement)
        }

        try checkStepResult(stepResult, sql: sql)

        logger.debug("Query returned \(messages.count) messages")
        return messages
    }

    // MARK: - Date Conversion

    /// Converts an Apple Core Data nanosecond timestamp to a Swift Date.
    ///
    /// chat.db stores dates as nanoseconds since January 1, 2001 00:00:00 UTC.
    /// Divide by 1_000_000_000 to get seconds, then use Date(timeIntervalSinceReferenceDate:).
    ///
    /// Older macOS versions stored timestamps in seconds instead of nanoseconds.
    /// The threshold `1_000_000_000_000` cleanly separates the two formats for
    /// any realistic date (seconds won't exceed ~1 billion until year ~2033,
    /// while nanosecond timestamps start at ~31 trillion for year 2002).
    ///
    /// - Parameter nanoseconds: The raw timestamp from the date column.
    /// - Returns: A Swift Date.
    static func appleNanosecondsToDate(_ nanoseconds: Int64) -> Date {
        let seconds: TimeInterval
        if nanoseconds > 1_000_000_000_000 {
            seconds = TimeInterval(nanoseconds) / 1_000_000_000.0
        } else {
            seconds = TimeInterval(nanoseconds)
        }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    /// Converts a Swift Date to Apple Core Data nanosecond timestamp.
    ///
    /// - Parameter date: The date to convert.
    /// - Returns: Nanoseconds since January 1, 2001.
    static func dateToAppleNanoseconds(_ date: Date) -> Int64 {
        return Int64(date.timeIntervalSinceReferenceDate * 1_000_000_000)
    }

    // MARK: - Attributed Body Parsing

    /// Attempts to extract plain text from an attributedBody blob.
    ///
    /// Starting with macOS Ventura (13.0), Messages stores message text as a
    /// serialized NSAttributedString in the attributedBody column instead of
    /// the plain text column. This method attempts to deserialize it.
    ///
    /// - Parameter data: The raw blob data from the attributedBody column.
    /// - Returns: The extracted plain text, or nil if extraction failed.
    static func extractTextFromAttributedBody(_ data: Data) -> String? {
        do {
            if let attributedString = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: data
            ) {
                return attributedString.string
            }
        } catch {
            return extractTextByScanning(data)
        }
        return nil
    }

    /// Fallback text extraction by scanning the raw attributedBody bytes.
    ///
    /// Scans for known markers ("NSString" / "NSMutableString") in the serialized
    /// typedstream data and extracts the UTF-8 string that follows. This is a
    /// best-effort fallback when `NSKeyedUnarchiver` fails (e.g., on blobs from
    /// a different macOS version or corrupted archives).
    ///
    /// - Parameter data: The raw blob data.
    /// - Returns: Extracted text, or nil.
    static func extractTextByScanning(_ data: Data) -> String? {
        guard data.count > 10 else { return nil }

        let markers = [Data("NSMutableString".utf8), Data("NSString".utf8)]

        for marker in markers {
            guard let markerRange = data.range(of: marker) else { continue }

            var offset = markerRange.upperBound
            while offset < data.count && data[offset] < 0x20 && data[offset] != 0x0A {
                offset += 1
            }

            guard offset < data.count else { continue }

            var endOffset = offset
            while endOffset < data.count {
                let byte = data[endOffset]
                if byte == 0x00 || byte == 0x86 || byte == 0x84 || byte == 0x85 {
                    break
                }
                endOffset += 1
            }

            if endOffset > offset,
               let text = String(data: data[offset..<endOffset], encoding: .utf8),
               !text.isEmpty {
                return text
            }
        }

        return nil
    }
}
