import XCTest
@testable import EmberHearth

// MARK: - Mock GroupChatChecking

/// A controllable mock for testing the secondary detection path in
/// `GroupChatDetector` without requiring a real SQLite database.
private final class MockGroupChatChecker: GroupChatChecking {

    /// When non-nil, `isGroupChat(chatId:)` throws this error instead of
    /// returning a value.
    var errorToThrow: Error?

    /// The value returned by `isGroupChat(chatId:)` when `errorToThrow` is nil.
    var isGroupChatResult: Bool = false

    /// Records every `chatId` passed to `isGroupChat(chatId:)`.
    private(set) var queriedChatIds: [Int64] = []

    func isGroupChat(chatId: Int64) throws -> Bool {
        queriedChatIds.append(chatId)
        if let error = errorToThrow {
            throw error
        }
        return isGroupChatResult
    }
}

// MARK: - Tests

final class GroupChatDetectorTests: XCTestCase {

    private var detector: GroupChatDetector!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "com.emberhearth.groupchatdetector.policy")
        detector = GroupChatDetector()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "com.emberhearth.groupchatdetector.policy")
        super.tearDown()
    }

    // MARK: - Helper

    private func makeMessage(
        id: Int64 = 1,
        text: String? = "Test message",
        isFromMe: Bool = false,
        phoneNumber: String? = "+15551234567",
        isGroupChat: Bool = false,
        chatId: Int64? = 1
    ) -> ChatMessage {
        return ChatMessage(
            id: id,
            text: text,
            date: Date(),
            isFromMe: isFromMe,
            handleId: 1,
            phoneNumber: phoneNumber,
            isGroupChat: isGroupChat,
            chatId: chatId
        )
    }

    // MARK: - Primary Signal Detection Tests

    func testDirectMessageIsNotGroupChat() {
        let message = makeMessage(isGroupChat: false)
        XCTAssertFalse(detector.isGroupChat(message))
    }

    func testGroupChatMessageIsDetected() {
        let message = makeMessage(isGroupChat: true)
        XCTAssertTrue(detector.isGroupChat(message))
    }

    func testPrimarySignalShortCircuitsWithoutQueryingChecker() {
        let mock = MockGroupChatChecker()
        let detectorWithMock = GroupChatDetector(groupChatChecker: mock)

        let message = makeMessage(isGroupChat: true, chatId: 42)
        XCTAssertTrue(detectorWithMock.isGroupChat(message))
        XCTAssertTrue(mock.queriedChatIds.isEmpty,
                      "Checker should not be queried when primary signal is already true")
    }

    // MARK: - Secondary Signal Detection Tests

    func testSecondarySignalDetectsGroupChatWhenPrimaryIsFalse() {
        let mock = MockGroupChatChecker()
        mock.isGroupChatResult = true
        let detectorWithMock = GroupChatDetector(groupChatChecker: mock)

        let message = makeMessage(isGroupChat: false, chatId: 42)
        XCTAssertTrue(detectorWithMock.isGroupChat(message))
        XCTAssertEqual(mock.queriedChatIds, [42])
    }

    func testSecondarySignalReturnsFalseWhenBothSignalsSayDirect() {
        let mock = MockGroupChatChecker()
        mock.isGroupChatResult = false
        let detectorWithMock = GroupChatDetector(groupChatChecker: mock)

        let message = makeMessage(isGroupChat: false, chatId: 7)
        XCTAssertFalse(detectorWithMock.isGroupChat(message))
        XCTAssertEqual(mock.queriedChatIds, [7])
    }

    func testSecondarySignalErrorFallsBackToNotBlocking() {
        let mock = MockGroupChatChecker()
        mock.errorToThrow = ChatDatabaseError.databaseLocked
        let detectorWithMock = GroupChatDetector(groupChatChecker: mock)

        let message = makeMessage(isGroupChat: false, chatId: 99)
        XCTAssertFalse(detectorWithMock.isGroupChat(message),
                       "When the secondary check throws, the detector must not block the message")
        XCTAssertEqual(mock.queriedChatIds, [99])
    }

    func testSecondarySignalSkippedWhenChatIdIsNil() {
        let mock = MockGroupChatChecker()
        mock.isGroupChatResult = true
        let detectorWithMock = GroupChatDetector(groupChatChecker: mock)

        let message = makeMessage(isGroupChat: false, chatId: nil)
        XCTAssertFalse(detectorWithMock.isGroupChat(message))
        XCTAssertTrue(mock.queriedChatIds.isEmpty,
                      "Checker should not be queried when chatId is nil")
    }

    func testNilCheckerReliesOnPrimarySignalOnly() {
        let detectorNoChecker = GroupChatDetector(groupChatChecker: nil)

        let directMessage = makeMessage(isGroupChat: false, chatId: 42)
        XCTAssertFalse(detectorNoChecker.isGroupChat(directMessage))

        let groupMessage = makeMessage(isGroupChat: true, chatId: 42)
        XCTAssertTrue(detectorNoChecker.isGroupChat(groupMessage))
    }

    // MARK: - Policy Tests

    func testDefaultPolicyIsBlock() {
        XCTAssertEqual(detector.policy, .block)
    }

    func testPolicyPersistsAcrossInstances() {
        detector.policy = .readOnly
        let newDetector = GroupChatDetector()
        XCTAssertEqual(newDetector.policy, .readOnly)
    }

    func testInvalidUserDefaultsPolicyFallsBackToBlock() {
        UserDefaults.standard.set("nonexistentPolicy", forKey: "com.emberhearth.groupchatdetector.policy")
        let freshDetector = GroupChatDetector()
        XCTAssertEqual(freshDetector.policy, .block,
                       "Unrecognized policy strings in UserDefaults must fall back to .block")
    }

    func testShouldProcessDirectMessage() {
        let message = makeMessage(isGroupChat: false)
        XCTAssertTrue(detector.shouldProcess(message))
    }

    func testShouldNotProcessGroupChatInBlockMode() {
        detector.policy = .block
        let message = makeMessage(isGroupChat: true)
        XCTAssertFalse(detector.shouldProcess(message))
    }

    func testShouldNotProcessGroupChatInReadOnlyMode() {
        detector.policy = .readOnly
        let message = makeMessage(isGroupChat: true)
        XCTAssertFalse(detector.shouldProcess(message))
    }

    func testShouldProcessGroupChatInSocialMode() {
        detector.policy = .socialMode
        let message = makeMessage(isGroupChat: true)
        XCTAssertTrue(detector.shouldProcess(message))
    }

    // MARK: - Filtering Tests

    func testFilterDirectMessagesRemovesGroupChats() {
        let messages = [
            makeMessage(id: 1, isGroupChat: false),
            makeMessage(id: 2, isGroupChat: true),
            makeMessage(id: 3, isGroupChat: false),
            makeMessage(id: 4, isGroupChat: true),
        ]

        let direct = detector.filterDirectMessages(messages)
        XCTAssertEqual(direct.count, 2)
        XCTAssertEqual(direct[0].id, 1)
        XCTAssertEqual(direct[1].id, 3)
    }

    func testFilterDirectMessagesPreservesOrderOfDirectMessages() {
        let messages = [
            makeMessage(id: 10, isGroupChat: false),
            makeMessage(id: 20, isGroupChat: true),
            makeMessage(id: 30, isGroupChat: false),
            makeMessage(id: 40, isGroupChat: true),
            makeMessage(id: 50, isGroupChat: false),
        ]

        let direct = detector.filterDirectMessages(messages)
        XCTAssertEqual(direct.map(\.id), [10, 30, 50])
    }

    func testFilterDirectMessagesWithAllDirect() {
        let messages = [
            makeMessage(id: 1, isGroupChat: false),
            makeMessage(id: 2, isGroupChat: false),
        ]

        let direct = detector.filterDirectMessages(messages)
        XCTAssertEqual(direct.count, 2)
    }

    func testFilterDirectMessagesWithAllGroup() {
        let messages = [
            makeMessage(id: 1, isGroupChat: true),
            makeMessage(id: 2, isGroupChat: true),
        ]

        let direct = detector.filterDirectMessages(messages)
        XCTAssertEqual(direct.count, 0)
    }

    func testFilterDirectMessagesWithEmptyArray() {
        let direct = detector.filterDirectMessages([])
        XCTAssertEqual(direct.count, 0)
    }

    func testFilterUsesSecondarySignalViaMock() {
        let mock = MockGroupChatChecker()
        mock.isGroupChatResult = true
        let detectorWithMock = GroupChatDetector(groupChatChecker: mock)

        let messages = [
            makeMessage(id: 1, isGroupChat: false, chatId: 100),
            makeMessage(id: 2, isGroupChat: false, chatId: 200),
        ]

        let direct = detectorWithMock.filterDirectMessages(messages)
        XCTAssertEqual(direct.count, 0,
                       "Both messages should be filtered because the mock says their chats are groups")
        XCTAssertEqual(mock.queriedChatIds, [100, 200])
    }

    // MARK: - Blocked Count Tests

    func testBlockedMessageCountIncrementsCorrectly() {
        XCTAssertEqual(detector.blockedMessageCount, 0)

        let messages = [
            makeMessage(id: 1, isGroupChat: true),
            makeMessage(id: 2, isGroupChat: true),
            makeMessage(id: 3, isGroupChat: false),
        ]

        _ = detector.filterDirectMessages(messages)
        XCTAssertEqual(detector.blockedMessageCount, 2)

        _ = detector.filterDirectMessages(messages)
        XCTAssertEqual(detector.blockedMessageCount, 4)
    }

    func testBlockedCountNotIncrementedWhenNoGroupMessages() {
        let messages = [
            makeMessage(id: 1, isGroupChat: false),
            makeMessage(id: 2, isGroupChat: false),
        ]

        _ = detector.filterDirectMessages(messages)
        XCTAssertEqual(detector.blockedMessageCount, 0)
    }

    func testResetBlockedCount() {
        let messages = [makeMessage(id: 1, isGroupChat: true)]
        _ = detector.filterDirectMessages(messages)
        XCTAssertEqual(detector.blockedMessageCount, 1)

        detector.resetBlockedCount()
        XCTAssertEqual(detector.blockedMessageCount, 0)
    }

    // MARK: - GroupChatPolicy Tests

    func testPolicyDisplayNames() {
        XCTAssertEqual(GroupChatPolicy.block.displayName, "Block (silent ignore)")
        XCTAssertEqual(GroupChatPolicy.readOnly.displayName, "Read Only (monitor, no responses)")
        XCTAssertEqual(GroupChatPolicy.socialMode.displayName, "Social Mode (participate in group chats)")
    }

    func testPolicyCaseIterable() {
        XCTAssertEqual(GroupChatPolicy.allCases.count, 3)
    }

    func testPolicyCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for policy in GroupChatPolicy.allCases {
            let data = try encoder.encode(policy)
            let decoded = try decoder.decode(GroupChatPolicy.self, from: data)
            XCTAssertEqual(decoded, policy)
        }
    }

    // MARK: - Integration with ChatMessage Model

    func testGroupChatMessageFromDatabaseHasFlagSet() {
        let groupMessage = ChatMessage(
            id: 100,
            text: "Hey everyone!",
            date: Date(),
            isFromMe: false,
            handleId: 1,
            phoneNumber: "+15551234567",
            isGroupChat: true,
            chatId: 2
        )

        XCTAssertTrue(detector.isGroupChat(groupMessage))
        XCTAssertFalse(detector.shouldProcess(groupMessage))
    }

    func testDirectMessageFromDatabaseHasFlagClear() {
        let directMessage = ChatMessage(
            id: 101,
            text: "Hey Ember, remind me to call Mom",
            date: Date(),
            isFromMe: false,
            handleId: 1,
            phoneNumber: "+15551234567",
            isGroupChat: false,
            chatId: 1
        )

        XCTAssertFalse(detector.isGroupChat(directMessage))
        XCTAssertTrue(detector.shouldProcess(directMessage))
    }
}
