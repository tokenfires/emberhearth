// ScanResult.swift
// EmberHearth
//
// Result of an injection scan on a message.

import Foundation

/// The result of scanning a message for prompt injection patterns.
///
/// Contains the overall threat level (the highest severity among all matched
/// patterns), the list of matched pattern IDs, and the original message.
/// The scanner does NOT modify messages — it either allows or blocks them.
struct ScanResult: Sendable {
    /// The highest threat level among all matched patterns.
    /// `.none` if no patterns matched.
    let threatLevel: ThreatLevel

    /// The IDs and descriptions of all patterns that matched.
    /// Empty if threatLevel is `.none`.
    let matchedPatterns: [MatchedPattern]

    /// The original message that was scanned. Included for caller convenience.
    /// NEVER log this value — it may contain the injection payload.
    let originalMessage: String

    /// Whether the message should be blocked based on threat level.
    /// Messages with `.critical` or `.high` threat levels are blocked.
    var shouldBlock: Bool {
        threatLevel >= .high
    }

    /// A single pattern match with its ID and description.
    struct MatchedPattern: Sendable {
        /// The pattern ID (e.g., "PI-001").
        let patternId: String
        /// The pattern description (e.g., "Instruction override attempt").
        let description: String
        /// The severity of this specific pattern.
        let severity: ThreatLevel
    }

    /// Creates a clean (no threat) scan result.
    static func clean(message: String) -> ScanResult {
        ScanResult(threatLevel: .none, matchedPatterns: [], originalMessage: message)
    }
}
