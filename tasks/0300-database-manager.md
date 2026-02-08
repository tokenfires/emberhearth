# Task 0300: SQLite Database Manager

**Milestone:** M4 - Memory System
**Unit:** 4.1 - SQLite Database Setup (memory.db)
**Phase:** 2
**Depends On:** 0204 (M3 complete)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions (PascalCase for Swift), security boundaries (Keychain for secrets, never store API keys in database), core principles
2. `docs/research/memory-learning.md` — Focus on Section 3: "Storage Architecture and Performance" (lines ~307-382) for schema design patterns, and Section 1: "Fact Taxonomy" (lines ~40-92) for category names
3. `docs/architecture-overview.md` — Focus on lines 181-200: "MemoryService.xpc" section for how the memory database fits into the architecture
4. `Package.swift` — Review the target structure (src path, tests path, exclude array) so you understand how to add files that compile

> **Context Budget Note:** memory-learning.md is 800+ lines. Focus only on Section 3 (storage schema, performance, SQLite considerations). Skip Section 4 (consolidation), Section 5 (temporal), and Section 6+ entirely. architecture-overview.md is 770+ lines; read only lines 181-200.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the SQLite database manager for EmberHearth, a native macOS personal AI assistant. This is the foundational data layer for the memory system — all facts, sessions, and messages will be stored here.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase (e.g., DatabaseManager.swift)
- Security first: NEVER store API keys or credentials in this database (they go in Keychain)
- NEVER implement shell execution
- All source files go under src/, all test files go under tests/

WHAT EXISTS (from prior tasks M1-M3):
- Package.swift at project root with executable target path "src" and test target path "tests"
- src/Database/DatabaseModule.swift (placeholder — leave it alone)
- src/App/, src/Core/, src/LLM/, src/Memory/, src/Views/, src/Logging/, src/Personality/, src/Security/ directories
- The project builds with `swift build`

YOU WILL CREATE:
1. src/Database/DatabaseManager.swift — Main database manager class
2. src/Database/DatabaseError.swift — Error types
3. tests/DatabaseManagerTests.swift — Comprehensive unit tests

STEP 1: Create src/Database/DatabaseError.swift

This file defines all database-related errors.

File: src/Database/DatabaseError.swift
```swift
// DatabaseError.swift
// EmberHearth
//
// Database error types for the memory storage system.

import Foundation

/// Errors that can occur during database operations.
enum DatabaseError: LocalizedError {
    /// The database file could not be found at the expected path.
    case databaseNotFound(path: String)

    /// Failed to create the database file or Application Support directory.
    case failedToCreate(reason: String)

    /// A schema migration failed to apply.
    case migrationFailed(fromVersion: Int, toVersion: Int, reason: String)

    /// A SQL query failed to execute.
    case queryFailed(sql: String, reason: String)

    /// The database file appears to be corrupt.
    case corruptDatabase(reason: String)

    /// A required parameter was missing or invalid.
    case invalidParameter(name: String, reason: String)

    /// The database connection is not open.
    case connectionClosed

    /// A backup operation failed.
    case backupFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .databaseNotFound(let path):
            return "Database not found at path: \(path)"
        case .failedToCreate(let reason):
            return "Failed to create database: \(reason)"
        case .migrationFailed(let from, let to, let reason):
            return "Migration from v\(from) to v\(to) failed: \(reason)"
        case .queryFailed(let sql, let reason):
            return "Query failed (\(sql)): \(reason)"
        case .corruptDatabase(let reason):
            return "Database appears corrupt: \(reason)"
        case .invalidParameter(let name, let reason):
            return "Invalid parameter '\(name)': \(reason)"
        case .connectionClosed:
            return "Database connection is not open"
        case .backupFailed(let reason):
            return "Backup failed: \(reason)"
        }
    }
}
```

STEP 2: Create src/Database/DatabaseManager.swift

This is the main database manager class. It uses the SQLite3 C API directly (import SQLite3) with NO third-party packages.

Key design decisions:
- Thread safety via a serial DispatchQueue — ALL database operations go through this queue
- WAL journal mode for better concurrent read performance
- Schema versioning with migrations
- The database lives at ~/Library/Application Support/EmberHearth/memory.db
- For unit tests, pass ":memory:" as the path to use an in-memory database

File: src/Database/DatabaseManager.swift
```swift
// DatabaseManager.swift
// EmberHearth
//
// Manages the SQLite database for memory storage.
// Uses the SQLite3 C API directly — no third-party dependencies.
// All operations are serialized through a DispatchQueue for thread safety.

import Foundation
import SQLite3

/// Manages the SQLite database for EmberHearth's memory system.
///
/// Usage:
/// ```swift
/// let db = try DatabaseManager()          // Production: ~/Library/Application Support/EmberHearth/memory.db
/// let db = try DatabaseManager(path: ":memory:")  // Testing: in-memory database
/// ```
final class DatabaseManager {

    // MARK: - Constants

    /// Current schema version. Increment this when adding migrations.
    static let currentSchemaVersion = 1

    /// Default database filename.
    static let defaultDatabaseFilename = "memory.db"

    /// Default backup filename.
    static let backupFilename = "memory.db.backup"

    /// Application Support subdirectory name.
    static let appSupportDirectoryName = "EmberHearth"

    // MARK: - Properties

    /// The file path of the database. ":memory:" for in-memory databases.
    let databasePath: String

    /// The raw SQLite3 database pointer. Access ONLY through the serialQueue.
    private var db: OpaquePointer?

    /// Serial queue for thread-safe database access.
    /// ALL database operations MUST be dispatched to this queue.
    private let serialQueue = DispatchQueue(label: "com.emberhearth.database", qos: .userInitiated)

    // MARK: - Initialization

    /// Creates a DatabaseManager with the default production path.
    /// The database is stored at ~/Library/Application Support/EmberHearth/memory.db.
    /// Creates the Application Support directory if it doesn't exist.
    ///
    /// - Throws: `DatabaseError.failedToCreate` if the directory or database can't be created.
    convenience init() throws {
        let path = try DatabaseManager.defaultDatabasePath()
        try self.init(path: path)
    }

    /// Creates a DatabaseManager with a custom path.
    /// Use ":memory:" for in-memory databases (unit testing).
    ///
    /// - Parameter path: The file path for the database, or ":memory:" for in-memory.
    /// - Throws: `DatabaseError` if the database can't be opened or initialized.
    init(path: String) throws {
        self.databasePath = path

        // If this is a file-based database (not in-memory), ensure the directory exists
        if path != ":memory:" {
            let directory = (path as NSString).deletingLastPathComponent
            try DatabaseManager.ensureDirectoryExists(at: directory)
        }

        // Open the database connection
        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &dbPointer, flags, nil)

        guard result == SQLITE_OK, let openedDb = dbPointer else {
            let errorMessage = dbPointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(dbPointer)
            throw DatabaseError.failedToCreate(reason: "Failed to open database: \(errorMessage)")
        }

        self.db = openedDb

        // Configure the database
        try configureDatabase()

        // Run schema migrations
        try migrateSchema()
    }

    deinit {
        close()
    }

    // MARK: - Database Configuration

    /// Configures database settings (WAL mode, foreign keys, etc.).
    private func configureDatabase() throws {
        // Enable WAL journal mode for better concurrent read performance
        try executeRaw(sql: "PRAGMA journal_mode = WAL")

        // Enable foreign key enforcement
        try executeRaw(sql: "PRAGMA foreign_keys = ON")

        // Set busy timeout to 5 seconds (prevents SQLITE_BUSY errors)
        try executeRaw(sql: "PRAGMA busy_timeout = 5000")
    }

    /// Executes a raw SQL statement without going through the serial queue.
    /// Used ONLY during initialization before the queue is needed.
    private func executeRaw(sql: String) throws {
        guard let db = db else {
            throw DatabaseError.connectionClosed
        }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.queryFailed(sql: sql, reason: message)
        }
    }

    // MARK: - Connection Management

    /// Closes the database connection.
    func close() {
        serialQueue.sync {
            if let db = db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    /// Returns true if the database connection is open.
    var isOpen: Bool {
        return serialQueue.sync { db != nil }
    }

    // MARK: - Schema Migration

    /// Checks the current schema version and runs any needed migrations.
    private func migrateSchema() throws {
        let currentVersion = try getCurrentSchemaVersion()

        if currentVersion == 0 {
            // Fresh database — create all tables
            try createInitialSchema()
            try setSchemaVersion(DatabaseManager.currentSchemaVersion)
        } else if currentVersion < DatabaseManager.currentSchemaVersion {
            // Run incremental migrations
            for version in (currentVersion + 1)...DatabaseManager.currentSchemaVersion {
                try runMigration(to: version)
                try setSchemaVersion(version)
            }
        }
        // If currentVersion == currentSchemaVersion, no migration needed
    }

    /// Gets the current schema version from the database.
    /// Returns 0 if the schema_version table doesn't exist (fresh database).
    private func getCurrentSchemaVersion() throws -> Int {
        guard let db = db else {
            throw DatabaseError.connectionClosed
        }

        // Check if the schema_version table exists
        let checkSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'"
        var checkStmt: OpaquePointer?
        defer { sqlite3_finalize(checkStmt) }

        guard sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(sql: checkSQL, reason: String(cString: sqlite3_errmsg(db)))
        }

        if sqlite3_step(checkStmt) != SQLITE_ROW {
            // Table doesn't exist — fresh database
            return 0
        }

        // Table exists, get the latest version
        let versionSQL = "SELECT MAX(version) FROM schema_version"
        var versionStmt: OpaquePointer?
        defer { sqlite3_finalize(versionStmt) }

        guard sqlite3_prepare_v2(db, versionSQL, -1, &versionStmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(sql: versionSQL, reason: String(cString: sqlite3_errmsg(db)))
        }

        if sqlite3_step(versionStmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(versionStmt, 0))
        }

        return 0
    }

    /// Sets the schema version in the database.
    private func setSchemaVersion(_ version: Int) throws {
        guard let db = db else {
            throw DatabaseError.connectionClosed
        }
        let sql = "INSERT INTO schema_version (version) VALUES (?)"
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
        }

        sqlite3_bind_int(stmt, 1, Int32(version))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
        }
    }

    /// Creates the initial database schema (version 1).
    private func createInitialSchema() throws {
        let statements = [
            // Schema version tracking
            """
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER NOT NULL,
                applied_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """,

            // Facts table — stores extracted and explicit user facts
            """
            CREATE TABLE IF NOT EXISTS facts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                content TEXT NOT NULL,
                category TEXT NOT NULL,
                source TEXT NOT NULL DEFAULT 'extracted',
                confidence REAL NOT NULL DEFAULT 0.8,
                created_at TEXT NOT NULL DEFAULT (datetime('now')),
                updated_at TEXT NOT NULL DEFAULT (datetime('now')),
                last_accessed TEXT,
                access_count INTEGER NOT NULL DEFAULT 0,
                importance REAL NOT NULL DEFAULT 0.5,
                is_deleted INTEGER NOT NULL DEFAULT 0
            )
            """,

            // Sessions table — tracks conversation sessions
            """
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                phone_number TEXT NOT NULL,
                started_at TEXT NOT NULL DEFAULT (datetime('now')),
                ended_at TEXT,
                summary TEXT,
                message_count INTEGER NOT NULL DEFAULT 0,
                is_active INTEGER NOT NULL DEFAULT 1
            )
            """,

            // Messages table — stores conversation messages
            """
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL DEFAULT (datetime('now')),
                token_count INTEGER,
                FOREIGN KEY (session_id) REFERENCES sessions(id)
            )
            """,

            // Indexes for common queries
            "CREATE INDEX IF NOT EXISTS idx_facts_category ON facts(category)",
            "CREATE INDEX IF NOT EXISTS idx_facts_is_deleted ON facts(is_deleted)",
            "CREATE INDEX IF NOT EXISTS idx_facts_content ON facts(content)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_phone_number ON sessions(phone_number)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_is_active ON sessions(is_active)",
            "CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id)",
            "CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)",
        ]

        for sql in statements {
            try executeRaw(sql: sql)
        }
    }

    /// Runs a specific migration to a target version.
    /// Add new cases here as the schema evolves.
    private func runMigration(to version: Int) throws {
        switch version {
        // Future migrations go here:
        // case 2:
        //     try migrationV2()
        default:
            throw DatabaseError.migrationFailed(
                fromVersion: version - 1,
                toVersion: version,
                reason: "No migration defined for version \(version)"
            )
        }
    }

    // MARK: - Query Execution (Thread-Safe)

    /// Executes a SQL statement that does not return rows (INSERT, UPDATE, DELETE, CREATE).
    /// All calls are dispatched to the serial queue for thread safety.
    ///
    /// - Parameters:
    ///   - sql: The SQL statement to execute. Use `?` for parameter placeholders.
    ///   - parameters: An array of values to bind to the `?` placeholders, in order.
    ///     Supported types: String, Int, Int64, Double, Bool, nil (for NULL).
    /// - Throws: `DatabaseError.queryFailed` if the statement fails.
    func execute(sql: String, parameters: [Any?] = []) throws {
        try serialQueue.sync {
            guard let db = db else {
                throw DatabaseError.connectionClosed
            }

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
            }

            try bindParameters(stmt: stmt!, parameters: parameters, db: db, sql: sql)

            let result = sqlite3_step(stmt)
            guard result == SQLITE_DONE else {
                throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    /// Executes a SQL INSERT and returns the last inserted row ID.
    ///
    /// - Parameters:
    ///   - sql: The INSERT SQL statement.
    ///   - parameters: Values to bind to `?` placeholders.
    /// - Returns: The row ID of the newly inserted row.
    /// - Throws: `DatabaseError.queryFailed` if the statement fails.
    func insertAndReturnId(sql: String, parameters: [Any?] = []) throws -> Int64 {
        return try serialQueue.sync {
            guard let db = db else {
                throw DatabaseError.connectionClosed
            }

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
            }

            try bindParameters(stmt: stmt!, parameters: parameters, db: db, sql: sql)

            let result = sqlite3_step(stmt)
            guard result == SQLITE_DONE else {
                throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
            }

            return sqlite3_last_insert_rowid(db)
        }
    }

    /// Executes a SQL query and returns rows as an array of dictionaries.
    /// Each dictionary maps column names to their values.
    ///
    /// - Parameters:
    ///   - sql: The SELECT SQL statement.
    ///   - parameters: Values to bind to `?` placeholders.
    /// - Returns: An array of rows, where each row is a `[String: Any?]` dictionary.
    /// - Throws: `DatabaseError.queryFailed` if the statement fails.
    func query(sql: String, parameters: [Any?] = []) throws -> [[String: Any?]] {
        return try serialQueue.sync {
            guard let db = db else {
                throw DatabaseError.connectionClosed
            }

            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                throw DatabaseError.queryFailed(sql: sql, reason: String(cString: sqlite3_errmsg(db)))
            }

            try bindParameters(stmt: stmt!, parameters: parameters, db: db, sql: sql)

            var rows: [[String: Any?]] = []
            let columnCount = sqlite3_column_count(stmt)

            while sqlite3_step(stmt) == SQLITE_ROW {
                var row: [String: Any?] = [:]
                for i in 0..<columnCount {
                    let columnName = String(cString: sqlite3_column_name(stmt, i))
                    let columnType = sqlite3_column_type(stmt, i)

                    switch columnType {
                    case SQLITE_INTEGER:
                        row[columnName] = sqlite3_column_int64(stmt, i)
                    case SQLITE_FLOAT:
                        row[columnName] = sqlite3_column_double(stmt, i)
                    case SQLITE_TEXT:
                        row[columnName] = String(cString: sqlite3_column_text(stmt, i))
                    case SQLITE_BLOB:
                        let bytes = sqlite3_column_bytes(stmt, i)
                        if let blob = sqlite3_column_blob(stmt, i) {
                            row[columnName] = Data(bytes: blob, count: Int(bytes))
                        } else {
                            row[columnName] = nil as Any?
                        }
                    case SQLITE_NULL:
                        row[columnName] = nil as Any?
                    default:
                        row[columnName] = nil as Any?
                    }
                }
                rows.append(row)
            }

            return rows
        }
    }

    /// Executes a SQL query and returns a single scalar value.
    /// Useful for COUNT(*), MAX(), etc.
    ///
    /// - Parameters:
    ///   - sql: The SELECT SQL statement that returns one row, one column.
    ///   - parameters: Values to bind to `?` placeholders.
    /// - Returns: The value, or nil if no rows were returned.
    /// - Throws: `DatabaseError.queryFailed` if the statement fails.
    func queryScalar(sql: String, parameters: [Any?] = []) throws -> Any? {
        let rows = try query(sql: sql, parameters: parameters)
        guard let firstRow = rows.first, let firstValue = firstRow.values.first else {
            return nil
        }
        return firstValue
    }

    /// Executes multiple SQL statements inside a transaction.
    /// If any statement fails, the entire transaction is rolled back.
    ///
    /// - Parameter block: A closure that performs database operations.
    /// - Throws: Re-throws any error from the block after rolling back.
    func transaction(_ block: () throws -> Void) throws {
        try execute(sql: "BEGIN TRANSACTION")
        do {
            try block()
            try execute(sql: "COMMIT")
        } catch {
            try? execute(sql: "ROLLBACK")
            throw error
        }
    }

    // MARK: - Parameter Binding

    /// Binds parameters to a prepared statement.
    private func bindParameters(stmt: OpaquePointer, parameters: [Any?], db: OpaquePointer, sql: String) throws {
        for (index, param) in parameters.enumerated() {
            let sqlIndex = Int32(index + 1) // SQLite parameters are 1-indexed

            let bindResult: Int32
            if param == nil {
                bindResult = sqlite3_bind_null(stmt, sqlIndex)
            } else if let stringValue = param as? String {
                bindResult = sqlite3_bind_text(stmt, sqlIndex, (stringValue as NSString).utf8String, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            } else if let intValue = param as? Int {
                bindResult = sqlite3_bind_int64(stmt, sqlIndex, Int64(intValue))
            } else if let int64Value = param as? Int64 {
                bindResult = sqlite3_bind_int64(stmt, sqlIndex, int64Value)
            } else if let doubleValue = param as? Double {
                bindResult = sqlite3_bind_double(stmt, sqlIndex, doubleValue)
            } else if let boolValue = param as? Bool {
                bindResult = sqlite3_bind_int(stmt, sqlIndex, boolValue ? 1 : 0)
            } else if let int32Value = param as? Int32 {
                bindResult = sqlite3_bind_int(stmt, sqlIndex, int32Value)
            } else {
                throw DatabaseError.invalidParameter(
                    name: "parameter[\(index)]",
                    reason: "Unsupported type: \(type(of: param!))"
                )
            }

            guard bindResult == SQLITE_OK else {
                throw DatabaseError.queryFailed(
                    sql: sql,
                    reason: "Failed to bind parameter \(index + 1): \(String(cString: sqlite3_errmsg(db)))"
                )
            }
        }
    }

    // MARK: - Backup

    /// Creates a backup of the database file.
    /// Copies memory.db to memory.db.backup in the same directory.
    /// This is a no-op for in-memory databases.
    ///
    /// - Throws: `DatabaseError.backupFailed` if the copy fails.
    func backup() throws {
        guard databasePath != ":memory:" else {
            return // No backup for in-memory databases
        }

        let backupPath = (databasePath as NSString)
            .deletingLastPathComponent
            .appending("/\(DatabaseManager.backupFilename)")

        // Checkpoint WAL to ensure all data is in the main database file
        try serialQueue.sync {
            guard let db = db else {
                throw DatabaseError.connectionClosed
            }
            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, &errorMessage)
            if result != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)
                throw DatabaseError.backupFailed(reason: "WAL checkpoint failed: \(message)")
            }
        }

        let fileManager = FileManager.default

        // Remove existing backup if present
        if fileManager.fileExists(atPath: backupPath) {
            do {
                try fileManager.removeItem(atPath: backupPath)
            } catch {
                throw DatabaseError.backupFailed(reason: "Failed to remove existing backup: \(error.localizedDescription)")
            }
        }

        // Copy the database file
        do {
            try fileManager.copyItem(atPath: databasePath, toPath: backupPath)
        } catch {
            throw DatabaseError.backupFailed(reason: "Failed to copy database: \(error.localizedDescription)")
        }
    }

    // MARK: - Utility

    /// Returns the default database path: ~/Library/Application Support/EmberHearth/memory.db
    static func defaultDatabasePath() throws -> String {
        guard let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DatabaseError.failedToCreate(reason: "Could not locate Application Support directory")
        }

        let emberHearthDir = appSupportURL.appendingPathComponent(appSupportDirectoryName)
        return emberHearthDir.appendingPathComponent(defaultDatabaseFilename).path
    }

    /// Ensures a directory exists, creating it if necessary.
    private static func ensureDirectoryExists(at path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw DatabaseError.failedToCreate(reason: "Path exists but is not a directory: \(path)")
            }
            return // Directory already exists
        }

        do {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw DatabaseError.failedToCreate(reason: "Failed to create directory: \(error.localizedDescription)")
        }
    }

    /// Returns the number of rows affected by the last INSERT, UPDATE, or DELETE.
    func lastChangesCount() -> Int {
        return serialQueue.sync {
            guard let db = db else { return 0 }
            return Int(sqlite3_changes(db))
        }
    }
}
```

STEP 3: Create tests/DatabaseManagerTests.swift

These tests use in-memory databases (":memory:") so they don't touch the filesystem.

File: tests/DatabaseManagerTests.swift
```swift
// DatabaseManagerTests.swift
// EmberHearth
//
// Unit tests for DatabaseManager.

import XCTest
@testable import EmberHearth

final class DatabaseManagerTests: XCTestCase {

    // MARK: - Setup

    /// Creates a fresh in-memory DatabaseManager for each test.
    private func makeManager() throws -> DatabaseManager {
        return try DatabaseManager(path: ":memory:")
    }

    // MARK: - Initialization Tests

    func testInitializationCreatesAllTables() throws {
        let manager = try makeManager()

        // Verify facts table exists
        let factsResult = try manager.query(
            sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='facts'"
        )
        XCTAssertEqual(factsResult.count, 1, "facts table should exist")

        // Verify sessions table exists
        let sessionsResult = try manager.query(
            sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'"
        )
        XCTAssertEqual(sessionsResult.count, 1, "sessions table should exist")

        // Verify messages table exists
        let messagesResult = try manager.query(
            sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='messages'"
        )
        XCTAssertEqual(messagesResult.count, 1, "messages table should exist")

        // Verify schema_version table exists
        let schemaResult = try manager.query(
            sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'"
        )
        XCTAssertEqual(schemaResult.count, 1, "schema_version table should exist")
    }

    func testSchemaVersionIsSet() throws {
        let manager = try makeManager()

        let result = try manager.query(sql: "SELECT MAX(version) as version FROM schema_version")
        XCTAssertEqual(result.count, 1)

        let version = result[0]["version"] as? Int64
        XCTAssertEqual(version, Int64(DatabaseManager.currentSchemaVersion))
    }

    func testWALModeEnabled() throws {
        let manager = try makeManager()

        let result = try manager.query(sql: "PRAGMA journal_mode")
        XCTAssertEqual(result.count, 1)

        // In-memory databases may report "memory" instead of "wal"
        let journalMode = result[0]["journal_mode"] as? String
        XCTAssertTrue(
            journalMode == "wal" || journalMode == "memory",
            "Journal mode should be WAL (or memory for in-memory databases)"
        )
    }

    func testForeignKeysEnabled() throws {
        let manager = try makeManager()

        let result = try manager.query(sql: "PRAGMA foreign_keys")
        let fkEnabled = result[0]["foreign_keys"] as? Int64
        XCTAssertEqual(fkEnabled, 1, "Foreign keys should be enabled")
    }

    func testMultipleInitializationsAreSafe() throws {
        // Opening the same in-memory database twice should not fail
        // (each ":memory:" is independent)
        let manager1 = try makeManager()
        let manager2 = try makeManager()

        XCTAssertTrue(manager1.isOpen)
        XCTAssertTrue(manager2.isOpen)
    }

    // MARK: - Execute Tests

    func testInsertAndQuery() throws {
        let manager = try makeManager()

        try manager.execute(
            sql: """
                INSERT INTO facts (content, category, source, confidence, importance)
                VALUES (?, ?, ?, ?, ?)
                """,
            parameters: ["User likes coffee", "preference", "extracted", 0.9, 0.5]
        )

        let results = try manager.query(sql: "SELECT * FROM facts WHERE content = ?", parameters: ["User likes coffee"])
        XCTAssertEqual(results.count, 1)

        let row = results[0]
        XCTAssertEqual(row["content"] as? String, "User likes coffee")
        XCTAssertEqual(row["category"] as? String, "preference")
        XCTAssertEqual(row["source"] as? String, "extracted")
        XCTAssertEqual(row["confidence"] as? Double, 0.9)
        XCTAssertEqual(row["importance"] as? Double, 0.5)
        XCTAssertEqual(row["is_deleted"] as? Int64, 0)
        XCTAssertEqual(row["access_count"] as? Int64, 0)
    }

    func testInsertAndReturnId() throws {
        let manager = try makeManager()

        let id1 = try manager.insertAndReturnId(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Fact one", "preference"]
        )

        let id2 = try manager.insertAndReturnId(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Fact two", "biographical"]
        )

        XCTAssertEqual(id1, 1)
        XCTAssertEqual(id2, 2)
    }

    func testUpdateQuery() throws {
        let manager = try makeManager()

        try manager.execute(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["User likes tea", "preference"]
        )

        try manager.execute(
            sql: "UPDATE facts SET content = ?, updated_at = datetime('now') WHERE content = ?",
            parameters: ["User loves tea", "User likes tea"]
        )

        let results = try manager.query(sql: "SELECT content FROM facts")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["content"] as? String, "User loves tea")
    }

    func testDeleteQuery() throws {
        let manager = try makeManager()

        try manager.execute(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Temporary fact", "contextual"]
        )

        try manager.execute(
            sql: "DELETE FROM facts WHERE content = ?",
            parameters: ["Temporary fact"]
        )

        let results = try manager.query(sql: "SELECT * FROM facts")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Query Scalar Tests

    func testQueryScalar() throws {
        let manager = try makeManager()

        try manager.execute(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Fact A", "preference"]
        )
        try manager.execute(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Fact B", "biographical"]
        )

        let count = try manager.queryScalar(sql: "SELECT COUNT(*) FROM facts")
        XCTAssertEqual(count as? Int64, 2)
    }

    func testQueryScalarReturnsNilForEmptyResult() throws {
        let manager = try makeManager()

        let result = try manager.queryScalar(sql: "SELECT id FROM facts WHERE id = 999")
        XCTAssertNil(result as Any?)
    }

    // MARK: - Transaction Tests

    func testTransactionCommits() throws {
        let manager = try makeManager()

        try manager.transaction {
            try manager.execute(
                sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
                parameters: ["Transaction fact 1", "preference"]
            )
            try manager.execute(
                sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
                parameters: ["Transaction fact 2", "preference"]
            )
        }

        let count = try manager.queryScalar(sql: "SELECT COUNT(*) FROM facts") as? Int64
        XCTAssertEqual(count, 2)
    }

    func testTransactionRollsBackOnError() throws {
        let manager = try makeManager()

        // Insert one fact outside the transaction
        try manager.execute(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Existing fact", "preference"]
        )

        do {
            try manager.transaction {
                try manager.execute(
                    sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
                    parameters: ["Will be rolled back", "preference"]
                )
                // This should fail (invalid table name)
                try manager.execute(sql: "INSERT INTO nonexistent_table VALUES (?)", parameters: ["fail"])
            }
            XCTFail("Transaction should have thrown an error")
        } catch {
            // Expected — transaction rolled back
        }

        // Only the pre-transaction fact should remain
        let count = try manager.queryScalar(sql: "SELECT COUNT(*) FROM facts") as? Int64
        XCTAssertEqual(count, 1)
    }

    // MARK: - Parameter Binding Tests

    func testNullParameterBinding() throws {
        let manager = try makeManager()

        let id = try manager.insertAndReturnId(
            sql: "INSERT INTO sessions (phone_number, summary) VALUES (?, ?)",
            parameters: ["+15551234567", nil]
        )

        let results = try manager.query(sql: "SELECT summary FROM sessions WHERE id = ?", parameters: [id])
        XCTAssertEqual(results.count, 1)
        // summary should be nil/NULL
        let summary = results[0]["summary"]
        XCTAssertTrue(summary is NSNull || summary == nil, "Summary should be NULL")
    }

    func testBoolParameterBinding() throws {
        let manager = try makeManager()

        try manager.execute(
            sql: "INSERT INTO facts (content, category, is_deleted) VALUES (?, ?, ?)",
            parameters: ["Deleted fact", "preference", true]
        )

        let results = try manager.query(
            sql: "SELECT is_deleted FROM facts WHERE content = ?",
            parameters: ["Deleted fact"]
        )
        XCTAssertEqual(results[0]["is_deleted"] as? Int64, 1)
    }

    // MARK: - Foreign Key Tests

    func testForeignKeyConstraint() throws {
        let manager = try makeManager()

        // Inserting a message with a non-existent session_id should fail
        // because foreign keys are enabled
        XCTAssertThrowsError(try manager.execute(
            sql: "INSERT INTO messages (session_id, role, content) VALUES (?, ?, ?)",
            parameters: [999, "user", "Hello"]
        ))
    }

    // MARK: - Sessions and Messages Table Tests

    func testSessionInsertAndQuery() throws {
        let manager = try makeManager()

        let sessionId = try manager.insertAndReturnId(
            sql: "INSERT INTO sessions (phone_number) VALUES (?)",
            parameters: ["+15551234567"]
        )

        let results = try manager.query(
            sql: "SELECT * FROM sessions WHERE id = ?",
            parameters: [sessionId]
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["phone_number"] as? String, "+15551234567")
        XCTAssertEqual(results[0]["is_active"] as? Int64, 1)
        XCTAssertEqual(results[0]["message_count"] as? Int64, 0)
    }

    func testMessageInsertWithForeignKey() throws {
        let manager = try makeManager()

        // First create a session
        let sessionId = try manager.insertAndReturnId(
            sql: "INSERT INTO sessions (phone_number) VALUES (?)",
            parameters: ["+15551234567"]
        )

        // Then insert a message linked to that session
        let messageId = try manager.insertAndReturnId(
            sql: "INSERT INTO messages (session_id, role, content) VALUES (?, ?, ?)",
            parameters: [sessionId, "user", "Hello Ember"]
        )

        let results = try manager.query(
            sql: "SELECT * FROM messages WHERE id = ?",
            parameters: [messageId]
        )
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["role"] as? String, "user")
        XCTAssertEqual(results[0]["content"] as? String, "Hello Ember")
        XCTAssertEqual(results[0]["session_id"] as? Int64, sessionId)
    }

    // MARK: - Connection Tests

    func testCloseAndReopen() throws {
        let manager = try makeManager()
        XCTAssertTrue(manager.isOpen)

        manager.close()
        XCTAssertFalse(manager.isOpen)
    }

    func testOperationAfterCloseThrows() throws {
        let manager = try makeManager()
        manager.close()

        XCTAssertThrowsError(try manager.execute(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Should fail", "preference"]
        ))
    }

    // MARK: - Backup Tests (in-memory is a no-op)

    func testBackupInMemoryIsNoOp() throws {
        let manager = try makeManager()

        // backup() on an in-memory database should not throw
        XCTAssertNoThrow(try manager.backup())
    }

    // MARK: - Schema Defaults Tests

    func testFactsTableDefaults() throws {
        let manager = try makeManager()

        // Insert with only required fields
        let id = try manager.insertAndReturnId(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: ["Minimal fact", "preference"]
        )

        let results = try manager.query(sql: "SELECT * FROM facts WHERE id = ?", parameters: [id])
        let row = results[0]

        XCTAssertEqual(row["source"] as? String, "extracted", "Default source should be 'extracted'")
        XCTAssertEqual(row["confidence"] as? Double, 0.8, "Default confidence should be 0.8")
        XCTAssertEqual(row["access_count"] as? Int64, 0, "Default access_count should be 0")
        XCTAssertEqual(row["importance"] as? Double, 0.5, "Default importance should be 0.5")
        XCTAssertEqual(row["is_deleted"] as? Int64, 0, "Default is_deleted should be 0")
        XCTAssertNotNil(row["created_at"] as? String, "created_at should be auto-populated")
        XCTAssertNotNil(row["updated_at"] as? String, "updated_at should be auto-populated")
    }

    // MARK: - Index Tests

    func testIndexesExist() throws {
        let manager = try makeManager()

        let results = try manager.query(
            sql: "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'"
        )

        let indexNames = results.compactMap { $0["name"] as? String }
        XCTAssertTrue(indexNames.contains("idx_facts_category"))
        XCTAssertTrue(indexNames.contains("idx_facts_is_deleted"))
        XCTAssertTrue(indexNames.contains("idx_sessions_phone_number"))
        XCTAssertTrue(indexNames.contains("idx_sessions_is_active"))
        XCTAssertTrue(indexNames.contains("idx_messages_session_id"))
        XCTAssertTrue(indexNames.contains("idx_messages_timestamp"))
    }

    // MARK: - Special Characters Tests

    func testSpecialCharactersInContent() throws {
        let manager = try makeManager()

        let specialContent = "User's name is O'Brien & they \"love\" emojis 🔥 — also: SELECT * FROM users"
        let id = try manager.insertAndReturnId(
            sql: "INSERT INTO facts (content, category) VALUES (?, ?)",
            parameters: [specialContent, "biographical"]
        )

        let results = try manager.query(sql: "SELECT content FROM facts WHERE id = ?", parameters: [id])
        XCTAssertEqual(results[0]["content"] as? String, specialContent)
    }
}
```

STEP 4: Verify the build

After creating all files, run these commands from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. If the build fails, debug the issue. Common problems:
- Import SQLite3 not found: This should work on macOS as SQLite3 is included in the system
- SQLITE_TRANSIENT vs unsafeBitCast: The parameter binding for strings uses `unsafeBitCast(-1, to: sqlite3_destructor_type.self)` which is equivalent to SQLITE_TRANSIENT. If the compiler complains, replace with: `{ _ in }` as the destructor (but note this is a different semantic — the unsafeBitCast approach tells SQLite to make its own copy of the string)
- Thread safety: The serialQueue.sync calls may cause issues if called from the same queue. The transaction() method calls execute() which also uses serialQueue.sync. This is safe because DispatchQueue.sync is reentrant when called from the same queue on the same thread — but ONLY for serial queues.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify any existing files except those specified.
- Do NOT add any third-party SQLite wrapper packages.
- The SQLite3 framework is available on macOS by default via `import SQLite3`.
- NEVER store API keys or credentials in this database. They belong in Keychain.
- The `:memory:` path creates an in-memory database that exists only for the lifetime of the connection.
- All SQL uses parameterized queries (? placeholders) to prevent SQL injection.
```

---

## Acceptance Criteria

- [ ] `src/Database/DatabaseManager.swift` exists and compiles
- [ ] `src/Database/DatabaseError.swift` exists with all 8 error cases
- [ ] Uses `import SQLite3` (C API) — NO third-party packages
- [ ] Database is created at `~/Library/Application Support/EmberHearth/memory.db` for production
- [ ] Application Support directory is created if it doesn't exist
- [ ] WAL journal mode is enabled
- [ ] Foreign keys are enabled
- [ ] All 4 tables are created: `facts`, `sessions`, `messages`, `schema_version`
- [ ] Schema versioning works (checks version, runs migrations)
- [ ] `currentSchemaVersion` constant is set to `1`
- [ ] Thread safety via serial DispatchQueue for ALL database operations
- [ ] `execute()`, `insertAndReturnId()`, `query()`, `queryScalar()` helpers work
- [ ] `transaction()` method commits on success and rolls back on failure
- [ ] `backup()` method copies database file (no-op for in-memory)
- [ ] `close()` properly closes the connection
- [ ] All unit tests pass using in-memory database
- [ ] `facts` table has correct columns: id, content, category, source, confidence, created_at, updated_at, last_accessed, access_count, importance, is_deleted
- [ ] `sessions` table has correct columns: id, phone_number, started_at, ended_at, summary, message_count, is_active
- [ ] `messages` table has correct columns: id, session_id, role, content, timestamp, token_count
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Database/DatabaseManager.swift && echo "DatabaseManager.swift exists" || echo "MISSING: DatabaseManager.swift"
test -f src/Database/DatabaseError.swift && echo "DatabaseError.swift exists" || echo "MISSING: DatabaseError.swift"
test -f tests/DatabaseManagerTests.swift && echo "DatabaseManagerTests.swift exists" || echo "MISSING: DatabaseManagerTests.swift"

# Verify no third-party SQLite packages in Package.swift
grep -c "sqlite" Package.swift || echo "No third-party SQLite packages (correct)"

# Verify import SQLite3 is used
grep "import SQLite3" src/Database/DatabaseManager.swift

# Verify thread safety (serial queue)
grep "serialQueue" src/Database/DatabaseManager.swift

# Verify WAL mode
grep "journal_mode = WAL" src/Database/DatabaseManager.swift

# Verify schema version constant
grep "currentSchemaVersion = 1" src/Database/DatabaseManager.swift

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the SQLite DatabaseManager created in task 0300 for EmberHearth. Check for these common issues:

1. SQLITE3 C API USAGE:
   - Verify `import SQLite3` is used (not a third-party wrapper)
   - Verify all sqlite3_* function calls have proper error checking
   - Verify sqlite3_finalize is called on ALL prepared statements (check for defer)
   - Verify sqlite3_close is called in deinit or close()
   - Verify string binding uses SQLITE_TRANSIENT semantics (SQLite must copy strings)

2. THREAD SAFETY:
   - ALL public methods that access `db` must go through `serialQueue.sync`
   - The `configureDatabase()` and `migrateSchema()` calls in init happen BEFORE the queue is needed (init is single-threaded) — verify this is safe
   - The `transaction()` method calls `execute()` which uses serialQueue.sync — verify this doesn't deadlock. On macOS, calling sync on a serial queue from the same queue on the same thread IS reentrant and won't deadlock (this is a documented behavior of GCD)
   - Verify `db` property is private and only accessed through the queue

3. SCHEMA CORRECTNESS:
   - Verify the facts table has ALL columns: id, content, category, source, confidence, created_at, updated_at, last_accessed, access_count, importance, is_deleted
   - Verify the sessions table has ALL columns: id, phone_number, started_at, ended_at, summary, message_count, is_active
   - Verify the messages table has ALL columns: id, session_id, role, content, timestamp, token_count
   - Verify the messages table has a FOREIGN KEY to sessions(id)
   - Verify schema_version table exists with version and applied_at columns
   - Verify all DEFAULT values match the specification
   - Verify category column accepts: preference, relationship, biographical, event, opinion, contextual, secret
   - Verify source column accepts: extracted, explicit
   - Verify role column accepts: user, assistant

4. WAL AND FOREIGN KEYS:
   - Verify PRAGMA journal_mode = WAL is executed
   - Verify PRAGMA foreign_keys = ON is executed
   - Verify the foreign key constraint on messages.session_id actually works (check test)

5. MIGRATION SYSTEM:
   - Verify getCurrentSchemaVersion() handles fresh databases (no schema_version table)
   - Verify it creates all tables on first run
   - Verify it records the version in schema_version
   - Verify the migration path handles version 0 → currentSchemaVersion
   - Verify future migrations can be added as new cases in runMigration()

6. BACKUP METHOD:
   - Verify backup() checkpoints WAL before copying
   - Verify it handles in-memory databases gracefully
   - Verify it removes existing backup before creating new one

7. SECURITY:
   - Verify NO API keys, tokens, or credentials are stored or referenced
   - Verify all queries use parameterized SQL (? placeholders)
   - Verify no string interpolation is used in SQL queries

8. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test` and verify all DatabaseManagerTests pass
   - Check that no warnings appear

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m4): add SQLite database manager for memory storage
```

---

## Notes for Next Task

- DatabaseManager is now available at `src/Database/DatabaseManager.swift`. Task 0301 (FactStore) will use it for all database operations via the `execute()`, `insertAndReturnId()`, and `query()` methods.
- The facts table schema is fixed: id, content, category, source, confidence, created_at, updated_at, last_accessed, access_count, importance, is_deleted. Task 0301 must map its Fact model to these exact columns.
- The `category` column stores raw strings matching the FactCategory enum: "preference", "relationship", "biographical", "event", "opinion", "contextual", "secret". Task 0301 should define this enum in Fact.swift.
- The `source` column stores "extracted" or "explicit". Task 0301 should define a FactSource enum.
- For unit tests, always use `DatabaseManager(path: ":memory:")` to avoid filesystem side effects.
- The `insertAndReturnId()` method returns `Int64`, which maps to the `id` column type. Task 0301's Fact model should use `Int64` for its `id` property.
- The `transaction()` method is available for batch operations. Task 0301 may use it when inserting multiple facts at once.
