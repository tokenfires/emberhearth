# Task 0503: Security and Application Logging Infrastructure

**Milestone:** M6 - Security Basics
**Unit:** 6.5 - Security Event Logging
**Phase:** 3
**Depends On:** 0502
**Estimated Effort:** 2-3 hours
**Complexity:** Medium

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, project structure
2. `src/Security/TronPipeline.swift` — The pipeline from task 0502. Note the existing os.Logger calls that will be replaced with SecurityLogger.
3. `src/Security/ThreatLevel.swift` — The ThreatLevel enum used in security events
4. `src/Security/ScanResult.swift` — The injection scan result (referenced in logging)
5. `src/Security/CredentialScanResult.swift` — The credential scan result (referenced in logging)
6. `docs/specs/tron-security.md` — Focus on Section 8 "Audit Logging" (lines ~1312-1460) for the log schema and sanitization requirements

> **Context Budget Note:** Read the source files in full (they are small). For tron-security.md, only read Section 8 (Audit Logging, ~150 lines). Skip the full AuditLogEntry schema — we are building a simpler MVP version.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the logging infrastructure for EmberHearth, a native macOS personal AI assistant. This includes a general-purpose AppLogger and a specialized SecurityLogger for security events. These replace the ad-hoc os.Logger usage in existing files and provide structured, safe logging.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., SecurityLogger.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target
- No third-party dependencies — use only Apple frameworks

PROJECT CONTEXT:
- This is a Swift Package Manager project
- Package.swift has the main target at path "src" and test target at path "tests"
- The following files already exist from previous tasks:
  - src/Security/ThreatLevel.swift — ThreatLevel enum
  - src/Security/TronPipeline.swift — Uses os.Logger directly (will be updated)
  - src/Security/InjectionScanner.swift — Uses os.Logger directly (will be updated)
  - src/Security/CredentialScanner.swift — Uses os.Logger directly (will be updated)

CRITICAL SECURITY RULES FOR LOGGING:
- NEVER log message content at ANY level (not even .debug)
- NEVER log API keys, credentials, or full phone numbers
- Phone numbers: log only last 4 digits (e.g., "...4567")
- Credentials: log only the type name (e.g., "Anthropic API Key"), NEVER the value
- Injection patterns: log only the pattern ID (e.g., "PI-001"), NEVER the message text
- Security events at .critical/.high use os.Logger .error level
- Routine security events use os.Logger .info level
- Debug-level security events use os.Logger .debug level

STEP 1: Create the AppLogger

File: src/Logging/AppLogger.swift
```swift
// AppLogger.swift
// EmberHearth
//
// Central logging infrastructure using Apple's unified logging system (os.Logger).

import Foundation
import os

/// Log categories for EmberHearth's subsystems.
///
/// Each category maps to a unique os.Logger instance with a specific category string.
/// Use `AppLogger.logger(for:)` to get the appropriate logger.
///
/// View logs in Console.app by filtering on subsystem "com.emberhearth".
enum LogCategory: String, CaseIterable, Sendable {
    /// General application lifecycle events (launch, shutdown, state changes).
    case app = "app"

    /// Security events (injection detection, credential scanning, pipeline decisions).
    case security = "security"

    /// Message processing events (new message detected, response sent).
    /// NEVER log message content in this category.
    case messages = "messages"

    /// Memory system events (fact extraction, retrieval, storage).
    case memory = "memory"

    /// LLM provider events (API calls, streaming, errors).
    /// NEVER log API keys or response content.
    case llm = "llm"

    /// Network events (connectivity changes, request failures).
    case network = "network"
}

/// Central logging facility for EmberHearth.
///
/// Provides categorized os.Logger instances using Apple's unified logging system.
/// All logs go to the macOS unified log and can be viewed in Console.app.
///
/// ## Usage
/// ```swift
/// let logger = AppLogger.logger(for: .security)
/// logger.info("Pipeline check passed for number: ...4567")
/// logger.error("Injection detected: pattern PI-001")
/// ```
///
/// ## Security Rules
/// - NEVER log message content, API keys, or credentials at any log level
/// - NEVER log full phone numbers — use only the last 4 digits
/// - Use `.public` privacy only for non-sensitive values (pattern IDs, threat levels, counts)
/// - All log messages with user data default to `.private` (redacted in non-debug logs)
enum AppLogger {

    /// The subsystem identifier for all EmberHearth loggers.
    static let subsystem = "com.emberhearth"

    /// Cache of logger instances keyed by category.
    /// Using nonisolated(unsafe) because Logger is thread-safe and we only
    /// write during first access of each category.
    private nonisolated(unsafe) static var loggers: [LogCategory: Logger] = [:]

    /// Returns a logger for the specified category.
    ///
    /// Logger instances are cached after first creation.
    ///
    /// - Parameter category: The log category.
    /// - Returns: An os.Logger configured with the EmberHearth subsystem and category.
    static func logger(for category: LogCategory) -> Logger {
        if let cached = loggers[category] {
            return cached
        }
        let logger = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = logger
        return logger
    }
}
```

STEP 2: Create the SecurityEventType enum

File: src/Logging/SecurityEventType.swift
```swift
// SecurityEventType.swift
// EmberHearth
//
// Types of security events that can be logged.

import Foundation

/// Types of security events tracked by the SecurityLogger.
enum SecurityEventType: String, Sendable, CaseIterable {
    /// An injection attempt was detected in an inbound message.
    case injectionDetected = "injection_detected"

    /// Credentials were detected in an outbound LLM response.
    case credentialDetected = "credential_detected"

    /// A group chat message was blocked.
    case groupChatBlocked = "group_chat_blocked"

    /// A message from an unauthorized phone number was ignored.
    case unauthorizedNumber = "unauthorized_number"

    /// An inbound message was blocked by the security pipeline.
    case messageBlocked = "message_blocked"

    /// An inbound message was allowed (passed all checks).
    case messageAllowed = "message_allowed"

    /// An outbound response was redacted (credentials removed).
    case responseRedacted = "response_redacted"

    /// An outbound response was allowed (no credentials found).
    case responseAllowed = "response_allowed"
}
```

STEP 3: Create the SecurityEvent model

File: src/Logging/SecurityEvent.swift
```swift
// SecurityEvent.swift
// EmberHearth
//
// Structured security event for in-memory tracking and future audit logging.

import Foundation

/// A structured security event for in-memory tracking.
///
/// SecurityEvents are stored in the SecurityLogger's recent events buffer
/// (last 100 events) for display in the future settings UI. They contain
/// only sanitized data — NEVER raw message content or credentials.
struct SecurityEvent: Sendable {
    /// When the event occurred.
    let timestamp: Date

    /// The type of security event.
    let eventType: SecurityEventType

    /// The threat level associated with this event.
    /// `.none` for non-threat events (e.g., messageAllowed, responseAllowed).
    let threatLevel: ThreatLevel

    /// A sanitized, human-readable description of the event.
    /// NEVER contains raw message content, credentials, or full phone numbers.
    /// Examples:
    /// - "Injection detected: patterns [PI-001, JB-003], threat: high"
    /// - "Credential redacted: 2 credential(s) of type [Anthropic API Key]"
    /// - "Group chat message blocked from ...4567"
    let details: String

    /// Creates a SecurityEvent with the current timestamp.
    init(eventType: SecurityEventType, threatLevel: ThreatLevel, details: String) {
        self.timestamp = Date()
        self.eventType = eventType
        self.threatLevel = threatLevel
        self.details = details
    }
}
```

STEP 4: Create the SecurityLogger

File: src/Logging/SecurityLogger.swift
```swift
// SecurityLogger.swift
// EmberHearth
//
// Specialized security logging with data sanitization and in-memory event tracking.

import Foundation
import os

/// Specialized logger for security events with built-in data sanitization.
///
/// SecurityLogger wraps AppLogger with security-specific methods that ensure
/// sensitive data is NEVER included in log output. It also maintains an in-memory
/// buffer of recent security events for the future settings UI.
///
/// ## Security Guarantees
/// - Message content is NEVER logged at any level
/// - Credential values are NEVER logged — only the credential type name
/// - Phone numbers are masked to last 4 digits
/// - All log output uses os.Logger privacy annotations
///
/// ## In-Memory Event Buffer
/// The logger maintains a circular buffer of the last 100 security events.
/// These events contain only sanitized data and are intended for display
/// in the Mac app's security dashboard (future task).
///
/// ## Usage
/// ```swift
/// let secLogger = SecurityLogger.shared
/// secLogger.logInjectionAttempt(patternIds: ["PI-001"], threatLevel: .high, phoneNumber: "+15551234567")
/// secLogger.logCredentialDetection(types: ["Anthropic API Key"], count: 1)
/// ```
final class SecurityLogger: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared SecurityLogger instance.
    static let shared = SecurityLogger()

    // MARK: - Properties

    /// The underlying os.Logger for security events.
    private let logger: Logger

    /// In-memory buffer of recent security events.
    /// Protected by a lock for thread safety.
    private var recentEvents: [SecurityEvent] = []

    /// Maximum number of events to keep in the buffer.
    private let maxBufferSize = 100

    /// Lock for thread-safe access to the events buffer.
    private let lock = NSLock()

    // MARK: - Initialization

    /// Creates a SecurityLogger. Use `.shared` for the singleton instance.
    /// The init is internal (not private) to allow testing with a fresh instance.
    init() {
        self.logger = AppLogger.logger(for: .security)
    }

    // MARK: - Security Event Logging

    /// Logs an injection attempt detection.
    ///
    /// - Parameters:
    ///   - patternIds: The IDs of the matched injection patterns (e.g., ["PI-001", "JB-003"]).
    ///   - threatLevel: The highest threat level among matched patterns.
    ///   - phoneNumber: The sender's phone number. Only the last 4 digits are logged.
    func logInjectionAttempt(patternIds: [String], threatLevel: ThreatLevel, phoneNumber: String) {
        let maskedNumber = maskPhoneNumber(phoneNumber)
        let patterns = patternIds.joined(separator: ", ")

        switch threatLevel {
        case .critical, .high:
            logger.error(
                "Injection detected: patterns=[\(patterns, privacy: .public)], threat=\(threatLevel.label, privacy: .public), from=\(maskedNumber, privacy: .public)"
            )
        case .medium:
            logger.warning(
                "Injection warning: patterns=[\(patterns, privacy: .public)], threat=\(threatLevel.label, privacy: .public), from=\(maskedNumber, privacy: .public)"
            )
        case .low, .none:
            logger.info(
                "Injection note: patterns=[\(patterns, privacy: .public)], threat=\(threatLevel.label, privacy: .public), from=\(maskedNumber, privacy: .public)"
            )
        }

        let event = SecurityEvent(
            eventType: .injectionDetected,
            threatLevel: threatLevel,
            details: "Injection detected: patterns [\(patterns)], threat: \(threatLevel.label), from: \(maskedNumber)"
        )
        appendEvent(event)
    }

    /// Logs a credential detection in an outbound response.
    ///
    /// - Parameters:
    ///   - types: The names of the detected credential types (e.g., ["Anthropic API Key"]).
    ///     NEVER pass the actual credential values.
    ///   - count: The number of individual credential matches found.
    func logCredentialDetection(types: [String], count: Int) {
        let typeList = types.joined(separator: ", ")

        logger.warning(
            "Credentials redacted: \(count, privacy: .public) match(es) of type [\(typeList, privacy: .public)]"
        )

        let event = SecurityEvent(
            eventType: .credentialDetected,
            threatLevel: .high,
            details: "Credential redacted: \(count) credential(s) of type [\(typeList)]"
        )
        appendEvent(event)
    }

    /// Logs a group chat message block.
    ///
    /// - Parameter phoneNumber: The sender's phone number. Only the last 4 digits are logged.
    func logGroupChatBlock(phoneNumber: String) {
        let maskedNumber = maskPhoneNumber(phoneNumber)

        logger.info(
            "Group chat blocked from: \(maskedNumber, privacy: .public)"
        )

        let event = SecurityEvent(
            eventType: .groupChatBlocked,
            threatLevel: .none,
            details: "Group chat message blocked from \(maskedNumber)"
        )
        appendEvent(event)
    }

    /// Logs a message from an unauthorized phone number.
    ///
    /// - Parameter phoneNumber: The sender's phone number. Only the last 4 digits are logged.
    func logUnauthorizedNumber(phoneNumber: String) {
        let maskedNumber = maskPhoneNumber(phoneNumber)

        logger.info(
            "Unauthorized number ignored: \(maskedNumber, privacy: .public)"
        )

        let event = SecurityEvent(
            eventType: .unauthorizedNumber,
            threatLevel: .none,
            details: "Message from unauthorized number \(maskedNumber) ignored"
        )
        appendEvent(event)
    }

    /// Logs that an inbound message was blocked.
    ///
    /// - Parameters:
    ///   - reason: A sanitized reason string (from InboundResult.blocked).
    ///   - phoneNumber: The sender's phone number. Only the last 4 digits are logged.
    func logMessageBlocked(reason: String, phoneNumber: String) {
        let maskedNumber = maskPhoneNumber(phoneNumber)

        logger.warning(
            "Message blocked: reason=\(reason, privacy: .public), from=\(maskedNumber, privacy: .public)"
        )

        let event = SecurityEvent(
            eventType: .messageBlocked,
            threatLevel: .high,
            details: "Message blocked from \(maskedNumber): \(reason)"
        )
        appendEvent(event)
    }

    /// Logs that an inbound message was allowed.
    ///
    /// - Parameter phoneNumber: The sender's phone number. Only the last 4 digits are logged.
    func logMessageAllowed(phoneNumber: String) {
        let maskedNumber = maskPhoneNumber(phoneNumber)

        logger.debug(
            "Message allowed from: \(maskedNumber, privacy: .public)"
        )

        // Note: We do NOT store "allowed" events in the buffer to avoid
        // filling it with routine events. Only security-relevant events are stored.
    }

    /// Logs that an outbound response was allowed (no credentials found).
    func logResponseAllowed() {
        logger.debug("Outbound response allowed (clean)")
        // Not stored in buffer — routine event
    }

    /// Logs that an outbound response was redacted.
    ///
    /// - Parameters:
    ///   - types: The names of the redacted credential types.
    ///   - count: The number of credentials redacted.
    func logResponseRedacted(types: [String], count: Int) {
        let typeList = types.joined(separator: ", ")

        logger.warning(
            "Response redacted: \(count, privacy: .public) credential(s) of type [\(typeList, privacy: .public)]"
        )

        let event = SecurityEvent(
            eventType: .responseRedacted,
            threatLevel: .high,
            details: "Response redacted: \(count) credential(s) of type [\(typeList)]"
        )
        appendEvent(event)
    }

    // MARK: - Event Buffer Access

    /// Returns a copy of the recent security events.
    ///
    /// Events are ordered from oldest to newest. The buffer holds at most
    /// `maxBufferSize` (100) events.
    ///
    /// - Returns: Array of recent SecurityEvent instances.
    func getRecentEvents() -> [SecurityEvent] {
        lock.lock()
        defer { lock.unlock() }
        return recentEvents
    }

    /// Clears the in-memory event buffer.
    func clearEvents() {
        lock.lock()
        defer { lock.unlock() }
        recentEvents.removeAll()
    }

    /// Returns the number of events currently in the buffer.
    var eventCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return recentEvents.count
    }

    // MARK: - Private Helpers

    /// Masks a phone number to show only the last 4 digits.
    ///
    /// - Parameter phoneNumber: The full phone number (e.g., "+15551234567").
    /// - Returns: A masked string (e.g., "...4567"). Returns "...????" if too short.
    private func maskPhoneNumber(_ phoneNumber: String) -> String {
        guard phoneNumber.count >= 4 else { return "...????" }
        return "...\(phoneNumber.suffix(4))"
    }

    /// Appends a security event to the in-memory buffer.
    /// Removes the oldest event if the buffer is full.
    private func appendEvent(_ event: SecurityEvent) {
        lock.lock()
        defer { lock.unlock() }

        recentEvents.append(event)
        if recentEvents.count > maxBufferSize {
            recentEvents.removeFirst()
        }
    }
}
```

STEP 5: Create unit tests

File: tests/SecurityLoggerTests.swift
```swift
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
        XCTAssertEqual(allTypes.count, 8)
        XCTAssertTrue(allTypes.contains(.injectionDetected))
        XCTAssertTrue(allTypes.contains(.credentialDetected))
        XCTAssertTrue(allTypes.contains(.groupChatBlocked))
        XCTAssertTrue(allTypes.contains(.unauthorizedNumber))
        XCTAssertTrue(allTypes.contains(.messageBlocked))
        XCTAssertTrue(allTypes.contains(.messageAllowed))
        XCTAssertTrue(allTypes.contains(.responseRedacted))
        XCTAssertTrue(allTypes.contains(.responseAllowed))
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
```

STEP 6: Update TronPipeline to use SecurityLogger

After creating the logging infrastructure, update src/Security/TronPipeline.swift to use the SecurityLogger alongside the existing os.Logger calls. The SecurityLogger adds structured event tracking; the os.Logger calls can remain for the unified log. Add SecurityLogger calls in these locations:

In processInbound():
- After blocking a group chat: call `SecurityLogger.shared.logGroupChatBlock(phoneNumber:)`
- After ignoring an unauthorized number: call `SecurityLogger.shared.logUnauthorizedNumber(phoneNumber:)`
- After blocking an injection: call `SecurityLogger.shared.logInjectionAttempt(patternIds:threatLevel:phoneNumber:)`
- After allowing a message: call `SecurityLogger.shared.logMessageAllowed(phoneNumber:)`

In processOutbound():
- After redacting credentials: call `SecurityLogger.shared.logResponseRedacted(types:count:)`
- After allowing a response: call `SecurityLogger.shared.logResponseAllowed()`

Do NOT remove the existing os.Logger calls in TronPipeline — the SecurityLogger is an ADDITION for structured event tracking. Both can coexist.

IMPORTANT IMPLEMENTATION NOTES:
- Test file goes at `tests/SecurityLoggerTests.swift` (flat directory structure).
- Source files go in `src/Logging/` — create this directory if it does not exist.
- SecurityLogger uses @unchecked Sendable because it uses NSLock for thread safety.
- The shared singleton is fine for production use. Tests should create fresh instances.
- AppLogger is an enum (not a class) — it has no instances, only static methods.
- The event buffer is a simple array with a cap of 100 events. This is for MVP.
- Phone number masking: show only the last 4 digits, prefixed with "...".
- When updating TronPipeline, do NOT remove existing os.Logger calls — add SecurityLogger calls alongside them.

FINAL CHECKS:
1. All files compile with `swift build`
2. All tests pass with `swift test --filter SecurityLoggerTests`
3. All previous tests still pass
4. No calls to Process(), /bin/bash, or shell execution
5. No message content appears in any event details
6. No full phone numbers appear in any event details
7. SecurityLogger is thread-safe (concurrent tests pass)
8. All public types and methods have documentation comments
```

---

## Acceptance Criteria

- [ ] `src/Logging/AppLogger.swift` exists with `AppLogger` enum and `LogCategory` enum
- [ ] `src/Logging/SecurityEventType.swift` exists with all 8 security event types
- [ ] `src/Logging/SecurityEvent.swift` exists with timestamp, eventType, threatLevel, details
- [ ] `src/Logging/SecurityLogger.swift` exists with all 8 logging methods
- [ ] AppLogger subsystem is "com.emberhearth"
- [ ] LogCategory has 6 categories: app, security, messages, memory, llm, network
- [ ] SecurityLogger masks phone numbers to last 4 digits in all methods
- [ ] SecurityLogger NEVER logs message content or credential values
- [ ] Event buffer holds last 100 events, oldest removed when full
- [ ] "Allowed" events are NOT stored in buffer (routine events)
- [ ] SecurityLogger is thread-safe (concurrent read/write tests pass)
- [ ] TronPipeline updated to call SecurityLogger in addition to existing logging
- [ ] `tests/SecurityLoggerTests.swift` exists with comprehensive tests
- [ ] All tests pass with `swift test --filter SecurityLoggerTests`
- [ ] All previous tests still pass
- [ ] `swift build` succeeds with no errors

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Logging/AppLogger.swift && echo "AppLogger.swift exists" || echo "MISSING"
test -f src/Logging/SecurityEventType.swift && echo "SecurityEventType.swift exists" || echo "MISSING"
test -f src/Logging/SecurityEvent.swift && echo "SecurityEvent.swift exists" || echo "MISSING"
test -f src/Logging/SecurityLogger.swift && echo "SecurityLogger.swift exists" || echo "MISSING"
test -f tests/SecurityLoggerTests.swift && echo "Test file exists" || echo "MISSING"

# Verify no sensitive data in log calls (search for message interpolation)
grep -n 'message\b' src/Logging/SecurityLogger.swift | grep -v "//\|///\|Message blocked\|message_blocked\|message_allowed" && echo "Check for message content leaks" || echo "OK"

# Verify phone masking
grep -n "maskPhoneNumber" src/Logging/SecurityLogger.swift && echo "Phone masking found" || echo "WARNING: No phone masking"

# Verify no shell execution
grep -rn "Process()" src/Logging/ && echo "WARNING" || echo "OK: No Process() calls"

# Verify TronPipeline was updated
grep -n "SecurityLogger" src/Security/TronPipeline.swift && echo "TronPipeline updated with SecurityLogger" || echo "WARNING: TronPipeline not updated"

# Build the project
swift build 2>&1

# Run logger tests
swift test --filter SecurityLoggerTests 2>&1

# Run ALL tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the logging infrastructure created in task 0503 for EmberHearth. Check for these specific issues:

1. SECURITY REVIEW (Critical):
   - Open src/Logging/SecurityLogger.swift
   - For EVERY logging method, verify that:
     a. Message content is NEVER logged (not even the first N characters)
     b. Credential values are NEVER logged (only type names like "Anthropic API Key")
     c. Full phone numbers are NEVER logged (only last 4 digits via maskPhoneNumber)
   - For EVERY SecurityEvent stored in the buffer, verify the `details` string cannot contain raw user data
   - Verify maskPhoneNumber correctly extracts only the last 4 digits
   - Verify os.Logger privacy annotations: user data uses .private, only safe values use .public

2. THREAD SAFETY (Critical):
   - Verify NSLock is used correctly (lock/unlock paired, defer used)
   - Verify there are no deadlocks possible (no nested locks, no lock+await)
   - Verify the concurrent read/write test actually tests concurrency (uses DispatchQueue.concurrent)
   - Verify SecurityLogger is marked @unchecked Sendable (because of NSLock)
   - Verify all public methods that access recentEvents use the lock

3. EVENT BUFFER:
   - Verify buffer caps at 100 events
   - Verify oldest events are removed when buffer is full (FIFO, not LIFO)
   - Verify "allowed" events (messageAllowed, responseAllowed) are NOT stored in the buffer
   - Verify clearEvents() properly empties the buffer

4. APPLOGGER:
   - Verify AppLogger.subsystem is "com.emberhearth"
   - Verify LogCategory has exactly 6 categories (app, security, messages, memory, llm, network)
   - Verify AppLogger returns cached Logger instances (not creating new ones each call)
   - Verify AppLogger is an enum (stateless, not instantiable)

5. TRON PIPELINE INTEGRATION:
   - Open src/Security/TronPipeline.swift
   - Verify SecurityLogger calls were ADDED (not replacing existing os.Logger calls)
   - Verify every pipeline decision point has a corresponding SecurityLogger call:
     - Group chat block → logGroupChatBlock
     - Unauthorized number → logUnauthorizedNumber
     - Injection detected → logInjectionAttempt
     - Message allowed → logMessageAllowed
     - Response redacted → logResponseRedacted
     - Response allowed → logResponseAllowed

6. TYPE SAFETY:
   - Verify SecurityEvent is Sendable
   - Verify SecurityEventType is Sendable
   - Verify LogCategory is Sendable
   - Verify no force-unwraps (!) exist in any logging files

7. TEST QUALITY:
   - Verify there are tests for every logging method
   - Verify there are tests for phone number masking (including edge cases)
   - Verify there are concurrent access tests
   - Verify there are tests verifying no sensitive data in event details
   - Verify there are buffer capacity tests

8. BUILD VERIFICATION:
   - Run `swift build` and verify it succeeds
   - Run `swift test --filter SecurityLoggerTests` and verify all tests pass
   - Run `swift test` to verify ALL tests pass

Report any issues found with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m6): add security and application logging infrastructure
```

---

## Notes for Next Task

- `SecurityLogger.shared` is the singleton for production use. Task 0504 (MessageCoordinator) should use it for all security-related logging.
- `AppLogger.logger(for: .messages)` should be used by MessageCoordinator for message processing events (without message content).
- `AppLogger.logger(for: .llm)` should be used by ClaudeAPIClient (task 0201) for LLM API events (without API keys or response content).
- `AppLogger.logger(for: .memory)` should be used by memory system components (tasks 0300-0304).
- The SecurityLogger event buffer (`getRecentEvents()`) is intended for a future settings UI that shows recent security events. Task 0503 just stores them; a future onboarding/settings task will display them.
- The TronPipeline now calls both os.Logger (unified log) and SecurityLogger (structured events). Task 0504 should use the SecurityLogger directly for its own security-relevant decisions.
