// EmberHearthApp.swift
// EmberHearth
//
// Main entry point for the EmberHearth macOS application.
// Uses SwiftUI App lifecycle with NSApplicationDelegateAdaptor
// for system-level integration (menu bar, launch agent, etc.).

import SwiftUI
import EmberHearthCore

@main
struct EmberHearthApp: App {

    /// Bridge to AppDelegate for system integration (menu bar, notifications, etc.)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 500)
                .frame(idealWidth: 700, idealHeight: 550)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 700, height: 550)
    }
}
