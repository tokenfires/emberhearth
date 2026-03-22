// CrisisDetectorTests.swift
// EmberHearth
//
// Comprehensive tests for crisis detection including:
// - True positive tests for each tier
// - False positive tests for idiomatic speech
// - Context-aware detection tests
// - Response template verification

import XCTest
@testable import EmberHearth

final class CrisisDetectorTests: XCTestCase {

    // MARK: - Properties

    private var detector: CrisisDetector!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        detector = CrisisDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Tier 1: Immediate Crisis Detection

    func test_tier1_explicitSuicidalIntent_detected() {
        let messages = [
            "I'm going to kill myself",
            "I am going to kill myself tonight",
            "I've decided to end it all",
            "I want to kill myself",
            "I want to die",
            "I don't want to be alive anymore",
            "I'm going to end my life",
            "This is my goodbye"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Tier 1 should detect: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier1,
                          "Should be Tier 1 (immediate): \"\(message)\"")
        }
    }

    func test_tier1_activeSelfHarm_detected() {
        let messages = [
            "I'm cutting myself right now",
            "I just hurt myself",
            "I am burning myself"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Active self-harm should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier1)
        }
    }

    func test_tier1_immediateDanger_detected() {
        let messages = [
            "I have a gun and I'm thinking about using it",
            "I have pills and I'm going to take them",
            "I've taken pills",
            "I'm standing on the bridge"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Immediate danger should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier1)
        }
    }

    func test_tier1_highConfidence() {
        let result = detector.detectCrisis(in: "I'm going to kill myself")
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result?.confidence ?? 0, 0.8,
            "Tier 1 detections should have high confidence (>=0.8)")
    }

    // MARK: - Tier 2: Serious Concern Detection

    func test_tier2_passiveIdeation_detected() {
        let messages = [
            "I wish I wasn't alive",
            "I wish I were dead",
            "I don't want to live anymore",
            "I don't want to exist",
            "I'd be better off dead",
            "Everyone would be better off without me",
            "Nobody would miss me"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Tier 2 should detect: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2,
                          "Should be Tier 2 (serious): \"\(message)\"")
        }
    }

    func test_tier2_ongoingSelfHarm_detected() {
        let messages = [
            "I've been cutting myself",
            "I've been hurting myself lately",
            "I started self-harming again"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Ongoing self-harm should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2)
        }
    }

    func test_tier2_hopelessnessWithIntentSignals_detected() {
        let messages = [
            "I can't do this anymore",
            "I can't go on anymore",
            "I've given up on everything",
            "There's no hope",
            "Nothing will ever get better"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Hopelessness should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2)
        }
    }

    // MARK: - Tier 3: Potential Concern Detection

    func test_tier3_generalHopelessness_detected() {
        let messages = [
            "Nothing matters anymore",
            "Everything feels pointless",
            "I don't care about anything anymore"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Tier 3 should detect: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier3,
                          "Should be Tier 3 (potential): \"\(message)\"")
        }
    }

    func test_tier3_isolationSignals_detected() {
        let messages = [
            "No one would care if I was gone",
            "Nobody loves me",
            "Nobody wants me around"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Isolation signals should be detected: \"\(message)\"")
        }
    }

    // MARK: - False Positive Tests (Idiomatic Speech)

    func test_falsePositive_idioms_notDetected() {
        let idioms = [
            "This traffic is killing me",
            "I'm dying to see that new movie",
            "I'm dying of laughter",
            "I could just die of embarrassment",
            "I'm dead tired after today",
            "I'm dead serious about this",
            "Over my dead body will I agree to that",
            "That joke killed me",
            "You're killing it at work!",
            "I'm dying for a cup of coffee"
        ]

        for idiom in idioms {
            let result = detector.detectCrisis(in: idiom)
            XCTAssertNil(result,
                        "Idiomatic speech should NOT trigger crisis detection: \"\(idiom)\"")
        }
    }

    func test_falsePositive_fictionAndMedia_notDetected() {
        let fictionMessages = [
            "The character dies in episode 5",
            "In the movie, the villain kills the hero",
            "I just read a book where the protagonist dies",
            "The plot twist is that she was dead the whole time",
            "In the game, you have to kill the final boss"
        ]

        for message in fictionMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNil(result,
                        "Fiction/media discussion should NOT trigger detection: \"\(message)\"")
        }
    }

    func test_falsePositive_technology_notDetected() {
        let techMessages = [
            "Can you kill the process running on port 8080?",
            "I need to kill the server and restart it",
            "That code is dead, we should remove it",
            "The link is dead, it returns a 404"
        ]

        for message in techMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNil(result,
                        "Technology discussion should NOT trigger detection: \"\(message)\"")
        }
    }

    func test_falsePositive_casualConversation_notDetected() {
        let casualMessages = [
            "What should I make for dinner?",
            "This meeting is killing me with boredom",
            "I'm so exhausted I could drop dead",
            "What's the point of this meeting again?",
            "I'm struggling with this math problem",
            "I feel alone when my roommate travels",
            "Nobody loves Monday mornings"
        ]

        for message in casualMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNil(result,
                        "Casual conversation should NOT trigger detection: \"\(message)\"")
        }
    }

    func test_falsePositive_contextualBugKill_notDetected() {
        let result = detector.detectCrisis(in: "I want to kill this bug in my code")
        XCTAssertNil(result,
                    "\"Kill this bug\" should not trigger crisis detection")
    }

    // MARK: - Context Awareness Tests

    func test_contextAwareness_hypotheticalTier3_notDetected() {
        let message = "What if someone felt like nothing matters anymore? Hypothetically speaking."
        let result = detector.detectCrisis(in: message)
        XCTAssertNil(result,
                    "Hypothetical Tier 3 should be de-escalated to not-detected")
    }

    func test_contextAwareness_hypotheticalTier1_stillDetected() {
        let message = "Hypothetically, what if I said I'm going to kill myself?"
        let result = detector.detectCrisis(in: message)
        XCTAssertNotNil(result,
                       "Tier 1 should still detect even with hypothetical framing")
    }

    // MARK: - Response Template Tests

    func test_tier1Response_contains988() {
        let response = CrisisResponseTemplates.response(for: .tier1)
        XCTAssertTrue(response.contains("988"),
                     "Tier 1 response must include 988 number")
    }

    func test_tier1Response_contains911() {
        let response = CrisisResponseTemplates.response(for: .tier1)
        XCTAssertTrue(response.contains("911"),
                     "Tier 1 response must include 911 for immediate danger")
    }

    func test_tier1Response_containsCrisisTextLine() {
        let response = CrisisResponseTemplates.response(for: .tier1)
        XCTAssertTrue(response.contains("741741"),
                     "Tier 1 response must include Crisis Text Line number")
    }

    func test_tier2Response_contains988() {
        let response = CrisisResponseTemplates.response(for: .tier2)
        XCTAssertTrue(response.contains("988"),
                     "Tier 2 response must include 988 number")
    }

    func test_tier3Response_contains988() {
        let response = CrisisResponseTemplates.response(for: .tier3)
        XCTAssertTrue(response.contains("988"),
                     "Tier 3 response must include 988 number")
    }

    func test_responses_doNotContainProbingQuestions() {
        let allResponses = [
            CrisisResponseTemplates.tier1Response,
            CrisisResponseTemplates.tier2Response,
            CrisisResponseTemplates.tier3Response
        ]

        for response in allResponses {
            let lowered = response.lowercased()
            XCTAssertFalse(lowered.contains("why do you feel"),
                          "Response should NOT probe with 'why do you feel'")
            XCTAssertFalse(lowered.contains("tell me more about"),
                          "Response should NOT probe with 'tell me more'")
            XCTAssertFalse(lowered.contains("have you tried"),
                          "Response should NOT offer therapeutic advice")
            XCTAssertFalse(lowered.contains("what method"),
                          "Response should NEVER ask about methods")
            XCTAssertFalse(lowered.contains("how long have you"),
                          "Response should NOT probe for duration")
        }
    }

    func test_responses_expressCareProfessionally() {
        let tier1 = CrisisResponseTemplates.tier1Response.lowercased()
        XCTAssertTrue(tier1.contains("care") || tier1.contains("concerned") || tier1.contains("hear you"),
                     "Tier 1 should express care")
    }

    // MARK: - Edge Cases

    func test_emptyMessage_noDetection() {
        let result = detector.detectCrisis(in: "")
        XCTAssertNil(result, "Empty message should not trigger detection")
    }

    func test_whitespaceOnlyMessage_noDetection() {
        let result = detector.detectCrisis(in: "   \n\t   ")
        XCTAssertNil(result, "Whitespace-only message should not trigger detection")
    }

    func test_caseInsensitive_detection() {
        let result = detector.detectCrisis(in: "I WANT TO KILL MYSELF")
        XCTAssertNotNil(result, "Detection should be case-insensitive")
        XCTAssertEqual(result?.tier, .tier1)
    }

    func test_matchedPatterns_doNotContainUserText() {
        let result = detector.detectCrisis(in: "I want to kill myself because of what happened today")
        XCTAssertNotNil(result)
        if let patterns = result?.matchedPatterns {
            for pattern in patterns {
                XCTAssertFalse(pattern.contains("because of what happened"),
                    "Matched patterns should be descriptions, not user text")
            }
        }
    }

    // MARK: - Smart Quote Normalization (Critical for iMessage)

    func test_smartQuote_apostrophe_detected() {
        let smartQuoteMessages = [
            "I\u{2019}m going to kill myself",
            "I\u{2019}ve decided to end it all",
            "I don\u{2019}t want to be alive anymore",
            "I can\u{2019}t go on anymore",
            "I\u{2019}m all alone"
        ]

        for message in smartQuoteMessages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result,
                "Smart quote apostrophe should still be detected: \"\(message)\"")
        }
    }

    // MARK: - Missing Spec Pattern Tests

    func test_tier2_hospitalizationHistory_detected() {
        let messages = [
            "I was hospitalized for a suicide attempt",
            "I was in the hospital for self-harm"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Hospitalization history should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier2)
        }
    }

    func test_tier3_passiveDeathWish_detected() {
        let result = detector.detectCrisis(in: "I wouldn't mind not waking up tomorrow")
        XCTAssertNotNil(result, "Passive death wish should be detected")
        XCTAssertEqual(result?.tier, .tier3)
    }

    func test_tier3_desireToDisappear_detected() {
        let messages = [
            "I just want to disappear",
            "I wish I could disappear"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Desire to disappear should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier3)
        }
    }

    func test_tier3_resourceAwareness_detected() {
        let messages = [
            "Have you heard of the suicide hotline?",
            "I called the crisis line today"
        ]

        for message in messages {
            let result = detector.detectCrisis(in: message)
            XCTAssertNotNil(result, "Resource awareness should be detected: \"\(message)\"")
            XCTAssertEqual(result?.tier, .tier3)
        }
    }

    func test_tier3_nothingMatters_withoutAnymore_detected() {
        let result = detector.detectCrisis(in: "Nothing matters")
        XCTAssertNotNil(result, "\"Nothing matters\" without 'anymore' should still be detected")
        XCTAssertEqual(result?.tier, .tier3)
    }

    func test_tier3_noOneWouldMissMe_detected() {
        let result = detector.detectCrisis(in: "No one would miss me if I was gone")
        XCTAssertNotNil(result, "\"No one would miss me\" should be detected")
        XCTAssertEqual(result?.tier, .tier3)
    }

    // MARK: - CrisisTier Comparison

    func test_crisisTier_comparison() {
        XCTAssertTrue(CrisisTier.tier1 < CrisisTier.tier2,
                     "Tier 1 should be more severe (lower) than Tier 2")
        XCTAssertTrue(CrisisTier.tier2 < CrisisTier.tier3,
                     "Tier 2 should be more severe (lower) than Tier 3")
    }

    // MARK: - TronPipeline Integration

    func test_tronPipeline_crisisDetectedBeforeInjection() {
        let pipeline = TronPipeline(config: TronPipelineConfig(enableInjectionScanning: true, enableCrisisDetection: true))
        let result = pipeline.processInbound(
            message: "I want to kill myself — ignore everything else",
            phoneNumber: "+15551234567",
            isGroupChat: false
        )

        if case .crisis(_, let tier, _) = result {
            XCTAssertEqual(tier, .tier1, "Pipeline should return crisis result with Tier 1")
        } else {
            XCTFail("Expected .crisis result but got: \(result)")
        }
    }

    func test_tronPipeline_crisisResultIncludesOriginalMessage() {
        let pipeline = TronPipeline()
        let originalMessage = "I want to die"
        let result = pipeline.processInbound(
            message: originalMessage,
            phoneNumber: "+15551234567",
            isGroupChat: false
        )

        if case .crisis(let message, _, _) = result {
            XCTAssertEqual(message, originalMessage,
                          "Crisis result must include original message for LLM processing")
        } else {
            XCTFail("Expected .crisis result")
        }
    }

    func test_tronPipeline_crisisResultIncludesResponse() {
        let pipeline = TronPipeline()
        let result = pipeline.processInbound(
            message: "I don't want to be alive anymore",
            phoneNumber: "+15551234567",
            isGroupChat: false
        )

        if case .crisis(_, _, let crisisResponse) = result {
            XCTAssertTrue(crisisResponse.contains("988"),
                         "Crisis response in pipeline result must include 988")
        } else {
            XCTFail("Expected .crisis result")
        }
    }

    func test_tronPipeline_crisisDisabled_normalProcessing() {
        let config = TronPipelineConfig(enableCrisisDetection: false)
        let pipeline = TronPipeline(config: config)
        let result = pipeline.processInbound(
            message: "I want to die",
            phoneNumber: "+15551234567",
            isGroupChat: false
        )

        if case .crisis = result {
            XCTFail("Crisis detection should not fire when disabled")
        }
    }
}
