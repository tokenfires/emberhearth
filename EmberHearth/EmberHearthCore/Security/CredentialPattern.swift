// CredentialPattern.swift
// EmberHearth
//
// Model for credential detection patterns used by the outbound scanner.

import Foundation

/// A credential detection pattern with a pre-compiled regex.
///
/// Each pattern identifies a specific type of credential (API key, token, etc.)
/// and has a severity level indicating how dangerous the leak would be.
struct CredentialPattern: Sendable {
    /// Unique identifier for this pattern (e.g., "CRED-001").
    let id: String

    /// Human-readable name for this credential type (e.g., "OpenAI API Key").
    /// Used in log messages and redaction placeholders. NEVER include the actual value.
    let name: String

    /// The raw regex pattern string.
    let pattern: String

    /// The pre-compiled NSRegularExpression. Nil if the pattern failed to compile.
    let compiledRegex: NSRegularExpression?

    /// Threat severity if this pattern matches.
    let severity: ThreatLevel

    /// Creates a CredentialPattern with a pre-compiled regex.
    ///
    /// - Parameters:
    ///   - id: Unique pattern identifier (e.g., "CRED-001").
    ///   - name: Human-readable credential type name.
    ///   - pattern: Regex pattern string. Compiled without case-insensitive flag
    ///     (credential patterns are typically case-sensitive).
    ///   - severity: Threat level if matched.
    ///   - caseInsensitive: Whether to compile with case-insensitive flag. Defaults to false.
    init(id: String, name: String, pattern: String, severity: ThreatLevel, caseInsensitive: Bool = false) {
        self.id = id
        self.name = name
        self.pattern = pattern
        self.severity = severity

        var options: NSRegularExpression.Options = []
        if caseInsensitive {
            options.insert(.caseInsensitive)
        }
        self.compiledRegex = try? NSRegularExpression(pattern: pattern, options: options)
    }
}
