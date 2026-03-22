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
/// Conforms to Codable for persistent storage via JSON file.
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

    /// UserDefaults key reserved for future fallback use.
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
            guard let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first else {
                let fallback = FileManager.default.temporaryDirectory
                    .appendingPathComponent("EmberHearth", isDirectory: true)
                    .appendingPathComponent("offline_queue.json")
                self.storageURL = fallback
                loadFromDisk()
                return
            }
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
