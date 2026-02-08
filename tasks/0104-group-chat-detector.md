# Task 0104: Group Chat Detection and Blocking

**Milestone:** M2 - iMessage Integration
**Unit:** 2.5 - Group Chat Detection
**Phase:** 1
**Depends On:** 0100
**Estimated Effort:** 1-2 hours
**Complexity:** Small

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `src/Core/Models/ChatMessage.swift` — The `ChatMessage` model. The `isGroupChat` and `chatId` properties are your primary inputs.
2. `src/Core/ChatDatabaseReader.swift` — The `isGroupChat(chatId:)` method. Your detector may use this for deeper verification.
3. `src/Core/MessageWatcher.swift` — You will integrate the group chat filter into the watcher's output pipeline.
4. `docs/research/imessage.md` — See the chat.db schema notes on `cache_roomnames` and `group_id`.
5. `docs/releases/mvp-scope.md` — Confirms group chat detection is MVP, group chat social mode is NOT.

> **Context Budget Note:** All context files are short. Read them in full.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing group chat detection and blocking for EmberHearth, a macOS personal AI assistant. In MVP, EmberHearth silently ignores all group chat messages — it only responds to direct (1-on-1) conversations.

## What You Are Building

A detector that:
1. Determines whether a `ChatMessage` belongs to a group chat
2. Provides a policy enum for future extensibility (block, readOnly, socialMode)
3. Filters group chat messages out of the message pipeline
4. Logs group chat detections for debugging

## Context: How Group Chats Are Identified in chat.db

There are three signals that indicate a message is from a group chat:

1. **`cache_roomnames` on the message table:** If this column is non-null and non-empty, the message is from a group chat. This is already decoded into `ChatMessage.isGroupChat` by the ChatDatabaseReader.

2. **`group_id` on the chat table:** If the chat associated with the message has a non-null, non-empty `group_id`, it is a group chat. This is checked by `ChatDatabaseReader.isGroupChat(chatId:)`.

3. **Participant count in `chat_handle_join`:** If a chat has more than one handle linked via the `chat_handle_join` table, it is a group chat. Also checked by `ChatDatabaseReader.isGroupChat(chatId:)`.

For MVP, signal #1 (`ChatMessage.isGroupChat`) is sufficient for fast filtering. Signals #2 and #3 are fallback verifications if needed.

## Files to Create

### 1. `src/Core/GroupChatDetector.swift`

```swift
import Foundation
import os.log

/// Policy for how EmberHearth handles group chat messages.
///
/// In MVP, only `.block` is supported. Future versions may allow read-only
/// monitoring or full social mode participation.
enum GroupChatPolicy: String, Codable, CaseIterable {
    /// Silently ignore all group chat messages. No response is sent.
    /// This is the only supported mode in MVP.
    case block

    /// Monitor group chats for context (read messages) but never respond.
    /// Future feature — not implemented in MVP.
    case readOnly

    /// Participate in group chats with social awareness.
    /// Responds when mentioned by name, maintains group context.
    /// Future feature — not implemented in MVP.
    case socialMode

    /// Human-readable description of the policy.
    var displayName: String {
        switch self {
        case .block:
            return "Block (silent ignore)"
        case .readOnly:
            return "Read Only (monitor, no responses)"
        case .socialMode:
            return "Social Mode (participate in group chats)"
        }
    }
}

/// Detects group chat messages and filters them based on the configured policy.
///
/// In MVP, all group chat messages are silently ignored (`.block` policy).
/// The detector checks the `isGroupChat` property on `ChatMessage`, which is
/// derived from the `cache_roomnames` column in chat.db.
///
/// For additional verification (e.g., when `cache_roomnames` is unexpectedly null
/// for a group chat), the detector can optionally query the `ChatDatabaseReader`
/// for deeper checks using the `chatId`.
///
/// ## Usage
/// ```swift
/// let detector = GroupChatDetector()
///
/// let messages: [ChatMessage] = watcher.getNewMessages()
/// let directMessages = detector.filterDirectMessages(messages)
/// // directMessages contains only 1-on-1 conversations
/// ```
final class GroupChatDetector {

    // MARK: - Properties

    /// The current group chat policy. Defaults to `.block` for MVP.
    /// Persisted in UserDefaults.
    var policy: GroupChatPolicy {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: Self.policyKey),
               let policy = GroupChatPolicy(rawValue: rawValue) {
                return policy
            }
            return .block  // MVP default
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Self.policyKey)
            logger.info("Group chat policy changed to: \(newValue.rawValue, privacy: .public)")
        }
    }

    /// Optional database reader for deeper group chat verification.
    /// If provided, the detector can check chat-level signals when the
    /// message-level signal is ambiguous.
    private let databaseReader: ChatDatabaseReader?

    /// Logger for group chat detection events.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "GroupChatDetector")

    /// UserDefaults key for the group chat policy.
    private static let policyKey = "com.emberhearth.groupchatdetector.policy"

    /// Counter for tracking group chat messages blocked in the current session.
    /// Useful for diagnostics and logging.
    private(set) var blockedMessageCount: Int = 0

    // MARK: - Initialization

    /// Creates a new GroupChatDetector.
    ///
    /// - Parameter databaseReader: Optional ChatDatabaseReader for deeper
    ///   group chat verification. If nil, only the message-level `isGroupChat`
    ///   property is used. Pass the same reader used by the MessageWatcher.
    init(databaseReader: ChatDatabaseReader? = nil) {
        self.databaseReader = databaseReader
    }

    // MARK: - Detection

    /// Determines whether a message belongs to a group chat.
    ///
    /// The primary detection signal is `ChatMessage.isGroupChat`, which is derived
    /// from the `cache_roomnames` column in chat.db. If a `ChatDatabaseReader` is
    /// available and the message has a `chatId`, a deeper check is also performed
    /// using the chat-level signals (group_id, participant count).
    ///
    /// - Parameter message: The message to check.
    /// - Returns: True if the message belongs to a group chat.
    func isGroupChat(_ message: ChatMessage) -> Bool {
        // Primary signal: message-level flag from cache_roomnames
        if message.isGroupChat {
            logger.info("Group chat detected (cache_roomnames) for message \(message.id)")
            return true
        }

        // Secondary signal: chat-level check via database reader
        if let chatId = message.chatId, let reader = databaseReader {
            do {
                let isGroup = try reader.isGroupChat(chatId: chatId)
                if isGroup {
                    logger.info("Group chat detected (chat-level) for message \(message.id), chatId: \(chatId)")
                    return true
                }
            } catch {
                // If the database query fails, err on the side of caution
                // and rely only on the message-level signal (which was false)
                logger.warning("Failed to verify group chat via database: \(error.localizedDescription, privacy: .public)")
            }
        }

        return false
    }

    // MARK: - Filtering

    /// Filters an array of messages, returning only direct (non-group) messages.
    ///
    /// Messages identified as group chat messages are silently dropped when
    /// the policy is `.block` (MVP default). The number of blocked messages
    /// is tracked in `blockedMessageCount`.
    ///
    /// - Parameter messages: The messages to filter.
    /// - Returns: Only the messages that are NOT from group chats.
    func filterDirectMessages(_ messages: [ChatMessage]) -> [ChatMessage] {
        var directMessages: [ChatMessage] = []
        var groupCount = 0

        for message in messages {
            if isGroupChat(message) {
                groupCount += 1
                handleGroupChatMessage(message)
            } else {
                directMessages.append(message)
            }
        }

        if groupCount > 0 {
            blockedMessageCount += groupCount
            logger.info("Filtered \(groupCount) group chat message(s). Total blocked this session: \(self.blockedMessageCount)")
        }

        return directMessages
    }

    /// Determines whether a message should be processed based on the current policy.
    ///
    /// - Parameter message: The message to evaluate.
    /// - Returns: True if the message should be processed (responded to).
    func shouldProcess(_ message: ChatMessage) -> Bool {
        if isGroupChat(message) {
            switch policy {
            case .block:
                return false
            case .readOnly:
                // Future: allow reading but not responding
                return false
            case .socialMode:
                // Future: allow full participation
                return true
            }
        }
        return true  // Direct messages are always processed
    }

    /// Resets the blocked message counter. Called at the start of a new session
    /// or for diagnostics.
    func resetBlockedCount() {
        blockedMessageCount = 0
    }

    // MARK: - Private

    /// Handles a group chat message according to the current policy.
    /// In MVP (.block), this is a no-op beyond logging.
    private func handleGroupChatMessage(_ message: ChatMessage) {
        switch policy {
        case .block:
            // Silent ignore — no response, just log
            logger.info("Blocked group chat message \(message.id) from \(message.phoneNumber ?? "unknown", privacy: .private)")
        case .readOnly:
            // Future: store for context without responding
            logger.info("Read-only group chat message \(message.id)")
        case .socialMode:
            // Future: process for social participation
            logger.info("Social mode group chat message \(message.id)")
        }
    }
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. All Swift files use PascalCase naming.
3. All classes and methods must have documentation comments.
4. Use `os.Logger` for logging (subsystem: "com.emberhearth.core", category: "GroupChatDetector").
5. Phone numbers in logs use `privacy: .private`.
6. The MVP policy is always `.block`. The other enum cases exist for forward compatibility but are not actively used.
7. When detection is uncertain and the database check fails, default to treating the message as a direct message (do not block — false positives are worse than false negatives here since blocking a real message is more harmful than accidentally processing a group message).

## Directory Structure

Create these files:
- `src/Core/GroupChatDetector.swift`
- `tests/Core/GroupChatDetectorTests.swift`

## Unit Tests

Create `tests/Core/GroupChatDetectorTests.swift`:

```swift
import XCTest
@testable import EmberHearth

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

    /// Creates a ChatMessage with the specified properties for testing.
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

    // MARK: - Detection Tests

    func testDirectMessageIsNotGroupChat() {
        let message = makeMessage(isGroupChat: false)
        XCTAssertFalse(detector.isGroupChat(message))
    }

    func testGroupChatMessageIsDetected() {
        let message = makeMessage(isGroupChat: true)
        XCTAssertTrue(detector.isGroupChat(message))
    }

    func testGroupChatDetectionWithCacheRoomnames() {
        // isGroupChat = true means cache_roomnames was non-null in chat.db
        let message = makeMessage(isGroupChat: true)
        XCTAssertTrue(detector.isGroupChat(message))
    }

    // MARK: - Policy Tests

    func testDefaultPolicyIsBlock() {
        XCTAssertEqual(detector.policy, .block)
    }

    func testPolicyPersists() {
        detector.policy = .readOnly
        let newDetector = GroupChatDetector()
        XCTAssertEqual(newDetector.policy, .readOnly)

        // Clean up
        detector.policy = .block
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

        // Filter more messages — count should accumulate
        _ = detector.filterDirectMessages(messages)
        XCTAssertEqual(detector.blockedMessageCount, 4)
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
        // Simulate a message that came from a group chat in chat.db
        // (cache_roomnames was non-null)
        let groupMessage = ChatMessage(
            id: 100,
            text: "Hey everyone!",
            date: Date(),
            isFromMe: false,
            handleId: 1,
            phoneNumber: "+15551234567",
            isGroupChat: true,  // This was set by ChatDatabaseReader
            chatId: 2
        )

        XCTAssertTrue(detector.isGroupChat(groupMessage))
        XCTAssertFalse(detector.shouldProcess(groupMessage))
    }

    func testDirectMessageFromDatabaseHasFlagClear() {
        // Simulate a direct message from chat.db
        // (cache_roomnames was null)
        let directMessage = ChatMessage(
            id: 101,
            text: "Hey Ember, remind me to call Mom",
            date: Date(),
            isFromMe: false,
            handleId: 1,
            phoneNumber: "+15551234567",
            isGroupChat: false,  // This was set by ChatDatabaseReader
            chatId: 1
        )

        XCTAssertFalse(detector.isGroupChat(directMessage))
        XCTAssertTrue(detector.shouldProcess(directMessage))
    }
}
```

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. There are no calls to Process(), /bin/bash, or any shell execution
4. The default policy is .block
5. Group chat messages are silently ignored (no response sent)
6. Direct messages pass through the filter unchanged
7. The blocked message count tracks correctly
8. Policy persists in UserDefaults
9. GroupChatPolicy is Codable for future settings serialization
10. All public methods have documentation comments
11. os.Logger is used with privacy: .private for phone numbers
```

---

## Acceptance Criteria

- [ ] `src/Core/GroupChatDetector.swift` exists with all specified types and methods
- [ ] `GroupChatPolicy` enum has `.block`, `.readOnly`, `.socialMode` cases
- [ ] Default policy is `.block`
- [ ] `isGroupChat(_ message:)` checks `ChatMessage.isGroupChat` flag
- [ ] `isGroupChat(_ message:)` optionally checks database reader for deeper verification
- [ ] `filterDirectMessages(_ messages:)` returns only non-group messages
- [ ] `shouldProcess(_ message:)` respects the current policy
- [ ] `blockedMessageCount` increments correctly and can be reset
- [ ] Policy persists in UserDefaults
- [ ] `GroupChatPolicy` is `Codable` and `CaseIterable`
- [ ] Group chat messages are logged at `.info` level
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging

---

## Verification Commands

```bash
# Build the project
cd /Users/robault/Documents/GitHub/emberhearth
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the GroupChatDetector tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/GroupChatDetectorTests 2>&1 | tail -30

# Verify no shell execution
grep -rn "Process()" src/ || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/ || echo "PASS: No /bin/bash references found"

# Verify GroupChatPolicy enum exists
grep -n "enum GroupChatPolicy" src/Core/GroupChatDetector.swift && echo "PASS: GroupChatPolicy enum found"

# Verify all three policy cases
grep -n "case block" src/Core/GroupChatDetector.swift && echo "PASS: block case found"
grep -n "case readOnly" src/Core/GroupChatDetector.swift && echo "PASS: readOnly case found"
grep -n "case socialMode" src/Core/GroupChatDetector.swift && echo "PASS: socialMode case found"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth GroupChatDetector implementation for correctness and completeness. Open these files:

@src/Core/GroupChatDetector.swift
@tests/Core/GroupChatDetectorTests.swift
@src/Core/Models/ChatMessage.swift
@src/Core/ChatDatabaseReader.swift

Check for these specific issues:

1. **Detection Accuracy:**
   - Is the primary signal (ChatMessage.isGroupChat from cache_roomnames) reliable?
   - Does the secondary signal (ChatDatabaseReader.isGroupChat) add value, or could it cause false positives?
   - What happens if both signals disagree? (e.g., cache_roomnames is null but chat has multiple participants)
   - Is the fallback behavior correct when the database query fails? (Should default to NOT blocking)

2. **Policy Logic:**
   - Does shouldProcess() correctly return false for .block and .readOnly policies?
   - Does shouldProcess() correctly return true for .socialMode?
   - Is the default policy .block?
   - Does the policy persist correctly?

3. **Filtering:**
   - Does filterDirectMessages preserve the order of direct messages?
   - Does it handle empty arrays?
   - Does it handle all-group or all-direct arrays?
   - Is blockedMessageCount updated atomically? (Thread safety concern)

4. **Edge Cases:**
   - What if a message has isGroupChat=false but chatId=nil? (Cannot do secondary check)
   - What if the databaseReader is nil? (Should still work with primary signal only)
   - What if UserDefaults has an invalid policy string?

5. **Testing:**
   - Are all three policy modes tested?
   - Is the blocked count accumulation tested?
   - Is the Codable conformance of GroupChatPolicy tested?
   - Are integration scenarios with ChatMessage tested?

Report issues with severity: CRITICAL, IMPORTANT, MINOR.
```

---

## Commit Message

```
feat(m2): add group chat detection and blocking
```

---

## Notes for Next Task

- `GroupChatDetector` is the last component of the M2 iMessage Integration milestone.
- The complete message pipeline from the M2 tasks is:
  1. `MessageWatcher` detects new messages via FSEvents (task 0101)
  2. `GroupChatDetector` filters out group chats (this task)
  3. `PhoneNumberFilter` filters to allowed numbers only (task 0103)
  4. Remaining messages are ready for LLM processing (M3 tasks)
  5. `MessageSender` sends responses back via AppleScript (task 0102)
- The pipeline integration (wiring these components together) will be a separate task in M3 or M4.
- The `.readOnly` and `.socialMode` policies are stubs for future versions. The settings UI (future task) will only show `.block` in MVP.
