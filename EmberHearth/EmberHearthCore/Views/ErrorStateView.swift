// ErrorStateView.swift
// EmberHearth
//
// Reusable full-area error display for major error states.

import SwiftUI

/// A reusable error display component that presents a friendly,
/// accessible error message with an icon, title, description,
/// and optional action button.
///
/// Used in the main app window and settings when a critical error
/// prevents normal operation. Designed following Apple HIG for
/// empty/error states.
///
/// ## Accessibility
/// - Full VoiceOver support with grouped elements
/// - Dynamic Type support for all text
/// - Keyboard navigation for action button
/// - High contrast mode support
///
/// ## Usage
/// ```swift
/// ErrorStateView(
///     error: .noAPIKey,
///     onAction: { /* open settings */ },
///     onDismiss: nil
/// )
/// ```
struct ErrorStateView: View {

    /// The error to display.
    let error: AppError

    /// Called when the user taps the action button (if the error has one).
    let onAction: (() -> Void)?

    /// Called when the user dismisses the error. Nil if not dismissible.
    let onDismiss: (() -> Void)?

    /// Whether to show the auto-retry indicator for transient errors.
    @State private var showingRetryIndicator = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: error.iconName)
                .font(.system(size: 48))
                .foregroundColor(error.iconColor)
                .accessibilityHidden(true)

            Text(error.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            Text(error.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)

            if error.isTransient && showingRetryIndicator {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking automatically...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Checking automatically")
            }

            if let actionLabel = error.actionLabel, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .padding(.top, 8)
            }

            if let onDismiss = onDismiss {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                    .keyboardShortcut(.cancelAction)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(error.title). \(error.description)")
        .onAppear {
            if error.isTransient {
                withAnimation(.easeIn.delay(1.0)) {
                    showingRetryIndicator = true
                }
            }
        }
    }
}
