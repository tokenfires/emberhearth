// RetryHandlerTests.swift
// EmberHearth
//
// Unit tests for RetryHandler.

import XCTest
@testable import EmberHearthCore

/// Thread-safe counter for use in async test closures.
private final class CallCounter: @unchecked Sendable {
    private var _count = 0
    private let lock = NSLock()

    var count: Int {
        lock.withLock { _count }
    }

    @discardableResult
    func increment() -> Int {
        lock.withLock {
            _count += 1
            return _count
        }
    }
}

final class RetryHandlerTests: XCTestCase {

    private var handler: RetryHandler!

    override func setUp() {
        super.setUp()
        handler = RetryHandler(configuration: RetryConfiguration(
            maxRetries: 3,
            baseDelay: 0.01,
            maxDelay: 0.1,
            maxJitter: 0.01
        ))
    }

    override func tearDown() {
        handler = nil
        super.tearDown()
    }

    func testExecuteSuccessOnFirstAttempt() async throws {
        let counter = CallCounter()
        let result = try await handler.execute {
            counter.increment()
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(counter.count, 1)
    }

    func testExecuteSuccessOnSecondAttempt() async throws {
        let counter = CallCounter()
        let result: String = try await handler.execute {
            let current = counter.increment()
            if current == 1 { throw ClaudeAPIError.timeout }
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(counter.count, 2)
    }

    func testExecuteSuccessOnLastAttempt() async throws {
        let counter = CallCounter()
        let result: String = try await handler.execute {
            let current = counter.increment()
            if current <= 3 { throw ClaudeAPIError.serverError(statusCode: 500) }
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(counter.count, 4)
    }

    func testExecuteExhaustsAllRetries() async {
        let counter = CallCounter()
        do {
            let _: String = try await handler.execute {
                counter.increment()
                throw ClaudeAPIError.serverError(statusCode: 500)
            }
            XCTFail("Should have thrown after exhausting retries.")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(counter.count, 4)
            if case .serverError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected ClaudeAPIError, got \(error)")
        }
    }

    func testNonRetryableErrorDoesNotRetry() async {
        let counter = CallCounter()
        do {
            let _: String = try await handler.execute {
                counter.increment()
                throw ClaudeAPIError.unauthorized
            }
            XCTFail("Should have thrown unauthorized error.")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(counter.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBadRequestDoesNotRetry() async {
        let counter = CallCounter()
        do {
            let _: String = try await handler.execute {
                counter.increment()
                throw ClaudeAPIError.badRequest("Invalid model")
            }
            XCTFail("Should have thrown.")
        } catch {
            XCTAssertEqual(counter.count, 1)
        }
    }

    func testNoAPIKeyDoesNotRetry() async {
        let counter = CallCounter()
        do {
            let _: String = try await handler.execute {
                counter.increment()
                throw ClaudeAPIError.noAPIKey
            }
            XCTFail("Should have thrown.")
        } catch {
            XCTAssertEqual(counter.count, 1)
        }
    }

    func testRetryableErrors() {
        let retryableErrors: [ClaudeAPIError] = [
            .rateLimited(retryAfter: nil),
            .rateLimited(retryAfter: 5.0),
            .serverError(statusCode: 500),
            .serverError(statusCode: 502),
            .serverError(statusCode: 503),
            .networkError("Connection reset"),
            .timeout,
            .overloaded
        ]
        for error in retryableErrors {
            XCTAssertTrue(handler.isRetryable(error), "\(error) should be retryable.")
        }
    }

    func testNonRetryableErrors() {
        let nonRetryableErrors: [ClaudeAPIError] = [
            .unauthorized,
            .badRequest("Invalid"),
            .noAPIKey,
            .decodingError("Bad")
        ]
        for error in nonRetryableErrors {
            XCTAssertFalse(handler.isRetryable(error), "\(error) should NOT be retryable.")
        }
    }

    func testExponentialBackoffDelays() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)
        let dummyError = ClaudeAPIError.serverError(statusCode: 500)

        XCTAssertEqual(handler.calculateDelay(attempt: 0, error: dummyError), 1.0, accuracy: 0.01)
        XCTAssertEqual(handler.calculateDelay(attempt: 1, error: dummyError), 2.0, accuracy: 0.01)
        XCTAssertEqual(handler.calculateDelay(attempt: 2, error: dummyError), 4.0, accuracy: 0.01)
    }

    func testDelayDoesNotExceedMaxDelay() {
        let config = RetryConfiguration(maxRetries: 10, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)
        let dummyError = ClaudeAPIError.serverError(statusCode: 500)
        XCTAssertLessThanOrEqual(handler.calculateDelay(attempt: 10, error: dummyError), 30.0)
    }

    func testRetryAfterHeaderRespected() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)
        XCTAssertEqual(handler.calculateDelay(attempt: 0, error: ClaudeAPIError.rateLimited(retryAfter: 15.0)), 15.0)
    }

    func testRetryAfterCappedAtMaxDelay() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)
        XCTAssertEqual(handler.calculateDelay(attempt: 0, error: ClaudeAPIError.rateLimited(retryAfter: 120.0)), 30.0)
    }

    func testDefaultConfiguration() {
        let config = RetryConfiguration.default
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.baseDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 30.0)
        XCTAssertEqual(config.maxJitter, 1.0)
    }
}
