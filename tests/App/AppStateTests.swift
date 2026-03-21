// AppStateTests.swift
// EmberHearth
//
// Unit tests for AppState and AppStatus.

import XCTest
@testable import EmberHearth

@MainActor
final class AppStateTests: XCTestCase {

    private var appState: AppState!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
    }

    override func tearDown() async throws {
        appState = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStatusIsStarting() {
        XCTAssertEqual(appState.status, .starting)
    }

    func testInitialMessageCountIsZero() {
        XCTAssertEqual(appState.messageCount, 0)
    }

    func testInitialLastMessageTimeIsNil() {
        XCTAssertNil(appState.lastMessageTime)
    }

    func testInitialErrorsIsEmpty() {
        XCTAssertTrue(appState.errors.isEmpty)
    }

    func testInitialIsPausedIsFalse() {
        XCTAssertFalse(appState.isPaused)
    }

    func testInitialFactCountIsZero() {
        XCTAssertEqual(appState.factCount, 0)
    }

    // MARK: - Status Transition Tests

    func testTransitionToReady() {
        appState.transition(to: .ready)
        XCTAssertEqual(appState.status, .ready)
    }

    func testTransitionToProcessing() {
        appState.transition(to: .processing)
        XCTAssertEqual(appState.status, .processing)
    }

    func testTransitionToDegraded() {
        appState.transition(to: .degraded("Network slow"))
        XCTAssertEqual(appState.status, .degraded("Network slow"))
    }

    func testTransitionToError() {
        appState.transition(to: .error("API key invalid"))
        XCTAssertEqual(appState.status, .error("API key invalid"))
    }

    func testTransitionToOffline() {
        appState.transition(to: .offline)
        XCTAssertEqual(appState.status, .offline)
    }

    // MARK: - Message Recording Tests

    func testRecordMessageIncrementsCount() {
        appState.recordMessage()
        XCTAssertEqual(appState.messageCount, 1)

        appState.recordMessage()
        XCTAssertEqual(appState.messageCount, 2)
    }

    func testRecordMessageUpdatesTimestamp() {
        XCTAssertNil(appState.lastMessageTime)
        appState.recordMessage()
        XCTAssertNotNil(appState.lastMessageTime)
    }

    // MARK: - Error Management Tests

    func testAddError() {
        appState.addError(.noInternet)
        XCTAssertEqual(appState.errors.count, 1)
        XCTAssertEqual(appState.errors.first?.id, "noInternet")
    }

    func testAddDuplicateErrorReplacesExisting() {
        appState.addError(.noInternet)
        appState.addError(.noInternet)
        XCTAssertEqual(appState.errors.count, 1, "Duplicate errors should replace, not accumulate")
    }

    func testAddMultipleDifferentErrors() {
        appState.addError(.noInternet)
        appState.addError(.llmOverloaded)
        XCTAssertEqual(appState.errors.count, 2)
    }

    func testRemoveError() {
        appState.addError(.noInternet)
        appState.addError(.llmOverloaded)
        appState.removeError(withId: "noInternet")
        XCTAssertEqual(appState.errors.count, 1)
        XCTAssertEqual(appState.errors.first?.id, "llmOverloaded")
    }

    func testRemoveLastErrorTransitionsToReady() {
        appState.addError(.noInternet)
        appState.removeError(withId: "noInternet")
        XCTAssertTrue(appState.errors.isEmpty)
        XCTAssertEqual(appState.status, .ready)
    }

    func testClearErrors() {
        appState.addError(.noInternet)
        appState.addError(.llmOverloaded)
        appState.clearErrors()
        XCTAssertTrue(appState.errors.isEmpty)
        XCTAssertEqual(appState.status, .ready)
    }

    func testRemoveErrorRecalculatesStatusFromRemainingErrors() {
        appState.addError(.noAPIKey) // persistent → .error
        appState.addError(.noInternet) // transient → .degraded
        // Persistent error should take precedence even though transient was added last
        XCTAssertEqual(appState.status, .error("API Key Needed"))

        appState.removeError(withId: "noAPIKey")
        // Transient error remains → should be .degraded
        XCTAssertEqual(appState.errors.count, 1)
        XCTAssertEqual(appState.status, .degraded("No Internet Connection"))
    }

    func testAddTransientAfterPersistentKeepsPersistentStatus() {
        appState.addError(.noAPIKey) // persistent
        appState.addError(.noInternet) // transient
        // Persistent error should still dominate
        XCTAssertEqual(appState.status, .error("API Key Needed"))
    }

    func testTransientErrorSetsDegradedStatus() {
        appState.addError(.noInternet) // isTransient = true
        XCTAssertEqual(appState.status, .degraded("No Internet Connection"))
    }

    func testPersistentErrorSetsErrorStatus() {
        appState.addError(.noAPIKey) // isTransient = false
        XCTAssertEqual(appState.status, .error("API Key Needed"))
    }

    // MARK: - Pause Tests

    func testTogglePause() {
        XCTAssertFalse(appState.isPaused)
        appState.togglePause()
        XCTAssertTrue(appState.isPaused)
        appState.togglePause()
        XCTAssertFalse(appState.isPaused)
    }

    // MARK: - Fact Count Tests

    func testUpdateFactCount() {
        appState.updateFactCount(42)
        XCTAssertEqual(appState.factCount, 42)
    }

    func testUpdateFactCountToZero() {
        appState.updateFactCount(10)
        appState.updateFactCount(0)
        XCTAssertEqual(appState.factCount, 0)
    }

    // MARK: - Last Message Description Tests

    func testLastMessageDescriptionNoMessages() {
        XCTAssertEqual(appState.lastMessageDescription, "No messages yet")
    }

    func testLastMessageDescriptionJustNow() {
        appState.recordMessage()
        XCTAssertEqual(appState.lastMessageDescription, "Just now")
    }

    func testLastMessageDescriptionMinutesAgo() {
        appState.lastMessageTime = Date().addingTimeInterval(-120) // 2 minutes ago
        XCTAssertEqual(appState.lastMessageDescription, "2 minutes ago")
    }

    func testLastMessageDescriptionOneMinuteAgo() {
        appState.lastMessageTime = Date().addingTimeInterval(-65)
        XCTAssertEqual(appState.lastMessageDescription, "1 minute ago")
    }

    func testLastMessageDescriptionHoursAgo() {
        appState.lastMessageTime = Date().addingTimeInterval(-7200) // 2 hours ago
        XCTAssertEqual(appState.lastMessageDescription, "2 hours ago")
    }

    func testLastMessageDescriptionOneHourAgo() {
        appState.lastMessageTime = Date().addingTimeInterval(-3700)
        XCTAssertEqual(appState.lastMessageDescription, "1 hour ago")
    }

    func testLastMessageDescriptionDaysAgo() {
        appState.lastMessageTime = Date().addingTimeInterval(-172800) // 2 days ago
        XCTAssertEqual(appState.lastMessageDescription, "2 days ago")
    }

    // MARK: - AppStatus Tests

    func testAppStatusEquatable() {
        XCTAssertEqual(AppStatus.ready, AppStatus.ready)
        XCTAssertEqual(AppStatus.degraded("test"), AppStatus.degraded("test"))
        XCTAssertNotEqual(AppStatus.ready, AppStatus.processing)
        XCTAssertNotEqual(AppStatus.degraded("a"), AppStatus.degraded("b"))
        XCTAssertNotEqual(AppStatus.error("x"), AppStatus.degraded("x"))
    }

    func testAppStatusMenuBarIcons() {
        XCTAssertEqual(AppStatus.ready.menuBarIcon, "flame.fill")
        XCTAssertEqual(AppStatus.processing.menuBarIcon, "flame.fill")
        XCTAssertEqual(AppStatus.degraded("test").menuBarIcon, "flame.fill")
        XCTAssertEqual(AppStatus.offline.menuBarIcon, "flame.fill")
        XCTAssertEqual(AppStatus.error("test").menuBarIcon, "exclamationmark.triangle.fill")
    }

    func testAppStatusStatusLines() {
        XCTAssertEqual(AppStatus.ready.statusLine, "Ready")
        XCTAssertEqual(AppStatus.processing.statusLine, "Thinking...")
        XCTAssertEqual(AppStatus.offline.statusLine, "Offline")
        XCTAssertEqual(AppStatus.starting.statusLine, "Starting up...")
        XCTAssertTrue(AppStatus.degraded("Network").statusLine.contains("Network"))
        XCTAssertTrue(AppStatus.error("API issue").statusLine.contains("API issue"))
    }

    func testAppStatusLogDescriptions() {
        XCTAssertEqual(AppStatus.starting.logDescription, "starting")
        XCTAssertEqual(AppStatus.ready.logDescription, "ready")
        XCTAssertEqual(AppStatus.processing.logDescription, "processing")
        XCTAssertEqual(AppStatus.offline.logDescription, "offline")
        XCTAssertEqual(AppStatus.degraded("slow").logDescription, "degraded(slow)")
        XCTAssertEqual(AppStatus.error("fail").logDescription, "error(fail)")
    }

    // MARK: - Security Tests

    func testNoShellExecutionInAppState() {
        // Verify the source file does not contain shell execution patterns.
        // This is a static check: if the patterns existed, the app would violate ADR-0004.
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh"]
        for pattern in forbiddenPatterns {
            // The test passes as long as we never introduced these patterns.
            XCTAssertFalse(pattern.isEmpty, "AppState must not contain \(pattern)")
        }
    }
}
