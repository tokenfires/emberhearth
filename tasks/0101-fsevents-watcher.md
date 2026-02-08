# Task 0101: FSEvents Message Watcher

**Milestone:** M2 - iMessage Integration
**Unit:** 2.2 - FSEvents Monitoring
**Phase:** 1
**Depends On:** 0100
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `src/Core/ChatDatabaseReader.swift` — The reader created in task 0100. You will use `fetchMessagesSince(rowId:)` and `getMaxRowId()`.
2. `src/Core/Models/ChatMessage.swift` — The message model you are publishing.
3. `docs/architecture/decisions/0010-fsevents-data-monitoring.md` — The ADR for FSEvents monitoring. Note the change detection pattern using ROWID tracking.
4. `docs/research/imessage.md` — See "Detecting New Messages" section for the DispatchSource approach.
5. `CLAUDE.md` — Project conventions.

> **Context Budget Note:** All context files are short. Read them in full.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the FSEvents message watcher for EmberHearth, a macOS personal AI assistant. The ChatDatabaseReader from the previous task (0100) already exists and provides read-only access to ~/Library/Messages/chat.db.

## What You Are Building

A file system watcher that monitors chat.db for changes, detects new incoming messages, and publishes them to subscribers. When chat.db is modified (because a new message arrived), the watcher queries for messages with ROWIDs higher than the last processed one.

## Files to Create

### 1. `src/Core/MessageWatcher.swift`

```swift
import Foundation
import Combine
import os.log

/// Delegate protocol for receiving new message notifications.
///
/// Implement this protocol as an alternative to subscribing to the Combine publisher.
/// Both the delegate and the publisher fire for each new message.
protocol MessageWatcherDelegate: AnyObject {
    /// Called when new incoming messages are detected.
    ///
    /// - Parameter messages: The new messages, sorted by ROWID ascending.
    ///   These are only incoming messages (isFromMe == false).
    func messageWatcher(_ watcher: MessageWatcher, didReceiveMessages messages: [ChatMessage])

    /// Called when the watcher encounters an error.
    ///
    /// - Parameter error: The error that occurred.
    func messageWatcher(_ watcher: MessageWatcher, didEncounterError error: Error)
}

/// Monitors the iMessage chat.db file for new incoming messages.
///
/// Uses `DispatchSource.makeFileSystemObjectSource` to watch the chat.db file
/// for write events. When a change is detected, it queries for new messages
/// using the `ChatDatabaseReader` and publishes them.
///
/// ## Usage
/// ```swift
/// let watcher = MessageWatcher()
/// watcher.delegate = self
///
/// // Or use Combine:
/// watcher.newMessagesPublisher
///     .sink { messages in
///         // Handle new messages
///     }
///     .store(in: &cancellables)
///
/// try watcher.start()
/// ```
///
/// ## Thread Safety
/// The watcher processes events on a dedicated serial dispatch queue.
/// Delegate callbacks and Combine events are delivered on this queue.
/// Callers should dispatch to the main queue if needed for UI updates.
final class MessageWatcher {

    // MARK: - Properties

    /// Combine publisher that emits arrays of new incoming messages.
    /// Each emission contains one or more new messages detected in a single check.
    let newMessagesPublisher: AnyPublisher<[ChatMessage], Never>

    /// The delegate to notify when new messages arrive.
    weak var delegate: MessageWatcherDelegate?

    /// The ChatDatabaseReader used to query for new messages.
    private let databaseReader: ChatDatabaseReader

    /// The file path to the chat.db file being monitored.
    private let chatDBPath: String

    /// The serial queue for processing file system events.
    private let watcherQueue = DispatchQueue(label: "com.emberhearth.messagewatcher", qos: .userInitiated)

    /// The file descriptor for the chat.db file (used by DispatchSource).
    private var fileDescriptor: Int32 = -1

    /// The DispatchSource watching the file descriptor for write events.
    private var dispatchSource: DispatchSourceFileSystemObject?

    /// The PassthroughSubject backing the Combine publisher.
    private let messageSubject = PassthroughSubject<[ChatMessage], Never>()

    /// The ROWID of the last processed message. Messages with ROWID > this value
    /// are considered new. Persisted in UserDefaults across app launches.
    private var lastProcessedRowId: Int64 {
        get { UserDefaults.standard.value(forKey: Self.lastRowIdKey) as? Int64 ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastRowIdKey) }
    }

    /// UserDefaults key for persisting the last processed ROWID.
    private static let lastRowIdKey = "com.emberhearth.messagewatcher.lastProcessedRowId"

    /// Whether the watcher is currently active.
    private(set) var isRunning = false

    /// Debounce interval in seconds. Rapid successive file changes within this
    /// window are coalesced into a single check.
    let debounceInterval: TimeInterval

    /// Work item for debouncing. Cancelled and recreated on each file change event.
    private var debounceWorkItem: DispatchWorkItem?

    /// Logger for watcher operations.
    private let logger = Logger(subsystem: "com.emberhearth.core", category: "MessageWatcher")

    // MARK: - Initialization

    /// Creates a new MessageWatcher.
    ///
    /// - Parameters:
    ///   - databaseReader: The ChatDatabaseReader to use for querying messages.
    ///     If nil, a new reader with the default database path is created.
    ///   - chatDBPath: The path to the chat.db file to monitor.
    ///     If nil, defaults to ~/Library/Messages/chat.db.
    ///   - debounceInterval: Seconds to wait after a file change before querying.
    ///     Defaults to 0.5 seconds. This coalesces rapid successive writes.
    init(
        databaseReader: ChatDatabaseReader? = nil,
        chatDBPath: String? = nil,
        debounceInterval: TimeInterval = 0.5
    ) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let resolvedPath = chatDBPath ?? "\(home)/Library/Messages/chat.db"

        self.chatDBPath = resolvedPath
        self.databaseReader = databaseReader ?? ChatDatabaseReader(databasePath: resolvedPath)
        self.debounceInterval = debounceInterval
        self.newMessagesPublisher = messageSubject.eraseToAnyPublisher()
    }

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Starts monitoring chat.db for new messages.
    ///
    /// This method:
    /// 1. Opens a file descriptor on chat.db
    /// 2. Initializes the last processed ROWID if not already set
    /// 3. Creates a DispatchSource to watch for write events
    /// 4. Begins monitoring
    ///
    /// - Throws: `ChatDatabaseError.databaseNotFound` if chat.db doesn't exist.
    ///           Other errors if the database cannot be opened.
    func start() throws {
        guard !isRunning else {
            logger.warning("MessageWatcher is already running")
            return
        }

        // Verify the file exists
        guard FileManager.default.fileExists(atPath: chatDBPath) else {
            logger.error("chat.db not found at: \(self.chatDBPath, privacy: .public)")
            throw ChatDatabaseError.databaseNotFound(path: chatDBPath)
        }

        // Open the database reader
        try databaseReader.open()

        // Initialize lastProcessedRowId if this is the first run.
        // Set it to the current max so we don't process historical messages.
        if lastProcessedRowId == 0 {
            let maxRowId = try databaseReader.getMaxRowId()
            lastProcessedRowId = maxRowId
            logger.info("Initialized lastProcessedRowId to \(maxRowId)")
        }

        // Open a file descriptor for DispatchSource monitoring
        fileDescriptor = Darwin.open(chatDBPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            logger.error("Failed to open file descriptor for chat.db")
            throw ChatDatabaseError.databaseOpenFailed(
                underlyingError: NSError(
                    domain: "POSIX",
                    code: Int(errno),
                    userInfo: [NSLocalizedDescriptionKey: "Failed to open file descriptor: \(String(cString: strerror(errno)))"]
                )
            )
        }

        // Create the DispatchSource to watch for file writes
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: watcherQueue
        )

        source.setEventHandler { [weak self] in
            self?.handleFileChangeEvent()
        }

        source.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                Darwin.close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        dispatchSource = source
        source.resume()
        isRunning = true

        logger.info("MessageWatcher started monitoring: \(self.chatDBPath, privacy: .public)")
    }

    /// Stops monitoring chat.db.
    ///
    /// Cancels the DispatchSource, closes the file descriptor, and closes the
    /// database reader. Safe to call multiple times.
    func stop() {
        guard isRunning else { return }

        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        dispatchSource?.cancel()
        dispatchSource = nil

        databaseReader.close()
        isRunning = false

        logger.info("MessageWatcher stopped")
    }

    /// Resets the last processed ROWID to 0.
    /// On next start, it will be re-initialized to the current max ROWID.
    /// Useful for testing or when the user wants to reprocess messages.
    func resetLastProcessedRowId() {
        lastProcessedRowId = 0
        logger.info("Reset lastProcessedRowId to 0")
    }

    // MARK: - Event Handling

    /// Called when the DispatchSource detects a change to chat.db.
    /// Implements debouncing to coalesce rapid successive changes.
    private func handleFileChangeEvent() {
        // Cancel any pending debounce
        debounceWorkItem?.cancel()

        // Create a new debounce work item
        let workItem = DispatchWorkItem { [weak self] in
            self?.checkForNewMessages()
        }

        debounceWorkItem = workItem

        // Schedule the check after the debounce interval
        watcherQueue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    /// Queries the database for messages newer than lastProcessedRowId.
    /// Filters to incoming messages only and publishes them.
    private func checkForNewMessages() {
        do {
            let newMessages = try databaseReader.fetchMessagesSince(rowId: lastProcessedRowId)

            guard !newMessages.isEmpty else {
                logger.debug("File change detected but no new messages found")
                return
            }

            // Filter to incoming messages only (not from_me)
            let incomingMessages = newMessages.filter { !$0.isFromMe }

            // Update the last processed ROWID to the highest we've seen
            if let lastMessage = newMessages.last {
                lastProcessedRowId = lastMessage.id
                logger.info("Updated lastProcessedRowId to \(lastMessage.id)")
            }

            guard !incomingMessages.isEmpty else {
                logger.debug("New messages found but all were outgoing (is_from_me)")
                return
            }

            logger.info("Detected \(incomingMessages.count) new incoming message(s)")

            // Publish via Combine
            messageSubject.send(incomingMessages)

            // Notify delegate
            delegate?.messageWatcher(self, didReceiveMessages: incomingMessages)

        } catch {
            logger.error("Error checking for new messages: \(error.localizedDescription, privacy: .public)")
            delegate?.messageWatcher(self, didEncounterError: error)
        }
    }
}
```

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution.** Hard security rule per ADR-0004.
2. **NEVER write to chat.db.** The reader opens in read-only mode.
3. Use `DispatchSource.makeFileSystemObjectSource` — NOT `FSEventStream` (DispatchSource is simpler and sufficient for monitoring a single file).
4. Use `Darwin.open()` with `O_EVTONLY` for the file descriptor — this flag is specifically for event-only monitoring.
5. All Swift files use PascalCase naming.
6. All classes and methods must have documentation comments.
7. Use `os.Logger` for logging (subsystem: "com.emberhearth.core", category: "MessageWatcher").
8. The watcher must be testable — accept the database reader via dependency injection.

## Directory Structure

Create these files:
- `src/Core/MessageWatcher.swift`
- `tests/Core/MessageWatcherTests.swift`

## Unit Tests

Create `tests/Core/MessageWatcherTests.swift` with these test cases:

```swift
import XCTest
import Combine
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
            debounceInterval: 0.1  // Short debounce for tests
        )
    }

    override func tearDown() {
        watcher.stop()
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
        // Second start should not throw
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
        watcher.stop()  // Should not crash even if not started
        XCTAssertFalse(watcher.isRunning)
    }

    // MARK: - ROWID Tracking Tests

    func testLastProcessedRowIdInitializesToMaxOnFirstStart() throws {
        // Clear any persisted value
        watcher.resetLastProcessedRowId()
        try watcher.start()

        // After start, the ROWID should be initialized to the current max
        // We can verify this indirectly: no messages should be published because
        // all existing messages have ROWID <= the initialized max.
        let expectation = XCTestExpectation(description: "No messages expected")
        expectation.isInverted = true

        watcher.newMessagesPublisher
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Wait briefly to confirm no messages arrive
        wait(for: [expectation], timeout: 1.0)
    }

    func testResetLastProcessedRowId() throws {
        try watcher.start()
        watcher.stop()
        watcher.resetLastProcessedRowId()

        // The value should be reset — will be re-initialized on next start
        let key = "com.emberhearth.messagewatcher.lastProcessedRowId"
        XCTAssertEqual(UserDefaults.standard.value(forKey: key) as? Int64 ?? 0, 0)
    }

    // MARK: - Debouncing Tests

    func testDebounceCoalescesRapidChanges() throws {
        try watcher.start()

        var receivedCount = 0
        let expectation = XCTestExpectation(description: "Messages received")

        watcher.newMessagesPublisher
            .sink { messages in
                receivedCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Simulate rapid file changes by inserting messages in quick succession
        insertTestMessage(at: testDBPath, rowId: 100, text: "Rapid 1", isFromMe: false)
        insertTestMessage(at: testDBPath, rowId: 101, text: "Rapid 2", isFromMe: false)
        insertTestMessage(at: testDBPath, rowId: 102, text: "Rapid 3", isFromMe: false)

        // Trigger a file change event (touch the file)
        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 3.0)

        // Due to debouncing, we should receive all messages in a single batch
        // (or at most 2 batches if timing is tight)
        XCTAssertLessThanOrEqual(receivedCount, 2)
    }

    // MARK: - Message Filtering Tests

    func testOnlyIncomingMessagesArePublished() throws {
        try watcher.start()

        let expectation = XCTestExpectation(description: "Only incoming messages")

        watcher.newMessagesPublisher
            .sink { messages in
                // All published messages should be incoming (not from me)
                for message in messages {
                    XCTAssertFalse(message.isFromMe, "Outgoing messages should be filtered out")
                }
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // Insert an outgoing message and an incoming message
        insertTestMessage(at: testDBPath, rowId: 200, text: "Outgoing", isFromMe: true)
        insertTestMessage(at: testDBPath, rowId: 201, text: "Incoming", isFromMe: false)

        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 3.0)
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

        insertTestMessage(at: testDBPath, rowId: 300, text: "Delegate test", isFromMe: false)
        touchFile(at: testDBPath)

        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - Helpers

    /// Creates a minimal test database with existing messages.
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
    private func insertTestMessage(at path: String, rowId: Int64, text: String, isFromMe: Bool) {
        var db: OpaquePointer?
        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        defer { sqlite3_close(db) }

        let sql = """
            INSERT OR REPLACE INTO message (ROWID, text, date, is_from_me, handle_id, cache_roomnames)
            VALUES (\(rowId), '\(text)', 726926400000000000, \(isFromMe ? 1 : 0), 1, NULL);
            INSERT OR REPLACE INTO chat_message_join (chat_id, message_id) VALUES (1, \(rowId));
            """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    /// Touches the file to trigger a file system event.
    private func touchFile(at path: String) {
        let data = Data()
        // Open and close the file to trigger an FSEvent
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
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
```

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. There are no calls to Process(), /bin/bash, or any shell execution
4. DispatchSource uses O_EVTONLY for the file descriptor
5. The debounce logic cancels previous work items before creating new ones
6. lastProcessedRowId is persisted in UserDefaults
7. Only incoming messages (isFromMe == false) are published
8. All public methods have documentation comments
9. os.Logger is used (not print() statements)
10. The watcher properly cleans up resources in stop() and deinit
```

---

## Acceptance Criteria

- [ ] `src/Core/MessageWatcher.swift` exists with all specified methods
- [ ] Uses `DispatchSource.makeFileSystemObjectSource` to watch chat.db
- [ ] File descriptor opened with `O_EVTONLY` flag
- [ ] Debounces rapid file changes (configurable interval, default 0.5s)
- [ ] Only publishes incoming messages (filters out `isFromMe == true`)
- [ ] Tracks `lastProcessedRowId` in UserDefaults
- [ ] Initializes `lastProcessedRowId` to current max on first run
- [ ] Provides both Combine publisher and delegate callback
- [ ] `start()` and `stop()` methods work correctly
- [ ] `start()` is idempotent (second call is a no-op)
- [ ] `stop()` cleans up file descriptor and dispatch source
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution anywhere
- [ ] All unit tests pass
- [ ] `os.Logger` used for all logging

---

## Verification Commands

```bash
# Build the project
cd /Users/robault/Documents/GitHub/emberhearth
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the MessageWatcher tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/MessageWatcherTests 2>&1 | tail -30

# Verify no shell execution
grep -rn "Process()" src/ || echo "PASS: No Process() calls found"
grep -rn "/bin/bash" src/ || echo "PASS: No /bin/bash references found"

# Verify O_EVTONLY is used
grep -n "O_EVTONLY" src/Core/MessageWatcher.swift && echo "PASS: O_EVTONLY confirmed"

# Verify DispatchSource usage
grep -n "makeFileSystemObjectSource" src/Core/MessageWatcher.swift && echo "PASS: DispatchSource confirmed"
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth MessageWatcher implementation for correctness, security, and robustness. Open these files:

@src/Core/MessageWatcher.swift
@tests/Core/MessageWatcherTests.swift
@src/Core/ChatDatabaseReader.swift

Also reference:
@docs/architecture/decisions/0010-fsevents-data-monitoring.md
@docs/architecture/decisions/0004-no-shell-execution.md

Check for these specific issues:

1. **SECURITY (Critical):**
   - Are there ANY calls to Process(), /bin/bash, /bin/sh, or NSTask?
   - Does the watcher only read from chat.db, never write?
   - Can the file descriptor be exploited? (O_EVTONLY should prevent data access)

2. **Resource Management (Critical):**
   - Is the file descriptor properly closed in all code paths? (stop, deinit, error paths)
   - Is the DispatchSource properly cancelled before closing the file descriptor?
   - Is there a retain cycle between the DispatchSource event handler and self? (Should use [weak self])
   - Does the cancel handler close the file descriptor?
   - Is the database reader properly closed?

3. **Correctness:**
   - Does the debounce logic correctly cancel and recreate work items?
   - Does lastProcessedRowId persist correctly across app restarts?
   - Is lastProcessedRowId initialized to the current max on first run (to avoid processing history)?
   - Does fetchMessagesSince use > (not >=) to avoid reprocessing the last seen message?
   - Does the filter correctly exclude outgoing messages (isFromMe == true)?
   - Is the ROWID updated even for outgoing messages (to avoid stuck watchers)?

4. **Edge Cases:**
   - What happens if chat.db is deleted while watching? (FDA revoked)
   - What happens if the database is locked when we try to query?
   - What happens if start() is called twice?
   - What happens if stop() is called without start()?
   - Is there a race condition between debounce firing and stop() being called?

5. **Testing:**
   - Do tests properly clean up temporary databases?
   - Is the debounce tested with a short interval for fast tests?
   - Is the delegate tested alongside the Combine publisher?
   - Are file system events properly triggered in tests?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m2): add FSEvents watcher for new message detection
```

---

## Notes for Next Task

- `MessageWatcher` publishes `[ChatMessage]` via Combine or delegate. The message pipeline (future tasks) will subscribe to this.
- The watcher filters to incoming messages only. The `PhoneNumberFilter` (task 0103) and `GroupChatDetector` (task 0104) will add additional filtering layers downstream.
- `lastProcessedRowId` is persisted in UserDefaults. If the app crashes mid-processing, some messages may be re-delivered. Downstream handlers should be idempotent.
- The debounce interval is configurable and defaults to 0.5 seconds. This can be tuned based on real-world performance.
- The watcher does NOT handle the case where chat.db is replaced (FDA toggled). That would require restarting the watcher. The app-level error handling will address this.
