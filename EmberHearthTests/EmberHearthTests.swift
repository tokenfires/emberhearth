// EmberHearthTests.swift
// EmberHearth
//
// Basic test suite for EmberHearth.

import XCTest
@testable import EmberHearth

final class EmberHearthTests: XCTestCase {

    func testModulesExist() {
        // Verify all module placeholders are accessible
        XCTAssertEqual(AppModule.name, "App")
        XCTAssertEqual(CoreModule.name, "Core")
        XCTAssertEqual(DatabaseModule.name, "Database")
        XCTAssertEqual(LLMModule.name, "LLM")
        XCTAssertEqual(MemoryModule.name, "Memory")
        XCTAssertEqual(PersonalityModule.name, "Personality")
        XCTAssertEqual(SecurityModule.name, "Security")
        XCTAssertEqual(ViewsModule.name, "Views")
        XCTAssertEqual(LoggingModule.name, "Logging")
    }
}
