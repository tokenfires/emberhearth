// EmberHearthApp.swift
// EmberHearth
//
// Main entry point for the EmberHearth macOS application.
// Uses SwiftUI App lifecycle with NSApplicationDelegateAdaptor
// for system-level integration (menu bar, launch agent, etc.).

import SwiftUI

@main
struct EmberHearthApp: App {

    /// Bridge to AppDelegate for system integration (menu bar, notifications, etc.)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 400, minHeight: 300)
                .frame(idealWidth: 500, idealHeight: 400)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 500, height: 400)
    }
}
