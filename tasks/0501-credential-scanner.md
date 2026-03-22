# Task 0501: Credential Scanner for Outbound Response Filtering

**Milestone:** M6 - Security Basics
**Unit:** 6.4 - Credential Filtering in Output
**Phase:** 3
**Depends On:** 0500
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; naming conventions, security boundaries, project structure
2. `docs/specs/tron-security.md` — Focus on Section 4.1 "Credential Detection" (lines ~490-672) for the full credential pattern list with 20 patterns and the scan/redact approach. Also Section 4.2 "PII Detection" (lines ~675-772) for SSN and credit card patterns (we include these in MVP for credential scanning).
3. `src/Security/ThreatLevel.swift` — Reuse the ThreatLevel enum from task 0500
4. `src/Security/InjectionScanner.swift` — Reference the pattern and scan approach for consistency

> **Context Budget Note:** tron-security.md is ~1900 lines. Focus only on Section 4.1 (credential detection, lines 490-672) and Section 4.2 (PII detection, lines 675-772). Skip everything else.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the Credential Scanner for EmberHearth, a native macOS personal AI assistant. This component scans OUTBOUND messages (LLM responses before they are sent to the user via iMessage) for accidentally leaked credentials, API keys, tokens, and sensitive patterns. It is the outbound half of the Tron security layer.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., CredentialScanner.swift)
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target
- No third-party dependencies — use only Apple frameworks

PROJECT CONTEXT:
- This is a Swift Package Manager project
- Package.swift has the main target at path "src" and test target at path "tests"
- Task 0500 already created: src/Security/ThreatLevel.swift, src/Security/SignaturePattern.swift, src/Security/ScanResult.swift, src/Security/InjectionScanner.swift
- You are REUSING the ThreatLevel enum from task 0500 — do NOT recreate it
- This scanner is for OUTBOUND messages only (LLM responses), not inbound

WHAT YOU ARE BUILDING:
An outbound response scanner that detects accidentally leaked credentials in LLM responses, redacts them, and returns a clean response. The scanner must be fast (<10ms) and have a low false positive rate.

STEP 1: Create the CredentialPattern model

File: src/Security/CredentialPattern.swift
```swift
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
```

STEP 2: Create the CredentialScanResult model

File: src/Security/CredentialScanResult.swift
```swift
// CredentialScanResult.swift
// EmberHearth
//
// Result of scanning an outbound response for credentials.

import Foundation

/// The result of scanning an outbound LLM response for credential leaks.
///
/// If credentials are detected, `containsCredentials` is true and
/// `redactedResponse` contains the response with credentials replaced
/// by `[REDACTED]` placeholders. The original response is NOT stored
/// to avoid keeping credentials in memory longer than necessary.
struct CredentialScanResult: Sendable {
    /// Whether any credentials were detected in the response.
    let containsCredentials: Bool

    /// The response with any detected credentials replaced by `[REDACTED]`.
    /// If no credentials were detected, this is identical to the original response.
    let redactedResponse: String

    /// The types of credentials detected (e.g., ["OpenAI API Key", "GitHub Token"]).
    /// Used for logging. NEVER includes the actual credential values.
    let detectedTypes: [String]

    /// The number of individual credential matches found.
    let matchCount: Int

    /// Creates a clean (no credentials) scan result.
    ///
    /// - Parameter response: The original response that passed clean.
    static func clean(response: String) -> CredentialScanResult {
        CredentialScanResult(
            containsCredentials: false,
            redactedResponse: response,
            detectedTypes: [],
            matchCount: 0
        )
    }
}
```

STEP 3: Create the CredentialScanner

File: src/Security/CredentialScanner.swift
```swift
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

        // Sort matches by range start position in reverse order
        // (process from end to start so ranges remain valid during replacement)
        let sortedMatches = allMatches.sorted { $0.range.lowerBound > $1.range.lowerBound }

        // Build the redacted response
        var redacted = response
        for match in sortedMatches {
            redacted.replaceSubrange(match.range, with: "[REDACTED]")
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
            // OpenAI keys: sk- followed by 48+ alphanumeric chars
            pattern: #"sk-[A-Za-z0-9]{48,}"#,
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
```

STEP 4: Create unit tests

File: tests/CredentialScannerTests.swift
```swift
// CredentialScannerTests.swift
// EmberHearth
//
// Unit tests for CredentialScanner.

import XCTest
@testable import EmberHearth

final class CredentialScannerTests: XCTestCase {

    private var scanner: CredentialScanner!

    override func setUp() {
        super.setUp()
        scanner = CredentialScanner()
    }

    override func tearDown() {
        scanner = nil
        super.tearDown()
    }

    // MARK: - Clean Responses (No Credentials)

    func testCleanResponses() {
        let cleanResponses = [
            "The weather today is sunny with a high of 72 degrees.",
            "Your meeting with Sarah is at 3pm in Conference Room B.",
            "Here's a recipe for chocolate chip cookies: mix flour, sugar, butter...",
            "Swift is a great programming language for macOS development.",
            "I'd recommend the hiking trail at Mount Tamalpais this weekend.",
            "To reset your password, go to Settings > Account > Change Password.",
            "",  // Empty response
        ]

        for response in cleanResponses {
            let result = scanner.scanOutput(response: response)
            XCTAssertFalse(
                result.containsCredentials,
                "False positive on clean response: \"\(response)\""
            )
            XCTAssertEqual(result.redactedResponse, response)
            XCTAssertTrue(result.detectedTypes.isEmpty)
            XCTAssertEqual(result.matchCount, 0)
        }
    }

    /// Normal text that mentions keys/secrets without actual credential values
    func testFalsePositiveResistance() {
        let legitimateResponses = [
            "The key to success is persistence and hard work.",
            "My secret recipe uses a special blend of spices.",
            "You can find the API documentation at developer.example.com.",
            "The bearer of good news arrived early today.",
            "The SSH protocol is used for secure communication.",
            "A JWT (JSON Web Token) is used for authentication.",
            "The database connection was lost for a moment.",
            "Your credit card statement is available online.",
            "The private key to understanding this is practice.",
            "Use a strong password for your accounts.",
            "The token of appreciation was a gift card.",
        ]

        for response in legitimateResponses {
            let result = scanner.scanOutput(response: response)
            XCTAssertFalse(
                result.containsCredentials,
                "False positive on legitimate response: \"\(response)\""
            )
        }
    }

    // MARK: - API Key Detection

    func testAnthropicAPIKeyDetection() {
        let response = "Your Anthropic key is sk-ant-api03-ABC123DEF456GHI789JKL012MNO345PQR678STU901"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Anthropic API Key"))
        XCTAssertTrue(result.redactedResponse.contains("[REDACTED]"))
        XCTAssertFalse(result.redactedResponse.contains("sk-ant-api03"))
    }

    func testOpenAIAPIKeyDetection() {
        let response = "The key is sk-abcdefghijklmnopqrstuvwxyz012345678901234567890123"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("OpenAI API Key"))
        XCTAssertFalse(result.redactedResponse.contains("sk-abcdefghijklmnop"))
    }

    func testAWSAccessKeyDetection() {
        let response = "Your AWS key is AKIAIOSFODNN7EXAMPLE"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("AWS Access Key ID"))
        XCTAssertFalse(result.redactedResponse.contains("AKIA"))
    }

    func testGoogleAPIKeyDetection() {
        let response = "The API key is AIzaSyA1234567890abcdefghijklmnopqrstuv"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Google API Key"))
    }

    // MARK: - GitHub Token Detection

    func testGitHubPATDetection() {
        let response = "Use this token: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("GitHub Personal Access Token"))
    }

    func testGitHubOAuthDetection() {
        let response = "OAuth: gho_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("GitHub OAuth Token"))
    }

    // MARK: - Payment Provider Detection

    func testStripeLiveKeyDetection() {
        let response = "The live key is sk_live_ABCDEFghijklmnopqrstuvwx"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Stripe Live Secret Key"))
    }

    func testStripeTestKeyDetection() {
        let response = "For testing use sk_test_ABCDEFghijklmnopqrstuvwx"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Stripe Test Secret Key"))
    }

    // MARK: - Slack Token Detection

    func testSlackBotTokenDetection() {
        let response = "Bot token: xoxb-1234567890123-1234567890123-ABCDEFGHIJKLMNOPqrstuvwx"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Slack Bot Token"))
    }

    // MARK: - Generic Pattern Detection

    func testGenericAPIKeyAssignment() {
        let response = "Set your api_key = \"ABCDEF1234567890GHIJKLMN\""
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Generic API Key Assignment"))
    }

    func testBearerTokenDetection() {
        let response = "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9abcdef1234567890"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Bearer Token"))
    }

    func testGenericSecretAssignment() {
        let response = "secret = \"ABCDefgh1234567890IJKL\""
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Generic Secret Assignment"))
    }

    // MARK: - Private Key Detection

    func testRSAPrivateKeyDetection() {
        let response = "Here's the key:\n-----BEGIN RSA PRIVATE KEY-----\nMIIBog..."
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("RSA Private Key"))
    }

    func testECPrivateKeyDetection() {
        let response = "-----BEGIN EC PRIVATE KEY-----\nMHQCAQ..."
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("EC Private Key"))
    }

    func testOpenSSHPrivateKeyDetection() {
        let response = "-----BEGIN OPENSSH PRIVATE KEY-----\nb3Blbn..."
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("OpenSSH Private Key"))
    }

    // MARK: - JWT Detection

    func testJWTDetection() {
        let response = "The token is eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("JWT Token"))
    }

    // MARK: - Database Connection Strings

    func testMongoDBConnectionString() {
        let response = "Connect with: mongodb://admin:password123@hostname.example.com:27017/mydb"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Database Connection String"))
        XCTAssertFalse(result.redactedResponse.contains("password123"))
    }

    func testPostgresConnectionString() {
        let response = "Use: postgres://user:secret@db.example.com:5432/production"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Database Connection String"))
    }

    func testPasswordInURL() {
        let response = "Access it at https://admin:supersecret@internal.example.com/dashboard"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Password in URL"))
    }

    // MARK: - PII Detection

    func testSSNDetection() {
        let response = "Your SSN is 123-45-6789"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("US Social Security Number"))
        XCTAssertFalse(result.redactedResponse.contains("123-45-6789"))
    }

    func testSSNExcludesInvalidPatterns() {
        // 000-xx-xxxx and 999-xx-xxxx are invalid SSNs
        let response1 = scanner.scanOutput(response: "Number: 000-12-3456")
        XCTAssertFalse(response1.containsCredentials, "000-xx-xxxx should not match as SSN")

        let response2 = scanner.scanOutput(response: "Number: 999-12-3456")
        XCTAssertFalse(response2.containsCredentials, "999-xx-xxxx should not match as SSN")
    }

    func testCreditCardDetection() {
        // Valid Visa number (passes Luhn)
        let response = "Card number: 4111 1111 1111 1111"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Credit Card Number"))
        XCTAssertFalse(result.redactedResponse.contains("4111"))
    }

    func testCreditCardLuhnValidation() {
        // A number that looks like a credit card but fails Luhn check
        let response = "Number: 4111 1111 1111 1112"
        let result = scanner.scanOutput(response: response)
        // Should NOT be detected because it fails Luhn
        XCTAssertFalse(
            result.detectedTypes.contains("Credit Card Number"),
            "Invalid Luhn number should not be flagged as credit card"
        )
    }

    // MARK: - Redaction Correctness

    func testRedactionReplacesCredentialOnly() {
        let response = "Before sk-ant-api03-ABCDEFGHIJ1234567890KLMNOP After"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.redactedResponse.hasPrefix("Before "))
        XCTAssertTrue(result.redactedResponse.hasSuffix(" After"))
        XCTAssertTrue(result.redactedResponse.contains("[REDACTED]"))
        XCTAssertFalse(result.redactedResponse.contains("sk-ant"))
    }

    func testMultipleCredentialRedaction() {
        let response = "Key 1: AKIAIOSFODNN7EXAMPLE and key 2: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertGreaterThanOrEqual(result.matchCount, 2)
        XCTAssertFalse(result.redactedResponse.contains("AKIA"))
        XCTAssertFalse(result.redactedResponse.contains("ghp_"))
    }

    // MARK: - Clean Result

    func testCleanResult() {
        let result = CredentialScanResult.clean(response: "Hello")
        XCTAssertFalse(result.containsCredentials)
        XCTAssertEqual(result.redactedResponse, "Hello")
        XCTAssertTrue(result.detectedTypes.isEmpty)
        XCTAssertEqual(result.matchCount, 0)
    }

    // MARK: - Pattern Compilation

    func testAllDefaultPatternsCompile() {
        for pattern in CredentialScanner.defaultPatterns {
            XCTAssertNotNil(
                pattern.compiledRegex,
                "Pattern \(pattern.id) (\(pattern.name)) failed to compile: \(pattern.pattern)"
            )
        }
    }

    // MARK: - Performance

    func testScanPerformanceTypicalResponse() {
        let response = "Here's what I found about your schedule: You have a meeting at 2pm with the design team in Room 204. After that, you have a 30-minute break before your 3:30pm call with the client. I'd recommend using the break to prepare the presentation slides."

        measure {
            for _ in 0..<100 {
                _ = scanner.scanOutput(response: response)
            }
        }
        // 100 scans should complete well under 1 second (target: <10ms per scan)
    }

    func testScanPerformanceLongResponse() {
        let longResponse = String(repeating: "This is a normal response about various topics. ", count: 200)

        measure {
            for _ in 0..<10 {
                _ = scanner.scanOutput(response: longResponse)
            }
        }
    }

    // MARK: - Edge Cases

    func testEmptyResponse() {
        let result = scanner.scanOutput(response: "")
        XCTAssertFalse(result.containsCredentials)
        XCTAssertEqual(result.redactedResponse, "")
    }

    func testResponseWithOnlyWhitespace() {
        let result = scanner.scanOutput(response: "   \n\t  ")
        XCTAssertFalse(result.containsCredentials)
    }

    // MARK: - Custom Patterns (Testing DI)

    func testCustomPatterns() {
        let customPattern = CredentialPattern(
            id: "CUSTOM-001",
            name: "Test Credential",
            pattern: #"test-cred-[a-z]{10}"#,
            severity: .high
        )
        let customScanner = CredentialScanner(patterns: [customPattern])

        let result = customScanner.scanOutput(response: "The value is test-cred-abcdefghij")
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Test Credential"))
    }
}
```

IMPORTANT IMPLEMENTATION NOTES:
- The test file goes at `tests/CredentialScannerTests.swift` (flat directory structure).
- Place new source files in `src/Security/` alongside existing files from task 0500.
- REUSE `ThreatLevel` from `src/Security/ThreatLevel.swift` — do NOT create a new one.
- The scanner NEVER logs actual credential values — only the type name (e.g., "OpenAI API Key").
- The redaction replaces the matched text with `[REDACTED]` (no type info in the placeholder for simplicity).
- Credit card detection uses Luhn algorithm for validation to reduce false positives.
- SSN pattern excludes known-invalid prefixes (000, 999).
- The `CredentialScanner` class is `final` and `Sendable` (no mutable state).
- Performance target: <10ms per scan for typical responses (~500 characters).

FINAL CHECKS:
1. All files compile with `swift build`
2. All tests pass with `swift test --filter CredentialScannerTests`
3. No calls to Process(), /bin/bash, or shell execution
4. All regex patterns compile successfully
5. ThreatLevel.swift is NOT duplicated
6. os.Logger is used (not print statements)
7. Credential values are NEVER logged
8. All public types and methods have documentation comments
```

---

## Acceptance Criteria

- [ ] `src/Security/CredentialPattern.swift` exists with pre-compiled regex support
- [ ] `src/Security/CredentialScanResult.swift` exists with `containsCredentials`, `redactedResponse`, `detectedTypes`, `matchCount`
- [ ] `src/Security/CredentialScanner.swift` exists with `scanOutput(response:)` method
- [ ] Reuses `ThreatLevel` from task 0500 (no duplication)
- [ ] Detects all 34 credential patterns: Anthropic, OpenAI, AWS, Google, GitHub (5 types), Stripe (4 types), Slack (3 types), generic (3 types), private keys (6 types), SSH (2 types), JWT, DB connections (2 types), SSN, credit cards
- [ ] Credit card detection uses Luhn algorithm for validation
- [ ] SSN pattern excludes invalid prefixes (000, 999)
- [ ] Detected credentials are replaced with `[REDACTED]` in output
- [ ] Multiple credentials in same response are all redacted
- [ ] Credential values are NEVER logged — only type names
- [ ] False positive rate: all legitimate response test cases pass clean
- [ ] Performance: typical response scans in <10ms
- [ ] `tests/CredentialScannerTests.swift` exists with comprehensive tests
- [ ] All tests pass with `swift test --filter CredentialScannerTests`
- [ ] `swift build` succeeds with no errors

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/Security/CredentialPattern.swift && echo "CredentialPattern.swift exists" || echo "MISSING: CredentialPattern.swift"
test -f src/Security/CredentialScanResult.swift && echo "CredentialScanResult.swift exists" || echo "MISSING: CredentialScanResult.swift"
test -f src/Security/CredentialScanner.swift && echo "CredentialScanner.swift exists" || echo "MISSING: CredentialScanner.swift"
test -f tests/CredentialScannerTests.swift && echo "Test file exists" || echo "MISSING: CredentialScannerTests.swift"

# Verify ThreatLevel is NOT duplicated
grep -rn "enum ThreatLevel" src/Security/ | wc -l | xargs -I {} test {} -eq 1 && echo "OK: ThreatLevel defined once" || echo "WARNING: ThreatLevel may be duplicated"

# Verify no credential values in log statements
grep -n "logger\." src/Security/CredentialScanner.swift

# Verify no shell execution
grep -rn "Process()" src/Security/ && echo "WARNING: Found Process() calls" || echo "OK: No Process() calls"
grep -rn "/bin/bash" src/Security/ && echo "WARNING: Found /bin/bash" || echo "OK: No /bin/bash"

# Build the project
swift build 2>&1

# Run credential scanner tests
swift test --filter CredentialScannerTests 2>&1

# Run all tests to ensure nothing is broken
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the CredentialScanner implementation created in task 0501 for EmberHearth. Check for these specific issues:

1. SECURITY REVIEW (Critical):
   - Open src/Security/CredentialScanner.swift
   - Verify that credential values are NEVER logged. Search ALL os.Logger calls and verify they only reference pattern names/types, never the matched text.
   - Verify the CredentialScanResult does NOT store the original unredacted response (only the redacted version is kept)
   - Verify the redaction logic processes matches from end-to-start so string indices remain valid
   - Verify no calls to Process(), /bin/bash, NSTask exist anywhere in src/Security/

2. PATTERN CORRECTNESS (Critical):
   - For each pattern in CredentialScanner.defaultPatterns, verify:
     a. The regex compiles without error (testAllDefaultPatternsCompile)
     b. The pattern catches real-world credential formats
     c. The pattern does NOT trigger on normal English text
   - Verify the Luhn algorithm implementation is correct:
     - 4111 1111 1111 1111 (valid Visa test number) should pass
     - 4111 1111 1111 1112 (invalid) should fail
   - Verify SSN pattern correctly excludes 000-xx-xxxx and 999-xx-xxxx
   - Verify the OpenAI pattern (sk-[A-Za-z0-9]{48,}) does NOT match Anthropic keys (sk-ant-...) — the Anthropic pattern should match those first

3. REDACTION CORRECTNESS:
   - Verify multiple credentials in the same response are all redacted
   - Verify redaction preserves surrounding text exactly
   - Verify overlapping matches (if possible) are handled correctly
   - Verify the redaction placeholder is exactly "[REDACTED]" (no type info leaking)

4. REUSE OF SHARED TYPES:
   - Verify ThreatLevel from src/Security/ThreatLevel.swift is REUSED, not redefined
   - Verify CredentialPattern is SEPARATE from SignaturePattern (different type for different purpose)
   - Verify no naming conflicts with task 0500 types

5. TYPE SAFETY AND SENDABILITY:
   - Verify CredentialScanner is Sendable (final class, no mutable state)
   - Verify CredentialScanResult is Sendable
   - Verify CredentialPattern is Sendable
   - Verify no force-unwraps (!) exist

6. TEST QUALITY:
   - Verify there are tests for every credential category
   - Verify there are false positive resistance tests
   - Verify there is a Luhn validation test (both valid and invalid)
   - Verify there is a multi-credential redaction test
   - Verify there is a performance benchmark test
   - Verify edge cases are tested (empty response, whitespace)

7. BUILD VERIFICATION:
   - Run `swift build` and verify it succeeds with no warnings
   - Run `swift test --filter CredentialScannerTests` and verify all tests pass
   - Run `swift test` to verify no existing tests (including InjectionScannerTests) are broken

Report any issues found with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m6): add credential scanner for outbound response filtering
```

---

## Notes for Next Task

- `CredentialScanner.scanOutput(response:)` returns a `CredentialScanResult` with the redacted response. Task 0502 (TronPipeline) will call this method as part of the outbound pipeline.
- The scanner is stateless and `Sendable` — safe to use from any thread.
- `ThreatLevel` is shared between InjectionScanner and CredentialScanner. Task 0502 will use it for pipeline-level decisions.
- `CredentialScanResult.clean(response:)` is a convenience factory for when no credentials are found. Task 0502 can use this as the default.
- The Luhn algorithm is implemented as a private method on CredentialScanner. If other components need it, it can be extracted later.
- Credit card and SSN detection are included in the credential scanner (not a separate PII scanner) for MVP simplicity. A full PII scanner is planned for v1.0.
