// ServiceContainer.swift
// EmberHearth
//
// Lightweight dependency container constructed during app startup.
// Holds references to all initialized services for the application lifetime.
//
// This is NOT a service locator pattern — components receive their dependencies
// through constructor injection. The container just manages the lifecycle.

import Foundation
import os

/// Holds all initialized services for the application.
///
/// Created once during `applicationDidFinishLaunching` and retained for the
/// app's lifetime. Components are initialized in dependency order and torn
/// down in reverse order during shutdown.
///
/// Usage:
/// ```swift
/// let container = try ServiceContainer.initialize(apiKey: key)
/// try container.start()
/// ```
final class ServiceContainer {

    // MARK: - Core Services

    /// The SQLite database manager for memory and session storage.
    let database: DatabaseManager

    /// The application state manager.
    let appState: AppState

    // MARK: - Security Services

    /// The Tron security pipeline (inbound/outbound message screening).
    let tronPipeline: TronPipeline

    // MARK: - Memory Services

    /// Fact storage (CRUD operations).
    let factStore: FactStore

    /// Fact retrieval (relevance-based search).
    let factRetriever: FactRetriever

    /// Fact extraction from conversations.
    let factExtractor: FactExtractor

    // MARK: - Session Services

    /// Conversation session management.
    let sessionManager: SessionManager

    // MARK: - LLM Services

    /// The Claude API client for LLM interactions.
    let llmClient: ClaudeAPIClient

    /// Context builder for assembling LLM messages.
    let contextBuilder: ContextBuilder

    /// Rolling summary generator for long conversations.
    let summaryGenerator: SummaryGenerator

    // MARK: - Network & Offline Services

    /// Network connectivity monitor (wraps NWPathMonitor).
    let networkMonitor: NetworkMonitor

    /// Persistent FIFO queue for messages received while offline.
    let messageQueue: MessageQueue

    /// Bridges network monitoring, message queuing, and pipeline recovery.
    let offlineCoordinator: OfflineCoordinator

    // MARK: - iMessage Services

    /// Message sender (AppleScript-based).
    let messageSender: MessageSender

    /// File system events watcher that detects new iMessages.
    let messageWatcher: MessageWatcher

    /// The central message coordinator.
    let messageCoordinator: MessageCoordinator

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ServiceContainer"
    )

    // MARK: - Private Initialization

    private init(
        database: DatabaseManager,
        appState: AppState,
        tronPipeline: TronPipeline,
        factStore: FactStore,
        factRetriever: FactRetriever,
        factExtractor: FactExtractor,
        sessionManager: SessionManager,
        llmClient: ClaudeAPIClient,
        contextBuilder: ContextBuilder,
        summaryGenerator: SummaryGenerator,
        networkMonitor: NetworkMonitor,
        messageQueue: MessageQueue,
        offlineCoordinator: OfflineCoordinator,
        messageSender: MessageSender,
        messageWatcher: MessageWatcher,
        messageCoordinator: MessageCoordinator
    ) {
        self.database = database
        self.appState = appState
        self.tronPipeline = tronPipeline
        self.factStore = factStore
        self.factRetriever = factRetriever
        self.factExtractor = factExtractor
        self.sessionManager = sessionManager
        self.llmClient = llmClient
        self.contextBuilder = contextBuilder
        self.summaryGenerator = summaryGenerator
        self.networkMonitor = networkMonitor
        self.messageQueue = messageQueue
        self.offlineCoordinator = offlineCoordinator
        self.messageSender = messageSender
        self.messageWatcher = messageWatcher
        self.messageCoordinator = messageCoordinator
    }

    // MARK: - Factory

    /// Initializes all services in dependency order.
    ///
    /// This is the main entry point for starting the application. Steps:
    /// 1. Creates the database (or opens existing)
    /// 2. Initializes app state and security pipeline
    /// 3. Initializes memory system (facts, sessions)
    /// 4. Initializes LLM client (loads API key from caller)
    /// 5. Initializes context and personality
    /// 6. Initializes iMessage integration
    /// 7. Wires everything into the MessageCoordinator
    ///
    /// - Parameter apiKey: The Claude API key retrieved from Keychain by the caller.
    /// - Returns: A fully initialized `ServiceContainer`.
    /// - Throws: `AppStartupError` if any critical component fails to initialize.
    @MainActor
    static func initialize(apiKey: String) throws -> ServiceContainer {
        let startTime = CFAbsoluteTimeGetCurrent()

        // ── Step 1: Database ──
        let dbStepStart = CFAbsoluteTimeGetCurrent()
        let database: DatabaseManager
        do {
            database = try DatabaseManager()
        } catch {
            throw AppStartupError.databaseInitializationFailed(underlying: error)
        }
        logger.info("Database initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - dbStepStart) * 1000))ms")

        // ── Step 2: App State ──
        let appState = AppState()

        // ── Step 3: Security Pipeline ──
        let secStepStart = CFAbsoluteTimeGetCurrent()
        let tronPipeline = TronPipeline()
        logger.info("Security pipeline initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - secStepStart) * 1000))ms")

        // ── Step 4: Memory System ──
        let memStepStart = CFAbsoluteTimeGetCurrent()
        let factStore = FactStore(database: database)
        let factRetriever = FactRetriever(factStore: factStore)
        logger.info("Memory system initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - memStepStart) * 1000))ms")

        // ── Step 5: Session Manager ──
        let sessionManager = SessionManager(database: database)

        // ── Step 6: LLM Client ──
        let llmStepStart = CFAbsoluteTimeGetCurrent()
        let llmClient = ClaudeAPIClient(apiKey: apiKey)
        logger.info("LLM client initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - llmStepStart) * 1000))ms")

        // ── Step 7: Fact Extractor (depends on LLM client + FactStore) ──
        let factExtractor = FactExtractor(llmProvider: llmClient, factStore: factStore)

        // ── Step 8: Personality & Context ──
        let contextBuilder = ContextBuilder()
        let summaryGenerator = SummaryGenerator()

        // ── Step 9: iMessage Integration ──
        let messageSender = MessageSender()
        let messageWatcher = MessageWatcher()

        // ── Step 10: Network & Offline ──
        let networkMonitor = NetworkMonitor()
        let messageQueue = MessageQueue()
        let offlineCoordinator = OfflineCoordinator(
            networkMonitor: networkMonitor,
            messageQueue: messageQueue,
            messageSender: messageSender,
            appState: appState
        )

        // ── Step 11: Message Coordinator (wires everything together) ──
        let messageCoordinator = MessageCoordinator(
            tronPipeline: tronPipeline,
            messageSender: messageSender,
            llmClient: llmClient,
            sessionManager: sessionManager,
            factRetriever: factRetriever,
            factExtractor: factExtractor,
            contextBuilder: contextBuilder,
            summaryGenerator: summaryGenerator,
            messageWatcher: messageWatcher,
            appState: appState,
            offlineCoordinator: offlineCoordinator
        )

        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("All services initialized in \(String(format: "%.0f", totalTime))ms")

        return ServiceContainer(
            database: database,
            appState: appState,
            tronPipeline: tronPipeline,
            factStore: factStore,
            factRetriever: factRetriever,
            factExtractor: factExtractor,
            sessionManager: sessionManager,
            llmClient: llmClient,
            contextBuilder: contextBuilder,
            summaryGenerator: summaryGenerator,
            networkMonitor: networkMonitor,
            messageQueue: messageQueue,
            offlineCoordinator: offlineCoordinator,
            messageSender: messageSender,
            messageWatcher: messageWatcher,
            messageCoordinator: messageCoordinator
        )
    }

    // MARK: - Lifecycle

    /// Starts all runtime services in dependency order.
    ///
    /// 1. Starts network monitoring (connectivity detection).
    /// 2. Starts the offline coordinator (queue restoration + Combine subscriptions).
    /// 3. Starts the message coordinator (begins watching for new iMessages).
    ///
    /// - Throws: `ChatDatabaseError.databaseNotFound` if chat.db doesn't exist
    ///   (Full Disk Access not granted), or other errors if the watcher fails to start.
    func start() throws {
        networkMonitor.start()
        offlineCoordinator.start()
        try messageCoordinator.start()
    }

    /// Performs a clean shutdown of all services.
    ///
    /// Call this from `applicationWillTerminate`. Services are stopped in
    /// reverse initialization order:
    /// 1. Stop message coordinator (also stops the watcher)
    /// 2. Stop offline coordinator (cancels subscriptions, preserves queue)
    /// 3. Stop network monitor (releases NWPathMonitor)
    /// 4. Close database connection
    func shutdown() {
        Self.logger.info("Beginning clean shutdown...")
        messageCoordinator.stop()
        offlineCoordinator.stop()
        networkMonitor.stop()
        database.close()
        Self.logger.info("Clean shutdown complete.")
    }
}

// MARK: - AppStartupError

/// Errors that can occur during app startup.
enum AppStartupError: Error, LocalizedError {
    /// The database could not be initialized.
    case databaseInitializationFailed(underlying: Error)

    /// No API key was found in the Keychain.
    case noAPIKey

    /// The API key is invalid (e.g., wrong format).
    case invalidAPIKey

    /// A required permission was not granted.
    case missingPermission(String)

    /// A component failed to initialize.
    case componentInitializationFailed(component: String, underlying: Error)

    /// The iMessage database (chat.db) was not found — Full Disk Access may not be granted.
    case chatDatabaseNotFound

    var errorDescription: String? {
        switch self {
        case .databaseInitializationFailed(let error):
            return "Failed to initialize database: \(error.localizedDescription)"
        case .noAPIKey:
            return "No API key found. Please add your Claude API key in Settings."
        case .invalidAPIKey:
            return "The stored API key appears to be invalid. Please update it in Settings."
        case .missingPermission(let permission):
            return "EmberHearth needs the '\(permission)' permission to work properly."
        case .componentInitializationFailed(let component, let error):
            return "Failed to initialize \(component): \(error.localizedDescription)"
        case .chatDatabaseNotFound:
            return "The iMessage database could not be found. Please grant Full Disk Access in System Settings > Privacy & Security."
        }
    }
}
