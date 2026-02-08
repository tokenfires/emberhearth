# Task 0702: Enhanced Menu Bar Status

**Milestone:** M8 - Polish & Release
**Unit:** 8.2 - Status Indicators (Enhanced Menu Bar)
**Phase:** 3
**Depends On:** 0701, 0504 (MessageCoordinator)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `docs/specs/autonomous-operation.md` — Read Section 1.2 "Health State Machine" (lines 42-60) for the four health states (HEALTHY, DEGRADED, HEALING, IMPAIRED) and their transitions. This maps to AppState.AppStatus.
2. `docs/specs/error-handling.md` — Read "Health Monitoring > Startup Health Check" (lines 389-430) for the startup check structure. Read "Runtime Health Dashboard" (lines 432-453) for the status display format.
3. `docs/releases/feature-matrix.md` — Read "Mac Application > System" rows (lines 89-94) to confirm MVP includes: menu bar, launch at login, status indicator.
4. `docs/architecture/decisions/0004-no-shell-execution.md` — Read in full. No Process(), no /bin/bash, no NSTask.
5. `CLAUDE.md` — Project conventions.
6. `src/Core/Errors/AppError.swift` — Reference the error types from task 0700 that AppState will track.

> **Context Budget Note:** `autonomous-operation.md` is long (~600 lines). Only read Part 1, lines 32-60 (health state machine). Skip everything else. `error-handling.md` focus on lines 389-453 only.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the enhanced menu bar status system for EmberHearth, a native macOS personal AI assistant. The menu bar icon is the primary visible indicator that EmberHearth is running. It needs to communicate the app's state at a glance through icon changes and provide detailed status in its dropdown menu.

## Important Rules (from CLAUDE.md)

- Swift files use PascalCase (e.g., AppState.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask, no osascript via Process)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- Use `os.Logger` for logging (subsystem: "com.emberhearth.app")
- All public types and methods must have documentation comments (///)
- Menu items must have VoiceOver accessibility labels

## What You Are Building

Two components:
1. **AppState** — A central `@Observable` (or `ObservableObject`) state object that tracks the app's health, message counts, errors, and onboarding status. This is the single source of truth for the app's current condition.
2. **Enhanced StatusBarController** — Updates to the existing menu bar controller to use AppState for dynamic icon changes and richer menu content.

## Existing Components

These components exist from prior tasks:
- `StatusBarController` (from task 0003) — The basic menu bar controller with NSStatusItem. You will UPDATE this file.
- `AppError` (from task 0700) — Error types for tracking.
- `MessageCoordinator` (from task 0504) — The message processing pipeline. AppState will be updated by the coordinator.

If StatusBarController doesn't exist yet, create it fresh. If it exists, modify it.

## Files to Create / Update

### 1. `src/App/AppState.swift`

```swift
// AppState.swift
// EmberHearth
//
// Central observable state for the entire application.

import Foundation
import SwiftUI
import os

/// The central observable state object for EmberHearth.
///
/// AppState is the single source of truth for the application's current
/// health, activity, and statistics. It is observed by the menu bar,
/// settings views, and error displays to present consistent status information.
///
/// ## Thread Safety
/// All published properties must be updated on the main actor since
/// they drive UI updates.
///
/// ## Usage
/// ```swift
/// @StateObject private var appState = AppState()
/// // or inject via environment
/// .environmentObject(appState)
/// ```
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// The current operational status of the application.
    @Published var status: AppStatus = .starting

    /// The timestamp of the last message received from the user.
    @Published var lastMessageTime: Date?

    /// Total messages processed in the current session.
    @Published var messageCount: Int = 0

    /// Total facts stored in the memory database.
    @Published var factCount: Int = 0

    /// Whether the onboarding flow has been completed.
    @Published var isOnboardingComplete: Bool

    /// Current active errors (may have multiple simultaneous issues).
    @Published var errors: [AppError] = []

    /// Whether Ember is paused (user manually paused responses).
    @Published var isPaused: Bool = false

    // MARK: - Private Properties

    /// Logger for state transitions.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "AppState")

    // MARK: - Initialization

    /// Creates a new AppState, checking onboarding completion from UserDefaults.
    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
        logger.info("AppState initialized. Onboarding complete: \(self.isOnboardingComplete)")
    }

    // MARK: - Status Transitions

    /// Transitions the app to a new status, logging the change.
    ///
    /// - Parameter newStatus: The new status to transition to.
    func transition(to newStatus: AppStatus) {
        let oldStatus = status
        status = newStatus
        logger.info("Status transition: \(oldStatus.logDescription) -> \(newStatus.logDescription)")
    }

    /// Records a processed message, updating counts and timestamp.
    func recordMessage() {
        messageCount += 1
        lastMessageTime = Date()
        logger.debug("Message recorded. Count: \(self.messageCount)")
    }

    /// Adds an error to the active errors list.
    ///
    /// If an error with the same ID already exists, it is replaced.
    ///
    /// - Parameter error: The error to add.
    func addError(_ error: AppError) {
        errors.removeAll { $0.id == error.id }
        errors.append(error)
        logger.info("Error added: \(error.id). Active errors: \(self.errors.count)")

        // If we have critical errors, transition to error state
        if !error.isTransient {
            transition(to: .error(error.title))
        } else {
            transition(to: .degraded(error.title))
        }
    }

    /// Removes an error from the active errors list.
    ///
    /// If no errors remain, transitions back to .ready.
    ///
    /// - Parameter errorId: The ID of the error to remove.
    func removeError(withId errorId: String) {
        errors.removeAll { $0.id == errorId }
        logger.info("Error removed: \(errorId). Active errors: \(self.errors.count)")

        if errors.isEmpty {
            transition(to: .ready)
        }
    }

    /// Clears all errors and transitions to .ready.
    func clearErrors() {
        errors.removeAll()
        transition(to: .ready)
        logger.info("All errors cleared")
    }

    /// Updates the fact count from the memory system.
    ///
    /// - Parameter count: The current number of stored facts.
    func updateFactCount(_ count: Int) {
        factCount = count
    }

    /// Toggles the paused state.
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            logger.info("Ember paused by user")
        } else {
            logger.info("Ember resumed by user")
        }
    }

    /// A human-readable string describing the time since the last message.
    var lastMessageDescription: String {
        guard let lastTime = lastMessageTime else {
            return "No messages yet"
        }

        let interval = Date().timeIntervalSince(lastTime)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - AppStatus Enum

/// The operational status of the EmberHearth application.
///
/// Maps to the health state machine from the autonomous operation spec:
/// - .starting → Initial boot
/// - .ready → HEALTHY (connected, waiting for messages)
/// - .processing → HEALTHY (actively handling a message)
/// - .degraded → DEGRADED (working with issues)
/// - .error → IMPAIRED (not working)
/// - .offline → Special case of DEGRADED (no internet)
enum AppStatus: Equatable {
    /// App is starting up, running health checks.
    case starting
    /// Fully operational, waiting for messages.
    case ready
    /// Currently processing a message.
    case processing
    /// Working but with non-critical issues.
    case degraded(String)
    /// Not working due to a critical error.
    case error(String)
    /// No internet connection.
    case offline

    /// A short human-readable description for logging.
    var logDescription: String {
        switch self {
        case .starting: return "starting"
        case .ready: return "ready"
        case .processing: return "processing"
        case .degraded(let reason): return "degraded(\(reason))"
        case .error(let reason): return "error(\(reason))"
        case .offline: return "offline"
        }
    }

    /// The SF Symbol name for the menu bar icon.
    var menuBarIcon: String {
        switch self {
        case .starting: return "flame.fill"
        case .ready: return "flame.fill"
        case .processing: return "flame.fill"
        case .degraded: return "flame.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .offline: return "flame.fill"
        }
    }

    /// A short status line for the menu bar dropdown.
    var statusLine: String {
        switch self {
        case .starting: return "Starting up..."
        case .ready: return "Ready"
        case .processing: return "Thinking..."
        case .degraded(let reason): return "Limited: \(reason)"
        case .error(let reason): return "Issue: \(reason)"
        case .offline: return "Offline"
        }
    }

    /// Equatable conformance.
    static func == (lhs: AppStatus, rhs: AppStatus) -> Bool {
        switch (lhs, rhs) {
        case (.starting, .starting), (.ready, .ready),
             (.processing, .processing), (.offline, .offline):
            return true
        case (.degraded(let a), .degraded(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
```

### 2. `src/App/StatusBarController.swift`

Create (or replace) the menu bar controller that uses AppState:

```swift
// StatusBarController.swift
// EmberHearth
//
// Menu bar status item with dynamic status indicators.

import AppKit
import SwiftUI
import Combine
import os

/// Manages the NSStatusItem in the macOS menu bar.
///
/// The menu bar icon is the primary visible indicator that EmberHearth
/// is running. It changes appearance based on AppState to communicate
/// status at a glance:
///
/// - **Ready:** Flame icon (default color)
/// - **Processing:** Flame icon with subtle pulse
/// - **Degraded:** Flame icon (yellow tint)
/// - **Error:** Exclamation triangle (red)
/// - **Offline:** Flame icon with slash
/// - **Paused:** Flame icon (dimmed)
///
/// The dropdown menu shows detailed status information and controls.
///
/// ## Accessibility
/// - Menu items have VoiceOver-friendly titles
/// - Status information is conveyed in text, not just color
final class StatusBarController {

    // MARK: - Properties

    /// The status bar item in the macOS menu bar.
    private var statusItem: NSStatusItem

    /// Reference to the app state for status updates.
    private let appState: AppState

    /// Logger for menu bar operations.
    private let logger = Logger(subsystem: "com.emberhearth.app", category: "StatusBar")

    /// Combine subscriptions for observing state changes.
    private var cancellables = Set<AnyCancellable>()

    /// Timer for animating the processing state.
    private var pulseTimer: Timer?

    /// Whether the icon is in the "bright" phase of the pulse animation.
    private var isPulseBright: Bool = false

    // MARK: - Initialization

    /// Creates a new StatusBarController with the given app state.
    ///
    /// - Parameter appState: The shared app state to observe for status changes.
    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusItem()
        observeStateChanges()

        logger.info("StatusBarController initialized")
    }

    // MARK: - Setup

    /// Configures the initial status bar item appearance.
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth")
            button.image?.isTemplate = true
        }

        rebuildMenu()
    }

    /// Observes AppState changes and updates the menu bar accordingly.
    private func observeStateChanges() {
        // Observe status changes
        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                self?.updateIcon(for: newStatus)
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        // Observe message count changes
        appState.$messageCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        // Observe pause state changes
        appState.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        // Observe error changes
        appState.$errors
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    // MARK: - Icon Updates

    /// Updates the menu bar icon based on the current app status.
    ///
    /// - Parameter status: The new app status.
    private func updateIcon(for status: AppStatus) {
        stopPulseAnimation()

        guard let button = statusItem.button else { return }

        switch status {
        case .starting:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth starting")
            button.image?.isTemplate = true
            button.appearsDisabled = true

        case .ready:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth ready")
            button.image?.isTemplate = true
            button.appearsDisabled = false

        case .processing:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth thinking")
            button.image?.isTemplate = true
            button.appearsDisabled = false
            startPulseAnimation()

        case .degraded:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth limited")
            button.image?.isTemplate = false // Allows tinting
            button.contentTintColor = .systemYellow

        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "EmberHearth error")
            button.image?.isTemplate = false
            button.contentTintColor = .systemRed

        case .offline:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth offline")
            button.image?.isTemplate = true
            button.appearsDisabled = true
        }

        // Paused state overlay
        if appState.isPaused {
            button.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "EmberHearth paused")
            button.image?.isTemplate = true
            button.appearsDisabled = false
        }
    }

    // MARK: - Pulse Animation

    /// Starts a subtle pulse animation for the processing state.
    private func startPulseAnimation() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.isPulseBright.toggle()
            if let button = self.statusItem.button {
                button.appearsDisabled = !self.isPulseBright
            }
        }
    }

    /// Stops the pulse animation.
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        isPulseBright = false
        statusItem.button?.appearsDisabled = false
    }

    // MARK: - Menu Construction

    /// Rebuilds the dropdown menu with current state information.
    private func rebuildMenu() {
        let menu = NSMenu()

        // Status line
        let statusItem = NSMenuItem(title: "Ember: \(appState.status.statusLine)", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Onboarding check
        if !appState.isOnboardingComplete {
            let setupItem = NSMenuItem(title: "Setup Required...", action: #selector(openOnboarding), keyEquivalent: "")
            setupItem.target = self
            menu.addItem(setupItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Message stats
        let messageItem = NSMenuItem(title: "Messages today: \(appState.messageCount)", action: nil, keyEquivalent: "")
        messageItem.isEnabled = false
        menu.addItem(messageItem)

        let lastMessageItem = NSMenuItem(title: "Last message: \(appState.lastMessageDescription)", action: nil, keyEquivalent: "")
        lastMessageItem.isEnabled = false
        menu.addItem(lastMessageItem)

        if appState.factCount > 0 {
            let factItem = NSMenuItem(title: "Memory: \(appState.factCount) fact\(appState.factCount == 1 ? "" : "s") stored", action: nil, keyEquivalent: "")
            factItem.isEnabled = false
            menu.addItem(factItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Pause / Resume toggle
        let pauseTitle = appState.isPaused ? "Resume Ember" : "Pause Ember"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit EmberHearth", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    // MARK: - Menu Actions

    /// Opens the onboarding flow.
    @objc private func openOnboarding() {
        logger.info("Opening onboarding from menu bar")
        // TODO: Wire to onboarding window during integration
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the Settings window.
    @objc private func openSettings() {
        logger.info("Opening settings from menu bar")
        // Open SwiftUI Settings window
        NSApp.activate(ignoringOtherApps: true)
        // On macOS 14+, use NSApp.sendAction for Settings
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    /// Toggles the pause state.
    @objc private func togglePause() {
        Task { @MainActor in
            appState.togglePause()
        }
    }

    /// Quits the application.
    @objc private func quitApp() {
        logger.info("Quit requested from menu bar")
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Cleanup

    /// Removes the status item from the menu bar.
    func removeFromMenuBar() {
        stopPulseAnimation()
        NSStatusBar.system.removeStatusItem(statusItem)
        logger.info("StatusBarController removed from menu bar")
    }
}
```

### 3. `tests/App/AppStateTests.swift`

```swift
// AppStateTests.swift
// EmberHearth
//
// Unit tests for AppState and AppStatus.

import XCTest
@testable import EmberHearth

@MainActor
final class AppStateTests: XCTestCase {

    private var appState: AppState!

    override func setUp() {
        super.setUp()
        appState = AppState()
    }

    override func tearDown() {
        appState = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStatusIsStarting() {
        XCTAssertEqual(appState.status, .starting)
    }

    func testInitialMessageCountIsZero() {
        XCTAssertEqual(appState.messageCount, 0)
    }

    func testInitialLastMessageTimeIsNil() {
        XCTAssertNil(appState.lastMessageTime)
    }

    func testInitialErrorsIsEmpty() {
        XCTAssertTrue(appState.errors.isEmpty)
    }

    func testInitialIsPausedIsFalse() {
        XCTAssertFalse(appState.isPaused)
    }

    // MARK: - Status Transition Tests

    func testTransitionToReady() {
        appState.transition(to: .ready)
        XCTAssertEqual(appState.status, .ready)
    }

    func testTransitionToProcessing() {
        appState.transition(to: .processing)
        XCTAssertEqual(appState.status, .processing)
    }

    func testTransitionToDegraded() {
        appState.transition(to: .degraded("Network slow"))
        XCTAssertEqual(appState.status, .degraded("Network slow"))
    }

    func testTransitionToError() {
        appState.transition(to: .error("API key invalid"))
        XCTAssertEqual(appState.status, .error("API key invalid"))
    }

    func testTransitionToOffline() {
        appState.transition(to: .offline)
        XCTAssertEqual(appState.status, .offline)
    }

    // MARK: - Message Recording Tests

    func testRecordMessageIncrementsCount() {
        appState.recordMessage()
        XCTAssertEqual(appState.messageCount, 1)

        appState.recordMessage()
        XCTAssertEqual(appState.messageCount, 2)
    }

    func testRecordMessageUpdatesTimestamp() {
        XCTAssertNil(appState.lastMessageTime)
        appState.recordMessage()
        XCTAssertNotNil(appState.lastMessageTime)
    }

    // MARK: - Error Management Tests

    func testAddError() {
        appState.addError(.noInternet)
        XCTAssertEqual(appState.errors.count, 1)
        XCTAssertEqual(appState.errors.first?.id, "noInternet")
    }

    func testAddDuplicateErrorReplacesExisting() {
        appState.addError(.noInternet)
        appState.addError(.noInternet)
        XCTAssertEqual(appState.errors.count, 1, "Duplicate errors should replace, not accumulate")
    }

    func testAddMultipleDifferentErrors() {
        appState.addError(.noInternet)
        appState.addError(.llmOverloaded)
        XCTAssertEqual(appState.errors.count, 2)
    }

    func testRemoveError() {
        appState.addError(.noInternet)
        appState.addError(.llmOverloaded)
        appState.removeError(withId: "noInternet")
        XCTAssertEqual(appState.errors.count, 1)
        XCTAssertEqual(appState.errors.first?.id, "llmOverloaded")
    }

    func testRemoveLastErrorTransitionsToReady() {
        appState.addError(.noInternet)
        appState.removeError(withId: "noInternet")
        XCTAssertTrue(appState.errors.isEmpty)
        XCTAssertEqual(appState.status, .ready)
    }

    func testClearErrors() {
        appState.addError(.noInternet)
        appState.addError(.llmOverloaded)
        appState.clearErrors()
        XCTAssertTrue(appState.errors.isEmpty)
        XCTAssertEqual(appState.status, .ready)
    }

    func testTransientErrorSetsDegradedStatus() {
        appState.addError(.noInternet) // isTransient = true
        XCTAssertEqual(appState.status, .degraded("No Internet Connection"))
    }

    func testPersistentErrorSetsErrorStatus() {
        appState.addError(.noAPIKey) // isTransient = false
        XCTAssertEqual(appState.status, .error("API Key Needed"))
    }

    // MARK: - Pause Tests

    func testTogglePause() {
        XCTAssertFalse(appState.isPaused)
        appState.togglePause()
        XCTAssertTrue(appState.isPaused)
        appState.togglePause()
        XCTAssertFalse(appState.isPaused)
    }

    // MARK: - Fact Count Tests

    func testUpdateFactCount() {
        appState.updateFactCount(42)
        XCTAssertEqual(appState.factCount, 42)
    }

    // MARK: - Last Message Description Tests

    func testLastMessageDescriptionNoMessages() {
        XCTAssertEqual(appState.lastMessageDescription, "No messages yet")
    }

    func testLastMessageDescriptionJustNow() {
        appState.recordMessage()
        XCTAssertEqual(appState.lastMessageDescription, "Just now")
    }

    // MARK: - AppStatus Tests

    func testAppStatusEquatable() {
        XCTAssertEqual(AppStatus.ready, AppStatus.ready)
        XCTAssertEqual(AppStatus.degraded("test"), AppStatus.degraded("test"))
        XCTAssertNotEqual(AppStatus.ready, AppStatus.processing)
        XCTAssertNotEqual(AppStatus.degraded("a"), AppStatus.degraded("b"))
    }

    func testAppStatusMenuBarIcons() {
        XCTAssertEqual(AppStatus.ready.menuBarIcon, "flame.fill")
        XCTAssertEqual(AppStatus.processing.menuBarIcon, "flame.fill")
        XCTAssertEqual(AppStatus.error("test").menuBarIcon, "exclamationmark.triangle.fill")
    }

    func testAppStatusStatusLines() {
        XCTAssertEqual(AppStatus.ready.statusLine, "Ready")
        XCTAssertEqual(AppStatus.processing.statusLine, "Thinking...")
        XCTAssertEqual(AppStatus.offline.statusLine, "Offline")
        XCTAssertTrue(AppStatus.degraded("Network").statusLine.contains("Network"))
    }

    // MARK: - Security Tests

    func testNoShellExecution() {
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh"]
        for pattern in forbiddenPatterns {
            XCTAssertFalse(pattern.isEmpty, "AppState must not contain \(pattern)")
        }
    }
}
```

## Implementation Rules

1. **NEVER use Process(), /bin/bash, /bin/sh, NSTask, or osascript.** Hard security rule per ADR-0004.
2. No third-party dependencies. Use only Apple frameworks (Foundation, SwiftUI, AppKit, Combine, os).
3. All Swift files use PascalCase naming.
4. All public types and methods must have documentation comments (///).
5. Use `os.Logger` for logging (subsystem: "com.emberhearth.app", category: class name).
6. AppState must be `@MainActor` since all its published properties drive UI.
7. StatusBarController uses Combine to observe AppState changes.
8. Menu bar icon changes must not be jarring — use template images where possible for system theme integration.
9. The pulse animation for .processing state should be subtle (toggle `appearsDisabled`), not distracting.
10. Menu items that are informational (not actionable) should have `isEnabled = false`.
11. The "Pause Ember" toggle is a convenience feature — it sets a flag that the MessageCoordinator checks before processing.
12. Test file path: Match existing test directory structure.

## Directory Structure

Create/update these files:
- `src/App/AppState.swift` (NEW)
- `src/App/StatusBarController.swift` (NEW or UPDATE)
- `tests/App/AppStateTests.swift` (NEW)

## Final Checks

Before finishing, verify:
1. All files compile without errors
2. All tests pass
3. No Process(), /bin/bash, NSTask, or osascript calls exist
4. AppState is @MainActor
5. StatusBarController observes AppState via Combine
6. Menu bar icon changes based on status
7. Menu includes: status line, message count, last message time, fact count, pause/resume, settings, quit
8. Onboarding check shows "Setup Required..." when not complete
9. Settings opens via standard Cmd+, mechanism
10. All public methods have documentation comments
11. os.Logger is used (not print())
```

---

## Acceptance Criteria

- [ ] `src/App/AppState.swift` exists with AppStatus enum and all published properties
- [ ] `src/App/StatusBarController.swift` exists (or is updated) with dynamic menu and icon
- [ ] AppState tracks: status, lastMessageTime, messageCount, factCount, isOnboardingComplete, errors, isPaused
- [ ] AppStatus has cases: starting, ready, processing, degraded, error, offline
- [ ] Status transitions are logged via os.Logger
- [ ] Error management: addError, removeError, clearErrors work correctly
- [ ] Duplicate errors replace rather than accumulate
- [ ] Removing last error transitions to .ready
- [ ] Transient errors set .degraded status; persistent errors set .error status
- [ ] Menu bar icon changes for each status state
- [ ] Processing state has subtle pulse animation
- [ ] Error state shows exclamation triangle in red
- [ ] Menu dropdown shows: status line, message count, last message time, fact count
- [ ] "Pause Ember" / "Resume Ember" toggle works
- [ ] "Settings..." menu item opens Settings window (Cmd+,)
- [ ] "Setup Required..." shows when onboarding is incomplete
- [ ] "Quit EmberHearth" menu item terminates the app
- [ ] lastMessageDescription returns human-readable time ("Just now", "5 minutes ago", etc.)
- [ ] Menu items have VoiceOver-appropriate titles
- [ ] **CRITICAL:** No calls to `Process()`, `/bin/bash`, `/bin/sh`, `NSTask`, or `osascript`
- [ ] All unit tests pass
- [ ] `os.Logger` used for logging (no `print()` statements)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/App/AppState.swift && echo "PASS: AppState.swift exists" || echo "MISSING: AppState.swift"
test -f src/App/StatusBarController.swift && echo "PASS: StatusBarController.swift exists" || echo "MISSING: StatusBarController.swift"

# Verify no shell execution
grep -rn "Process()" src/App/ || echo "PASS: No Process() calls found"
grep -rn "NSTask" src/App/ || echo "PASS: No NSTask calls found"
grep -rn "/bin/bash" src/App/ || echo "PASS: No /bin/bash references found"
grep -rn "/bin/sh" src/App/ || echo "PASS: No /bin/sh references found"

# Verify @MainActor on AppState
grep -n "@MainActor" src/App/AppState.swift && echo "PASS: @MainActor found" || echo "FAIL: @MainActor missing"

# Verify AppStatus cases exist
grep -c "case " src/App/AppState.swift | xargs -I {} echo "AppStatus has {} cases"

# Build the project
xcodebuild build -scheme EmberHearth -destination 'platform=macOS' 2>&1 | tail -20

# Run the AppState tests
xcodebuild test -scheme EmberHearth -destination 'platform=macOS' -only-testing:EmberHearthTests/AppStateTests 2>&1 | tail -30
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the EmberHearth AppState and StatusBarController implementation for correctness, thread safety, and macOS best practices. Open these files:

@src/App/AppState.swift
@src/App/StatusBarController.swift
@tests/App/AppStateTests.swift

Also reference:
@src/Core/Errors/AppError.swift
@docs/specs/autonomous-operation.md (Section 1.2 only)
@docs/specs/error-handling.md (lines 389-453 only)

## THREAD SAFETY (Top Priority)

1. **@MainActor Enforcement (CRITICAL):**
   - Is AppState correctly marked @MainActor?
   - Are all published property mutations on the main actor?
   - Is there any risk of data races on messageCount, errors, or status?
   - Does StatusBarController access AppState properties safely (dispatch to main)?

2. **Combine Subscriptions:**
   - Do all `.sink` subscriptions use `.receive(on: DispatchQueue.main)`?
   - Are subscriptions properly stored in cancellables?
   - Is there a retain cycle between StatusBarController and AppState?

## CORRECTNESS

3. **State Machine:**
   - Does the status transition logic match the health state machine from autonomous-operation.md?
   - Is it correct that addError() always transitions to .degraded or .error? Could this override a more specific status?
   - When removeError is called and errors remain, does the status correctly reflect the remaining errors?

4. **Error Management:**
   - Is duplicate error replacement correct (remove by ID, then append)?
   - When multiple errors exist and one is removed, does the status correctly reflect the remaining errors?
   - Should clearErrors always transition to .ready, or should it check for other conditions?

5. **Menu Bar Icon:**
   - Is the icon correctly different for each status?
   - Does the pulse animation for .processing work correctly? Is Timer.scheduledTimer correct in this context?
   - Is the paused state icon override correct (should it override error states too)?
   - Are template images used correctly (isTemplate = true for system-themed, false for tinted)?

6. **Menu Construction:**
   - Is the menu rebuilt on every state change? Is this efficient enough?
   - Are menu keyboard shortcuts correct (Cmd+, for Settings, Cmd+Q for Quit)?
   - Does the Settings selector work on both macOS 14+ and earlier?

7. **Last Message Description:**
   - Are the time intervals correct (60 seconds = 1 minute, 3600 = 1 hour, 86400 = 1 day)?
   - Is singular/plural correct ("1 minute" vs "2 minutes")?
   - Does "Just now" work for the boundary case (exactly 60 seconds)?

## CODE QUALITY

8. **Logging:**
   - Is os.Logger used consistently?
   - Are log levels appropriate (info for transitions, debug for stats)?
   - Is anything sensitive logged (phone numbers, API keys)? It should not be.

9. **Memory Management:**
   - Are [weak self] references used in closures?
   - Is the pulse timer properly invalidated on cleanup?
   - Is removeFromMenuBar properly cleaning up resources?

10. **Test Quality:**
    - Do tests cover all status transitions?
    - Do tests cover error management (add, duplicate, remove, clear)?
    - Do tests cover the transient vs persistent error behavior?
    - Are tests @MainActor annotated correctly?

Report any issues with specific file paths and line numbers. Severity: CRITICAL (must fix before merge), IMPORTANT (should fix), MINOR (nice to have).
```

---

## Commit Message

```
feat(m8): enhance menu bar with dynamic status indicators
```

---

## Notes for Next Task

- `AppState` is the single source of truth for the application. The `MessageCoordinator` (from task 0504) should update AppState as it processes messages: `.processing` when handling, `.ready` when done, `.degraded`/`.error` on failures.
- `StatusBarController` needs to be initialized in the AppDelegate (or @main App struct) with a shared `AppState` instance. Wire this during integration.
- The `isPaused` flag needs to be checked by the `MessageCoordinator` before processing incoming messages. When paused, messages should be queued but not processed.
- The pulse animation uses `Timer` which runs on the main run loop. This is intentional since the animation is purely visual. If performance is a concern, it can be replaced with a CADisplayLink.
- The "Setup Required..." menu item currently just activates the app. Wire it to the onboarding window during integration.
- `factCount` needs to be updated by the `DatabaseManager` whenever facts are added or removed. Wire this during integration.
- The Settings window is opened via `NSApp.sendAction(Selector(("showSettingsWindow:")))` on macOS 14+ or `showPreferencesWindow:` on earlier versions. This works automatically when using SwiftUI's Settings scene.
