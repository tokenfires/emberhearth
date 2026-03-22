// CredentialScanResult.swift
// EmberHearth
//
// Result of scanning an outbound response for credentials.

import Foundation

/// The result of scanning an outbound LLM response for credential leaks.
///
/// If credentials are detected, `containsCredentials` is true and
/// `redactedResponse` contains the response with credentials replaced
/// by `[REDACTED]` placeholders. The original response is NOT stored
/// to avoid keeping credentials in memory longer than necessary.
struct CredentialScanResult: Sendable {
    /// Whether any credentials were detected in the response.
    let containsCredentials: Bool

    /// The response with any detected credentials replaced by `[REDACTED]`.
    /// If no credentials were detected, this is identical to the original response.
    let redactedResponse: String

    /// The types of credentials detected (e.g., ["OpenAI API Key", "GitHub Token"]).
    /// Used for logging. NEVER includes the actual credential values.
    let detectedTypes: [String]

    /// The number of individual credential matches found.
    let matchCount: Int

    /// Creates a clean (no credentials) scan result.
    ///
    /// - Parameter response: The original response that passed clean.
    static func clean(response: String) -> CredentialScanResult {
        CredentialScanResult(
            containsCredentials: false,
            redactedResponse: response,
            detectedTypes: [],
            matchCount: 0
        )
    }
}
