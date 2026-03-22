// WelcomeView.swift
// EmberHearth
//
// Welcome screen shown as the first step of onboarding.
// Introduces EmberHearth with security messaging and a "Get Started" button.

import SwiftUI

/// The welcome screen shown when a user launches EmberHearth for the first time.
///
/// Design principles (from onboarding-ux.md):
/// - Warm, not corporate
/// - Set expectations: time estimate, what's needed
/// - Three-layer security explanation (Layer 1: one-sentence reassurance)
/// - The "grandmother test": keep it simple enough for anyone
///
/// Accessibility Compliance (Task 0604):
/// - [x] VoiceOver: Flame icon labeled, heading has .isHeader trait, security bullets grouped, button has label+hint
/// - [x] Dynamic Type: All text uses semantic font styles (.largeTitle, .title3, .body, .callout, .headline)
/// - [x] Keyboard: Primary action has .keyboardShortcut(.defaultAction), Tab navigates to button
/// - [x] Color: System colors used (.primary, .secondary, .accentColor), no information-only color
/// - [x] Reduce Motion: No animations in this view; reduceMotion read for container transitions
/// - [x] UI Testing: Get Started button has accessibilityIdentifier
struct WelcomeView: View {

    // MARK: - Properties

    /// Callback invoked when the user taps "Get Started".
    var onContinue: () -> Void

    /// Respect the user's Reduce Motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Flame icon
            Image(systemName: "flame.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .accessibilityLabel("EmberHearth flame icon")
                .accessibilityAddTraits(.isImage)
                .padding(.bottom, 16)

            // Heading
            Text("Welcome to EmberHearth")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 8)

            // Subtitle
            Text("Your personal AI assistant, right in iMessage")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            // Security bullet points
            VStack(alignment: .leading, spacing: 16) {
                securityBullet(
                    icon: "lock.shield",
                    text: "Your data stays on your Mac"
                )
                securityBullet(
                    icon: "eye.slash",
                    text: "We never see your conversations"
                )
                securityBullet(
                    icon: "hand.raised",
                    text: "You control what Ember remembers"
                )
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)

            // Time estimate
            Text("Setup takes about 5 minutes")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 24)

            // Get Started button
            Button(action: onContinue) {
                Text("Get Started")
                    .font(.headline)
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .accessibilityLabel("Get Started")
            .accessibilityHint("Begins the EmberHearth setup process")
            .accessibilityIdentifier("onboarding_welcome_getStartedButton")

            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Security Bullet Point

    /// A single security bullet point with an SF Symbol icon and text.
    private func securityBullet(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, alignment: .center)
                .accessibilityHidden(true)

            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }
}
