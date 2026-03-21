// OnboardingContainerView.swift
// EmberHearth
//
// Multi-step onboarding wizard container. Manages navigation between
// onboarding steps and displays a progress bar.

import SwiftUI

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
/// Accessibility:
/// - Progress bar has a VoiceOver label announcing "Step X of 5"
/// - All navigation uses keyboard-accessible controls
/// - Back navigation is available via a button or Escape key
struct OnboardingContainerView: View {

    // MARK: - State

    /// The current onboarding step.
    @State private var currentStep: OnboardingStep = .welcome

    /// Whether onboarding is complete and the main app should be shown.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    /// The permission manager shared across onboarding views.
    @StateObject private var permissionManager = PermissionManager()

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
                    // Placeholder — will be implemented in task 0602
                    placeholderView(title: "Phone Number Setup", step: .phoneConfig)

                case .test:
                    // Placeholder — will be implemented in task 0603
                    placeholderView(title: "First Message Test", step: .test)
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
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            .frame(height: 6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Onboarding progress")
            .accessibilityValue("Step \(currentStep.rawValue + 1) of \(OnboardingStep.totalSteps)")
        }
    }

    // MARK: - Placeholder Views

    /// A placeholder view for steps not yet implemented (tasks 0601-0603).
    private func placeholderView(title: String, step: OnboardingStep) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Text(title)
                .font(.title)
                .fontWeight(.bold)

            Text("This step will be implemented in a future task.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Back") {
                    goBack()
                }
                .keyboardShortcut(.cancelAction)
                .accessibilityLabel("Go back to previous step")
                .accessibilityHint("Returns to the previous onboarding step")

                if step == .test {
                    Button("Finish Onboarding") {
                        completeOnboarding()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Finish onboarding")
                    .accessibilityHint("Completes setup and opens the main app")
                } else {
                    Button("Continue") {
                        advanceToNextStep()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Continue to next step")
                    .accessibilityHint("Advances to the next onboarding step")
                }
            }

            Spacer()
        }
        .padding(40)
    }

    // MARK: - Navigation

    /// Advances to a specific onboarding step.
    private func advanceToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
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
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    /// Goes back one step.
    private func goBack() {
        guard let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        goBackToStep(previousStep)
    }

    /// Marks onboarding as complete and invokes the completion callback.
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        onComplete?()
    }
}
