// VerbosityAdapterTests.swift
// EmberHearth
//
// Unit tests for VerbosityAdapter.

import XCTest
@testable import EmberHearth

final class VerbosityAdapterTests: XCTestCase {

    private var adapter: VerbosityAdapter!

    override func setUp() {
        super.setUp()
        adapter = VerbosityAdapter()
    }

    override func tearDown() {
        adapter = nil
        super.tearDown()
    }

    // MARK: - VerbosityLevel Enum Tests

    func testVerbosityLevelAllCases() {
        XCTAssertEqual(VerbosityLevel.allCases.count, 4)
        XCTAssertTrue(VerbosityLevel.allCases.contains(.terse))
        XCTAssertTrue(VerbosityLevel.allCases.contains(.concise))
        XCTAssertTrue(VerbosityLevel.allCases.contains(.moderate))
        XCTAssertTrue(VerbosityLevel.allCases.contains(.detailed))
    }

    // MARK: - Short Message Detection

    func testVeryShortMessageReturnsTerse() {
        let level = adapter.detectVerbosity(from: "ok", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testSingleWordReturnsTerse() {
        let level = adapter.detectVerbosity(from: "thanks", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testShortAcknowledgmentReturnsTerse() {
        let level = adapter.detectVerbosity(from: "yeah", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testSingleEmojiReturnsTerse() {
        let level = adapter.detectVerbosity(from: "👍", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    // MARK: - Medium Message Detection

    func testOneSentenceReturnsConcise() {
        let level = adapter.detectVerbosity(from: "What time is my dentist appointment?", recentUserMessages: [])
        XCTAssertEqual(level, .concise)
    }

    func testSimpleQuestionReturnsConcise() {
        let level = adapter.detectVerbosity(from: "Can you remind me to call mom tonight?", recentUserMessages: [])
        XCTAssertEqual(level, .concise)
    }

    // MARK: - Longer Message Detection

    func testParagraphReturnsModerate() {
        let message = "I've been thinking about switching jobs. My current role is fine but I feel like I'm stagnating. I don't have any particular leads yet but I wanted to start thinking about what I'd want in a new position."
        let level = adapter.detectVerbosity(from: message, recentUserMessages: [])
        XCTAssertEqual(level, .moderate)
    }

    func testVeryLongMessageReturnsDetailed() {
        let message = String(repeating: "This is a longer message with multiple thoughts and considerations. ", count: 10)
        let level = adapter.detectVerbosity(from: message, recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    // MARK: - Explicit Cue Detection

    func testBriefCueReturnsTerse() {
        let level = adapter.detectVerbosity(from: "Give me a brief summary of what we discussed", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testTldrCueReturnsTerse() {
        let level = adapter.detectVerbosity(from: "What's the tldr on that article?", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testExplainCueReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Can you explain how that works?", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    func testDetailsCueReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Give me the details", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    func testWalkMeThroughReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Walk me through the process", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    func testStepByStepReturnsDetailed() {
        let level = adapter.detectVerbosity(from: "Can you give me step by step instructions?", recentUserMessages: [])
        XCTAssertEqual(level, .detailed)
    }

    // MARK: - Complex Question Detection

    func testMultipleQuestionsReturnsModerate() {
        let level = adapter.detectVerbosity(from: "What should I wear? Is it going to rain?", recentUserMessages: [])
        // Multiple questions bump to at least moderate
        XCTAssertTrue(level == .moderate || level == .detailed)
    }

    func testWhyQuestionBumpsUp() {
        let level = adapter.detectVerbosity(from: "Why does that happen?", recentUserMessages: [])
        XCTAssertTrue(level == .moderate || level == .detailed, "Why questions should be at least moderate")
    }

    func testHowDoesQuestionBumpsUp() {
        let level = adapter.detectVerbosity(from: "How does the memory system work?", recentUserMessages: [])
        XCTAssertTrue(level == .moderate || level == .detailed, "How-does questions should be at least moderate")
    }

    func testCompareQuestionBumpsUp() {
        let level = adapter.detectVerbosity(from: "Compare these two options", recentUserMessages: [])
        XCTAssertTrue(level == .moderate || level == .detailed, "Comparison requests should be at least moderate")
    }

    // MARK: - Recent History Pattern Detection

    func testConsistentlyShortHistoryBiasesToTerse() {
        let recentMessages = ["ok", "yeah", "sure", "k", "got it"]
        let level = adapter.detectVerbosity(from: "sounds good", recentUserMessages: recentMessages)
        XCTAssertEqual(level, .terse, "User with consistently short messages should get terse responses")
    }

    func testConsistentlyShortHistoryWithLongerCurrentMessage() {
        let recentMessages = ["ok", "yeah", "sure", "k", "got it"]
        let level = adapter.detectVerbosity(
            from: "Can you help me plan my schedule for tomorrow afternoon?",
            recentUserMessages: recentMessages
        )
        // Should be somewhere between terse (pattern) and concise (message length)
        XCTAssertTrue(level == .terse || level == .concise,
                       "Should balance between short history pattern and longer current message")
    }

    func testNoHistoryUsesCurrentMessageOnly() {
        let level = adapter.detectVerbosity(from: "What's the weather?", recentUserMessages: [])
        XCTAssertEqual(level, .concise)
    }

    func testInsufficientHistoryIgnoresPattern() {
        // Only 2 messages — below the threshold of 3
        let recentMessages = ["ok", "yeah"]
        let level = adapter.detectVerbosity(
            from: "What's going on this weekend? Any events nearby?",
            recentUserMessages: recentMessages
        )
        // Should rely on message length/content, not pattern
        XCTAssertTrue(level == .concise || level == .moderate)
    }

    // MARK: - Instruction Generation

    func testTerseInstructionContent() {
        let instruction = adapter.instruction(for: .terse)
        XCTAssertTrue(instruction.contains("1-2 sentences"), "Terse instruction should mention 1-2 sentences")
        XCTAssertTrue(instruction.lowercased().contains("direct"), "Terse instruction should mention directness")
    }

    func testConciseInstructionContent() {
        let instruction = adapter.instruction(for: .concise)
        XCTAssertTrue(instruction.contains("2-4 sentences"), "Concise instruction should mention 2-4 sentences")
    }

    func testModerateInstructionContent() {
        let instruction = adapter.instruction(for: .moderate)
        XCTAssertTrue(instruction.lowercased().contains("thorough"), "Moderate instruction should mention thoroughness")
    }

    func testDetailedInstructionContent() {
        let instruction = adapter.instruction(for: .detailed)
        XCTAssertTrue(instruction.lowercased().contains("comprehensive"), "Detailed instruction should mention comprehensiveness")
    }

    func testInstructionsAreReasonablyShort() {
        for level in VerbosityLevel.allCases {
            let instruction = adapter.instruction(for: level)
            XCTAssertLessThan(instruction.count, 200,
                              "Instruction for \(level.rawValue) should be concise (under 200 chars)")
        }
    }

    // MARK: - Edge Cases

    func testEmptyMessageReturnsTerse() {
        let level = adapter.detectVerbosity(from: "", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testWhitespaceOnlyMessageReturnsTerse() {
        let level = adapter.detectVerbosity(from: "   \n\t  ", recentUserMessages: [])
        XCTAssertEqual(level, .terse)
    }

    func testExplicitCueOverridesMessageLength() {
        // Long message but with explicit "briefly" cue
        let longMessage = "I have a lot of thoughts about this topic but can you briefly summarize the key takeaway from our earlier discussion about the project timeline and deliverables?"
        let level = adapter.detectVerbosity(from: longMessage, recentUserMessages: [])
        XCTAssertEqual(level, .terse, "Explicit brevity cue should override message length")
    }

    func testExplicitDetailCueOverridesShortHistory() {
        let recentMessages = ["ok", "yeah", "sure", "k", "got it"]
        let level = adapter.detectVerbosity(from: "explain how that works", recentUserMessages: recentMessages)
        XCTAssertEqual(level, .detailed, "Explicit detail cue should override short message history")
    }
}
