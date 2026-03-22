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
