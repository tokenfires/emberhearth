// FactStoreTests.swift
// EmberHearth
//
// Unit tests for Fact model and FactStore.

import XCTest
@testable import EmberHearth

final class FactStoreTests: XCTestCase {

    private func makeStore() throws -> (DatabaseManager, FactStore) {
        let db = try DatabaseManager(path: ":memory:")
        return (db, FactStore(database: db))
    }

    private func makeFact(content: String = "User likes coffee", category: FactCategory = .preference,
                          source: FactSource = .extracted, confidence: Double = 0.8, importance: Double = 0.5) -> Fact {
        return Fact.create(content: content, category: category, source: source, confidence: confidence, importance: importance)
    }

    func testFactCreateDefaults() {
        let fact = Fact.create(content: "Test", category: .preference)
        XCTAssertEqual(fact.id, 0)
        XCTAssertEqual(fact.source, .extracted)
        XCTAssertEqual(fact.confidence, 0.8)
        XCTAssertEqual(fact.importance, 0.5)
        XCTAssertEqual(fact.accessCount, 0)
        XCTAssertFalse(fact.isDeleted)
        XCTAssertNil(fact.lastAccessed)
    }

    func testFactCategoryAllCases() {
        let expected: [FactCategory] = [.preference, .relationship, .biographical, .event, .opinion, .contextual, .secret]
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

    func testInsertReturnsDatabaseId() throws {
        let (_, store) = try makeStore()
        let id1 = try store.insert(makeFact(content: "Fact one"))
        let id2 = try store.insert(makeFact(content: "Fact two"))
        XCTAssertEqual(id1, 1)
        XCTAssertEqual(id2, 2)
    }

    func testInsertedFactIsRetrievable() throws {
        let (_, store) = try makeStore()
        let id = try store.insert(makeFact(content: "User prefers oat milk lattes", category: .preference, source: .explicit, confidence: 0.95, importance: 0.7))
        let fact = try store.getById(id)
        XCTAssertNotNil(fact)
        XCTAssertEqual(fact?.content, "User prefers oat milk lattes")
        XCTAssertEqual(fact?.category, .preference)
        XCTAssertEqual(fact?.source, .explicit)
        XCTAssertEqual(fact?.confidence, 0.95)
        XCTAssertEqual(fact?.importance, 0.7)
        XCTAssertFalse(fact?.isDeleted ?? true)
    }

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

    func testSoftDeleteExcludesFromNormalQueries() throws {
        let (_, store) = try makeStore()
        let id = try store.insert(makeFact(content: "Delete me"))
        try store.softDelete(id: id)
        XCTAssertNil(try store.getById(id))
        XCTAssertEqual(try store.getAll().count, 0)
    }

    func testSoftDeleteStillAccessibleWithIncludeDeleted() throws {
        let (_, store) = try makeStore()
        let id = try store.insert(makeFact(content: "Soft deleted fact"))
        try store.softDelete(id: id)
        let allFacts = try store.getAll(includeDeleted: true)
        XCTAssertEqual(allFacts.count, 1)
        XCTAssertTrue(allFacts[0].isDeleted)
    }

    func testGetAllReturnsMultipleFacts() throws {
        let (_, store) = try makeStore()
        try store.insert(makeFact(content: "Fact A"))
        try store.insert(makeFact(content: "Fact B"))
        try store.insert(makeFact(content: "Fact C"))
        XCTAssertEqual(try store.getAll().count, 3)
    }

    func testGetByCategoryFiltersCorrectly() throws {
        let (_, store) = try makeStore()
        try store.insert(makeFact(content: "Likes coffee", category: .preference))
        try store.insert(makeFact(content: "Sister named Sarah", category: .relationship))
        try store.insert(makeFact(content: "Prefers mornings", category: .preference))
        let preferences = try store.getByCategory(.preference)
        XCTAssertEqual(preferences.count, 2)
        XCTAssertTrue(preferences.allSatisfy { $0.category == .preference })
    }

    func testSearchByKeyword() throws {
        let (_, store) = try makeStore()
        try store.insert(makeFact(content: "User likes coffee"))
        try store.insert(makeFact(content: "User prefers morning meetings"))
        try store.insert(makeFact(content: "User's sister likes tea"))
        XCTAssertEqual(try store.search(query: "coffee").count, 1)
        XCTAssertEqual(try store.search(query: "likes").count, 2)
    }

    func testSearchIsCaseInsensitive() throws {
        let (_, store) = try makeStore()
        try store.insert(makeFact(content: "User likes COFFEE"))
        XCTAssertEqual(try store.search(query: "coffee").count, 1)
    }

    func testSearchEmptyQueryReturnsEmpty() throws {
        let (_, store) = try makeStore()
        try store.insert(makeFact(content: "Some fact"))
        XCTAssertEqual(try store.search(query: "").count, 0)
        XCTAssertEqual(try store.search(query: "   ").count, 0)
    }

    func testUpdateAccessTracking() throws {
        let (_, store) = try makeStore()
        let id = try store.insert(makeFact(content: "Tracked fact"))
        let before = try store.getById(id)!
        XCTAssertEqual(before.accessCount, 0)
        XCTAssertNil(before.lastAccessed)
        try store.updateAccessTracking(id: id)
        let after = try store.getById(id)!
        XCTAssertEqual(after.accessCount, 1)
        XCTAssertNotNil(after.lastAccessed)
    }

    func testInsertOrUpdateMergesSimilarFact() throws {
        let (_, store) = try makeStore()
        let originalId = try store.insert(makeFact(content: "User likes coffee", confidence: 0.7))
        let mergedId = try store.insertOrUpdate(makeFact(content: "User likes coffee very much", confidence: 0.9))
        XCTAssertEqual(mergedId, originalId)
        let updated = try store.getById(originalId)
        XCTAssertEqual(updated?.content, "User likes coffee very much")
        XCTAssertEqual(updated?.confidence, 0.9)
    }

    func testCount() throws {
        let (_, store) = try makeStore()
        XCTAssertEqual(try store.count(), 0)
        try store.insert(makeFact(content: "A"))
        try store.insert(makeFact(content: "B"))
        XCTAssertEqual(try store.count(), 2)
        let id = try store.insert(makeFact(content: "C"))
        try store.softDelete(id: id)
        XCTAssertEqual(try store.count(), 2)
    }

    func testSpecialCharactersInContent() throws {
        let (_, store) = try makeStore()
        let special = "User's name is O'Brien & they \"love\" emojis 🔥 — also: SELECT * FROM users; DROP TABLE facts;--"
        let id = try store.insert(makeFact(content: special))
        XCTAssertEqual(try store.getById(id)?.content, special)
    }

    func testGetByIdReturnsNilForNonexistent() throws {
        let (_, store) = try makeStore()
        XCTAssertNil(try store.getById(999))
    }
}
