// AppDelegate.swift
// EmberHearth
//
// NSApplicationDelegate for system-level integration.
// Manages app lifecycle events, menu bar presence,
// and other system hooks that SwiftUI doesn't directly support.

import AppKit
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// The shared app state — single source of truth for the application's condition.
    let appState = AppState()

    /// The menu bar controller that manages the NSStatusItem and dropdown menu.
    private var statusBarController: StatusBarController?

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the app as an accessory application.
        // LSUIElement is set in Info.plist, but we also set the activation policy
        // programmatically to ensure the app runs without a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        // Create the status bar controller with the shared app state
        let controller = StatusBarController(appState: appState)
        statusBarController = controller
        controller.setup()

        // Synchronize launch-at-login state with user preference.
        LaunchAtLoginManager.shared.synchronize()

        // Transition from .starting to .ready once subsystems are up.
        // In production this will be driven by actual health checks.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            self?.appState.transition(to: .ready)
        }

        // Bring the main window to front on first launch
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.teardown()
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
