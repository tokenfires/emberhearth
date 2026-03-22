// EmberHearthApp.swift
// EmberHearth
//
// Main entry point for the EmberHearth macOS application.
// Uses SwiftUI App lifecycle with NSApplicationDelegateAdaptor
// for system-level integration (menu bar, launch agent, etc.).

import SwiftUI

@main
struct EmberHearthApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .frame(minWidth: 400, minHeight: 300)
            } else {
                OnboardingContainerView(onComplete: {
                    appDelegate.onboardingCompleted()
                })
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 600, height: 500)
    }
}
