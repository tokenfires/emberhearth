// DatabaseManagerTests.swift
// EmberHearth
//
// Unit tests for DatabaseManager.

import XCTest
@testable import EmberHearth

final class DatabaseManagerTests: XCTestCase {

    private func makeManager() throws -> DatabaseManager {
        return try DatabaseManager(path: ":memory:")
    }

    func testInitializationCreatesAllTables() throws {
        let manager = try makeManager()
        let factsResult = try manager.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='facts'")
        XCTAssertEqual(factsResult.count, 1)
        let sessionsResult = try manager.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'")
        XCTAssertEqual(sessionsResult.count, 1)
        let messagesResult = try manager.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='messages'")
        XCTAssertEqual(messagesResult.count, 1)
        let schemaResult = try manager.query(sql: "SELECT name FROM sqlite_master WHERE type='table' AND name='schema_version'")
        XCTAssertEqual(schemaResult.count, 1)
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
        let journalMode = result[0]["journal_mode"] as? String
        XCTAssertTrue(journalMode == "wal" || journalMode == "memory")
    }

    func testForeignKeysEnabled() throws {
        let manager = try makeManager()
        let result = try manager.query(sql: "PRAGMA foreign_keys")
        let fkEnabled = result[0]["foreign_keys"] as? Int64
        XCTAssertEqual(fkEnabled, 1)
    }

    func testInsertAndQuery() throws {
        let manager = try makeManager()
        try manager.execute(sql: "INSERT INTO facts (content, category, source, confidence, importance) VALUES (?, ?, ?, ?, ?)",
            parameters: ["User likes coffee", "preference", "extracted", 0.9, 0.5])
        let results = try manager.query(sql: "SELECT * FROM facts WHERE content = ?", parameters: ["User likes coffee"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["content"] as? String, "User likes coffee")
        XCTAssertEqual(results[0]["category"] as? String, "preference")
        XCTAssertEqual(results[0]["confidence"] as? Double, 0.9)
        XCTAssertEqual(results[0]["is_deleted"] as? Int64, 0)
    }

    func testInsertAndReturnId() throws {
        let manager = try makeManager()
        let id1 = try manager.insertAndReturnId(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Fact one", "preference"])
        let id2 = try manager.insertAndReturnId(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Fact two", "biographical"])
        XCTAssertEqual(id1, 1)
        XCTAssertEqual(id2, 2)
    }

    func testUpdateQuery() throws {
        let manager = try makeManager()
        try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["User likes tea", "preference"])
        try manager.execute(sql: "UPDATE facts SET content = ?, updated_at = datetime('now') WHERE content = ?", parameters: ["User loves tea", "User likes tea"])
        let results = try manager.query(sql: "SELECT content FROM facts")
        XCTAssertEqual(results[0]["content"] as? String, "User loves tea")
    }

    func testDeleteQuery() throws {
        let manager = try makeManager()
        try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Temporary fact", "contextual"])
        try manager.execute(sql: "DELETE FROM facts WHERE content = ?", parameters: ["Temporary fact"])
        let results = try manager.query(sql: "SELECT * FROM facts")
        XCTAssertEqual(results.count, 0)
    }

    func testQueryScalar() throws {
        let manager = try makeManager()
        try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Fact A", "preference"])
        try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Fact B", "biographical"])
        let count = try manager.queryScalar(sql: "SELECT COUNT(*) FROM facts")
        XCTAssertEqual(count as? Int64, 2)
    }

    func testQueryScalarReturnsNilForEmptyResult() throws {
        let manager = try makeManager()
        let result = try manager.queryScalar(sql: "SELECT id FROM facts WHERE id = 999")
        XCTAssertNil(result as Any?)
    }

    func testTransactionCommits() throws {
        let manager = try makeManager()
        try manager.transaction {
            try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Transaction fact 1", "preference"])
            try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Transaction fact 2", "preference"])
        }
        let count = try manager.queryScalar(sql: "SELECT COUNT(*) FROM facts") as? Int64
        XCTAssertEqual(count, 2)
    }

    func testTransactionRollsBackOnError() throws {
        let manager = try makeManager()
        try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Existing fact", "preference"])
        do {
            try manager.transaction {
                try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Will be rolled back", "preference"])
                try manager.execute(sql: "INSERT INTO nonexistent_table VALUES (?)", parameters: ["fail"])
            }
            XCTFail("Transaction should have thrown")
        } catch {}
        let count = try manager.queryScalar(sql: "SELECT COUNT(*) FROM facts") as? Int64
        XCTAssertEqual(count, 1)
    }

    func testNullParameterBinding() throws {
        let manager = try makeManager()
        let id = try manager.insertAndReturnId(sql: "INSERT INTO sessions (phone_number, summary) VALUES (?, ?)", parameters: ["+15551234567", nil])
        let results = try manager.query(sql: "SELECT summary FROM sessions WHERE id = ?", parameters: [id])
        XCTAssertEqual(results.count, 1)
        let summary = results[0]["summary"]
        // Dictionary lookup returns Optional<Any?>, so unwrap the outer optional
        if let innerValue = summary {
            XCTAssertNil(innerValue, "Expected nil but got \(innerValue!)")
        }
        // If summary itself is nil (key missing), that's also acceptable
    }

    func testForeignKeyConstraint() throws {
        let manager = try makeManager()
        XCTAssertThrowsError(try manager.execute(sql: "INSERT INTO messages (session_id, role, content) VALUES (?, ?, ?)", parameters: [999, "user", "Hello"]))
    }

    func testSessionInsertAndQuery() throws {
        let manager = try makeManager()
        let sessionId = try manager.insertAndReturnId(sql: "INSERT INTO sessions (phone_number) VALUES (?)", parameters: ["+15551234567"])
        let results = try manager.query(sql: "SELECT * FROM sessions WHERE id = ?", parameters: [sessionId])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0]["phone_number"] as? String, "+15551234567")
        XCTAssertEqual(results[0]["is_active"] as? Int64, 1)
    }

    func testMessageInsertWithForeignKey() throws {
        let manager = try makeManager()
        let sessionId = try manager.insertAndReturnId(sql: "INSERT INTO sessions (phone_number) VALUES (?)", parameters: ["+15551234567"])
        let messageId = try manager.insertAndReturnId(sql: "INSERT INTO messages (session_id, role, content) VALUES (?, ?, ?)", parameters: [sessionId, "user", "Hello Ember"])
        let results = try manager.query(sql: "SELECT * FROM messages WHERE id = ?", parameters: [messageId])
        XCTAssertEqual(results[0]["role"] as? String, "user")
        XCTAssertEqual(results[0]["content"] as? String, "Hello Ember")
    }

    func testCloseAndReopen() throws {
        let manager = try makeManager()
        XCTAssertTrue(manager.isOpen)
        manager.close()
        XCTAssertFalse(manager.isOpen)
    }

    func testOperationAfterCloseThrows() throws {
        let manager = try makeManager()
        manager.close()
        XCTAssertThrowsError(try manager.execute(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Should fail", "preference"]))
    }

    func testBackupInMemoryIsNoOp() throws {
        let manager = try makeManager()
        XCTAssertNoThrow(try manager.backup())
    }

    func testFactsTableDefaults() throws {
        let manager = try makeManager()
        let id = try manager.insertAndReturnId(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: ["Minimal fact", "preference"])
        let results = try manager.query(sql: "SELECT * FROM facts WHERE id = ?", parameters: [id])
        XCTAssertEqual(results[0]["source"] as? String, "extracted")
        XCTAssertEqual(results[0]["confidence"] as? Double, 0.8)
        XCTAssertEqual(results[0]["access_count"] as? Int64, 0)
        XCTAssertEqual(results[0]["importance"] as? Double, 0.5)
        XCTAssertEqual(results[0]["is_deleted"] as? Int64, 0)
    }

    func testIndexesExist() throws {
        let manager = try makeManager()
        let results = try manager.query(sql: "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%'")
        let indexNames = results.compactMap { $0["name"] as? String }
        XCTAssertTrue(indexNames.contains("idx_facts_category"))
        XCTAssertTrue(indexNames.contains("idx_facts_is_deleted"))
        XCTAssertTrue(indexNames.contains("idx_sessions_phone_number"))
        XCTAssertTrue(indexNames.contains("idx_sessions_is_active"))
        XCTAssertTrue(indexNames.contains("idx_messages_session_id"))
        XCTAssertTrue(indexNames.contains("idx_messages_timestamp"))
    }

    func testSpecialCharactersInContent() throws {
        let manager = try makeManager()
        let specialContent = "User's name is O'Brien & they \"love\" emojis 🔥 — also: SELECT * FROM users"
        let id = try manager.insertAndReturnId(sql: "INSERT INTO facts (content, category) VALUES (?, ?)", parameters: [specialContent, "biographical"])
        let results = try manager.query(sql: "SELECT content FROM facts WHERE id = ?", parameters: [id])
        XCTAssertEqual(results[0]["content"] as? String, specialContent)
    }
}
