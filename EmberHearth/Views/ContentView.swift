// ContentView.swift
// EmberHearth
//
// Root content view for the EmberHearth main window.
// Displays a welcome/status screen. Will be replaced with
// settings and onboarding views in later milestones.

import SwiftUI

struct ContentView: View {

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
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
        .background(backgroundColor)
    }

    // MARK: - Styling

    /// Gradient for the flame icon, adapts to color scheme
    private var flameGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [.orange, .red]
                : [.orange, .red.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Background color that adapts to the system color scheme
    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(nsColor: .windowBackgroundColor)
            : Color(nsColor: .windowBackgroundColor)
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
