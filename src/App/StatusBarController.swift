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
/// - **Ready:** Flame icon (template, adapts to system theme)
/// - **Processing:** Flame icon with subtle pulse animation
/// - **Degraded:** Flame icon (yellow tint)
/// - **Error:** Exclamation triangle (red)
/// - **Offline:** Flame icon (dimmed)
/// - **Paused:** Pause circle icon (template)
///
/// The dropdown menu shows detailed status information and controls.
///
/// ## Accessibility
/// - Menu items have VoiceOver-friendly titles and accessibility labels
/// - Status information is conveyed in text, not just color
@MainActor
final class StatusBarController: NSObject {

    // MARK: - Properties

    /// The status bar item in the macOS menu bar.
    private var statusItem: NSStatusItem?

    /// Reference to the app state for status updates.
    private let appState: AppState

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
        super.init()
        logger.info("StatusBarController initialized")
    }

    // MARK: - Setup

    /// Sets up the status bar item. Call once from AppDelegate.
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let statusItem else { return }

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth")
            button.image?.isTemplate = true
            button.setAccessibilityLabel("EmberHearth")
            button.setAccessibilityHelp("Click to open EmberHearth menu")
            button.setAccessibilityRole(.menuButton)
        }

        rebuildMenu()
        observeStateChanges()
    }

    /// Observes AppState changes and updates the menu bar accordingly.
    private func observeStateChanges() {
        appState.$status
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                self?.updateIcon(for: newStatus)
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        appState.$messageCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        appState.$isPaused
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateIcon(for: self?.appState.status ?? .starting)
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

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

        guard let button = statusItem?.button else { return }

        // Paused state takes visual precedence over normal status
        if appState.isPaused {
            button.image = NSImage(systemSymbolName: "pause.circle.fill", accessibilityDescription: "EmberHearth paused")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.appearsDisabled = false
            button.setAccessibilityLabel("EmberHearth is paused")
            return
        }

        switch status {
        case .starting:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth starting")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.appearsDisabled = true
            button.setAccessibilityLabel("EmberHearth is starting up")

        case .ready:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth ready")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.appearsDisabled = false
            button.setAccessibilityLabel("EmberHearth is running and ready")

        case .processing:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth thinking")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.appearsDisabled = false
            button.setAccessibilityLabel("EmberHearth is thinking")
            startPulseAnimation()

        case .degraded(let reason):
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth limited")
            button.image?.isTemplate = false
            button.contentTintColor = .systemYellow
            button.appearsDisabled = false
            button.setAccessibilityLabel("EmberHearth has limited functionality: \(reason)")

        case .error(let reason):
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "EmberHearth error")
            button.image?.isTemplate = false
            button.contentTintColor = .systemRed
            button.appearsDisabled = false
            button.setAccessibilityLabel("EmberHearth has an issue: \(reason)")

        case .offline:
            button.image = NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "EmberHearth offline")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.appearsDisabled = true
            button.setAccessibilityLabel("EmberHearth is offline")
        }
    }

    // MARK: - Pulse Animation

    /// Starts a subtle pulse animation for the processing state.
    private func startPulseAnimation() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isPulseBright.toggle()
                self.statusItem?.button?.appearsDisabled = !self.isPulseBright
            }
        }
    }

    /// Stops the pulse animation and resets button appearance.
    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        isPulseBright = false
        statusItem?.button?.appearsDisabled = false
    }

    // MARK: - Menu Construction

    /// Rebuilds the dropdown menu with current state information.
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.setAccessibilityLabel("EmberHearth menu")

        // Status line
        let statusMenuItem = NSMenuItem(title: "Ember: \(appState.status.statusLine)", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.setAccessibilityLabel("EmberHearth status: \(appState.status.statusLine)")
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Onboarding prompt or restart option
        if !appState.isOnboardingComplete {
            let setupItem = NSMenuItem(title: "Setup Required\u{2026}", action: #selector(openOnboarding), keyEquivalent: "")
            setupItem.target = self
            setupItem.setAccessibilityLabel("EmberHearth setup is required")
            menu.addItem(setupItem)
            menu.addItem(NSMenuItem.separator())
        } else {
            let restartItem = NSMenuItem(title: "Restart Setup\u{2026}", action: #selector(openOnboarding), keyEquivalent: "")
            restartItem.target = self
            restartItem.setAccessibilityLabel("Restart EmberHearth setup wizard")
            menu.addItem(restartItem)
            menu.addItem(NSMenuItem.separator())
        }

        // Message stats
        let messageItem = NSMenuItem(title: "Messages today: \(appState.messageCount)", action: nil, keyEquivalent: "")
        messageItem.isEnabled = false
        messageItem.setAccessibilityLabel("Messages today: \(appState.messageCount)")
        menu.addItem(messageItem)

        let lastMessageItem = NSMenuItem(title: "Last message: \(appState.lastMessageDescription)", action: nil, keyEquivalent: "")
        lastMessageItem.isEnabled = false
        lastMessageItem.setAccessibilityLabel("Last message: \(appState.lastMessageDescription)")
        menu.addItem(lastMessageItem)

        if appState.factCount > 0 {
            let plural = appState.factCount == 1 ? "fact" : "facts"
            let factItem = NSMenuItem(title: "Memory: \(appState.factCount) \(plural) stored", action: nil, keyEquivalent: "")
            factItem.isEnabled = false
            factItem.setAccessibilityLabel("Memory: \(appState.factCount) \(plural) stored")
            menu.addItem(factItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Pause / Resume toggle
        let pauseTitle = appState.isPaused ? "Resume Ember" : "Pause Ember"
        let pauseAccessibility = appState.isPaused ? "Resume Ember responses" : "Pause Ember responses"
        let pauseItem = NSMenuItem(title: pauseTitle, action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        pauseItem.setAccessibilityLabel(pauseAccessibility)
        menu.addItem(pauseItem)

        menu.addItem(NSMenuItem.separator())

        // Launch at Login
        let launchItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLoginManager.shared.isEnabled ? .on : .off
        launchItem.setAccessibilityLabel(
            LaunchAtLoginManager.shared.isEnabled
                ? "Launch at Login is enabled. Click to disable."
                : "Launch at Login is disabled. Click to enable."
        )
        menu.addItem(launchItem)

        // Settings
        let settingsItem = NSMenuItem(title: "Settings\u{2026}", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.setAccessibilityLabel("Open EmberHearth settings")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit EmberHearth", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.setAccessibilityLabel("Quit EmberHearth application")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    /// Resets onboarding state and brings the main window forward so
    /// ContentView re-evaluates and shows the onboarding flow.
    @objc private func openOnboarding() {
        logger.info("Opening onboarding from menu bar")
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        appState.isOnboardingComplete = false
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Opens the Settings window.
    @objc private func openSettings() {
        logger.info("Opening settings from menu bar")
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    /// Toggles the pause state.
    @objc private func togglePause() {
        appState.togglePause()
    }

    /// Toggles the Launch at Login setting and refreshes the menu.
    @objc private func toggleLaunchAtLogin() {
        let newState = !LaunchAtLoginManager.shared.isEnabled
        LaunchAtLoginManager.shared.setEnabled(newState)
        rebuildMenu()
    }

    /// Quits the application.
    @objc private func quitApp() {
        logger.info("Quit requested from menu bar")
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Cleanup

    /// Removes the status item from the menu bar and cancels all subscriptions.
    func teardown() {
        stopPulseAnimation()
        cancellables.removeAll()
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
        logger.info("StatusBarController torn down")
    }
}
