// ClaudeAPIError.swift
// EmberHearth
//
// Domain-specific error types for the Claude API client.

import Foundation

/// Errors that can occur when communicating with the Claude API.
enum ClaudeAPIError: Error, LocalizedError, Sendable {
    /// The API returned an HTTP error status code.
    case httpError(statusCode: Int, message: String)
    /// The response could not be decoded.
    case decodingError(String)
    /// The streaming connection was interrupted unexpectedly.
    case streamInterrupted(String)
    /// The request was invalid or malformed.
    case invalidRequest(String)
    /// Authentication failed (invalid or missing API key).
    case authenticationError
    /// The API rate limit was exceeded.
    case rateLimitExceeded
    /// An unexpected error occurred.
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .decodingError(let detail):
            return "Decoding error: \(detail)"
        case .streamInterrupted(let detail):
            return "Stream interrupted: \(detail)"
        case .invalidRequest(let detail):
            return "Invalid request: \(detail)"
        case .authenticationError:
            return "Authentication failed. Check your API key."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .unknown(let detail):
            return "Unknown error: \(detail)"
        }
    }
}