// SecurityLoggerTests.swift
// EmberHearth
//
// Unit tests for SecurityLogger and AppLogger.

import XCTest
@testable import EmberHearth

final class SecurityLoggerTests: XCTestCase {

    private var secLogger: SecurityLogger!

    override func setUp() {
        super.setUp()
        // Use a fresh instance for each test (not the shared singleton)
        secLogger = SecurityLogger()
    }

    override func tearDown() {
        secLogger.clearEvents()
        secLogger = nil
        super.tearDown()
    }

    // MARK: - AppLogger Tests

    func testAppLoggerReturnsLoggerForCategory() {
        let securityLogger = AppLogger.logger(for: .security)
        let appLogger = AppLogger.logger(for: .app)
        // Both should be valid Logger instances (no crash)
        XCTAssertNotNil(securityLogger)
        XCTAssertNotNil(appLogger)
    }

    func testAppLoggerSubsystem() {
        XCTAssertEqual(AppLogger.subsystem, "com.emberhearth")
    }

    func testAllLogCategoriesExist() {
        // Verify all expected categories are defined
        let categories = LogCategory.allCases
        XCTAssertTrue(categories.contains(.app))
        XCTAssertTrue(categories.contains(.security))
        XCTAssertTrue(categories.contains(.messages))
        XCTAssertTrue(categories.contains(.memory))
        XCTAssertTrue(categories.contains(.llm))
        XCTAssertTrue(categories.contains(.network))
        XCTAssertEqual(categories.count, 6)
    }

    // MARK: - SecurityLogger Event Buffer Tests

    func testInjectionAttemptLogged() {
        secLogger.logInjectionAttempt(
            patternIds: ["PI-001", "JB-003"],
            threatLevel: .high,
            phoneNumber: "+15551234567"
        )

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .injectionDetected)
        XCTAssertEqual(events[0].threatLevel, .high)
        XCTAssertTrue(events[0].details.contains("PI-001"))
        XCTAssertTrue(events[0].details.contains("JB-003"))
        XCTAssertTrue(events[0].details.contains("...4567"))
        // Verify full phone number is NOT in the details
        XCTAssertFalse(events[0].details.contains("+15551234567"))
        XCTAssertFalse(events[0].details.contains("5551234567"))
    }

    func testCredentialDetectionLogged() {
        secLogger.logCredentialDetection(
            types: ["Anthropic API Key", "GitHub Token"],
            count: 2
        )

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .credentialDetected)
        XCTAssertEqual(events[0].threatLevel, .high)
        XCTAssertTrue(events[0].details.contains("Anthropic API Key"))
        XCTAssertTrue(events[0].details.contains("2"))
    }

    func testGroupChatBlockLogged() {
        secLogger.logGroupChatBlock(phoneNumber: "+15559876543")

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .groupChatBlocked)
        XCTAssertEqual(events[0].threatLevel, .none)
        XCTAssertTrue(events[0].details.contains("...6543"))
        XCTAssertFalse(events[0].details.contains("+15559876543"))
    }

    func testUnauthorizedNumberLogged() {
        secLogger.logUnauthorizedNumber(phoneNumber: "+15550001111")

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .unauthorizedNumber)
        XCTAssertTrue(events[0].details.contains("...1111"))
        XCTAssertFalse(events[0].details.contains("+15550001111"))
    }

    func testMessageBlockedLogged() {
        secLogger.logMessageBlocked(
            reason: "Potential security threat detected (level: high)",
            phoneNumber: "+15551234567"
        )

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .messageBlocked)
        XCTAssertTrue(events[0].details.contains("...4567"))
    }

    func testMessageAllowedNotStoredInBuffer() {
        secLogger.logMessageAllowed(phoneNumber: "+15551234567")

        // "Allowed" events are NOT stored in the buffer (routine events)
        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 0)
    }

    func testResponseAllowedNotStoredInBuffer() {
        secLogger.logResponseAllowed()

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 0)
    }

    func testResponseRedactedLogged() {
        secLogger.logResponseRedacted(types: ["OpenAI API Key"], count: 1)

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].eventType, .responseRedacted)
        XCTAssertTrue(events[0].details.contains("OpenAI API Key"))
    }

    // MARK: - Event Buffer Management

    func testEventBufferCapacity() {
        // Fill the buffer beyond capacity (100)
        for i in 0..<150 {
            secLogger.logGroupChatBlock(phoneNumber: "+1555000\(String(format: "%04d", i))")
        }

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 100, "Buffer should cap at 100 events")
    }

    func testEventBufferOrderOldestFirst() {
        secLogger.logGroupChatBlock(phoneNumber: "+15550001111")
        secLogger.logGroupChatBlock(phoneNumber: "+15550002222")
        secLogger.logGroupChatBlock(phoneNumber: "+15550003333")

        let events = secLogger.getRecentEvents()
        XCTAssertEqual(events.count, 3)
        XCTAssertTrue(events[0].details.contains("...1111"))
        XCTAssertTrue(events[2].details.contains("...3333"))
    }

    func testClearEvents() {
        secLogger.logGroupChatBlock(phoneNumber: "+15551234567")
        XCTAssertEqual(secLogger.eventCount, 1)

        secLogger.clearEvents()
        XCTAssertEqual(secLogger.eventCount, 0)
        XCTAssertTrue(secLogger.getRecentEvents().isEmpty)
    }

    func testEventCount() {
        XCTAssertEqual(secLogger.eventCount, 0)

        secLogger.logGroupChatBlock(phoneNumber: "+15551234567")
        XCTAssertEqual(secLogger.eventCount, 1)

        secLogger.logCredentialDetection(types: ["Test"], count: 1)
        XCTAssertEqual(secLogger.eventCount, 2)
    }

    // MARK: - Phone Number Masking

    func testPhoneNumberMasking() {
        secLogger.logGroupChatBlock(phoneNumber: "+15551234567")

        let events = secLogger.getRecentEvents()
        let details = events[0].details

        // Should contain masked number
        XCTAssertTrue(details.contains("...4567"))

        // Should NOT contain any more than last 4 digits
        XCTAssertFalse(details.contains("1234567"))
        XCTAssertFalse(details.contains("5551234567"))
        XCTAssertFalse(details.contains("+1555"))
    }

    func testShortPhoneNumberMasking() {
        secLogger.logGroupChatBlock(phoneNumber: "123")

        let events = secLogger.getRecentEvents()
        // Very short numbers get "...????"
        XCTAssertTrue(events[0].details.contains("...????"))
    }

    // MARK: - SecurityEvent Model

    func testSecurityEventTimestamp() {
        let beforeCreation = Date()
        let event = SecurityEvent(
            eventType: .injectionDetected,
            threatLevel: .high,
            details: "Test event"
        )
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(event.timestamp, beforeCreation)
        XCTAssertLessThanOrEqual(event.timestamp, afterCreation)
    }

    func testSecurityEventTypes() {
        let allTypes = SecurityEventType.allCases
        XCTAssertEqual(allTypes.count, 9)
        XCTAssertTrue(allTypes.contains(.injectionDetected))
        XCTAssertTrue(allTypes.contains(.credentialDetected))
        XCTAssertTrue(allTypes.contains(.groupChatBlocked))
        XCTAssertTrue(allTypes.contains(.unauthorizedNumber))
        XCTAssertTrue(allTypes.contains(.messageBlocked))
        XCTAssertTrue(allTypes.contains(.messageAllowed))
        XCTAssertTrue(allTypes.contains(.responseRedacted))
        XCTAssertTrue(allTypes.contains(.responseAllowed))
        XCTAssertTrue(allTypes.contains(.crisisDetected))
    }

    // MARK: - Thread Safety

    func testConcurrentEventLogging() {
        let expectation = XCTestExpectation(description: "Concurrent logging")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<10 {
            queue.async {
                self.secLogger.logGroupChatBlock(phoneNumber: "+1555000\(String(format: "%04d", i))")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
        XCTAssertEqual(secLogger.eventCount, 10)
    }

    func testConcurrentReadWrite() {
        let writeExpectation = XCTestExpectation(description: "Concurrent write")
        writeExpectation.expectedFulfillmentCount = 50
        let readExpectation = XCTestExpectation(description: "Concurrent read")
        readExpectation.expectedFulfillmentCount = 50

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<50 {
            queue.async {
                self.secLogger.logGroupChatBlock(phoneNumber: "+1555000\(String(format: "%04d", i))")
                writeExpectation.fulfill()
            }
            queue.async {
                _ = self.secLogger.getRecentEvents()
                readExpectation.fulfill()
            }
        }

        wait(for: [writeExpectation, readExpectation], timeout: 5.0)
        // No crash = thread safety verified
        XCTAssertGreaterThan(secLogger.eventCount, 0)
    }

    // MARK: - Data Sanitization Verification

    /// This test verifies that no security event detail string contains
    /// patterns that look like actual credentials or full phone numbers.
    func testNoSensitiveDataInEventDetails() {
        // Log various events with "sensitive" input
        secLogger.logInjectionAttempt(
            patternIds: ["PI-001"],
            threatLevel: .high,
            phoneNumber: "+15551234567"
        )
        secLogger.logCredentialDetection(
            types: ["Test Key"],
            count: 1
        )
        secLogger.logGroupChatBlock(phoneNumber: "+15559876543")
        secLogger.logUnauthorizedNumber(phoneNumber: "+15550001111")

        let events = secLogger.getRecentEvents()

        for event in events {
            // Full phone numbers should never appear
            XCTAssertFalse(
                event.details.contains("+1555"),
                "Event details should not contain phone number prefix: \(event.details)"
            )

            // API key patterns should never appear
            XCTAssertFalse(
                event.details.contains("sk-ant-"),
                "Event details should not contain API key patterns"
            )
            XCTAssertFalse(
                event.details.contains("sk-"),
                "Event details should not contain API key prefixes"
            )
        }
    }
}
