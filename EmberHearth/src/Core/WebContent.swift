// WebContent.swift
// EmberHearth
//
// Represents fetched and extracted web content.

import Foundation

/// The result of fetching and extracting content from a web page.
///
/// Contains the extracted text content, page title, source URL,
/// and fetch timestamp. This is what gets included in the LLM
/// context when a user shares a URL.
struct WebContent: Sendable {
    /// The original URL that was fetched.
    let url: URL

    /// The page title extracted from the <title> tag, if present.
    let title: String?

    /// The extracted main text content from the page.
    /// HTML tags, scripts, styles, and navigation are stripped.
    /// Truncated to WebFetcher.maxExtractedTextLength if the original was longer.
    let textContent: String

    /// When the content was fetched.
    let fetchedAt: Date

    /// A formatted summary string suitable for including in LLM context.
    ///
    /// Format:
    /// ```
    /// [Web page: "Title" from example.com]
    /// Content here...
    /// ```
    var contextString: String {
        var header = "[Web page"
        if let title = title, !title.isEmpty {
            header += ": \"\(title)\""
        }
        if let host = url.host {
            header += " from \(host)"
        }
        header += "]\n"
        return header + textContent
    }
}
