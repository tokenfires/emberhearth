// TronPipelineConfig.swift
// EmberHearth
//
// Configuration for the Tron security pipeline.

import Foundation

/// Configuration for the Tron security pipeline.
///
/// For MVP, this uses sensible defaults. Future versions will allow
/// user customization via the Mac app settings UI.
struct TronPipelineConfig: Sendable {
    /// Phone numbers allowed to interact with Ember.
    /// Empty means all numbers are allowed (not recommended for production).
    /// Phone numbers should be in E.164 format (e.g., "+15551234567").
    let allowedPhoneNumbers: Set<String>

    /// Whether to block group chat messages entirely.
    /// MVP default: true (group chats are blocked).
    let blockGroupChats: Bool

    /// The minimum threat level that causes an inbound message to be blocked.
    /// Messages at this level or above are blocked. Below this level, they are allowed.
    /// MVP default: .high (critical and high are blocked; medium and low are allowed with logging).
    let inboundBlockThreshold: ThreatLevel

    /// Whether to enable credential scanning on outbound responses.
    /// MVP default: true.
    let enableCredentialScanning: Bool

    /// Whether to enable injection scanning on inbound messages.
    /// MVP default: true.
    let enableInjectionScanning: Bool

    /// Creates a pipeline configuration with sensible MVP defaults.
    ///
    /// - Parameter allowedPhoneNumbers: Set of phone numbers in E.164 format.
    ///   If empty, phone number filtering is disabled (all numbers allowed).
    init(
        allowedPhoneNumbers: Set<String> = [],
        blockGroupChats: Bool = true,
        inboundBlockThreshold: ThreatLevel = .high,
        enableCredentialScanning: Bool = true,
        enableInjectionScanning: Bool = true
    ) {
        self.allowedPhoneNumbers = allowedPhoneNumbers
        self.blockGroupChats = blockGroupChats
        self.inboundBlockThreshold = inboundBlockThreshold
        self.enableCredentialScanning = enableCredentialScanning
        self.enableInjectionScanning = enableInjectionScanning
    }

    /// Default MVP configuration.
    static let `default` = TronPipelineConfig()
}
