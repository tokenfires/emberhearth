import XCTest
@testable import EmberHearth

final class MessageSenderTests: XCTestCase {

    // MARK: - Phone Number Validation Tests

    func testValidE164PhoneNumbers() {
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+15551234567"))
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+442071234567"))   // UK
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+81312345678"))    // Japan
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+1"))              // Minimum: + and 1 digit
        XCTAssertTrue(MessageSender.isValidE164PhoneNumber("+123456789012345")) // 15 digits (max)
    }

    func testInvalidE164PhoneNumbers() {
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("5551234567"))     // Missing +
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+0551234567"))    // Leading 0 after +
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+"))              // Just +
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber(""))               // Empty
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+1234567890123456")) // 16 digits (too long)
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+1-555-123-4567"))   // Dashes
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+(555)1234567"))     // Parens
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+1 555 123 4567"))   // Spaces
        XCTAssertFalse(MessageSender.isValidE164PhoneNumber("+abc1234567"))        // Letters
    }

    // MARK: - AppleScript Sanitization Tests

    func testSanitizeBasicText() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("Hello, world!"),
            "Hello, world!"
        )
    }

    func testSanitizeDoubleQuotes() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("She said \"hello\""),
            "She said \\\"hello\\\""
        )
    }

    func testSanitizeBackslashes() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("path\\to\\file"),
            "path\\\\to\\\\file"
        )
    }

    func testSanitizeBackslashesBeforeQuotes() {
        XCTAssertEqual(
            MessageSender.sanitizeForAppleScript("test\\\"inject"),
            "test\\\\\\\"inject"
        )
    }

    func testSanitizeAppleScriptInjectionAttempt() {
        let malicious = "\" & do shell script \"rm -rf /\" & \""
        let sanitized = MessageSender.sanitizeForAppleScript(malicious)
        let hasUnescapedQuote = sanitized.range(of: #"(?<!\\)""#, options: .regularExpression) != nil
        XCTAssertFalse(hasUnescapedQuote, "Sanitized output must not contain unescaped double quotes")
        XCTAssertTrue(sanitized.contains("\\\""))
    }

    func testSanitizeEmptyString() {
        XCTAssertEqual(MessageSender.sanitizeForAppleScript(""), "")
    }

    func testSanitizeNewlines() {
        let text = "Line 1\nLine 2"
        XCTAssertEqual(MessageSender.sanitizeForAppleScript(text), "Line 1\nLine 2")
    }

    func testSanitizeUnicode() {
        let text = "Hello! Regards"
        XCTAssertEqual(MessageSender.sanitizeForAppleScript(text), "Hello! Regards")
    }

    // MARK: - Message Splitting Tests

    func testShortMessageNotSplit() {
        let chunks = MessageSender.splitMessage("Hello!", maxLength: 2000)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], "Hello!")
    }

    func testLongMessageSplitAtSentence() {
        let sentence1 = String(repeating: "A", count: 60) + ". "
        let sentence2 = String(repeating: "B", count: 60) + ". "
        let message = sentence1 + sentence2
        let chunks = MessageSender.splitMessage(message, maxLength: 100)

        XCTAssertEqual(chunks.count, 2)
        XCTAssertTrue(chunks[0].hasSuffix("."))
        XCTAssertLessThanOrEqual(chunks[0].count, 100)
    }

    func testLongMessageSplitAtSpace() {
        let words = (0..<30).map { _ in "word" }.joined(separator: " ")
        let chunks = MessageSender.splitMessage(words, maxLength: 50)

        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 50)
        }
        let reconstructed = chunks.joined(separator: " ")
        XCTAssertEqual(reconstructed.components(separatedBy: "word").count,
                       words.components(separatedBy: "word").count)
    }

    func testHardSplitWhenNoBreakpoints() {
        let longWord = String(repeating: "x", count: 250)
        let chunks = MessageSender.splitMessage(longWord, maxLength: 100)

        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 100)
        }
        let total = chunks.reduce(0) { $0 + $1.count }
        XCTAssertEqual(total, 250)
    }

    func testSplitEmptyMessage() {
        let chunks = MessageSender.splitMessage("", maxLength: 100)
        XCTAssertEqual(chunks.count, 1)
        XCTAssertEqual(chunks[0], "")
    }

    func testSplitExactlyMaxLength() {
        let message = String(repeating: "a", count: 100)
        let chunks = MessageSender.splitMessage(message, maxLength: 100)
        XCTAssertEqual(chunks.count, 1)
    }

    // MARK: - Send Validation Tests (without actual AppleScript execution)

    func testSendRejectsInvalidPhoneNumber() async {
        let sender = MessageSender()
        do {
            try await sender.send(message: "Hello", to: "not-a-number")
            XCTFail("Should have thrown invalidPhoneNumber")
        } catch let error as MessageSenderError {
            guard case .invalidPhoneNumber = error else {
                XCTFail("Expected invalidPhoneNumber, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendRejectsEmptyMessage() async {
        let sender = MessageSender()
        do {
            try await sender.send(message: "   ", to: "+15551234567")
            XCTFail("Should have thrown emptyMessage")
        } catch let error as MessageSenderError {
            guard case .emptyMessage = error else {
                XCTFail("Expected emptyMessage, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendRejectsTooLongMessage() async {
        let sender = MessageSender()
        let longMessage = String(repeating: "a", count: MessageSender.maxTotalLength + 1)
        do {
            try await sender.send(message: longMessage, to: "+15551234567")
            XCTFail("Should have thrown messageTooLong")
        } catch let error as MessageSenderError {
            guard case .messageTooLong = error else {
                XCTFail("Expected messageTooLong, got \(error)")
                return
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Error Description Tests

    func testErrorDescriptions() {
        let cases: [(MessageSenderError, String)] = [
            (.invalidPhoneNumber(number: "+bad"), "Invalid phone number format"),
            (.emptyMessage, "Cannot send an empty message"),
            (.messageTooLong(length: 20000, maxLength: 10000), "too long"),
            (.appleScriptFailed(errorDescription: "test"), "test"),
            (.automationPermissionDenied, "Automation permission not granted"),
            (.buddyNotFound(phoneNumber: "+15551234567"), "+15551234567"),
        ]

        for (error, expectedSubstring) in cases {
            let description = error.errorDescription ?? ""
            XCTAssertTrue(
                description.contains(expectedSubstring),
                "\(error) description should contain '\(expectedSubstring)', got: '\(description)'"
            )
        }
    }

    // MARK: - Security Verification Tests

    func testNoShellExecutionInSource() throws {
        let sourceFile = #file
        let sourceDir = (sourceFile as NSString).deletingLastPathComponent
        let senderPath = (sourceDir as NSString)
            .deletingLastPathComponent + "/src/Core/MessageSender.swift"

        if let source = try? String(contentsOfFile: senderPath, encoding: .utf8) {
            XCTAssertFalse(source.contains("Process("), "SECURITY: Process() is PROHIBITED")
            XCTAssertFalse(source.contains("NSTask"), "SECURITY: NSTask is PROHIBITED")
            XCTAssertFalse(source.contains("/bin/bash"), "SECURITY: /bin/bash is PROHIBITED")
            XCTAssertFalse(source.contains("/bin/sh"), "SECURITY: /bin/sh is PROHIBITED")
            XCTAssertFalse(source.contains("osascript"), "SECURITY: osascript is PROHIBITED")
            XCTAssertFalse(source.contains("do shell script"), "SECURITY: do shell script in AppleScript is PROHIBITED")
        }
    }
}
