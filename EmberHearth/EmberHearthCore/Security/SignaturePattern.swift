// SignaturePattern.swift
// EmberHearth
//
// Model for injection detection signature patterns.

import Foundation

/// A single injection detection signature with its compiled regex.
///
/// Each pattern has a unique ID (e.g., "PI-001"), a regex pattern string,
/// a severity level, and a human-readable description for logging.
/// The regex is pre-compiled at initialization time for performance.
struct SignaturePattern: Sendable {
    /// Unique identifier for this pattern (e.g., "PI-001", "JB-002").
    let id: String

    /// The raw regex pattern string.
    let pattern: String

    /// The pre-compiled NSRegularExpression. Nil if the pattern failed to compile.
    let compiledRegex: NSRegularExpression?

    /// Threat severity if this pattern matches.
    let severity: ThreatLevel

    /// Human-readable description for logging. Never shown to users.
    let description: String

    /// Creates a SignaturePattern with a pre-compiled regex.
    ///
    /// - Parameters:
    ///   - id: Unique pattern identifier (e.g., "PI-001").
    ///   - pattern: Regex pattern string. Compiled with case-insensitive flag.
    ///   - severity: Threat level if matched.
    ///   - description: Human-readable description for logging.
    init(id: String, pattern: String, severity: ThreatLevel, description: String) {
        self.id = id
        self.pattern = pattern
        self.severity = severity
        self.description = description
        self.compiledRegex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        )
    }
}
