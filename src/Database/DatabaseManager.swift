// DatabaseManager.swift
// EmberHearth
//
// Manages the SQLite database for memory storage.
// Uses the SQLite3 C API directly — no third-party dependencies.
// All operations are serialized through a DispatchQueue for thread safety.

import Foundation
import SQLite3

final class DatabaseManager {

    static let currentSchemaVersion = 1
    static let defaultDatabaseFilename = "memory.db"
    static let backupFilename = "memory.db.backup"
    static let appSupportDirectoryName = "EmberHearth"

    let databasePath: String
    private var db: OpaquePointer?
    private let serialQueue = DispatchQueue(label: "com.emberhearth.database", qos: .userInitiated)

    convenience init() throws {
        let path = try DatabaseManager.defaultDatabasePath()
        try self.init(path: path)
    }

    init(path: String) throws {
        self.databasePath = path

        if path != ":memory:" {
            let directory = (path as NSString).deletingLastPathComponent
            try DatabaseManager.ensureDirectoryExists(at: directory)
        }

        var dbPointer: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(path, &dbPointer, flags, nil)

        guard result == SQLITE_OK, let openedDb = dbPointer else {
            let errorMessage = dbPointer.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown error"
            sqlite3_close(dbPointer)
            throw DatabaseError.failedToCreate(reason: "Failed to open database: \(errorMessage)")
        }

        self.db = openedDb
        try configureDatabase()
        try migrateSchema()
    }

    deinit {
        close()
    }

    private func configureDatabase() throws {
        try executeRaw(sql: "PRAGMA journal_mode = WAL")
        try executeRaw(sql: "PRAGMA foreign_keys = ON")
        try executeRaw(sql: "PRAGMA busy_timeout = 5000")
    }

    private func executeRaw(sql: String) throws {
        guard let db = db else { throw DatabaseError.connectionClosed }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(db, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
            sqlite3_free(errorMessage)
            throw DatabaseError.queryFailed(sql: sql, reason: message)
        }
    }

    func close() {
        serialQueue.sync {
            if let db = db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    var isOpen: Bool {
        return serialQueue.sync { db != nil }
    }

    private func migrateSchema() throws {
        let currentVersion = try getCurrentSchemaVersion()
        if currentVersion == 0 {
            try createInitialSchema()
            try setSchemaVersion(DatabaseManager.currentSchemaVersion)
        } else if currentVersion < DatabaseManager.currentSchemaVersion {
            for version in (currentVersion + 1)...DatabaseManager.currentSchemaVersion {
                try runMigration(to: version)
                try setSchemaVersion(version)
            }
        }
    }

    private func getCurrentSchemaVersion() throws -> Int {
        guard let db = db else { throw DatabaseError.connectionClosed }

        let checkSQL = "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'"
        var checkStmt: OpaquePointer?
        defer { sqlite3_finalize(checkStmt) }

        guard sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK else {
            throw DatabaseError.queryFailed(sql: checkSQL, reason: String(cString: sqlite3_errmsg(db)))
        }

        if sqlite3_step(checkStmt) != SQLITE_ROW { return 0 }

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

    private func setSchemaVersion(_ version: Int) throws {
        guard let db = db else { throw DatabaseError.connectionClosed }
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

    private func createInitialSchema() throws {
        let statements = [
            """
            CREATE TABLE IF NOT EXISTS schema_version (
                version INTEGER NOT NULL,
                applied_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
            """,
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
            "CREATE INDEX IF NOT EXISTS idx_facts_category ON facts(category)",
            "CREATE INDEX IF NOT EXISTS idx_facts_is_deleted ON facts(is_deleted)",
            "CREATE INDEX IF NOT EXISTS idx_facts_content ON facts(content)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_phone_number ON sessions(phone_number)",
            "CREATE INDEX IF NOT EXISTS idx_sessions_is_active ON sessions(is_active)",
            "CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id)",
            "CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)",
        ]
        for sql in statements { try executeRaw(sql: sql) }
    }

    private func runMigration(to version: Int) throws {
        throw DatabaseError.migrationFailed(
            fromVersion: version - 1,
            toVersion: version,
            reason: "No migration defined for version \(version)"
        )
    }

    func execute(sql: String, parameters: [Any?] = []) throws {
        try serialQueue.sync {
            guard let db = db else { throw DatabaseError.connectionClosed }
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

    func insertAndReturnId(sql: String, parameters: [Any?] = []) throws -> Int64 {
        return try serialQueue.sync {
            guard let db = db else { throw DatabaseError.connectionClosed }
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

    func query(sql: String, parameters: [Any?] = []) throws -> [[String: Any?]] {
        return try serialQueue.sync {
            guard let db = db else { throw DatabaseError.connectionClosed }
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
                    case SQLITE_INTEGER: row[columnName] = sqlite3_column_int64(stmt, i)
                    case SQLITE_FLOAT: row[columnName] = sqlite3_column_double(stmt, i)
                    case SQLITE_TEXT: row[columnName] = String(cString: sqlite3_column_text(stmt, i))
                    case SQLITE_BLOB:
                        let bytes = sqlite3_column_bytes(stmt, i)
                        if let blob = sqlite3_column_blob(stmt, i) {
                            row[columnName] = Data(bytes: blob, count: Int(bytes))
                        } else { row[columnName] = nil as Any? }
                    case SQLITE_NULL: row[columnName] = nil as Any?
                    default: row[columnName] = nil as Any?
                    }
                }
                rows.append(row)
            }
            return rows
        }
    }

    func queryScalar(sql: String, parameters: [Any?] = []) throws -> Any? {
        let rows = try query(sql: sql, parameters: parameters)
        guard let firstRow = rows.first, let firstValue = firstRow.values.first else { return nil }
        return firstValue
    }

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

    private func bindParameters(stmt: OpaquePointer, parameters: [Any?], db: OpaquePointer, sql: String) throws {
        for (index, param) in parameters.enumerated() {
            let sqlIndex = Int32(index + 1)
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
                throw DatabaseError.invalidParameter(name: "parameter[\(index)]", reason: "Unsupported type: \(type(of: param!))")
            }
            guard bindResult == SQLITE_OK else {
                throw DatabaseError.queryFailed(sql: sql, reason: "Failed to bind parameter \(index + 1): \(String(cString: sqlite3_errmsg(db)))")
            }
        }
    }

    func backup() throws {
        guard databasePath != ":memory:" else { return }
        let backupPath = (databasePath as NSString).deletingLastPathComponent.appending("/\(DatabaseManager.backupFilename)")

        try serialQueue.sync {
            guard let db = db else { throw DatabaseError.connectionClosed }
            var errorMessage: UnsafeMutablePointer<CChar>?
            let result = sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE)", nil, nil, &errorMessage)
            if result != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "Unknown error"
                sqlite3_free(errorMessage)
                throw DatabaseError.backupFailed(reason: "WAL checkpoint failed: \(message)")
            }
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: backupPath) {
            do { try fileManager.removeItem(atPath: backupPath) } catch {
                throw DatabaseError.backupFailed(reason: "Failed to remove existing backup: \(error.localizedDescription)")
            }
        }
        do { try fileManager.copyItem(atPath: databasePath, toPath: backupPath) } catch {
            throw DatabaseError.backupFailed(reason: "Failed to copy database: \(error.localizedDescription)")
        }
    }

    static func defaultDatabasePath() throws -> String {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw DatabaseError.failedToCreate(reason: "Could not locate Application Support directory")
        }
        let emberHearthDir = appSupportURL.appendingPathComponent(appSupportDirectoryName)
        return emberHearthDir.appendingPathComponent(defaultDatabaseFilename).path
    }

    private static func ensureDirectoryExists(at path: String) throws {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
            if !isDirectory.boolValue {
                throw DatabaseError.failedToCreate(reason: "Path exists but is not a directory: \(path)")
            }
            return
        }
        do {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw DatabaseError.failedToCreate(reason: "Failed to create directory: \(error.localizedDescription)")
        }
    }

    func lastChangesCount() -> Int {
        return serialQueue.sync {
            guard let db = db else { return 0 }
            return Int(sqlite3_changes(db))
        }
    }
}
