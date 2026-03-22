// CredentialScannerTests.swift
// EmberHearth
//
// Unit tests for CredentialScanner.

import XCTest
@testable import EmberHearthCore

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
        let key = TestCredentialFactory.anthropicKey("ABC123DEF456GHI789JKL012MNO345PQR678STU901")
        let response = "Your Anthropic key is \(key)"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Anthropic API Key"))
        XCTAssertTrue(result.redactedResponse.contains("[REDACTED]"))
        XCTAssertFalse(result.redactedResponse.contains(key))
    }

    func testOpenAIAPIKeyDetection() {
        let response = "The key is \(TestCredentialFactory.openAIKey("abcdefghijklmnopqrstuvwxyz012345678901234567890123"))"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("OpenAI API Key"))
        XCTAssertFalse(result.redactedResponse.contains("sk-abcdefghijklmnop"))
    }

    func testAWSAccessKeyDetection() {
        let response = "Your AWS key is \(TestCredentialFactory.awsAccessKeyId())"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("AWS Access Key ID"))
        XCTAssertFalse(result.redactedResponse.contains("AKIA"))
    }

    func testGoogleAPIKeyDetection() {
        let response = "The API key is \(TestCredentialFactory.googleAPIKey())"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Google API Key"))
    }

    func testGoogleOAuthTokenDetection() {
        let response = "Token: ya29.a0AfH6SMB-xxxx_1234567890abcdefg"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Google OAuth Token"))
    }

    func testAWSSecretAccessKeyDetection() {
        let response = "aws_secret = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("AWS Secret Access Key"))
    }

    // MARK: - GitHub Token Detection

    func testGitHubPATDetection() {
        let response = "Use this token: \(TestCredentialFactory.githubPAT())"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("GitHub Personal Access Token"))
    }

    func testGitHubOAuthDetection() {
        let response = "OAuth: \(TestCredentialFactory.githubOAuth())"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("GitHub OAuth Token"))
    }

    func testGitHubServerTokenDetection() {
        let response = "Server token: \(TestCredentialFactory.githubServer())"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("GitHub Server Token"))
    }

    // MARK: - Payment Provider Detection

    func testStripeLiveKeyDetection() {
        let response = "The live key is \(TestCredentialFactory.stripeKey(live: true))"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Stripe Live Secret Key"))
    }

    func testStripeTestKeyDetection() {
        let response = "For testing use \(TestCredentialFactory.stripeKey(live: false))"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Stripe Test Secret Key"))
    }

    // MARK: - Slack Token Detection

    func testSlackBotTokenDetection() {
        let response = "Bot token: \(TestCredentialFactory.slackBotToken("1234567890123-1234567890123-ABCDEFGHIJKLMNOPqrstuvwx"))"
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

    func testGenericPrivateKeyDetection() {
        let response = "-----BEGIN PRIVATE KEY-----\nMIIEvg..."
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("Generic Private Key"))
    }

    func testPGPPrivateKeyDetection() {
        let response = "-----BEGIN PGP PRIVATE KEY BLOCK-----\nlQOY..."
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("PGP Private Key"))
    }

    // MARK: - SSH Public Key Detection

    func testSSHRSAPublicKeyDetection() {
        let sshKey = "ssh-rsa " + String(repeating: "AAAAB3NzaC1yc2EAAAADAQABAAABgQC3Fj0G", count: 4)
        let response = "Key: \(sshKey)"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("SSH Public Key (RSA)"))
    }

    func testSSHEd25519PublicKeyDetection() {
        let sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxYnr1234567890abcdefg"
        let response = "Key: \(sshKey)"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.detectedTypes.contains("SSH Public Key (Ed25519)"))
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

    func testMySQLConnectionString() {
        let response = "Use: MySQL://dbuser:s3cret@db.internal:3306/app"
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
        let response = "Before \(TestCredentialFactory.anthropicKey("ABCDEFGHIJ1234567890KLMNOP")) After"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertTrue(result.redactedResponse.hasPrefix("Before "))
        XCTAssertTrue(result.redactedResponse.hasSuffix(" After"))
        XCTAssertTrue(result.redactedResponse.contains("[REDACTED]"))
        XCTAssertFalse(result.redactedResponse.contains("sk-ant"))
    }

    func testMultipleCredentialRedaction() {
        let response = "Key 1: \(TestCredentialFactory.awsAccessKeyId()) and key 2: \(TestCredentialFactory.githubPAT())"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertGreaterThanOrEqual(result.matchCount, 2)
        XCTAssertFalse(result.redactedResponse.contains("AKIA"))
        XCTAssertFalse(result.redactedResponse.contains("ghp_"))
    }

    func testOverlappingMatchesBearerAndJWT() {
        let jwt = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U"
        let response = "Authorization: Bearer \(jwt)"
        let result = scanner.scanOutput(response: response)
        XCTAssertTrue(result.containsCredentials)
        XCTAssertFalse(result.redactedResponse.contains("eyJ"))
        XCTAssertFalse(result.redactedResponse.contains("Bearer e"))
        XCTAssertTrue(result.redactedResponse.contains("[REDACTED]"))
        XCTAssertTrue(result.redactedResponse.hasPrefix("Authorization: "))
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
