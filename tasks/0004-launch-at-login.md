# Task 0004: Launch at Login via SMAppService

**Milestone:** M1 - Foundation
**Unit:** 1.4 - Launch at Login
**Phase:** 1
**Depends On:** Task 0003 (Menu Bar Integration)
**Estimated Effort:** 1-2 hours
**Complexity:** Small

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; focus on security boundaries (use Keychain for secrets, validate inputs), naming conventions, core principles
2. `docs/specs/autonomous-operation.md` — Focus on lines 1-30 only: the philosophy section ("The Grandmother Test") and design principles (detect silently, heal automatically, degrade gracefully)
3. `docs/releases/mvp-scope.md` — Focus on lines 78-80: "Launch at login" is listed as an MVP feature under "Mac App > System"

> **Context Budget Note:** autonomous-operation.md is 895 lines. Read ONLY lines 1-41 (philosophy and design principles). Everything else is about health monitoring and upgrades which are not relevant here. For mvp-scope.md, only confirm that "Launch at login" appears in the MVP column.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing Launch at Login functionality for EmberHearth, a native macOS personal AI assistant that runs as a menu bar app. Tasks 0001-0003 have set up the project structure, SwiftUI app shell, and menu bar integration.

Your job is to create a LaunchAtLoginManager that uses Apple's SMAppService API (macOS 13+) and integrate a toggle into the menu bar dropdown.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase
- All UI must support VoiceOver accessibility
- Handle errors gracefully — log them, never crash
- Security first: use structured operations only

WHAT EXISTS (from Tasks 0001-0003):
- Package.swift at project root
- src/App/EmberHearthApp.swift — @main entry point
- src/App/AppDelegate.swift — Creates and retains StatusBarController
- src/App/StatusBarController.swift — NSStatusItem with dropdown menu, AppHealthState enum
- src/Views/ContentView.swift — Basic welcome view
- Module placeholder files in all directories
- tests/EmberHearthTests.swift — Basic module existence tests

KEY DETAILS ABOUT StatusBarController (from Task 0003):
- StatusBarController is `final class StatusBarController: NSObject`
- It has a `buildMenu()` method that constructs the dropdown menu
- The menu structure is: Title > Separator > Status > Separator > Settings/About > Separator > Quit
- Menu items use target-action pattern with @objc selectors

STEP 1: Create src/App/LaunchAtLoginManager.swift

This class wraps SMAppService for launch-at-login functionality. It uses a singleton pattern for easy access from both the menu and future settings UI.

File: src/App/LaunchAtLoginManager.swift
```swift
// LaunchAtLoginManager.swift
// EmberHearth
//
// Manages Launch at Login registration using SMAppService (macOS 13+).
// Provides a simple API for toggling and querying the launch-at-login state.

import Foundation
import OSLog
import ServiceManagement

/// Manages whether EmberHearth launches automatically when the user logs in.
///
/// Uses Apple's SMAppService API (available macOS 13.0+) for proper
/// system integration. Falls back gracefully if registration fails.
///
/// Usage:
/// ```swift
/// // Check current state
/// let isEnabled = LaunchAtLoginManager.shared.isEnabled
///
/// // Toggle
/// LaunchAtLoginManager.shared.setEnabled(true)
/// ```
final class LaunchAtLoginManager {

    // MARK: - Singleton

    /// Shared instance for app-wide access.
    static let shared = LaunchAtLoginManager()

    // MARK: - Properties

    /// Logger for launch-at-login events.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "LaunchAtLogin"
    )

    /// UserDefaults key for storing the user's launch-at-login preference.
    /// This tracks what the user WANTS, which may differ from actual system state
    /// (e.g., if the user revoked permission in System Settings).
    private let preferenceKey = "launchAtLoginEnabled"

    /// The SMAppService instance for this app's login item.
    private let service = SMAppService.mainApp

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Whether launch-at-login is currently enabled at the system level.
    ///
    /// This checks the actual SMAppService status, not just the stored preference.
    /// The two can diverge if the user changes settings in System Settings > General > Login Items.
    var isEnabled: Bool {
        return service.status == .enabled
    }

    /// Whether the user has expressed a preference for launch-at-login.
    /// Returns `nil` if the user has never been asked (first launch).
    var userPreference: Bool? {
        guard UserDefaults.standard.object(forKey: preferenceKey) != nil else {
            return nil
        }
        return UserDefaults.standard.bool(forKey: preferenceKey)
    }

    /// Enables or disables launch at login.
    ///
    /// - Parameter enabled: Whether the app should launch at login.
    /// - Returns: `true` if the operation succeeded, `false` if it failed.
    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        // Store the user's preference regardless of whether the system call succeeds.
        // This lets us retry on next launch if the system call failed.
        UserDefaults.standard.set(enabled, forKey: preferenceKey)

        do {
            if enabled {
                try service.register()
                logger.info("Launch at login enabled successfully")
            } else {
                try service.unregister()
                logger.info("Launch at login disabled successfully")
            }
            return true
        } catch {
            logger.error("Failed to \(enabled ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            return false
        }
    }

    /// Toggles the current launch-at-login state.
    ///
    /// - Returns: `true` if the operation succeeded, `false` if it failed.
    @discardableResult
    func toggle() -> Bool {
        return setEnabled(!isEnabled)
    }

    /// Ensures launch-at-login state matches the user's preference.
    ///
    /// Call this on app launch to handle cases where:
    /// - First launch: enables by default
    /// - System state diverged from preference (user changed in System Settings)
    /// - Previous registration attempt failed
    func synchronize() {
        let currentStatus = service.status

        // First launch: default to enabled
        if userPreference == nil {
            logger.info("First launch — enabling launch at login by default")
            setEnabled(true)
            return
        }

        // Check if system state matches user preference
        guard let preference = userPreference else { return }
        let systemEnabled = currentStatus == .enabled

        if preference != systemEnabled {
            logger.info("Launch at login state mismatch — preference: \(preference), system: \(systemEnabled). Attempting to sync.")

            // Only try to re-register if the user wants it enabled.
            // If they disabled it but system shows enabled, that's unusual
            // and likely means they re-enabled in System Settings, which is fine.
            if preference && !systemEnabled {
                setEnabled(true)
            }
        }

        // Log current state for debugging
        logger.debug("Launch at login status: \(currentStatus.rawValue) (preference: \(preference))")
    }

    /// Returns a human-readable description of the current status.
    /// Useful for logging and debugging.
    var statusDescription: String {
        switch service.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Not registered"
        case .notFound:
            return "Not found (app may have moved)"
        case .requiresApproval:
            return "Requires user approval in System Settings"
        @unknown default:
            return "Unknown status"
        }
    }
}
```

STEP 2: Update src/App/StatusBarController.swift — Add Launch at Login toggle to menu

Modify the existing StatusBarController to add a "Launch at Login" checkbox menu item. You need to:

1. Add a new stored property for the launch-at-login menu item
2. Add the menu item in `buildMenu()` between "About EmberHearth" and the final separator
3. Add an @objc action method for the toggle
4. Add a method to refresh the checkbox state

Add this stored property alongside the existing properties in StatusBarController:

```swift
/// Menu item for the Launch at Login toggle.
private var launchAtLoginMenuItem: NSMenuItem?
```

In the `buildMenu()` method, insert the following AFTER the "About EmberHearth" item and BEFORE the final separator (before `menu.addItem(NSMenuItem.separator())` that precedes the Quit item):

```swift
        // Launch at Login toggle
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        launchItem.setAccessibilityLabel(
            LaunchAtLoginManager.shared.isEnabled
                ? "Launch at Login is enabled. Click to disable."
                : "Launch at Login is disabled. Click to enable."
        )
        self.launchAtLoginMenuItem = launchItem
        menu.addItem(launchItem)
```

Add this @objc method to StatusBarController's "Menu Actions" section:

```swift
    /// Toggles the Launch at Login setting and updates the menu checkbox.
    @objc private func toggleLaunchAtLogin() {
        let newState = !LaunchAtLoginManager.shared.isEnabled
        let success = LaunchAtLoginManager.shared.setEnabled(newState)

        if success {
            refreshLaunchAtLoginState()
        }
    }
```

Add this method to StatusBarController (below the menu actions section):

```swift
    // MARK: - State Refresh

    /// Updates the Launch at Login menu item to reflect the current system state.
    /// Call this when the menu is about to open to catch external changes
    /// (e.g., user changed setting in System Settings).
    func refreshLaunchAtLoginState() {
        let isEnabled = LaunchAtLoginManager.shared.isEnabled
        launchAtLoginMenuItem?.state = isEnabled ? .on : .off
        launchAtLoginMenuItem?.setAccessibilityLabel(
            isEnabled
                ? "Launch at Login is enabled. Click to disable."
                : "Launch at Login is disabled. Click to enable."
        )
    }
```

The final menu order should be:
1. EmberHearth v0.1.0 (1)  [disabled title]
2. ─────────────
3. Status: Starting...      [disabled status]
4. ─────────────
5. Settings...              [Cmd+,]
6. About EmberHearth
7. Launch at Login           [checkmark toggle]
8. ─────────────
9. Quit EmberHearth          [Cmd+Q]

STEP 3: Update src/App/AppDelegate.swift — Synchronize on launch

Add a call to LaunchAtLoginManager.shared.synchronize() in applicationDidFinishLaunching, AFTER the status bar setup:

In AppDelegate.applicationDidFinishLaunching, add this line after `statusBarController.updateState(.starting)`:

```swift
        // Synchronize launch-at-login state with user preference.
        // On first launch, this defaults to enabled.
        LaunchAtLoginManager.shared.synchronize()
```

STEP 4: Create the unit test

File: tests/LaunchAtLoginTests.swift
```swift
// LaunchAtLoginTests.swift
// EmberHearth
//
// Unit tests for LaunchAtLoginManager state management.

import XCTest
@testable import EmberHearth

final class LaunchAtLoginTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up UserDefaults before each test to ensure isolation
        UserDefaults.standard.removeObject(forKey: "launchAtLoginEnabled")
    }

    override func tearDown() {
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: "launchAtLoginEnabled")
        super.tearDown()
    }

    func testUserPreferenceIsNilOnFirstLaunch() {
        // On a fresh install, the user has never set a preference
        XCTAssertNil(LaunchAtLoginManager.shared.userPreference,
                     "User preference should be nil before any interaction")
    }

    func testSetEnabledStoresPreference() {
        // When we set enabled, the preference should be stored
        LaunchAtLoginManager.shared.setEnabled(true)
        XCTAssertEqual(LaunchAtLoginManager.shared.userPreference, true,
                       "User preference should be true after enabling")

        LaunchAtLoginManager.shared.setEnabled(false)
        XCTAssertEqual(LaunchAtLoginManager.shared.userPreference, false,
                       "User preference should be false after disabling")
    }

    func testStatusDescriptionReturnsString() {
        // statusDescription should always return a non-empty string
        let description = LaunchAtLoginManager.shared.statusDescription
        XCTAssertFalse(description.isEmpty,
                       "Status description should not be empty")
    }

    func testSynchronizeOnFirstLaunchSetsPreference() {
        // First launch should default to enabling launch at login
        XCTAssertNil(LaunchAtLoginManager.shared.userPreference)
        LaunchAtLoginManager.shared.synchronize()
        XCTAssertEqual(LaunchAtLoginManager.shared.userPreference, true,
                       "First launch synchronize should set preference to true")
    }
}
```

STEP 5: Verify the build

After creating/modifying all files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. Common issues:
- `import ServiceManagement` may fail if the deployment target is wrong — verify Package.swift has .macOS(.v13)
- SMAppService.mainApp is available on macOS 13.0+ which matches our target
- The test file must be in tests/ directory
- LaunchAtLoginManager.shared is a singleton — tests that modify state need proper setUp/tearDown cleanup

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify EmberHearthApp.swift.
- Do NOT modify ContentView.swift.
- Do NOT modify any module placeholder files.
- Do NOT add any third-party dependencies.
- SMAppService is Apple's official API for launch-at-login (replaces the deprecated SMLoginItemSetEnabled and LSSharedFileList approaches).
- The UserDefaults preference key is "launchAtLoginEnabled". This stores the user's INTENT, which may differ from the system state if they modify settings in System Settings > General > Login Items.
- The synchronize() method is called on every app launch to reconcile preference vs system state.
- On first launch (userPreference is nil), launch-at-login defaults to ENABLED. This matches the spec: EmberHearth should always be running as a personal assistant.
- Error handling is graceful: failed registration is logged, not surfaced to the user. The method returns a Bool so callers can decide what to do.
- The menu item uses .state = .on/.off to show a checkmark, which is the standard macOS pattern for toggle menu items.
- LaunchAtLoginManager.shared.synchronize() must be called AFTER statusBarController.setup() in AppDelegate, because the menu bar must exist before we try to update it.
```

---

## Acceptance Criteria

- [ ] `src/App/LaunchAtLoginManager.swift` exists with complete implementation
- [ ] LaunchAtLoginManager uses `SMAppService.mainApp` (not deprecated APIs)
- [ ] LaunchAtLoginManager uses singleton pattern (`shared` static property)
- [ ] `isEnabled` property checks actual `SMAppService.status` (not just UserDefaults)
- [ ] `userPreference` property returns `nil` on first launch, `Bool` after first set
- [ ] `setEnabled(_:)` stores preference in UserDefaults AND calls SMAppService register/unregister
- [ ] `setEnabled(_:)` returns `Bool` indicating success/failure
- [ ] `synchronize()` enables by default on first launch
- [ ] `synchronize()` reconciles preference vs system state on subsequent launches
- [ ] Errors are logged via `OSLog` (Logger), never crash the app
- [ ] StatusBarController menu includes "Launch at Login" toggle item
- [ ] Toggle item shows checkmark (.on/.off state) reflecting current status
- [ ] Toggle item has VoiceOver accessibility label describing current state
- [ ] AppDelegate calls `LaunchAtLoginManager.shared.synchronize()` during launch
- [ ] `tests/LaunchAtLoginTests.swift` exists with at least 4 test cases
- [ ] `swift build` succeeds with no errors
- [ ] `swift test` succeeds (all tests pass, including existing 0001 tests)

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/App/LaunchAtLoginManager.swift && echo "LaunchAtLoginManager.swift exists" || echo "MISSING"
test -f tests/LaunchAtLoginTests.swift && echo "LaunchAtLoginTests.swift exists" || echo "MISSING"

# Verify SMAppService usage (not deprecated APIs)
grep -q "SMAppService" src/App/LaunchAtLoginManager.swift && echo "Uses SMAppService" || echo "WRONG API"
grep -q "SMLoginItemSetEnabled" src/App/LaunchAtLoginManager.swift && echo "WARNING: Uses deprecated API" || echo "OK: No deprecated APIs"

# Verify singleton pattern
grep -q "static let shared" src/App/LaunchAtLoginManager.swift && echo "Has singleton" || echo "MISSING singleton"

# Verify OSLog usage for error logging
grep -q "Logger" src/App/LaunchAtLoginManager.swift && echo "Uses Logger (OSLog)" || echo "MISSING logging"

# Verify UserDefaults preference key
grep -q "launchAtLoginEnabled" src/App/LaunchAtLoginManager.swift && echo "Has preference key" || echo "MISSING preference key"

# Verify menu integration
grep -q "Launch at Login" src/App/StatusBarController.swift && echo "Menu item exists" || echo "MISSING menu item"
grep -q "toggleLaunchAtLogin" src/App/StatusBarController.swift && echo "Toggle action exists" || echo "MISSING toggle action"

# Verify AppDelegate synchronize call
grep -q "synchronize" src/App/AppDelegate.swift && echo "AppDelegate calls synchronize" || echo "MISSING synchronize call"

# Build the project
swift build 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the Launch at Login implementation created in task 0004 for EmberHearth. Check for these common Sonnet failure modes:

1. SMAppService API USAGE:
   - Verify `import ServiceManagement` is present (not `import SMAppService` which doesn't exist)
   - Verify `SMAppService.mainApp` is used (not `SMAppService(bundleIdentifier:)` which is for helper apps)
   - Verify .register() and .unregister() are called (not older deprecated methods)
   - Verify service.status is compared to .enabled (not .registered or other values)

2. SINGLETON CORRECTNESS:
   - Verify `init()` is private (prevents external instantiation)
   - Verify `static let shared = LaunchAtLoginManager()` exists
   - Verify tests use `LaunchAtLoginManager.shared` (not creating new instances)

3. USERDEFAULTS ISOLATION IN TESTS:
   - Verify setUp() removes the "launchAtLoginEnabled" key before each test
   - Verify tearDown() cleans up after each test
   - If tests don't clean up, they may affect each other and produce false positives

4. ERROR HANDLING:
   - Verify setEnabled() wraps SMAppService calls in do/catch (not try!)
   - Verify errors are logged via Logger, not printed to console
   - Verify setEnabled() returns Bool, not Void
   - Verify the method is marked @discardableResult so callers can ignore the return value

5. MENU ITEM INTEGRATION:
   - Verify the "Launch at Login" item is in the correct position in the menu (between About and final separator)
   - Verify .target = self is set on the menu item (critical for action delivery)
   - Verify .state is set to .on or .off (not a string or bool)
   - Verify the @objc method calls LaunchAtLoginManager.shared (not creating a new instance)

6. SYNCHRONIZE BEHAVIOR:
   - Verify synchronize() checks userPreference for nil (first launch detection)
   - Verify first launch defaults to enabled (setEnabled(true))
   - Verify subsequent launches only try to re-register if preference is true but system says disabled
   - Verify synchronize() is called in AppDelegate.applicationDidFinishLaunching AFTER statusBarController.setup()

7. ACCESSIBILITY:
   - Verify the Launch at Login menu item has setAccessibilityLabel()
   - Verify the label changes based on current state (not just a static string)
   - Verify refreshLaunchAtLoginState() updates the accessibility label

8. BUILD AND TEST VERIFICATION:
   - Run `swift build` and confirm success
   - Run `swift test` and confirm ALL tests pass (including Task 0001 module tests)
   - Verify no warnings about deprecated APIs or missing imports
   - Note: SMAppService register/unregister may fail in test environment (no app bundle). Tests should account for this by testing preference storage, not system registration.

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m1): add launch at login via SMAppService
```

---

## Notes for Next Task

- LaunchAtLoginManager is at `src/App/LaunchAtLoginManager.swift`. It uses the singleton pattern via `LaunchAtLoginManager.shared`.
- The user preference is stored in UserDefaults under the key `"launchAtLoginEnabled"`. Future settings UI can bind to this.
- `synchronize()` is called on every app launch from AppDelegate. It handles first-launch defaults and preference-vs-system reconciliation.
- The "Launch at Login" toggle is in the menu bar dropdown, managed by StatusBarController. The `refreshLaunchAtLoginState()` method can be called to update the checkbox from outside.
- SMAppService.mainApp works for the main app executable. If the project later moves to an XPC architecture, helper app registration would use `SMAppService(bundleIdentifier:)` instead, but that is not needed for MVP.
- The next task in M1 would logically be either basic logging infrastructure or initial settings UI, depending on the roadmap. The foundation tasks (project setup, app shell, menu bar, launch at login) are now complete.
- All M1 Foundation milestone items from mvp-scope.md are addressed by tasks 0001-0004:
  - [x] Xcode project setup with signing (0001)
  - [x] Basic SwiftUI app structure (0002)
  - [x] Menu bar presence (0003)
  - [x] Launch at login (0004)
