// CircuitBreaker.swift
// EmberHearth
//
// Circuit breaker pattern for LLM API resilience.

import Foundation
import os

enum CircuitBreakerState: String, Sendable, Equatable {
    case closed
    case open
    case halfOpen
}

struct CircuitBreakerOpenError: Error, Sendable, Equatable {
    let retryAfter: Date

    var localizedDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relativeTime = formatter.localizedString(for: retryAfter, relativeTo: Date())
        return "Service temporarily unavailable. Will retry \(relativeTime)."
    }
}

struct LLMServiceHealth: Sendable, Equatable {
    let state: CircuitBreakerState
    let consecutiveFailures: Int
    let lastOpenedAt: Date?
    let nextRetryAt: Date?
}

final class CircuitBreaker: @unchecked Sendable {
    let failureThreshold: Int
    let resetTimeout: TimeInterval

    private let lock = NSLock()
    private var _state: CircuitBreakerState = .closed
    private var _consecutiveFailures: Int = 0
    private var _lastOpenedAt: Date? = nil

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "CircuitBreaker"
    )

    init(failureThreshold: Int = 5, resetTimeout: TimeInterval = 60.0) {
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }

    var state: CircuitBreakerState {
        lock.lock()
        defer { lock.unlock() }
        return evaluateState()
    }

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

    func execute<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
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

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        _state = .closed
        _consecutiveFailures = 0
        _lastOpenedAt = nil
        Self.logger.info("Circuit breaker manually reset to closed.")
    }

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
    }

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

    private func recordFailure() {
        lock.lock()
        defer { lock.unlock() }
        _consecutiveFailures += 1
        if _state == .halfOpen {
            _state = .open
            _lastOpenedAt = Date()
            Self.logger.warning("Circuit breaker: halfOpen test failed. Reopening circuit for \(Int(self.resetTimeout))s.")
        } else if _consecutiveFailures >= failureThreshold {
            _state = .open
            _lastOpenedAt = Date()
            Self.logger.warning("Circuit breaker OPENED after \(self._consecutiveFailures) consecutive failures. Blocking requests for \(Int(self.resetTimeout))s.")
        } else {
            Self.logger.info("Circuit breaker: failure \(self._consecutiveFailures)/\(self.failureThreshold).")
        }
    }
}
