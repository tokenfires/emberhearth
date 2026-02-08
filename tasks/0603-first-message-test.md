# Task 0603: First Message Test View

**Milestone:** M7 - Onboarding
**Unit:** 7.4 - First Message Test (Verify End-to-End)
**Phase:** 3
**Depends On:** 0602 (PhoneConfigView integrated), 0504 (MessageCoordinator)
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, accessibility requirements
2. `docs/research/onboarding-ux.md` — Focus on Section 6: "First Message Success" (lines ~428-458) for the success screen design, and Section 10: "Handling Edge Cases" (lines ~627-702) for troubleshooting patterns
3. `src/Views/Onboarding/OnboardingContainerView.swift` — Read entirely; understand the `.test` placeholder that this view will replace, the `completeOnboarding()` method, and the `@AppStorage("hasCompletedOnboarding")` key
4. `src/Core/MessageCoordinator.swift` — If it exists from task 0504, read the delegate/publisher pattern for message pipeline status updates. If it does not exist yet, this view will use a simulated/mock pipeline for the test.

> **Context Budget Note:** onboarding-ux.md is ~920 lines. Focus only on Section 6 (lines ~428-458) and Section 10 (lines ~627-702). MessageCoordinator.swift may be large — focus on the public API for starting the watcher and subscribing to status updates.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are creating the First Message Test view for EmberHearth's onboarding flow. This is Step 5 (the final step) of the onboarding wizard — the "moment of truth" where the user sends their first iMessage to Ember and verifies the complete pipeline works end-to-end.

IMPORTANT RULES (from CLAUDE.md):
- Product display name: "EmberHearth"
- Swift files use PascalCase (e.g., FirstMessageTestView.swift)
- Security first: NEVER implement shell execution
- ALL UI must support VoiceOver, Dynamic Type, and keyboard navigation
- Follow Apple Human Interface Guidelines
- All source files go under src/, all test files go under tests/

PROJECT CONTEXT:
- This is a Swift Package Manager project with main target at path "src" and test target at path "tests"
- macOS 14.0+ deployment target
- No third-party dependencies — use only Apple frameworks
- MessageCoordinator from task 0504 should exist at src/Core/MessageCoordinator.swift
  - If it exists, it provides: `start()`, `stop()`, and publishes status updates
  - If it does NOT exist yet, this view will use a simulated test status publisher
- Phone numbers are stored in UserDefaults key "allowedPhoneNumbers" (from task 0602)
- OnboardingContainerView (from task 0600) has a `.test` step that currently shows a placeholder
- The `@AppStorage("hasCompletedOnboarding")` key marks onboarding as complete

WHAT YOU WILL CREATE:
1. src/Views/Onboarding/FirstMessageTestView.swift — The first message test UI
2. tests/FirstMessageTestViewModelTests.swift — Unit tests for the view model
3. Update src/Views/Onboarding/OnboardingContainerView.swift — Replace the `.test` placeholder

STEP 1: Create src/Views/Onboarding/FirstMessageTestView.swift

This view guides the user through sending their first message to Ember and shows real-time pipeline status.

File: src/Views/Onboarding/FirstMessageTestView.swift
```swift
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

    // MARK: - Computed Properties

    /// The configured phone numbers from the previous step.
    var configuredPhoneNumbers: [String] {
        UserDefaults.standard.stringArray(forKey: "allowedPhoneNumbers") ?? []
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

        // Start the message pipeline
        startMessagePipeline()

        // Start the timeout timer
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

        // Transition to processing after a brief display
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.testStatus = .processing
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
        .onChange(of: viewModel.testStatus) { oldValue, newValue in
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
            // Animated icon or static icon based on state
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
            // Celebration
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
                .scaleEffect(reduceMotion ? 1.0 : 1.0)

            Text("Ember is ready!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.green)

            // Show the exchange
            if let userMsg = viewModel.userMessage, let emberReply = viewModel.emberResponse {
                VStack(alignment: .leading, spacing: 12) {
                    // User message bubble
                    HStack {
                        Spacer()
                        Text(userMsg)
                            .font(.body)
                            .padding(12)
                            .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("You said: \(userMsg)")

                    // Ember response bubble
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
                    // Mark onboarding as complete
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
```

STEP 2: Update OnboardingContainerView.swift to use FirstMessageTestView

Open `src/Views/Onboarding/OnboardingContainerView.swift` and replace the `.test` placeholder case in the `switch currentStep` block.

Find this code:
```swift
                case .test:
                    // Placeholder — will be implemented in task 0603
                    placeholderView(title: "First Message Test", step: .test)
```

Replace it with:
```swift
                case .test:
                    FirstMessageTestView(
                        onComplete: { completeOnboarding() },
                        onBack: { goBackToStep(.phoneConfig) }
                    )
```

ALSO: Remove the `placeholderView(title:step:)` method from OnboardingContainerView if all placeholders have been replaced. Check that no cases still reference it. If any remaining cases use it, leave it. If none do, delete the entire `placeholderView` method.

STEP 3: Create tests/FirstMessageTestViewModelTests.swift

File: tests/FirstMessageTestViewModelTests.swift
```swift
// FirstMessageTestViewModelTests.swift
// EmberHearth
//
// Unit tests for FirstMessageTestViewModel.

import XCTest
@testable import EmberHearth

@MainActor
final class FirstMessageTestViewModelTests: XCTestCase {

    private var viewModel: FirstMessageTestViewModel!

    override func setUp() {
        super.setUp()
        viewModel = FirstMessageTestViewModel()
        // Set up test phone numbers
        UserDefaults.standard.set(["+15551234567"], forKey: "allowedPhoneNumbers")
    }

    override func tearDown() {
        viewModel.stopTest()
        viewModel = nil
        UserDefaults.standard.removeObject(forKey: "allowedPhoneNumbers")
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialStatus() {
        XCTAssertEqual(viewModel.testStatus, .waitingForMessage)
        XCTAssertNil(viewModel.userMessage)
        XCTAssertNil(viewModel.emberResponse)
    }

    // MARK: - Configured Phone Numbers

    func testConfiguredPhoneNumbers() {
        let numbers = viewModel.configuredPhoneNumbers
        XCTAssertEqual(numbers.count, 1)
        XCTAssertEqual(numbers.first, "+15551234567")
    }

    func testConfiguredPhoneNumbersEmpty() {
        UserDefaults.standard.removeObject(forKey: "allowedPhoneNumbers")
        XCTAssertTrue(viewModel.configuredPhoneNumbers.isEmpty)
    }

    func testDisplayPhoneNumber() {
        let display = viewModel.displayPhoneNumber
        XCTAssertEqual(display, "+1 (555) 123-4567")
    }

    func testDisplayPhoneNumberFallback() {
        UserDefaults.standard.removeObject(forKey: "allowedPhoneNumbers")
        let display = viewModel.displayPhoneNumber
        XCTAssertEqual(display, "your configured number")
    }

    // MARK: - Test Lifecycle

    func testStartTest() {
        viewModel.startTest()
        XCTAssertEqual(viewModel.testStatus, .waitingForMessage)
        XCTAssertEqual(viewModel.timeoutRemaining, FirstMessageTestViewModel.timeoutDuration)
    }

    func testStopTest() {
        viewModel.startTest()
        viewModel.stopTest()
        // After stop, the status should remain wherever it was
        // (stopTest doesn't reset status, retryTest does)
    }

    func testRetryTest() {
        viewModel.startTest()
        viewModel.onMessageReceived("Hello")
        viewModel.retryTest()
        XCTAssertEqual(viewModel.testStatus, .waitingForMessage)
        XCTAssertNil(viewModel.userMessage)
        XCTAssertNil(viewModel.emberResponse)
    }

    // MARK: - Status Transitions

    func testMessageReceivedTransition() {
        viewModel.startTest()
        viewModel.onMessageReceived("Hey Ember!")
        XCTAssertEqual(viewModel.testStatus, .messageReceived)
        XCTAssertEqual(viewModel.userMessage, "Hey Ember!")
    }

    func testResponseSentTransition() {
        viewModel.startTest()
        viewModel.onMessageReceived("Hey Ember!")
        viewModel.onResponseSent("Hi! I'm so glad you set me up.")
        XCTAssertEqual(viewModel.testStatus, .responseSent)
        XCTAssertEqual(viewModel.emberResponse, "Hi! I'm so glad you set me up.")
    }

    func testPipelineErrorTransition() {
        viewModel.startTest()
        viewModel.onPipelineError("LLM connection failed")
        if case .failed(let reason) = viewModel.testStatus {
            XCTAssertEqual(reason, "LLM connection failed")
        } else {
            XCTFail("Expected .failed status")
        }
    }

    func testIgnoresEventsWhenNotRunning() {
        // Don't start the test
        viewModel.onMessageReceived("Hello")
        XCTAssertEqual(viewModel.testStatus, .waitingForMessage, "Should ignore events when not running")
        XCTAssertNil(viewModel.userMessage)
    }

    // MARK: - FirstMessageTestStatus Tests

    func testStatusDescriptions() {
        XCTAssertFalse(FirstMessageTestStatus.waitingForMessage.description.isEmpty)
        XCTAssertFalse(FirstMessageTestStatus.messageReceived.description.isEmpty)
        XCTAssertFalse(FirstMessageTestStatus.processing.description.isEmpty)
        XCTAssertFalse(FirstMessageTestStatus.responseSent.description.isEmpty)
        XCTAssertFalse(FirstMessageTestStatus.failed(reason: "test").description.isEmpty)
        XCTAssertFalse(FirstMessageTestStatus.timedOut.description.isEmpty)
    }

    func testStatusIsFinal() {
        XCTAssertFalse(FirstMessageTestStatus.waitingForMessage.isFinal)
        XCTAssertFalse(FirstMessageTestStatus.messageReceived.isFinal)
        XCTAssertFalse(FirstMessageTestStatus.processing.isFinal)
        XCTAssertTrue(FirstMessageTestStatus.responseSent.isFinal)
        XCTAssertTrue(FirstMessageTestStatus.failed(reason: "err").isFinal)
        XCTAssertTrue(FirstMessageTestStatus.timedOut.isFinal)
    }

    func testStatusIsSuccess() {
        XCTAssertFalse(FirstMessageTestStatus.waitingForMessage.isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.messageReceived.isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.processing.isSuccess)
        XCTAssertTrue(FirstMessageTestStatus.responseSent.isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.failed(reason: "err").isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.timedOut.isSuccess)
    }

    func testStatusEquality() {
        XCTAssertEqual(FirstMessageTestStatus.waitingForMessage, FirstMessageTestStatus.waitingForMessage)
        XCTAssertEqual(FirstMessageTestStatus.responseSent, FirstMessageTestStatus.responseSent)
        XCTAssertEqual(
            FirstMessageTestStatus.failed(reason: "a"),
            FirstMessageTestStatus.failed(reason: "a")
        )
        XCTAssertNotEqual(
            FirstMessageTestStatus.failed(reason: "a"),
            FirstMessageTestStatus.failed(reason: "b")
        )
    }

    // MARK: - Format Tests

    func testFormatUSNumber() {
        XCTAssertEqual(viewModel.formatForDisplay("+15551234567"), "+1 (555) 123-4567")
    }

    func testFormatNonUSNumber() {
        XCTAssertEqual(viewModel.formatForDisplay("+442071234567"), "+442071234567")
    }

    // MARK: - Timeout Tests

    func testTimeoutDuration() {
        XCTAssertEqual(FirstMessageTestViewModel.timeoutDuration, 60)
    }

    func testTimeoutRemainingAfterStart() {
        viewModel.startTest()
        XCTAssertEqual(viewModel.timeoutRemaining, 60)
    }
}
```

STEP 4: Verify the build

After creating/updating all files, run from the project root (/Users/robault/Documents/GitHub/emberhearth):

```bash
swift build
swift test
```

Both must succeed. If the build fails, debug the issue. Common problems:
- Timer: Available in Foundation. Import Foundation.
- DispatchQueue.main.asyncAfter: Available in Foundation.
- If the placeholderView method is still referenced by any case, do NOT delete it.
- @MainActor on tests: Ensure async test compatibility.

IMPORTANT NOTES:
- Do NOT modify Package.swift.
- Do NOT modify any existing files except OnboardingContainerView.swift (replacing the `.test` placeholder and optionally removing the `placeholderView` method if no longer used).
- The test view currently has TODO comments for MessageCoordinator integration. When task 0504 is complete, the `startMessagePipeline()` method should connect to the real pipeline. For now, the view model exposes `onMessageReceived()`, `onResponseSent()`, and `onPipelineError()` methods that can be called by the coordinator.
- The 60-second timeout is critical UX — if the user doesn't send a message within 60 seconds, show troubleshooting tips rather than leaving them waiting indefinitely.
- The "Skip Test" button is always available because some users may want to configure additional settings before testing.
- On success, display the actual first exchange (user message and Ember's response) as chat bubbles.
- ALL status changes must be announced to VoiceOver.
```

---

## Acceptance Criteria

- [ ] `src/Views/Onboarding/FirstMessageTestView.swift` exists and compiles
- [ ] `tests/FirstMessageTestViewModelTests.swift` exists and all tests pass
- [ ] `OnboardingContainerView.swift` updated to use `FirstMessageTestView` instead of placeholder
- [ ] `FirstMessageTestStatus` enum has 6 cases: `waitingForMessage`, `messageReceived`, `processing`, `responseSent`, `failed`, `timedOut`
- [ ] Each status has `description`, `sfSymbol`, `color`, `isFinal`, `isSuccess` properties
- [ ] Step-by-step instructions shown: open Messages, send text to configured number, wait for response
- [ ] Real-time status indicator with progress spinner for waiting/processing states
- [ ] Configured phone number(s) read from `UserDefaults` key `"allowedPhoneNumbers"`
- [ ] 60-second timeout with countdown display
- [ ] On timeout: show troubleshooting tips
- [ ] On failure: show troubleshooting tips with specific advice
- [ ] Troubleshooting tips: check Messages is open, check FDA, check phone number, check internet, check API key
- [ ] On success: show celebration with "Ember is ready!" and the actual message exchange
- [ ] Message exchange shown as chat bubbles (user on right, Ember on left)
- [ ] "Skip Test" button always available
- [ ] "Retry" button shown on failure/timeout
- [ ] "Finish Setup" button shown on success
- [ ] Onboarding marked complete (`hasCompletedOnboarding = true`) on finish or skip
- [ ] VoiceOver: All status changes announced
- [ ] VoiceOver: Instruction steps have descriptive labels
- [ ] VoiceOver: Buttons have labels and hints
- [ ] All text uses semantic font styles (Dynamic Type)
- [ ] Keyboard: Enter/Return for primary action, Escape to go back
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify files exist
test -f src/Views/Onboarding/FirstMessageTestView.swift && echo "FirstMessageTestView.swift exists" || echo "MISSING: FirstMessageTestView.swift"
test -f tests/FirstMessageTestViewModelTests.swift && echo "Tests exist" || echo "MISSING: Tests"

# Verify no shell execution
grep -rn "Process()" src/Views/Onboarding/FirstMessageTestView.swift && echo "WARNING: Found Process()" || echo "OK: No Process()"

# Verify accessibility
grep -c "accessibilityLabel" src/Views/Onboarding/FirstMessageTestView.swift
grep "announcementRequested" src/Views/Onboarding/FirstMessageTestView.swift && echo "OK: VoiceOver announcements"

# Verify timeout
grep "timeoutDuration" src/Views/Onboarding/FirstMessageTestView.swift && echo "OK: Timeout defined"
grep "60" src/Views/Onboarding/FirstMessageTestView.swift && echo "OK: 60-second timeout"

# Verify container was updated
grep "FirstMessageTestView" src/Views/Onboarding/OnboardingContainerView.swift && echo "OK: Container updated"

# Verify no placeholder views remain (optional)
grep "placeholderView" src/Views/Onboarding/OnboardingContainerView.swift && echo "NOTE: Placeholder method still exists" || echo "OK: No more placeholders"

# Build
swift build 2>&1

# Run tests
swift test --filter FirstMessageTestViewModelTests 2>&1
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the First Message Test view created in task 0603 for EmberHearth. Open these files:

@src/Views/Onboarding/FirstMessageTestView.swift
@src/Views/Onboarding/OnboardingContainerView.swift
@tests/FirstMessageTestViewModelTests.swift

Also reference:
@CLAUDE.md
@docs/research/onboarding-ux.md (focus on Section 6 and Section 10)

Check for these specific issues:

1. STATUS STATE MACHINE:
   - Verify all 6 states exist: waitingForMessage, messageReceived, processing, responseSent, failed, timedOut
   - Verify isFinal returns true ONLY for responseSent, failed, timedOut
   - Verify isSuccess returns true ONLY for responseSent
   - Verify status transitions are guarded by `isRunning` (no events processed when test is stopped)
   - Verify the timeout timer stops when a final state is reached
   - Verify retryTest properly resets ALL state (status, userMessage, emberResponse, timer)

2. TIMEOUT:
   - Verify 60-second timeout duration
   - Verify the countdown display updates every second
   - Verify the timer is invalidated in onDisappear and deinit (no leaked timers)
   - Verify timeout transitions to .timedOut status

3. ACCESSIBILITY:
   - ALL status changes are announced to VoiceOver via NSAccessibility.post
   - Instruction steps have descriptive labels ("Step 1: ...", "Step 2: ...")
   - Skip/Retry/Finish buttons have labels AND hints
   - Troubleshooting tips are accessible
   - All text uses semantic font styles
   - Reduce Motion preference is respected (no animations when enabled)

4. UI/UX:
   - Step-by-step instructions are clear and match the onboarding UX research
   - Configured phone number is displayed (read from UserDefaults)
   - Success shows chat bubble display of the exchange
   - Troubleshooting tips are helpful and specific
   - Skip Test is always available
   - Retry is shown only on failure/timeout

5. INTEGRATION:
   - OnboardingContainerView updated correctly
   - onComplete marks onboarding as done (hasCompletedOnboarding = true)
   - onBack returns to .phoneConfig
   - The placeholder view method is removed if no longer used
   - TODO comments for MessageCoordinator integration are present

6. BUILD VERIFICATION:
   - Run `swift build` and verify success
   - Run `swift test --filter FirstMessageTestViewModelTests` and verify all tests pass
   - Run `swift test` and verify no existing tests are broken

Report issues with file paths and line numbers. Severity: CRITICAL, IMPORTANT, MINOR.
```

---

## Commit Message

```
feat(m7): add first message test view for end-to-end verification
```

---

## Notes for Next Task

- All 5 onboarding steps now have real implementations. The `placeholderView` method in `OnboardingContainerView` should have been removed.
- The `FirstMessageTestViewModel` exposes `onMessageReceived()`, `onResponseSent()`, and `onPipelineError()` methods. When `MessageCoordinator` (task 0504) is integrated, it should call these methods to drive the test UI.
- Onboarding completion is stored in `UserDefaults` key `"hasCompletedOnboarding"`.
- The next task (0604) is an accessibility review pass across ALL onboarding views. It will audit and enhance accessibility on all 6 files created in tasks 0600-0603.
- Phone numbers are stored in `UserDefaults` key `"allowedPhoneNumbers"`. This should eventually be migrated to `PhoneNumberFilter` (task 0103).
