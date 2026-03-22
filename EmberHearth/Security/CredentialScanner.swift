// CredentialScanner.swift
// EmberHearth
//
// Scans outbound LLM responses for accidentally leaked credentials.

import Foundation
import os

/// Scans outbound LLM responses for accidentally leaked credentials,
/// API keys, tokens, private keys, and other sensitive patterns.
///
/// When credentials are detected, they are replaced with `[REDACTED]`
/// in the output. The scanner NEVER logs the actual credential values —
/// only the type of credential detected.
///
/// ## Performance
/// All regex patterns are pre-compiled at initialization. Typical scan time
/// is <10ms for responses under 10,000 characters.
///
/// ## Usage
/// ```swift
/// let scanner = CredentialScanner()
/// let result = scanner.scanOutput(response: llmResponseText)
/// if result.containsCredentials {
///     // Use result.redactedResponse instead of the original
///     sendMessage(result.redactedResponse)
/// } else {
///     sendMessage(llmResponseText)
/// }
/// ```
final class CredentialScanner: Sendable {

    // MARK: - Properties

    /// All credential patterns used for detection. Pre-compiled at init.
    let patterns: [CredentialPattern]

    /// Logger for security events. NEVER logs credential values.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "CredentialScanner"
    )

    // MARK: - Initialization

    /// Creates a CredentialScanner with the default pattern set.
    init() {
        self.patterns = Self.defaultPatterns
    }

    /// Creates a CredentialScanner with custom patterns (for testing).
    ///
    /// - Parameter patterns: The credential patterns to use for scanning.
    init(patterns: [CredentialPattern]) {
        self.patterns = patterns
    }

    // MARK: - Scanning

    /// Scans an outbound LLM response for credential leaks.
    ///
    /// If credentials are found, they are replaced with `[REDACTED]` in the
    /// returned result. The original response text is NOT stored in the result.
    ///
    /// - Parameter response: The LLM response text to scan.
    /// - Returns: A `CredentialScanResult` with the redacted response and detection info.
    func scanOutput(response: String) -> CredentialScanResult {
        guard !response.isEmpty else {
            return .clean(response: response)
        }

        var allMatches: [(range: Range<String.Index>, patternName: String)] = []

        for pattern in patterns {
            guard let regex = pattern.compiledRegex else { continue }
            let nsRange = NSRange(response.startIndex..., in: response)
            let regexMatches = regex.matches(in: response, options: [], range: nsRange)

            for match in regexMatches {
                guard let swiftRange = Range(match.range, in: response) else { continue }
                let matchedText = String(response[swiftRange])

                // Additional validation for specific pattern types
                if pattern.id == "CRED-PII-002" {
                    // Credit card: validate with Luhn algorithm
                    let digitsOnly = matchedText.filter(\.isNumber)
                    guard luhnCheck(digitsOnly) else { continue }
                }

                allMatches.append((range: swiftRange, patternName: pattern.name))
            }
        }

        guard !allMatches.isEmpty else {
            return .clean(response: response)
        }

        // Sort by start position ascending to merge overlapping ranges.
        // Without merging, replacing one range invalidates String.Index
        // values for any overlapping range (e.g., Bearer wrapping a JWT).
        let sortedAsc = allMatches.sorted { $0.range.lowerBound < $1.range.lowerBound }

        var mergedRanges: [Range<String.Index>] = []
        for match in sortedAsc {
            if let last = mergedRanges.last, match.range.lowerBound < last.upperBound {
                let newUpper = max(last.upperBound, match.range.upperBound)
                mergedRanges[mergedRanges.count - 1] = last.lowerBound..<newUpper
            } else {
                mergedRanges.append(match.range)
            }
        }

        // Replace from end to start so earlier ranges stay valid
        var redacted = response
        for range in mergedRanges.reversed() {
            redacted.replaceSubrange(range, with: "[REDACTED]")
        }

        // Collect unique detected types
        let uniqueTypes = Array(Set(allMatches.map(\.patternName))).sorted()

        // Log the detection (NEVER log the actual credential values)
        Self.logger.warning(
            "Credential scan detected \(allMatches.count, privacy: .public) credential(s) of type(s): \(uniqueTypes.joined(separator: ", "), privacy: .public)"
        )

        return CredentialScanResult(
            containsCredentials: true,
            redactedResponse: redacted,
            detectedTypes: uniqueTypes,
            matchCount: allMatches.count
        )
    }

    // MARK: - Luhn Algorithm

    /// Validates a number string using the Luhn algorithm (credit card checksum).
    ///
    /// - Parameter number: A string of digits to validate.
    /// - Returns: True if the number passes the Luhn check.
    private func luhnCheck(_ number: String) -> Bool {
        let digits = number.compactMap { $0.wholeNumberValue }
        guard digits.count >= 13 && digits.count <= 19 else { return false }

        var sum = 0
        let reversedDigits = digits.reversed().enumerated()

        for (index, digit) in reversedDigits {
            if index % 2 == 1 {
                let doubled = digit * 2
                sum += doubled > 9 ? doubled - 9 : doubled
            } else {
                sum += digit
            }
        }

        return sum % 10 == 0
    }

    // MARK: - Default Patterns

    /// The default set of credential detection patterns for MVP.
    ///
    /// Sourced from the EmberHearth tron-security.md specification and
    /// industry pattern databases (secret-regex-list, LLM Guard).
    static let defaultPatterns: [CredentialPattern] = [

        // =============================================
        // API KEYS — Cloud AI Providers
        // =============================================

        CredentialPattern(
            id: "CRED-001",
            name: "Anthropic API Key",
            // Anthropic keys: sk-ant-api03-... with alphanumeric and hyphens
            pattern: #"sk-ant-api03-[A-Za-z0-9_\-]{20,}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-002",
            name: "OpenAI API Key",
            // OpenAI keys: sk- followed by 48+ alphanumeric chars (excludes Anthropic prefix)
            pattern: #"sk-(?!ant-)[A-Za-z0-9]{48,}"#,
            severity: .critical
        ),

        // =============================================
        // API KEYS — Cloud Providers
        // =============================================

        CredentialPattern(
            id: "CRED-003",
            name: "AWS Access Key ID",
            // AWS access keys always start with AKIA followed by 16 uppercase alphanumeric
            pattern: #"AKIA[A-Z0-9]{16}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-004",
            name: "AWS Secret Access Key",
            // AWS secrets near "aws" keyword, 40 chars in quotes
            pattern: #"(?i)aws.{0,20}['"][0-9a-zA-Z/+]{40}['"]"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-005",
            name: "Google API Key",
            pattern: #"AIza[0-9A-Za-z\-_]{35}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-006",
            name: "Google OAuth Token",
            pattern: #"ya29\.[0-9A-Za-z\-_]+"#,
            severity: .critical
        ),

        // =============================================
        // VERSION CONTROL
        // =============================================

        CredentialPattern(
            id: "CRED-007",
            name: "GitHub Personal Access Token",
            pattern: #"ghp_[0-9a-zA-Z]{36}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-008",
            name: "GitHub OAuth Token",
            pattern: #"gho_[0-9a-zA-Z]{36}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-009",
            name: "GitHub User Token",
            pattern: #"ghu_[0-9a-zA-Z]{36}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-010",
            name: "GitHub Server Token",
            pattern: #"ghs_[0-9a-zA-Z]{36}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-011",
            name: "GitHub Refresh Token",
            pattern: #"ghr_[0-9a-zA-Z]{36}"#,
            severity: .critical
        ),

        // =============================================
        // PAYMENT PROVIDERS
        // =============================================

        CredentialPattern(
            id: "CRED-012",
            name: "Stripe Live Secret Key",
            pattern: #"sk_live_[0-9a-zA-Z]{24,}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-013",
            name: "Stripe Live Publishable Key",
            pattern: #"pk_live_[0-9a-zA-Z]{24,}"#,
            severity: .high
        ),
        CredentialPattern(
            id: "CRED-014",
            name: "Stripe Test Secret Key",
            pattern: #"sk_test_[0-9a-zA-Z]{24,}"#,
            severity: .medium
        ),
        CredentialPattern(
            id: "CRED-015",
            name: "Stripe Test Publishable Key",
            pattern: #"pk_test_[0-9a-zA-Z]{24,}"#,
            severity: .low
        ),

        // =============================================
        // COMMUNICATION SERVICES
        // =============================================

        CredentialPattern(
            id: "CRED-016",
            name: "Slack Bot Token",
            pattern: #"xoxb-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24,}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-017",
            name: "Slack User Token",
            pattern: #"xoxp-[0-9]{10,13}-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{32}"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-018",
            name: "Slack App Token",
            pattern: #"xapp-[0-9]-[A-Z0-9]{10,}-[0-9]{10,}-[a-zA-Z0-9]{64}"#,
            severity: .critical
        ),

        // =============================================
        // GENERIC PATTERNS
        // =============================================

        CredentialPattern(
            id: "CRED-019",
            name: "Generic API Key Assignment",
            // Matches: api_key = "abc123...", apikey: 'xyz789...', secret-key="..."
            pattern: #"(?i)(api[_\-]?key|apikey|secret[_\-]?key)\s*[:=]\s*['"]?[A-Za-z0-9_\-]{20,}['"]?"#,
            severity: .medium
        ),
        CredentialPattern(
            id: "CRED-020",
            name: "Bearer Token",
            // Matches: Bearer eyJ..., Authorization: Bearer xxx
            pattern: #"Bearer\s+[A-Za-z0-9\-._~+/]{20,}={0,2}"#,
            severity: .high
        ),
        CredentialPattern(
            id: "CRED-021",
            name: "Generic Secret Assignment",
            // Matches: secret = "abc...", secret_key: 'xyz...'
            pattern: #"(?i)secret[_\-]?\s*[:=]\s*['"]?[A-Za-z0-9_\-]{16,}['"]?"#,
            severity: .medium
        ),

        // =============================================
        // CERTIFICATES & PRIVATE KEYS
        // =============================================

        CredentialPattern(
            id: "CRED-022",
            name: "RSA Private Key",
            pattern: #"-----BEGIN RSA PRIVATE KEY-----"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-023",
            name: "EC Private Key",
            pattern: #"-----BEGIN EC PRIVATE KEY-----"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-024",
            name: "DSA Private Key",
            pattern: #"-----BEGIN DSA PRIVATE KEY-----"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-025",
            name: "Generic Private Key",
            pattern: #"-----BEGIN PRIVATE KEY-----"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-026",
            name: "OpenSSH Private Key",
            pattern: #"-----BEGIN OPENSSH PRIVATE KEY-----"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-027",
            name: "PGP Private Key",
            pattern: #"-----BEGIN PGP PRIVATE KEY BLOCK-----"#,
            severity: .critical
        ),

        // =============================================
        // SSH KEYS
        // =============================================

        CredentialPattern(
            id: "CRED-028",
            name: "SSH Public Key (RSA)",
            // SSH public keys: ssh-rsa followed by base64 data
            pattern: #"ssh-rsa\s+[A-Za-z0-9+/]{100,}"#,
            severity: .medium
        ),
        CredentialPattern(
            id: "CRED-029",
            name: "SSH Public Key (Ed25519)",
            pattern: #"ssh-ed25519\s+[A-Za-z0-9+/]{40,}"#,
            severity: .medium
        ),

        // =============================================
        // TOKENS & AUTH
        // =============================================

        CredentialPattern(
            id: "CRED-030",
            name: "JWT Token",
            // JWT format: header.payload.signature (each base64url encoded)
            pattern: #"eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"#,
            severity: .high
        ),

        // =============================================
        // DATABASE CONNECTION STRINGS
        // =============================================

        CredentialPattern(
            id: "CRED-031",
            name: "Database Connection String",
            // Matches: mongodb://user:pass@host, postgres://user:pass@host, mysql://user:pass@host, redis://user:pass@host
            pattern: #"(mongodb|postgres|postgresql|mysql|redis|amqp):\/\/[^:\s]+:[^@\s]+@[^\s]+"#,
            severity: .critical,
            caseInsensitive: true
        ),
        CredentialPattern(
            id: "CRED-032",
            name: "Password in URL",
            // Generic pattern for credentials embedded in URLs
            pattern: #"https?:\/\/[^:\s]+:[^@\s]+@[^\s]+"#,
            severity: .high
        ),

        // =============================================
        // PII — Included in MVP for Credential Scanner
        // =============================================

        CredentialPattern(
            id: "CRED-PII-001",
            name: "US Social Security Number",
            // Matches: 123-45-6789 (but not 000-00-0000 or 999-99-9999)
            pattern: #"\b(?!000|999)(?!.{4}00)(?!.{7}0000)\d{3}-\d{2}-\d{4}\b"#,
            severity: .critical
        ),
        CredentialPattern(
            id: "CRED-PII-002",
            name: "Credit Card Number",
            // Matches common card formats: Visa, MC, Amex, Discover
            // Spaces or hyphens optional. Luhn validation done separately.
            pattern: #"\b(?:4[0-9]{3}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}|5[1-5][0-9]{2}[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4}|3[47][0-9]{2}[\s-]?[0-9]{6}[\s-]?[0-9]{5}|6(?:011|5[0-9]{2})[\s-]?[0-9]{4}[\s-]?[0-9]{4}[\s-]?[0-9]{4})\b"#,
            severity: .critical
        ),
    ]
}
