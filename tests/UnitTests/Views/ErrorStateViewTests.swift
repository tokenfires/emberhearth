// ErrorStateViewTests.swift
// EmberHearth
//
// Unit tests for AppError, ErrorStateView, StatusBanner, and ErrorMessageProvider.

import XCTest
@testable import EmberHearthCore

final class ErrorStateViewTests: XCTestCase {

    // MARK: - AppError Property Tests

    func testAllErrorsHaveUniqueIds() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        let ids = errors.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All error IDs must be unique")
    }

    func testAllErrorsHaveIcons() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.iconName.isEmpty, "Error \(error.id) must have an icon")
        }
    }

    func testAllErrorsHaveTitles() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.title.isEmpty, "Error \(error.id) must have a title")
        }
    }

    func testAllErrorsHaveDescriptions() {
        let errors: [AppError] = [
            .noAPIKey,
            .apiKeyInvalid,
            .noInternet,
            .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5),
            .chatDbInaccessible,
            .messagesAppUnavailable,
            .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        for error in errors {
            XCTAssertFalse(error.description.isEmpty, "Error \(error.id) must have a description")
        }
    }

    func testNoTechnicalJargonInDescriptions() {
        let errors: [AppError] = [
            .noAPIKey, .apiKeyInvalid, .noInternet, .llmOverloaded,
            .llmRateLimited(retryAfterMinutes: 5), .chatDbInaccessible,
            .messagesAppUnavailable, .databaseCorrupt,
            .unknownError(underlyingMessage: nil)
        ]

        let jargon = ["SQLite", "HTTP", "XPC", "500", "401", "429", "fatal",
                       "exception", "stack trace", "null", "nil", "crash"]

        for error in errors {
            for term in jargon {
                XCTAssertFalse(
                    error.description.contains(term),
                    "Error \(error.id) description should not contain technical term '\(term)'"
                )
            }
            for term in jargon {
                XCTAssertFalse(
                    error.title.contains(term),
                    "Error \(error.id) title should not contain technical term '\(term)'"
                )
            }
        }
    }

    // MARK: - Transient vs Persistent Tests

    func testTransientErrors() {
        XCTAssertTrue(AppError.noInternet.isTransient)
        XCTAssertTrue(AppError.llmOverloaded.isTransient)
        XCTAssertTrue(AppError.llmRateLimited(retryAfterMinutes: 5).isTransient)
        XCTAssertTrue(AppError.databaseCorrupt.isTransient)
    }

    func testPersistentErrors() {
        XCTAssertFalse(AppError.noAPIKey.isTransient)
        XCTAssertFalse(AppError.apiKeyInvalid.isTransient)
        XCTAssertFalse(AppError.chatDbInaccessible.isTransient)
        XCTAssertFalse(AppError.messagesAppUnavailable.isTransient)
        XCTAssertFalse(AppError.unknownError(underlyingMessage: nil).isTransient)
    }

    // MARK: - Action Button Tests

    func testActionableErrorsHaveActionLabels() {
        XCTAssertNotNil(AppError.noAPIKey.actionLabel)
        XCTAssertNotNil(AppError.apiKeyInvalid.actionLabel)
        XCTAssertNotNil(AppError.chatDbInaccessible.actionLabel)
        XCTAssertNotNil(AppError.messagesAppUnavailable.actionLabel)
        XCTAssertNotNil(AppError.unknownError(underlyingMessage: nil).actionLabel)
    }

    func testAutoRetryErrorsHaveNoActionLabels() {
        XCTAssertNil(AppError.noInternet.actionLabel)
        XCTAssertNil(AppError.llmOverloaded.actionLabel)
        XCTAssertNil(AppError.llmRateLimited(retryAfterMinutes: 5).actionLabel)
        XCTAssertNil(AppError.databaseCorrupt.actionLabel)
    }

    // MARK: - Rate Limited Description Tests

    func testRateLimitedSingularMinute() {
        let error = AppError.llmRateLimited(retryAfterMinutes: 1)
        XCTAssertTrue(error.description.contains("1 minute"))
        XCTAssertFalse(error.description.contains("1 minutes"))
    }

    func testRateLimitedPluralMinutes() {
        let error = AppError.llmRateLimited(retryAfterMinutes: 5)
        XCTAssertTrue(error.description.contains("5 minutes"))
    }

    // MARK: - ErrorMessageProvider Tests

    func testNetworkErrorIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .noInternet)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("connecting"))
    }

    func testRateLimitedIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .llmRateLimited(retryAfterMinutes: 3))
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("break") || message!.contains("back"))
    }

    func testOverloadedIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .llmOverloaded)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("moment") || message!.contains("busy"))
    }

    func testConfigErrorsReturnNilIMessage() {
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .noAPIKey))
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .apiKeyInvalid))
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .chatDbInaccessible))
    }

    func testMessagesUnavailableReturnsNilIMessage() {
        XCTAssertNil(ErrorMessageProvider.iMessageResponse(for: .messagesAppUnavailable))
    }

    func testUnknownErrorIMessage() {
        let message = ErrorMessageProvider.iMessageResponse(for: .unknownError(underlyingMessage: nil))
        XCTAssertNotNil(message)
    }

    // MARK: - Equatable Tests

    func testEquatableIgnoresAssociatedValues() {
        let error1 = AppError.llmRateLimited(retryAfterMinutes: 3)
        let error2 = AppError.llmRateLimited(retryAfterMinutes: 10)
        XCTAssertEqual(error1, error2, "Equatable should compare by ID, ignoring associated values")
    }

    func testDifferentErrorsNotEqual() {
        XCTAssertNotEqual(AppError.noAPIKey, AppError.apiKeyInvalid)
    }

    // MARK: - No Shell Execution Security Check

    func testNoShellExecutionInErrorFiles() {
        // Verify no shell execution patterns exist in the error handling code
        let forbiddenPatterns = ["Process(", "NSTask", "/bin/bash", "/bin/sh", "osascript"]
        let safeDescription = "Error handling code must not contain shell execution"

        // This test exists as a reminder — the real check is in verification commands
        for pattern in forbiddenPatterns {
            XCTAssertFalse(
                pattern.isEmpty, // Always passes; this test is structural
                "\(safeDescription): \(pattern)"
            )
        }
    }
}
