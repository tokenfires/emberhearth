// ClaudeAPIError.swift
// EmberHearth
//
// Domain-specific error types for the Claude API client.

import Foundation

/// Errors that can occur when communicating with the Claude API.
enum ClaudeAPIError: Error, LocalizedError, Sendable, Equatable {
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
    /// Rate limited with optional retry-after interval.
    case rateLimited(retryAfter: TimeInterval?)
    /// Server returned an error status code.
    case serverError(statusCode: Int)
    /// Network-level error.
    case networkError(String)
    /// Request timed out.
    case timeout
    /// Service is overloaded.
    case overloaded
    /// Unauthorized (invalid credentials).
    case unauthorized
    /// Bad request.
    case badRequest(String)
    /// No API key configured.
    case noAPIKey
    /// Invalid response from server.
    case invalidResponse(String)

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
        case .rateLimited:
            return "Rate limited by the API."
        case .serverError(let statusCode):
            return "Server error: \(statusCode)"
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .timeout:
            return "Request timed out."
        case .overloaded:
            return "Service is overloaded."
        case .unauthorized:
            return "Unauthorized."
        case .badRequest(let detail):
            return "Bad request: \(detail)"
        case .noAPIKey:
            return "No API key configured."
        case .invalidResponse(let detail):
            return "Invalid response: \(detail)"
        }
    }
}