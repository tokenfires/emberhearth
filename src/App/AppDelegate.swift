// AppDelegate.swift
// EmberHearth
//
// NSApplicationDelegate for system-level integration.
// Manages app lifecycle events, menu bar presence (future),
// and other system hooks that SwiftUI doesn't directly support.

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure the app as an accessory application.
        // LSUIElement is set in Info.plist, but we also set the activation policy
        // programmatically to ensure the app runs without a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        // Bring the main window to front on first launch
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean shutdown: flush pending writes, close database connections.
        // Placeholder for future cleanup logic.
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
