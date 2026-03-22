// PermissionManagerTests.swift
// EmberHearth
//
// Unit tests for PermissionManager data structures and logic.

import XCTest
@testable import EmberHearth

final class PermissionManagerTests: XCTestCase {

    // MARK: - PermissionStatus Tests

    func testAllDeniedStatus() {
        let status = PermissionStatus.allDenied
        XCTAssertFalse(status.fullDiskAccess)
        XCTAssertFalse(status.automation)
        XCTAssertFalse(status.notifications)
        XCTAssertFalse(status.allRequiredGranted)
        XCTAssertFalse(status.allGranted)
    }

    func testAllRequiredGrantedWithoutNotifications() {
        let status = PermissionStatus(
            fullDiskAccess: true,
            automation: true,
            notifications: false
        )
        XCTAssertTrue(status.allRequiredGranted, "Should be true when FDA and Automation are granted")
        XCTAssertFalse(status.allGranted, "Should be false when notifications are not granted")
    }

    func testAllGranted() {
        let status = PermissionStatus(
            fullDiskAccess: true,
            automation: true,
            notifications: true
        )
        XCTAssertTrue(status.allRequiredGranted)
        XCTAssertTrue(status.allGranted)
    }

    func testPartialRequiredPermissions() {
        let fdaOnly = PermissionStatus(fullDiskAccess: true, automation: false, notifications: false)
        XCTAssertFalse(fdaOnly.allRequiredGranted, "Should be false with only FDA granted")

        let automationOnly = PermissionStatus(fullDiskAccess: false, automation: true, notifications: false)
        XCTAssertFalse(automationOnly.allRequiredGranted, "Should be false with only Automation granted")
    }

    func testPermissionStatusEquality() {
        let status1 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: false)
        let status2 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: false)
        XCTAssertEqual(status1, status2)
    }

    func testPermissionStatusInequality() {
        let status1 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: false)
        let status2 = PermissionStatus(fullDiskAccess: true, automation: true, notifications: true)
        XCTAssertNotEqual(status1, status2)
    }

    // MARK: - PermissionType Tests

    func testPermissionTypeDisplayNames() {
        XCTAssertEqual(PermissionType.fullDiskAccess.displayName, "Full Disk Access")
        XCTAssertEqual(PermissionType.automation.displayName, "Automation")
        XCTAssertEqual(PermissionType.notifications.displayName, "Notifications")
    }

    func testPermissionTypeIsRequired() {
        XCTAssertTrue(PermissionType.fullDiskAccess.isRequired)
        XCTAssertTrue(PermissionType.automation.isRequired)
        XCTAssertFalse(PermissionType.notifications.isRequired)
    }

    func testPermissionTypeExplanations() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.explanation.isEmpty, "\(permission.displayName) should have a non-empty explanation")
        }
    }

    func testPermissionTypeSFSymbols() {
        XCTAssertEqual(PermissionType.fullDiskAccess.sfSymbolName, "lock.open.fill")
        XCTAssertEqual(PermissionType.automation.sfSymbolName, "bubble.left.and.bubble.right.fill")
        XCTAssertEqual(PermissionType.notifications.sfSymbolName, "bell.fill")
    }

    func testPermissionTypeAllCases() {
        XCTAssertEqual(PermissionType.allCases.count, 3)
        XCTAssertTrue(PermissionType.allCases.contains(.fullDiskAccess))
        XCTAssertTrue(PermissionType.allCases.contains(.automation))
        XCTAssertTrue(PermissionType.allCases.contains(.notifications))
    }

    // MARK: - OnboardingStep Tests

    func testOnboardingStepOrder() {
        XCTAssertLessThan(OnboardingStep.welcome, OnboardingStep.permissions)
        XCTAssertLessThan(OnboardingStep.permissions, OnboardingStep.apiKey)
        XCTAssertLessThan(OnboardingStep.apiKey, OnboardingStep.phoneConfig)
        XCTAssertLessThan(OnboardingStep.phoneConfig, OnboardingStep.test)
    }

    func testOnboardingStepTotalSteps() {
        XCTAssertEqual(OnboardingStep.totalSteps, 5)
    }

    func testOnboardingStepProgressFractions() {
        XCTAssertEqual(OnboardingStep.welcome.progressFraction, 0.2, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.permissions.progressFraction, 0.4, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.apiKey.progressFraction, 0.6, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.phoneConfig.progressFraction, 0.8, accuracy: 0.01)
        XCTAssertEqual(OnboardingStep.test.progressFraction, 1.0, accuracy: 0.01)
    }

    func testOnboardingStepTitles() {
        XCTAssertEqual(OnboardingStep.welcome.title, "Welcome")
        XCTAssertEqual(OnboardingStep.permissions.title, "Permissions")
        XCTAssertEqual(OnboardingStep.apiKey.title, "API Key")
        XCTAssertEqual(OnboardingStep.phoneConfig.title, "Phone Number")
        XCTAssertEqual(OnboardingStep.test.title, "Test")
    }

    func testOnboardingStepRawValues() {
        XCTAssertEqual(OnboardingStep.welcome.rawValue, 0)
        XCTAssertEqual(OnboardingStep.permissions.rawValue, 1)
        XCTAssertEqual(OnboardingStep.apiKey.rawValue, 2)
        XCTAssertEqual(OnboardingStep.phoneConfig.rawValue, 3)
        XCTAssertEqual(OnboardingStep.test.rawValue, 4)
    }
}
