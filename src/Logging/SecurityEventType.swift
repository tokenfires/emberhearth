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
