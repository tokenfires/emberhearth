// FactRetrieverTests.swift
// EmberHearth
//
// Unit tests for FactRetriever.

import XCTest
@testable import EmberHearth

final class FactRetrieverTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a fresh in-memory database, FactStore, and FactRetriever.
    /// Optionally pre-populates with test facts.
    private func makeRetriever(populate: Bool = true) throws -> (DatabaseManager, FactStore, FactRetriever) {
        let db = try DatabaseManager(path: ":memory:")
        let store = FactStore(database: db)
        let retriever = FactRetriever(factStore: store)

        if populate {
            try populateTestFacts(store: store)
        }

        return (db, store, retriever)
    }

    /// Populates the database with a realistic set of test facts.
    private func populateTestFacts(store: FactStore) throws {
        // Preferences
        try store.insert(Fact.create(
            content: "User prefers morning meetings before 10am",
            category: .preference, confidence: 0.9, importance: 0.6
        ))
        try store.insert(Fact.create(
            content: "User likes oat milk lattes from the coffee shop",
            category: .preference, confidence: 0.85, importance: 0.4
        ))
        try store.insert(Fact.create(
            content: "User prefers dark mode in all applications",
            category: .preference, confidence: 0.95, importance: 0.3
        ))

        // Relationships
        try store.insert(Fact.create(
            content: "User has a sister named Sarah who is vegan",
            category: .relationship, confidence: 0.95, importance: 0.7
        ))
        try store.insert(Fact.create(
            content: "User's manager at work is named David Chen",
            category: .relationship, confidence: 0.9, importance: 0.6
        ))

        // Biographical
        try store.insert(Fact.create(
            content: "User works as a software engineer at Acme Corp",
            category: .biographical, confidence: 0.95, importance: 0.8
        ))
        try store.insert(Fact.create(
            content: "User lives in Portland Oregon",
            category: .biographical, confidence: 0.9, importance: 0.5
        ))

        // Events
        try store.insert(Fact.create(
            content: "User has a dentist appointment next Tuesday",
            category: .event, confidence: 0.85, importance: 0.6
        ))

        // Opinions
        try store.insert(Fact.create(
            content: "User thinks remote work is more productive than office work",
            category: .opinion, confidence: 0.8, importance: 0.4
        ))

        // Contextual
        try store.insert(Fact.create(
            content: "User is currently working on a machine learning project",
            category: .contextual, confidence: 0.9, importance: 0.7
        ))
    }

    // MARK: - Keyword Extraction Tests

    func testExtractKeywordsBasic() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "What should I get my sister for her birthday?")
        // "what", "should", "i", "get", "my", "sister", "for", "her", "birthday" →
        // After stop word removal and length filter: "sister", "birthday", "get"
        XCTAssertTrue(keywords.contains("sister"), "Should contain 'sister'")
        XCTAssertTrue(keywords.contains("birthday"), "Should contain 'birthday'")
        XCTAssertFalse(keywords.contains("what"), "'what' is a stop word")
        XCTAssertFalse(keywords.contains("my"), "'my' is a stop word")
        XCTAssertFalse(keywords.contains("her"), "'her' is a stop word")
        XCTAssertFalse(keywords.contains("for"), "'for' is a stop word")
    }

    func testExtractKeywordsRemovesPunctuation() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "Hey, what's the coffee shop's name?")
        XCTAssertTrue(keywords.contains("coffee"), "Should contain 'coffee'")
        XCTAssertTrue(keywords.contains("shop"), "Should contain 'shop' (with apostrophe removed)")
        XCTAssertTrue(keywords.contains("name"), "Should contain 'name'")
        XCTAssertFalse(keywords.contains("hey"), "'hey' is a stop word")
    }

    func testExtractKeywordsHandlesEmptyInput() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "")
        XCTAssertTrue(keywords.isEmpty)
    }

    func testExtractKeywordsHandlesOnlyStopWords() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "I am the one who is it")
        XCTAssertTrue(keywords.isEmpty, "All words are stop words or too short")
    }

    func testExtractKeywordsRemovesDuplicates() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "coffee coffee coffee morning morning")
        XCTAssertEqual(keywords.filter { $0 == "coffee" }.count, 1, "Should deduplicate")
        XCTAssertEqual(keywords.filter { $0 == "morning" }.count, 1, "Should deduplicate")
    }

    func testExtractKeywordsLowercases() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "COFFEE Morning PORTLAND")
        XCTAssertTrue(keywords.contains("coffee"))
        XCTAssertTrue(keywords.contains("morning"))
        XCTAssertTrue(keywords.contains("portland"))
    }

    func testExtractKeywordsFiltersShortWords() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let keywords = retriever.extractKeywords(from: "go to NW 5th coffee")
        XCTAssertFalse(keywords.contains("go"), "'go' is too short (< 3 chars)")
        XCTAssertFalse(keywords.contains("nw"), "'nw' is too short (< 3 chars)")
        XCTAssertTrue(keywords.contains("coffee"))
    }

    // MARK: - Retrieval Tests

    func testRetrieveRelevantFactsBasic() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "Tell me about my sister")
        XCTAssertFalse(facts.isEmpty, "Should find facts about sister")

        // The sister fact should be in the results
        let sisterFact = facts.first { $0.content.lowercased().contains("sister") }
        XCTAssertNotNil(sisterFact, "Should find the sister/Sarah fact")
    }

    func testRetrieveRelevantFactsCoffee() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "I want coffee")
        let coffeeFact = facts.first { $0.content.lowercased().contains("coffee") }
        XCTAssertNotNil(coffeeFact, "Should find the coffee preference fact")
    }

    func testRetrieveRelevantFactsWork() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "What do I do for work?")
        let workFact = facts.first { $0.content.lowercased().contains("software engineer") }
        XCTAssertNotNil(workFact, "Should find the work/software engineer fact")
    }

    func testRetrieveRelevantFactsRespectsLimit() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "Tell me everything about my work and meetings and coffee", limit: 3)
        XCTAssertLessThanOrEqual(facts.count, 3, "Should respect the limit")
    }

    func testRetrieveRelevantFactsNoMatchReturnsEmpty() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "quantum physics entanglement")
        XCTAssertTrue(facts.isEmpty, "Should return empty for completely unrelated query")
    }

    func testRetrieveRelevantFactsEmptyMessageReturnsEmpty() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "")
        XCTAssertTrue(facts.isEmpty, "Should return empty for empty message")
    }

    func testRetrieveRelevantFactsOnlyStopWordsReturnsEmpty() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRelevantFacts(for: "I am so very")
        XCTAssertTrue(facts.isEmpty, "Should return empty when message contains only stop words")
    }

    func testRetrieveRelevantFactsUpdatesAccessTracking() throws {
        let (_, store, retriever) = try makeRetriever()

        // Get all facts before retrieval
        let before = try store.getAll()
        let allAccessCountsBefore = before.map { $0.accessCount }
        XCTAssertTrue(allAccessCountsBefore.allSatisfy { $0 == 0 }, "All access counts should start at 0")

        // Retrieve facts about sister
        let facts = try retriever.retrieveRelevantFacts(for: "Tell me about my sister Sarah")
        XCTAssertFalse(facts.isEmpty)

        // Check that returned facts now have updated access tracking
        for fact in facts {
            let updated = try store.getById(fact.id)
            XCTAssertEqual(updated?.accessCount, 1, "Returned fact should have access_count = 1")
            XCTAssertNotNil(updated?.lastAccessed, "Returned fact should have last_accessed set")
        }
    }

    func testRetrieveRelevantFactsMultiKeywordScoresHigher() throws {
        let (_, _, retriever) = try makeRetriever()

        // "morning meetings" should rank the morning meetings fact highest
        // because it matches two keywords
        let facts = try retriever.retrieveRelevantFacts(for: "I need to schedule a morning meeting")
        guard let firstFact = facts.first else {
            XCTFail("Should return at least one fact")
            return
        }
        XCTAssertTrue(
            firstFact.content.lowercased().contains("morning") &&
            firstFact.content.lowercased().contains("meeting"),
            "Fact matching multiple keywords should rank first. Got: \(firstFact.content)"
        )
    }

    // MARK: - Retrieve Recent Facts Tests

    func testRetrieveRecentFacts() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRecentFacts(limit: 3)
        XCTAssertEqual(facts.count, 3, "Should return exactly 3 recent facts")
    }

    func testRetrieveRecentFactsRespectsLimit() throws {
        let (_, _, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRecentFacts(limit: 2)
        XCTAssertEqual(facts.count, 2)
    }

    func testRetrieveRecentFactsUpdatesAccessTracking() throws {
        let (_, store, retriever) = try makeRetriever()

        let facts = try retriever.retrieveRecentFacts(limit: 2)
        for fact in facts {
            let updated = try store.getById(fact.id)
            XCTAssertEqual(updated?.accessCount, 1, "Recent facts should have access tracking updated")
        }
    }

    func testRetrieveRecentFactsEmptyDatabase() throws {
        let (_, _, retriever) = try makeRetriever(populate: false)

        let facts = try retriever.retrieveRecentFacts()
        XCTAssertTrue(facts.isEmpty, "Should return empty for empty database")
    }

    // MARK: - Scoring Tests

    func testHighImportanceFactsRankHigher() throws {
        let freshDb = try DatabaseManager(path: ":memory:")
        let freshStore = FactStore(database: freshDb)
        let freshRetriever = FactRetriever(factStore: freshStore)

        // Insert two facts with the same keyword but different importance
        try freshStore.insert(Fact.create(
            content: "User drinks coffee occasionally",
            category: .preference, confidence: 0.8, importance: 0.2
        ))
        try freshStore.insert(Fact.create(
            content: "User absolutely loves coffee and drinks it every morning",
            category: .preference, confidence: 0.8, importance: 0.9
        ))

        let facts = try freshRetriever.retrieveRelevantFacts(for: "coffee")
        XCTAssertEqual(facts.count, 2)
        // Higher importance fact should rank first
        XCTAssertTrue(
            facts[0].importance > facts[1].importance,
            "Higher importance fact should rank first"
        )
    }

    func testHighConfidenceFactsRankHigher() throws {
        let freshDb = try DatabaseManager(path: ":memory:")
        let freshStore = FactStore(database: freshDb)
        let freshRetriever = FactRetriever(factStore: freshStore)

        try freshStore.insert(Fact.create(
            content: "User might like hiking",
            category: .preference, confidence: 0.3, importance: 0.5
        ))
        try freshStore.insert(Fact.create(
            content: "User definitely enjoys hiking every weekend",
            category: .preference, confidence: 0.95, importance: 0.5
        ))

        let facts = try freshRetriever.retrieveRelevantFacts(for: "hiking")
        XCTAssertEqual(facts.count, 2)
        XCTAssertTrue(
            facts[0].confidence > facts[1].confidence,
            "Higher confidence fact should rank first"
        )
    }

    // MARK: - Performance Test

    func testRetrievalPerformanceWith1000Facts() throws {
        let db = try DatabaseManager(path: ":memory:")
        let store = FactStore(database: db)
        let retriever = FactRetriever(factStore: store)

        // Insert 1000 facts
        let categories = FactCategory.allCases
        for i in 0..<1000 {
            let category = categories[i % categories.count]
            try store.insert(Fact.create(
                content: "Fact number \(i) about topic \(i % 50) related to category \(category.rawValue)",
                category: category,
                confidence: Double.random(in: 0.3...1.0),
                importance: Double.random(in: 0.1...1.0)
            ))
        }

        // Measure retrieval time
        let start = CFAbsoluteTimeGetCurrent()
        let facts = try retriever.retrieveRelevantFacts(for: "topic related category preference")
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertFalse(facts.isEmpty, "Should find matching facts")
        XCTAssertLessThan(elapsed, 0.15, "Retrieval should complete in under 150ms for 1000 facts. Took \(elapsed * 1000)ms")
    }
}
