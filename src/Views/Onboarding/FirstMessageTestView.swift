// FirstMessageTestView.swift
// EmberHearth
//
// First message test screen — the final step of onboarding.
// Guides the user to send their first iMessage to Ember and
// displays real-time pipeline status to verify end-to-end functionality.

import SwiftUI
import os

// MARK: - Test Status

/// The possible states of the first message test.
enum FirstMessageTestStatus: Equatable {
    /// Waiting for the user to send a message.
    case waitingForMessage
    /// A message has been received from the user.
    case messageReceived
    /// The message is being processed by the LLM.
    case processing
    /// A response has been sent successfully.
    case responseSent
    /// The test failed with a reason.
    case failed(reason: String)
    /// The test timed out.
    case timedOut

    /// Human-readable description of the current status.
    var description: String {
        switch self {
        case .waitingForMessage: return "Watching for messages..."
        case .messageReceived: return "Message received!"
        case .processing: return "Thinking..."
        case .responseSent: return "Response sent!"
        case .failed(let reason): return "Something went wrong: \(reason)"
        case .timedOut: return "We didn't detect a message. Let's troubleshoot."
        }
    }

    /// SF Symbol for each status.
    var sfSymbol: String {
        switch self {
        case .waitingForMessage: return "antenna.radiowaves.left.and.right"
        case .messageReceived: return "envelope.open.fill"
        case .processing: return "brain"
        case .responseSent: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .timedOut: return "clock.badge.exclamationmark"
        }
    }

    /// Color for each status.
    var color: Color {
        switch self {
        case .waitingForMessage: return .blue
        case .messageReceived: return .orange
        case .processing: return .purple
        case .responseSent: return .green
        case .failed: return .red
        case .timedOut: return .yellow
        }
    }

    /// Whether this is a final state (test complete or failed).
    var isFinal: Bool {
        switch self {
        case .responseSent, .failed, .timedOut: return true
        default: return false
        }
    }

    /// Whether the test was successful.
    var isSuccess: Bool {
        if case .responseSent = self { return true }
        return false
    }
}

// MARK: - View Model

/// View model for the first message test screen.
///
/// Manages:
/// - Test pipeline status tracking
/// - Timeout handling (60 seconds)
/// - Retry logic
/// - Message content display on success
@MainActor
final class FirstMessageTestViewModel: ObservableObject {

    // MARK: - Published Properties

    /// The current test status.
    @Published var testStatus: FirstMessageTestStatus = .waitingForMessage

    /// The remaining seconds on the timeout timer.
    @Published var timeoutRemaining: Int = 60

    /// The first message sent by the user (displayed on success).
    @Published var userMessage: String?

    /// Ember's response to the first message (displayed on success).
    @Published var emberResponse: String?

    // MARK: - Private Properties

    /// The timeout timer.
    private var timeoutTimer: Timer?

    /// Whether the test has been started.
    private var isRunning: Bool = false

    /// Logger for test events.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "FirstMessageTest"
    )

    /// The timeout duration in seconds.
    static let timeoutDuration: Int = 60

    // MARK: - Dependencies

    /// Phone number filter for reading configured numbers.
    private let phoneNumberFilter: PhoneNumberFilter

    // MARK: - Initialization

    init(phoneNumberFilter: PhoneNumberFilter = PhoneNumberFilter()) {
        self.phoneNumberFilter = phoneNumberFilter
    }

    /// The configured phone numbers from the previous step.
    var configuredPhoneNumbers: [String] {
        phoneNumberFilter.getAllowedNumbers()
    }

    /// A formatted display of the first configured phone number.
    var displayPhoneNumber: String {
        guard let firstNumber = configuredPhoneNumbers.first else {
            return "your configured number"
        }
        return formatForDisplay(firstNumber)
    }

    // MARK: - Test Lifecycle

    /// Starts the first message test.
    ///
    /// Begins watching for messages and starts the timeout timer.
    func startTest() {
        guard !isRunning else { return }
        isRunning = true
        testStatus = .waitingForMessage
        timeoutRemaining = Self.timeoutDuration
        Self.logger.info("First message test started")

        startMessagePipeline()
        startTimeoutTimer()
    }

    /// Stops the test and cleans up timers.
    func stopTest() {
        isRunning = false
        stopTimeoutTimer()
        Self.logger.info("First message test stopped")
    }

    /// Retries the test from the beginning.
    func retryTest() {
        stopTest()
        userMessage = nil
        emberResponse = nil
        startTest()
    }

    // MARK: - Message Pipeline

    /// Starts the message watching pipeline.
    ///
    /// In the full implementation, this connects to MessageCoordinator.
    /// For now, this sets up the pipeline and subscribes to status updates.
    private func startMessagePipeline() {
        // TODO: When MessageCoordinator is available:
        // MessageCoordinator.shared.start()
        // Subscribe to MessageCoordinator.shared.statusPublisher
        //
        // For now, the test relies on the message pipeline already being
        // initialized by prior onboarding steps. The pipeline will
        // automatically process incoming messages and this view will
        // observe the status.

        Self.logger.info("Message pipeline started for first message test")
    }

    /// Called when a message is received from the user.
    ///
    /// This method should be called by the MessageCoordinator delegate
    /// or a Combine subscriber when a new message arrives.
    ///
    /// - Parameter message: The text of the received message.
    func onMessageReceived(_ message: String) {
        guard isRunning else { return }
        userMessage = message
        testStatus = .messageReceived
        Self.logger.info("First message received")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.testStatus = .processing
        }
    }

    /// Called when Ember's response has been sent.
    ///
    /// - Parameter response: The text of Ember's response.
    func onResponseSent(_ response: String) {
        guard isRunning else { return }
        emberResponse = response
        testStatus = .responseSent
        stopTimeoutTimer()
        Self.logger.info("First message test succeeded — response sent")
    }

    /// Called when an error occurs in the pipeline.
    ///
    /// - Parameter error: Description of what went wrong.
    func onPipelineError(_ error: String) {
        guard isRunning else { return }
        testStatus = .failed(reason: error)
        stopTimeoutTimer()
        Self.logger.error("First message test failed: pipeline error")
    }

    // MARK: - Timeout Timer

    /// Starts a countdown timer that fires every second.
    private func startTimeoutTimer() {
        stopTimeoutTimer()
        timeoutRemaining = Self.timeoutDuration

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.timeoutRemaining -= 1

                if self.timeoutRemaining <= 0 {
                    self.testStatus = .timedOut
                    self.stopTimeoutTimer()
                    Self.logger.warning("First message test timed out")
                }
            }
        }
    }

    /// Stops the timeout timer.
    private func stopTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }

    // MARK: - Formatting

    /// Formats a normalized E.164 number for display.
    func formatForDisplay(_ normalized: String) -> String {
        let digits = normalized.filter { $0.isNumber }
        if digits.count == 11 && digits.hasPrefix("1") {
            let areaCode = digits.dropFirst().prefix(3)
            let exchange = digits.dropFirst(4).prefix(3)
            let subscriber = digits.dropFirst(7)
            return "+1 (\(areaCode)) \(exchange)-\(subscriber)"
        }
        return normalized
    }

    deinit {
        timeoutTimer?.invalidate()
    }
}

// MARK: - First Message Test View

/// The first message test screen — the final onboarding step.
///
/// Guides the user through:
/// 1. Opening Messages on their iPhone or Mac
/// 2. Sending a text to their configured number
/// 3. Waiting for Ember to respond
/// 4. Celebrating success (or troubleshooting failure)
///
/// Accessibility:
/// - All status changes are announced to VoiceOver
/// - Step-by-step instructions are readable
/// - Buttons have descriptive labels and hints
/// - Dynamic Type support throughout
struct FirstMessageTestView: View {

    // MARK: - Properties

    @StateObject private var viewModel = FirstMessageTestViewModel()

    /// Callback when onboarding is complete (success or skip).
    var onComplete: () -> Void

    /// Callback when the user taps Back.
    var onBack: () -> Void

    /// Respect the user's Reduce Motion preference.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Heading
                    VStack(spacing: 8) {
                        Text("Let's test it!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityAddTraits(.isHeader)

                        Text("Send Ember a message to make sure everything works.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Step-by-step instructions (shown before success)
                    if !viewModel.testStatus.isSuccess {
                        instructionSteps
                    }

                    // Status indicator
                    statusIndicator

                    // Success display
                    if viewModel.testStatus.isSuccess {
                        successDisplay
                    }

                    // Troubleshooting (shown on failure/timeout)
                    if case .failed = viewModel.testStatus {
                        troubleshootingTips
                    }
                    if case .timedOut = viewModel.testStatus {
                        troubleshootingTips
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }

            Divider()

            // Navigation buttons
            navigationButtons
        }
        .onAppear {
            viewModel.startTest()
        }
        .onDisappear {
            viewModel.stopTest()
        }
        .onChange(of: viewModel.testStatus) { newValue in
            announceStatusChange(newValue)
        }
    }

    // MARK: - Instruction Steps

    /// Step-by-step instructions for sending the first message.
    private var instructionSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            instructionStep(
                number: 1,
                text: "Open Messages on your iPhone or Mac",
                isComplete: false
            )
            instructionStep(
                number: 2,
                text: "Send a text to \(viewModel.displayPhoneNumber)",
                isComplete: false
            )
            instructionStep(
                number: 3,
                text: "Say something like \"Hey Ember, are you there?\"",
                isComplete: viewModel.testStatus != .waitingForMessage
            )
            instructionStep(
                number: 4,
                text: "Wait for Ember to respond...",
                isComplete: viewModel.testStatus.isSuccess
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }

    /// A single instruction step with a number and checkmark on completion.
    private func instructionStep(number: Int, text: String, isComplete: Bool) -> some View {
        HStack(spacing: 12) {
            if isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                    .accessibilityHidden(true)
            } else {
                Text("\(number)")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accentColor))
                    .accessibilityHidden(true)
            }

            Text(text)
                .font(.body)
                .foregroundStyle(isComplete ? .secondary : .primary)
                .strikethrough(isComplete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number): \(text)\(isComplete ? ", completed" : "")")
    }

    // MARK: - Status Indicator

    /// Real-time status display showing what the pipeline is doing.
    private var statusIndicator: some View {
        HStack(spacing: 12) {
            if viewModel.testStatus == .waitingForMessage || viewModel.testStatus == .processing {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Image(systemName: viewModel.testStatus.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(viewModel.testStatus.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.testStatus.description)
                    .font(.headline)
                    .foregroundStyle(viewModel.testStatus.color)

                if viewModel.testStatus == .waitingForMessage {
                    Text("Timeout in \(viewModel.timeoutRemaining) seconds")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(viewModel.testStatus.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(viewModel.testStatus.color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(viewModel.testStatus.description)
        .accessibilityIdentifier("testStatusIndicator")
    }

    // MARK: - Success Display

    /// Shows the first exchange on success with a celebration.
    private var successDisplay: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
                .scaleEffect(reduceMotion ? 1.0 : 1.0)

            Text("Ember is ready!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.green)

            if let userMsg = viewModel.userMessage, let emberReply = viewModel.emberResponse {
                VStack(alignment: .leading, spacing: 12) {
                    // User message bubble (right-aligned)
                    HStack {
                        Spacer()
                        Text(userMsg)
                            .font(.body)
                            .padding(12)
                            .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("You said: \(userMsg)")

                    // Ember response bubble (left-aligned)
                    HStack {
                        Text(emberReply)
                            .font(.body)
                            .padding(12)
                            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .accessibilityLabel("Ember replied: \(emberReply)")
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.03))
                )
            }
        }
    }

    // MARK: - Troubleshooting

    /// Troubleshooting tips shown when the test fails or times out.
    private var troubleshootingTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Troubleshooting")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            troubleshootingTip(
                icon: "message.fill",
                text: "Make sure Messages is open and signed into iMessage"
            )
            troubleshootingTip(
                icon: "lock.open.fill",
                text: "Check that Full Disk Access is enabled in System Settings"
            )
            troubleshootingTip(
                icon: "phone.fill",
                text: "Try sending from the phone number you configured (\(viewModel.displayPhoneNumber))"
            )
            troubleshootingTip(
                icon: "wifi",
                text: "Make sure you're connected to the internet"
            )
            troubleshootingTip(
                icon: "key.fill",
                text: "Verify your API key is still valid in Settings"
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.yellow.opacity(0.2), lineWidth: 1)
        )
    }

    /// A single troubleshooting tip with an icon.
    private func troubleshootingTip(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    // MARK: - Navigation

    /// Navigation buttons at the bottom.
    private var navigationButtons: some View {
        HStack {
            Button("Back") {
                viewModel.stopTest()
                onBack()
            }
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Go back")
            .accessibilityHint("Returns to phone number configuration")

            Spacer()

            if viewModel.testStatus.isFinal && !viewModel.testStatus.isSuccess {
                Button("Retry") {
                    viewModel.retryTest()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Retry the test")
                .accessibilityHint("Restarts the first message test from the beginning")
                .accessibilityIdentifier("retryTestButton")
            }

            if viewModel.testStatus.isFinal {
                Button(viewModel.testStatus.isSuccess ? "Finish Setup" : "Skip Test") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    viewModel.stopTest()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel(viewModel.testStatus.isSuccess ? "Finish setup" : "Skip test")
                .accessibilityHint(
                    viewModel.testStatus.isSuccess
                    ? "Completes onboarding and opens the EmberHearth app"
                    : "Skips the test and completes onboarding. You can test later."
                )
                .accessibilityIdentifier("finishSetupButton")
            } else {
                Button("Skip Test") {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    viewModel.stopTest()
                    onComplete()
                }
                .foregroundStyle(.secondary)
                .accessibilityLabel("Skip test")
                .accessibilityHint("Skips the first message test. You can test Ember later by sending a message.")
                .accessibilityIdentifier("skipTestButton")
            }
        }
        .padding(16)
    }

    // MARK: - VoiceOver

    /// Announces status changes to VoiceOver.
    private func announceStatusChange(_ status: FirstMessageTestStatus) {
        let message: String
        switch status {
        case .waitingForMessage:
            message = "Watching for messages. Send a text to Ember."
        case .messageReceived:
            message = "Message received from you."
        case .processing:
            message = "Ember is thinking about your message."
        case .responseSent:
            message = "Ember has responded! Setup is complete."
        case .failed(let reason):
            message = "Test failed: \(reason). Check troubleshooting tips below."
        case .timedOut:
            message = "Test timed out. Check troubleshooting tips below."
        }

        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.high]
        )
    }
}
