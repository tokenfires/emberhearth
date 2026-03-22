// ContentView.swift
// EmberHearth
//
// Root content view for the EmberHearth main window.
// Routes between onboarding and the main status view based on whether
// critical prerequisites are met: API key in Keychain, Full Disk Access,
// and Messages Automation permission.

import SwiftUI

public struct ContentView: View {

    @Environment(\.colorScheme) private var colorScheme

    /// Whether all prerequisites for running are met.
    @State private var isReady: Bool = false

    /// Whether we've finished the initial prerequisite check (avoids flash of wrong view).
    @State private var hasChecked: Bool = false

    /// Mirrors the UserDefaults flag so SwiftUI reacts when it changes
    /// (e.g. when "Setup Required" resets it from the menu bar).
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if !hasChecked {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isReady {
                mainStatusView
            } else {
                OnboardingContainerView(onComplete: {
                    checkPrerequisites()
                })
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            checkPrerequisites()
        }
        .onChange(of: hasCompletedOnboarding) { _, _ in
            checkPrerequisites()
        }
    }

    // MARK: - Prerequisite Check

    /// Checks that onboarding is complete, the API key exists, AND critical
    /// permissions are granted. If any are missing, routes to onboarding.
    private func checkPrerequisites() {
        guard hasCompletedOnboarding else {
            isReady = false
            hasChecked = true
            return
        }

        let keychain = KeychainManager()
        let hasKey: Bool
        do {
            if let key = try keychain.retrieve(for: .claude), !key.isEmpty {
                hasKey = true
            } else {
                hasKey = false
            }
        } catch {
            hasKey = false
        }

        let permissionManager = PermissionManager()
        let hasFDA = permissionManager.checkFullDiskAccess()
        let hasAutomation = permissionManager.checkAutomation()

        isReady = hasKey && hasFDA && hasAutomation

        // If permissions were revoked after onboarding, reset the flag
        // so the user goes through the flow again.
        if !isReady {
            hasCompletedOnboarding = false
        } else {
            // Tell AppDelegate to start services if they aren't running yet.
            // Uses NotificationCenter because SwiftUI's @NSApplicationDelegateAdaptor
            // wraps the delegate in a proxy that can't be cast to AppDelegate.
            NotificationCenter.default.post(name: .emberHearthOnboardingCompleted, object: nil)
        }

        hasChecked = true
    }

    // MARK: - Main Status View

    private var mainStatusView: some View {
        VStack(spacing: 20) {
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(flameGradient)
                .accessibilityLabel("EmberHearth flame icon")

            Text("EmberHearth")
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Your personal AI assistant")
                .font(.title3)
                .foregroundStyle(.secondary)

            Divider()
                .frame(maxWidth: 200)

            HStack(spacing: 8) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Status indicator: running")

                Text("Running")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("EmberHearth status: running")
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Styling

    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.orange, .red]
                : [.orange, .red.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}
#endif
