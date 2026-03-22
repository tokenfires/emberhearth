// OnboardingContainerView.swift
// EmberHearth
//
// Multi-step onboarding wizard container. Manages navigation between
// onboarding steps and displays a progress bar.

import SwiftUI
import os

extension Notification.Name {
    /// Posted when the onboarding flow completes. AppDelegate observes this
    /// to start services, since SwiftUI's @NSApplicationDelegateAdaptor wraps
    /// the delegate in a proxy that can't be cast to AppDelegate directly.
    static let emberHearthOnboardingCompleted = Notification.Name("emberHearthOnboardingCompleted")
}

// MARK: - Onboarding Step Enum

/// The sequential steps in the onboarding flow.
enum OnboardingStep: Int, CaseIterable, Comparable {
    case welcome = 0
    case permissions = 1
    case apiKey = 2
    case phoneConfig = 3
    case test = 4

    /// Human-readable title for each step.
    var title: String {
        switch self {
        case .welcome: return "Welcome"
        case .permissions: return "Permissions"
        case .apiKey: return "API Key"
        case .phoneConfig: return "Phone Number"
        case .test: return "Test"
        }
    }

    /// Total number of steps (for progress calculation).
    static var totalSteps: Int { allCases.count }

    /// Progress fraction (0.0 to 1.0) for this step.
    var progressFraction: Double {
        return Double(rawValue + 1) / Double(Self.totalSteps)
    }

    static func < (lhs: OnboardingStep, rhs: OnboardingStep) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Onboarding Container View

/// The top-level container for the onboarding flow.
///
/// Displays a progress bar at the top, manages navigation between steps,
/// and stores onboarding completion state in UserDefaults.
///
/// Accessibility Compliance (Task 0604):
/// - [x] VoiceOver: Progress bar labeled "Onboarding progress", value "Step X of 5"
/// - [x] Dynamic Type: All text uses semantic font styles, layout adapts
/// - [x] Keyboard: Escape key navigates back via onExitCommand
/// - [x] Color: System colors used, progress bar uses accentColor
/// - [x] Reduce Motion: Step transitions and progress bar animation respect reduceMotion
/// - [x] UI Testing: Progress bar has accessibilityIdentifier
struct OnboardingContainerView: View {

    // MARK: - State

    /// The current onboarding step.
    @State private var currentStep: OnboardingStep = .welcome

    /// Whether onboarding is complete and the main app should be shown.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    /// The permission manager shared across onboarding views.
    @StateObject private var permissionManager = PermissionManager()

    /// Respect the user's Reduce Motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Callback invoked when onboarding is finished.
    var onComplete: (() -> Void)?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar (not shown on welcome step for cleaner first impression)
            if currentStep != .welcome {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }

            // Step content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onContinue: { advanceToStep(.permissions) })

                case .permissions:
                    PermissionsView(
                        permissionManager: permissionManager,
                        onContinue: { advanceToStep(.apiKey) },
                        onBack: { goBackToStep(.welcome) }
                    )

                case .apiKey:
                    APIKeyEntryView(
                        onContinue: { advanceToStep(.phoneConfig) },
                        onBack: { goBackToStep(.permissions) }
                    )

                case .phoneConfig:
                    PhoneConfigView(
                        onContinue: { advanceToStep(.test) },
                        onBack: { goBackToStep(.apiKey) }
                    )

                case .test:
                    FirstMessageTestView(
                        onComplete: { completeOnboarding() },
                        onBack: { goBackToStep(.phoneConfig) }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onExitCommand {
            if currentStep != .welcome {
                goBack()
            }
        }
    }

    // MARK: - Progress Bar

    /// A horizontal progress bar showing the current step out of total steps.
    private var progressBar: some View {
        VStack(spacing: 4) {
            // Step indicator text
            Text("Step \(currentStep.rawValue + 1) of \(OnboardingStep.totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Progress track
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Filled progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width * currentStep.progressFraction,
                            height: 6
                        )
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("Step \(currentStep.rawValue + 1) of \(OnboardingStep.totalSteps)")
            .accessibilityIdentifier("onboarding_progressBar")
        }
    }

    // MARK: - Navigation

    /// Advances to a specific onboarding step.
    private func advanceToStep(_ step: OnboardingStep) {
        if reduceMotion {
            currentStep = step
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = step
            }
        }
    }

    /// Advances to the next sequential step.
    private func advanceToNextStep() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else {
            completeOnboarding()
            return
        }
        advanceToStep(nextStep)
    }

    /// Goes back to a specific step.
    private func goBackToStep(_ step: OnboardingStep) {
        if reduceMotion {
            currentStep = step
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = step
            }
        }
    }

    /// Goes back one step.
    private func goBack() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        goBackToStep(previousStep)
    }

    /// Marks onboarding as complete and starts services.
    private func completeOnboarding() {
        hasCompletedOnboarding = true

        // Post a notification that AppDelegate observes to start services.
        // We can't cast NSApp.delegate to AppDelegate because SwiftUI's
        // @NSApplicationDelegateAdaptor wraps it in an internal proxy type.
        NotificationCenter.default.post(name: .emberHearthOnboardingCompleted, object: nil)

        onComplete?()
    }
}
