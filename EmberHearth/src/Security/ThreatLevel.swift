// ThreatLevel.swift
// EmberHearth
//
// Threat severity levels for security events.

import Foundation

/// Severity levels for security threats detected by the Tron security layer.
///
/// Based on the EmberHearth threat model:
/// - `.critical`: Block, no override allowed. Example: ethics bypass attempt.
/// - `.high`: Block, admin override only. Example: clear injection signature.
/// - `.medium`: Warn, allow with user confirmation. Example: suspicious but uncertain pattern.
/// - `.low`: Log only. Example: unusual but likely benign.
/// - `.none`: No threat detected.
enum ThreatLevel: Int, Comparable, Sendable, CaseIterable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    static func < (lhs: ThreatLevel, rhs: ThreatLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Human-readable label for logging (never include in user-facing messages).
    var label: String {
        switch self {
        case .none: return "none"
        case .low: return "low"
        case .medium: return "medium"
        case .high: return "high"
        case .critical: return "critical"
        }
    }
}
