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
/// controller.setup()
/// controller.updateState(.healthy)
/// ```
final class StatusBarController: NSObject {

    // MARK: - Properties

    /// The system status bar item. Retained strongly to keep it visible.
    private var statusItem: NSStatusItem?

    /// The dropdown menu attached to the status item.
    private let menu = NSMenu()

    /// Current health state of the application.
    private(set) var currentState: AppHealthState = .starting

    /// Menu item that displays the current status (updated dynamically).
    private var statusMenuItem: NSMenuItem?

    /// Menu item for the Launch at Login toggle.
    private var launchAtLoginMenuItem: NSMenuItem?

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem = statusItem else { return }

        if let button = statusItem.button {
            updateIcon(for: .starting, button: button)

            button.setAccessibilityLabel("EmberHearth")
            button.setAccessibilityHelp("Click to open EmberHearth menu")
            button.setAccessibilityRole(.menuButton)
        }

        buildMenu()
        statusItem.menu = menu

        menu.setAccessibilityLabel("EmberHearth menu")
    }

    // MARK: - State Management

    /// Updates the visual state of the menu bar icon and status text.
    ///
    /// - Parameter newState: The new health state to display.
    func updateState(_ newState: AppHealthState) {
        currentState = newState

        if let button = statusItem?.button {
            updateIcon(for: newState, button: button)
            button.setAccessibilityLabel(newState.accessibilityDescription)
        }

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
    ///   Launch at Login              [toggle, checkmark reflects state]
    ///   ─────────────────────
    ///   Quit EmberHearth             [terminates app]
    private func buildMenu() {
        menu.removeAllItems()

        let titleItem = NSMenuItem(
            title: "EmberHearth \(appVersion)",
            action: nil,
            keyEquivalent: ""
        )
        titleItem.isEnabled = false
        titleItem.setAccessibilityLabel("EmberHearth version \(appVersion)")
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

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

        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        settingsItem.setAccessibilityLabel("Open EmberHearth settings")
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(
            title: "About EmberHearth",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        aboutItem.setAccessibilityLabel("Show information about EmberHearth")
        menu.addItem(aboutItem)

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

        menu.addItem(NSMenuItem.separator())

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
    /// based on the current health state. isTemplate is set to false so macOS
    /// does not override our custom tint colors.
    private func updateIcon(for state: AppHealthState, button: NSStatusBarButton) {
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let baseImage = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth")

        if let image = baseImage {
            let configuredImage = image.withSymbolConfiguration(config) ?? image

            let tinted = NSImage(size: configuredImage.size, flipped: false) { rect in
                configuredImage.draw(in: rect)
                state.iconTintColor.set()
                rect.fill(using: .sourceAtop)
                return true
            }
            tinted.isTemplate = false

            button.image = tinted
        }
    }

    // MARK: - Menu Actions

    /// Opens the main settings window and brings it to the front.
    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.contentView is NSHostingView<ContentView> }) {
            window.makeKeyAndOrderFront(nil)
        } else {
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

    /// Toggles the Launch at Login setting and updates the menu checkbox.
    @objc private func toggleLaunchAtLogin() {
        let newState = !LaunchAtLoginManager.shared.isEnabled
        let success = LaunchAtLoginManager.shared.setEnabled(newState)

        if success {
            refreshLaunchAtLoginState()
        }
    }

    /// Terminates the application.
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

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

    // MARK: - Cleanup

    /// Removes the status item from the menu bar.
    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
