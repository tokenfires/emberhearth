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

        // Synchronize launch-at-login state with user preference.
        // On first launch, this defaults to enabled.
        LaunchAtLoginManager.shared.synchronize()

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
