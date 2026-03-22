# Task 0204: Error Handling with Retry and Circuit Breaker

**Milestone:** M3 - LLM Integration
**Unit:** 3.4 - Error Handling (Retry, Backoff)
**Phase:** 1
**Depends On:** 0201 (ClaudeAPIClient, ClaudeAPIError)
**Estimated Effort:** 3-4 hours
**Complexity:** Large

---

## Context Files

Open these files in Cursor using `@file` references before starting:

1. `CLAUDE.md` — Read entirely; security rules, naming conventions
2. `src/LLM/ClaudeAPIError.swift` — Read entirely; you will use these error types to decide what to retry. Key cases: `.rateLimited(retryAfter:)`, `.serverError(statusCode:)`, `.timeout`, `.overloaded` are retryable. `.unauthorized`, `.badRequest`, `.noAPIKey` are NOT retryable.
3. `src/LLM/ClaudeAPIClient.swift` — Read entirely; you will integrate the retry handler and circuit breaker with this client. Note the `sendMessage()` method.
4. `docs/specs/error-handling.md` — Focus on lines 60-78 (LLM Provider failure modes table and retry policy), lines 389-429 (health monitoring and HealthStatus struct), and the "Design Principles" section (lines 22-55). Key takeaway: self-healing, fail gracefully, never go silent.

> **Context Budget Note:** error-handling.md is ~587 lines. Focus on lines 22-78 (principles + LLM failure modes) and lines 389-429 (health monitoring). Skip all database, iMessage, XPC, and UI sections.

---

## Sonnet Prompt

> Copy everything in this section and paste it into a new Claude Sonnet 4.5 chat session in Cursor.

```
You are implementing the retry handler and circuit breaker for EmberHearth, a native macOS personal AI assistant. These components wrap the Claude API client to provide resilient error handling. When the API returns transient errors, we retry with exponential backoff. When errors persist, the circuit breaker prevents wasting requests on a dead service.

IMPORTANT RULES (from CLAUDE.md):
- Swift files use PascalCase (e.g., RetryHandler.swift)
- NEVER log or print API keys, request bodies, or response bodies
- NEVER use shell execution (no Process(), no /bin/bash, no NSTask)
- No third-party dependencies — use only Apple frameworks
- All source files go under src/
- All test files go under tests/
- Every Swift file must have the filename as its first comment line
- macOS 13.0+ deployment target

EXISTING CODE CONTEXT:
- src/LLM/ClaudeAPIError.swift defines these errors:
  - .noAPIKey — NOT retryable
  - .unauthorized — NOT retryable (HTTP 401)
  - .rateLimited(retryAfter: TimeInterval?) — Retryable (HTTP 429)
  - .serverError(statusCode: Int) — Retryable (HTTP 500, 502, 503)
  - .networkError(String) — Retryable (transient network issues)
  - .timeout — Retryable
  - .invalidResponse(String) — NOT retryable
  - .overloaded — Retryable (HTTP 529)
  - .badRequest(String) — NOT retryable (HTTP 400)

RETRY POLICY (from docs/specs/error-handling.md):
- Max retries: 3 (so up to 4 total attempts)
- Base delay: 1 second
- Max delay: 30 seconds
- Jitter: random 0-1 second added to each delay
- Exponential backoff: delay = min(baseDelay * 2^attempt + jitter, maxDelay)
- If API returns Retry-After header, use that value instead of calculated delay
- Only retry on: rate limit (429), server error (500, 502, 503), network timeout, overloaded (529)
- Do NOT retry on: unauthorized (401), bad request (400), not found, no API key, invalid response

CIRCUIT BREAKER DESIGN:
- Three states: .closed (normal), .open (blocking), .halfOpen (testing)
- Opens after 5 consecutive failures
- Stays open for 60 seconds, then transitions to .halfOpen
- In .halfOpen: allows exactly 1 request through
  - If it succeeds: transition to .closed (reset failure count)
  - If it fails: transition back to .open (restart 60-second timer)
- When circuit is .open: immediately throw an error (don't even attempt the request)

STEP 1: Create the RetryHandler

File: src/LLM/RetryHandler.swift
```swift
// RetryHandler.swift
// EmberHearth
//
// Retry logic with exponential backoff for LLM API calls.

import Foundation
import os

/// Configuration for retry behavior.
struct RetryConfiguration: Sendable {
    /// Maximum number of retry attempts (not counting the initial attempt).
    let maxRetries: Int
    /// Base delay between retries in seconds.
    let baseDelay: TimeInterval
    /// Maximum delay between retries in seconds.
    let maxDelay: TimeInterval
    /// Maximum random jitter added to each delay in seconds.
    let maxJitter: TimeInterval

    /// Default retry configuration for LLM API calls.
    static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        maxJitter: 1.0
    )
}

/// Handles retry logic with exponential backoff for async operations.
///
/// Usage:
/// ```swift
/// let handler = RetryHandler()
/// let response = try await handler.execute {
///     try await apiClient.sendMessage(messages, systemPrompt: prompt)
/// }
/// ```
final class RetryHandler: Sendable {

    /// The retry configuration.
    let configuration: RetryConfiguration

    /// Logger for retry events. NEVER logs request/response content.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "RetryHandler"
    )

    /// Creates a RetryHandler with the specified configuration.
    ///
    /// - Parameter configuration: Retry behavior settings. Defaults to `.default`.
    init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }

    /// Executes an async operation with retry logic.
    ///
    /// If the operation fails with a retryable error, it will be retried up to
    /// `maxRetries` times with exponential backoff and jitter.
    ///
    /// - Parameter operation: The async operation to execute.
    /// - Returns: The result of the successful operation.
    /// - Throws: The last error if all retries are exhausted, or immediately for non-retryable errors.
    func execute<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...configuration.maxRetries {
            do {
                // Check for cancellation before each attempt
                try Task.checkCancellation()

                let result = try await operation()
                if attempt > 0 {
                    Self.logger.info("Retry succeeded on attempt \(attempt + 1).")
                }
                return result
            } catch {
                lastError = error

                // Check if this error is retryable
                guard isRetryable(error) else {
                    Self.logger.info("Non-retryable error encountered. Not retrying.")
                    throw error
                }

                // Don't wait after the last attempt
                if attempt < configuration.maxRetries {
                    let delay = calculateDelay(attempt: attempt, error: error)
                    Self.logger.info("Attempt \(attempt + 1) failed. Retrying in \(String(format: "%.1f", delay))s (attempt \(attempt + 2) of \(self.configuration.maxRetries + 1)).")

                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    Self.logger.error("All \(self.configuration.maxRetries + 1) attempts exhausted.")
                }
            }
        }

        throw lastError ?? ClaudeAPIError.networkError("All retry attempts exhausted with no error captured.")
    }

    // MARK: - Retryability Check

    /// Determines whether an error is retryable.
    ///
    /// Retryable errors are transient failures that may succeed on retry:
    /// - Rate limiting (429)
    /// - Server errors (500, 502, 503)
    /// - Network errors (DNS, connection reset, etc.)
    /// - Timeouts
    /// - API overloaded (529)
    ///
    /// Non-retryable errors are permanent failures:
    /// - Unauthorized (401) — API key is wrong
    /// - Bad request (400) — request is malformed
    /// - No API key — missing configuration
    /// - Invalid response — parsing error
    ///
    /// - Parameter error: The error to check.
    /// - Returns: `true` if the error is retryable.
    func isRetryable(_ error: Error) -> Bool {
        guard let apiError = error as? ClaudeAPIError else {
            // Unknown errors (e.g., CancellationError) are NOT retryable
            return false
        }

        switch apiError {
        case .rateLimited:
            return true
        case .serverError:
            return true
        case .networkError:
            return true
        case .timeout:
            return true
        case .overloaded:
            return true
        case .unauthorized, .badRequest, .noAPIKey, .invalidResponse:
            return false
        }
    }

    // MARK: - Delay Calculation

    /// Calculates the delay before the next retry attempt.
    ///
    /// Uses exponential backoff with jitter:
    /// `delay = min(baseDelay * 2^attempt + random(0, maxJitter), maxDelay)`
    ///
    /// If the error is a rate limit with a Retry-After value, that value is used instead.
    ///
    /// - Parameters:
    ///   - attempt: The current attempt number (0-indexed).
    ///   - error: The error that triggered the retry (may contain Retry-After).
    /// - Returns: The delay in seconds.
    func calculateDelay(attempt: Int, error: Error) -> TimeInterval {
        // Check for Retry-After from rate limiting
        if let apiError = error as? ClaudeAPIError,
           case .rateLimited(let retryAfter) = apiError,
           let retryAfter = retryAfter {
            // Use the server-specified delay, but cap it at maxDelay
            return min(retryAfter, configuration.maxDelay)
        }

        // Exponential backoff: baseDelay * 2^attempt
        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))

        // Add random jitter
        let jitter = Double.random(in: 0...configuration.maxJitter)

        // Cap at maxDelay
        return min(exponentialDelay + jitter, configuration.maxDelay)
    }
}
```

STEP 2: Create the CircuitBreaker

File: src/LLM/CircuitBreaker.swift
```swift
// CircuitBreaker.swift
// EmberHearth
//
// Circuit breaker pattern for LLM API resilience.

import Foundation
import os

/// The three states of the circuit breaker.
enum CircuitBreakerState: String, Sendable, Equatable {
    /// Normal operation. Requests are allowed through.
    case closed
    /// Requests are blocked. The service is assumed to be down.
    case open
    /// Testing recovery. One request is allowed through.
    case halfOpen
}

/// Error thrown when the circuit breaker is open and blocking requests.
struct CircuitBreakerOpenError: Error, Sendable, Equatable {
    /// When the circuit breaker will transition to half-open and allow a test request.
    let retryAfter: Date

    var localizedDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeTime = formatter.localizedString(for: retryAfter, relativeTo: Date())
        return "Service temporarily unavailable. Will retry \(relativeTime)."
    }
}

/// Reports the current health status of the LLM service.
struct LLMServiceHealth: Sendable, Equatable {
    /// The current circuit breaker state.
    let state: CircuitBreakerState
    /// The number of consecutive failures.
    let consecutiveFailures: Int
    /// When the circuit was last opened (nil if never opened).
    let lastOpenedAt: Date?
    /// When the circuit will transition from open to halfOpen (nil if not open).
    let nextRetryAt: Date?
}

/// Implements the circuit breaker pattern for LLM API calls.
///
/// Prevents overwhelming a failing service with requests. After a threshold
/// of consecutive failures, the circuit "opens" and blocks all requests for
/// a cooldown period. After the cooldown, it allows a single test request.
///
/// Thread Safety: Uses an actor-like pattern with a lock for synchronization.
/// This is necessary because the circuit breaker state is shared across
/// concurrent API calls.
///
/// Usage:
/// ```swift
/// let breaker = CircuitBreaker()
/// let response = try await breaker.execute {
///     try await apiClient.sendMessage(messages, systemPrompt: prompt)
/// }
/// ```
final class CircuitBreaker: @unchecked Sendable {

    // MARK: - Configuration

    /// Number of consecutive failures before the circuit opens.
    let failureThreshold: Int

    /// How long the circuit stays open before transitioning to half-open (seconds).
    let resetTimeout: TimeInterval

    // MARK: - Internal State (protected by lock)

    /// Lock for thread-safe state access.
    private let lock = NSLock()

    /// Current circuit state.
    private var _state: CircuitBreakerState = .closed

    /// Number of consecutive failures.
    private var _consecutiveFailures: Int = 0

    /// When the circuit was last opened.
    private var _lastOpenedAt: Date? = nil

    /// Logger for circuit breaker events.
    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "CircuitBreaker"
    )

    // MARK: - Initialization

    /// Creates a circuit breaker with the specified configuration.
    ///
    /// - Parameters:
    ///   - failureThreshold: Number of consecutive failures to trigger open state. Default: 5.
    ///   - resetTimeout: Seconds to wait before transitioning from open to halfOpen. Default: 60.
    init(failureThreshold: Int = 5, resetTimeout: TimeInterval = 60.0) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    // MARK: - Public API

    /// The current state of the circuit breaker.
    var state: CircuitBreakerState {
        lock.lock()
        defer { lock.unlock() }
        return evaluateState()
    }

    /// Reports the current health status of the LLM service.
    var health: LLMServiceHealth {
        lock.lock()
        defer { lock.unlock() }
        let currentState = evaluateState()
        let nextRetry: Date? = if currentState == .open, let openedAt = _lastOpenedAt {
            openedAt.addingTimeInterval(resetTimeout)
        } else {
            nil
        }
        return LLMServiceHealth(
            state: currentState,
            consecutiveFailures: _consecutiveFailures,
            lastOpenedAt: _lastOpenedAt,
            nextRetryAt: nextRetry
        )
    }

    /// Executes an async operation through the circuit breaker.
    ///
    /// - If the circuit is **closed**: the operation runs normally.
    /// - If the circuit is **open**: throws `CircuitBreakerOpenError` immediately.
    /// - If the circuit is **halfOpen**: allows the operation as a test request.
    ///
    /// On success: resets the failure count (closes the circuit if half-open).
    /// On failure: increments the failure count (opens the circuit if threshold reached).
    ///
    /// - Parameter operation: The async operation to execute.
    /// - Returns: The result of the successful operation.
    /// - Throws: `CircuitBreakerOpenError` if the circuit is open, or the operation's error.
    func execute<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        // Check if the circuit allows this request
        try checkCircuit()

        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }

    /// Manually resets the circuit breaker to the closed state.
    /// Useful for testing or when external recovery is detected.
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _state = .closed
        _consecutiveFailures = 0
        _lastOpenedAt = nil
        Self.logger.info("Circuit breaker manually reset to closed.")
    }

    // MARK: - Internal State Management

    /// Evaluates the current state, potentially transitioning from open to halfOpen.
    /// Must be called with the lock held.
    private func evaluateState() -> CircuitBreakerState {
        if _state == .open, let openedAt = _lastOpenedAt {
            let elapsed = Date().timeIntervalSince(openedAt)
            if elapsed >= resetTimeout {
                _state = .halfOpen
                Self.logger.info("Circuit breaker transitioning from open to halfOpen after \(Int(elapsed))s cooldown.")
            }
        }
        return _state
    }

    /// Checks whether the circuit allows a request. Throws if the circuit is open.
    private func checkCircuit() throws {
        lock.lock()
        let currentState = evaluateState()
        lock.unlock()

        if currentState == .open {
            let retryDate: Date
            lock.lock()
            retryDate = (_lastOpenedAt ?? Date()).addingTimeInterval(resetTimeout)
            lock.unlock()

            Self.logger.info("Circuit breaker is OPEN. Blocking request. Retry after \(retryDate).")
            throw CircuitBreakerOpenError(retryAfter: retryDate)
        }
        // .closed and .halfOpen both allow the request through
    }

    /// Records a successful operation. Resets failure count and closes the circuit.
    private func recordSuccess() {
        lock.lock()
        defer { lock.unlock() }

        let previousState = _state

        _consecutiveFailures = 0
        _state = .closed

        if previousState == .halfOpen {
            Self.logger.info("Circuit breaker: halfOpen test succeeded. Closing circuit.")
        }
    }

    /// Records a failed operation. Increments failure count and potentially opens the circuit.
    private func recordFailure() {
        lock.lock()
        defer { lock.unlock() }

        _consecutiveFailures += 1

        if _state == .halfOpen {
            // Half-open test failed — reopen the circuit
            _state = .open
            _lastOpenedAt = Date()
            Self.logger.warning("Circuit breaker: halfOpen test failed. Reopening circuit for \(Int(self.resetTimeout))s.")
        } else if _consecutiveFailures >= failureThreshold {
            // Threshold reached — open the circuit
            _state = .open
            _lastOpenedAt = Date()
            Self.logger.warning("Circuit breaker OPENED after \(self._consecutiveFailures) consecutive failures. Blocking requests for \(Int(self.resetTimeout))s.")
        } else {
            Self.logger.info("Circuit breaker: failure \(self._consecutiveFailures)/\(self.failureThreshold).")
        }
    }
}
```

STEP 3: Create unit tests for RetryHandler

File: tests/RetryHandlerTests.swift
```swift
// RetryHandlerTests.swift
// EmberHearth
//
// Unit tests for RetryHandler.

import XCTest
@testable import EmberHearth

final class RetryHandlerTests: XCTestCase {

    private var handler: RetryHandler!

    override func setUp() {
        super.setUp()
        // Use fast delays for testing (10ms base, 100ms max, 10ms jitter)
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

    // MARK: - Success Tests

    func testExecuteSuccessOnFirstAttempt() async throws {
        var callCount = 0
        let result = try await handler.execute {
            callCount += 1
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1, "Should only call once on immediate success.")
    }

    func testExecuteSuccessOnSecondAttempt() async throws {
        var callCount = 0
        let result: String = try await handler.execute {
            callCount += 1
            if callCount == 1 {
                throw ClaudeAPIError.timeout
            }
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 2, "Should succeed on second attempt.")
    }

    func testExecuteSuccessOnLastAttempt() async throws {
        var callCount = 0
        let result: String = try await handler.execute {
            callCount += 1
            if callCount <= 3 {
                throw ClaudeAPIError.serverError(statusCode: 500)
            }
            return "success"
        }
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 4, "Should succeed on the 4th attempt (3 retries + 1 initial).")
    }

    // MARK: - Failure Tests

    func testExecuteExhaustsAllRetries() async {
        var callCount = 0
        do {
            let _: String = try await handler.execute {
                callCount += 1
                throw ClaudeAPIError.serverError(statusCode: 500)
            }
            XCTFail("Should have thrown after exhausting retries.")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(callCount, 4, "Should attempt 4 times (1 initial + 3 retries).")
            if case .serverError(let code) = error {
                XCTAssertEqual(code, 500)
            } else {
                XCTFail("Expected serverError, got \(error)")
            }
        } catch {
            XCTFail("Expected ClaudeAPIError, got \(error)")
        }
    }

    // MARK: - Non-Retryable Error Tests

    func testNonRetryableErrorDoesNotRetry() async {
        var callCount = 0

        // Test unauthorized (401) — should NOT retry
        do {
            let _: String = try await handler.execute {
                callCount += 1
                throw ClaudeAPIError.unauthorized
            }
            XCTFail("Should have thrown unauthorized error.")
        } catch let error as ClaudeAPIError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(callCount, 1, "Should NOT retry unauthorized errors.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBadRequestDoesNotRetry() async {
        var callCount = 0
        do {
            let _: String = try await handler.execute {
                callCount += 1
                throw ClaudeAPIError.badRequest("Invalid model")
            }
            XCTFail("Should have thrown.")
        } catch {
            XCTAssertEqual(callCount, 1, "Should NOT retry bad request errors.")
        }
    }

    func testNoAPIKeyDoesNotRetry() async {
        var callCount = 0
        do {
            let _: String = try await handler.execute {
                callCount += 1
                throw ClaudeAPIError.noAPIKey
            }
            XCTFail("Should have thrown.")
        } catch {
            XCTAssertEqual(callCount, 1, "Should NOT retry noAPIKey errors.")
        }
    }

    func testInvalidResponseDoesNotRetry() async {
        var callCount = 0
        do {
            let _: String = try await handler.execute {
                callCount += 1
                throw ClaudeAPIError.invalidResponse("Bad JSON")
            }
            XCTFail("Should have thrown.")
        } catch {
            XCTAssertEqual(callCount, 1, "Should NOT retry invalid response errors.")
        }
    }

    // MARK: - Retryable Error Tests

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
            .invalidResponse("Bad")
        ]

        for error in nonRetryableErrors {
            XCTAssertFalse(handler.isRetryable(error), "\(error) should NOT be retryable.")
        }
    }

    // MARK: - Delay Calculation Tests

    func testExponentialBackoffDelays() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)
        let dummyError = ClaudeAPIError.serverError(statusCode: 500)

        // Attempt 0: 1.0 * 2^0 = 1.0
        let delay0 = handler.calculateDelay(attempt: 0, error: dummyError)
        XCTAssertEqual(delay0, 1.0, accuracy: 0.01)

        // Attempt 1: 1.0 * 2^1 = 2.0
        let delay1 = handler.calculateDelay(attempt: 1, error: dummyError)
        XCTAssertEqual(delay1, 2.0, accuracy: 0.01)

        // Attempt 2: 1.0 * 2^2 = 4.0
        let delay2 = handler.calculateDelay(attempt: 2, error: dummyError)
        XCTAssertEqual(delay2, 4.0, accuracy: 0.01)
    }

    func testDelayDoesNotExceedMaxDelay() {
        let config = RetryConfiguration(maxRetries: 10, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)
        let dummyError = ClaudeAPIError.serverError(statusCode: 500)

        // Attempt 10: 1.0 * 2^10 = 1024 → capped at 30.0
        let delay = handler.calculateDelay(attempt: 10, error: dummyError)
        XCTAssertLessThanOrEqual(delay, 30.0)
    }

    func testRetryAfterHeaderRespected() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)

        let error = ClaudeAPIError.rateLimited(retryAfter: 15.0)
        let delay = handler.calculateDelay(attempt: 0, error: error)
        XCTAssertEqual(delay, 15.0, "Should use the Retry-After value from the server.")
    }

    func testRetryAfterCappedAtMaxDelay() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 0.0)
        let handler = RetryHandler(configuration: config)

        let error = ClaudeAPIError.rateLimited(retryAfter: 120.0)
        let delay = handler.calculateDelay(attempt: 0, error: error)
        XCTAssertEqual(delay, 30.0, "Retry-After should be capped at maxDelay.")
    }

    func testJitterAddsRandomness() {
        let config = RetryConfiguration(maxRetries: 3, baseDelay: 1.0, maxDelay: 30.0, maxJitter: 1.0)
        let handler = RetryHandler(configuration: config)
        let dummyError = ClaudeAPIError.serverError(statusCode: 500)

        // Run multiple times and verify jitter adds variation
        var delays: [TimeInterval] = []
        for _ in 0..<20 {
            delays.append(handler.calculateDelay(attempt: 0, error: dummyError))
        }

        // Base delay for attempt 0 is 1.0, with up to 1.0 jitter, so range is [1.0, 2.0]
        for delay in delays {
            XCTAssertGreaterThanOrEqual(delay, 1.0)
            XCTAssertLessThanOrEqual(delay, 2.0)
        }

        // With 20 samples, we should see some variation (not all identical)
        let uniqueDelays = Set(delays)
        XCTAssertGreaterThan(uniqueDelays.count, 1, "Jitter should produce varying delays.")
    }

    // MARK: - Default Configuration Tests

    func testDefaultConfiguration() {
        let config = RetryConfiguration.default
        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.baseDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 30.0)
        XCTAssertEqual(config.maxJitter, 1.0)
    }
}
```

STEP 4: Create unit tests for CircuitBreaker

File: tests/CircuitBreakerTests.swift
```swift
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
        // Use a short reset timeout for testing (0.5 seconds instead of 60)
        breaker = CircuitBreaker(failureThreshold: 3, resetTimeout: 0.5)
    }

    override func tearDown() {
        breaker = nil
        super.tearDown()
    }

    // MARK: - State Tests

    func testInitialStateIsClosed() {
        XCTAssertEqual(breaker.state, .closed)
    }

    func testCircuitStaysClosedOnSuccess() async throws {
        let result = try await breaker.execute { return "ok" }
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(breaker.state, .closed)
    }

    func testCircuitStaysClosedBelowThreshold() async {
        // Fail 2 times (below threshold of 3)
        for _ in 0..<2 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }
        XCTAssertEqual(breaker.state, .closed, "Circuit should stay closed below failure threshold.")
    }

    func testCircuitOpensAtThreshold() async {
        // Fail exactly 3 times (at threshold)
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }
        XCTAssertEqual(breaker.state, .open, "Circuit should open at failure threshold.")
    }

    func testOpenCircuitBlocksRequests() async {
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }
        XCTAssertEqual(breaker.state, .open)

        // Next request should be blocked immediately
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
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }
        XCTAssertEqual(breaker.state, .open)

        // Wait for the reset timeout (0.5 seconds)
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

        XCTAssertEqual(breaker.state, .halfOpen, "Circuit should transition to halfOpen after timeout.")
    }

    func testHalfOpenSuccessClosesCirucit() async throws {
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }

        // Wait for halfOpen
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(breaker.state, .halfOpen)

        // Successful request in halfOpen should close the circuit
        let result = try await breaker.execute { return "recovered" }
        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(breaker.state, .closed)
    }

    func testHalfOpenFailureReopensCircuit() async throws {
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }

        // Wait for halfOpen
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(breaker.state, .halfOpen)

        // Failed request in halfOpen should reopen the circuit
        do {
            let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
        } catch {}

        XCTAssertEqual(breaker.state, .open, "Circuit should reopen after halfOpen test failure.")
    }

    func testSuccessResetsFailureCount() async throws {
        // Fail twice
        for _ in 0..<2 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }

        // Succeed once — this should reset the failure count
        _ = try await breaker.execute { return "ok" }

        // Fail twice more — should NOT open (because count was reset)
        for _ in 0..<2 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }

        XCTAssertEqual(breaker.state, .closed, "Success should reset the failure count.")
    }

    func testManualReset() async {
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }
        XCTAssertEqual(breaker.state, .open)

        // Manual reset
        breaker.reset()
        XCTAssertEqual(breaker.state, .closed)
    }

    // MARK: - Health Reporting Tests

    func testHealthReportsClosed() {
        let health = breaker.health
        XCTAssertEqual(health.state, .closed)
        XCTAssertEqual(health.consecutiveFailures, 0)
        XCTAssertNil(health.lastOpenedAt)
        XCTAssertNil(health.nextRetryAt)
    }

    func testHealthReportsOpen() async {
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }

        let health = breaker.health
        XCTAssertEqual(health.state, .open)
        XCTAssertEqual(health.consecutiveFailures, 3)
        XCTAssertNotNil(health.lastOpenedAt)
        XCTAssertNotNil(health.nextRetryAt)
    }

    func testHealthReportsFailureCount() async {
        // Fail once
        do {
            let _: String = try await breaker.execute { throw ClaudeAPIError.timeout }
        } catch {}

        let health = breaker.health
        XCTAssertEqual(health.consecutiveFailures, 1)
        XCTAssertEqual(health.state, .closed) // Below threshold
    }

    // MARK: - CircuitBreakerOpenError Tests

    func testCircuitBreakerOpenErrorHasRetryDate() async {
        // Open the circuit
        for _ in 0..<3 {
            do {
                let _: String = try await breaker.execute { throw ClaudeAPIError.serverError(statusCode: 500) }
            } catch {}
        }

        do {
            let _: String = try await breaker.execute { return "blocked" }
            XCTFail("Should throw.")
        } catch let error as CircuitBreakerOpenError {
            // retryAfter should be in the future
            XCTAssertGreaterThan(error.retryAfter, Date())
        } catch {
            XCTFail("Expected CircuitBreakerOpenError, got \(error)")
        }
    }

    // MARK: - Default Configuration Tests

    func testDefaultCircuitBreakerConfiguration() {
        let defaultBreaker = CircuitBreaker()
        XCTAssertEqual(defaultBreaker.failureThreshold, 5)
        XCTAssertEqual(defaultBreaker.resetTimeout, 60.0)
        XCTAssertEqual(defaultBreaker.state, .closed)
    }
}
```

IMPORTANT NOTES:
- Two new source files: `src/LLM/RetryHandler.swift` and `src/LLM/CircuitBreaker.swift`
- Two new test files: `tests/RetryHandlerTests.swift` and `tests/CircuitBreakerTests.swift`
- NO existing files are modified in this task. The integration of RetryHandler and CircuitBreaker with ClaudeAPIClient will be done when the message coordinator is built (a later milestone).
- The RetryHandler and CircuitBreaker are independent components that can be composed by the caller:
  ```swift
  // Future usage pattern (not built yet):
  let response = try await circuitBreaker.execute {
      try await retryHandler.execute {
          try await apiClient.sendMessage(messages, systemPrompt: prompt)
      }
  }
  ```
- Test timing: CircuitBreaker tests use a 0.5-second reset timeout and `Task.sleep` for timing. RetryHandler tests use 10ms delays. This keeps tests fast.
- The CircuitBreaker uses NSLock for thread safety (not an actor) because it needs synchronous property access for `state` and `health`.
- The LLMServiceHealth struct is designed to be displayed in the Settings status panel described in error-handling.md.
- After creating all files, run:
  1. `swift build` from project root
  2. `swift test --filter RetryHandlerTests` to run retry tests
  3. `swift test --filter CircuitBreakerTests` to run circuit breaker tests
  4. `swift test` to run all tests
```

---

## Acceptance Criteria

- [ ] `src/LLM/RetryHandler.swift` exists with `execute()`, `isRetryable()`, `calculateDelay()` methods
- [ ] `src/LLM/CircuitBreaker.swift` exists with `execute()`, `reset()`, `state`, `health` members
- [ ] `RetryConfiguration` has: maxRetries=3, baseDelay=1.0, maxDelay=30.0, maxJitter=1.0 (defaults)
- [ ] Exponential backoff: delay = min(baseDelay * 2^attempt + jitter, maxDelay)
- [ ] Retry-After header is respected when present on rate limit errors
- [ ] Retryable errors: rateLimited, serverError, networkError, timeout, overloaded
- [ ] Non-retryable errors: unauthorized, badRequest, noAPIKey, invalidResponse
- [ ] CircuitBreaker has three states: closed, open, halfOpen
- [ ] Circuit opens after 5 consecutive failures (default)
- [ ] Circuit stays open for 60 seconds (default), then transitions to halfOpen
- [ ] In halfOpen: success closes circuit, failure reopens it
- [ ] `CircuitBreakerOpenError` is thrown when circuit is open (contains retryAfter date)
- [ ] `LLMServiceHealth` struct reports current state, failure count, timing
- [ ] Tests use fast timing (short delays) to keep test suite quick
- [ ] No existing files are modified
- [ ] `swift build` succeeds
- [ ] `swift test` passes all tests

---

## Verification Commands

```bash
# Navigate to project root
cd /Users/robault/Documents/GitHub/emberhearth

# Verify new files exist
test -f src/LLM/RetryHandler.swift && echo "RetryHandler.swift exists" || echo "MISSING: RetryHandler.swift"
test -f src/LLM/CircuitBreaker.swift && echo "CircuitBreaker.swift exists" || echo "MISSING: CircuitBreaker.swift"
test -f tests/RetryHandlerTests.swift && echo "RetryHandlerTests.swift exists" || echo "MISSING: RetryHandlerTests.swift"
test -f tests/CircuitBreakerTests.swift && echo "CircuitBreakerTests.swift exists" || echo "MISSING: CircuitBreakerTests.swift"

# Verify no existing files were modified (these should be unchanged from tasks 0200-0202)
git diff --name-only src/LLM/ClaudeAPIClient.swift 2>/dev/null && echo "NOTE: ClaudeAPIClient.swift was modified" || echo "OK: ClaudeAPIClient.swift unchanged"

# Verify retry configuration defaults
grep -n "maxRetries: 3" src/LLM/RetryHandler.swift && echo "OK: maxRetries is 3" || echo "WARNING: maxRetries not 3"
grep -n "baseDelay: 1.0" src/LLM/RetryHandler.swift && echo "OK: baseDelay is 1.0" || echo "WARNING: baseDelay not 1.0"

# Verify circuit breaker defaults
grep -n "failureThreshold: Int = 5" src/LLM/CircuitBreaker.swift && echo "OK: Threshold is 5" || echo "WARNING: Threshold not 5"
grep -n "resetTimeout: TimeInterval = 60" src/LLM/CircuitBreaker.swift && echo "OK: Timeout is 60" || echo "WARNING: Timeout not 60"

# Build the project
swift build 2>&1

# Run retry handler tests
swift test --filter RetryHandlerTests 2>&1

# Run circuit breaker tests
swift test --filter CircuitBreakerTests 2>&1

# Run all tests
swift test 2>&1
```

---

## Opus Verification Prompt

> After Sonnet completes and verification commands pass, paste this into a new Claude Opus session.

```
Review the retry handler and circuit breaker implementation created in task 0204 for EmberHearth. Check for these specific issues:

1. RETRY LOGIC CORRECTNESS:
   - Open src/LLM/RetryHandler.swift
   - Verify the retry loop runs maxRetries+1 total attempts (1 initial + maxRetries retries)
   - Verify non-retryable errors are thrown immediately (no retry)
   - Verify retryable error classification matches the spec:
     - Retryable: rateLimited, serverError, networkError, timeout, overloaded
     - Non-retryable: unauthorized, badRequest, noAPIKey, invalidResponse
   - Verify exponential backoff formula: min(baseDelay * 2^attempt + jitter, maxDelay)
   - Verify Retry-After header value is used when present on rateLimited errors
   - Verify Retry-After is capped at maxDelay
   - Verify Task.checkCancellation() is called before each attempt
   - Verify the LAST error is thrown when all retries are exhausted (not the first)

2. CIRCUIT BREAKER CORRECTNESS:
   - Open src/LLM/CircuitBreaker.swift
   - Verify three states exist: closed, open, halfOpen
   - Verify the circuit opens after exactly failureThreshold consecutive failures
   - Verify a success resets the consecutive failure count to 0
   - Verify the open→halfOpen transition happens after resetTimeout seconds
   - Verify halfOpen allows exactly 1 request:
     - Success → closed (reset failure count)
     - Failure → open (restart timer)
   - Verify open state throws CircuitBreakerOpenError (not any generic error)
   - Verify CircuitBreakerOpenError includes a retryAfter date in the future

3. THREAD SAFETY:
   - Verify CircuitBreaker uses a lock (NSLock) for all state access
   - Verify lock.lock() and lock.unlock() are properly paired (no deadlocks)
   - Verify defer { lock.unlock() } is used consistently
   - Verify the lock is NOT held during the async operation execution (would cause deadlock)
   - Verify the evaluateState() method is called within the lock
   - Verify CircuitBreaker is marked @unchecked Sendable (because of NSLock)
   - Verify RetryHandler is marked Sendable

4. HEALTH REPORTING:
   - Verify LLMServiceHealth includes: state, consecutiveFailures, lastOpenedAt, nextRetryAt
   - Verify nextRetryAt is only non-nil when state is .open
   - Verify LLMServiceHealth is Sendable and Equatable

5. INDEPENDENCE:
   - Verify NO existing files were modified (ClaudeAPIClient should be untouched)
   - RetryHandler and CircuitBreaker should be standalone components
   - They should be composable (breaker wraps retrier wraps operation)

6. TEST QUALITY:
   - Verify RetryHandler tests cover:
     - Success on first attempt
     - Success on second attempt
     - Success on last attempt
     - All retries exhausted
     - Non-retryable errors don't retry (unauthorized, badRequest, noAPIKey, invalidResponse)
     - Exponential backoff timing (without jitter)
     - Max delay cap
     - Retry-After header respected
     - Retry-After capped at maxDelay
     - Jitter produces variation
   - Verify CircuitBreaker tests cover:
     - Initial state is closed
     - Stays closed on success
     - Stays closed below threshold
     - Opens at threshold
     - Open blocks requests
     - Transitions to halfOpen after timeout
     - HalfOpen success closes
     - HalfOpen failure reopens
     - Success resets failure count
     - Manual reset
     - Health reporting in various states
   - Verify tests use fast timing (not 60-second waits)

7. BUILD VERIFICATION:
   - Run `swift build` — verify no warnings or errors
   - Run `swift test` — verify ALL tests pass (including tasks 0200-0203)

Report any issues found with exact file paths and line numbers.
```

---

## Commit Message

```
feat(m3): add retry handler and circuit breaker for LLM calls
```

---

## Notes for Next Task

- The RetryHandler and CircuitBreaker are standalone components. They will be integrated with ClaudeAPIClient when the message coordinator is built (M2/M3 integration tasks).
- The typical composition pattern will be:
  ```swift
  let response = try await circuitBreaker.execute {
      try await retryHandler.execute {
          try await apiClient.sendMessage(messages, systemPrompt: prompt)
      }
  }
  ```
- The `LLMServiceHealth` struct is designed to be consumed by the Settings status panel (described in docs/specs/error-handling.md, lines 433-453).
- The circuit breaker's `health` property can also be used by the startup health check system (error-handling.md, lines 393-429).
- For streaming requests, the same retry/circuit-breaker pattern applies, but retry on stream interruption is more nuanced — that will be handled in the integration layer.
- M3 (LLM Integration) is now complete with tasks 0200-0204. The next milestone (M4 - Memory System) builds the SQLite database and fact storage.
