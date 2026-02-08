# Task 0301: Fact Storage with CRUD Operations

**Milestone:** M4 - Memory System
**Unit:** 4.2 - Fact Storage (Insert, Update, Delete)
**Phase:** 2
**Depends On:** 0300 (DatabaseManager)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions (PascalCase for Swift), security boundaries, core principles
2. `src/Database/DatabaseManager.swift` — Read entirely; understand the `execute()`, `insertAndReturnId()`, `query()`, `queryScalar()`, and `transaction()` methods and their parameter types
3. `src/Database/DatabaseError.swift` — Read entirely; understand available error types
4. `docs/research/memory-learning.md` — Focus on Section 1: "Fact Taxonomy" (lines ~40-92) for the 7 fact categories, and Section 2: "Confidence, Decay, and Emotional Salience" (lines ~185-270) for confidence thresholds

> **Context Budget Note:** memory-learning.md is 800+ lines. Focus only on Sections 1-2 (lines 1-303). Skip Section 3 (storage architecture), Section 4 (consolidation), and everything after. DatabaseManager.swift is the most important context file — read the full file.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the Fact model and FactStore for EmberHearth, a native macOS personal AI assistant. The FactStore provides CRUD operations for user facts stored in the SQLite memory database.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., FactStore.swift)
- Security first: never store API keys or credentials in the database
- All source files go under src/, all test files go under tests/

WHAT EXISTS (from Task 0300):
- src/Database/DatabaseManager.swift — SQLite database manager with execute(), insertAndReturnId(), query(), queryScalar(), transaction() methods
- src/Database/DatabaseError.swift — Error types
- src/Memory/MemoryModule.swift — Placeholder (leave it alone)
- The facts table exists with these exact columns:
  - id INTEGER PRIMARY KEY AUTOINCREMENT
  - content TEXT NOT NULL
  - category TEXT NOT NULL (preference, relationship, biographical, event, opinion, contextual, secret)
  - source TEXT NOT NULL DEFAULT 'extracted' (extracted or explicit)
  - confidence REAL NOT NULL DEFAULT 0.8
  - created_at TEXT NOT NULL DEFAULT (datetime('now'))
  - updated_at TEXT NOT NULL DEFAULT (datetime('now'))
  - last_accessed TEXT
  - access_count INTEGER NOT NULL DEFAULT 0
  - importance REAL NOT NULL DEFAULT 0.5 (0.0-1.0)
  - is_deleted INTEGER NOT NULL DEFAULT 0 (soft delete)

IMPORTANT: DatabaseManager.query() returns [[String: Any?]] where each row is a dictionary.
- Integer columns come back as Int64
- Real/Float columns come back as Double
- Text columns come back as String
- NULL columns come back as nil (inside the Any? optional)
- DatabaseManager.insertAndReturnId() returns Int64

YOU WILL CREATE:
1. src/Memory/Fact.swift — The Fact model, FactCategory enum, FactSource enum
2. src/Memory/FactStore.swift — CRUD operations for facts
3. tests/FactStoreTests.swift — Comprehensive unit tests

STEP 1: Create src/Memory/Fact.swift

File: src/Memory/Fact.swift
```swift
// Fact.swift
// EmberHearth
//
// Data model for a stored fact about the user.

import Foundation

/// A stored fact about the user, extracted from conversations or explicitly stated.
struct Fact: Identifiable, Codable, Equatable {

    /// Unique database identifier. Set to 0 for new facts not yet persisted.
    let id: Int64

    /// The fact content as a natural language statement.
    /// Example: "User prefers morning meetings"
    var content: String

    /// The category of this fact (preference, relationship, etc.).
    var category: FactCategory

    /// How this fact was captured.
    var source: FactSource

    /// Confidence score from 0.0 to 1.0.
    /// - > 0.8: High confidence — use freely in responses
    /// - 0.5-0.8: Medium confidence — hedge when referencing ("I think you mentioned...")
    /// - 0.3-0.5: Low confidence — only surface if highly relevant
    /// - < 0.3: Candidate for pruning
    var confidence: Double

    /// When this fact was first stored.
    var createdAt: Date

    /// When this fact was last modified.
    var updatedAt: Date

    /// When this fact was last retrieved for use in a conversation.
    /// nil if never accessed since creation.
    var lastAccessed: Date?

    /// Number of times this fact has been retrieved for context.
    var accessCount: Int

    /// Importance score from 0.0 to 1.0.
    /// Higher importance facts are prioritized during retrieval.
    var importance: Double

    /// Whether this fact has been soft-deleted.
    /// Soft-deleted facts are excluded from normal queries.
    var isDeleted: Bool

    /// Creates a new Fact with sensible defaults for insertion.
    /// The `id` is set to 0 because the database assigns the actual ID on insert.
    ///
    /// - Parameters:
    ///   - content: The fact as a natural language statement.
    ///   - category: The fact category.
    ///   - source: How the fact was captured (default: .extracted).
    ///   - confidence: Confidence score 0.0-1.0 (default: 0.8).
    ///   - importance: Importance score 0.0-1.0 (default: 0.5).
    static func create(
        content: String,
        category: FactCategory,
        source: FactSource = .extracted,
        confidence: Double = 0.8,
        importance: Double = 0.5
    ) -> Fact {
        let now = Date()
        return Fact(
            id: 0,
            content: content,
            category: category,
            source: source,
            confidence: confidence,
            createdAt: now,
            updatedAt: now,
            lastAccessed: nil,
            accessCount: 0,
            importance: importance,
            isDeleted: false
        )
    }
}

/// Categories for classifying user facts.
/// Maps directly to the `category` column in the facts table.
enum FactCategory: String, Codable, CaseIterable {
    /// User likes, dislikes, and how they want things done.
    case preference

    /// People the user mentions — family, friends, colleagues, pets.
    case relationship

    /// Personal details — job, location, hobbies, birthday.
    case biographical

    /// Things that happened or will happen.
    case event

    /// User's views, values, and perspectives on topics.
    case opinion

    /// Situational facts — current projects, concerns, goals.
    case contextual

    /// Explicitly private information the user asked to keep secret.
    case secret
}

/// How a fact was captured.
/// Maps directly to the `source` column in the facts table.
enum FactSource: String, Codable {
    /// The LLM extracted this fact from a conversation.
    case extracted

    /// The user explicitly said "remember this" or similar.
    case explicit
}
```

STEP 2: Create src/Memory/FactStore.swift

The FactStore uses DatabaseManager for all database operations. It converts between the Fact model and database rows.

File: src/Memory/FactStore.swift
```swift
// FactStore.swift
// EmberHearth
//
// CRUD operations for user facts stored in the SQLite memory database.
// Uses DatabaseManager for all database access.

import Foundation

/// Provides CRUD operations for user facts.
///
/// Usage:
/// ```swift
/// let db = try DatabaseManager(path: ":memory:")
/// let store = FactStore(database: db)
/// let id = try store.insert(Fact.create(content: "User likes coffee", category: .preference))
/// ```
final class FactStore {

    // MARK: - Properties

    /// The database manager used for all operations.
    private let database: DatabaseManager

    // MARK: - Date Formatting

    /// ISO 8601 date formatter matching SQLite's datetime('now') format.
    /// SQLite stores dates as "YYYY-MM-DD HH:MM:SS" strings.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Initialization

    /// Creates a FactStore backed by the given database manager.
    ///
    /// - Parameter database: The DatabaseManager to use for all operations.
    init(database: DatabaseManager) {
        self.database = database
    }

    // MARK: - Insert

    /// Inserts a new fact into the database.
    ///
    /// - Parameter fact: The fact to insert. The `id` field is ignored (database assigns it).
    /// - Returns: The database-assigned ID of the new fact.
    /// - Throws: `DatabaseError` if the insert fails.
    @discardableResult
    func insert(_ fact: Fact) throws -> Int64 {
        let sql = """
            INSERT INTO facts (content, category, source, confidence, created_at, updated_at, importance)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        let now = FactStore.dateFormatter.string(from: Date())
        return try database.insertAndReturnId(
            sql: sql,
            parameters: [
                fact.content,
                fact.category.rawValue,
                fact.source.rawValue,
                fact.confidence,
                now,
                now,
                fact.importance
            ]
        )
    }

    // MARK: - Update

    /// Updates an existing fact in the database.
    /// Updates the content, category, source, confidence, importance, and updated_at fields.
    ///
    /// - Parameter fact: The fact to update. Must have a valid `id`.
    /// - Throws: `DatabaseError` if the update fails.
    func update(_ fact: Fact) throws {
        let sql = """
            UPDATE facts
            SET content = ?, category = ?, source = ?, confidence = ?, importance = ?, updated_at = ?
            WHERE id = ?
            """
        let now = FactStore.dateFormatter.string(from: Date())
        try database.execute(
            sql: sql,
            parameters: [
                fact.content,
                fact.category.rawValue,
                fact.source.rawValue,
                fact.confidence,
                fact.importance,
                now,
                fact.id
            ]
        )
    }

    // MARK: - Delete (Soft)

    /// Soft-deletes a fact by setting is_deleted = 1.
    /// The fact remains in the database but is excluded from normal queries.
    ///
    /// - Parameter id: The ID of the fact to soft-delete.
    /// - Throws: `DatabaseError` if the update fails.
    func softDelete(id: Int64) throws {
        let sql = "UPDATE facts SET is_deleted = 1, updated_at = ? WHERE id = ?"
        let now = FactStore.dateFormatter.string(from: Date())
        try database.execute(sql: sql, parameters: [now, id])
    }

    // MARK: - Read

    /// Returns all facts, optionally including soft-deleted ones.
    ///
    /// - Parameter includeDeleted: If true, includes soft-deleted facts. Default: false.
    /// - Returns: An array of all matching facts, ordered by created_at descending.
    /// - Throws: `DatabaseError` if the query fails.
    func getAll(includeDeleted: Bool = false) throws -> [Fact] {
        let sql: String
        if includeDeleted {
            sql = "SELECT * FROM facts ORDER BY created_at DESC"
        } else {
            sql = "SELECT * FROM facts WHERE is_deleted = 0 ORDER BY created_at DESC"
        }
        let rows = try database.query(sql: sql)
        return rows.compactMap { rowToFact($0) }
    }

    /// Returns a single fact by its ID, or nil if not found.
    ///
    /// - Parameter id: The fact ID.
    /// - Returns: The fact, or nil if not found (including if soft-deleted).
    /// - Throws: `DatabaseError` if the query fails.
    func getById(_ id: Int64) throws -> Fact? {
        let sql = "SELECT * FROM facts WHERE id = ? AND is_deleted = 0"
        let rows = try database.query(sql: sql, parameters: [id])
        return rows.first.flatMap { rowToFact($0) }
    }

    /// Returns all facts in a given category.
    ///
    /// - Parameter category: The fact category to filter by.
    /// - Returns: An array of facts in that category, ordered by importance descending.
    /// - Throws: `DatabaseError` if the query fails.
    func getByCategory(_ category: FactCategory) throws -> [Fact] {
        let sql = """
            SELECT * FROM facts
            WHERE category = ? AND is_deleted = 0
            ORDER BY importance DESC, created_at DESC
            """
        let rows = try database.query(sql: sql, parameters: [category.rawValue])
        return rows.compactMap { rowToFact($0) }
    }

    // MARK: - Search

    /// Searches facts by keyword using SQL LIKE.
    /// Matches against the `content` column (case-insensitive).
    ///
    /// - Parameter query: The search query string. Will be wrapped in %query%.
    /// - Returns: An array of matching facts, ordered by importance descending.
    /// - Throws: `DatabaseError` if the query fails.
    func search(query: String) throws -> [Fact] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        let sql = """
            SELECT * FROM facts
            WHERE content LIKE ? AND is_deleted = 0
            ORDER BY importance DESC, confidence DESC
            """
        let searchPattern = "%\(query)%"
        let rows = try database.query(sql: sql, parameters: [searchPattern])
        return rows.compactMap { rowToFact($0) }
    }

    // MARK: - Access Tracking

    /// Updates the access tracking for a fact.
    /// Increments access_count and sets last_accessed to now.
    ///
    /// - Parameter id: The ID of the fact being accessed.
    /// - Throws: `DatabaseError` if the update fails.
    func updateAccessTracking(id: Int64) throws {
        let sql = """
            UPDATE facts
            SET access_count = access_count + 1, last_accessed = ?
            WHERE id = ?
            """
        let now = FactStore.dateFormatter.string(from: Date())
        try database.execute(sql: sql, parameters: [now, id])
    }

    // MARK: - Duplicate Detection

    /// Checks if a very similar fact already exists.
    /// Uses a simple substring match: if the new content is contained in an existing fact
    /// or an existing fact is contained in the new content, they are considered similar.
    ///
    /// - Parameter content: The content of the new fact.
    /// - Returns: The existing similar fact, or nil if no match found.
    /// - Throws: `DatabaseError` if the query fails.
    func findSimilar(to content: String) throws -> Fact? {
        // Normalize whitespace for comparison
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }

        // Search for facts that contain the new content, or that the new content contains
        let sql = """
            SELECT * FROM facts
            WHERE is_deleted = 0
            AND (LOWER(content) LIKE ? OR ? LIKE '%' || LOWER(content) || '%')
            ORDER BY confidence DESC
            LIMIT 1
            """
        let searchPattern = "%\(normalized)%"
        let rows = try database.query(sql: sql, parameters: [searchPattern, normalized])
        return rows.first.flatMap { rowToFact($0) }
    }

    /// Inserts a fact, or updates an existing one if a similar fact is found.
    /// When updating, the new content replaces the old content, and confidence is
    /// set to the maximum of the old and new values.
    ///
    /// - Parameter fact: The fact to insert or merge.
    /// - Returns: The ID of the inserted or updated fact.
    /// - Throws: `DatabaseError` if the operation fails.
    @discardableResult
    func insertOrUpdate(_ fact: Fact) throws -> Int64 {
        if let existing = try findSimilar(to: fact.content) {
            // Update existing fact with new content and max confidence
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

    // MARK: - Count

    /// Returns the total number of non-deleted facts.
    ///
    /// - Returns: The fact count.
    /// - Throws: `DatabaseError` if the query fails.
    func count() throws -> Int {
        let result = try database.queryScalar(sql: "SELECT COUNT(*) FROM facts WHERE is_deleted = 0")
        return Int(result as? Int64 ?? 0)
    }

    // MARK: - Row Mapping

    /// Converts a database row dictionary to a Fact model.
    /// Returns nil if required fields are missing.
    ///
    /// - Parameter row: A dictionary from DatabaseManager.query().
    /// - Returns: A Fact, or nil if the row is invalid.
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
        else {
            return nil
        }

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
```

STEP 3: Create tests/FactStoreTests.swift

File: tests/FactStoreTests.swift
```swift
// FactStoreTests.swift
// EmberHearth
//
// Unit tests for Fact model and FactStore.

import XCTest
@testable import EmberHearth

final class FactStoreTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a fresh in-memory DatabaseManager and FactStore for each test.
    private func makeStore() throws -> (DatabaseManager, FactStore) {
        let db = try DatabaseManager(path: ":memory:")
        let store = FactStore(database: db)
        return (db, store)
    }

    /// Creates a test fact with the given content and category.
    private func makeFact(
        content: String = "User likes coffee",
        category: FactCategory = .preference,
        source: FactSource = .extracted,
        confidence: Double = 0.8,
        importance: Double = 0.5
    ) -> Fact {
        return Fact.create(
            content: content,
            category: category,
            source: source,
            confidence: confidence,
            importance: importance
        )
    }

    // MARK: - Fact Model Tests

    func testFactCreateDefaults() {
        let fact = Fact.create(content: "Test", category: .preference)

        XCTAssertEqual(fact.id, 0, "New facts should have id = 0 before insertion")
        XCTAssertEqual(fact.content, "Test")
        XCTAssertEqual(fact.category, .preference)
        XCTAssertEqual(fact.source, .extracted, "Default source should be .extracted")
        XCTAssertEqual(fact.confidence, 0.8, "Default confidence should be 0.8")
        XCTAssertEqual(fact.importance, 0.5, "Default importance should be 0.5")
        XCTAssertEqual(fact.accessCount, 0)
        XCTAssertFalse(fact.isDeleted)
        XCTAssertNil(fact.lastAccessed)
    }

    func testFactCategoryAllCases() {
        let expected: [FactCategory] = [
            .preference, .relationship, .biographical, .event,
            .opinion, .contextual, .secret
        ]
        XCTAssertEqual(FactCategory.allCases, expected)
    }

    func testFactCategoryRawValues() {
        XCTAssertEqual(FactCategory.preference.rawValue, "preference")
        XCTAssertEqual(FactCategory.relationship.rawValue, "relationship")
        XCTAssertEqual(FactCategory.biographical.rawValue, "biographical")
        XCTAssertEqual(FactCategory.event.rawValue, "event")
        XCTAssertEqual(FactCategory.opinion.rawValue, "opinion")
        XCTAssertEqual(FactCategory.contextual.rawValue, "contextual")
        XCTAssertEqual(FactCategory.secret.rawValue, "secret")
    }

    func testFactSourceRawValues() {
        XCTAssertEqual(FactSource.extracted.rawValue, "extracted")
        XCTAssertEqual(FactSource.explicit.rawValue, "explicit")
    }

    // MARK: - Insert Tests

    func testInsertReturnsDatabaseId() throws {
        let (_, store) = try makeStore()

        let id1 = try store.insert(makeFact(content: "Fact one"))
        let id2 = try store.insert(makeFact(content: "Fact two"))

        XCTAssertEqual(id1, 1)
        XCTAssertEqual(id2, 2)
    }

    func testInsertedFactIsRetrievable() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(
            content: "User prefers oat milk lattes",
            category: .preference,
            source: .explicit,
            confidence: 0.95,
            importance: 0.7
        ))

        let fact = try store.getById(id)
        XCTAssertNotNil(fact)
        XCTAssertEqual(fact?.id, id)
        XCTAssertEqual(fact?.content, "User prefers oat milk lattes")
        XCTAssertEqual(fact?.category, .preference)
        XCTAssertEqual(fact?.source, .explicit)
        XCTAssertEqual(fact?.confidence, 0.95)
        XCTAssertEqual(fact?.importance, 0.7)
        XCTAssertFalse(fact?.isDeleted ?? true)
        XCTAssertEqual(fact?.accessCount, 0)
    }

    func testInsertAllCategories() throws {
        let (_, store) = try makeStore()

        for category in FactCategory.allCases {
            let id = try store.insert(makeFact(
                content: "Fact for \(category.rawValue)",
                category: category
            ))
            let fact = try store.getById(id)
            XCTAssertEqual(fact?.category, category, "Category \(category.rawValue) should round-trip")
        }
    }

    // MARK: - Update Tests

    func testUpdateModifiesContent() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "User likes tea"))
        var fact = try store.getById(id)!

        fact.content = "User loves green tea specifically"
        fact.confidence = 0.95
        try store.update(fact)

        let updated = try store.getById(id)
        XCTAssertEqual(updated?.content, "User loves green tea specifically")
        XCTAssertEqual(updated?.confidence, 0.95)
    }

    func testUpdateModifiesCategory() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "User mentioned running", category: .contextual))
        var fact = try store.getById(id)!

        fact.category = .preference
        try store.update(fact)

        let updated = try store.getById(id)
        XCTAssertEqual(updated?.category, .preference)
    }

    // MARK: - Soft Delete Tests

    func testSoftDeleteExcludesFromNormalQueries() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "Delete me"))
        try store.softDelete(id: id)

        // Normal queries should not return soft-deleted facts
        let fact = try store.getById(id)
        XCTAssertNil(fact, "Soft-deleted fact should not be returned by getById")

        let allFacts = try store.getAll()
        XCTAssertEqual(allFacts.count, 0, "Soft-deleted fact should not appear in getAll")
    }

    func testSoftDeleteStillAccessibleWithIncludeDeleted() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "Soft deleted fact"))
        try store.softDelete(id: id)

        let allFacts = try store.getAll(includeDeleted: true)
        XCTAssertEqual(allFacts.count, 1)
        XCTAssertTrue(allFacts[0].isDeleted)
        XCTAssertEqual(allFacts[0].id, id)
    }

    // MARK: - GetAll Tests

    func testGetAllReturnsMultipleFacts() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "Fact A"))
        try store.insert(makeFact(content: "Fact B"))
        try store.insert(makeFact(content: "Fact C"))

        let facts = try store.getAll()
        XCTAssertEqual(facts.count, 3)
    }

    func testGetAllEmptyDatabase() throws {
        let (_, store) = try makeStore()

        let facts = try store.getAll()
        XCTAssertEqual(facts.count, 0)
    }

    // MARK: - GetByCategory Tests

    func testGetByCategoryFiltersCorrectly() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "Likes coffee", category: .preference))
        try store.insert(makeFact(content: "Sister named Sarah", category: .relationship))
        try store.insert(makeFact(content: "Works at Acme", category: .biographical))
        try store.insert(makeFact(content: "Prefers mornings", category: .preference))

        let preferences = try store.getByCategory(.preference)
        XCTAssertEqual(preferences.count, 2)
        XCTAssertTrue(preferences.allSatisfy { $0.category == .preference })

        let relationships = try store.getByCategory(.relationship)
        XCTAssertEqual(relationships.count, 1)
        XCTAssertEqual(relationships[0].content, "Sister named Sarah")
    }

    func testGetByCategoryExcludesDeleted() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "Deleted pref", category: .preference))
        try store.insert(makeFact(content: "Active pref", category: .preference))
        try store.softDelete(id: id)

        let preferences = try store.getByCategory(.preference)
        XCTAssertEqual(preferences.count, 1)
        XCTAssertEqual(preferences[0].content, "Active pref")
    }

    // MARK: - Search Tests

    func testSearchByKeyword() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "User likes coffee"))
        try store.insert(makeFact(content: "User prefers morning meetings"))
        try store.insert(makeFact(content: "User's sister likes tea"))

        let coffeeResults = try store.search(query: "coffee")
        XCTAssertEqual(coffeeResults.count, 1)
        XCTAssertEqual(coffeeResults[0].content, "User likes coffee")

        let likesResults = try store.search(query: "likes")
        XCTAssertEqual(likesResults.count, 2)
    }

    func testSearchIsCaseInsensitive() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "User likes COFFEE"))

        let results = try store.search(query: "coffee")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchEmptyQueryReturnsEmpty() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "Some fact"))

        let results = try store.search(query: "")
        XCTAssertEqual(results.count, 0)

        let whitespaceResults = try store.search(query: "   ")
        XCTAssertEqual(whitespaceResults.count, 0)
    }

    func testSearchExcludesSoftDeleted() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "User likes coffee"))
        try store.softDelete(id: id)

        let results = try store.search(query: "coffee")
        XCTAssertEqual(results.count, 0)
    }

    // MARK: - Access Tracking Tests

    func testUpdateAccessTracking() throws {
        let (_, store) = try makeStore()

        let id = try store.insert(makeFact(content: "Tracked fact"))

        // Initially, access_count = 0 and last_accessed is nil
        let before = try store.getById(id)!
        XCTAssertEqual(before.accessCount, 0)
        XCTAssertNil(before.lastAccessed)

        // Update tracking
        try store.updateAccessTracking(id: id)

        let after = try store.getById(id)!
        XCTAssertEqual(after.accessCount, 1)
        XCTAssertNotNil(after.lastAccessed)

        // Update again
        try store.updateAccessTracking(id: id)

        let afterSecond = try store.getById(id)!
        XCTAssertEqual(afterSecond.accessCount, 2)
    }

    // MARK: - Duplicate Detection Tests

    func testFindSimilarDetectsSubstring() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "User likes coffee"))

        let similar = try store.findSimilar(to: "User likes coffee a lot")
        XCTAssertNotNil(similar, "Should find similar fact when new content contains old content")
        XCTAssertEqual(similar?.content, "User likes coffee")
    }

    func testFindSimilarReturnsNilForNoMatch() throws {
        let (_, store) = try makeStore()

        try store.insert(makeFact(content: "User likes coffee"))

        let similar = try store.findSimilar(to: "Favorite color is blue")
        XCTAssertNil(similar, "Should not find similar fact for unrelated content")
    }

    func testInsertOrUpdateInsertNewFact() throws {
        let (_, store) = try makeStore()

        let id = try store.insertOrUpdate(makeFact(content: "User likes hiking"))

        let fact = try store.getById(id)
        XCTAssertNotNil(fact)
        XCTAssertEqual(fact?.content, "User likes hiking")
    }

    func testInsertOrUpdateMergesSimilarFact() throws {
        let (_, store) = try makeStore()

        let originalId = try store.insert(makeFact(content: "User likes coffee", confidence: 0.7))

        let mergedId = try store.insertOrUpdate(makeFact(
            content: "User likes coffee very much",
            confidence: 0.9
        ))

        XCTAssertEqual(mergedId, originalId, "Should update existing fact, not create new one")

        let updated = try store.getById(originalId)
        XCTAssertEqual(updated?.content, "User likes coffee very much")
        XCTAssertEqual(updated?.confidence, 0.9, "Should keep higher confidence")
    }

    // MARK: - Count Tests

    func testCount() throws {
        let (_, store) = try makeStore()

        XCTAssertEqual(try store.count(), 0)

        try store.insert(makeFact(content: "A"))
        try store.insert(makeFact(content: "B"))
        XCTAssertEqual(try store.count(), 2)

        let id = try store.insert(makeFact(content: "C"))
        try store.softDelete(id: id)
        XCTAssertEqual(try store.count(), 2, "Soft-deleted facts should not be counted")
    }

    // MARK: - Edge Cases

    func testEmptyContent() throws {
        // Empty content should fail due to NOT NULL constraint
        // But the SQL doesn't have a CHECK constraint for empty strings,
        // so it will insert. The application layer should handle this.
        let (_, store) = try makeStore()

        // This is technically allowed by the database (NOT NULL != not empty)
        let id = try store.insert(makeFact(content: ""))
        let fact = try store.getById(id)
        XCTAssertEqual(fact?.content, "")
    }

    func testVeryLongContent() throws {
        let (_, store) = try makeStore()

        let longContent = String(repeating: "A", count: 10_000)
        let id = try store.insert(makeFact(content: longContent))

        let fact = try store.getById(id)
        XCTAssertEqual(fact?.content.count, 10_000)
    }

    func testSpecialCharactersInContent() throws {
        let (_, store) = try makeStore()

        let special = "User's name is O'Brien & they \"love\" emojis 🔥 — also: SELECT * FROM users; DROP TABLE facts;--"
        let id = try store.insert(makeFact(content: special))

        let fact = try store.getById(id)
        XCTAssertEqual(fact?.content, special, "Special characters should be preserved exactly")
    }

    func testGetByIdReturnsNilForNonexistent() throws {
        let (_, store) = try makeStore()

        let fact = try store.getById(999)
        XCTAssertNil(fact)
    }

    func testConfidenceBoundaryValues() throws {
        let (_, store) = try makeStore()

        let id0 = try store.insert(makeFact(content: "Zero confidence", confidence: 0.0))
        let id1 = try store.insert(makeFact(content: "Full confidence", confidence: 1.0))

        XCTAssertEqual(try store.getById(id0)?.confidence, 0.0)
        XCTAssertEqual(try store.getById(id1)?.confidence, 1.0)
    }

    func testImportanceBoundaryValues() throws {
        let (_, store) = try makeStore()

        let id0 = try store.insert(makeFact(content: "No importance", importance: 0.0))
        let id1 = try store.insert(makeFact(content: "Max importance", importance: 1.0))

        XCTAssertEqual(try store.getById(id0)?.importance, 0.0)
        XCTAssertEqual(try store.getById(id1)?.importance, 1.0)
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
- Date formatting: SQLite stores dates as "YYYY-MM-DD HH:MM:SS" strings. The dateFormatter must match this exactly, using UTC timezone.
- Int vs Int64: DatabaseManager returns Int64 for integer columns. The Fact model uses Int for accessCount but the database returns Int64 — convert with Int(int64Value).
- Optional handling: last_accessed can be NULL in the database. The row dictionary will contain nil for this column.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify DatabaseManager.swift or DatabaseError.swift.
- Do NOT modify any module placeholder files.
- The FactStore does NOT own the DatabaseManager — it receives one via dependency injection.
- All SQL uses parameterized queries (? placeholders) to prevent SQL injection.
- The dateFormatter uses UTC timezone and "en_US_POSIX" locale for consistent behavior.
- Fact.create() is a factory method that sets id = 0 (the database assigns the real ID).
```

---

## Acceptance Criteria

- [ ] `src/Memory/Fact.swift` exists with `Fact` struct, `FactCategory` enum (7 cases), and `FactSource` enum (2 cases)
- [ ] `Fact` conforms to `Identifiable`, `Codable`, and `Equatable`
- [ ] `Fact.create()` factory method sets sensible defaults (id=0, confidence=0.8, importance=0.5)
- [ ] `FactCategory.allCases` has all 7 categories: preference, relationship, biographical, event, opinion, contextual, secret
- [ ] `FactSource` has 2 cases: extracted, explicit
- [ ] `src/Memory/FactStore.swift` exists with all CRUD operations
- [ ] `insert()` returns the database-assigned `Int64` ID
- [ ] `update()` modifies content, category, source, confidence, importance, and updated_at
- [ ] `softDelete()` sets `is_deleted = 1` (does NOT hard-delete)
- [ ] `getAll()` excludes soft-deleted facts by default
- [ ] `getAll(includeDeleted: true)` includes soft-deleted facts
- [ ] `getById()` returns nil for soft-deleted facts
- [ ] `getByCategory()` filters by category and excludes soft-deleted
- [ ] `search()` uses SQL LIKE for keyword matching (case-insensitive)
- [ ] `search()` returns empty array for empty/whitespace queries
- [ ] `updateAccessTracking()` increments access_count and sets last_accessed
- [ ] `findSimilar()` detects substring-level duplicates
- [ ] `insertOrUpdate()` merges similar facts instead of creating duplicates
- [ ] `count()` returns number of non-deleted facts
- [ ] FactStore uses DatabaseManager via dependency injection (not a singleton)
- [ ] Date formatting uses UTC timezone with "yyyy-MM-dd HH:mm:ss" format
- [ ] All unit tests pass
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Memory/Fact.swift && echo "Fact.swift exists" || echo "MISSING: Fact.swift"
test -f src/Memory/FactStore.swift && echo "FactStore.swift exists" || echo "MISSING: FactStore.swift"
test -f tests/FactStoreTests.swift && echo "FactStoreTests.swift exists" || echo "MISSING: FactStoreTests.swift"

# Verify all 7 categories exist
grep "case preference" src/Memory/Fact.swift
grep "case relationship" src/Memory/Fact.swift
grep "case biographical" src/Memory/Fact.swift
grep "case event" src/Memory/Fact.swift
grep "case opinion" src/Memory/Fact.swift
grep "case contextual" src/Memory/Fact.swift
grep "case secret" src/Memory/Fact.swift

# Verify both sources exist
grep "case extracted" src/Memory/Fact.swift
grep "case explicit" src/Memory/Fact.swift

# Verify FactStore uses DatabaseManager
grep "private let database: DatabaseManager" src/Memory/FactStore.swift

# Verify soft delete (not hard delete)
grep "is_deleted = 1" src/Memory/FactStore.swift

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the Fact model and FactStore created in task 0301 for EmberHearth. Check for these common issues:

1. FACT MODEL CORRECTNESS:
   - Verify Fact conforms to Identifiable, Codable, and Equatable
   - Verify the id property is Int64 (matching DatabaseManager.insertAndReturnId return type)
   - Verify FactCategory has EXACTLY 7 cases: preference, relationship, biographical, event, opinion, contextual, secret
   - Verify FactSource has EXACTLY 2 cases: extracted, explicit
   - Verify Fact.create() sets id = 0, confidence = 0.8, importance = 0.5, accessCount = 0, isDeleted = false
   - Verify raw values match the database column values (lowercase strings)

2. CRUD OPERATIONS:
   - Verify insert() uses parameterized SQL (? placeholders) — no string interpolation in SQL
   - Verify insert() returns Int64 from insertAndReturnId()
   - Verify update() updates content, category, source, confidence, importance, AND updated_at
   - Verify softDelete() sets is_deleted = 1 (not hard DELETE)
   - Verify getAll() excludes soft-deleted facts by default (WHERE is_deleted = 0)
   - Verify getAll(includeDeleted: true) includes soft-deleted facts
   - Verify getById() excludes soft-deleted facts
   - Verify getByCategory() excludes soft-deleted facts
   - Verify search() uses LIKE with % wildcards

3. DATE HANDLING:
   - Verify the dateFormatter format is "yyyy-MM-dd HH:mm:ss"
   - Verify timezone is UTC
   - Verify locale is "en_US_POSIX"
   - Verify dates are formatted when writing and parsed when reading
   - Verify last_accessed can be nil (optional Date)

4. ROW MAPPING:
   - Verify rowToFact() correctly maps ALL columns from the database row
   - Verify Int64 from database is converted to Int for accessCount
   - Verify is_deleted (Int64) is converted to Bool
   - Verify nil/NULL handling for last_accessed
   - Verify the function returns nil for rows with missing required fields

5. DUPLICATE DETECTION:
   - Verify findSimilar() checks for substring matches
   - Verify insertOrUpdate() updates existing facts instead of creating duplicates
   - Verify confidence takes the MAX of old and new values when merging

6. SECURITY:
   - Verify ALL SQL uses parameterized queries (? placeholders)
   - Verify no string interpolation in SQL queries (except for LIKE patterns which are bound as parameters)
   - Verify no API keys or credentials are referenced

7. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test` and verify all FactStoreTests pass
   - Check for any new warnings

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m4): add fact storage with CRUD operations
```

---

## Notes for Next Task

- The FactStore is now available at `src/Memory/FactStore.swift`. Task 0302 (FactRetriever) will use its `search()`, `getAll()`, and `updateAccessTracking()` methods.
- The `search()` method does simple SQL LIKE matching. Task 0302 will build a more sophisticated keyword-based retrieval on top of this.
- The `updateAccessTracking()` method increments access_count and sets last_accessed. Task 0302 should call this for every fact returned to the LLM context.
- FactStore uses dependency injection: `FactStore(database: db)`. Task 0302's FactRetriever should also take the DatabaseManager and/or FactStore as constructor parameters.
- The Fact model's `importance`, `confidence`, `accessCount`, and `createdAt` fields will be used by Task 0302 for relevance scoring.
- The `FactCategory` and `FactSource` enums are defined in `src/Memory/Fact.swift`. Task 0303 (FactExtractor) will use these when parsing LLM output.
