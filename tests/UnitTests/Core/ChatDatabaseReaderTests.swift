import XCTest
import SQLite3
@testable import EmberHearth

final class ChatDatabaseReaderTests: XCTestCase {

    private var testDBPath: String!
    private var reader: ChatDatabaseReader!

    override func setUp() {
        super.setUp()
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

    func testDefaultDatabasePathPointsToUserLibrary() {
        let defaultReader = ChatDatabaseReader()
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(defaultReader.databasePath, "\(home)/Library/Messages/chat.db")
    }

    // MARK: - Query Tests

    func testFetchRecentMessages() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 10)
        XCTAssertFalse(messages.isEmpty, "Should return messages from test database")
        for i in 1..<messages.count {
            XCTAssertLessThanOrEqual(messages[i-1].date, messages[i].date)
        }
    }

    func testFetchRecentMessagesWithSinceDate() throws {
        try reader.open()
        let allMessages = try reader.fetchRecentMessages(limit: 100)
        XCTAssertGreaterThanOrEqual(allMessages.count, 2)

        let cutoff = allMessages[1].date
        let filtered = try reader.fetchRecentMessages(limit: 100, since: cutoff)
        XCTAssertTrue(filtered.allSatisfy { $0.date > cutoff })
    }

    func testFetchRecentMessagesRespectsLimit() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 2)
        XCTAssertLessThanOrEqual(messages.count, 2)
    }

    func testFetchMessagesForHandle() throws {
        try reader.open()
        let messages = try reader.fetchMessages(forHandle: "+15551234567", limit: 10)
        XCTAssertFalse(messages.isEmpty, "Should return messages for test handle")
        for message in messages {
            XCTAssertEqual(message.phoneNumber, "+15551234567")
        }
    }

    func testFetchMessagesForNonexistentHandle() throws {
        try reader.open()
        let messages = try reader.fetchMessages(forHandle: "+10000000000", limit: 10)
        XCTAssertTrue(messages.isEmpty)
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

    func testFetchMessagesSinceRowIdBeyondMax() throws {
        try reader.open()
        let maxId = try reader.getMaxRowId()
        let messages = try reader.fetchMessagesSince(rowId: maxId)
        XCTAssertTrue(messages.isEmpty)
    }

    func testFetchMessagesSinceRowIdReturnsAscendingOrder() throws {
        try reader.open()
        let messages = try reader.fetchMessagesSince(rowId: 0)
        for i in 1..<messages.count {
            XCTAssertGreaterThan(messages[i].id, messages[i-1].id)
        }
    }

    func testGetMaxRowId() throws {
        try reader.open()
        let maxId = try reader.getMaxRowId()
        XCTAssertGreaterThan(maxId, 0, "Max ROWID should be positive in test database")
    }

    // MARK: - Empty Database Tests

    func testFetchRecentMessagesOnEmptyDatabase() throws {
        let emptyPath = NSTemporaryDirectory() + "test_empty_\(UUID().uuidString).db"
        createEmptyDatabase(at: emptyPath)
        defer { try? FileManager.default.removeItem(atPath: emptyPath) }

        let emptyReader = ChatDatabaseReader(databasePath: emptyPath)
        defer { emptyReader.close() }

        try emptyReader.open()
        let messages = try emptyReader.fetchRecentMessages(limit: 10)
        XCTAssertTrue(messages.isEmpty)
    }

    func testGetMaxRowIdOnEmptyDatabase() throws {
        let emptyPath = NSTemporaryDirectory() + "test_empty_\(UUID().uuidString).db"
        createEmptyDatabase(at: emptyPath)
        defer { try? FileManager.default.removeItem(atPath: emptyPath) }

        let emptyReader = ChatDatabaseReader(databasePath: emptyPath)
        defer { emptyReader.close() }

        try emptyReader.open()
        let maxId = try emptyReader.getMaxRowId()
        XCTAssertEqual(maxId, 0)
    }

    // MARK: - Group Chat Detection

    func testIsGroupChatReturnsFalseForDirectMessage() throws {
        try reader.open()
        let result = try reader.isGroupChat(chatId: 1)
        XCTAssertFalse(result)
    }

    func testIsGroupChatReturnsTrueForGroupChat() throws {
        try reader.open()
        let result = try reader.isGroupChat(chatId: 2)
        XCTAssertTrue(result)
    }

    func testIsGroupChatReturnsFalseForNonexistentChat() throws {
        try reader.open()
        let result = try reader.isGroupChat(chatId: 9999)
        XCTAssertFalse(result)
    }

    func testGroupChatDetectedViaCacheRoomnames() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 100)
        let groupMsg = messages.first { $0.id == 4 }
        XCTAssertNotNil(groupMsg)
        XCTAssertTrue(groupMsg!.isGroupChat)
    }

    func testGroupChatDetectedViaGroupId() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 100)
        // Message 5 has no cache_roomnames but belongs to a chat with group_id
        let groupMsg = messages.first { $0.id == 5 }
        XCTAssertNotNil(groupMsg, "Message 5 should exist in test data")
        XCTAssertTrue(groupMsg!.isGroupChat, "Should detect group via group_id even without cache_roomnames")
    }

    func testDirectMessageNotMarkedAsGroup() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 100)
        let directMsg = messages.first { $0.id == 1 }
        XCTAssertNotNil(directMsg)
        XCTAssertFalse(directMsg!.isGroupChat)
    }

    // MARK: - Nil Text / Attachment-Only Messages

    func testMessageWithNilTextAndNilAttributedBody() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 100)
        let attachmentMsg = messages.first { $0.id == 6 }
        XCTAssertNotNil(attachmentMsg, "Attachment-only message should exist")
        XCTAssertNil(attachmentMsg!.text)
    }

    // MARK: - AttributedBody Decoding

    func testExtractTextFromAttributedBody() throws {
        try reader.open()
        let messages = try reader.fetchRecentMessages(limit: 100)
        let venturaMsg = messages.first { $0.id == 7 }
        XCTAssertNotNil(venturaMsg, "Ventura-style message should exist")
        XCTAssertNotNil(venturaMsg!.text, "Should extract text from attributedBody")
        XCTAssertFalse(venturaMsg!.text!.isEmpty)
    }

    func testExtractTextByScanning() {
        let text = ChatDatabaseReader.extractTextByScanning(Data())
        XCTAssertNil(text, "Empty data should return nil")

        let tinyData = Data([0x01, 0x02, 0x03])
        XCTAssertNil(ChatDatabaseReader.extractTextByScanning(tinyData), "Data under 10 bytes should return nil")
    }

    func testExtractTextFromAttributedBodyWithNilResult() {
        let garbage = Data(repeating: 0xFF, count: 64)
        let result = ChatDatabaseReader.extractTextFromAttributedBody(garbage)
        XCTAssertNil(result, "Garbage data should return nil")
    }

    // MARK: - Date Conversion Tests

    func testAppleNanosecondsToDate() {
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
        let seconds: Int64 = 726_926_400
        let date = ChatDatabaseReader.appleNanosecondsToDate(seconds)
        let expected = Date(timeIntervalSinceReferenceDate: 726_926_400)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, expected.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    func testDateConversionRoundTrip() {
        let original = Date()
        let nanoseconds = ChatDatabaseReader.dateToAppleNanoseconds(original)
        let roundTripped = ChatDatabaseReader.appleNanosecondsToDate(nanoseconds)
        XCTAssertEqual(original.timeIntervalSinceReferenceDate, roundTripped.timeIntervalSinceReferenceDate, accuracy: 1.0)
    }

    func testZeroTimestampConvertsToReferenceDate() {
        let date = ChatDatabaseReader.appleNanosecondsToDate(0)
        XCTAssertEqual(date.timeIntervalSinceReferenceDate, 0, accuracy: 0.001)
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

    func testChatMessageWithNilChatId() {
        let msg = ChatMessage(id: 1, text: "Hi", date: Date(), isFromMe: true, handleId: 1, phoneNumber: nil, isGroupChat: false, chatId: nil)
        XCTAssertNil(msg.chatId)
        XCTAssertNil(msg.phoneNumber)
    }

    // MARK: - Test Database Helpers

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

            INSERT INTO handle (ROWID, id) VALUES (1, '+15551234567');
            INSERT INTO handle (ROWID, id) VALUES (2, '+15559876543');
            INSERT INTO handle (ROWID, id) VALUES (3, '+15550001111');

            INSERT INTO chat (ROWID, chat_identifier, group_id) VALUES (1, '+15551234567', NULL);
            INSERT INTO chat (ROWID, chat_identifier, group_id) VALUES (2, 'chat000000000000000001', 'group-id-abc');

            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (1, 'Hello Ember', 726926400000000000, 0, 1, NULL);

            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (2, 'Hi there!', 726926460000000000, 1, 1, NULL);

            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (3, 'Can you help me?', 726926520000000000, 0, 2, NULL);

            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (4, 'Group message', 726926580000000000, 0, 3, 'chat000000000000000001');

            -- Message in group chat WITHOUT cache_roomnames (tests group_id fallback detection)
            INSERT INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
                VALUES (5, 'Another group msg', 726926640000000000, 0, 2, NULL);

            -- Attachment-only message: no text, no attributedBody
            INSERT INTO message (ROWID, text, attributedBody, date, is_from_me, handle_id, cache_roomnames)
                VALUES (6, NULL, NULL, 726926700000000000, 0, 1, NULL);

            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 1);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 2);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 3);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (2, 4);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (2, 5);
            INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 6);

            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (1, 1);
            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (2, 2);
            INSERT INTO chat_handle_join (chat_id, handle_id) VALUES (2, 3);
            """

        sqlite3_exec(db, schema, nil, nil, nil)

        insertAttributedBodyMessage(db: db)
    }

    /// Inserts a message with a real NSKeyedArchiver-encoded attributedBody blob
    /// to test the Ventura+ decoding path.
    private func insertAttributedBodyMessage(db: OpaquePointer?) {
        let testString = "Hello from attributedBody"
        let attributedString = NSAttributedString(string: testString)

        guard let data = try? NSKeyedArchiver.archivedData(
            withRootObject: attributedString,
            requiringSecureCoding: true
        ) else { return }

        let sql = "INSERT INTO message (ROWID, text, attributedBody, date, is_from_me, handle_id, cache_roomnames) VALUES (7, NULL, ?, 726926760000000000, 0, 1, NULL)"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, 1, buffer.baseAddress, Int32(data.count), nil)
        }

        sqlite3_step(statement)

        let joinSql = "INSERT INTO chat_message_join (chat_id, message_id) VALUES (1, 7)"
        sqlite3_exec(db, joinSql, nil, nil, nil)
    }

    /// Creates an empty database with the correct schema but no data.
    private func createEmptyDatabase(at path: String) {
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
            """

        sqlite3_exec(db, schema, nil, nil, nil)
    }
}
