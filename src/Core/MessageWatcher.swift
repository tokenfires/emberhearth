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

    /// Maximum number of retries when the database is locked during a check.
    private static let maxLockedRetries = 3

    /// Delay between retries when the database is locked (doubles each attempt).
    private static let lockedRetryBaseDelay: TimeInterval = 0.25

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

        guard FileManager.default.fileExists(atPath: chatDBPath) else {
            logger.error("chat.db not found at: \(self.chatDBPath, privacy: .public)")
            throw ChatDatabaseError.databaseNotFound(path: chatDBPath)
        }

        try databaseReader.open()

        do {
            // Initialize lastProcessedRowId if this is the first run.
            // Set it to the current max so we don't process historical messages.
            if lastProcessedRowId == 0 {
                let maxRowId = try databaseReader.getMaxRowId()
                lastProcessedRowId = maxRowId
                logger.info("Initialized lastProcessedRowId to \(maxRowId)")
            }
        } catch {
            databaseReader.close()
            throw error
        }

        fileDescriptor = Darwin.open(chatDBPath, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            databaseReader.close()
            let posixError = NSError(
                domain: "POSIX",
                code: Int(errno),
                userInfo: [NSLocalizedDescriptionKey: "Failed to open file descriptor: \(String(cString: strerror(errno)))"]
            )
            logger.error("Failed to open file descriptor for chat.db")
            throw ChatDatabaseError.databaseOpenFailed(underlyingError: posixError)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename],
            queue: watcherQueue
        )

        source.setEventHandler { [weak self, weak source] in
            guard let self = self else { return }
            if let flags = source?.data, flags.contains(.rename) {
                self.logger.warning("chat.db was renamed or replaced — watcher may need restart")
            }
            self.handleFileChangeEvent()
        }

        source.setCancelHandler { }

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

        if fileDescriptor >= 0 {
            Darwin.close(fileDescriptor)
            fileDescriptor = -1
        }

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
        debounceWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.checkForNewMessages()
        }

        debounceWorkItem = workItem
        watcherQueue.asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }

    /// Queries the database for messages newer than lastProcessedRowId.
    /// Filters to incoming messages only and publishes them.
    /// Retries with exponential backoff when the database is locked.
    private func checkForNewMessages() {
        checkForNewMessages(attempt: 0)
    }

    private func checkForNewMessages(attempt: Int) {
        do {
            let newMessages = try databaseReader.fetchMessagesSince(rowId: lastProcessedRowId)

            guard !newMessages.isEmpty else {
                logger.debug("File change detected but no new messages found")
                return
            }

            let incomingMessages = newMessages.filter { !$0.isFromMe }

            // Always advance the cursor, even for outgoing-only batches,
            // to prevent the watcher from re-examining the same rows on the next event.
            if let lastMessage = newMessages.last {
                lastProcessedRowId = lastMessage.id
                logger.info("Updated lastProcessedRowId to \(lastMessage.id)")
            }

            guard !incomingMessages.isEmpty else {
                logger.debug("New messages found but all were outgoing (is_from_me)")
                return
            }

            logger.info("Detected \(incomingMessages.count) new incoming message(s)")

            messageSubject.send(incomingMessages)
            delegate?.messageWatcher(self, didReceiveMessages: incomingMessages)

        } catch let error as ChatDatabaseError where error.isDatabaseLocked && attempt < Self.maxLockedRetries {
            let delay = Self.lockedRetryBaseDelay * pow(2.0, Double(attempt))
            logger.warning("Database locked, retrying in \(delay)s (attempt \(attempt + 1)/\(Self.maxLockedRetries))")
            watcherQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.checkForNewMessages(attempt: attempt + 1)
            }
        } catch {
            logger.error("Error checking for new messages: \(error.localizedDescription, privacy: .public)")
            delegate?.messageWatcher(self, didEncounterError: error)
        }
    }
}
