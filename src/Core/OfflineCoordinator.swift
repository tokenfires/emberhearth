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
///     appState: appState
/// )
/// coordinator.start()
/// ```
final class OfflineCoordinator: @unchecked Sendable {

    // MARK: - Properties

    /// The network connectivity monitor.
    private let networkMonitor: NetworkMonitor

    /// The persistent message queue for offline messages.
    private let messageQueue: MessageQueue

    /// The message sender for iMessage communication.
    /// Used to notify the user about offline/online transitions.
    private let messageSender: any MessageSendingProtocol

    /// The shared app state for updating status indicators.
    /// Weak reference to avoid retain cycles; `AppState` is `@MainActor`.
    private weak var appState: AppState?

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
    ///   - appState: The shared app state for status transitions (optional, weak reference).
    init(
        networkMonitor: NetworkMonitor,
        messageQueue: MessageQueue,
        messageSender: any MessageSendingProtocol,
        appState: AppState? = nil
    ) {
        self.networkMonitor = networkMonitor
        self.messageQueue = messageQueue
        self.messageSender = messageSender
        self.appState = appState
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

        // Update status bar via AppState (main actor)
        Task { @MainActor [weak self] in
            self?.appState?.addError(.noInternet)
        }
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
    /// Updates the app state to reflect the offline state and notifies
    /// all configured owner phone numbers.
    private func handleConnectivityLost() {
        logger.warning("Connectivity lost. Entering offline mode.")

        // Update app state to offline (main actor)
        Task { @MainActor [weak self] in
            self?.appState?.transition(to: .offline)
        }

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

        // Update app state (main actor)
        if !messageQueue.isEmpty {
            Task { @MainActor [weak self] in
                self?.appState?.transition(to: .processing)
            }
        } else {
            Task { @MainActor [weak self] in
                self?.appState?.removeError(withId: "noInternet")
            }
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
                self.lock.withLock {
                    self.isDraining = false
                }
            }

            let messages = self.messageQueue.drainAll()
            guard !messages.isEmpty else {
                self.logger.debug("Queue is empty, nothing to drain")
                Task { @MainActor [weak self] in
                    self?.appState?.removeError(withId: "noInternet")
                }
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

            // If all processed successfully, clear the offline error
            if self.messageQueue.isEmpty {
                Task { @MainActor [weak self] in
                    self?.appState?.removeError(withId: "noInternet")
                }
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
