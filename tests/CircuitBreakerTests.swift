// CircuitBreakerTests.swift
// EmberHearth
//
// Unit tests for CircuitBreaker.

import XCTest
@testable import EmberHearth

final class CircuitBreakerTests: XCTestCase {

    private var breaker: CircuitBreaker!

    override func setUp() {
        super.setUp()
        breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.5)
    }

    override func tearDown() {
        breaker = nil
        super.tearDown()
    }

    func testInitialStateIsClosed() {
        XCTAssertEqual(breaker.state, .closed)
    }

    func testCircuitStaysClosedOnSuccess() async throws {
        let result = try await breaker.execute { return "ok" }
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(breaker.state, .closed)
    }

    func testCircuitStaysClosedBelowThreshold() async {
        for _ in 0..<2 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        XCTAssertEqual(breaker.state, .closed)
    }

    func testCircuitOpensAtThreshold() async {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        XCTAssertEqual(breaker.state, .open)
    }

    func testOpenCircuitBlocksRequests() async {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        do {
            let _: String = try await breaker.execute { return "should not reach here" }
            XCTFail("Should have thrown CircuitBreakerOpenError.")
        } catch is CircuitBreakerOpenError {
            // Expected
        } catch {
            XCTFail("Expected CircuitBreakerOpenError, got \(error)")
        }
    }

    func testCircuitTransitionsToHalfOpenAfterTimeout() async throws {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(breaker.state, .halfOpen)
    }

    func testHalfOpenSuccessClosesCirucit() async throws {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        try await Task.sleep(nanoseconds: 600_000_000)
        let result = try await breaker.execute { return "recovered" }
        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(breaker.state, .closed)
    }

    func testHalfOpenFailureReopensCircuit() async throws {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        try await Task.sleep(nanoseconds: 600_000_000)
        do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        XCTAssertEqual(breaker.state, .open)
    }

    func testSuccessResetsFailureCount() async throws {
        for _ in 0..<2 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        _ = try await breaker.execute { return "ok" }
        for _ in 0..<2 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        XCTAssertEqual(breaker.state, .closed)
    }

    func testManualReset() async {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        breaker.reset()
        XCTAssertEqual(breaker.state, .closed)
    }

    func testHealthReportsClosed() {
        let health = breaker.health
        XCTAssertEqual(health.state, .closed)
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertNil(health.lastOpenedAt)
        XCTAssertNil(health.nextRetryAt)
    }

    func testHealthReportsOpen() async {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        let health = breaker.health
        XCTAssertEqual(health.state, .open)
        XCTAssertEqual(health.consecutiveFailures, 3)
        XCTAssertNotNil(health.lastOpenedAt)
        XCTAssertNotNil(health.nextRetryAt)
    }

    func testCircuitBreakerOpenErrorHasRetryDate() async {
        for _ in 0..<3 {
            do { let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) } } catch {}
        }
        do {
            let _: String = try await breaker.execute { return "blocked" }
            XCTFail("Should throw.")
        } catch let error as CircuitBreakerOpenError {
            XCTAssertGreaterThan(error.retryAfter, Date())
        } catch {
            XCTFail("Expected CircuitBreakerOpenError, got \(error)")
        }
    }

    func testDefaultCircuitBreakerConfiguration() {
        let defaultBreaker = CircuitBreaker()
        XCTAssertEqual(defaultBreaker.failureThreshold, 5)
        XCTAssertEqual(defaultBreaker.resetTimeout, 60.0)
        XCTAssertEqual(defaultBreaker.state, .closed)
    }
}
