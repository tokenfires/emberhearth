// FirstMessageTestViewModelTests.swift
// EmberHearth
//
// Unit tests for FirstMessageTestViewModel.

import XCTest
@testable import EmberHearth

@MainActor
final class FirstMessageTestViewModelTests: XCTestCase {

    private var viewModel: FirstMessageTestViewModel!
    private var phoneNumberFilter: PhoneNumberFilter!

    override func setUp() {
        super.setUp()
        phoneNumberFilter = PhoneNumberFilter()
        phoneNumberFilter.removeAllAllowedNumbers()
        phoneNumberFilter.addAllowedNumber("+15551234567")
        viewModel = FirstMessageTestViewModel(phoneNumberFilter: phoneNumberFilter)
    }

    override func tearDown() {
        viewModel.stopTest()
        viewModel = nil
        phoneNumberFilter.removeAllAllowedNumbers()
        phoneNumberFilter = nil
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
        phoneNumberFilter.removeAllAllowedNumbers()
        XCTAssertTrue(viewModel.configuredPhoneNumbers.isEmpty)
    }

    func testDisplayPhoneNumber() {
        let display = viewModel.displayPhoneNumber
        XCTAssertEqual(display, "+1 (555) 123-4567")
    }

    func testDisplayPhoneNumberFallback() {
        phoneNumberFilter.removeAllAllowedNumbers()
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
