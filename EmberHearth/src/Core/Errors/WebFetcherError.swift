// WebFetcherError.swift
// EmberHearth
//
// Error types for the web fetcher.

import Foundation

/// Errors that can occur during web fetching and content extraction.
enum WebFetcherError: LocalizedError, Equatable {
    /// The URL is not valid (wrong scheme, blocked domain, private IP, etc.).
    case invalidURL(reason: String)

    /// A network error occurred during the fetch.
    case networkError(String)

    /// The request timed out (exceeded 15 seconds).
    case timeout

    /// The response body exceeded the size limit (1MB).
    case tooLarge(size: Int, limit: Int)

    /// The URL's domain is in the blocked list.
    case blockedDomain(domain: String)

    /// Too many redirects (exceeded 3).
    case tooManyRedirects

    var errorDescription: String? {
        switch self {
        case .invalidURL(let reason):
            return "Invalid URL: \(reason)"
        case .networkError(let description):
            return "Network error: \(description)"
        case .timeout:
            return "Request timed out after \(Int(WebFetcher.timeoutInterval)) seconds."
        case .tooLarge(let size, let limit):
            return "Response too large: \(size / 1024)KB exceeds \(limit / 1024)KB limit."
        case .blockedDomain(let domain):
            return "Domain blocked: \(domain)"
        case .tooManyRedirects:
            return "Too many redirects (maximum: \(WebFetcher.maxRedirects))."
        }
    }

    static func == (lhs: WebFetcherError, rhs: WebFetcherError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let a), .invalidURL(let b)): return a == b
        case (.networkError(let a), .networkError(let b)): return a == b
        case (.timeout, .timeout): return true
        case (.tooLarge(let s1, let l1), .tooLarge(let s2, let l2)): return s1 == s2 && l1 == l2
        case (.blockedDomain(let a), .blockedDomain(let b)): return a == b
        case (.tooManyRedirects, .tooManyRedirects): return true
        default: return false
        }
    }
}
