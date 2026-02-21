// LaunchAtLoginTests.swift
// EmberHearth
//
// Unit tests for LaunchAtLoginManager state management.

import XCTest
@testable import EmberHearth

final class LaunchAtLoginTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clean up UserDefaults before each test to ensure isolation
        UserDefaults.standard.removeObject(forKey: "launchAtLoginEnabled")
    }

    override func tearDown() {
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: "launchAtLoginEnabled")
        super.tearDown()
    }

    func testUserPreferenceIsNilOnFirstLaunch() {
        // On a fresh install, the user has never set a preference
        XCTAssertNil(LaunchAtLoginManager.shared.userPreference,
                     "User preference should be nil before any interaction")
    }

    func testSetEnabledStoresPreference() {
        // When we set enabled, the preference should be stored
        LaunchAtLoginManager.shared.setEnabled(true)
        XCTAssertEqual(LaunchAtLoginManager.shared.userPreference, true,
                       "User preference should be true after enabling")

        LaunchAtLoginManager.shared.setEnabled(false)
        XCTAssertEqual(LaunchAtLoginManager.shared.userPreference, false,
                       "User preference should be false after disabling")
    }

    func testStatusDescriptionReturnsString() {
        // statusDescription should always return a non-empty string
        let description = LaunchAtLoginManager.shared.statusDescription
        XCTAssertFalse(description.isEmpty,
                       "Status description should not be empty")
    }

    func testSynchronizeOnFirstLaunchSetsPreference() {
        // First launch should default to enabling launch at login
        XCTAssertNil(LaunchAtLoginManager.shared.userPreference)
        LaunchAtLoginManager.shared.synchronize()
        XCTAssertEqual(LaunchAtLoginManager.shared.userPreference, true,
                       "First launch synchronize should set preference to true")
    }
}
