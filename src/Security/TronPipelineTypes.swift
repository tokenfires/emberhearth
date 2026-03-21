// TronPipelineTypes.swift
// EmberHearth
//
// Result types for the Tron security pipeline.

import Foundation

/// Result of processing an inbound message through the security pipeline.
enum InboundResult: Sendable {
    /// Message passed all security checks. Contains the original message text.
    case allowed(String)

    /// Message was blocked by a security check. Contains the reason for blocking.
    /// The reason is safe to log but should NOT be shown to the user verbatim.
    /// Ember should rephrase the block reason in a friendly way.
    case blocked(reason: String)

    /// Message was ignored (e.g., from an unauthorized phone number).
    /// No response should be sent.
    case ignored
}

/// Result of processing an outbound LLM response through the security pipeline.
enum OutboundResult: Sendable {
    /// Response passed all security checks. Contains the original response text.
    case allowed(String)

    /// Response contained credentials that were redacted. Contains the cleaned response.
    case redacted(String)
}
