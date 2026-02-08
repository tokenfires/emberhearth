# Task 0003: Menu Bar Presence with Status Indicator

**Milestone:** M1 - Foundation
**Unit:** 1.3 - Menu Bar Presence (NSStatusItem)
**Phase:** 1
**Depends On:** Task 0002 (SwiftUI App Shell)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; focus on accessibility requirements (VoiceOver for all UI), naming conventions (PascalCase), security boundaries
2. `docs/architecture-overview.md` — Focus on lines 90-99: EmberHearth.app responsibilities, and lines 574-586: MVP scope table (menu bar presence is MVP)
3. `docs/releases/mvp-scope.md` — Focus on lines 59-81: "Mac App > System" section showing menu bar presence, launch at login, and status indicator as MVP features

> **Context Budget Note:** architecture-overview.md is 770+ lines. Only read the EmberHearth.app section (lines 90-121) and the MVP Scope table (lines 574-586). For mvp-scope.md, only read lines 59-81 (Mac App system features).

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the menu bar presence for EmberHearth, a native macOS personal AI assistant that runs as a menu bar app. Tasks 0001 and 0002 have set up the project structure and basic SwiftUI app shell.

Your job is to create a StatusBarController that manages an NSStatusItem in the macOS menu bar, with a dropdown menu for basic app control.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase
- All UI must support VoiceOver accessibility
- Follow Apple Human Interface Guidelines
- Security first: never implement shell execution

WHAT EXISTS (from Tasks 0001-0002):
- Package.swift at project root
- src/App/EmberHearthApp.swift — @main entry point with NSApplicationDelegateAdaptor
- src/App/AppDelegate.swift — NSApplicationDelegate with .accessory activation policy
- src/Views/ContentView.swift — Basic welcome view
- Module placeholder files in all directories

STEP 1: Create src/App/StatusBarController.swift

This is the main class that manages the menu bar icon and dropdown menu.

File: src/App/StatusBarController.swift
```swift
// StatusBarController.swift
// EmberHearth
//
// Manages the NSStatusItem (menu bar icon) and its dropdown menu.
// Provides visual status indication and quick access to app functions.

import AppKit
import SwiftUI

/// Represents the current operational state of EmberHearth.
/// Used to change the menu bar icon appearance and status text.
enum AppHealthState: String, CaseIterable {
    case healthy    = "Connected"
    case degraded   = "Degraded"
    case error      = "Error"
    case offline    = "Offline"
    case starting   = "Starting..."

    /// The tint color applied to the menu bar icon for this state.
    var iconTintColor: NSColor {
        switch self {
        case .healthy:  return .systemGreen
        case .degraded: return .systemYellow
        case .error:    return .systemRed
        case .offline:  return .systemGray
        case .starting: return .systemGray
        }
    }

    /// A user-friendly description of the current state.
    var statusDescription: String {
        switch self {
        case .healthy:  return "Status: Connected"
        case .degraded: return "Status: Limited"
        case .error:    return "Status: Error"
        case .offline:  return "Status: Offline"
        case .starting: return "Status: Starting..."
        }
    }

    /// VoiceOver description for the menu bar icon in this state.
    var accessibilityDescription: String {
        switch self {
        case .healthy:  return "EmberHearth is running and connected"
        case .degraded: return "EmberHearth is running with limited functionality"
        case .error:    return "EmberHearth has encountered an error"
        case .offline:  return "EmberHearth is offline"
        case .starting: return "EmberHearth is starting up"
        }
    }
}

/// Manages the persistent menu bar icon and dropdown menu for EmberHearth.
///
/// Usage:
/// ```
/// let controller = StatusBarController()
/// controller.updateState(.healthy)
/// ```
final class StatusBarController {

    // MARK: - Properties

    /// The system status bar item. Retained strongly to keep it visible.
    private var statusItem: NSStatusItem?

    /// The dropdown menu attached to the status item.
    private let menu = NSMenu()

    /// Current health state of the application.
    private(set) var currentState: AppHealthState = .starting

    /// Menu item that displays the current status (updated dynamically).
    private var statusMenuItem: NSMenuItem?

    /// The app version string, read from the bundle.
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(version) (\(build))"
    }

    // MARK: - Initialization

    /// Sets up the status bar item with icon and menu.
    /// Call this once during app launch (from AppDelegate.applicationDidFinishLaunching).
    func setup() {
        // Create the status bar item with variable width
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else { return }

        // Configure the button (the clickable area in the menu bar)
        if let button = statusItem.button {
            updateIcon(for: .starting, button: button)

            // VoiceOver accessibility
            button.setAccessibilityLabel("EmberHearth")
            button.setAccessibilityHelp("Click to open EmberHearth menu")
            button.setAccessibilityRole(.menuButton)
        }

        // Build and attach the dropdown menu
        buildMenu()
        statusItem.menu = menu

        // Set the menu's accessibility
        menu.setAccessibilityLabel("EmberHearth menu")
    }

    // MARK: - State Management

    /// Updates the visual state of the menu bar icon and status text.
    ///
    /// - Parameter newState: The new health state to display.
    func updateState(_ newState: AppHealthState) {
        currentState = newState

        // Update icon
        if let button = statusItem?.button {
            updateIcon(for: newState, button: button)
            button.setAccessibilityLabel(newState.accessibilityDescription)
        }

        // Update status menu item text
        statusMenuItem?.title = newState.statusDescription
    }

    // MARK: - Menu Construction

    /// Builds the dropdown menu with all items.
    /// Menu structure:
    ///   EmberHearth v0.1.0 (1)      [disabled, title]
    ///   ─────────────────────
    ///   Status: Starting...          [disabled, dynamic]
    ///   ─────────────────────
    ///   Settings...                  [opens settings window]
    ///   About EmberHearth            [shows about panel]
    ///   ─────────────────────
    ///   Quit EmberHearth             [terminates app]
    private func buildMenu() {
        menu.removeAllItems()

        // Title item (disabled, shows app name and version)
        let titleItem = NSMenuItem(
            title: "EmberHearth \(appVersion)",
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false
        titleItem.setAccessibilityLabel("EmberHearth version \(appVersion)")
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Status item (disabled, shows current state)
        let statusItem = NSMenuItem(
            title: currentState.statusDescription,
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        statusItem.setAccessibilityLabel(currentState.statusDescription)
        self.statusMenuItem = statusItem
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Settings item
        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.setAccessibilityLabel("Open EmberHearth settings")
        menu.addItem(settingsItem)

        // About item
        let aboutItem = NSMenuItem(
            title: "About EmberHearth",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        aboutItem.setAccessibilityLabel("Show information about EmberHearth")
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // Quit item
        let quitItem = NSMenuItem(
            title: "Quit EmberHearth",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.setAccessibilityLabel("Quit EmberHearth application")
        menu.addItem(quitItem)
    }

    // MARK: - Icon Rendering

    /// Updates the menu bar icon with the appropriate tint for the given state.
    ///
    /// Uses SF Symbol "flame.fill" as the base icon and applies a color tint
    /// based on the current health state.
    ///
    /// - Parameters:
    ///   - state: The health state to represent visually.
    ///   - button: The NSStatusBarButton to update.
    private func updateIcon(for state: AppHealthState, button: NSStatusBarButton) {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let baseImage = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth")

        if let image = baseImage {
            let tintedImage = image.withSymbolConfiguration(config)

            // Apply tint color using a template approach
            let coloredImage = tintedImage ?? image
            coloredImage.isTemplate = false

            // Create a tinted version by drawing with the state color
            let tinted = NSImage(size: coloredImage.size, flipped: false) { rect in
                coloredImage.draw(in: rect)
                state.iconTintColor.set()
                rect.fill(using: .sourceAtop)
                return true
            }

            button.image = tinted
        }
    }

    // MARK: - Menu Actions

    /// Opens the main settings window and brings it to the front.
    @objc private func openSettings() {
        // Activate the app to bring it to the foreground
        NSApp.activate(ignoringOtherApps: true)

        // Find and show the main window, or create one if needed
        if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<ContentView> }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // If no window exists, the WindowGroup should create one
            // This is handled by SwiftUI's WindowGroup lifecycle
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    /// Shows the standard macOS About panel for EmberHearth.
    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "EmberHearth",
                .applicationVersion: appVersion,
                .credits: NSAttributedString(
                    string: "Your personal AI assistant",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 11),
                        .foregroundColor: NSColor.secondaryLabelColor
                    ]
                )
            ]
        )
    }

    /// Terminates the application.
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Cleanup

    /// Removes the status item from the menu bar.
    /// Call this if you ever need to remove the icon (typically not needed).
    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
```

STEP 2: Update src/App/AppDelegate.swift

Modify AppDelegate to create and retain the StatusBarController. Add a stored property and wire it up in applicationDidFinishLaunching.

Replace the ENTIRE contents of src/App/AppDelegate.swift with:

File: src/App/AppDelegate.swift
```swift
// AppDelegate.swift
// EmberHearth
//
// NSApplicationDelegate for system-level integration.
// Manages app lifecycle events, menu bar presence,
// and other system hooks that SwiftUI doesn't directly support.

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// The menu bar controller that manages the NSStatusItem and dropdown menu.
    private let statusBarController = StatusBarController()

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the app as an accessory application.
        // LSUIElement is set in Info.plist, but we also set the activation policy
        // programmatically to ensure the app runs without a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        // Set up the menu bar icon and dropdown menu
        statusBarController.setup()

        // Set initial state to "starting" — will transition to "healthy"
        // once all subsystems are initialized (future tasks).
        statusBarController.updateState(.starting)

        // Simulate transition to healthy after a brief delay.
        // In production, this will be driven by actual health checks (M5+).
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.statusBarController.updateState(.healthy)
        }

        // Bring the main window to front on first launch
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean shutdown: remove status bar item, flush pending writes.
        statusBarController.teardown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        // Do NOT quit when the window is closed. EmberHearth runs in the background
        // as a menu bar app. The user quits via the menu bar dropdown.
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When the user clicks the app in Finder or Spotlight, show the main window.
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}
```

STEP 3: Verify the build

After creating/modifying all files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
```

The build must succeed. Common issues to check:
- StatusBarController.swift must be in src/App/ (same directory as AppDelegate)
- AppDelegate must import both AppKit and SwiftUI
- No duplicate @main entry points
- All @objc methods must be on a class that inherits from NSObject (StatusBarController inherits from nothing currently — if the compiler complains about @objc, make StatusBarController inherit from NSObject)

IMPORTANT: If `swift build` fails because @objc requires NSObject inheritance, update StatusBarController to:
```swift
final class StatusBarController: NSObject {
```
This is the most likely build failure. Fix it proactively.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify EmberHearthApp.swift (it was set up correctly in Task 0002).
- Do NOT modify ContentView.swift.
- Do NOT modify any module placeholder files.
- Do NOT add any third-party dependencies.
- The StatusBarController uses NSStatusItem (AppKit), not SwiftUI. Menu bar items require AppKit on macOS.
- The flame icon uses SF Symbol "flame.fill" with tint colors for different states.
- All menu items include VoiceOver accessibility labels via setAccessibilityLabel().
- The "Settings..." menu item uses the standard macOS keyboard shortcut Cmd+, (comma).
- The "Quit EmberHearth" menu item uses the standard Cmd+Q shortcut.
- The Settings action opens the main SwiftUI window. The About action uses the standard NSApplication about panel.
```

---

## Acceptance Criteria

- [ ] `src/App/StatusBarController.swift` exists with complete implementation
- [ ] `src/App/AppDelegate.swift` creates and retains a StatusBarController instance
- [ ] StatusBarController creates an NSStatusItem with "flame.fill" SF Symbol icon
- [ ] Dropdown menu contains all 6 items: title, separator, status, separator, Settings.../About, separator, Quit
- [ ] AppHealthState enum defines all 5 states: healthy, degraded, error, offline, starting
- [ ] Each state has a distinct icon tint color (green, yellow, red, gray, gray)
- [ ] Icon tint changes when `updateState(_:)` is called
- [ ] "Settings..." menu item has Cmd+, keyboard shortcut
- [ ] "Quit EmberHearth" menu item has Cmd+Q keyboard shortcut and terminates the app
- [ ] "About EmberHearth" shows the standard macOS about panel
- [ ] All menu items have VoiceOver accessibility labels via `setAccessibilityLabel()`
- [ ] The NSStatusBarButton has accessibility role set to `.menuButton`
- [ ] `swift build` succeeds with no errors
- [ ] Existing tests from Task 0001 still pass

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/App/StatusBarController.swift && echo "StatusBarController.swift exists" || echo "MISSING"

# Verify StatusBarController is referenced in AppDelegate
grep -q "StatusBarController" src/App/AppDelegate.swift && echo "AppDelegate uses StatusBarController" || echo "NOT WIRED UP"

# Verify all 5 health states exist
grep -c "case " src/App/StatusBarController.swift

# Verify SF Symbol usage
grep -q "flame.fill" src/App/StatusBarController.swift && echo "Uses flame.fill icon" || echo "WRONG ICON"

# Verify accessibility labels
grep -c "setAccessibilityLabel" src/App/StatusBarController.swift

# Verify menu items exist
grep "Settings" src/App/StatusBarController.swift
grep "About EmberHearth" src/App/StatusBarController.swift
grep "Quit EmberHearth" src/App/StatusBarController.swift

# Build the project
swift build 2>&1

# Run tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the menu bar integration created in task 0003 for EmberHearth. Check for these common Sonnet failure modes:

1. NSObject INHERITANCE:
   - StatusBarController must be `final class StatusBarController: NSObject` (not just `final class StatusBarController`)
   - Without NSObject, @objc selectors will crash at runtime
   - Verify all @objc methods are instance methods (not static/class methods)

2. STATUS ITEM RETENTION:
   - statusItem must be stored as a strong reference (var statusItem: NSStatusItem?)
   - If it's a local variable or weak reference, the menu bar icon will immediately disappear
   - Verify StatusBarController itself is retained strongly in AppDelegate (not a local variable)

3. MENU TARGET-ACTION PATTERN:
   - Every NSMenuItem with an action must have `target = self` set
   - Without setting target, the action may not fire or may fire on the wrong object
   - Verify: settingsItem.target = self, aboutItem.target = self, quitItem.target = self

4. KEYBOARD SHORTCUTS:
   - Settings: keyEquivalent must be "," (comma) — standard macOS convention
   - Quit: keyEquivalent must be "q" — standard macOS convention
   - Verify key equivalents are lowercase single characters, not modifier descriptions

5. ICON RENDERING:
   - Verify SF Symbol "flame.fill" is used (not "flame" or a custom image)
   - The icon must be visible in both light and dark menu bars
   - Check that isTemplate is set to false (since we're applying custom tint colors)
   - If isTemplate is true, macOS will override our tint colors

6. ACCESSIBILITY:
   - NSStatusBarButton must have setAccessibilityLabel("EmberHearth")
   - NSStatusBarButton must have setAccessibilityRole(.menuButton)
   - Every NSMenuItem must have setAccessibilityLabel() with descriptive text
   - The NSMenu itself should have setAccessibilityLabel("EmberHearth menu")

7. STATE TRANSITIONS:
   - Verify updateState() updates BOTH the icon AND the status menu item text
   - Verify the statusMenuItem is stored as a property (not recreated each time)
   - Verify initial state is .starting and transitions to .healthy

8. APP LIFECYCLE:
   - Verify AppDelegate calls statusBarController.setup() in applicationDidFinishLaunching
   - Verify AppDelegate calls statusBarController.teardown() in applicationWillTerminate
   - Verify applicationShouldTerminateAfterLastWindowClosed still returns false

9. BUILD VERIFICATION:
   - Run `swift build` and confirm success
   - Run `swift test` and confirm existing tests still pass
   - Check for any warnings about deprecated APIs

Report any issues found, with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m1): add menu bar presence with status indicator
```

---

## Notes for Next Task

- StatusBarController is in `src/App/StatusBarController.swift`. Task 0004 will add a "Launch at Login" toggle to the dropdown menu by modifying the `buildMenu()` method.
- The menu is built in `buildMenu()`. New items should be inserted before the final separator and Quit item.
- `updateState(_:)` is the public API for changing the displayed health state. Future tasks (M5+) will call this based on actual health monitoring.
- The AppDelegate retains the StatusBarController as a private property. It is not exposed publicly. If Task 0004 needs access, it can either add a public accessor or access it via the AppDelegate instance on NSApp.delegate.
- StatusBarController inherits from NSObject (required for @objc selectors). Any new @objc methods added in future tasks will work correctly.
- The simulated transition from `.starting` to `.healthy` after 2 seconds is a placeholder. Real health state transitions will be implemented in the self-monitoring milestone (M5+).
