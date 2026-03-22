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

    /// Shared app state — created early so the menu bar icon can display
    /// status before services are fully initialized.
    let appState = AppState()

    /// Logger for startup and lifecycle events.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "AppDelegate"
    )

    /// Manages crash detection and recovery across launches.
    private let crashRecoveryManager = CrashRecoveryManager()

    /// Workspace observer token for bringing the window forward after System Settings closes.
    private var systemSettingsObserver: NSObjectProtocol?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("EmberHearth starting — version \(AppVersion.displayString, privacy: .public)")

        // Configure as an accessory app (menu bar only, no Dock icon).
        NSApp.setActivationPolicy(.accessory)

        // Step 1: Set up the menu bar icon immediately so it's always visible.
        let controller = StatusBarController(appState: appState)
        statusBarController = controller
        controller.setup()

        // Observe System Settings deactivation so we can reclaim focus after the
        // user grants a permission and closes System Settings. For .accessory apps,
        // applicationDidBecomeActive never fires on its own in this scenario.
        systemSettingsObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.systempreferences" else { return }
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
            self?.logger.debug("Reclaimed focus after System Settings closed")
        }

        // Step 2: Check for crash recovery before touching any state.
        checkForCrashRecovery()

        // Step 3: Synchronize launch-at-login with user preference.
        LaunchAtLoginManager.shared.synchronize()

        // Step 4: If onboarding isn't complete, let the SwiftUI view handle it.
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        guard hasCompletedOnboarding else {
            logger.info("Onboarding not complete — SwiftUI will present onboarding flow")
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Step 5: Load API key from Keychain.
        guard let apiKey = loadAPIKey() else {
            logger.warning("No API key in Keychain — SwiftUI will present onboarding flow")
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Step 6: Initialize all services and start the coordinator.
        startServices(apiKey: apiKey)
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("EmberHearth shutting down...")

        services?.shutdown()
        statusBarController?.teardown()

        if let observer = systemSettingsObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

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

        let container: ServiceContainer
        do {
            container = try ServiceContainer.initialize(apiKey: apiKey, appState: appState)
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

        do {
            try container.start()
        } catch let error as ChatDatabaseError {
            logger.warning("iMessage watcher failed to start: \(error.localizedDescription, privacy: .public)")
            appState.addError(.chatDbInaccessible)
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
            Task { [weak self] in
                guard let self else { return }
                let result = await self.crashRecoveryManager.performRecovery(appState: self.appState)
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
            NSApp.activate(ignoringOtherApps: true)

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
