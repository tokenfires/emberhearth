// URLValidator.swift
// EmberHearth
//
// Validates and sanitizes URLs before fetching.

import Foundation

/// Validates URLs to ensure they are safe to fetch.
///
/// Checks:
/// - Only HTTP and HTTPS schemes allowed
/// - No file://, ftp://, or other schemes
/// - No localhost or loopback addresses
/// - No private IP ranges (10.x, 172.16-31.x, 192.168.x)
/// - Not in the blocked domains list
struct URLValidator {

    /// Private IPv4 address ranges that should not be fetched.
    private static let privateIPRanges: [(prefix: String, description: String)] = [
        ("10.", "Private (10.0.0.0/8)"),
        ("172.16.", "Private (172.16.0.0/12)"),
        ("172.17.", "Private (172.16.0.0/12)"),
        ("172.18.", "Private (172.16.0.0/12)"),
        ("172.19.", "Private (172.16.0.0/12)"),
        ("172.20.", "Private (172.16.0.0/12)"),
        ("172.21.", "Private (172.16.0.0/12)"),
        ("172.22.", "Private (172.16.0.0/12)"),
        ("172.23.", "Private (172.16.0.0/12)"),
        ("172.24.", "Private (172.16.0.0/12)"),
        ("172.25.", "Private (172.16.0.0/12)"),
        ("172.26.", "Private (172.16.0.0/12)"),
        ("172.27.", "Private (172.16.0.0/12)"),
        ("172.28.", "Private (172.16.0.0/12)"),
        ("172.29.", "Private (172.16.0.0/12)"),
        ("172.30.", "Private (172.16.0.0/12)"),
        ("172.31.", "Private (172.16.0.0/12)"),
        ("192.168.", "Private (192.168.0.0/16)"),
        ("127.", "Loopback"),
        ("0.", "Invalid"),
        ("169.254.", "Link-local")
    ]

    /// Validates a URL for safe fetching.
    ///
    /// - Parameters:
    ///   - url: The URL to validate.
    ///   - blockedDomains: Set of blocked domain names.
    /// - Throws: `WebFetcherError` if the URL is not safe to fetch.
    static func validate(_ url: URL, blockedDomains: Set<String>) throws {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw WebFetcherError.invalidURL(reason: "Only HTTP and HTTPS URLs are allowed")
        }

        guard let host = url.host?.lowercased(), !host.isEmpty else {
            throw WebFetcherError.invalidURL(reason: "URL must have a host")
        }

        if host == "localhost" || host == "127.0.0.1" || host == "::1" || host == "[::1]" {
            throw WebFetcherError.invalidURL(reason: "Localhost URLs are not allowed")
        }

        for range in privateIPRanges {
            if host.hasPrefix(range.prefix) {
                throw WebFetcherError.invalidURL(reason: "\(range.description) addresses are not allowed")
            }
        }

        for blockedDomain in blockedDomains {
            if host == blockedDomain || host.hasSuffix(".\(blockedDomain)") {
                throw WebFetcherError.blockedDomain(domain: host)
            }
        }
    }

    /// Detects URLs in a text message.
    ///
    /// Uses NSDataDetector to find URLs in user messages. This is used
    /// by the MessageCoordinator to auto-detect shared links.
    ///
    /// - Parameter text: The message text to scan.
    /// - Returns: An array of detected URLs.
    static func detectURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }

        let range = NSRange(text.startIndex..., in: text)
        let matches = detector.matches(in: text, range: range)

        return matches.compactMap { match -> URL? in
            guard let url = match.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                return nil
            }
            return url
        }
    }
}
