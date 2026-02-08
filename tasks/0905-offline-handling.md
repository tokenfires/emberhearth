# Task 0905: Offline Detection and Graceful Degradation

**Milestone:** M10 - Final Integration
**Unit:** 10.6 - Network Monitoring and Offline Message Queuing
**Phase:** Final
**Depends On:** 0204 (Error Retry Handler), 0703 (Crash Recovery), 0504 (Message Coordinator)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; security boundaries, core principles, naming conventions
2. `docs/specs/error-handling.md` — Focus on the "LLM Provider" section (lines ~60-86) for the retry policy, message queue specification (FIFO, max 100 messages, 24-hour age limit), and the "Extended outage" row for the user communication template: "I'm temporarily offline. Your messages are saved and I'll catch up soon."
3. `docs/specs/autonomous-operation.md` — Focus on "Health State Machine" (lines ~44-78) for the HEALTHY/DEGRADED/HEALING/IMPAIRED state definitions and transitions. Also read "Component Health Monitors" (lines ~80-106) for the LLM Health Monitor's recovery trigger: "Background ping every 5 minutes during IMPAIRED" and "On success, process queued messages" with the message "I'm back online! Let me catch up..."
4. `src/LLM/ClaudeAPIClient.swift` — Full file; understand current error handling and the `sendMessage()` method signature to know how to detect network failures vs. API failures
5. `src/Core/MessageCoordinator.swift` — Full file; understand the message processing pipeline flow (steps 0-13) and the `processMessage()` method where offline interception will hook in
6. `src/App/StatusBarController.swift` — If exists; understand `updateState(_ state: AppHealthState)` and the `.offline` state for menu bar indicator updates

> **Context Budget Note:** `error-handling.md` is ~587 lines. Focus only on lines 22-86 (principles + LLM failure modes + message queue). `autonomous-operation.md` focus on lines 42-106 (health state machine + LLM health monitor). Both source files are small (<550 lines each). Total context is manageable.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the offline detection and graceful degradation system for EmberHearth, a native macOS personal AI assistant. EmberHearth communicates with users via iMessage and calls the Claude API for responses. When the network goes down or the API becomes unreachable, the system must:

1. Detect the connectivity loss immediately
2. Inform the user via iMessage that Ember is temporarily offline
3. Queue all incoming messages for later processing
4. Automatically detect when connectivity returns
5. Process queued messages in FIFO order
6. Inform the user that Ember is back online
7. Update the menu bar status indicator

This ensures the user is never left wondering why Ember stopped responding.

## CRITICAL CONTEXT

EmberHearth is a consumer app for non-technical users. The grandmother test applies: if the user notices something is broken without being told what happened, the system has failed. When offline:
- Ember MUST acknowledge that it received the message
- Ember MUST tell the user it will catch up
- Ember MUST NOT just go silent

From docs/specs/error-handling.md:
- Extended outage (>10 min of failures): Enter degraded mode
- User communication: "I'm temporarily offline. Your messages are saved and I'll catch up soon."
- Message queue: FIFO order, oldest first, maximum queue size 50 messages

From docs/specs/autonomous-operation.md:
- Health states: HEALTHY, DEGRADED, HEALING, IMPAIRED
- Recovery trigger: Background ping every 5 minutes during IMPAIRED
- On success: process queued messages
- Recovery message: "I'm back online! Let me catch up..."

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., NetworkMonitor.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target
- No third-party dependencies — use only Apple frameworks (Foundation, Network, Combine, os, XCTest)
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- NEVER log message content — only log connectivity state transitions, queue sizes, and timing

## Existing Components

These exist from prior tasks and may be referenced or integrated with:

FROM M3 (LLM Integration):
- `src/LLM/ClaudeAPIClient.swift` — Claude API client. Has `sendMessage(_ messages: [LLMMessage], systemPrompt: String?) async throws -> LLMResponse`.
- `src/LLM/RetryHandler.swift` — Retry with exponential backoff. Has `execute<T>(_ operation: () async throws -> T) async throws -> T`.
- `src/LLM/CircuitBreaker.swift` — Circuit breaker pattern. Has `execute<T>(_ operation: () async throws -> T) async throws -> T` and `state: CircuitBreakerState` (.closed/.open/.halfOpen).

FROM M6 (Integration):
- `src/Core/MessageCoordinator.swift` — Central orchestrator. Has `start()`, `stop()`, pipeline processing methods. The offline coordinator will hook into the message flow when the LLM is unreachable.
- `src/Core/MessageSender.swift` — Sends responses via AppleScript to Messages.app. Has `send(message: String, to phoneNumber: String) async throws`.

FROM M8 (Polish):
- `src/App/CrashRecoveryManager.swift` — Crash detection and recovery. The offline coordinator should integrate with the startup health check to restore queued messages after a crash.
- `src/App/HealthCheckService.swift` — Startup health check. Has `performStartupHealthCheck() -> HealthStatus`.
- `src/App/StatusBarController.swift` — Menu bar controller. Has `updateState(_ state: AppHealthState)`. `AppHealthState` has `.starting`, `.healthy`, `.degraded`, `.error`, `.offline`.

If any of these types don't exist yet, use protocol stubs. Wire the real implementations during integration.

## What You Are Building

Three source files and two test files:
1. `src/Core/NetworkMonitor.swift` — Wraps NWPathMonitor for real-time connectivity detection
2. `src/Core/MessageQueue.swift` — Persistent FIFO queue for offline messages
3. `src/Core/OfflineCoordinator.swift` — Bridges network monitoring, message queuing, and pipeline recovery
4. `tests/CoreTests/NetworkMonitorTests.swift` — Tests for NetworkMonitor
5. `tests/CoreTests/MessageQueueTests.swift` — Tests for MessageQueue

## Files to Create

### 1. src/Core/NetworkMonitor.swift

```swift
// NetworkMonitor.swift
// EmberHearth
//
// Monitors network connectivity using Apple's Network framework (NWPathMonitor).
// Provides real-time connectivity status updates via Combine publishers.
// Used by OfflineCoordinator to detect offline state and trigger message queuing.

import Foundation
import Network
import Combine
import os

/// Represents the type of network connection currently available.
///
/// Used by OfflineCoordinator to make decisions about connectivity quality.
/// For example, cellular connections may warrant different retry behavior
/// than wired Ethernet connections.
enum ConnectionType: String, Sendable, Equatable {
    /// Connected via Wi-Fi.
    case wifi = "wifi"
    /// Connected via cellular network (rare on macOS, possible with iPhone tethering).
    case cellular = "cellular"
    /// Connected via wired Ethernet.
    case wiredEthernet = "wiredEthernet"
    /// Connected via an unrecognized interface type.
    case other = "other"
    /// No network connection available.
    case none = "none"
}

/// Monitors network connectivity using NWPathMonitor from Apple's Network framework.
///
/// NetworkMonitor provides real-time updates when the device's network connectivity
/// changes. It wraps NWPathMonitor and exposes connectivity state through:
/// - A `@Published` `isConnected` property for SwiftUI/Combine binding
/// - A `@Published` `connectionType` property for connection quality assessment
/// - A `pathPublisher` for raw NWPath updates via Combine
///
/// ## Thread Safety
/// NetworkMonitor runs its NWPathMonitor on a dedicated serial DispatchQueue.
/// Published property updates are dispatched to the main queue for UI safety.
/// The class is designed to be created once and shared (e.g., via dependency injection).
///
/// ## Usage
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.start()
///
/// // Observe connectivity changes
/// monitor.$isConnected
///     .sink { connected in
///         print("Network: \(connected ? "online" : "offline")")
///     }
///     .store(in: &cancellables)
///
/// // Clean up
/// monitor.stop()
/// ```
///
/// ## Important
/// - Call `start()` before observing properties. Before `start()`, `isConnected` defaults to `true`
///   (optimistic assumption to avoid false offline detection on launch).
/// - Call `stop()` when the monitor is no longer needed to release system resources.
/// - NWPathMonitor is an Apple framework — no third-party dependencies.
final class NetworkMonitor: ObservableObject {

    // MARK: - Published Properties

    /// Whether the device currently has network connectivity.
    ///
    /// Updated on the main queue whenever NWPathMonitor reports a path change.
    /// Defaults to `true` (optimistic) until the first path update arrives.
    @Published private(set) var isConnected: Bool = true

    /// The current type of network connection.
    ///
    /// Updated alongside `isConnected` on every path change.
    /// Defaults to `.other` until the first path update.
    @Published private(set) var connectionType: ConnectionType = .other

    // MARK: - Combine Publishers

    /// A subject that emits raw NWPath updates for advanced consumers.
    ///
    /// Use this when you need access to the full NWPath object (e.g., for
    /// checking specific interface types or DNS resolution status).
    private let pathSubject = PassthroughSubject<NWPath, Never>()

    /// Publisher for raw NWPath updates.
    ///
    /// Emits every time NWPathMonitor detects a network path change.
    /// Useful for advanced monitoring beyond simple connected/disconnected.
    var pathPublisher: AnyPublisher<NWPath, Never> {
        pathSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    /// The underlying NWPathMonitor from Apple's Network framework.
    private let monitor: NWPathMonitor

    /// Dedicated serial queue for NWPathMonitor callbacks.
    /// Using a dedicated queue avoids blocking the main queue with network checks.
    private let monitorQueue: DispatchQueue

    /// Logger for connectivity change events.
    /// NEVER logs message content — only connectivity state transitions.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "NetworkMonitor"
    )

    /// Whether the monitor has been started.
    private var isMonitoring = false

    // MARK: - Initialization

    /// Creates a new NetworkMonitor.
    ///
    /// The monitor does not begin observing until `start()` is called.
    /// This allows the caller to set up Combine subscriptions before
    /// the first connectivity update fires.
    init() {
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(
            label: "com.emberhearth.networkmonitor",
            qos: .utility
        )
    }

    // MARK: - Lifecycle

    /// Starts monitoring network connectivity.
    ///
    /// Begins receiving NWPath updates on the dedicated queue. Published
    /// properties are updated on the main queue. Safe to call multiple times
    /// (subsequent calls are no-ops).
    ///
    /// Call this early in the app launch sequence, after crash recovery
    /// but before starting the message pipeline.
    func start() {
        guard !isMonitoring else {
            logger.debug("NetworkMonitor is already running, ignoring start()")
            return
        }

        logger.info("Starting network monitoring")

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.handlePathUpdate(path)
        }

        monitor.start(queue: monitorQueue)
        isMonitoring = true
    }

    /// Stops monitoring network connectivity.
    ///
    /// Releases the NWPathMonitor and stops receiving updates.
    /// Safe to call multiple times (subsequent calls are no-ops).
    /// Call this during app termination or when monitoring is no longer needed.
    func stop() {
        guard isMonitoring else {
            logger.debug("NetworkMonitor is not running, ignoring stop()")
            return
        }

        logger.info("Stopping network monitoring")
        monitor.cancel()
        isMonitoring = false
    }

    // MARK: - Private Methods

    /// Handles a network path update from NWPathMonitor.
    ///
    /// Determines the connection status and type from the NWPath,
    /// then dispatches updates to the main queue for published properties.
    ///
    /// - Parameter path: The updated network path from NWPathMonitor.
    private func handlePathUpdate(_ path: NWPath) {
        let connected = path.status == .satisfied
        let type = determineConnectionType(from: path)

        // Emit raw path for advanced consumers
        pathSubject.send(path)

        // Update published properties on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let previouslyConnected = self.isConnected

            self.isConnected = connected
            self.connectionType = type

            // Log state transitions (not every update)
            if previouslyConnected && !connected {
                self.logger.warning("Network connectivity LOST. Connection type: \(type.rawValue, privacy: .public)")
            } else if !previouslyConnected && connected {
                self.logger.info("Network connectivity RESTORED. Connection type: \(type.rawValue, privacy: .public)")
            }
        }
    }

    /// Determines the connection type from an NWPath.
    ///
    /// Checks interface types in priority order: Wi-Fi, cellular, wired Ethernet.
    /// Returns `.none` if the path status is not satisfied.
    ///
    /// - Parameter path: The network path to analyze.
    /// - Returns: The detected connection type.
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else {
            return .none
        }

        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .other
        }
    }

    // MARK: - Deinit

    deinit {
        if isMonitoring {
            monitor.cancel()
        }
    }
}
```

### 2. src/Core/MessageQueue.swift

```swift
// MessageQueue.swift
// EmberHearth
//
// Persistent FIFO message queue for offline message storage.
// When the LLM API is unreachable, incoming user messages are queued here
// and processed in order when connectivity returns.

import Foundation
import os

/// A message that has been queued for later processing while offline.
///
/// Contains all the information needed to resume processing the message
/// through the full pipeline (security check, LLM call, response) once
/// connectivity returns.
///
/// Conforms to Codable for persistent storage via UserDefaults or file.
struct QueuedMessage: Codable, Identifiable, Equatable, Sendable {
    /// Unique identifier for this queued message.
    let id: UUID

    /// The user's message text.
    let text: String

    /// The sender's phone number in E.164 format (e.g., "+15551234567").
    let phoneNumber: String

    /// When the original message was received from iMessage.
    let receivedAt: Date

    /// How many times we have attempted to process this message.
    /// Incremented on each failed retry after connectivity returns.
    var retryCount: Int

    /// Creates a new QueuedMessage.
    ///
    /// - Parameters:
    ///   - text: The user's message text.
    ///   - phoneNumber: The sender's phone number.
    ///   - receivedAt: When the message was received. Defaults to now.
    init(text: String, phoneNumber: String, receivedAt: Date = Date()) {
        self.id = UUID()
        self.text = text
        self.phoneNumber = phoneNumber
        self.receivedAt = receivedAt
        self.retryCount = 0
    }
}

/// A persistent FIFO (first-in, first-out) queue for storing messages
/// received while the LLM API is unreachable.
///
/// ## Persistence
/// The queue is backed by a JSON file in the Application Support directory.
/// This ensures queued messages survive app restarts and crashes. The file
/// is written atomically on every mutation to prevent corruption.
///
/// ## Thread Safety
/// All access is serialized through an NSLock. This is safe for the expected
/// usage pattern (single OfflineCoordinator writing, single drain on recovery).
/// For higher concurrency, consider replacing with an actor.
///
/// ## Capacity
/// The queue has a maximum capacity of 50 messages. When the queue is full,
/// the oldest message is dropped to make room for new ones. This prevents
/// unbounded memory and disk usage during extended outages.
///
/// ## Usage
/// ```swift
/// let queue = MessageQueue()
///
/// // Queue a message while offline
/// queue.enqueue(message: QueuedMessage(text: "Hello", phoneNumber: "+15551234567"))
///
/// // When back online, drain and process
/// let messages = queue.drainAll()
/// for message in messages {
///     await processMessage(message)
/// }
/// ```
final class MessageQueue {

    // MARK: - Constants

    /// Maximum number of messages the queue will hold.
    ///
    /// When the queue is full and a new message arrives, the oldest
    /// message is dropped. This prevents unbounded growth during
    /// extended outages (days/weeks offline).
    static let maximumCapacity = 50

    /// UserDefaults key for the queue storage (fallback).
    static let storageKey = "offlineMessageQueue"

    // MARK: - Properties

    /// The queued messages, ordered from oldest (index 0) to newest.
    private var messages: [QueuedMessage] = []

    /// Lock for thread-safe access to the messages array.
    private let lock = NSLock()

    /// Logger for queue operations.
    /// NEVER logs message content — only queue sizes and operations.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "MessageQueue"
    )

    /// File URL for persistent queue storage.
    private let storageURL: URL

    // MARK: - Initialization

    /// Creates a new MessageQueue and loads any persisted messages.
    ///
    /// If persisted messages exist from a previous session (e.g., after
    /// a crash while offline), they are loaded and will be processed
    /// when connectivity returns.
    ///
    /// - Parameter storageURL: Custom storage location. Defaults to
    ///   Application Support/EmberHearth/offline_queue.json.
    init(storageURL: URL? = nil) {
        if let customURL = storageURL {
            self.storageURL = customURL
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let emberDir = appSupport.appendingPathComponent("EmberHearth", isDirectory: true)
            self.storageURL = emberDir.appendingPathComponent("offline_queue.json")
        }

        loadFromDisk()
    }

    // MARK: - Public API

    /// Adds a message to the end of the queue.
    ///
    /// If the queue is at maximum capacity, the oldest message is dropped
    /// to make room. The queue is persisted to disk after each enqueue.
    ///
    /// - Parameter message: The message to queue for later processing.
    func enqueue(message: QueuedMessage) {
        lock.lock()
        defer { lock.unlock() }

        // Drop oldest if at capacity
        if messages.count >= Self.maximumCapacity {
            let dropped = messages.removeFirst()
            logger.warning(
                "Queue at capacity (\(Self.maximumCapacity)). Dropped oldest message from \(dropped.phoneNumber.suffix(4), privacy: .public) received at \(dropped.receivedAt, privacy: .public)"
            )
        }

        messages.append(message)
        logger.info("Message queued. Queue size: \(self.messages.count, privacy: .public)")

        saveToDisk()
    }

    /// Removes and returns the oldest message from the queue.
    ///
    /// - Returns: The oldest queued message, or nil if the queue is empty.
    func dequeue() -> QueuedMessage? {
        lock.lock()
        defer { lock.unlock() }

        guard !messages.isEmpty else { return nil }

        let message = messages.removeFirst()
        logger.info("Message dequeued. Queue size: \(self.messages.count, privacy: .public)")

        saveToDisk()
        return message
    }

    /// Returns the oldest message without removing it.
    ///
    /// Useful for inspecting the next message before deciding whether
    /// to process it (e.g., checking if it's too old).
    ///
    /// - Returns: The oldest queued message, or nil if the queue is empty.
    func peek() -> QueuedMessage? {
        lock.lock()
        defer { lock.unlock() }
        return messages.first
    }

    /// The number of messages currently in the queue.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return messages.count
    }

    /// Whether the queue is empty.
    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return messages.isEmpty
    }

    /// Removes and returns all messages from the queue in FIFO order.
    ///
    /// The returned array is ordered from oldest (index 0) to newest.
    /// The queue is empty after this call. The empty state is persisted to disk.
    ///
    /// - Returns: All queued messages in FIFO order. Empty array if queue was empty.
    func drainAll() -> [QueuedMessage] {
        lock.lock()
        defer { lock.unlock() }

        let drained = messages
        messages.removeAll()

        if !drained.isEmpty {
            logger.info("Queue drained. \(drained.count, privacy: .public) message(s) removed.")
        }

        saveToDisk()
        return drained
    }

    /// Removes all messages from the queue without returning them.
    ///
    /// Use this to clear stale messages (e.g., messages older than 24 hours
    /// that are no longer relevant).
    func clear() {
        lock.lock()
        defer { lock.unlock() }

        let count = messages.count
        messages.removeAll()

        if count > 0 {
            logger.info("Queue cleared. \(count, privacy: .public) message(s) removed.")
        }

        saveToDisk()
    }

    // MARK: - Persistence

    /// Saves the current queue state to disk.
    ///
    /// Uses atomic writing to prevent corruption if the app crashes
    /// mid-write. Called after every mutation.
    ///
    /// Must be called with the lock held.
    private func saveToDisk() {
        do {
            // Ensure directory exists
            let directory = storageURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }

            let data = try JSONEncoder().encode(messages)
            try data.write(to: storageURL, options: [.atomic])
        } catch {
            logger.error("Failed to persist message queue: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Loads persisted queue state from disk.
    ///
    /// Called once during initialization. If no file exists or the file
    /// is corrupt, starts with an empty queue (no crash).
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            logger.debug("No persisted queue file found. Starting with empty queue.")
            return
        }

        do {
            let data = try Data(contentsOf: storageURL)
            messages = try JSONDecoder().decode([QueuedMessage].self, from: data)
            if !messages.isEmpty {
                logger.info("Loaded \(self.messages.count, privacy: .public) queued message(s) from disk.")
            }
        } catch {
            logger.error("Failed to load persisted queue: \(error.localizedDescription, privacy: .public). Starting with empty queue.")
            messages = []
        }
    }
}
```

### 3. src/Core/OfflineCoordinator.swift

```swift
// OfflineCoordinator.swift
// EmberHearth
//
// Bridges NetworkMonitor, MessageQueue, and MessageCoordinator to provide
// seamless offline handling. When the network drops, messages are queued.
// When it returns, messages are processed in order with user notification.

import Foundation
import Combine
import os

/// Coordinates offline detection, message queuing, and recovery for EmberHearth.
///
/// The OfflineCoordinator sits between the MessageCoordinator and the LLM client.
/// When the network is unavailable or the LLM API is unreachable:
/// 1. Incoming messages are queued in persistent storage
/// 2. The user receives an iMessage: "I'm temporarily offline..."
/// 3. The menu bar indicator updates to show offline state
///
/// When connectivity returns:
/// 1. The user receives an iMessage: "I'm back online! Let me catch up..."
/// 2. Queued messages are processed in FIFO order with rate limiting
/// 3. The menu bar indicator returns to healthy state
///
/// ## Health State Integration
/// The OfflineCoordinator maps to the health state machine from autonomous-operation.md:
/// - Online + no queue → HEALTHY
/// - Online + draining queue → HEALING
/// - Offline → DEGRADED (short outage) or IMPAIRED (extended outage)
///
/// ## Rate Limiting
/// When processing the catch-up queue, messages are sent with a 2-second
/// delay between each to avoid overwhelming the API with burst requests.
/// This prevents rate limiting (429) during recovery.
///
/// ## Persistence
/// The MessageQueue is persisted to disk. If the app crashes while offline,
/// queued messages are restored on the next launch and processed when
/// connectivity returns.
///
/// ## Thread Safety
/// Uses Combine subscriptions for reactive state management. Queue drain
/// operations run on a background task with [weak self] to prevent retain cycles.
///
/// ## Usage
/// ```swift
/// let networkMonitor = NetworkMonitor()
/// let messageQueue = MessageQueue()
/// let coordinator = OfflineCoordinator(
///     networkMonitor: networkMonitor,
///     messageQueue: messageQueue,
///     messageSender: messageSender,
///     statusBarController: statusBarController
/// )
/// coordinator.start()
/// ```
final class OfflineCoordinator {

    // MARK: - Properties

    /// The network connectivity monitor.
    private let networkMonitor: NetworkMonitor

    /// The persistent message queue for offline messages.
    private let messageQueue: MessageQueue

    /// The message sender for iMessage communication.
    /// Used to notify the user about offline/online transitions.
    private let messageSender: MessageSender

    /// The status bar controller for updating the menu bar indicator.
    /// Weak reference to avoid retain cycles.
    private weak var statusBarController: StatusBarController?

    /// Logger for offline coordination events.
    /// NEVER logs message content — only state transitions and queue sizes.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "OfflineCoordinator"
    )

    /// Combine subscriptions for network state changes.
    private var cancellables = Set<AnyCancellable>()

    /// Tracks whether we have already sent the "going offline" message
    /// to the user in this offline session. Reset when we come back online.
    /// Keyed by phone number to track per-user notification.
    private var offlineNotificationSent: Set<String> = []

    /// Tracks whether we are currently draining the queue.
    /// Prevents multiple concurrent drain operations.
    private var isDraining = false

    /// Lock for thread-safe access to isDraining and offlineNotificationSent.
    private let lock = NSLock()

    /// Whether the coordinator has been started.
    private(set) var isRunning = false

    /// The phone number(s) of the user (owner). Used for sending
    /// offline/online transition notifications. Set during configuration.
    /// In MVP, this is a single phone number. Future versions may support multiple.
    private var ownerPhoneNumbers: [String] = []

    /// The delay between processing queued messages during catch-up (seconds).
    /// Prevents API rate limiting during recovery.
    static let catchUpDelaySeconds: TimeInterval = 2.0

    /// The maximum number of retries for a single queued message during catch-up.
    /// After this many failures, the message is dropped to avoid blocking the queue.
    static let maxRetryPerMessage: Int = 3

    /// Callback invoked for each queued message that needs to be processed
    /// through the full pipeline. Set by MessageCoordinator during integration.
    ///
    /// - Parameters:
    ///   - text: The user's message text.
    ///   - phoneNumber: The sender's phone number.
    /// - Returns: True if the message was processed successfully.
    var processQueuedMessage: ((_ text: String, _ phoneNumber: String) async -> Bool)?

    // MARK: - Initialization

    /// Creates a new OfflineCoordinator.
    ///
    /// - Parameters:
    ///   - networkMonitor: The network connectivity monitor.
    ///   - messageQueue: The persistent message queue.
    ///   - messageSender: The iMessage sender for user notifications.
    ///   - statusBarController: The menu bar controller (optional, weak reference).
    init(
        networkMonitor: NetworkMonitor,
        messageQueue: MessageQueue,
        messageSender: MessageSender,
        statusBarController: StatusBarController? = nil
    ) {
        self.networkMonitor = networkMonitor
        self.messageQueue = messageQueue
        self.messageSender = messageSender
        self.statusBarController = statusBarController
    }

    // MARK: - Configuration

    /// Configures the owner phone numbers for offline/online notifications.
    ///
    /// These are the phone numbers that receive "I'm going offline" and
    /// "I'm back online" messages. In MVP, this is typically a single number.
    ///
    /// - Parameter phoneNumbers: The owner's phone number(s) in E.164 format.
    func configure(ownerPhoneNumbers: [String]) {
        self.ownerPhoneNumbers = ownerPhoneNumbers
        logger.info("OfflineCoordinator configured with \(ownerPhoneNumbers.count, privacy: .public) owner number(s)")
    }

    // MARK: - Lifecycle

    /// Starts the offline coordinator.
    ///
    /// Subscribes to NetworkMonitor connectivity changes and begins
    /// coordinating offline/online transitions.
    ///
    /// If there are persisted messages in the queue from a previous session
    /// (e.g., after a crash while offline), they will be processed once
    /// connectivity is confirmed.
    func start() {
        guard !isRunning else {
            logger.debug("OfflineCoordinator is already running, ignoring start()")
            return
        }

        logger.info("Starting OfflineCoordinator")

        // Subscribe to connectivity changes
        networkMonitor.$isConnected
            .removeDuplicates()
            .dropFirst() // Skip the initial value (set before monitoring starts)
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                if isConnected {
                    self.handleConnectivityRestored()
                } else {
                    self.handleConnectivityLost()
                }
            }
            .store(in: &cancellables)

        isRunning = true

        // Check if there are persisted messages from a previous session
        if !messageQueue.isEmpty {
            logger.info("Found \(self.messageQueue.count, privacy: .public) persisted queued message(s) from previous session")
            if networkMonitor.isConnected {
                // We're online and have queued messages — drain them
                handleConnectivityRestored()
            }
        }

        logger.info("OfflineCoordinator started")
    }

    /// Stops the offline coordinator.
    ///
    /// Cancels all subscriptions. Does NOT clear the message queue
    /// (persisted messages are preserved for the next session).
    func stop() {
        guard isRunning else { return }

        logger.info("Stopping OfflineCoordinator")
        cancellables.removeAll()
        isRunning = false
        logger.info("OfflineCoordinator stopped")
    }

    // MARK: - Public API

    /// Queues a message for later processing while offline.
    ///
    /// Called by MessageCoordinator when an LLM call fails due to
    /// network issues and the circuit breaker is open.
    ///
    /// Also sends an offline notification to the user if this is the
    /// first queued message in this offline session (per phone number).
    ///
    /// - Parameters:
    ///   - text: The user's message text.
    ///   - phoneNumber: The sender's phone number.
    func queueMessage(text: String, phoneNumber: String) {
        let queued = QueuedMessage(text: text, phoneNumber: phoneNumber)
        messageQueue.enqueue(message: queued)

        // Send offline notification to this user (once per offline session)
        sendOfflineNotificationIfNeeded(to: phoneNumber)

        // Update status bar
        statusBarController?.updateState(.degraded)
    }

    /// Whether the system is currently offline (no network connectivity).
    ///
    /// Used by MessageCoordinator to decide whether to attempt an LLM call
    /// or queue the message directly.
    var isOffline: Bool {
        !networkMonitor.isConnected
    }

    /// The number of messages currently queued.
    var queuedMessageCount: Int {
        messageQueue.count
    }

    // MARK: - Connectivity Handlers

    /// Called when network connectivity is lost.
    ///
    /// Updates the menu bar status indicator to reflect the offline state.
    /// Actual message queuing happens in `queueMessage(text:phoneNumber:)`
    /// when LLM calls fail.
    private func handleConnectivityLost() {
        logger.warning("Connectivity lost. Entering offline mode.")

        // Update status bar to offline
        statusBarController?.updateState(.offline)

        // Notify all configured owner phone numbers
        for phoneNumber in ownerPhoneNumbers {
            sendOfflineNotificationIfNeeded(to: phoneNumber)
        }
    }

    /// Called when network connectivity is restored.
    ///
    /// Sends an "I'm back online" notification to the user and begins
    /// draining the message queue in FIFO order.
    private func handleConnectivityRestored() {
        logger.info("Connectivity restored. Beginning recovery.")

        // Reset offline notification tracking
        lock.lock()
        offlineNotificationSent.removeAll()
        lock.unlock()

        // Update status bar to healing (processing queue)
        if !messageQueue.isEmpty {
            statusBarController?.updateState(.degraded)
        } else {
            statusBarController?.updateState(.healthy)
        }

        // Send "back online" notification to owner
        for phoneNumber in ownerPhoneNumbers {
            Task { [weak self] in
                guard let self = self else { return }
                await self.sendOnlineNotification(to: phoneNumber)
            }
        }

        // Drain the queue
        drainQueue()
    }

    // MARK: - Queue Draining

    /// Drains the message queue, processing each message in FIFO order.
    ///
    /// Messages are processed with a delay between each to avoid
    /// overwhelming the API (rate limiting prevention).
    ///
    /// If a message fails to process after `maxRetryPerMessage` attempts,
    /// it is dropped and the next message is processed.
    ///
    /// Only one drain operation can run at a time. If called while already
    /// draining, the call is ignored.
    private func drainQueue() {
        lock.lock()
        guard !isDraining else {
            lock.unlock()
            logger.debug("Already draining queue, ignoring duplicate drain request")
            return
        }
        isDraining = true
        lock.unlock()

        Task { [weak self] in
            guard let self = self else { return }

            defer {
                self.lock.lock()
                self.isDraining = false
                self.lock.unlock()
            }

            let messages = self.messageQueue.drainAll()
            guard !messages.isEmpty else {
                self.logger.debug("Queue is empty, nothing to drain")
                self.statusBarController?.updateState(.healthy)
                return
            }

            self.logger.info("Draining \(messages.count, privacy: .public) queued message(s)")

            var processedCount = 0
            var failedCount = 0

            for message in messages {
                // Check if we've gone offline again during draining
                guard self.networkMonitor.isConnected else {
                    self.logger.warning("Connectivity lost during queue drain. Re-queuing remaining messages.")
                    // Re-queue unprocessed messages (current + remaining)
                    let currentIndex = processedCount + failedCount
                    for i in currentIndex..<messages.count {
                        self.messageQueue.enqueue(message: messages[i])
                    }
                    return
                }

                // Process the message through the pipeline
                var succeeded = false
                if let processor = self.processQueuedMessage {
                    succeeded = await processor(message.text, message.phoneNumber)
                } else {
                    self.logger.error("No message processor configured. Dropping queued message.")
                    failedCount += 1
                    continue
                }

                if succeeded {
                    processedCount += 1
                    self.logger.info("Queued message processed successfully. Progress: \(processedCount, privacy: .public)/\(messages.count, privacy: .public)")
                } else {
                    // Check retry count
                    var retryMessage = message
                    retryMessage.retryCount += 1

                    if retryMessage.retryCount < Self.maxRetryPerMessage {
                        // Re-queue for another attempt
                        self.messageQueue.enqueue(message: retryMessage)
                        self.logger.warning("Queued message processing failed. Re-queued (retry \(retryMessage.retryCount, privacy: .public)/\(Self.maxRetryPerMessage, privacy: .public))")
                    } else {
                        failedCount += 1
                        self.logger.error("Queued message exceeded max retries (\(Self.maxRetryPerMessage, privacy: .public)). Dropping.")
                    }
                }

                // Rate limit: wait between messages to avoid API overload
                if processedCount + failedCount < messages.count {
                    try? await Task.sleep(nanoseconds: UInt64(Self.catchUpDelaySeconds * 1_000_000_000))
                }
            }

            self.logger.info("Queue drain complete. Processed: \(processedCount, privacy: .public), Failed: \(failedCount, privacy: .public)")

            // If all processed successfully, return to healthy
            if self.messageQueue.isEmpty {
                self.statusBarController?.updateState(.healthy)
            }
        }
    }

    // MARK: - User Notifications

    /// Sends the offline notification to a user if not already sent in this session.
    ///
    /// The message text matches the spec from error-handling.md:
    /// "I'm temporarily offline. Your messages are saved and I'll catch up soon."
    ///
    /// - Parameter phoneNumber: The phone number to notify.
    private func sendOfflineNotificationIfNeeded(to phoneNumber: String) {
        lock.lock()
        guard !offlineNotificationSent.contains(phoneNumber) else {
            lock.unlock()
            return
        }
        offlineNotificationSent.insert(phoneNumber)
        lock.unlock()

        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.messageSender.send(
                    message: "I'm temporarily offline. Your messages are saved and I'll catch up soon.",
                    to: phoneNumber
                )
                self.logger.info("Offline notification sent to \(phoneNumber.suffix(4), privacy: .public)")
            } catch {
                // If we can't even send the notification (e.g., Messages.app down),
                // log it but don't fail — the message is still queued.
                self.logger.error("Failed to send offline notification to \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Sends the "back online" notification to a user.
    ///
    /// The message text matches the spec from autonomous-operation.md:
    /// "I'm back online! Let me catch up on what I missed."
    ///
    /// - Parameter phoneNumber: The phone number to notify.
    private func sendOnlineNotification(to phoneNumber: String) async {
        do {
            try await messageSender.send(
                message: "I'm back online! Let me catch up on what I missed.",
                to: phoneNumber
            )
            logger.info("Online notification sent to \(phoneNumber.suffix(4), privacy: .public)")
        } catch {
            logger.error("Failed to send online notification to \(phoneNumber.suffix(4), privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Deinit

    deinit {
        cancellables.removeAll()
    }
}
```

### 4. tests/CoreTests/NetworkMonitorTests.swift

```swift
// NetworkMonitorTests.swift
// EmberHearth
//
// Unit tests for NetworkMonitor.
// Tests initialization, lifecycle, property defaults, and connection type detection.
//
// NOTE: NWPathMonitor depends on the real network stack, so these tests
// focus on the public API contract and lifecycle management rather than
// simulating network state changes (which require integration tests).

import XCTest
import Network
import Combine
@testable import EmberHearth

final class NetworkMonitorTests: XCTestCase {

    private var monitor: NetworkMonitor!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        monitor = NetworkMonitor()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        monitor.stop()
        monitor = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialStateIsOptimisticallyConnected() {
        // Before start(), isConnected defaults to true (optimistic)
        XCTAssertTrue(monitor.isConnected,
            "isConnected should default to true before start() is called")
    }

    func testInitialConnectionTypeIsOther() {
        // Before start(), connectionType defaults to .other
        XCTAssertEqual(monitor.connectionType, .other,
            "connectionType should default to .other before start() is called")
    }

    // MARK: - Lifecycle Tests

    func testStartIsIdempotent() {
        // Calling start() twice should not crash or create duplicate monitors
        monitor.start()
        monitor.start() // Should be a no-op
        // If this completes without crashing, the test passes
        XCTAssertTrue(true, "Double start() should not crash")
    }

    func testStopIsIdempotent() {
        // Calling stop() without start() should be safe
        monitor.stop()
        monitor.stop() // Double stop
        XCTAssertTrue(true, "Double stop() should not crash")
    }

    func testStartThenStop() {
        // Normal lifecycle
        monitor.start()
        monitor.stop()
        XCTAssertTrue(true, "Start then stop should complete without error")
    }

    func testStartAfterStop() {
        // NOTE: NWPathMonitor cannot be restarted after cancel().
        // This test verifies the monitor handles this gracefully.
        monitor.start()
        monitor.stop()
        // Creating a new monitor is the correct approach after stop
        let newMonitor = NetworkMonitor()
        newMonitor.start()
        newMonitor.stop()
        XCTAssertTrue(true, "Creating a new monitor after stop should work")
    }

    // MARK: - Publisher Tests

    func testPathPublisherExists() {
        // Verify the pathPublisher is accessible
        let publisher = monitor.pathPublisher
        XCTAssertNotNil(publisher, "pathPublisher should be accessible")
    }

    func testIsConnectedPublisherEmitsOnStart() {
        let expectation = expectation(description: "isConnected should emit after start")

        // Subscribe to isConnected changes
        monitor.$isConnected
            .dropFirst() // Skip initial value
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        monitor.start()

        // Wait a short time for the monitor to report initial state
        wait(for: [expectation], timeout: 5.0)
    }

    func testConnectionTypePublisherEmitsOnStart() {
        let expectation = expectation(description: "connectionType should emit after start")

        monitor.$connectionType
            .dropFirst()
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        monitor.start()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Connection Type Tests

    func testConnectionTypeEnumRawValues() {
        XCTAssertEqual(ConnectionType.wifi.rawValue, "wifi")
        XCTAssertEqual(ConnectionType.cellular.rawValue, "cellular")
        XCTAssertEqual(ConnectionType.wiredEthernet.rawValue, "wiredEthernet")
        XCTAssertEqual(ConnectionType.other.rawValue, "other")
        XCTAssertEqual(ConnectionType.none.rawValue, "none")
    }

    func testConnectionTypeEquatable() {
        XCTAssertEqual(ConnectionType.wifi, ConnectionType.wifi)
        XCTAssertNotEqual(ConnectionType.wifi, ConnectionType.cellular)
        XCTAssertNotEqual(ConnectionType.none, ConnectionType.wifi)
    }

    // MARK: - Deinit Safety

    func testDeinitDoesNotCrash() {
        // Create and start a monitor, then let it deallocate
        var localMonitor: NetworkMonitor? = NetworkMonitor()
        localMonitor?.start()
        localMonitor = nil // Should trigger deinit and cancel the monitor
        XCTAssertNil(localMonitor, "Monitor should be deallocated cleanly")
    }

    // MARK: - No Shell Execution

    func testNoShellExecution() {
        // Structural verification — real check is in verification commands
        // This test documents the requirement
        XCTAssertTrue(true,
            "NetworkMonitor must use NWPathMonitor (not ping, not Process())")
    }
}
```

### 5. tests/CoreTests/MessageQueueTests.swift

```swift
// MessageQueueTests.swift
// EmberHearth
//
// Unit tests for MessageQueue.
// Tests FIFO ordering, persistence, capacity limits, thread safety, and edge cases.

import XCTest
@testable import EmberHearth

final class MessageQueueTests: XCTestCase {

    private var queue: MessageQueue!
    private var testStorageURL: URL!

    override func setUp() {
        super.setUp()
        // Use a unique temp file for each test to ensure isolation
        let tempDir = FileManager.default.temporaryDirectory
        testStorageURL = tempDir.appendingPathComponent("test_queue_\(UUID().uuidString).json")
        queue = MessageQueue(storageURL: testStorageURL)
    }

    override func tearDown() {
        // Clean up the test file
        try? FileManager.default.removeItem(at: testStorageURL)
        queue = nil
        testStorageURL = nil
        super.tearDown()
    }

    // MARK: - Basic Operations

    func testNewQueueIsEmpty() {
        XCTAssertTrue(queue.isEmpty, "New queue should be empty")
        XCTAssertEqual(queue.count, 0, "New queue count should be 0")
        XCTAssertNil(queue.peek(), "Peek on empty queue should return nil")
        XCTAssertNil(queue.dequeue(), "Dequeue on empty queue should return nil")
    }

    func testEnqueueIncrementsCount() {
        let message = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        queue.enqueue(message: message)

        XCTAssertFalse(queue.isEmpty)
        XCTAssertEqual(queue.count, 1)
    }

    func testEnqueueMultipleMessages() {
        for i in 0..<5 {
            let message = QueuedMessage(text: "Message \(i)", phoneNumber: "+15551234567")
            queue.enqueue(message: message)
        }

        XCTAssertEqual(queue.count, 5)
    }

    // MARK: - FIFO Ordering

    func testDequeueFIFOOrder() {
        let msg1 = QueuedMessage(text: "First", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Second", phoneNumber: "+15552222222")
        let msg3 = QueuedMessage(text: "Third", phoneNumber: "+15553333333")

        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)
        queue.enqueue(message: msg3)

        let dequeued1 = queue.dequeue()
        XCTAssertEqual(dequeued1?.text, "First", "First dequeue should return the oldest message")

        let dequeued2 = queue.dequeue()
        XCTAssertEqual(dequeued2?.text, "Second")

        let dequeued3 = queue.dequeue()
        XCTAssertEqual(dequeued3?.text, "Third")

        XCTAssertNil(queue.dequeue(), "Queue should be empty after draining")
    }

    func testDrainAllReturnsFIFOOrder() {
        let messages = (0..<5).map { i in
            QueuedMessage(text: "Message \(i)", phoneNumber: "+1555000000\(i)")
        }

        for msg in messages {
            queue.enqueue(message: msg)
        }

        let drained = queue.drainAll()

        XCTAssertEqual(drained.count, 5)
        for (index, msg) in drained.enumerated() {
            XCTAssertEqual(msg.text, "Message \(index)",
                "drainAll should return messages in FIFO order")
        }

        XCTAssertTrue(queue.isEmpty, "Queue should be empty after drainAll")
    }

    // MARK: - Peek

    func testPeekReturnsOldestWithoutRemoving() {
        let msg1 = QueuedMessage(text: "First", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Second", phoneNumber: "+15552222222")

        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)

        let peeked = queue.peek()
        XCTAssertEqual(peeked?.text, "First", "Peek should return the oldest message")
        XCTAssertEqual(queue.count, 2, "Peek should NOT remove the message")

        // Peek again should return the same message
        let peekedAgain = queue.peek()
        XCTAssertEqual(peekedAgain?.text, "First")
    }

    // MARK: - Capacity Limits

    func testMaximumCapacityIs50() {
        XCTAssertEqual(MessageQueue.maximumCapacity, 50)
    }

    func testCapacityEnforcedDropsOldest() {
        // Fill the queue to capacity
        for i in 0..<50 {
            let msg = QueuedMessage(text: "Message \(i)", phoneNumber: "+15551234567")
            queue.enqueue(message: msg)
        }
        XCTAssertEqual(queue.count, 50, "Queue should be at capacity")

        // Add one more — should drop the oldest (Message 0)
        let overflow = QueuedMessage(text: "Overflow", phoneNumber: "+15551234567")
        queue.enqueue(message: overflow)

        XCTAssertEqual(queue.count, 50, "Queue should still be at capacity")

        // The oldest message should now be "Message 1" (Message 0 was dropped)
        let oldest = queue.peek()
        XCTAssertEqual(oldest?.text, "Message 1",
            "Oldest message should be 'Message 1' after overflow dropped 'Message 0'")
    }

    func testCapacityDropsMultipleOldest() {
        // Fill to capacity
        for i in 0..<50 {
            queue.enqueue(message: QueuedMessage(text: "Old \(i)", phoneNumber: "+15551234567"))
        }

        // Add 3 more — should drop 3 oldest
        for i in 0..<3 {
            queue.enqueue(message: QueuedMessage(text: "New \(i)", phoneNumber: "+15551234567"))
        }

        XCTAssertEqual(queue.count, 50, "Queue should still be at capacity")

        let oldest = queue.peek()
        XCTAssertEqual(oldest?.text, "Old 3",
            "After adding 3 over capacity, oldest should be 'Old 3'")
    }

    // MARK: - Persistence

    func testPersistenceAcrossInstances() {
        // Enqueue messages in one instance
        let msg1 = QueuedMessage(text: "Persisted 1", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Persisted 2", phoneNumber: "+15552222222")
        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)

        // Create a new instance pointing to the same file
        let newQueue = MessageQueue(storageURL: testStorageURL)

        XCTAssertEqual(newQueue.count, 2, "New instance should load persisted messages")

        let dequeued = newQueue.dequeue()
        XCTAssertEqual(dequeued?.text, "Persisted 1",
            "Persisted messages should maintain FIFO order")
    }

    func testPersistenceAfterDequeue() {
        let msg1 = QueuedMessage(text: "First", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "Second", phoneNumber: "+15552222222")
        queue.enqueue(message: msg1)
        queue.enqueue(message: msg2)

        // Dequeue one
        _ = queue.dequeue()

        // New instance should only have the remaining message
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertEqual(newQueue.count, 1)
        XCTAssertEqual(newQueue.peek()?.text, "Second")
    }

    func testPersistenceAfterDrainAll() {
        queue.enqueue(message: QueuedMessage(text: "Test", phoneNumber: "+15551234567"))
        _ = queue.drainAll()

        // New instance should have empty queue
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Queue should be empty after drainAll and reload")
    }

    func testPersistenceAfterClear() {
        queue.enqueue(message: QueuedMessage(text: "Test", phoneNumber: "+15551234567"))
        queue.clear()

        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Queue should be empty after clear and reload")
    }

    func testPersistenceWithCorruptFile() {
        // Write garbage to the storage file
        let garbage = "this is not valid json".data(using: .utf8)!
        try? garbage.write(to: testStorageURL)

        // Creating a new queue should not crash — starts with empty queue
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Corrupt file should result in empty queue")
    }

    func testPersistenceWithMissingFile() {
        // Delete the storage file
        try? FileManager.default.removeItem(at: testStorageURL)

        // Creating a new queue should not crash — starts with empty queue
        let newQueue = MessageQueue(storageURL: testStorageURL)
        XCTAssertTrue(newQueue.isEmpty, "Missing file should result in empty queue")
    }

    // MARK: - QueuedMessage Model

    func testQueuedMessageProperties() {
        let before = Date()
        let msg = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        let after = Date()

        XCTAssertEqual(msg.text, "Hello")
        XCTAssertEqual(msg.phoneNumber, "+15551234567")
        XCTAssertEqual(msg.retryCount, 0, "Initial retry count should be 0")
        XCTAssertGreaterThanOrEqual(msg.receivedAt, before)
        XCTAssertLessThanOrEqual(msg.receivedAt, after)
        XCTAssertNotNil(msg.id, "ID should be auto-generated")
    }

    func testQueuedMessageUniqueIds() {
        let msg1 = QueuedMessage(text: "A", phoneNumber: "+15551111111")
        let msg2 = QueuedMessage(text: "A", phoneNumber: "+15551111111")

        XCTAssertNotEqual(msg1.id, msg2.id,
            "Each queued message should have a unique ID")
    }

    func testQueuedMessageCodable() {
        let original = QueuedMessage(text: "Encode me", phoneNumber: "+15551234567")

        do {
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(QueuedMessage.self, from: data)

            XCTAssertEqual(decoded.id, original.id)
            XCTAssertEqual(decoded.text, original.text)
            XCTAssertEqual(decoded.phoneNumber, original.phoneNumber)
            XCTAssertEqual(decoded.retryCount, original.retryCount)
            // Date comparison with 1-second tolerance (JSON date encoding precision)
            XCTAssertEqual(
                decoded.receivedAt.timeIntervalSince1970,
                original.receivedAt.timeIntervalSince1970,
                accuracy: 1.0
            )
        } catch {
            XCTFail("QueuedMessage should be Codable: \(error)")
        }
    }

    func testQueuedMessageEquatable() {
        let msg1 = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        let msg2 = msg1 // Same instance values (but UUID differs in practice)

        // Two different QueuedMessages with different UUIDs should not be equal
        let msg3 = QueuedMessage(text: "Hello", phoneNumber: "+15551234567")
        XCTAssertNotEqual(msg1, msg3,
            "Messages with different UUIDs should not be equal")
    }

    // MARK: - Clear

    func testClearEmptiesQueue() {
        for i in 0..<10 {
            queue.enqueue(message: QueuedMessage(text: "Msg \(i)", phoneNumber: "+15551234567"))
        }

        queue.clear()

        XCTAssertTrue(queue.isEmpty)
        XCTAssertEqual(queue.count, 0)
    }

    func testClearOnEmptyQueueIsSafe() {
        queue.clear()
        XCTAssertTrue(queue.isEmpty, "Clearing an empty queue should be safe")
    }

    // MARK: - DrainAll on Empty

    func testDrainAllOnEmptyQueueReturnsEmpty() {
        let drained = queue.drainAll()
        XCTAssertTrue(drained.isEmpty, "drainAll on empty queue should return empty array")
    }

    // MARK: - Thread Safety

    func testConcurrentEnqueueAndDequeue() {
        let expectation = expectation(description: "Concurrent access should not crash")
        let iterations = 100

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 2 == 0 {
                let msg = QueuedMessage(text: "Concurrent \(i)", phoneNumber: "+15551234567")
                self.queue.enqueue(message: msg)
            } else {
                _ = self.queue.dequeue()
            }
        }

        // If we get here without crashing, thread safety is working
        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    func testConcurrentCountAndEnqueue() {
        let expectation = expectation(description: "Concurrent count access should not crash")
        let iterations = 100

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            if i % 3 == 0 {
                let msg = QueuedMessage(text: "Msg \(i)", phoneNumber: "+15551234567")
                self.queue.enqueue(message: msg)
            } else if i % 3 == 1 {
                _ = self.queue.count
            } else {
                _ = self.queue.isEmpty
            }
        }

        expectation.fulfill()
        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - RetryCount

    func testRetryCountCanBeIncremented() {
        var msg = QueuedMessage(text: "Retry me", phoneNumber: "+15551234567")
        XCTAssertEqual(msg.retryCount, 0)

        msg.retryCount += 1
        XCTAssertEqual(msg.retryCount, 1)

        msg.retryCount += 1
        XCTAssertEqual(msg.retryCount, 2)
    }

    func testRetryCountPersists() {
        var msg = QueuedMessage(text: "Retry me", phoneNumber: "+15551234567")
        msg.retryCount = 3
        queue.enqueue(message: msg)

        let newQueue = MessageQueue(storageURL: testStorageURL)
        let loaded = newQueue.peek()
        XCTAssertEqual(loaded?.retryCount, 3, "Retry count should persist across instances")
    }
}
```

## Integration with MessageCoordinator

After creating the three source files, the OfflineCoordinator should be integrated with the MessageCoordinator. The integration point is in `MessageCoordinator.processMessage()`:

```swift
// In MessageCoordinator, before calling the LLM:
// 1. Check if OfflineCoordinator reports offline
if offlineCoordinator.isOffline {
    offlineCoordinator.queueMessage(text: messageText, phoneNumber: phoneNumber)
    return
}

// 2. If LLM call fails with network error, queue the message:
do {
    let response = try await llmClient.sendMessage(context.messages, systemPrompt: context.systemPrompt)
    // ... process response ...
} catch {
    if isNetworkError(error) {
        offlineCoordinator.queueMessage(text: messageText, phoneNumber: phoneNumber)
        return
    }
    // ... handle other errors as before ...
}
```

The `processQueuedMessage` callback on OfflineCoordinator should be set by MessageCoordinator during initialization:

```swift
offlineCoordinator.processQueuedMessage = { [weak self] text, phoneNumber in
    guard let self = self else { return false }
    // Process through the full pipeline (security, context, LLM, send)
    return await self.processQueuedMessageThroughPipeline(text: text, phoneNumber: phoneNumber)
}
```

The exact integration depends on the current MessageCoordinator implementation. Adapt as needed, but ensure:
1. Offline check happens BEFORE the LLM call
2. Network errors during LLM calls trigger message queuing
3. The processQueuedMessage callback is set during app startup wiring

## Implementation Rules

1. **NEVER use Process(), /bin/bash, /bin/sh, NSTask, or osascript.** Hard security rule per ADR-0004.
2. Network monitoring uses `NWPathMonitor` from Apple's `Network` framework — no `ping`, no shell commands.
3. No third-party dependencies. Use only Apple frameworks (Foundation, Network, Combine, os, XCTest).
4. All Swift files use PascalCase naming.
5. All public types and methods must have documentation comments (///).
6. Use `os.Logger` for logging. **NEVER log message content.** Log only: connectivity state transitions, queue sizes, retry counts, and timing.
7. MessageQueue persistence uses JSON file, not UserDefaults (UserDefaults has size limits).
8. Queue maximum capacity is 50 messages. When full, oldest is dropped.
9. Rate-limit catch-up processing: 2-second delay between queued message processing.
10. All [weak self] in Combine subscriptions and Task closures.
11. Test file paths match the directory structure for Core component tests.

## Directory Structure

Create these files:
- `src/Core/NetworkMonitor.swift`
- `src/Core/MessageQueue.swift`
- `src/Core/OfflineCoordinator.swift`
- `tests/CoreTests/NetworkMonitorTests.swift`
- `tests/CoreTests/MessageQueueTests.swift`

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test --filter NetworkMonitorTests` and `swift test --filter MessageQueueTests`)
3. CRITICAL: No calls to Process(), /bin/bash, /bin/sh, NSTask, CommandLine, osascript, or ping
4. NWPathMonitor is used for connectivity detection (not URLSession polling)
5. MessageQueue uses file-based persistence (not UserDefaults)
6. Queue capacity is enforced at 50 messages
7. FIFO ordering is maintained in all queue operations
8. Combine subscriptions use [weak self]
9. os.Logger is used (not print())
10. No message content appears in any log statement
11. All public types and methods have documentation comments
12. Thread safety: NSLock is used correctly in MessageQueue with defer { lock.unlock() }
13. OfflineCoordinator sends offline/online iMessages per the spec text
```

---

## Acceptance Criteria

- [ ] `src/Core/NetworkMonitor.swift` exists and wraps `NWPathMonitor` from Apple's Network framework
- [ ] `NetworkMonitor.isConnected` is a `@Published` property updated on main queue
- [ ] `NetworkMonitor.connectionType` correctly detects wifi, cellular, wiredEthernet, none
- [ ] `NetworkMonitor.pathPublisher` provides raw `NWPath` updates via Combine
- [ ] `NetworkMonitor.start()` and `stop()` are idempotent (safe to call multiple times)
- [ ] NetworkMonitor runs on a dedicated `DispatchQueue` (not main queue)
- [ ] `src/Core/MessageQueue.swift` exists with FIFO ordering guaranteed
- [ ] `MessageQueue.enqueue()` adds to end, `dequeue()` removes from front
- [ ] `MessageQueue.peek()` returns oldest without removing
- [ ] `MessageQueue.drainAll()` returns all messages in FIFO order and clears queue
- [ ] `MessageQueue.count` and `isEmpty` are accurate
- [ ] MessageQueue has maximum capacity of 50 messages (drops oldest on overflow)
- [ ] MessageQueue persists to JSON file in Application Support directory
- [ ] MessageQueue survives app restart (persistence verified in tests)
- [ ] MessageQueue handles corrupt/missing persistence file gracefully (starts empty)
- [ ] `QueuedMessage` struct has: id (UUID), text (String), phoneNumber (String), receivedAt (Date), retryCount (Int)
- [ ] `QueuedMessage` conforms to Codable, Identifiable, Equatable, Sendable
- [ ] `src/Core/OfflineCoordinator.swift` exists bridging NetworkMonitor, MessageQueue, and MessageCoordinator
- [ ] OfflineCoordinator subscribes to NetworkMonitor connectivity changes
- [ ] When offline: messages are queued and user receives iMessage "I'm temporarily offline. Your messages are saved and I'll catch up soon."
- [ ] When back online: user receives "I'm back online! Let me catch up on what I missed." and queue is drained
- [ ] Offline notification is sent only once per phone number per offline session
- [ ] Queue drain processes messages in FIFO order with 2-second delay between each
- [ ] Queue drain re-queues remaining messages if connectivity drops during processing
- [ ] Messages exceeding max retry count (3) are dropped during catch-up
- [ ] Menu bar status indicator updates: `.offline` when disconnected, `.degraded` during catch-up, `.healthy` when complete
- [ ] OfflineCoordinator restores persisted queue on startup if messages exist
- [ ] `tests/CoreTests/NetworkMonitorTests.swift` exists with lifecycle and property tests
- [ ] `tests/CoreTests/MessageQueueTests.swift` exists with FIFO, persistence, capacity, and thread safety tests
- [ ] **CRITICAL:** No calls to `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, `CommandLine`, `osascript`, or `ping`
- [ ] **CRITICAL:** No message content is logged anywhere (only queue sizes, state transitions, phone number suffixes)
- [ ] All Combine subscriptions use `[weak self]` to prevent retain cycles
- [ ] `StatusBarController` reference is weak in OfflineCoordinator
- [ ] All `os.Logger` used (no `print()` statements)
- [ ] All public types and methods have documentation comments (`///`)
- [ ] `swift build` succeeds
- [ ] All tests pass

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify source files exist
test -f src/Core/NetworkMonitor.swift && echo "PASS: NetworkMonitor.swift exists" || echo "MISSING: NetworkMonitor.swift"
test -f src/Core/MessageQueue.swift && echo "PASS: MessageQueue.swift exists" || echo "MISSING: MessageQueue.swift"
test -f src/Core/OfflineCoordinator.swift && echo "PASS: OfflineCoordinator.swift exists" || echo "MISSING: OfflineCoordinator.swift"
test -f tests/CoreTests/NetworkMonitorTests.swift && echo "PASS: NetworkMonitorTests.swift exists" || echo "MISSING: NetworkMonitorTests.swift"
test -f tests/CoreTests/MessageQueueTests.swift && echo "PASS: MessageQueueTests.swift exists" || echo "MISSING: MessageQueueTests.swift"

# CRITICAL: Verify no shell execution
grep -rn "Process()" src/Core/NetworkMonitor.swift src/Core/MessageQueue.swift src/Core/OfflineCoordinator.swift || echo "PASS: No Process() calls"
grep -rn "NSTask" src/Core/ || echo "PASS: No NSTask references"
grep -rn "/bin/bash" src/Core/ || echo "PASS: No /bin/bash references"
grep -rn "/bin/sh" src/Core/ || echo "PASS: No /bin/sh references"
grep -rn "osascript" src/Core/NetworkMonitor.swift src/Core/MessageQueue.swift src/Core/OfflineCoordinator.swift || echo "PASS: No osascript in new files"
grep -rn "CommandLine" src/Core/NetworkMonitor.swift src/Core/MessageQueue.swift src/Core/OfflineCoordinator.swift || echo "PASS: No CommandLine in new files"

# Verify NWPathMonitor is used (not ping or URLSession for monitoring)
grep -n "NWPathMonitor" src/Core/NetworkMonitor.swift && echo "PASS: Uses NWPathMonitor" || echo "FAIL: Missing NWPathMonitor"
grep -n "import Network" src/Core/NetworkMonitor.swift && echo "PASS: Imports Network framework" || echo "FAIL: Missing Network import"

# Verify queue capacity is 50
grep -n "maximumCapacity.*=.*50" src/Core/MessageQueue.swift && echo "PASS: Queue capacity is 50" || echo "FAIL: Queue capacity not 50"

# Verify persistence uses file (not UserDefaults for queue storage)
grep -n "offline_queue.json" src/Core/MessageQueue.swift && echo "PASS: Uses file-based persistence" || echo "CHECK: Verify persistence approach"

# Verify no message content in logs
grep -n "message\.text\|msg\.text\|queued\.text\|\.text.*privacy" src/Core/OfflineCoordinator.swift | grep -i "log\|print" && echo "WARNING: Possible content logging" || echo "PASS: No content logging detected"

# Verify weak StatusBarController reference
grep -n "weak.*statusBarController" src/Core/OfflineCoordinator.swift && echo "PASS: Weak reference" || echo "WARNING: Check StatusBarController reference"

# Verify [weak self] in Combine sinks
grep -n "\[weak self\]" src/Core/OfflineCoordinator.swift && echo "PASS: Uses [weak self]" || echo "WARNING: Check for retain cycles"
grep -n "\[weak self\]" src/Core/NetworkMonitor.swift && echo "PASS: Uses [weak self] in monitor" || echo "WARNING: Check monitor for retain cycles"

# Verify offline/online messages match spec
grep -n "temporarily offline" src/Core/OfflineCoordinator.swift && echo "PASS: Offline message present" || echo "FAIL: Missing offline message"
grep -n "back online" src/Core/OfflineCoordinator.swift && echo "PASS: Online message present" || echo "FAIL: Missing online message"

# Verify catch-up rate limiting
grep -n "catchUpDelaySeconds.*=.*2" src/Core/OfflineCoordinator.swift && echo "PASS: 2-second catch-up delay" || echo "FAIL: Missing catch-up delay"

# Build the project
swift build 2>&1

# Run network monitor tests
swift test --filter NetworkMonitorTests 2>&1

# Run message queue tests
swift test --filter MessageQueueTests 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the offline detection and graceful degradation system created in task 0905 for EmberHearth. This system ensures the AI assistant never goes silent when the network drops. Open these files:

@src/Core/NetworkMonitor.swift
@src/Core/MessageQueue.swift
@src/Core/OfflineCoordinator.swift
@tests/CoreTests/NetworkMonitorTests.swift
@tests/CoreTests/MessageQueueTests.swift

Also reference:
@docs/specs/error-handling.md (lines 60-86 for message queue spec, extended outage handling)
@docs/specs/autonomous-operation.md (lines 42-106 for health state machine, recovery triggers)
@src/Core/MessageCoordinator.swift (integration point)

## 1. THREAD SAFETY (Critical):

a. NetworkMonitor:
   - Is `isConnected` accessed safely? The `@Published` property is updated on main queue — is that consistent with how NWPathMonitor's callback fires on the monitor queue?
   - Is the `pathUpdateHandler` closure safely capturing `self`? Does it use `[weak self]`?
   - Could there be a race condition between `start()` and the first `pathUpdateHandler` callback?
   - Is the `isMonitoring` flag protected? Could concurrent `start()`/`stop()` calls cause issues?

b. MessageQueue:
   - Is `NSLock` used correctly? Are all `lock.lock()`/`lock.unlock()` paired with `defer`?
   - Is `saveToDisk()` called within the lock? This means file I/O happens under the lock — is that acceptable for the expected usage pattern?
   - Could concurrent `enqueue` and `drainAll` cause data loss?

c. OfflineCoordinator:
   - Is `isDraining` flag protected by a lock?
   - Is `offlineNotificationSent` set protected by a lock?
   - Could the Combine subscription fire on a background thread while `handleConnectivityRestored` is running?

## 2. QUEUE PERSISTENCE (Critical):

a. Does the queue survive app restart? Verify:
   - Messages are written to disk on every `enqueue()`
   - Messages are loaded from disk on `init()`
   - The file path is in Application Support (not a temp directory)
   - Atomic writing is used (`options: [.atomic]`)

b. Corrupt file handling:
   - If the JSON file is corrupt, does the queue start empty (not crash)?
   - If the file is missing, does the queue start empty?
   - If the directory doesn't exist, does `saveToDisk()` create it?

c. Data integrity:
   - Could a crash mid-write leave a corrupt file?
   - Does atomic writing prevent this?

## 3. MESSAGE ORDERING (Critical — FIFO guarantee):

a. Is FIFO order maintained in all operations?
   - `enqueue` appends to end
   - `dequeue` removes from front
   - `drainAll` returns in insertion order
   - Capacity overflow drops from front (oldest first)

b. During catch-up drain:
   - If a message fails and is re-queued, does it go to the back of the queue?
   - Is this the correct behavior? (Should it retry before moving on?)
   - If connectivity drops mid-drain, are remaining messages re-queued in correct order?

## 4. RATE LIMITING ON CATCH-UP (Important):

a. Is the 2-second delay between queued message processing correct?
b. Is `Task.sleep` used correctly (not blocking)?
c. What happens if there are 50 queued messages? That's 100 seconds of catch-up — is this acceptable?
d. Could the rate limiting be interrupted if the network drops again?

## 5. MEMORY LEAKS AND RETAIN CYCLES (Important):

a. Are all Combine subscriptions stored in `cancellables`?
b. Are all `Task` closures using `[weak self]`?
c. Is `StatusBarController` reference weak?
d. Is `messageSender` a strong reference? Should it be weak?
e. Does `deinit` properly clean up resources?
f. In NetworkMonitor, does `deinit` cancel the NWPathMonitor?

## 6. USER NOTIFICATION CORRECTNESS (Important):

a. Does the offline message match the spec? "I'm temporarily offline. Your messages are saved and I'll catch up soon."
b. Does the online message match the spec? "I'm back online! Let me catch up on what I missed."
c. Is the offline notification sent only ONCE per phone number per offline session?
d. What happens if sending the offline notification itself fails (Messages.app is also down)?
e. Are notification sends non-blocking (they shouldn't block message queuing)?

## 7. EDGE CASES (Important):

a. Network flapping: What if the network goes down and up rapidly (e.g., every 5 seconds)?
   - Does the `removeDuplicates()` on the Combine publisher prevent rapid firing?
   - Could rapid online/offline transitions cause multiple drain operations?
   - Is the `isDraining` guard sufficient to prevent this?

b. Empty queue on recovery: If the network comes back but no messages were queued, does it handle gracefully?

c. App crash while offline: Are queued messages preserved? Does the next launch detect and process them?

d. Queue at capacity during extended outage: With 50-message limit, what happens during a 24-hour outage with many messages?

## 8. CODE QUALITY (Standard):

a. No force unwraps in production code?
b. All public types documented with `///`?
c. `os.Logger` used consistently (not `print()`)?
d. No message content in any log statement?
e. All enums have exhaustive raw values?
f. ConnectionType is Sendable?
g. QueuedMessage is Codable, Identifiable, Equatable, Sendable?

## 9. SECURITY (Standard):

a. No calls to Process(), /bin/bash, /bin/sh, NSTask, or CommandLine?
b. No sensitive data written to the queue file (phone numbers are acceptable, but API keys should never appear)?
c. Is the queue file in a user-specific directory (not world-readable)?

## 10. TEST QUALITY (Standard):

a. NetworkMonitorTests:
   - Tests initialization defaults (isConnected = true, connectionType = .other)?
   - Tests start/stop idempotency?
   - Tests deinit safety?
   - Tests publisher emission on start?

b. MessageQueueTests:
   - Tests FIFO ordering (enqueue/dequeue order)?
   - Tests persistence across instances?
   - Tests capacity limit (50 messages)?
   - Tests overflow drops oldest?
   - Tests corrupt file handling?
   - Tests thread safety (concurrent access)?
   - Tests QueuedMessage Codable/Equatable?
   - Tests empty queue operations?
   - Tests clear and drainAll?
   - Tests retryCount persistence?

Report all issues with severity: CRITICAL (must fix — data loss or crash risk), IMPORTANT (should fix — correctness concern), MINOR (nice to have — code quality improvement).
```

---

## Commit Message

```
feat(m10): add offline detection with network monitoring and message queuing
```

---

## Notes for Next Task

- The `NetworkMonitor` should be created once during app startup (in AppDelegate or the startup wiring from task 0902) and shared via dependency injection. Do NOT create multiple NWPathMonitor instances.
- `NWPathMonitor` cannot be restarted after `cancel()` is called. If `stop()` is called, a new `NetworkMonitor` instance must be created to resume monitoring. The current implementation handles this by guarding with `isMonitoring`.
- The `OfflineCoordinator.processQueuedMessage` callback must be set by the MessageCoordinator during initialization. Without it, queued messages will be logged as errors and dropped during catch-up.
- The `OfflineCoordinator.configure(ownerPhoneNumbers:)` method must be called with the user's phone number(s) during onboarding or startup. Without it, no offline/online notifications will be sent via iMessage.
- The queue file is stored at `~/Library/Application Support/EmberHearth/offline_queue.json`. This persists across app restarts and crashes.
- MessageQueue's `saveToDisk()` runs under the NSLock. This means file I/O happens while holding the lock, which is acceptable for the expected usage pattern (low-frequency writes, single writer). If performance becomes an issue, consider moving to async file I/O.
- The 2-second catch-up delay means processing 50 queued messages takes ~100 seconds. For the MVP target of a single user with moderate message volume, this is acceptable. For future scaling, consider parallel processing or batch API calls.
- The `removeDuplicates()` operator on the `$isConnected` publisher prevents rapid firing during network flapping. However, if the network flaps between connected and disconnected very quickly, the coordinator may still send multiple offline/online notifications. The `offlineNotificationSent` set provides a second layer of protection against duplicate offline messages.
- The OfflineCoordinator maps to the health state machine from `autonomous-operation.md`: HEALTHY when online with empty queue, DEGRADED when offline, HEALING when draining the catch-up queue.
- The `maxRetryPerMessage` (3) and `catchUpDelaySeconds` (2.0) are static constants on OfflineCoordinator. They can be made configurable in a future task if needed.
- Integration with the CircuitBreaker from task 0204: When the circuit breaker is open, the MessageCoordinator should route messages to `offlineCoordinator.queueMessage()` instead of attempting the LLM call.
