import XCTest
import Combine
import SQLite3
@testable import EmberHearth

final class MessageWatcherTests: XCTestCase {

    private var testDBPath: String!
    private var reader: ChatDatabaseReader!
    private var watcher: MessageWatcher!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        testDBPath = NSTemporaryDirectory() + "test_watcher_\(UUID().uuidString).db"
        createTestDatabase(at: testDBPath)
        reader = ChatDatabaseReader(databasePath: testDBPath)
        watcher = MessageWatcher(
            databaseReader: reader,
            chatDBPath: testDBPath,
            debounceInterval: 0.1
        )
        // Reset persisted ROWID to ensure a clean slate for each test.
        watcher.resetLastProcessedRowId()
    }

    override func tearDown() {
        watcher.stop()
        watcher.resetLastProcessedRowId()
        cancellables.removeAll()
        try? FileManager.default.removeItem(atPath: testDBPath)
        super.tearDown()
    }

    // MARK: - Lifecycle Tests

    func testStartSucceeds() throws {
        XCTAssertFalse(watcher.isRunning)
        try watcher.start()
        XCTAssertTrue(watcher.isRunning)
    }

    func testStartWithNonexistentDatabase() {
        let badWatcher = MessageWatcher(
            chatDBPath: "/nonexistent/path/chat.db",
            debounceInterval: 0.1
        )
        XCTAssertThrowsError(try badWatcher.start()) { error in
            guard case ChatDatabaseError.databaseNotFound = error else {
                XCTFail("Expected databaseNotFound error, got \(error)")
                return
            }
        }
    }

    func testDoubleStartIsNoOp() throws {
        try watcher.start()
        XCTAssertTrue(watcher.isRunning)
        try watcher.start()
        XCTAssertTrue(watcher.isRunning)
    }

    func testStopStopsWatching() throws {
        try watcher.start()
        XCTAssertTrue(watcher.isRunning)
        watcher.stop()
        XCTAssertFalse(watcher.isRunning)
    }

    func testStopIsIdempotent() {
        watcher.stop()
        XCTAssertFalse(watcher.isRunning)
    }

    // MARK: - ROWID Tracking Tests

    func testLastProcessedRowIdInitializesToMaxOnFirstStart() throws {
        try watcher.start()

        let expectation = XCTestExpectation(description: "No messages expected")
        expectation.isInverted = true

        watcher.newMessagesPublisher
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testResetLastProcessedRowId() throws {
        try watcher.start()
        watcher.stop()
        watcher.resetLastProcessedRowId()

        let key = "com.emberhearth.messagewatcher.lastProcessedRowId"
        XCTAssertEqual(UserDefaults.standard.value(forKey: key) as? Int64 ?? 0, 0)
    }

    // MARK: - Debouncing Tests

    func testDebounceCoalescesRapidChanges() throws {
        try watcher.start()

        var receivedCount = 0
        let expectation = XCTestExpectation(description: "Messages received")

        watcher.newMessagesPublisher
            .sink { _ in
                receivedCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)

        insertTestMessage(at: testDBPath, rowId: 100, text: "Rapid 1", isFromMe: false)
        insertTestMessage(at: testDBPath, rowId: 101, text: "Rapid 2", isFromMe: false)
        insertTestMessage(at: testDBPath, rowId: 102, text: "Rapid 3", isFromMe: false)

        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 3.0)

        XCTAssertLessThanOrEqual(receivedCount, 2)
    }

    // MARK: - Message Filtering Tests

    func testOnlyIncomingMessagesArePublished() throws {
        try watcher.start()

        let expectation = XCTestExpectation(description: "Only incoming messages")

        watcher.newMessagesPublisher
            .sink { messages in
                for message in messages {
                    XCTAssertFalse(message.isFromMe, "Outgoing messages should be filtered out")
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)

        insertTestMessage(at: testDBPath, rowId: 200, text: "Outgoing", isFromMe: true)
        insertTestMessage(at: testDBPath, rowId: 201, text: "Incoming", isFromMe: false)

        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 3.0)
    }

    func testOutgoingOnlyBatchDoesNotPublish() throws {
        try watcher.start()

        let expectation = XCTestExpectation(description: "No publish for outgoing-only batch")
        expectation.isInverted = true

        watcher.newMessagesPublisher
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)

        insertTestMessage(at: testDBPath, rowId: 300, text: "Outgoing only", isFromMe: true)
        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Delegate Tests

    func testDelegateIsNotified() throws {
        let delegateHelper = MockMessageWatcherDelegate()
        watcher.delegate = delegateHelper

        try watcher.start()

        let expectation = XCTestExpectation(description: "Delegate notified")
        delegateHelper.onMessagesReceived = { messages in
            XCTAssertFalse(messages.isEmpty)
            expectation.fulfill()
        }

        insertTestMessage(at: testDBPath, rowId: 400, text: "Delegate test", isFromMe: false)
        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 3.0)
    }

    func testDelegateAndPublisherBothFire() throws {
        let delegateHelper = MockMessageWatcherDelegate()
        watcher.delegate = delegateHelper

        try watcher.start()

        let publisherExpectation = XCTestExpectation(description: "Publisher fired")
        let delegateExpectation = XCTestExpectation(description: "Delegate fired")

        watcher.newMessagesPublisher
            .sink { _ in publisherExpectation.fulfill() }
            .store(in: &cancellables)

        delegateHelper.onMessagesReceived = { _ in delegateExpectation.fulfill() }

        insertTestMessage(at: testDBPath, rowId: 500, text: "Both channels", isFromMe: false)
        touchFile(at: testDBPath)

        wait(for: [publisherExpectation, delegateExpectation], timeout: 3.0)
    }

    // MARK: - Helpers

    /// Creates a minimal test database with one pre-existing message.
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

            INSERT INTO handle (ROWID, id) VALUES (1, '+15551234567');
            INSERT INTO chat (ROWID, chat_identifier, group_id) VALUES (1, '+15551234567', NULL);

            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (1, 'Existing message', 726926400000000000, 0, 1, NULL);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 1);
            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (1, 1);
            """

        sqlite3_exec(db, schema, nil, nil, nil)
    }

    /// Inserts a test message into the database to simulate a new message arriving.
    /// Uses parameterized queries to avoid SQL injection from test data.
    private func insertTestMessage(at path: String, rowId: Int64, text: String, isFromMe: Bool) {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        var msgStmt: OpaquePointer?
        let msgSQL = "INSERT OR REPLACE INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames) VALUES (?1, ?2, ?3, ?4, ?5, NULL)"
        if sqlite3_prepare_v2(db, msgSQL, -1, &msgStmt, nil) == SQLITE_OK {
            sqlite3_bind_int64(msgStmt, 1, rowId)
            text.withCString { sqlite3_bind_text(msgStmt, 2, $0, -1, sqliteTransient) }
            sqlite3_bind_int64(msgStmt, 3, 726926400000000000)
            sqlite3_bind_int(msgStmt, 4, isFromMe ? 1 : 0)
            sqlite3_bind_int(msgStmt, 5, 1)
            sqlite3_step(msgStmt)
        }
        sqlite3_finalize(msgStmt)

        var joinStmt: OpaquePointer?
        let joinSQL = "INSERT OR REPLACE INTO chat_message_join (chat_id, message_id) VALUES (?1, ?2)"
        if sqlite3_prepare_v2(db, joinSQL, -1, &joinStmt, nil) == SQLITE_OK {
            sqlite3_bind_int(joinStmt, 1, 1)
            sqlite3_bind_int64(joinStmt, 2, rowId)
            sqlite3_step(joinStmt)
        }
        sqlite3_finalize(joinStmt)
    }

    /// Touches the file to reliably trigger a file system event.
    /// Updates the modification timestamp via utimes(), which fires
    /// the DispatchSource's .write/.extend events.
    private func touchFile(at path: String) {
        path.withCString { cPath in
            var times = [timeval](repeating: timeval(), count: 2)
            gettimeofday(&times[0], nil)
            times[1] = times[0]
            utimes(cPath, times)
        }
    }
}

// MARK: - Mock Delegate

private final class MockMessageWatcherDelegate: MessageWatcherDelegate {
    var onMessagesReceived: (([ChatMessage]) -> Void)?
    var onError: ((Error) -> Void)?

    func messageWatcher(_ watcher: MessageWatcher, didReceiveMessages messages: [ChatMessage]) {
        onMessagesReceived?(messages)
    }

    func messageWatcher(_ watcher: MessageWatcher, didEncounterError error: Error) {
        onError?(error)
    }
}
