// ClaudeAPIError.swift
// EmberHearth
//
// Domain-specific error types for the Claude API client.

import Foundation

/// Errors that can occur when communicating with the Claude API.
///
/// ## Retryable errors (transient — may succeed on retry)
/// - `rateLimited` — HTTP 429. Back off and retry; respect Retry-After if present.
/// - `serverError` — HTTP 500/502/503. Transient server failure.
/// - `overloaded` — HTTP 529. Anthropic-specific overload signal.
/// - `networkError` — DNS failure, connection reset, etc.
/// - `timeout` — Request exceeded timeout.
/// - `streamInterrupted` — SSE stream dropped mid-response.
///
/// ## Non-retryable errors (permanent — fix the request or config)
/// - `unauthorized` — HTTP 401. Invalid or missing API key.
/// - `noAPIKey` — API key not configured at all.
/// - `badRequest` — HTTP 400. Malformed or invalid request.
/// - `decodingError` — Response body couldn't be parsed.
/// - `unknown` — Unexpected error; treat as non-retryable.
enum ClaudeAPIError: Error, LocalizedError, Sendable, Equatable {

    // MARK: - Retryable

    /// HTTP 429 — rate limited. Use `retryAfter` if provided by the server.
    case rateLimited(retryAfter: TimeInterval?)

    /// HTTP 500/502/503 — transient server failure.
    case serverError(statusCode: Int)

    /// HTTP 529 — Anthropic overload signal.
    case overloaded

    /// Network-level failure (DNS, connection reset, TLS, etc.).
    case networkError(String)

    /// Request timed out before a response was received.
    case timeout

    /// SSE streaming connection was interrupted mid-response.
    case streamInterrupted(String)

    // MARK: - Non-Retryable

    /// HTTP 401 — invalid or revoked API key.
    case unauthorized

    /// API key is not configured (missing from Keychain).
    case noAPIKey

    /// HTTP 400 — request was malformed or invalid.
    case badRequest(String)

    /// Response body could not be decoded.
    case decodingError(String)

    /// Unexpected error with no specific handling.
    case unknown(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .rateLimited(let retryAfter):
            if let interval = retryAfter {
                return "Rate limited by the API. Retry after \(Int(interval))s."
            }
            return "Rate limited by the API."
        case .serverError(let statusCode):
            return "Server error: HTTP \(statusCode)."
        case .overloaded:
            return "Service is overloaded. Please retry later."
        case .networkError(let detail):
            return "Network error: \(detail)"
        case .timeout:
            return "Request timed out."
        case .streamInterrupted(let detail):
            return "Stream interrupted: \(detail)"
        case .unauthorized:
            return "Unauthorized — check your API key."
        case .noAPIKey:
            return "No API key configured. Add it to Keychain."
        case .badRequest(let detail):
            return "Bad request: \(detail)"
        case .decodingError(let detail):
            return "Decoding error: \(detail)"
        case .unknown(let detail):
            return "Unexpected error: \(detail)"
        }
    }
}
