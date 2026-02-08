# Task 0902: App Startup Sequence and Final Wiring

**Milestone:** M10 - Final Integration
**Unit:** 10.3 - Complete Startup Sequence with Dependency Injection
**Phase:** Final
**Depends On:** 0901 (Build Configuration)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; security boundaries, core principles, project structure
2. `docs/VISION.md` — Read the "Architecture" section for how components connect
3. `docs/architecture-overview.md` — Read entirely; understand the component dependency graph
4. `src/App/AppDelegate.swift` — Full file; this is the primary file to update
5. `src/App/EmberHearthApp.swift` — Full file; the SwiftUI app entry point
6. `src/App/AppState.swift` — Full file; understand state management
7. `src/Core/MessageCoordinator.swift` — Full file; understand what dependencies it needs
8. `src/Database/DatabaseManager.swift` — Full file; understand initialization
9. `src/Security/TronPipeline.swift` — Full file; understand initialization
10. `src/LLM/ClaudeAPIClient.swift` — Full file; understand how API key is loaded
11. `src/iMessage/MessageWatcher.swift` — Full file; understand how to start watching

> **Context Budget Note:** This task references many source files because it wires everything together. Focus on the constructor/initializer of each component to understand what dependencies it needs. You do not need to read internal method implementations.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the complete app startup sequence for EmberHearth, a native macOS personal AI assistant. This task wires all previously-created components together into a working application using dependency injection.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., AppDelegate.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask) in source code
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- Use Keychain for API key storage — never hardcode credentials
- All UI must support VoiceOver

## What You Are Building

The complete app startup sequence that:
1. Initializes all components in the correct dependency order
2. Handles initialization failures gracefully
3. Uses dependency injection (no singletons)
4. Starts the message watching loop
5. Handles clean shutdown

## Architecture: Component Dependency Graph

```
AppDelegate
├── AppLogger (standalone)
├── CrashRecoveryManager (standalone)
├── DatabaseManager (path: ~/Library/Application Support/EmberHearth/ember.db)
├── AppState (standalone)
├── StatusBarController (depends: AppState)
├── KeychainManager (standalone)
├── TronPipeline (standalone)
│   └── CrisisDetector (integrated)
│   └── InjectionScanner (integrated)
│   └── CredentialScanner (integrated)
├── FactStore (depends: DatabaseManager)
├── FactRetriever (depends: FactStore)
├── FactExtractor (depends: FactStore)
├── SessionManager (depends: DatabaseManager)
├── ClaudeAPIClient (depends: API key from Keychain)
├── SystemPromptBuilder (standalone)
├── VerbosityAdapter (standalone)
├── ContextBuilder (depends: FactRetriever, SessionManager, SystemPromptBuilder, VerbosityAdapter)
├── PhoneNumberFilter (depends: authorized numbers from settings)
├── MessageCoordinator (depends: ClaudeAPIClient, MessageSender, TronPipeline, SessionManager,
│                                FactStore, FactExtractor, ContextBuilder, PhoneNumberFilter)
├── MessageSender (standalone)
├── ChatDatabaseReader (standalone)
└── MessageWatcher (depends: ChatDatabaseReader, MessageCoordinator, PhoneNumberFilter)
```

## Files to Create/Update

### 1. src/App/ServiceContainer.swift (NEW)

A lightweight dependency container that holds all initialized services. This is NOT a service locator — it's constructed once at startup and passed where needed.

```swift
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
/// let container = try ServiceContainer.initialize()
/// container.messageWatcher.startWatching()
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

    /// System prompt builder for Ember's personality.
    let systemPromptBuilder: SystemPromptBuilder

    /// Verbosity adaptation logic.
    let verbosityAdapter: VerbosityAdapter

    /// Context builder for assembling LLM messages.
    let contextBuilder: ContextBuilder

    // MARK: - iMessage Services

    /// Phone number authorization filter.
    let phoneNumberFilter: PhoneNumberFilter

    /// Message sender (AppleScript-based).
    let messageSender: MessageSender

    /// Chat database reader (chat.db watcher).
    let chatDatabaseReader: ChatDatabaseReader

    /// The central message coordinator.
    let messageCoordinator: MessageCoordinator

    /// The file system events watcher that detects new messages.
    let messageWatcher: MessageWatcher

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ServiceContainer"
    )

    // MARK: - Initialization

    /// Private initializer — use `ServiceContainer.initialize()` instead.
    private init(
        database: DatabaseManager,
        appState: AppState,
        tronPipeline: TronPipeline,
        factStore: FactStore,
        factRetriever: FactRetriever,
        factExtractor: FactExtractor,
        sessionManager: SessionManager,
        llmClient: ClaudeAPIClient,
        systemPromptBuilder: SystemPromptBuilder,
        verbosityAdapter: VerbosityAdapter,
        contextBuilder: ContextBuilder,
        phoneNumberFilter: PhoneNumberFilter,
        messageSender: MessageSender,
        chatDatabaseReader: ChatDatabaseReader,
        messageCoordinator: MessageCoordinator,
        messageWatcher: MessageWatcher
    ) {
        self.database = database
        self.appState = appState
        self.tronPipeline = tronPipeline
        self.factStore = factStore
        self.factRetriever = factRetriever
        self.factExtractor = factExtractor
        self.sessionManager = sessionManager
        self.llmClient = llmClient
        self.systemPromptBuilder = systemPromptBuilder
        self.verbosityAdapter = verbosityAdapter
        self.contextBuilder = contextBuilder
        self.phoneNumberFilter = phoneNumberFilter
        self.messageSender = messageSender
        self.chatDatabaseReader = chatDatabaseReader
        self.messageCoordinator = messageCoordinator
        self.messageWatcher = messageWatcher
    }

    /// Initializes all services in dependency order.
    ///
    /// This is the main entry point for starting the application. It:
    /// 1. Creates the database (or opens existing)
    /// 2. Initializes security pipeline
    /// 3. Initializes memory system
    /// 4. Initializes LLM client (loads API key from Keychain)
    /// 5. Initializes personality/context
    /// 6. Initializes iMessage integration
    /// 7. Wires everything into the MessageCoordinator
    ///
    /// - Parameter apiKey: The Claude API key (loaded from Keychain by the caller).
    /// - Returns: A fully initialized ServiceContainer.
    /// - Throws: `AppStartupError` if any critical component fails to initialize.
    static func initialize(apiKey: String) throws -> ServiceContainer {
        let startTime = CFAbsoluteTimeGetCurrent()

        // ── Step 1: Database ──
        let dbStepStart = CFAbsoluteTimeGetCurrent()
        let dbPath = try Self.databasePath()
        let database = try DatabaseManager(path: dbPath)
        logger.info("Database initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - dbStepStart) * 1000))ms")

        // ── Step 2: App State ──
        let appState = AppState()
        appState.updateState(.initializing)

        // ── Step 3: Security Pipeline ──
        let secStepStart = CFAbsoluteTimeGetCurrent()
        let tronPipeline = TronPipeline()
        logger.info("Security pipeline initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - secStepStart) * 1000))ms")

        // ── Step 4: Memory System ──
        let memStepStart = CFAbsoluteTimeGetCurrent()
        let factStore = FactStore(database: database)
        let factRetriever = FactRetriever(factStore: factStore)
        let factExtractor = FactExtractor(factStore: factStore)
        logger.info("Memory system initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - memStepStart) * 1000))ms")

        // ── Step 5: Session Manager ──
        let sessionManager = SessionManager(database: database)

        // ── Step 6: LLM Client ──
        let llmStepStart = CFAbsoluteTimeGetCurrent()
        let llmClient = ClaudeAPIClient(apiKey: apiKey)
        logger.info("LLM client initialized in \(String(format: "%.0f", (CFAbsoluteTimeGetCurrent() - llmStepStart) * 1000))ms")

        // ── Step 7: Personality & Context ──
        let systemPromptBuilder = SystemPromptBuilder()
        let verbosityAdapter = VerbosityAdapter()
        let contextBuilder = ContextBuilder(
            factRetriever: factRetriever,
            sessionManager: sessionManager,
            systemPromptBuilder: systemPromptBuilder,
            verbosityAdapter: verbosityAdapter
        )

        // ── Step 8: iMessage Integration ──
        let phoneNumberFilter = PhoneNumberFilter()
        let messageSender = MessageSender()
        let chatDatabaseReader = ChatDatabaseReader()

        // ── Step 9: Message Coordinator (wires everything together) ──
        let messageCoordinator = MessageCoordinator(
            llmClient: llmClient,
            messageSender: messageSender,
            tronPipeline: tronPipeline,
            sessionManager: sessionManager,
            factStore: factStore,
            factExtractor: factExtractor,
            contextBuilder: contextBuilder,
            phoneNumberFilter: phoneNumberFilter
        )

        // ── Step 10: Message Watcher ──
        let messageWatcher = MessageWatcher(
            chatDatabaseReader: chatDatabaseReader,
            messageCoordinator: messageCoordinator,
            phoneNumberFilter: phoneNumberFilter
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
            systemPromptBuilder: systemPromptBuilder,
            verbosityAdapter: verbosityAdapter,
            contextBuilder: contextBuilder,
            phoneNumberFilter: phoneNumberFilter,
            messageSender: messageSender,
            chatDatabaseReader: chatDatabaseReader,
            messageCoordinator: messageCoordinator,
            messageWatcher: messageWatcher
        )
    }

    // MARK: - Shutdown

    /// Performs clean shutdown of all services.
    ///
    /// Call this from `applicationWillTerminate`. Services are shut down
    /// in reverse initialization order.
    func shutdown() {
        Self.logger.info("Beginning clean shutdown...")

        // Stop watching for new messages
        messageWatcher.stopWatching()

        // End active sessions
        sessionManager.endAllActiveSessions()

        // Flush database WAL
        database.checkpoint()

        Self.logger.info("Clean shutdown complete.")
    }

    // MARK: - Private Helpers

    /// Returns the path to the database file, creating the directory if needed.
    private static func databasePath() throws -> String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let emberDir = appSupport.appendingPathComponent("EmberHearth", isDirectory: true)

        if !FileManager.default.fileExists(atPath: emberDir.path) {
            try FileManager.default.createDirectory(
                at: emberDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }

        return emberDir.appendingPathComponent("ember.db").path
    }
}

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
        }
    }
}
```

### 2. Update src/App/AppDelegate.swift

Update the existing AppDelegate to implement the complete startup sequence.

```swift
// AppDelegate.swift
// EmberHearth
//
// Application delegate managing the startup sequence, menu bar, and lifecycle.

import Cocoa
import os

/// The application delegate for EmberHearth.
///
/// Manages the complete lifecycle:
/// - Startup: Initializes all components via ServiceContainer
/// - Running: Manages the menu bar and settings window
/// - Shutdown: Performs clean teardown of all services
@main
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// The service container holding all initialized components.
    /// nil until startup completes successfully.
    private var services: ServiceContainer?

    /// The status bar controller for the menu bar icon.
    private var statusBarController: StatusBarController?

    /// Logger for startup and lifecycle events.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "AppDelegate"
    )

    /// Flag to detect whether the last shutdown was clean.
    private static let cleanShutdownKey = "lastShutdownClean"

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("EmberHearth starting up...")

        // Step 1: Initialize logging
        logger.info("App version: \(AppVersion.displayString)")

        // Step 2: Check for crash recovery
        checkForCrashRecovery()

        // Step 3: Check if onboarding is complete
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboardingComplete")

        if !hasCompletedOnboarding {
            logger.info("Onboarding not complete, showing onboarding window")
            showOnboardingWindow()
            return
        }

        // Step 4: Load API key from Keychain
        guard let apiKey = loadAPIKey() else {
            logger.warning("No API key found in Keychain, showing onboarding")
            showOnboardingWindow()
            return
        }

        // Step 5: Initialize all services
        startServices(apiKey: apiKey)
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("EmberHearth shutting down...")

        // Clean shutdown
        services?.shutdown()

        // Mark clean shutdown
        UserDefaults.standard.set(true, forKey: Self.cleanShutdownKey)

        logger.info("Shutdown complete.")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar app — don't terminate when windows close
        return false
    }

    // MARK: - Startup Helpers

    /// Initializes all services and starts the message watcher.
    ///
    /// If initialization fails at any step, the user is shown an appropriate
    /// error message with options to fix the issue.
    private func startServices(apiKey: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            // Initialize the service container (all components)
            let container = try ServiceContainer.initialize(apiKey: apiKey)
            self.services = container

            // Set up the status bar
            statusBarController = StatusBarController(appState: container.appState)

            // Start watching for messages
            container.messageWatcher.startWatching()

            // Update app state to ready
            container.appState.updateState(.ready)

            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            logger.info("EmberHearth ready in \(String(format: "%.0f", totalTime))ms")

            // Target: <3 seconds
            if totalTime > 3000 {
                logger.warning("Startup took \(String(format: "%.0f", totalTime))ms (target: <3000ms)")
            }

        } catch let error as AppStartupError {
            logger.error("Startup failed: \(error.localizedDescription)")
            handleStartupError(error)
        } catch {
            logger.error("Unexpected startup error: \(error.localizedDescription)")
            handleStartupError(.componentInitializationFailed(
                component: "unknown",
                underlying: error
            ))
        }
    }

    /// Loads the Claude API key from the Keychain.
    ///
    /// - Returns: The API key string, or nil if not found.
    private func loadAPIKey() -> String? {
        do {
            let key = try KeychainManager.retrieve(
                service: "com.emberhearth.app",
                account: "claude-api-key"
            )
            guard !key.isEmpty else {
                logger.warning("API key found but empty")
                return nil
            }
            return key
        } catch {
            logger.info("No API key in Keychain: \(error.localizedDescription)")
            return nil
        }
    }

    /// Checks if the last shutdown was clean and performs recovery if needed.
    private func checkForCrashRecovery() {
        let lastShutdownClean = UserDefaults.standard.bool(forKey: Self.cleanShutdownKey)

        if !lastShutdownClean {
            logger.warning("Previous shutdown was not clean — running recovery")
            // Future: CrashRecoveryManager.recover()
            // For MVP: just log the event
        }

        // Reset the flag (will be set to true on clean shutdown)
        UserDefaults.standard.set(false, forKey: Self.cleanShutdownKey)
    }

    // MARK: - Error Handling

    /// Handles startup errors by showing appropriate UI to the user.
    private func handleStartupError(_ error: AppStartupError) {
        switch error {
        case .noAPIKey, .invalidAPIKey:
            showOnboardingWindow()

        case .databaseInitializationFailed:
            showErrorAlert(
                title: "Database Error",
                message: "EmberHearth couldn't open its database. Try restarting the app. If the problem persists, you may need to reset the database in Settings.",
                showSettings: true
            )

        case .missingPermission(let permission):
            showErrorAlert(
                title: "Permission Required",
                message: "EmberHearth needs the '\(permission)' permission to work. Please grant it in System Settings > Privacy & Security.",
                showSettings: false
            )

        case .componentInitializationFailed(let component, _):
            showErrorAlert(
                title: "Startup Error",
                message: "EmberHearth couldn't start the \(component) component. Try restarting the app.",
                showSettings: false
            )
        }
    }

    /// Shows an error alert to the user.
    private func showErrorAlert(title: String, message: String, showSettings: Bool) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        if showSettings {
            alert.addButton(withTitle: "Open Settings")
        }

        let response = alert.runModal()
        if showSettings && response == .alertSecondButtonReturn {
            showSettingsWindow()
        }
    }

    // MARK: - Window Management

    /// Shows the onboarding window for first-time setup.
    private func showOnboardingWindow() {
        // Implementation depends on the onboarding UI from task 0600-0699
        logger.info("Showing onboarding window")
        // OnboardingWindowController.shared.showWindow(nil)
    }

    /// Shows the settings window.
    private func showSettingsWindow() {
        logger.info("Showing settings window")
        // SettingsWindowController.shared.showWindow(nil)
    }

    /// Called when the user completes onboarding (including API key setup).
    /// Attempts to start services with the newly-configured API key.
    func onboardingCompleted() {
        logger.info("Onboarding completed, attempting to start services")
        UserDefaults.standard.set(true, forKey: "onboardingComplete")

        guard let apiKey = loadAPIKey() else {
            logger.error("Onboarding completed but no API key found!")
            return
        }

        startServices(apiKey: apiKey)
    }
}
```

### 3. Update src/App/EmberHearthApp.swift (if using SwiftUI lifecycle)

If the project uses SwiftUI App lifecycle instead of AppDelegate, update accordingly:

```swift
// EmberHearthApp.swift
// EmberHearth
//
// SwiftUI app entry point. EmberHearth is a menu bar app — the main window is hidden.

import SwiftUI

@main
struct EmberHearthApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar app — no main window
        Settings {
            SettingsView()
                .frame(width: 500, height: 400)
        }
    }
}
```

NOTE: Only ONE of AppDelegate or EmberHearthApp can have `@main`. Check which one the project currently uses and adapt accordingly. If AppDelegate already has `@main`, do NOT add it to EmberHearthApp (and vice versa).

## Adapting to Actual Component APIs

Before implementing, check each component's actual initializer:
1. `DatabaseManager(path:)` — Does it take a String path?
2. `ClaudeAPIClient(apiKey:)` — Does it take the API key in its initializer?
3. `MessageCoordinator(...)` — What parameters does its init require?
4. `MessageWatcher(...)` — What parameters does its init require?
5. `KeychainManager.retrieve(service:account:)` — What's the actual API?
6. `StatusBarController(appState:)` — Does it take AppState?

Adapt the ServiceContainer.initialize() method to match the actual APIs. The initialization ORDER should remain the same (database first, then security, then memory, then LLM, then iMessage) but the specific parameter names and types may differ.

## Implementation Rules

1. **NEVER use Process() or /bin/bash or any shell execution in source code.**
2. No third-party dependencies. Use only Apple frameworks.
3. All Swift files use PascalCase naming.
4. All public types and methods must have documentation comments (///).
5. Use `os.Logger` for all logging (not print()).
6. Use Keychain for API key storage — retrieve via KeychainManager.
7. Handle initialization failures gracefully — show helpful error messages.
8. Target: App should be ready to respond within 3 seconds of launch.
9. Log the time taken for each initialization step.
10. The database path is ~/Library/Application Support/EmberHearth/ember.db.
11. The ServiceContainer is created ONCE and retained for the app's lifetime.
12. On shutdown: stop watcher, end sessions, flush database WAL.

## Final Checks

Before finishing, verify:
1. All files compile without errors (`swift build`)
2. All tests pass (`swift test`)
3. No calls to Process(), /bin/bash, or shell execution in source
4. ServiceContainer initializes all components in correct dependency order
5. Startup errors show helpful messages to the user
6. Clean shutdown: watcher stops, sessions end, database flushes
7. Onboarding flow: no API key -> show onboarding -> onboarding complete -> start services
8. Menu bar app: window closes don't terminate the app
9. Performance logging shows initialization times
10. Only ONE @main attribute exists in the project
```

---

## Acceptance Criteria

- [ ] `src/App/ServiceContainer.swift` exists with complete dependency container
- [ ] `ServiceContainer.initialize(apiKey:)` creates all components in correct order
- [ ] Components initialized in order: database -> security -> memory -> LLM -> personality -> iMessage -> coordinator -> watcher
- [ ] `ServiceContainer.shutdown()` performs clean teardown in reverse order
- [ ] `AppDelegate.applicationDidFinishLaunching` implements full startup sequence
- [ ] Crash recovery check runs at startup
- [ ] API key loaded from Keychain (not hardcoded)
- [ ] Missing API key redirects to onboarding
- [ ] Startup errors show helpful error messages to the user
- [ ] `applicationWillTerminate` performs clean shutdown
- [ ] App is a menu bar app (doesn't terminate when windows close)
- [ ] Performance logging for each initialization step
- [ ] Startup target: ready in <3 seconds (warning logged if exceeded)
- [ ] `AppStartupError` enum covers: database failure, no API key, invalid key, missing permission
- [ ] Database stored in ~/Library/Application Support/EmberHearth/ember.db
- [ ] No calls to `Process()`, `/bin/bash`, or shell execution
- [ ] `swift build` succeeds
- [ ] `swift test` passes

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new file exists
test -f src/App/ServiceContainer.swift && echo "ServiceContainer.swift exists" || echo "MISSING"

# Verify no shell execution in source
grep -rn "Process()" src/ --include="*.swift" || echo "PASS: No Process() calls"
grep -rn "/bin/bash\|/bin/sh" src/ --include="*.swift" || echo "PASS: No shell references"
grep -rn "NSTask" src/ --include="*.swift" || echo "PASS: No NSTask usage"

# Verify only one @main attribute
grep -rn "@main" src/ --include="*.swift" | wc -l
echo "(Should be exactly 1)"

# Verify Keychain is used for API key (not hardcoded)
grep -rn "KeychainManager" src/App/AppDelegate.swift || grep -rn "Keychain" src/App/AppDelegate.swift
echo "(Should find Keychain references)"

# Verify no hardcoded API keys
grep -rn "sk-ant-\|sk-proj-" src/ --include="*.swift" || echo "PASS: No hardcoded keys"

# Build
swift build 2>&1

# Test
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the app startup sequence and ServiceContainer created in task 0902 for EmberHearth.

@src/App/ServiceContainer.swift
@src/App/AppDelegate.swift
@src/App/EmberHearthApp.swift (if it exists)
@src/App/AppState.swift

Also reference the components being initialized:
@src/Core/MessageCoordinator.swift
@src/Database/DatabaseManager.swift
@src/Security/TronPipeline.swift
@src/LLM/ClaudeAPIClient.swift
@src/iMessage/MessageWatcher.swift

1. **DEPENDENCY ORDER (Critical):**
   - Is the initialization order correct? Specifically:
     * Database MUST be initialized before FactStore, SessionManager
     * TronPipeline MUST be initialized before MessageCoordinator
     * FactStore MUST be initialized before FactRetriever, FactExtractor
     * All dependencies of MessageCoordinator MUST be initialized before it
     * All dependencies of MessageWatcher MUST be initialized before it
   - Are there any circular dependencies?
   - Would any component try to use another component that hasn't been initialized yet?

2. **API MATCHING (Critical):**
   - Does `ServiceContainer.initialize()` call each component's constructor with the correct parameters?
   - Do the parameter types match what each component's init actually expects?
   - Are there any missing parameters or extra parameters?

3. **ERROR HANDLING (Important):**
   - Does the startup sequence handle database initialization failure?
   - Does it handle missing API key?
   - Does it handle invalid API key?
   - Does it handle missing permissions?
   - Are error messages user-friendly (no technical jargon, no stack traces)?
   - Is the user given a clear action to resolve each error?

4. **SHUTDOWN (Important):**
   - Does shutdown stop the message watcher?
   - Does it end active sessions?
   - Does it flush the database WAL?
   - Is the shutdown order correct (reverse of initialization)?
   - Is the clean shutdown flag set correctly?

5. **SECURITY (Critical):**
   - Is the API key loaded from Keychain only (never hardcoded)?
   - Is there any sensitive data in log output?
   - Are error messages safe to show to users (no internal paths, keys, etc.)?
   - No Process(), /bin/bash, or shell execution?

6. **PERFORMANCE:**
   - Is each initialization step timed?
   - Is a warning logged if startup exceeds 3 seconds?
   - Are there any blocking operations that could slow startup?

7. **APP LIFECYCLE:**
   - Is applicationShouldTerminateAfterLastWindowClosed returning false (menu bar app)?
   - Is only ONE @main attribute present in the project?
   - Does the onboarding flow correctly transition to normal operation?

Report any issues with severity: CRITICAL (must fix), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat: wire complete app startup sequence with dependency injection
```

---

## Notes for Next Task

- The ServiceContainer is the single point of truth for component initialization. If new components are added later, they should be added here.
- The startup sequence logs timing for each step. If startup is slow, check these logs to identify the bottleneck.
- The `onboardingCompleted()` method on AppDelegate is the callback for when onboarding finishes. The onboarding UI (task 0600-0699) should call this.
- The clean shutdown flag (`lastShutdownClean`) is stored in UserDefaults. If the flag is false at startup, the last shutdown was not clean (crash or force quit).
- The database path is ~/Library/Application Support/EmberHearth/ember.db. The directory is created automatically if it doesn't exist.
- Only ONE `@main` attribute should exist. If both AppDelegate and EmberHearthApp have it, remove one.
