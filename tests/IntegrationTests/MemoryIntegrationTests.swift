// MemoryIntegrationTests.swift
// EmberHearth
//
// Integration tests for the memory system: fact extraction, storage, and retrieval.

import XCTest
@testable import EmberHearthCore

/// Integration tests for the memory system.
///
/// Exercises `FactStore`, `FactRetriever`, `FactExtractor`, and `SessionManager`
/// together using an in-memory SQLite database. No file system side effects.
final class MemoryIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var db: DatabaseManager!
    private var factStore: FactStore!
    private var factRetriever: FactRetriever!
    private var factExtractor: FactExtractor!
    private var mockLLM: IntegrationMockLLMProvider!
    private var sessionManager: SessionManager!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        db = try! DatabaseManager(path: ":memory:")
        factStore = FactStore(database: db)
        factRetriever = FactRetriever(factStore: factStore)
        mockLLM = IntegrationMockLLMProvider()
        factExtractor = FactExtractor(llmProvider: mockLLM, factStore: factStore)
        sessionManager = SessionManager(database: db)
    }

    override func tearDown() {
        sessionManager = nil
        factExtractor = nil
        factRetriever = nil
        factStore = nil
        mockLLM = nil
        db = nil

        // Clean up any stale timeout we may have set in UserDefaults
        UserDefaults.standard.removeObject(forKey: SessionManager.staleTimeoutDefaultsKey)
        super.tearDown()
    }

    // MARK: - Fact Lifecycle Tests

    /// Facts inserted into the store should be retrievable by keyword search.
    func test_insertedFact_retrievableByKeyword() throws {
        let fact = TestData.fact(content: "User loves hiking in the mountains on weekends")
        try factStore.insert(fact)

        let results = try factRetriever.retrieveRelevantFacts(for: "hiking mountains")

        XCTAssertGreaterThan(results.count, 0, "Inserted fact should be retrievable by keyword")
        XCTAssertTrue(
            results.contains { $0.content.contains("hiking") },
            "Retrieved facts should include the hiking preference"
        )
    }

    /// Facts extracted via FactExtractor (LLM-based) should appear in the store.
    func test_factExtraction_storesAndRetrieves() async throws {
        let userMessage = "I really love hiking in the mountains on weekends"
        let emberResponse = "That sounds wonderful! Mountain hiking is a great way to spend weekends."

        // Mock the LLM to return a valid JSON fact extraction response
        mockLLM.nextResponse = """
            [{"content":"User loves hiking in the mountains on weekends","category":"preference","importance":0.7,"confidence":0.9}]
            """

        let extracted = try await factExtractor.extractFacts(
            from: userMessage,
            assistantResponse: emberResponse,
            existingFacts: []
        )

        XCTAssertGreaterThan(extracted.count, 0,
                             "At least one fact should be extracted from the conversation")

        let allFacts = try factStore.getAll()
        XCTAssertGreaterThan(allFacts.count, 0,
                             "Extracted facts should be persisted in the store")
    }

    /// A fact stored with a known keyword should be returned when that keyword is queried.
    func test_factRetrievedForRelevantQuery() throws {
        let fact = TestData.fact(content: "User's favorite color is blue", category: .preference)
        try factStore.insert(fact)

        let relevantFacts = try factRetriever.retrieveRelevantFacts(for: "What's my favorite color?")

        let factContents = relevantFacts.map { $0.content }
        XCTAssertTrue(
            factContents.contains { $0.contains("blue") },
            "Previously stored color preference should be retrieved for color-related queries"
        )
    }

    /// A fact should not be retrieved when the query has no overlapping keywords.
    func test_unrelatedFact_notRetrivedForUnrelatedQuery() throws {
        let fact = TestData.fact(content: "User prefers coffee over tea", category: .preference)
        try factStore.insert(fact)

        // Query about something completely unrelated
        let results = try factRetriever.retrieveRelevantFacts(for: "astronomy telescope stars")

        XCTAssertFalse(
            results.contains { $0.content.contains("coffee") },
            "Coffee preference should not be retrieved for an astronomy query"
        )
    }

    // MARK: - Duplicate Fact Handling

    /// Inserting a similar fact via `insertOrUpdate` should update rather than duplicate.
    func test_duplicateFactMerged() throws {
        let id1 = try factStore.insert(
            TestData.fact(content: "User likes coffee", confidence: 0.7, importance: 0.5)
        )

        // A more specific version of the same fact should merge, not duplicate
        let id2 = try factStore.insertOrUpdate(
            TestData.fact(content: "User likes coffee a lot", confidence: 0.9, importance: 0.6)
        )

        XCTAssertEqual(id1, id2, "Similar facts should be merged, not inserted as duplicates")

        let merged = try factStore.getById(id1)
        XCTAssertNotNil(merged, "Merged fact should still be retrievable")
        XCTAssertEqual(merged?.confidence, 0.9,
                       "Merged fact should retain the higher confidence score")
    }

    /// Inserting a clearly different fact should NOT merge with an existing fact.
    func test_differentFact_insertedSeparately() throws {
        try factStore.insert(TestData.fact(content: "User likes coffee", category: .preference))
        try factStore.insert(TestData.fact(content: "User has a dog named Max", category: .relationship))

        let allFacts = try factStore.getAll()
        XCTAssertEqual(allFacts.count, 2, "Two distinct facts should be stored separately")
    }

    // MARK: - Access Tracking

    /// Each call to `updateAccessTracking` should increment the access count by one.
    func test_factAccessCount_incrementsWithEachTracking() throws {
        let id = try factStore.insert(TestData.fact(content: "User has a dog named Max"))

        try factStore.updateAccessTracking(id: id)
        try factStore.updateAccessTracking(id: id)
        try factStore.updateAccessTracking(id: id)

        let fact = try factStore.getById(id)
        XCTAssertEqual(fact?.accessCount, 3,
                       "Access count should be 3 after three tracking updates")
        XCTAssertNotNil(fact?.lastAccessed,
                        "Last accessed timestamp should be set after tracking")
    }

    /// `retrieveRelevantFacts` should automatically update access tracking for returned facts.
    func test_retrievalUpdatesAccessTracking() throws {
        let id = try factStore.insert(TestData.fact(content: "User enjoys yoga"))

        // Access count starts at zero
        let factBefore = try factStore.getById(id)
        XCTAssertEqual(factBefore?.accessCount, 0)

        // Retrieval should increment access count
        _ = try factRetriever.retrieveRelevantFacts(for: "yoga exercise")

        let factAfter = try factStore.getById(id)
        XCTAssertGreaterThan(factAfter?.accessCount ?? 0, 0,
                             "Access count should increase after retrieval")
    }

    // MARK: - Session Lifecycle Tests

    /// Getting a session for a phone number should create one if none exists.
    func test_sessionCreation_createsNewSessionForNewPhone() throws {
        let session = try sessionManager.getOrCreateSession(for: TestData.authorizedPhone)

        XCTAssertTrue(session.isActive, "Newly created session should be active")
        XCTAssertEqual(session.phoneNumber, TestData.authorizedPhone)
        XCTAssertEqual(session.messageCount, 0, "New session should have no messages")
    }

    /// Messages added to a session should be retrievable in chronological order.
    func test_sessionMessageTracking_storesAndReturnsMessages() throws {
        let session = try sessionManager.getOrCreateSession(for: TestData.authorizedPhone)

        try sessionManager.addMessage(to: session, role: .user, content: "Hello Ember!")
        try sessionManager.addMessage(to: session, role: .assistant, content: "Hi there! How can I help?")

        let messages = try sessionManager.getRecentMessages(for: session)

        XCTAssertEqual(messages.count, 2, "Session should have exactly 2 messages")
        XCTAssertEqual(messages[0].role, .user, "First message should be from the user")
        XCTAssertEqual(messages[0].content, "Hello Ember!")
        XCTAssertEqual(messages[1].role, .assistant, "Second message should be from the assistant")
    }

    /// Getting a session for the same phone number twice should return the same session.
    func test_sessionRetrieval_returnsSameActiveSession() throws {
        let session1 = try sessionManager.getOrCreateSession(for: TestData.authorizedPhone)
        let session2 = try sessionManager.getOrCreateSession(for: TestData.authorizedPhone)

        XCTAssertEqual(session1.id, session2.id,
                       "Second call should return the same active session")
    }

    /// A stale session should be automatically ended and replaced with a new session.
    func test_staleSession_replacedWithNewSession() throws {
        // Create a session and set the stale timeout to an extremely short value
        let phone = TestData.authorizedPhone
        let oldSession = try sessionManager.getOrCreateSession(for: phone)

        // Add a message so "last activity" is tracked
        try sessionManager.addMessage(to: oldSession, role: .user, content: "Hello")

        // Set the stale timeout to 0.001 seconds (effectively immediate staleness)
        UserDefaults.standard.set(0.001, forKey: SessionManager.staleTimeoutDefaultsKey)

        // Wait a moment to ensure the session is past the stale threshold
        Thread.sleep(forTimeInterval: 0.01)

        // Request a session again — should detect staleness and create a new one
        let newSession = try sessionManager.getOrCreateSession(for: phone)

        XCTAssertNotEqual(oldSession.id, newSession.id,
                          "A stale session should result in a new session being created")
        XCTAssertTrue(newSession.isActive, "The replacement session should be active")
    }

    // MARK: - Multi-Session Isolation

    /// Sessions for different phone numbers should be independent.
    func test_differentPhoneNumbers_haveSeparateSessions() throws {
        let session1 = try sessionManager.getOrCreateSession(for: "+15551111111")
        let session2 = try sessionManager.getOrCreateSession(for: "+15552222222")

        XCTAssertNotEqual(session1.id, session2.id,
                          "Different phone numbers should have separate sessions")

        try sessionManager.addMessage(to: session1, role: .user, content: "Message for user 1")

        let messages1 = try sessionManager.getRecentMessages(for: session1)
        let messages2 = try sessionManager.getRecentMessages(for: session2)

        XCTAssertEqual(messages1.count, 1, "Session 1 should have 1 message")
        XCTAssertEqual(messages2.count, 0, "Session 2 should have 0 messages (isolated)")
    }
}
