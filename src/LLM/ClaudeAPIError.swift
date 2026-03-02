// ClaudeAPIError.swift
// EmberHearth
//
// Domain-specific error type for the Claude API client.

import Foundation

/// Errors that can be thrown by ClaudeAPIClient.
public enum ClaudeAPIError: Error, Equatable {

    /// No API key is stored in the Keychain.
    case noAPIKey

    /// The API key was rejected (HTTP 401).
    case unauthorized

    /// The request was rate-limited (HTTP 429).
    /// - Parameter retryAfter: Seconds to wait before retrying, if provided by the server.
    case rateLimited(retryAfter: Double?)

    /// The request body was invalid (HTTP 400).
    /// - Parameter message: The error message returned by the API.
    case badRequest(String)

    /// A server-side error occurred (HTTP 5xx).
    /// - Parameter statusCode: The HTTP status code.
    case serverError(Int)

    /// The API is temporarily overloaded (HTTP 529).
    case overloaded

    /// Streaming is not yet implemented.
    case notImplemented

    /// The response body could not be decoded.
    case decodingFailed(String)

    /// An unexpected HTTP status code was received.
    case unexpectedStatusCode(Int)
}