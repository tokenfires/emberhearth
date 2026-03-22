# System API Mocking Strategy

**Version:** 1.0
**Date:** February 5, 2026
**Purpose:** Enable comprehensive testing of system integrations without real API access

---

## Overview

EmberHearth integrates deeply with macOS system APIs that are difficult or impossible to test in CI environments:

| API | Challenge | Impact |
|-----|-----------|--------|
| **iMessage (chat.db)** | Requires Full Disk Access, real Messages.app | Core functionality |
| **Calendar (EventKit)** | Requires calendar entitlements, user data | Tool integration |
| **Reminders (EventKit)** | Same as Calendar | Tool integration |
| **Contacts** | Requires contacts entitlement | Context enrichment |
| **AppleScript** | Requires Automation permission, real apps | Message sending |

This document defines the mocking strategy that enables:
1. Fast unit tests (no system access)
2. CI-compatible integration tests (mocked APIs)
3. Local integration tests (real APIs)
4. Staging validation (full system)

---

## Testing Tiers

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  TESTING TIERS                                                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Tier 1: Unit Tests (Mocked)                                                │
│  ├── Run on: Every commit, CI                                               │
│  ├── Dependencies: None (all mocked)                                        │
│  ├── Speed: < 30 seconds                                                    │
│  └── Coverage: Business logic, parsing, security                            │
│                                                                             │
│  Tier 2: Integration Tests (Mocked APIs)                                    │
│  ├── Run on: Every PR, CI                                                   │
│  ├── Dependencies: Mock frameworks only                                     │
│  ├── Speed: < 2 minutes                                                     │
│  └── Coverage: Component interactions, data flow                            │
│                                                                             │
│  Tier 3: Local Integration Tests (Real APIs)                                │
│  ├── Run on: Developer machine, manual                                      │
│  ├── Dependencies: Real system APIs, test accounts                          │
│  ├── Speed: < 5 minutes                                                     │
│  └── Coverage: Actual system behavior, edge cases                           │
│                                                                             │
│  Tier 4: Staging Validation (Full System)                                   │
│  ├── Run on: Pre-release, manual                                            │
│  ├── Dependencies: Production-like environment                              │
│  ├── Speed: Manual testing + automated smoke tests                          │
│  └── Coverage: End-to-end user scenarios                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. iMessage Mock Framework

### The Challenge

iMessage integration requires:
- Reading `~/Library/Messages/chat.db` (SQLite)
- Monitoring via FSEvents
- Sending via AppleScript to Messages.app

None of these work in CI without Full Disk Access and a logged-in user session.

### Mock Architecture

```swift
// MARK: - Protocol Definition

/// Abstraction for reading iMessage data
protocol MessageStoreReading {
    func getNewMessages(since: Date) async throws -> [IncomingMessage]
    func getMessage(id: Int64) async throws -> IncomingMessage?
    func getConversation(chatId: String, limit: Int) async throws -> [IncomingMessage]
}

/// Abstraction for sending messages
protocol MessageSending {
    func send(text: String, to recipient: String) async throws
    func send(text: String, toGroup chatId: String) async throws
}

/// Abstraction for monitoring new messages
protocol MessageMonitoring {
    var newMessages: AsyncStream<IncomingMessage> { get }
    func startMonitoring() async throws
    func stopMonitoring()
}
```

### Real Implementation

```swift
/// Real implementation using chat.db and AppleScript
final class SystemMessageStore: MessageStoreReading, MessageSending, MessageMonitoring {
    private let dbPath: String
    private let db: Connection
    private var fsEventStream: FSEventStreamRef?

    init(dbPath: String = "~/Library/Messages/chat.db") throws {
        self.dbPath = (dbPath as NSString).expandingTildeInPath
        self.db = try Connection(self.dbPath, readonly: true)
    }

    func getNewMessages(since: Date) async throws -> [IncomingMessage] {
        // Real SQLite query against chat.db
        let query = """
            SELECT m.ROWID, m.text, m.date, h.id as handle
            FROM message m
            JOIN handle h ON m.handle_id = h.ROWID
            WHERE m.date > ?
            ORDER BY m.date ASC
        """
        // ... implementation
    }

    func send(text: String, to recipient: String) async throws {
        let script = """
            tell application "Messages"
                set targetService to 1st account whose service type = iMessage
                set targetBuddy to participant "\(recipient)" of targetService
                send "\(text)" to targetBuddy
            end tell
        """
        try await executeAppleScript(script)
    }

    // ... rest of implementation
}
```

### Mock Implementation

```swift
/// Mock implementation for testing
final class MockMessageStore: MessageStoreReading, MessageSending, MessageMonitoring {
    // MARK: - Test Configuration

    /// Messages to return from queries
    var messages: [IncomingMessage] = []

    /// Sent messages (for verification)
    private(set) var sentMessages: [(text: String, recipient: String)] = []

    /// Stream continuation for simulating incoming messages
    private var messageContinuation: AsyncStream<IncomingMessage>.Continuation?

    /// Errors to throw (for testing error handling)
    var errorToThrow: Error?

    // MARK: - MessageStoreReading

    func getNewMessages(since: Date) async throws -> [IncomingMessage] {
        if let error = errorToThrow { throw error }
        return messages.filter { $0.date > since }
    }

    func getMessage(id: Int64) async throws -> IncomingMessage? {
        if let error = errorToThrow { throw error }
        return messages.first { $0.id == id }
    }

    func getConversation(chatId: String, limit: Int) async throws -> [IncomingMessage] {
        if let error = errorToThrow { throw error }
        return Array(messages.filter { $0.chatId == chatId }.prefix(limit))
    }

    // MARK: - MessageSending

    func send(text: String, to recipient: String) async throws {
        if let error = errorToThrow { throw error }
        sentMessages.append((text, recipient))
    }

    func send(text: String, toGroup chatId: String) async throws {
        if let error = errorToThrow { throw error }
        sentMessages.append((text, chatId))
    }

    // MARK: - MessageMonitoring

    var newMessages: AsyncStream<IncomingMessage> {
        AsyncStream { continuation in
            self.messageContinuation = continuation
        }
    }

    func startMonitoring() async throws {
        if let error = errorToThrow { throw error }
    }

    func stopMonitoring() {
        messageContinuation?.finish()
    }

    // MARK: - Test Helpers

    /// Simulate an incoming message
    func simulateIncomingMessage(_ message: IncomingMessage) {
        messages.append(message)
        messageContinuation?.yield(message)
    }

    /// Reset state between tests
    func reset() {
        messages = []
        sentMessages = []
        errorToThrow = nil
    }
}
```

### chat.db Fixture System

```swift
/// Provides realistic chat.db fixtures for testing
struct ChatDBFixtures {
    /// Create an in-memory SQLite database with chat.db schema
    static func createMockDatabase() throws -> Connection {
        let db = try Connection(.inMemory)

        // Create tables matching real chat.db schema
        try db.execute("""
            CREATE TABLE handle (
                ROWID INTEGER PRIMARY KEY,
                id TEXT UNIQUE,
                service TEXT
            );

            CREATE TABLE chat (
                ROWID INTEGER PRIMARY KEY,
                guid TEXT UNIQUE,
                chat_identifier TEXT,
                display_name TEXT,
                group_id TEXT
            );

            CREATE TABLE message (
                ROWID INTEGER PRIMARY KEY,
                guid TEXT UNIQUE,
                text TEXT,
                handle_id INTEGER,
                date INTEGER,
                is_from_me INTEGER,
                attributedBody BLOB,
                FOREIGN KEY(handle_id) REFERENCES handle(ROWID)
            );

            CREATE TABLE chat_message_join (
                chat_id INTEGER,
                message_id INTEGER,
                PRIMARY KEY(chat_id, message_id)
            );
        """)

        return db
    }

    /// Seed database with test data
    static func seedTestData(db: Connection) throws {
        // Add test contacts
        try db.run("INSERT INTO handle (id, service) VALUES (?, ?)",
                   ["+15551234567", "iMessage"])
        try db.run("INSERT INTO handle (id, service) VALUES (?, ?)",
                   ["+15559876543", "iMessage"])

        // Add test chat
        try db.run("""
            INSERT INTO chat (guid, chat_identifier, display_name)
            VALUES (?, ?, ?)
        """, ["chat123", "+15551234567", nil])

        // Add test messages
        let baseDate = Date().timeIntervalSinceReferenceDate
        try db.run("""
            INSERT INTO message (guid, text, handle_id, date, is_from_me)
            VALUES (?, ?, ?, ?, ?)
        """, ["msg1", "Hello Ember!", 1, Int(baseDate * 1_000_000_000), 0])

        try db.run("""
            INSERT INTO message (guid, text, handle_id, date, is_from_me)
            VALUES (?, ?, ?, ?, ?)
        """, ["msg2", "How can I help you today?", 1, Int((baseDate + 1) * 1_000_000_000), 1])
    }

    /// Load fixtures from JSON files
    static func loadFixture(named name: String) throws -> [IncomingMessage] {
        let url = Bundle.module.url(forResource: name, withExtension: "json",
                                     subdirectory: "Fixtures/Messages")!
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([IncomingMessage].self, from: data)
    }
}
```

### Fixture Files

```json
// tests/Fixtures/Messages/simple-conversation.json
[
    {
        "id": 1,
        "text": "Hey Ember, what's the weather like?",
        "sender": "+15551234567",
        "chatId": "chat123",
        "date": "2026-02-05T10:30:00Z",
        "isFromMe": false
    },
    {
        "id": 2,
        "text": "It's currently 72°F and sunny in your area!",
        "sender": "ember",
        "chatId": "chat123",
        "date": "2026-02-05T10:30:05Z",
        "isFromMe": true
    }
]

// tests/Fixtures/Messages/group-chat.json
[
    {
        "id": 10,
        "text": "Hey everyone!",
        "sender": "+15551234567",
        "chatId": "group-abc",
        "date": "2026-02-05T14:00:00Z",
        "isFromMe": false,
        "isGroupChat": true,
        "participantCount": 4
    }
]

// tests/Fixtures/Messages/edge-cases.json
[
    {
        "id": 100,
        "text": null,
        "attributedBody": "base64encodeddata...",
        "sender": "+15551234567",
        "chatId": "chat123",
        "date": "2026-02-05T16:00:00Z",
        "isFromMe": false,
        "comment": "Message with attributedBody instead of text (macOS 13+)"
    },
    {
        "id": 101,
        "text": "🎉🔥💯",
        "sender": "+15551234567",
        "chatId": "chat123",
        "date": "2026-02-05T16:01:00Z",
        "isFromMe": false,
        "comment": "Emoji-only message"
    }
]
```

---

## 2. EventKit Mock Framework (Calendar/Reminders)

### Protocol Abstraction

```swift
// MARK: - Calendar Protocols

protocol CalendarReading {
    func getEvents(from: Date, to: Date, calendars: [String]?) async throws -> [CalendarEvent]
    func getEvent(id: String) async throws -> CalendarEvent?
}

protocol CalendarWriting {
    func createEvent(_ event: CalendarEvent) async throws -> String
    func updateEvent(_ event: CalendarEvent) async throws
    func deleteEvent(id: String) async throws
}

protocol ReminderReading {
    func getReminders(completed: Bool?, calendars: [String]?) async throws -> [Reminder]
    func getReminder(id: String) async throws -> Reminder?
}

protocol ReminderWriting {
    func createReminder(_ reminder: Reminder) async throws -> String
    func completeReminder(id: String) async throws
    func deleteReminder(id: String) async throws
}
```

### Mock Implementation

```swift
final class MockEventStore: CalendarReading, CalendarWriting, ReminderReading, ReminderWriting {
    // MARK: - Test State

    var events: [String: CalendarEvent] = [:]
    var reminders: [String: Reminder] = [:]
    var errorToThrow: Error?

    // Track operations for verification
    private(set) var createdEvents: [CalendarEvent] = []
    private(set) var deletedEventIds: [String] = []
    private(set) var createdReminders: [Reminder] = []
    private(set) var completedReminderIds: [String] = []

    // MARK: - CalendarReading

    func getEvents(from: Date, to: Date, calendars: [String]?) async throws -> [CalendarEvent] {
        if let error = errorToThrow { throw error }

        return events.values.filter { event in
            event.startDate >= from && event.startDate <= to &&
            (calendars == nil || calendars!.contains(event.calendarId))
        }.sorted { $0.startDate < $1.startDate }
    }

    func getEvent(id: String) async throws -> CalendarEvent? {
        if let error = errorToThrow { throw error }
        return events[id]
    }

    // MARK: - CalendarWriting

    func createEvent(_ event: CalendarEvent) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = event.id ?? UUID().uuidString
        var newEvent = event
        newEvent.id = id
        events[id] = newEvent
        createdEvents.append(newEvent)
        return id
    }

    func updateEvent(_ event: CalendarEvent) async throws {
        if let error = errorToThrow { throw error }
        guard let id = event.id, events[id] != nil else {
            throw EventStoreError.eventNotFound
        }
        events[id] = event
    }

    func deleteEvent(id: String) async throws {
        if let error = errorToThrow { throw error }
        guard events.removeValue(forKey: id) != nil else {
            throw EventStoreError.eventNotFound
        }
        deletedEventIds.append(id)
    }

    // MARK: - ReminderReading

    func getReminders(completed: Bool?, calendars: [String]?) async throws -> [Reminder] {
        if let error = errorToThrow { throw error }

        return reminders.values.filter { reminder in
            (completed == nil || reminder.isCompleted == completed) &&
            (calendars == nil || calendars!.contains(reminder.calendarId))
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    func getReminder(id: String) async throws -> Reminder? {
        if let error = errorToThrow { throw error }
        return reminders[id]
    }

    // MARK: - ReminderWriting

    func createReminder(_ reminder: Reminder) async throws -> String {
        if let error = errorToThrow { throw error }

        let id = reminder.id ?? UUID().uuidString
        var newReminder = reminder
        newReminder.id = id
        reminders[id] = newReminder
        createdReminders.append(newReminder)
        return id
    }

    func completeReminder(id: String) async throws {
        if let error = errorToThrow { throw error }
        guard var reminder = reminders[id] else {
            throw EventStoreError.reminderNotFound
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        reminders[id] = reminder
        completedReminderIds.append(id)
    }

    func deleteReminder(id: String) async throws {
        if let error = errorToThrow { throw error }
        guard reminders.removeValue(forKey: id) != nil else {
            throw EventStoreError.reminderNotFound
        }
    }

    // MARK: - Test Helpers

    func reset() {
        events = [:]
        reminders = [:]
        createdEvents = []
        deletedEventIds = []
        createdReminders = []
        completedReminderIds = []
        errorToThrow = nil
    }

    /// Seed with fixture data
    func seed(with fixtures: EventKitFixtures.Scenario) {
        switch fixtures {
        case .empty:
            break
        case .busyDay:
            events = EventKitFixtures.busyDayEvents
        case .upcomingDeadlines:
            reminders = EventKitFixtures.upcomingDeadlineReminders
        case .conflictingMeetings:
            events = EventKitFixtures.conflictingMeetings
        }
    }
}
```

### EventKit Fixtures

```swift
enum EventKitFixtures {
    enum Scenario {
        case empty
        case busyDay
        case upcomingDeadlines
        case conflictingMeetings
    }

    static var busyDayEvents: [String: CalendarEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            "evt1": CalendarEvent(
                id: "evt1",
                title: "Team Standup",
                startDate: today.addingTimeInterval(9 * 3600),  // 9 AM
                endDate: today.addingTimeInterval(9.5 * 3600),  // 9:30 AM
                calendarId: "work"
            ),
            "evt2": CalendarEvent(
                id: "evt2",
                title: "1:1 with Manager",
                startDate: today.addingTimeInterval(10 * 3600), // 10 AM
                endDate: today.addingTimeInterval(11 * 3600),   // 11 AM
                calendarId: "work"
            ),
            "evt3": CalendarEvent(
                id: "evt3",
                title: "Lunch",
                startDate: today.addingTimeInterval(12 * 3600), // 12 PM
                endDate: today.addingTimeInterval(13 * 3600),   // 1 PM
                calendarId: "personal"
            ),
            "evt4": CalendarEvent(
                id: "evt4",
                title: "Project Review",
                startDate: today.addingTimeInterval(14 * 3600), // 2 PM
                endDate: today.addingTimeInterval(15 * 3600),   // 3 PM
                calendarId: "work"
            )
        ]
    }

    static var conflictingMeetings: [String: CalendarEvent] {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            "conflict1": CalendarEvent(
                id: "conflict1",
                title: "Meeting A",
                startDate: today.addingTimeInterval(10 * 3600),
                endDate: today.addingTimeInterval(11 * 3600),
                calendarId: "work"
            ),
            "conflict2": CalendarEvent(
                id: "conflict2",
                title: "Meeting B",
                startDate: today.addingTimeInterval(10.5 * 3600),
                endDate: today.addingTimeInterval(11.5 * 3600),
                calendarId: "work"
            )
        ]
    }

    static var upcomingDeadlineReminders: [String: Reminder] {
        [
            "rem1": Reminder(
                id: "rem1",
                title: "Submit expense report",
                dueDate: Date().addingTimeInterval(2 * 3600),  // 2 hours from now
                calendarId: "work",
                isCompleted: false
            ),
            "rem2": Reminder(
                id: "rem2",
                title: "Call dentist",
                dueDate: Date().addingTimeInterval(24 * 3600), // Tomorrow
                calendarId: "personal",
                isCompleted: false
            ),
            "rem3": Reminder(
                id: "rem3",
                title: "Completed task",
                dueDate: Date().addingTimeInterval(-24 * 3600), // Yesterday
                calendarId: "personal",
                isCompleted: true,
                completionDate: Date().addingTimeInterval(-12 * 3600)
            )
        ]
    }
}
```

---

## 3. AppleScript Mock Framework

### Protocol Abstraction

```swift
protocol AppleScriptExecuting {
    func execute(script: String) async throws -> String?
}

protocol AppControlling {
    func isAppRunning(_ bundleId: String) async -> Bool
    func launchApp(_ bundleId: String) async throws
    func activateApp(_ bundleId: String) async throws
}
```

### Mock Implementation

```swift
final class MockAppleScriptExecutor: AppleScriptExecuting, AppControlling {
    // MARK: - Test Configuration

    /// Scripts that have been executed (for verification)
    private(set) var executedScripts: [String] = []

    /// Responses to return for specific script patterns
    var scriptResponses: [String: String] = [:]

    /// Apps that are "running"
    var runningApps: Set<String> = ["com.apple.MobileSMS"]

    /// Error to throw
    var errorToThrow: Error?

    // MARK: - AppleScriptExecuting

    func execute(script: String) async throws -> String? {
        if let error = errorToThrow { throw error }

        executedScripts.append(script)

        // Return configured response or nil
        for (pattern, response) in scriptResponses {
            if script.contains(pattern) {
                return response
            }
        }

        return nil
    }

    // MARK: - AppControlling

    func isAppRunning(_ bundleId: String) async -> Bool {
        runningApps.contains(bundleId)
    }

    func launchApp(_ bundleId: String) async throws {
        if let error = errorToThrow { throw error }
        runningApps.insert(bundleId)
    }

    func activateApp(_ bundleId: String) async throws {
        if let error = errorToThrow { throw error }
        guard runningApps.contains(bundleId) else {
            throw AppleScriptError.appNotRunning(bundleId)
        }
    }

    // MARK: - Test Helpers

    func reset() {
        executedScripts = []
        scriptResponses = [:]
        runningApps = ["com.apple.MobileSMS"]
        errorToThrow = nil
    }

    /// Verify that a message send script was executed
    func verifySentMessage(to recipient: String, containing text: String) -> Bool {
        executedScripts.contains { script in
            script.contains("send") &&
            script.contains(recipient) &&
            script.contains(text)
        }
    }
}
```

---

## 4. Dependency Injection Setup

### Container Pattern

```swift
/// Dependency container for the application
final class Dependencies {
    static let shared = Dependencies()

    // MARK: - Message System

    lazy var messageStore: MessageStoreReading & MessageSending & MessageMonitoring = {
        #if TESTING
        return MockMessageStore()
        #else
        return try! SystemMessageStore()
        #endif
    }()

    // MARK: - Calendar System

    lazy var eventStore: CalendarReading & CalendarWriting & ReminderReading & ReminderWriting = {
        #if TESTING
        return MockEventStore()
        #else
        return SystemEventStore()
        #endif
    }()

    // MARK: - AppleScript

    lazy var scriptExecutor: AppleScriptExecuting & AppControlling = {
        #if TESTING
        return MockAppleScriptExecutor()
        #else
        return SystemAppleScriptExecutor()
        #endif
    }()

    // MARK: - Test Support

    #if TESTING
    func reset() {
        (messageStore as? MockMessageStore)?.reset()
        (eventStore as? MockEventStore)?.reset()
        (scriptExecutor as? MockAppleScriptExecutor)?.reset()
    }

    func configure(
        messageStore: (MockMessageStore) -> Void = { _ in },
        eventStore: (MockEventStore) -> Void = { _ in },
        scriptExecutor: (MockAppleScriptExecutor) -> Void = { _ in }
    ) {
        if let mock = self.messageStore as? MockMessageStore {
            messageStore(mock)
        }
        if let mock = self.eventStore as? MockEventStore {
            eventStore(mock)
        }
        if let mock = self.scriptExecutor as? MockAppleScriptExecutor {
            scriptExecutor(mock)
        }
    }
    #endif
}
```

### Test Setup

```swift
import Testing

@Suite("Message Processing Tests")
struct MessageProcessingTests {
    let deps = Dependencies.shared

    init() {
        deps.reset()
    }

    @Test func processesIncomingMessage() async throws {
        // Arrange
        let mockMessages = deps.messageStore as! MockMessageStore
        mockMessages.simulateIncomingMessage(IncomingMessage(
            id: 1,
            text: "Hello Ember!",
            sender: "+15551234567",
            chatId: "chat123",
            date: Date()
        ))

        let processor = MessageProcessor(
            messageStore: deps.messageStore,
            llmService: MockLLMService()
        )

        // Act
        let response = try await processor.processNext()

        // Assert
        #expect(response != nil)
        #expect(mockMessages.sentMessages.count == 1)
        #expect(mockMessages.sentMessages[0].recipient == "+15551234567")
    }

    @Test func detectsGroupChat() async throws {
        // Arrange
        let mockMessages = deps.messageStore as! MockMessageStore
        mockMessages.messages = try ChatDBFixtures.loadFixture(named: "group-chat")

        let detector = GroupChatDetector(messageStore: deps.messageStore)

        // Act
        let isGroup = try await detector.isGroupChat(chatId: "group-abc")

        // Assert
        #expect(isGroup == true)
    }
}

@Suite("Calendar Integration Tests")
struct CalendarIntegrationTests {
    let deps = Dependencies.shared

    init() {
        deps.reset()
    }

    @Test func detectsConflictingMeetings() async throws {
        // Arrange
        let mockEvents = deps.eventStore as! MockEventStore
        mockEvents.seed(with: .conflictingMeetings)

        let conflictDetector = ConflictDetector(eventStore: deps.eventStore)

        // Act
        let conflicts = try await conflictDetector.findConflicts(
            on: Calendar.current.startOfDay(for: Date())
        )

        // Assert
        #expect(conflicts.count == 1)
        #expect(conflicts[0].events.count == 2)
    }

    @Test func createsReminderFromUserRequest() async throws {
        // Arrange
        let mockEvents = deps.eventStore as! MockEventStore
        let handler = ReminderHandler(eventStore: deps.eventStore)

        // Act
        try await handler.createReminder(
            title: "Buy milk",
            dueDate: Date().addingTimeInterval(3600)
        )

        // Assert
        #expect(mockEvents.createdReminders.count == 1)
        #expect(mockEvents.createdReminders[0].title == "Buy milk")
    }
}
```

---

## 5. Recording/Replay Strategy

For complex scenarios, record real API interactions and replay in tests.

### Recording

```swift
/// Records real API interactions for replay in tests
final class InteractionRecorder {
    private var recordings: [String: Any] = [:]
    private let outputPath: URL

    init(outputPath: URL) {
        self.outputPath = outputPath
    }

    func record<T: Encodable>(key: String, value: T) {
        recordings[key] = value
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(recordings as! [String: AnyCodable])
        try data.write(to: outputPath)
    }
}

// Usage in development mode:
#if DEBUG && RECORD_INTERACTIONS
let recorder = InteractionRecorder(outputPath: .developerDirectory.appending("recording.json"))

// After each real API call:
let messages = try await realMessageStore.getNewMessages(since: lastCheck)
recorder.record(key: "getNewMessages_\(Date())", value: messages)
#endif
```

### Replay

```swift
/// Replays recorded interactions in tests
final class InteractionReplayer {
    private let recordings: [String: Any]

    init(from url: URL) throws {
        let data = try Data(contentsOf: url)
        self.recordings = try JSONDecoder().decode([String: AnyCodable].self, from: data)
    }

    func replay<T: Decodable>(key: String) throws -> T {
        guard let value = recordings[key] else {
            throw ReplayError.recordingNotFound(key)
        }
        // Decode and return
    }
}
```

---

## 6. CI Configuration

### GitHub Actions for Mocked Tests

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Run Unit Tests (Tier 1 + 2)
        run: |
          xcodebuild test \
            -project EmberHearth.xcodeproj \
            -scheme EmberHearth \
            -destination 'platform=macOS' \
            -only-testing:EmberHearthTests/UnitTests \
            -only-testing:EmberHearthTests/IntegrationTests \
            TESTING=1

      - name: Upload Coverage
        uses: codecov/codecov-action@v3

  # Tier 3 tests run manually or on specific branches
  system-integration-tests:
    runs-on: macos-14
    if: github.ref == 'refs/heads/main' || contains(github.event.head_commit.message, '[run-system-tests]')
    steps:
      - uses: actions/checkout@v4

      - name: Run System Integration Tests (Tier 3)
        run: |
          # These tests require manual setup and won't run in standard CI
          echo "System integration tests require manual execution with proper permissions"
          echo "Run locally with: xcodebuild test -only-testing:EmberHearthTests/SystemTests"
```

---

## 7. Test Organization

```
tests/
├── UnitTests/                    # Tier 1: Fast, no dependencies
│   ├── Memory/
│   │   ├── FactStorageTests.swift
│   │   └── DecayCalculationTests.swift
│   ├── Parsing/
│   │   ├── MessageParserTests.swift
│   │   └── PhoneNumberTests.swift
│   └── Security/
│       ├── InjectionDetectorTests.swift
│       └── CredentialPatternTests.swift
│
├── IntegrationTests/             # Tier 2: Mocked system APIs
│   ├── MessageProcessingTests.swift
│   ├── CalendarIntegrationTests.swift
│   └── ReminderHandlerTests.swift
│
├── SystemTests/                  # Tier 3: Real APIs, local only
│   ├── RealMessageStoreTests.swift
│   └── RealEventStoreTests.swift
│
├── Fixtures/                     # Test data
│   ├── Messages/
│   │   ├── simple-conversation.json
│   │   ├── group-chat.json
│   │   └── edge-cases.json
│   └── Events/
│       ├── busy-day.json
│       └── conflicts.json
│
└── Mocks/                        # Shared mock implementations
    ├── MockMessageStore.swift
    ├── MockEventStore.swift
    └── MockAppleScriptExecutor.swift
```

---

## Summary

| Component | Protocol | Mock | Fixtures |
|-----------|----------|------|----------|
| iMessage | `MessageStoreReading`, `MessageSending`, `MessageMonitoring` | `MockMessageStore` | JSON files, in-memory SQLite |
| Calendar | `CalendarReading`, `CalendarWriting` | `MockEventStore` | `EventKitFixtures` scenarios |
| Reminders | `ReminderReading`, `ReminderWriting` | `MockEventStore` | `EventKitFixtures` scenarios |
| AppleScript | `AppleScriptExecuting`, `AppControlling` | `MockAppleScriptExecutor` | Script patterns |

This framework enables:
- ✅ CI-compatible testing (Tier 1 + 2)
- ✅ Local integration testing (Tier 3)
- ✅ Realistic test scenarios via fixtures
- ✅ Error condition testing via mock configuration
- ✅ Verification of system interactions

---

*See also: `docs/testing/strategy.md` for overall testing approach.*
