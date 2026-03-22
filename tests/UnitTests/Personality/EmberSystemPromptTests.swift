// EmberSystemPromptTests.swift
// EmberHearth
//
// Unit tests for EmberSystemPrompt and SystemPromptBuilder.

import XCTest
@testable import EmberHearthCore

final class EmberSystemPromptTests: XCTestCase {

    private var builder: SystemPromptBuilder!

    override func setUp() {
        super.setUp()
        builder = SystemPromptBuilder()
    }

    override func tearDown() {
        builder = nil
        super.tearDown()
    }

    // MARK: - Base Prompt Tests

    func testBasePromptIsNotEmpty() {
        XCTAssertFalse(EmberSystemPrompt.basePrompt.isEmpty)
    }

    func testBasePromptContainsIdentity() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.contains("Ember"), "Base prompt must mention Ember's name")
        XCTAssertTrue(prompt.contains("personal AI assistant"), "Base prompt must define role")
        XCTAssertTrue(prompt.contains("iMessage"), "Base prompt must mention iMessage interface")
    }

    func testBasePromptContainsCoreTraits() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.lowercased().contains("warm"), "Must include warm trait")
        XCTAssertTrue(prompt.lowercased().contains("curious"), "Must include curious trait")
        XCTAssertTrue(prompt.lowercased().contains("capable"), "Must include capable trait")
        XCTAssertTrue(prompt.lowercased().contains("present"), "Must include present trait")
        XCTAssertTrue(prompt.lowercased().contains("honest"), "Must include honest trait")
    }

    func testBasePromptContainsBehavioralRules() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.contains("never do"), "Must include behavioral constraints")
        XCTAssertTrue(prompt.contains("physical experience"), "Must address not pretending physical senses")
    }

    func testBasePromptContainsCrisisGuidance() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.contains("988"), "Must include 988 Suicide & Crisis Lifeline number")
    }

    func testBasePromptContainsPrivacyStatement() {
        let prompt = EmberSystemPrompt.basePrompt
        XCTAssertTrue(prompt.lowercased().contains("local"), "Must mention local data storage")
    }

    func testBasePromptTokenBudget() {
        let prompt = EmberSystemPrompt.basePrompt
        // Base prompt should be approximately 400-800 tokens (~1600-3200 chars)
        // Allow some margin
        XCTAssertLessThan(prompt.count, 4000, "Base prompt should be under ~1000 tokens")
        XCTAssertGreaterThan(prompt.count, 800, "Base prompt should be at least ~200 tokens")
    }

    func testBasePromptAvoidsImmersionBreakers() {
        let prompt = EmberSystemPrompt.basePrompt
        // These are words/phrases the personality-design doc says to avoid in Ember's output
        // The system prompt itself should model good behavior
        XCTAssertFalse(prompt.contains("Delve"), "Should not use LLM vocabulary artifacts")
        XCTAssertFalse(prompt.contains("Leverage"), "Should not use LLM vocabulary artifacts")
        XCTAssertFalse(prompt.contains("Utilize"), "Should not use LLM vocabulary artifacts")
    }

    // MARK: - Builder Tests: Basic Assembly

    func testBuildWithNoOptionalSections() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertFalse(prompt.isEmpty)
        XCTAssertTrue(prompt.contains(EmberSystemPrompt.basePrompt))
    }

    func testBuildIncludesTimeContext() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertTrue(prompt.contains("Current context:"), "Should include current context section")
    }

    func testBuildIncludesUserFacts() {
        let facts = [
            FactInfo(content: "User prefers dark roast coffee", importance: 0.5, lastUpdated: Date()),
            FactInfo(content: "User's name is Alex", importance: 0.9, lastUpdated: Date())
        ]

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertTrue(prompt.contains("What you know about the user:"))
        XCTAssertTrue(prompt.contains("dark roast coffee"))
        XCTAssertTrue(prompt.contains("Alex"))
    }

    func testBuildSortsFactsByImportance() {
        let facts = [
            FactInfo(content: "Low importance fact", importance: 0.1, lastUpdated: Date()),
            FactInfo(content: "High importance fact", importance: 0.9, lastUpdated: Date()),
            FactInfo(content: "Medium importance fact", importance: 0.5, lastUpdated: Date())
        ]

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: nil,
            currentDate: Date()
        )

        // High importance fact should appear before low importance fact
        let highRange = prompt.range(of: "High importance fact")
        let lowRange = prompt.range(of: "Low importance fact")
        XCTAssertNotNil(highRange)
        XCTAssertNotNil(lowRange)
        if let high = highRange, let low = lowRange {
            XCTAssertTrue(high.lowerBound < low.lowerBound, "Higher importance facts should appear first")
        }
    }

    func testBuildIncludesSessionSummary() {
        let summary = "User discussed their upcoming trip to Portland and mentioned wanting restaurant recommendations."

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: summary,
            currentDate: Date()
        )

        XCTAssertTrue(prompt.contains("Earlier in this conversation:"))
        XCTAssertTrue(prompt.contains("Portland"))
    }

    func testBuildIncludesVerbosityInstruction() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date(),
            verbosityInstruction: "Respond in 1-2 sentences maximum. Be direct."
        )

        XCTAssertTrue(prompt.contains("Response style for this message:"))
        XCTAssertTrue(prompt.contains("1-2 sentences"))
    }

    func testBuildIncludesUserName() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date(),
            userName: "Alex"
        )

        XCTAssertTrue(prompt.contains("Alex"))
        XCTAssertTrue(prompt.contains("naturally but not excessively"))
    }

    // MARK: - Builder Tests: Time Context

    func testMorningContext() {
        // Create a date at 7:30 AM on a Wednesday
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 4  // A Wednesday
        components.hour = 7
        components.minute = 30
        let morning = Calendar.current.date(from: components)!

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: morning
        )

        XCTAssertTrue(prompt.lowercased().contains("early morning"))
        XCTAssertTrue(prompt.contains("Wednesday"))
    }

    func testEveningContext() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 6  // A Friday
        components.hour = 19
        components.minute = 0
        let evening = Calendar.current.date(from: components)!

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: evening
        )

        XCTAssertTrue(prompt.lowercased().contains("evening"))
        XCTAssertTrue(prompt.contains("Friday"))
    }

    func testWeekendContext() {
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 7  // A Saturday
        components.hour = 10
        components.minute = 0
        let saturday = Calendar.current.date(from: components)!

        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: saturday
        )

        XCTAssertTrue(prompt.contains("Saturday"))
        XCTAssertTrue(prompt.contains("weekend"))
    }

    // MARK: - Builder Tests: Budget Enforcement

    func testPromptStaysUnderBudget() {
        // Create many facts to push the prompt close to the limit
        var facts: [FactInfo] = []
        for i in 0..<50 {
            facts.append(FactInfo(
                content: "This is test fact number \(i) which contains some reasonable amount of content to simulate a real user fact stored in the memory system",
                importance: Double(i) / 50.0,
                lastUpdated: Date()
            ))
        }

        let longSummary = String(repeating: "The user discussed various topics including work, hobbies, and plans. ", count: 20)

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: longSummary,
            currentDate: Date()
        )

        XCTAssertLessThanOrEqual(
            prompt.count,
            SystemPromptBuilder.maxPromptCharacters,
            "Assembled prompt must not exceed \(SystemPromptBuilder.maxPromptCharacters) characters"
        )
    }

    func testBudgetTrimmingPreservesHighImportanceFacts() {
        // Create enough facts to trigger trimming
        var facts: [FactInfo] = []
        let criticalFact = FactInfo(
            content: "CRITICAL: User is allergic to peanuts",
            importance: 1.0,
            lastUpdated: Date()
        )
        facts.append(criticalFact)

        for i in 0..<100 {
            facts.append(FactInfo(
                content: "Filler fact number \(i) with enough content to consume space in the prompt budget allocation",
                importance: 0.1,
                lastUpdated: Date()
            ))
        }

        let longSummary = String(repeating: "Summary content that takes up space. ", count: 50)

        let prompt = builder.buildSystemPrompt(
            userFacts: facts,
            sessionSummary: longSummary,
            currentDate: Date()
        )

        // The critical fact should survive trimming
        XCTAssertTrue(prompt.contains("allergic to peanuts"), "Critical facts should be preserved during trimming")
    }

    func testEmptyFactsProducesNoFactsSection() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertFalse(prompt.contains("What you know about the user:"), "Empty facts should not produce a facts section")
    }

    // MARK: - Builder Tests: Edge Cases

    func testNilSessionSummaryOmitsSection() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date()
        )

        XCTAssertFalse(prompt.contains("Earlier in this conversation:"))
    }

    func testEmptySessionSummaryOmitsSection() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: "",
            currentDate: Date()
        )

        XCTAssertFalse(prompt.contains("Earlier in this conversation:"))
    }

    func testEmptyUserNameOmitsNameLine() {
        let prompt = builder.buildSystemPrompt(
            userFacts: [],
            sessionSummary: nil,
            currentDate: Date(),
            userName: ""
        )

        XCTAssertFalse(prompt.contains("user's name is"))
    }
}
