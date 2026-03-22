// FactStore.swift
// EmberHearth
//
// CRUD operations for user facts stored in the SQLite memory database.

import Foundation

final class FactStore {

    private let database: DatabaseManager

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init(database: DatabaseManager) {
        self.database = database
    }

    @discardableResult
    func insert(_ fact: Fact) throws -> Int64 {
        let sql = """
            INSERT INTO facts (content, category, source, confidence, created_at, updated_at, importance)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        let now = FactStore.dateFormatter.string(from: Date())
        return try database.insertAndReturnId(
            sql: sql,
            parameters: [fact.content, fact.category.rawValue, fact.source.rawValue, fact.confidence, now, now, fact.importance]
        )
    }

    func update(_ fact: Fact) throws {
        let sql = """
            UPDATE facts
            SET content = ?, category = ?, source = ?, confidence = ?, importance = ?, updated_at = ?
            WHERE id = ?
            """
        let now = FactStore.dateFormatter.string(from: Date())
        try database.execute(sql: sql, parameters: [fact.content, fact.category.rawValue, fact.source.rawValue, fact.confidence, fact.importance, now, fact.id])
    }

    func softDelete(id: Int64) throws {
        let now = FactStore.dateFormatter.string(from: Date())
        try database.execute(sql: "UPDATE facts SET is_deleted = 1, updated_at = ? WHERE id = ?", parameters: [now, id])
    }

    func getAll(includeDeleted: Bool = false) throws -> [Fact] {
        let sql = includeDeleted
            ? "SELECT * FROM facts ORDER BY created_at DESC"
            : "SELECT * FROM facts WHERE is_deleted = 0 ORDER BY created_at DESC"
        return try database.query(sql: sql).compactMap { rowToFact($0) }
    }

    func getById(_ id: Int64) throws -> Fact? {
        let rows = try database.query(sql: "SELECT * FROM facts WHERE id = ? AND is_deleted = 0", parameters: [id])
        return rows.first.flatMap { rowToFact($0) }
    }

    func getByCategory(_ category: FactCategory) throws -> [Fact] {
        let sql = "SELECT * FROM facts WHERE category = ? AND is_deleted = 0 ORDER BY importance DESC, created_at DESC"
        return try database.query(sql: sql, parameters: [category.rawValue]).compactMap { rowToFact($0) }
    }

    func search(query: String) throws -> [Fact] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let sql = "SELECT * FROM facts WHERE content LIKE ? AND is_deleted = 0 ORDER BY importance DESC, confidence DESC"
        return try database.query(sql: sql, parameters: ["%\(query)%"]).compactMap { rowToFact($0) }
    }

    func updateAccessTracking(id: Int64) throws {
        let now = FactStore.dateFormatter.string(from: Date())
        try database.execute(sql: "UPDATE facts SET access_count = access_count + 1, last_accessed = ? WHERE id = ?", parameters: [now, id])
    }

    func findSimilar(to content: String) throws -> Fact? {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        let sql = """
            SELECT * FROM facts
            WHERE is_deleted = 0
            AND (LOWER(content) LIKE ? OR ? LIKE '%' || LOWER(content) || '%')
            ORDER BY confidence DESC
            LIMIT 1
            """
        return try database.query(sql: sql, parameters: ["%\(normalized)%", normalized]).first.flatMap { rowToFact($0) }
    }

    @discardableResult
    func insertOrUpdate(_ fact: Fact) throws -> Int64 {
        if let existing = try findSimilar(to: fact.content) {
            var updated = existing
            updated.content = fact.content
            updated.confidence = max(existing.confidence, fact.confidence)
            updated.importance = max(existing.importance, fact.importance)
            try update(updated)
            return existing.id
        } else {
            return try insert(fact)
        }
    }

    func count() throws -> Int {
        let result = try database.queryScalar(sql: "SELECT COUNT(*) FROM facts WHERE is_deleted = 0")
        return Int(result as? Int64 ?? 0)
    }

    private func rowToFact(_ row: [String: Any?]) -> Fact? {
        guard
            let id = row["id"] as? Int64,
            let content = row["content"] as? String,
            let categoryStr = row["category"] as? String,
            let category = FactCategory(rawValue: categoryStr),
            let sourceStr = row["source"] as? String,
            let source = FactSource(rawValue: sourceStr),
            let confidence = row["confidence"] as? Double,
            let createdAtStr = row["created_at"] as? String,
            let createdAt = FactStore.dateFormatter.date(from: createdAtStr),
            let updatedAtStr = row["updated_at"] as? String,
            let updatedAt = FactStore.dateFormatter.date(from: updatedAtStr),
            let accessCount = row["access_count"] as? Int64,
            let importance = row["importance"] as? Double,
            let isDeletedInt = row["is_deleted"] as? Int64
        else { return nil }

        var lastAccessed: Date? = nil
        if let lastAccessedStr = row["last_accessed"] as? String {
            lastAccessed = FactStore.dateFormatter.date(from: lastAccessedStr)
        }

        return Fact(
            id: id,
            content: content,
            category: category,
            source: source,
            confidence: confidence,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastAccessed: lastAccessed,
            accessCount: Int(accessCount),
            importance: importance,
            isDeleted: isDeletedInt != 0
        )
    }
}
