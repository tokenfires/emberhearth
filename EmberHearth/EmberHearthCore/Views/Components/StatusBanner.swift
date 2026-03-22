// StatusBanner.swift
// EmberHearth
//
// Dismissible banner for transient status messages.

import SwiftUI

/// The severity level of a status banner, which determines its color.
enum BannerSeverity {
    /// Warning: something needs attention but is not critical (yellow).
    case warning
    /// Error: something failed (red).
    case error
    /// Recovery: a previous error has been resolved (green).
    case recovery
    /// Info: neutral informational message (blue).
    case info

    /// The background color for this severity level.
    var backgroundColor: Color {
        switch self {
        case .warning: return .yellow.opacity(0.15)
        case .error: return .red.opacity(0.15)
        case .recovery: return .green.opacity(0.15)
        case .info: return .blue.opacity(0.15)
        }
    }

    /// The accent/icon color for this severity level.
    var accentColor: Color {
        switch self {
        case .warning: return .orange
        case .error: return .red
        case .recovery: return .green
        case .info: return .blue
        }
    }

    /// The SF Symbol for this severity level.
    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .recovery: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }

    /// The accessibility label prefix for VoiceOver announcements.
    var accessibilityPrefix: String {
        switch self {
        case .warning: return "Warning"
        case .error: return "Error"
        case .recovery: return "Success"
        case .info: return "Info"
        }
    }
}

/// A small banner that slides in from the top of the window for
/// non-critical, transient status messages.
///
/// Features:
/// - Auto-dismisses after 5 seconds (configurable)
/// - Can be manually dismissed by the user
/// - Color-coded by severity: yellow (warning), red (error), green (recovery), blue (info)
/// - Slides in and out with animation
///
/// ## Accessibility
/// - Announced to VoiceOver as a live region
/// - Dismiss button has clear accessibility label
/// - Dynamic Type support for all text
///
/// ## Usage
/// ```swift
/// StatusBanner(
///     message: "Connection restored!",
///     severity: .recovery,
///     isPresented: $showBanner
/// )
/// ```
struct StatusBanner: View {

    /// The message to display in the banner.
    let message: String

    /// The severity level, which determines the color coding.
    let severity: BannerSeverity

    /// Controls whether the banner is shown. Set to false to dismiss.
    @Binding var isPresented: Bool

    /// How long (in seconds) before the banner auto-dismisses.
    /// Set to nil to disable auto-dismiss.
    var autoDismissAfter: TimeInterval? = 5.0

    /// Timer task for auto-dismiss.
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        if isPresented {
            HStack(spacing: 10) {
                Image(systemName: severity.iconName)
                    .foregroundColor(severity.accentColor)
                    .font(.body)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss notification")
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(severity.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(severity.accentColor.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(severity.accessibilityPrefix): \(message)")
            .accessibilityAddTraits(.isStaticText)
            .onAppear {
                startAutoDismiss()
            }
            .onDisappear {
                dismissTask?.cancel()
            }
        }
    }

    // MARK: - Private Methods

    /// Starts the auto-dismiss timer if configured.
    private func startAutoDismiss() {
        guard let delay = autoDismissAfter else { return }
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    /// Dismisses the banner with animation.
    private func dismiss() {
        withAnimation(.easeOut(duration: 0.3)) {
            isPresented = false
        }
        dismissTask?.cancel()
    }
}
