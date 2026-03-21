// SettingsView.swift
// EmberHearth
//
// The main Settings window, using macOS native Settings scene with tabs.

import SwiftUI

/// Identifies the settings tabs for state management.
enum SettingsTab: Hashable {
    case general
    case api
    case about
}

/// The main Settings window for EmberHearth.
///
/// Uses SwiftUI's `Settings` scene to present a standard macOS
/// settings window with tab navigation. Opened via:
/// - Menu bar > "Settings..."
/// - Standard Cmd+, keyboard shortcut (handled automatically by Settings scene)
///
/// ## Accessibility
/// - Each tab has a VoiceOver label with its name
/// - Tab icons use SF Symbols for clarity
/// - All content within tabs is fully accessible
struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            APISettingsView()
                .tabItem {
                    Label("API", systemImage: "key.fill")
                }
                .tag(SettingsTab.api)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 480, maxWidth: 480, minHeight: 320)
    }
}
