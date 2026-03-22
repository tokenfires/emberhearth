// FalsePositiveTests.swift
// EmberHearth
//
// Tests that legitimate messages are NOT incorrectly flagged as security threats.
// A false positive rate above 5% is unacceptable — it would make Ember unusable.
// Reference: docs/testing/security-penetration-protocol.md, Appendix

import XCTest
@testable import EmberHearth

final class FalsePositiveTests: XCTestCase {

    private var injectionScanner: InjectionScanner!

    override func setUp() {
        super.setUp()
        injectionScanner = InjectionScanner()
    }

    override func tearDown() {
        injectionScanner = nil
        super.tearDown()
    }

    func test_legitimateMessages_notBlocked() {
        var falsePositiveCount = 0
        let messages = SecurityTestPayloads.legitimateMessages

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            if scan.shouldBlock {
                falsePositiveCount += 1
                let patternIds = scan.matchedPatterns.map(\.patternId).joined(separator: ", ")
                print("FALSE POSITIVE (\(scan.threatLevel.label)) patterns=[\(patternIds)]: \"\(message.prefix(80))\"")
            }
        }

        let falsePositiveRate = Double(falsePositiveCount) / Double(messages.count)
        XCTAssertLessThan(
            falsePositiveRate, 0.05,
            "False positive rate must be <5% " +
            "(actual: \(Int(falsePositiveRate * 100))%, \(falsePositiveCount)/\(messages.count) flagged)"
        )
    }

    func test_codeSnippets_notBlocked() {
        for message in SecurityTestPayloads.codeSnippetMessages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(
                scan.shouldBlock,
                "Code snippet should NOT be blocked " +
                "(threat: \(scan.threatLevel.label)): \"\(message.prefix(60))\""
            )
        }
    }

    func test_ignoreInNonInjectionContext_notBlocked() {
        let messages = [
            "Can you ignore what I said earlier and focus on X instead?",
            "Just ignore that last message, I figured it out",
            "Please ignore the typos in my previous message",
            "I'm going to ignore the noise and focus on work",
            "Ignore the first item — it's already done",
        ]

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(scan.shouldBlock, "Non-injection 'ignore' should not be blocked: \"\(message)\"")
        }
    }

    func test_actAsInNonInjectionContext_notBlocked() {
        let messages = [
            "I need you to act as a translator for me",
            "Can you act as a proofreader for this email?",
            "The play requires me to act as a king",
            "She can act as our representative at the meeting",
            "Can you act as a sounding board for me?",
        ]

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(scan.shouldBlock, "Non-injection 'act as' should not be blocked: \"\(message)\"")
        }
    }

    func test_systemInNonInjectionContext_notBlocked() {
        let messages = [
            "The system is running slowly",
            "I need to update the operating system",
            "The solar system is fascinating",
            "Our file system is getting full",
            "The immune system fights off infections",
            "The nervous system controls movement",
        ]

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(scan.shouldBlock, "Non-injection 'system' should not be blocked: \"\(message)\"")
        }
    }

    func test_overrideInNonInjectionContext_notBlocked() {
        let messages = [
            "Can I override the default font settings in Xcode?",
            "My manager wants to override the deadline we agreed on",
            "The system allows an admin to override user preferences",
            "The new policy overrides the old one from last year",
        ]

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(scan.shouldBlock, "Non-injection 'override' should not be blocked: \"\(message)\"")
        }
    }

    func test_nonInjectionBase64_notBlocked() {
        let messages = [
            "The string in Base64 is: aGVsbG8gd29ybGQ=",
            "Here's the encoded message: SGVsbG8sIEkgbG92ZSBwcm9ncmFtbWluZyE=",
            "The hash is: dGVzdA==",
        ]

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(scan.shouldBlock, "Non-injection Base64 should not be blocked: \"\(message.prefix(60))\"")
        }
    }

    func test_longLegitimateMessageWithTriggerWords_notBlocked() {
        let longMessage = """
        I've been thinking about my career lately and I want to bounce some ideas off you. \
        I've been working as a software engineer for about 5 years now, mostly doing backend \
        work in Python and Go. I enjoy the problem-solving aspect but I want to act as more \
        of a bridge between the technical team and the business stakeholders. I've heard that \
        making this transition can be tricky and I should probably ignore the advice about \
        needing an MBA. The system design work I do is interesting but I want to explore new \
        directions. What do you think? Can you help me think through this? My friend who's a \
        PM says I should just go for it, but I have some concerns about the learning curve.
        """

        let scan = injectionScanner.scan(message: longMessage)
        XCTAssertFalse(scan.shouldBlock, "Long legitimate message should not be blocked despite trigger words")
    }

    func test_aiConceptQuestions_notBlocked() {
        let messages = [
            "I read an article about how AI systems handle instructions",
            "What's the difference between a system prompt and a user prompt in AI?",
            "Tell me about how language models work",
            "How do AI assistants stay safe from prompt injection attacks?",
            "What does 'context window' mean for an LLM?",
        ]

        for message in messages {
            let scan = injectionScanner.scan(message: message)
            XCTAssertFalse(scan.shouldBlock, "AI concept question should not be blocked: \"\(message)\"")
        }
    }

    func test_overallFalsePositiveRate_belowThreshold() {
        let allLegitimate =
            SecurityTestPayloads.legitimateMessages +
            SecurityTestPayloads.codeSnippetMessages

        var blockedCount = 0
        for message in allLegitimate {
            let scan = injectionScanner.scan(message: message)
            if scan.shouldBlock { blockedCount += 1 }
        }

        let rate = Double(blockedCount) / Double(allLegitimate.count) * 100.0
        XCTAssertLessThan(rate, 5.0,
            "Overall false positive rate must be <5%: actual \(String(format: "%.1f", rate))% " +
            "(\(blockedCount)/\(allLegitimate.count) messages blocked)")
    }

    func test_credentialScannerFalsePositives_belowThreshold() {
        let credentialScanner = CredentialScanner()
        let benignResponses = [
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
            "GitHub is a great platform for open source collaboration.",
            "Let me begin with the opening remarks.",
            "The weather today is sunny.",
            "I need to update my calendar for next week.",
        ]

        var falsePositiveCount = 0
        for response in benignResponses {
            let result = credentialScanner.scanOutput(response: response)
            if result.containsCredentials { falsePositiveCount += 1 }
        }

        let rate = Double(falsePositiveCount) / Double(benignResponses.count) * 100.0
        XCTAssertLessThan(rate, 5.0,
            "Credential scanner false positive rate must be <5% " +
            "(actual: \(String(format: "%.1f", rate))%, \(falsePositiveCount)/\(benignResponses.count))")
    }
}
