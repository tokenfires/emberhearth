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

    /// A crisis signal was detected in the message.
    ///
    /// The caller (MessageCoordinator) must prepend `crisisResponse` to (or use it
    /// instead of) the LLM response. The original message is still passed to the LLM
    /// for normal conversation — Ember does NOT go silent after a crisis detection.
    ///
    /// - Parameters:
    ///   - message: The original message text, to be passed to the LLM as normal.
    ///   - tier: The detected crisis severity tier.
    ///   - crisisResponse: The pre-written static response to prepend to the LLM reply.
    case crisis(message: String, tier: CrisisTier, crisisResponse: String)
}

/// Result of processing an outbound LLM response through the security pipeline.
enum OutboundResult: Sendable {
    /// Response passed all security checks. Contains the original response text.
    case allowed(String)

    /// Response contained credentials that were redacted. Contains the cleaned response.
    case redacted(String)
}
