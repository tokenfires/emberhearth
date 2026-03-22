# Task 0100: chat.db SQLite Reader

**Milestone:** M2 - iMessage Integration
**Unit:** 2.1 - chat.db Reader
**Phase:** 1
**Depends On:** 0004 (M1 Foundation complete)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/research/imessage.md` — Read the "Technical Deep Dive" section on chat.db schema, key tables, timestamp format, and the `attributedBody` change in macOS Ventura
2. `docs/architecture/decisions/0004-no-shell-execution.md` — Understand the security constraint: no shell execution, no Process(), no /bin/bash
3. `docs/architecture/decisions/0010-fsevents-data-monitoring.md` — See the change detection pattern using ROWID tracking
4. `CLAUDE.md` — Project conventions (PascalCase for Swift files, src/ layout, security principles)

> **Context Budget Note:** `imessage.md` is ~500 lines. Focus on the "Technical Deep Dive" and "Recommended Architecture" sections. Skip the "Work/Personal Context Separation" section — that is not relevant to this task.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the chat.db SQLite reader for EmberHearth, a macOS personal AI assistant. This is a greenfield Swift project. The Xcode project and SwiftUI shell already exist from prior tasks (0001-0004).

## What You Are Building

A read-only SQLite reader that queries ~/Library/Messages/chat.db to extract iMessage conversations. This is the foundation of iMessage integration — it reads messages but NEVER writes to chat.db.

## Files to Create

### 1. `src/Core/Models/ChatMessage.swift`

Create this model struct:

```swift
import Foundation

/// Represents a single message read from the iMessage chat.db database.
/// This is a read-only data model — EmberHearth never writes to chat.db.
struct ChatMessage: Identifiable, Equatable, Sendable {
    /// The ROWID from the message table in chat.db. Used for tracking
    /// which messages have already been processed.
    let id: Int64

    /// The message text content. May be nil for attachment-only messages
    /// or if the text could not be decoded from attributedBody.
    let text: String?

    /// When the message was sent or received. Converted from Apple's
    /// Core Data timestamp format (nanoseconds since 2001-01-01 00:00:00 UTC).
    let date: Date

    /// True if this message was sent by the local user, false if received.
    let isFromMe: Bool

    /// The ROWID of the handle (contact) in the handle table.
    let handleId: Int64

    /// The phone number or email address of the other party.
    /// Phone numbers are in E.164 format (e.g., "+15551234567").
    /// May be nil if the handle could not be resolved.
    let phoneNumber: String?

    /// True if this message belongs to a group chat.
    /// Group chats are detected by checking cache_roomnames on the message
    /// or group_id on the associated chat.
    let isGroupChat: Bool

    /// The chat_id from chat_message_join, linking this message to a conversation thread.
    let chatId: Int64?
}
```

### 2. `src/Core/Errors/ChatDatabaseError.swift`

Create this error enum:

```swift
import Foundation

/// Errors that can occur when reading from the iMessage chat.db database.
enum ChatDatabaseError: LocalizedError {
    /// The chat.db file was not found at the expected path.
    /// This typically means Full Disk Access has not been granted.
    case databaseNotFound(path: String)

    /// The database file exists but could not be opened.
    /// May indicate corruption or an incompatible format.
    case databaseOpenFailed(underlyingError: Error)

    /// A SQL query failed to execute.
    case queryFailed(query: String, underlyingError: Error)

    /// The database is currently locked by another process.
    /// This can happen if Messages.app is actively writing.
    case databaseLocked

    /// A required column was missing from the query result.
    /// This may indicate a schema change in a newer macOS version.
    case schemaMismatch(details: String)

    /// The message date could not be converted from Apple's timestamp format.
    case dateConversionFailed(rawValue: Int64)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "iMessage database not found at \(path). Please grant Full Disk Access in System Settings > Privacy & Security."
        case .databaseOpenFailed(let error):
            return "Failed to open iMessage database: \(error.localizedDescription)"
        case .queryFailed(let query, let error):
            return "Database query failed (\(query)): \(error.localizedDescription)"
        case .databaseLocked:
            return "iMessage database is temporarily locked. Will retry."
        case .schemaMismatch(let details):
            return "iMessage database schema mismatch: \(details)"
        case .dateConversionFailed(let rawValue):
            return "Failed to convert message date from raw value: \(rawValue)"
        }
    }
}
```

### 3. `src/Core/ChatDatabaseReader.swift`

This is the main file. Create it with these exact specifications:

```swift
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

    /// The reference date for Apple's Core Data timestamps: January 1, 2001 00:00:00 UTC.
    /// chat.db stores dates as nanoseconds since this reference date.
    private static let appleReferenceDate = Date(timeIntervalSinceReferenceDate: 0)

    // MARK: - Initialization

    /// Creates a new ChatDatabaseReader.
    ///
    /// - Parameter databasePath: The path to the chat.db file. Defaults to
    ///   ~/Library/Messages/chat.db. Override this for testing with a mock database.
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
        // Check that the file exists before trying to open
        guard FileManager.default.fileExists(atPath: databasePath) else {
            logger.error("chat.db not found at path: \(self.databasePath, privacy: .public)")
            throw ChatDatabaseError.databaseNotFound(path: databasePath)
        }

        // Open in read-only mode — CRITICAL: we must never write to chat.db
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

        // Set a busy timeout of 5 seconds for when the database is locked
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

        var sql = """
            SELECT
                m.ROWID,
                m.text,
                m.attributedBody,
                m.date,
                m.is_from_me,
                m.handle_id,
                m.cache_roomnames,
                h.id AS phone_number,
                cmj.chat_id
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            """

        if since != nil {
            let nanoseconds = Self.dateToAppleNanoseconds(since!)
            sql += " WHERE m.date > \(nanoseconds)"
        }

        sql += " ORDER BY m.date DESC LIMIT \(limit)"

        let messages = try executeMessageQuery(sql: sql)

        // Return in chronological order (oldest first)
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
            SELECT
                m.ROWID,
                m.text,
                m.attributedBody,
                m.date,
                m.is_from_me,
                m.handle_id,
                m.cache_roomnames,
                h.id AS phone_number,
                cmj.chat_id
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            WHERE h.id = ?
            ORDER BY m.date DESC
            LIMIT \(limit)
            """

        let messages = try executeMessageQuery(sql: sql, bindText: handle, paramIndex: 1)
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
            SELECT
                m.ROWID,
                m.text,
                m.attributedBody,
                m.date,
                m.is_from_me,
                m.handle_id,
                m.cache_roomnames,
                h.id AS phone_number,
                cmj.chat_id
            FROM message m
            LEFT JOIN handle h ON m.handle_id = h.ROWID
            LEFT JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            WHERE m.ROWID > \(lastRowId)
            ORDER BY m.ROWID ASC
            """

        return try executeMessageQuery(sql: sql)
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

        if sqlite3_step(statement) == SQLITE_ROW {
            return sqlite3_column_int64(statement, 0)
        }

        return 0
    }

    /// Checks whether a specific chat is a group chat.
    ///
    /// - Parameter chatId: The chat ROWID from the chat table.
    /// - Returns: True if the chat is a group chat.
    /// - Throws: `ChatDatabaseError` if the query fails.
    func isGroupChat(chatId: Int64) throws -> Bool {
        try ensureOpen()

        // A chat is a group chat if:
        // 1. It has a non-null, non-empty group_id, OR
        // 2. It has more than one participant in chat_handle_join
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

        if sqlite3_step(statement) == SQLITE_ROW {
            // Check group_id (column 0)
            if sqlite3_column_type(statement, 0) != SQLITE_NULL {
                let groupId = String(cString: sqlite3_column_text(statement, 0))
                if !groupId.isEmpty {
                    return true
                }
            }

            // Check participant count (column 1)
            let participantCount = sqlite3_column_int64(statement, 1)
            if participantCount > 1 {
                return true
            }
        }

        return false
    }

    // MARK: - Private Helpers

    /// Ensures the database connection is open.
    private func ensureOpen() throws {
        if db == nil {
            try open()
        }
    }

    /// Executes a message query and maps results to ChatMessage structs.
    ///
    /// - Parameters:
    ///   - sql: The SQL query string. Must SELECT the standard message columns.
    ///   - bindText: Optional text value to bind to a parameter.
    ///   - paramIndex: The 1-based parameter index for bindText.
    /// - Returns: An array of ChatMessage.
    private func executeMessageQuery(sql: String, bindText: String? = nil, paramIndex: Int32 = 0) throws -> [ChatMessage] {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let error = String(cString: sqlite3_errmsg(db))

            // Check specifically for locked database
            if error.contains("locked") || error.contains("busy") {
                throw ChatDatabaseError.databaseLocked
            }

            throw ChatDatabaseError.queryFailed(
                query: sql,
                underlyingError: NSError(domain: "SQLite", code: 0, userInfo: [NSLocalizedDescriptionKey: error])
            )
        }

        // Bind text parameter if provided
        if let bindText = bindText {
            sqlite3_bind_text(statement, paramIndex, (bindText as NSString).utf8String, -1, nil)
        }

        var messages: [ChatMessage] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(statement, 0)

            // Try to get text from the text column first, then fall back to attributedBody
            var text: String? = nil
            if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                text = String(cString: sqlite3_column_text(statement, 1))
            }

            // If text is nil or empty, try to extract from attributedBody (macOS Ventura+)
            if (text == nil || text?.isEmpty == true), sqlite3_column_type(statement, 2) != SQLITE_NULL {
                let blobPointer = sqlite3_column_blob(statement, 2)
                let blobSize = sqlite3_column_bytes(statement, 2)
                if let blobPointer = blobPointer, blobSize > 0 {
                    let data = Data(bytes: blobPointer, count: Int(blobSize))
                    text = Self.extractTextFromAttributedBody(data)
                }
            }

            // Convert Apple nanosecond timestamp to Date
            let rawDate = sqlite3_column_int64(statement, 3)
            let date = Self.appleNanosecondsToDate(rawDate)

            let isFromMe = sqlite3_column_int(statement, 4) == 1
            let handleId = sqlite3_column_int64(statement, 5)

            // Check cache_roomnames for group chat detection
            let isGroupChat: Bool
            if sqlite3_column_type(statement, 6) != SQLITE_NULL {
                let roomName = String(cString: sqlite3_column_text(statement, 6))
                isGroupChat = !roomName.isEmpty
            } else {
                isGroupChat = false
            }

            // Phone number from handle table
            var phoneNumber: String? = nil
            if sqlite3_column_type(statement, 7) != SQLITE_NULL {
                phoneNumber = String(cString: sqlite3_column_text(statement, 7))
            }

            // Chat ID from chat_message_join
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
        }

        logger.debug("Query returned \(messages.count) messages")
        return messages
    }

    // MARK: - Date Conversion

    /// Converts an Apple Core Data nanosecond timestamp to a Swift Date.
    ///
    /// chat.db stores dates as nanoseconds since January 1, 2001 00:00:00 UTC.
    /// Divide by 1_000_000_000 to get seconds, then use Date(timeIntervalSinceReferenceDate:).
    ///
    /// - Parameter nanoseconds: The raw timestamp from the date column.
    /// - Returns: A Swift Date.
    static func appleNanosecondsToDate(_ nanoseconds: Int64) -> Date {
        // On older macOS versions, timestamps may already be in seconds.
        // Nanosecond timestamps are very large (> 1_000_000_000_000_000_000 range for 2020+).
        // Second timestamps are much smaller (< 1_000_000_000 range).
        let seconds: TimeInterval
        if nanoseconds > 1_000_000_000_000 {
            // Nanosecond timestamp (modern macOS)
            seconds = TimeInterval(nanoseconds) / 1_000_000_000.0
        } else {
            // Already in seconds (older macOS)
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
        // The attributedBody is an NSKeyedArchiver-encoded NSAttributedString.
        // We attempt to unarchive it and extract the string.
        do {
            if let attributedString = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSAttributedString.self,
                from: data
            ) {
                return attributedString.string
            }
        } catch {
            // If NSKeyedUnarchiver fails, try a byte-scanning fallback.
            // The text is often embedded in the blob preceded by specific markers.
            return extractTextByScanning(data)
        }
        return nil
    }

    /// Fallback text extraction by scanning the raw attributedBody bytes.
    ///
    /// This scans for the "NSString" marker in the serialized data and extracts
    /// the UTF-8 string that follows. This is a best-effort fallback.
    ///
    /// - Parameter data: The raw blob data.
    /// - Returns: Extracted text, or nil.
    private static func extractTextByScanning(_ data: Data) -> String? {
        // Look for the streamtyped preamble that appears before the text content.
        // The pattern is: 0x01 followed by the text content, then 0x00 or other markers.
        // This is fragile but serves as a fallback when NSKeyedUnarchiver fails.

        guard data.count > 10 else { return nil }

        // Try to find text between known markers in the typedstream format.
        // The text payload often appears after "NSString" or "NSMutableString" markers.
        let nsStringMarker = Data("NSString".utf8)
        if let markerRange = data.range(of: nsStringMarker) {
            // Skip past the marker and a few control bytes to find the text
            var offset = markerRange.upperBound
            // Skip control bytes (typically 1-3 bytes of length/type info)
            while offset < data.count && data[offset] < 0x20 && data[offset] != 0x0A {
                offset += 1
            }

            if offset < data.count {
                // Try to read a length-prefixed string
                var endOffset = offset
                while endOffset < data.count {
                    let byte = data[endOffset]
                    // Stop at null byte or common terminator bytes
                    if byte == 0x00 || byte == 0x86 || byte == 0x84 {
                        break
                    }
                    endOffset += 1
                }

                if endOffset > offset {
                    let textData = data[offset..<endOffset]
                    return String(data: textData, encoding: .utf8)
                }
            }
        }

        return nil
    }
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** This is a hard security rule per ADR-0004.
2. **NEVER write to chat.db.** Open with SQLITE_OPEN_READONLY flag only.
3. Use the raw SQLite3 C API from Foundation — do NOT add any third-party SPM dependencies for this task.
4. All Swift files use PascalCase naming.
5. All classes and methods must have documentation comments.
6. Use `os.Logger` for logging (subsystem: "com.emberhearth.core").
7. The database path must be configurable via the initializer (for testing).

## Directory Structure

Create these directories and files:
- `src/Core/Models/ChatMessage.swift`
- `src/Core/Errors/ChatDatabaseError.swift`
- `src/Core/ChatDatabaseReader.swift`
- `tests/Core/ChatDatabaseReaderTests.swift`

## Unit Tests

Create `tests/Core/ChatDatabaseReaderTests.swift` with these test cases:

```swift
import XCTest
@testable import EmberHearth

final class ChatDatabaseReaderTests: XCTestCase {

    private var testDBPath: String!
    private var reader: ChatDatabaseReader!

    override func setUp() {
        super.setUp()
        // Create a temporary test database
        testDBPath = NSTemporaryDirectory() + "test_chat_\(UUID().uuidString).db"
        createTestDatabase(at: testDBPath)
        reader = ChatDatabaseReader(databasePath: testDBPath)
    }

    override func tearDown() {
        reader.close()
        try? FileManager.default.removeItem(atPath: testDBPath)
        super.tearDown()
    }

    // MARK: - Connection Tests

    func testOpenValidDatabase() throws {
        XCTAssertNoThrow(try reader.open())
    }

    func testOpenNonexistentDatabase() {
        let badReader = ChatDatabaseReader(databasePath: "/nonexistent/path/chat.db")
        XCTAssertThrowsError(try badReader.open()) { error in
            guard case ChatDatabaseError.databaseNotFound = error else {
                XCTFail("Expected databaseNotFound error, got \(error)")
                return
            }
        }
    }

    // MARK: - Query Tests

    func testFetchRecentMessages() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 10)
        XCTAssertFalse(messages.isEmpty, "Should return messages from test database")
        // Verify chronological order
        for i in 1..<messages.count {
            XCTAssertLessThanOrEqual(messages[i-1].date, messages[i].date)
        }
    }

    func testFetchMessagesForHandle() throws {
        try reader.open()
        let messages = try reader.fetchMessages(forHandle: "+15551234567", limit: 10)
        XCTAssertFalse(messages.isEmpty, "Should return messages for test handle")
        for message in messages {
            XCTAssertEqual(message.phoneNumber, "+15551234567")
        }
    }

    func testFetchMessagesSinceRowId() throws {
        try reader.open()
        let allMessages = try reader.fetchRecentMessages(limit: 100)
        guard let firstMessage = allMessages.first else {
            XCTFail("No messages in test database")
            return
        }
        let newerMessages = try reader.fetchMessagesSince(rowId: firstMessage.id)
        XCTAssertTrue(newerMessages.allSatisfy { $0.id > firstMessage.id })
    }

    func testGetMaxRowId() throws {
        try reader.open()
        let maxId = try reader.getMaxRowId()
        XCTAssertGreaterThan(maxId, 0, "Max ROWID should be positive in test database")
    }

    // MARK: - Group Chat Detection

    func testIsGroupChatReturnsFalseForDirectMessage() throws {
        try reader.open()
        // Chat ID 1 is a direct message in our test DB
        let result = try reader.isGroupChat(chatId: 1)
        XCTAssertFalse(result)
    }

    func testIsGroupChatReturnsTrueForGroupChat() throws {
        try reader.open()
        // Chat ID 2 is a group chat in our test DB
        let result = try reader.isGroupChat(chatId: 2)
        XCTAssertTrue(result)
    }

    // MARK: - Date Conversion Tests

    func testAppleNanosecondsToDate() {
        // 2024-01-15 12:00:00 UTC = 726926400 seconds since 2001-01-01
        // In nanoseconds: 726926400 * 1_000_000_000 = 726926400000000000
        let nanoseconds: Int64 = 726_926_400_000_000_000
        let date = ChatDatabaseReader.appleNanosecondsToDate(nanoseconds)
        let expected = Date(timeIntervalSinceReferenceDate: 726_926_400)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, expected.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    func testDateToAppleNanoseconds() {
        let date = Date(timeIntervalSinceReferenceDate: 726_926_400)
        let nanoseconds = ChatDatabaseReader.dateToAppleNanoseconds(date)
        XCTAssertEqual(nanoseconds, 726_926_400_000_000_000)
    }

    func testOlderMacOSSecondsTimestamp() {
        // On older macOS, timestamps are in seconds, not nanoseconds
        let seconds: Int64 = 726_926_400
        let date = ChatDatabaseReader.appleNanosecondsToDate(seconds)
        let expected = Date(timeIntervalSinceReferenceDate: 726_926_400)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, expected.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    // MARK: - ChatMessage Model Tests

    func testChatMessageEquality() {
        let msg1 = ChatMessage(id: 1, text: "Hello", date: Date(), isFromMe: false, handleId: 1, phoneNumber: "+15551234567", isGroupChat: false, chatId: 1)
        let msg2 = ChatMessage(id: 1, text: "Hello", date: msg1.date, isFromMe: false, handleId: 1, phoneNumber: "+15551234567", isGroupChat: false, chatId: 1)
        XCTAssertEqual(msg1, msg2)
    }

    func testChatMessageWithNilText() {
        let msg = ChatMessage(id: 1, text: nil, date: Date(), isFromMe: false, handleId: 1, phoneNumber: "+15551234567", isGroupChat: false, chatId: 1)
        XCTAssertNil(msg.text)
    }

    // MARK: - Test Database Helper

    /// Creates a minimal chat.db-like SQLite database for testing.
    private func createTestDatabase(at path: String) {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let schema = """
            CREATE TABLE IF NOT EXISTS handle (
                ROWID INTEGER PRIMARY KEY,
                id TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS chat (
                ROWID INTEGER PRIMARY KEY,
                chat_identifier TEXT,
                group_id TEXT
            );

            CREATE TABLE IF NOT EXISTS message (
                ROWID INTEGER PRIMARY KEY,
                text TEXT,
                attributedBody BLOB,
                date INTEGER DEFAULT 0,
                is_from_me INTEGER DEFAULT 0,
                handle_id INTEGER DEFAULT 0,
                cache_roomnames TEXT
            );

            CREATE TABLE IF NOT EXISTS chat_message_join (
                chat_id INTEGER,
                message_id INTEGER
            );

            CREATE TABLE IF NOT EXISTS chat_handle_join (
                chat_id INTEGER,
                handle_id INTEGER
            );

            -- Insert test handles
            INSERT INTO handle (ROWID, id) VALUES (1, '+15551234567');
            INSERT INTO handle (ROWID, id) VALUES (2, '+15559876543');
            INSERT INTO handle (ROWID, id) VALUES (3, '+15550001111');

            -- Insert test chats (chat 1 = direct, chat 2 = group)
            INSERT INTO chat (ROWID, chat_identifier, group_id) VALUES (1, '+15551234567', NULL);
            INSERT INTO chat (ROWID, chat_identifier, group_id) VALUES (2, 'chat000000000000000001', 'group-id-abc');

            -- Insert test messages (dates in nanoseconds since 2001-01-01)
            -- Message 1: incoming from handle 1, direct chat
            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (1, 'Hello Ember', 726926400000000000, 0, 1, NULL);

            -- Message 2: outgoing reply, direct chat
            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (2, 'Hi there!', 726926460000000000, 1, 1, NULL);

            -- Message 3: incoming from handle 2, direct chat
            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (3, 'Can you help me?', 726926520000000000, 0, 2, NULL);

            -- Message 4: group chat message
            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (4, 'Group message', 726926580000000000, 0, 3, 'chat000000000000000001');

            -- Link messages to chats
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 1);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 2);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 3);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (2, 4);

            -- Link handles to chats (group chat has multiple handles)
            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (1, 1);
            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (2, 2);
            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (2, 3);
            """

        sqlite3_exec(db, schema, nil, nil, nil)
    }
}
```

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. The database is NEVER opened in write mode (search for SQLITE_OPEN_READWRITE — it should not exist)
4. There are no calls to Process(), /bin/bash, or any shell execution
5. All public methods have documentation comments
6. os.Logger is used (not print() statements)
```

---

## Acceptance Criteria

- [ ] `src/Core/Models/ChatMessage.swift` exists with all specified properties
- [ ] `src/Core/Errors/ChatDatabaseError.swift` exists with all specified error cases
- [ ] `src/Core/ChatDatabaseReader.swift` exists with all specified methods
- [ ] Database is opened with `SQLITE_OPEN_READONLY` flag only
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution anywhere
- [ ] `fetchRecentMessages(limit:since:)` returns messages in chronological order
- [ ] `fetchMessages(forHandle:limit:)` filters by phone number/email
- [ ] `fetchMessagesSince(rowId:)` returns messages with ROWID > specified value
- [ ] `getMaxRowId()` returns the highest ROWID in the message table
- [ ] `isGroupChat(chatId:)` correctly detects group chats
- [ ] Apple nanosecond timestamp conversion handles both nanosecond and second formats
- [ ] `attributedBody` decoding handles macOS Ventura+ message format
- [ ] All unit tests pass with a mock test database
- [ ] `os.Logger` used for all logging (no `print()` statements)
- [ ] All public types and methods have documentation comments

---

## Verification Commands

```bash
# Build the project
cd /Users/robault/Documents/GitHub/emberhearth
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the ChatDatabaseReader tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/ChatDatabaseReaderTests 2>&1 | tail -30

# Verify no shell execution exists in the codebase
grep -rn "Process()" src/ || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/ || echo "PASS: No /bin/sh references found"
grep -rn "SQLITE_OPEN_READWRITE" src/ || echo "PASS: No READWRITE mode found"

# Verify read-only flag is present
grep -n "SQLITE_OPEN_READONLY" src/Core/ChatDatabaseReader.swift && echo "PASS: READONLY mode confirmed"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth chat.db reader implementation for correctness, security, and completeness. Open these files:

@src/Core/Models/ChatMessage.swift
@src/Core/Errors/ChatDatabaseError.swift
@src/Core/ChatDatabaseReader.swift
@tests/Core/ChatDatabaseReaderTests.swift

Also reference:
@docs/research/imessage.md
@docs/architecture/decisions/0004-no-shell-execution.md

Check for these specific issues:

1. **SECURITY (Critical):**
   - Is the database opened ONLY with SQLITE_OPEN_READONLY? No READWRITE anywhere?
   - Are there ANY calls to Process(), /bin/bash, /bin/sh, or NSTask?
   - Is SQL injection possible? (Parameters should use bind, not string interpolation for user input)
   - Can the database path be manipulated to access other databases?

2. **Correctness:**
   - Does the Apple timestamp conversion correctly handle both nanosecond (modern) and second (legacy) formats?
   - Does the attributedBody decoding work for macOS Ventura+ NSAttributedString blobs?
   - Is the group chat detection checking all three signals: cache_roomnames, group_id, and participant count?
   - Does fetchRecentMessages return results in chronological order (oldest first)?
   - Does fetchMessagesSince(rowId:) correctly use > (not >=) to avoid re-processing?

3. **Error Handling:**
   - Does it handle: database not found, database locked, schema mismatch?
   - Is the busy timeout set for locked database scenarios?
   - Are SQLite statement handles properly finalized in all code paths (including errors)?

4. **Testing:**
   - Does the test database schema match the real chat.db schema?
   - Are both direct message and group chat scenarios tested?
   - Is the date conversion tested with realistic values?
   - Are edge cases tested (nil text, empty database, nonexistent path)?

5. **Code Quality:**
   - Are all public APIs documented with /// comments?
   - Is os.Logger used consistently (no print statements)?
   - Are there any memory leaks (unclosed database connections, unfinalized statements)?
   - Is Sendable conformance appropriate on ChatMessage?

Report any issues found with specific file paths and line numbers. For each issue, indicate severity: CRITICAL (must fix), IMPORTANT (should fix), or MINOR (nice to have).
```

---

## Commit Message

```
feat(m2): add chat.db reader for iMessage integration
```

---

## Notes for Next Task

- `ChatDatabaseReader` is now available for use by `MessageWatcher` (task 0101).
- The `fetchMessagesSince(rowId:)` method is specifically designed for the watcher pattern.
- The `getMaxRowId()` method is used to initialize the watcher's starting position.
- The database path is configurable, so tests can use mock databases without touching the real chat.db.
- The `attributedBody` parsing is best-effort; if extraction fails for some messages, text will be nil. Future tasks may need to improve this.
- Group chat detection via `isGroupChat` on the ChatMessage model and `isGroupChat(chatId:)` on the reader can be used by the GroupChatDetector (task 0104).
