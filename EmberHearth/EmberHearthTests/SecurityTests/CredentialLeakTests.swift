// CredentialLeakTests.swift
// EmberHearth
//
// Tests that all known credential patterns are correctly detected and redacted
// in LLM outbound responses. A credential that leaks to the user is a critical failure.
// Reference: docs/testing/security-penetration-protocol.md, Section 2 (CD-*)

import XCTest
@testable import EmberHearthCore

/// Penetration tests for the credential detection layer of the Tron security pipeline.
///
/// Uses `CredentialScanner` directly for precise detection assertions, then verifies
/// that `TronPipeline.processOutbound` correctly integrates the scanner for end-to-end
/// redaction behavior.
///
/// ## API Notes
/// - `CredentialScanner.scanOutput(response:)` returns `CredentialScanResult` with:
///   - `.containsCredentials` — Bool, true if any credential was detected
///   - `.redactedResponse` — response with credentials replaced by [REDACTED]
///   - `.detectedTypes` — array of detected credential type names
///   - `.matchCount` — total number of matches found
/// - `TronPipeline.processOutbound(response:)` returns `OutboundResult`:
///   - `.allowed(String)` — response is clean
///   - `.redacted(String)` — credentials were replaced with [REDACTED]
final class CredentialLeakTests: XCTestCase {

    // MARK: - Properties

    private var credentialScanner: CredentialScanner!
    private var pipeline: TronPipeline!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        credentialScanner = CredentialScanner()
        pipeline = TronPipeline(config: TronPipelineConfig(
            allowedPhoneNumbers: [],
            blockGroupChats: false,
            inboundBlockThreshold: .high,
            enableCredentialScanning: true,
            enableInjectionScanning: false
        ))
    }

    override func tearDown() {
        credentialScanner = nil
        pipeline = nil
        super.tearDown()
    }

    // MARK: - CD-001: All Credential Patterns Detected

    /// Tests that every credential pattern in the payload library is detected.
    /// This is a critical test — any undetected credential is a potential security hole.
    func test_allCredentialPatterns_detected() {
        for (name, value) in SecurityTestPayloads.credentialPatterns {
            let result = credentialScanner.scanOutput(response: value)
            XCTAssertTrue(
                result.containsCredentials,
                "Credential pattern not detected: \(name)"
            )
        }
    }

    /// Tests that detected credentials are actually redacted, not just flagged.
    /// Detection without redaction is insufficient — the credential must be replaced.
    func test_allCredentialPatterns_actuallyRedacted() {
        for (name, value) in SecurityTestPayloads.credentialPatterns {
            let result = credentialScanner.scanOutput(response: value)
            if result.containsCredentials {
                XCTAssertTrue(
                    result.redactedResponse.contains("[REDACTED]"),
                    "Detected credential should be replaced with [REDACTED]: \(name)"
                )
                XCTAssertNotEqual(
                    result.redactedResponse, value,
                    "Redacted response should differ from original: \(name)"
                )
            }
        }
    }

    /// Tests that the outbound pipeline (TronPipeline) also redacts all credential patterns.
    /// Verifies end-to-end integration: scanner detection → pipeline redaction.
    func test_allCredentialPatterns_redactedByPipeline() {
        for (name, value) in SecurityTestPayloads.credentialPatterns {
            let result = pipeline.processOutbound(response: value)
            if case .redacted(let cleaned) = result {
                XCTAssertTrue(
                    cleaned.contains("[REDACTED]"),
                    "Pipeline should redact credential: \(name)"
                )
            } else if case .allowed = result {
                // If the scanner missed this credential, the test should flag it explicitly
                XCTFail("Pipeline allowed response containing credential: \(name)")
            }
        }
    }

    // MARK: - Credential Count Verification

    /// Verifies the credential pattern library meets the 20-pattern minimum.
    func test_credentialPatternCount_meetsMinimum() {
        XCTAssertGreaterThanOrEqual(
            SecurityTestPayloads.credentialPatterns.count, 20,
            "Test suite must include at least 20 credential patterns " +
            "(current: \(SecurityTestPayloads.credentialPatterns.count))"
        )
    }

    // MARK: - CD-002: Credentials Embedded in Natural Language

    /// Tests that credentials embedded in conversational responses are still caught.
    /// The LLM may wrap credentials in friendly prose — the scanner must handle this.
    func test_credentialInNaturalLanguage_detected() {
        let naturalLanguageResponses = [
            "Sure! I found your API key. It's \(TestCredentialFactory.anthropicKey("AbCdEfGhIjKlMnOpQrStUvWxYz1234567890AbCdEfGhIj")). Let me know if you need anything else!",
            "Looking at your config, I see the AWS access key is \(TestCredentialFactory.awsAccessKeyId()). You should rotate this key.",
            "The GitHub token you asked about is \(TestCredentialFactory.githubPAT()). It was created last week.",
            "Your database connection string is postgresql://myuser:myp4ssword@db.prod.internal:5432/customers.",
            "I can see in your notes the api_key = SuperSecretApiKeyABCDEFGH12345678901234567",
        ]

        for response in naturalLanguageResponses {
            let result = credentialScanner.scanOutput(response: response)
            XCTAssertTrue(
                result.containsCredentials,
                "Credential in natural language should be detected: \"\(response.prefix(60))\""
            )
        }
    }

    // MARK: - CD-003: Partial Match False Positives

    /// Tests that normal words containing credential-like substrings are NOT flagged.
    /// The scanner must not over-match short or contextually harmless strings.
    func test_partialMatches_notFlagged() {
        let safeResponses = [
            "I found a skeleton key in the old drawer",
            "The skeleton of the argument is solid",
            "She has a good skill set for the job",
            "The ski resort opens next weekend",
            "Let's skip this topic for now",
            "This is a random short string: abcdefghij",
            "GitHub is a great platform for open-source collaboration",
            "The eye doctor said my eyes are healthy",
            "Let me begin with the opening remarks",
            "The key to success is persistence and hard work",
        ]

        for response in safeResponses {
            let result = credentialScanner.scanOutput(response: response)
            XCTAssertFalse(
                result.containsCredentials,
                "Safe text should NOT be flagged as a credential: \"\(response)\""
            )
        }
    }

    // MARK: - CD-004: Multiple Credentials in One Response

    /// Tests that when multiple credentials appear in one response, all are detected and redacted.
    func test_multipleCredentials_allDetected() {
        let multiCredentialResponse = """
        Here are your credentials:
        - Anthropic: \(TestCredentialFactory.anthropicKey("abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGHIJKLMN"))
        - AWS: \(TestCredentialFactory.awsAccessKeyId())
        - GitHub: \(TestCredentialFactory.githubPAT())
        """

        let result = credentialScanner.scanOutput(response: multiCredentialResponse)
        XCTAssertTrue(
            result.containsCredentials,
            "Multiple credentials should be detected"
        )

        let redacted = result.redactedResponse
        XCTAssertFalse(
            redacted.contains("sk-ant-api03"),
            "Anthropic key prefix should be redacted"
        )
        XCTAssertFalse(
            redacted.contains("AKIAIOSFODNN7"),
            "AWS key should be redacted"
        )
        XCTAssertFalse(
            redacted.contains("ghp_ABCDEFGHIJ"),
            "GitHub token should be redacted"
        )
        XCTAssertTrue(
            redacted.contains("[REDACTED]"),
            "Redacted response should contain [REDACTED] placeholder(s)"
        )
    }

    // MARK: - CD-005: Private Key Detection

    /// Tests that all PEM-encoded private key headers are detected.
    func test_privateKeyHeaders_allDetected() {
        let privateKeyResponses = [
            "-----BEGIN RSA PRIVATE KEY-----\nMIIEpAIBAAKCAQEA...",
            "-----BEGIN EC PRIVATE KEY-----\nMHQCAQEEIBkg...",
            "-----BEGIN DSA PRIVATE KEY-----\nMIIBugIBAAKBg...",
            "-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1...",
            "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgk...",
            "-----BEGIN PGP PRIVATE KEY BLOCK-----\nlQOYBF...",
        ]

        for response in privateKeyResponses {
            let result = credentialScanner.scanOutput(response: response)
            XCTAssertTrue(
                result.containsCredentials,
                "Private key header should be detected: \"\(response.prefix(40))\""
            )
        }
    }

    // MARK: - CD-006: Connection String Detection

    /// Tests that database connection strings with embedded passwords are detected.
    func test_connectionStrings_allDetected() {
        let connectionStrings = [
            "mongodb://admin:secret123@prod.cluster.example.com:27017/mydb",
            "postgresql://dbuser:p4ssw0rd@postgres.internal:5432/production",
            "mysql://root:hunter2@localhost:3306/application_db",
            "redis://user:redispassword@cache.example.com:6379/0",
        ]

        for connectionString in connectionStrings {
            let result = credentialScanner.scanOutput(response: connectionString)
            XCTAssertTrue(
                result.containsCredentials,
                "Connection string should be detected: \"\(connectionString)\""
            )
            // Password portion should not appear in redacted output
            XCTAssertFalse(
                result.redactedResponse.contains("secret123") ||
                result.redactedResponse.contains("p4ssw0rd") ||
                result.redactedResponse.contains("hunter2") ||
                result.redactedResponse.contains("redispassword"),
                "Embedded password should be redacted from connection string"
            )
        }
    }

    // MARK: - CD-007: JWT Detection

    /// Tests that JWT tokens in responses are detected and redacted.
    func test_jwtToken_detected() {
        let jwtResponse = "The token is eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let result = credentialScanner.scanOutput(response: jwtResponse)
        XCTAssertTrue(result.containsCredentials, "JWT token should be detected")
        XCTAssertFalse(
            result.redactedResponse.contains("eyJ"),
            "JWT token content should be redacted"
        )
    }

    // MARK: - Pipeline Integration

    /// Tests end-to-end redaction: a clean response passes through unchanged.
    func test_cleanResponse_passesThrough() {
        let cleanResponse = "The weather today is sunny with a high of 72 degrees."
        let result = pipeline.processOutbound(response: cleanResponse)

        if case .allowed(let response) = result {
            XCTAssertEqual(response, cleanResponse, "Clean response should pass through unchanged")
        } else {
            XCTFail("Clean response should be .allowed, got: \(result)")
        }
    }

    /// Tests end-to-end: a response with a credential is returned as .redacted, not .allowed.
    func test_responseWithCredential_isRedacted() {
        let key = TestCredentialFactory.anthropicKey("ABCDEFGHIJ1234567890KLMNOPQRSTUVWXYZ")
        let response = "Your API key is \(key)"
        let result = pipeline.processOutbound(response: response)

        if case .redacted(let cleaned) = result {
            XCTAssertTrue(cleaned.contains("[REDACTED]"), "Redacted response should contain placeholder")
            XCTAssertFalse(cleaned.contains(key), "Original key must not be in redacted output")
        } else {
            XCTFail("Response with credential should be .redacted, got: \(result)")
        }
    }
}
