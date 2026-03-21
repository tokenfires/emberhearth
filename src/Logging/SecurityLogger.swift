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
