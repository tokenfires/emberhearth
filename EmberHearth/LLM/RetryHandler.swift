// RetryHandler.swift
// EmberHearth
//
// Retry logic with exponential backoff for LLM API calls.

import Foundation
import os

/// Configuration for retry behavior.
struct RetryConfiguration: Sendable {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let maxJitter: TimeInterval

    static let `default` = RetryConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        maxJitter: 1.0
    )
}

final class RetryHandler: Sendable {
    let configuration: RetryConfiguration

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "RetryHandler"
    )

    init(configuration: RetryConfiguration = .default) {
        self.configuration = configuration
    }

    func execute<T: Sendable>(
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...configuration.maxRetries {
            do {
                try Task.checkCancellation()
                let result = try await operation()
                if attempt > 0 {
                    Self.logger.info("Retry succeeded on attempt \(attempt + 1).")
                }
                return result
            } catch {
                lastError = error
                guard isRetryable(error) else {
                    Self.logger.info("Non-retryable error encountered. Not retrying.")
                    throw error
                }
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

    func isRetryable(_ error: Error) -> Bool {
        guard let apiError = error as? ClaudeAPIError else {
            return false
        }
        switch apiError {
        case .rateLimited, .serverError, .networkError, .timeout, .overloaded, .streamInterrupted:
            return true
        case .unauthorized, .noAPIKey, .badRequest, .decodingError, .unknown:
            return false
        }
    }

    func calculateDelay(attempt: Int, error: Error) -> TimeInterval {
        if let apiError = error as? ClaudeAPIError,
           case .rateLimited(let retryAfter) = apiError,
           let retryAfter = retryAfter {
            return min(retryAfter, configuration.maxDelay)
        }
        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt))
        let jitter = Double.random(in: 0...configuration.maxJitter)
        return min(exponentialDelay + jitter, configuration.maxDelay)
    }
}
