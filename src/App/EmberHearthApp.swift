// EmberHearthApp.swift
// EmberHearth
//
// Main entry point for the EmberHearth macOS application.

import SwiftUI

@main
struct EmberHearthApp: App {
    var body: some Scene {
        WindowGroup {
            Text("EmberHearth")
                .frame(width: 300, height: 200)
                .accessibilityLabel("EmberHearth application window")
        }
    }
}
