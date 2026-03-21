// AppDelegate.swift
// EmberHearth
//
// Application delegate managing the startup sequence, menu bar, and lifecycle.

import AppKit
import SwiftUI
import os

/// The application delegate for EmberHearth.
///
/// Manages the complete lifecycle:
/// - Startup: Initializes all components via `ServiceContainer`
/// - Running: Manages the menu bar status item and settings window
/// - Shutdown: Performs clean teardown of all services
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// The service container holding all initialized components.
    /// `nil` until startup completes successfully.
    private var services: ServiceContainer?

    /// The status bar controller for the menu bar icon.
    private var statusBarController: StatusBarController?

    /// Logger for startup and lifecycle events.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "AppDelegate"
    )

    /// Manages crash detection and recovery across launches.
    private let crashRecoveryManager = CrashRecoveryManager()

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("EmberHearth starting — version \(AppVersion.displayString, privacy: .public)")

        // Configure as an accessory app (menu bar only, no Dock icon).
        NSApp.setActivationPolicy(.accessory)

        // Step 1: Check for crash recovery before touching any state.
        checkForCrashRecovery()

        // Step 2: Synchronize launch-at-login with user preference.
        LaunchAtLoginManager.shared.synchronize()

        // Step 3: Check if onboarding has been completed.
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else {
            logger.info("Onboarding not complete — showing onboarding window")
            showOnboardingWindow()
            return
        }

        // Step 4: Load API key from Keychain.
        guard let apiKey = loadAPIKey() else {
            logger.warning("No API key in Keychain — showing onboarding")
            showOnboardingWindow()
            return
        }

        // Step 5: Initialize all services and start the coordinator.
        startServices(apiKey: apiKey)
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("EmberHearth shutting down...")

        services?.shutdown()
        statusBarController?.teardown()

        crashRecoveryManager.markCleanShutdown()

        logger.info("Shutdown complete.")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        // Menu bar app — do NOT quit when the window is closed.
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When the user clicks the app icon in Finder or Spotlight, show the main window.
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    // MARK: - Startup

    /// Initializes all services and starts the message coordinator.
    ///
    /// On failure, shows an appropriate error alert with options to resolve the issue.
    private func startServices(apiKey: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Initialize the service container (all components in dependency order).
        let container: ServiceContainer
        do {
            container = try ServiceContainer.initialize(apiKey: apiKey)
        } catch let error as AppStartupError {
            logger.error("Service initialization failed: \(error.localizedDescription, privacy: .public)")
            handleStartupError(error)
            return
        } catch {
            logger.error("Unexpected initialization error: \(error.localizedDescription, privacy: .public)")
            handleStartupError(.componentInitializationFailed(component: "services", underlying: error))
            return
        }

        self.services = container

        // Set up the menu bar status item.
        let controller = StatusBarController(appState: container.appState)
        statusBarController = controller
        controller.setup()

        // Start the message coordinator (begins watching chat.db).
        do {
            try container.start()
        } catch let error as ChatDatabaseError {
            logger.warning("iMessage watcher failed to start: \(error.localizedDescription, privacy: .public)")
            // Degrade gracefully — services are up but messages won't be received.
            container.appState.addError(.chatDbInaccessible)
        } catch {
            logger.error("Unexpected error starting coordinator: \(error.localizedDescription, privacy: .public)")
            handleStartupError(.componentInitializationFailed(component: "message coordinator", underlying: error))
            return
        }

        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        logger.info("EmberHearth ready in \(String(format: "%.0f", elapsed), privacy: .public)ms")

        if elapsed > 3_000 {
            logger.warning("Startup exceeded target: \(String(format: "%.0f", elapsed), privacy: .public)ms (target: <3000ms)")
        }

        // Bring the main window to front on first launch.
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Loads the Claude API key from the Keychain.
    ///
    /// - Returns: The API key string, or `nil` if not found or empty.
    private func loadAPIKey() -> String? {
        let keychain = KeychainManager()
        do {
            guard let key = try keychain.retrieve(for: .claude) else {
                logger.info("No API key stored in Keychain")
                return nil
            }
            guard !key.isEmpty else {
                logger.warning("API key found but is empty")
                return nil
            }
            return key
        } catch {
            logger.info("Keychain retrieval failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Checks whether the previous shutdown was clean and performs recovery if needed.
    ///
    /// Delegates to `CrashRecoveryManager` which tracks the clean-shutdown flag
    /// via its own UserDefaults key (`cleanShutdown`).
    private func checkForCrashRecovery() {
        if crashRecoveryManager.didCrashLastRun() {
            logger.warning("Previous shutdown was not clean — possible crash")
            // Full recovery (database integrity check, stale session cleanup)
            // runs asynchronously; it does not block the startup sequence.
            Task { [weak self] in
                guard let self, let appState = self.services?.appState else { return }
                let result = await self.crashRecoveryManager.performRecovery(appState: appState)
                if result.shouldNotifyUser {
                    self.logger.warning("Multiple crashes detected today: \(result.crashCountToday)")
                }
            }
        }

        crashRecoveryManager.markSessionStarted()
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

        case .chatDatabaseNotFound:
            showErrorAlert(
                title: "iMessage Access Required",
                message: "EmberHearth needs Full Disk Access to read iMessages. Please grant it in System Settings > Privacy & Security.",
                showSettings: false
            )
        }
    }

    /// Presents a modal error alert, with an optional "Open Settings" button.
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
        logger.info("Showing onboarding window")
        // TODO: Present OnboardingContainerView via window controller (task 0600–0699)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// Shows the settings window.
    private func showSettingsWindow() {
        logger.info("Showing settings window")
        // TODO: Present SettingsView via window controller (task 0701)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Onboarding Callback

    /// Called by the onboarding UI when setup is complete.
    ///
    /// Marks onboarding as complete, then attempts to start all services
    /// using the newly-stored API key.
    func onboardingCompleted() {
        logger.info("Onboarding completed — starting services")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        guard let apiKey = loadAPIKey() else {
            logger.error("Onboarding completed but no API key found")
            return
        }

        startServices(apiKey: apiKey)
    }
}
