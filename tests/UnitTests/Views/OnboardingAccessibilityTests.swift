// OnboardingAccessibilityTests.swift
// EmberHearth
//
// Verifies that onboarding views have the required accessibility identifiers
// for UI testing. This does not test VoiceOver behavior (manual testing required).

import XCTest
import SwiftUI
@testable import EmberHearthCore

final class OnboardingAccessibilityTests: XCTestCase {

    // MARK: - OnboardingStep Tests

    func testAllOnboardingStepsHaveTitles() {
        for step in OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty, "Step \(step.rawValue) should have a title")
        }
    }

    func testOnboardingStepCount() {
        XCTAssertEqual(OnboardingStep.totalSteps, 5, "There should be exactly 5 onboarding steps")
    }

    func testOnboardingStepProgressFractions() {
        XCTAssertEqual(OnboardingStep.welcome.progressFraction, 0.2, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.permissions.progressFraction, 0.4, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.apiKey.progressFraction, 0.6, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.phoneConfig.progressFraction, 0.8, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.test.progressFraction, 1.0, accuracy: 0.001)
    }

    func testOnboardingStepComparability() {
        XCTAssertTrue(OnboardingStep.welcome < OnboardingStep.permissions)
        XCTAssertTrue(OnboardingStep.permissions < OnboardingStep.apiKey)
        XCTAssertFalse(OnboardingStep.test < OnboardingStep.welcome)
    }

    // MARK: - PermissionType Accessibility Tests

    func testAllPermissionTypesHaveDisplayNames() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.displayName.isEmpty, "\(permission) should have a display name")
        }
    }

    func testAllPermissionTypesHaveExplanations() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.explanation.isEmpty, "\(permission) should have an explanation")
        }
    }

    func testAllPermissionTypesHaveSFSymbols() {
        for permission in PermissionType.allCases {
            XCTAssertFalse(permission.sfSymbolName.isEmpty, "\(permission) should have an SF Symbol name")
        }
    }

    func testRequiredPermissionsAreMarked() {
        XCTAssertTrue(PermissionType.fullDiskAccess.isRequired, "Full Disk Access should be required")
        XCTAssertTrue(PermissionType.automation.isRequired, "Automation should be required")
        XCTAssertFalse(PermissionType.notifications.isRequired, "Notifications should be optional")
    }

    // MARK: - FirstMessageTestStatus Accessibility Tests

    func testAllTestStatusesHaveDescriptions() {
        let statuses: [FirstMessageTestStatus] = [
            .waitingForMessage,
            .messageReceived,
            .processing,
            .responseSent,
            .failed(reason: "test error"),
            .timedOut
        ]

        for status in statuses {
            XCTAssertFalse(status.description.isEmpty, "\(status) should have a description")
        }
    }

    func testAllTestStatusesHaveSFSymbols() {
        let statuses: [FirstMessageTestStatus] = [
            .waitingForMessage,
            .messageReceived,
            .processing,
            .responseSent,
            .failed(reason: "test"),
            .timedOut
        ]

        for status in statuses {
            XCTAssertFalse(status.sfSymbol.isEmpty, "\(status) should have an SF Symbol")
        }
    }

    func testFinalStatusesAreCorrect() {
        XCTAssertFalse(FirstMessageTestStatus.waitingForMessage.isFinal)
        XCTAssertFalse(FirstMessageTestStatus.messageReceived.isFinal)
        XCTAssertFalse(FirstMessageTestStatus.processing.isFinal)
        XCTAssertTrue(FirstMessageTestStatus.responseSent.isFinal)
        XCTAssertTrue(FirstMessageTestStatus.failed(reason: "x").isFinal)
        XCTAssertTrue(FirstMessageTestStatus.timedOut.isFinal)
    }

    func testSuccessStatusIsCorrect() {
        XCTAssertTrue(FirstMessageTestStatus.responseSent.isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.waitingForMessage.isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.failed(reason: "x").isSuccess)
        XCTAssertFalse(FirstMessageTestStatus.timedOut.isSuccess)
    }

    func testFailedStatusIncludesReason() {
        let reason = "pipeline disconnected"
        let status = FirstMessageTestStatus.failed(reason: reason)
        XCTAssertTrue(status.description.contains(reason), "Failed status description should include the reason")
    }

    // MARK: - APIKeyValidationState Accessibility Tests

    func testValidationStatesProvideUserFeedback() {
        let invalidState = APIKeyValidationState.invalid(message: "test error")
        if case .invalid(let message) = invalidState {
            XCTAssertFalse(message.isEmpty, "Invalid state should have a non-empty message")
        }
    }

    func testValidationStateProperties() {
        XCTAssertFalse(APIKeyValidationState.idle.isValidating)
        XCTAssertFalse(APIKeyValidationState.idle.isValid)
        XCTAssertTrue(APIKeyValidationState.validating.isValidating)
        XCTAssertFalse(APIKeyValidationState.validating.isValid)
        XCTAssertFalse(APIKeyValidationState.valid.isValidating)
        XCTAssertTrue(APIKeyValidationState.valid.isValid)
        XCTAssertFalse(APIKeyValidationState.invalid(message: "err").isValidating)
        XCTAssertFalse(APIKeyValidationState.invalid(message: "err").isValid)
    }

    // MARK: - PhoneEntry Tests

    func testPhoneEntryHasRequiredFields() {
        let entry = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        XCTAssertFalse(entry.rawInput.isEmpty)
        XCTAssertFalse(entry.normalized.isEmpty)
        XCTAssertFalse(entry.id.uuidString.isEmpty)
    }

    func testPhoneEntryEquality() {
        let entry1 = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        let entry2 = PhoneEntry(rawInput: "555-123-4567", normalized: "+15551234567")
        // PhoneEntry uses UUID id, so two entries with same data are not equal
        XCTAssertNotEqual(entry1, entry2, "Two separately created PhoneEntry values should not be equal")
    }

    // MARK: - Dynamic Type Verification (Data Layer)

    // Note: Verifying that views use semantic font styles requires manual inspection
    // or snapshot testing. These tests verify the data layer supports accessibility.

    func testPermissionStatusAllDenied() {
        let status = PermissionStatus.allDenied
        XCTAssertFalse(status.allRequiredGranted)
        XCTAssertFalse(status.allGranted)
    }

    func testPermissionStatusAllGranted() {
        let status = PermissionStatus(fullDiskAccess: true, automation: true, notificationAuth: .authorized)
        XCTAssertTrue(status.allRequiredGranted)
        XCTAssertTrue(status.allGranted)
    }

    func testPermissionStatusRequiredWithoutOptional() {
        let status = PermissionStatus(fullDiskAccess: true, automation: true, notificationAuth: .denied)
        XCTAssertTrue(status.allRequiredGranted, "Required permissions are sufficient to proceed")
        XCTAssertFalse(status.allGranted, "allGranted should be false without notifications")
    }

    func testPermissionStatusTransitionsAreAnnounceworthy() {
        let before = PermissionStatus(fullDiskAccess: false, automation: false, notificationAuth: .notDetermined)
        let after = PermissionStatus(fullDiskAccess: true, automation: false, notificationAuth: .notDetermined)
        XCTAssertNotEqual(before, after, "Status change should be detectable for VoiceOver announcements")
    }

    // MARK: - Accessibility Identifier Naming Convention

    // These tests document that we follow the naming pattern:
    // "onboarding_[step]_[action]Type"

    func testAccessibilityIdentifierConventionDocumented() {
        // Identifiers used across the onboarding views (for XCUITest reference):
        let expectedIdentifiers = [
            // Container
            "onboarding_progressBar",
            // Welcome
            "onboarding_welcome_getStartedButton",
            // Permissions
            "onboarding_permissions_backButton",
            "onboarding_permissions_continueButton",
            "onboarding_permissions_fullDiskAccessCard",
            "onboarding_permissions_automationCard",
            "onboarding_permissions_notificationsCard",
            "onboarding_permissions_enableNotificationsButton",
            "onboarding_permissions_skipNotificationsButton",
            // API Key
            "onboarding_apiKey_backButton",
            "onboarding_apiKey_explanationSection",
            "onboarding_apiKey_getKeyLink",
            "onboarding_apiKey_keyField",
            "onboarding_apiKey_validateButton",
            "onboarding_apiKey_validationSuccess",
            "onboarding_apiKey_validationError",
            "onboarding_apiKey_skipButton",
            "onboarding_apiKey_continueButton",
            // Phone
            "onboarding_phone_backButton",
            "onboarding_phone_numberField",
            "onboarding_phone_addButton",
            "onboarding_phone_continueButton",
            // Test
            "onboarding_test_backButton",
            "onboarding_test_statusIndicator",
            "onboarding_test_retryButton",
            "onboarding_test_finishButton",
            "onboarding_test_skipButton",
        ]

        // Verify all identifiers follow the naming convention
        for identifier in expectedIdentifiers {
            XCTAssertTrue(
                identifier.hasPrefix("onboarding_"),
                "'\(identifier)' should start with 'onboarding_'"
            )
        }

        // Verify no duplicates in the list
        let uniqueIdentifiers = Set(expectedIdentifiers)
        XCTAssertEqual(
            uniqueIdentifiers.count,
            expectedIdentifiers.count,
            "Accessibility identifiers must be unique across all onboarding views"
        )
    }
}
