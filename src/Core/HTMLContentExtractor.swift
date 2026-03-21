// HTMLContentExtractor.swift
// EmberHearth
//
// Extracts text content from HTML without third-party dependencies.

import Foundation

/// Extracts text content from raw HTML strings.
///
/// This is a simple, dependency-free HTML text extractor for MVP.
/// It strips HTML tags, removes script/style/nav/footer content,
/// and extracts the main article text.
///
/// ## Limitations (MVP)
/// - No JavaScript rendering (static HTML only)
/// - No CSS-based content detection
/// - Simple tag-based extraction (not DOM-aware)
/// - May include some boilerplate text from sidebars
///
/// ## Extraction Priority
/// 1. Content within `<article>` tags
/// 2. Content within `<main>` tags
/// 3. Content within `<body>` tags (fallback)
struct HTMLContentExtractor {

    // MARK: - Title Extraction

    /// Extracts the page title from HTML.
    ///
    /// Looks for content between `<title>` and `</title>` tags.
    ///
    /// - Parameter html: The raw HTML string.
    /// - Returns: The page title, or nil if not found.
    func extractTitle(from html: String) -> String? {
        guard let titleStart = html.range(of: "<title", options: .caseInsensitive),
              let titleTagEnd = html.range(of: ">", range: titleStart.upperBound..<html.endIndex),
              let titleEnd = html.range(of: "</title>", options: .caseInsensitive, range: titleTagEnd.upperBound..<html.endIndex) else {
            return nil
        }

        let title = String(html[titleTagEnd.upperBound..<titleEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return title.isEmpty ? nil : decodeHTMLEntities(title)
    }

    // MARK: - Article Text Extraction

    /// Extracts the main text content from HTML.
    ///
    /// Strategy:
    /// 1. Remove `<script>`, `<style>`, `<nav>`, `<footer>`, `<header>`,
    ///    `<aside>`, `<noscript>` elements and their content
    /// 2. Look for `<article>` content first, then `<main>`, then `<body>`
    /// 3. Strip all remaining HTML tags
    /// 4. Decode HTML entities
    /// 5. Collapse whitespace
    ///
    /// - Parameter html: The raw HTML string.
    /// - Returns: The extracted text content.
    func extractArticleText(from html: String) -> String {
        var workingHTML = html

        let elementsToRemove = ["script", "style", "nav", "footer", "header", "aside", "noscript", "svg", "iframe"]
        for element in elementsToRemove {
            workingHTML = removeElement(element, from: workingHTML)
        }

        var contentHTML: String
        if let articleContent = extractElementContent("article", from: workingHTML) {
            contentHTML = articleContent
        } else if let mainContent = extractElementContent("main", from: workingHTML) {
            contentHTML = mainContent
        } else if let bodyContent = extractElementContent("body", from: workingHTML) {
            contentHTML = bodyContent
        } else {
            contentHTML = workingHTML
        }

        var text = stripHTMLTags(from: contentHTML)
        text = decodeHTMLEntities(text)
        text = collapseWhitespace(text)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private Helpers

    /// Removes an HTML element and all its content (including nested instances).
    ///
    /// - Parameters:
    ///   - element: The element name (e.g., "script", "style").
    ///   - html: The HTML string to process.
    /// - Returns: The HTML with the element removed.
    private func removeElement(_ element: String, from html: String) -> String {
        var result = html
        let openPattern = "<\(element)[^>]*>"
        let closeTag = "</\(element)>"

        while let openRange = result.range(of: openPattern, options: [.caseInsensitive, .regularExpression]) {
            if let closeRange = result.range(of: closeTag, options: .caseInsensitive, range: openRange.lowerBound..<result.endIndex) {
                result.removeSubrange(openRange.lowerBound..<closeRange.upperBound)
            } else {
                result.removeSubrange(openRange)
            }
        }

        return result
    }

    /// Extracts the content between the first opening and last closing tag of an element.
    ///
    /// - Parameters:
    ///   - element: The element name (e.g., "article", "main").
    ///   - html: The HTML string to search.
    /// - Returns: The inner HTML content, or nil if the element is not found.
    private func extractElementContent(_ element: String, from html: String) -> String? {
        let openPattern = "<\(element)[^>]*>"
        guard let openRange = html.range(of: openPattern, options: [.caseInsensitive, .regularExpression]) else {
            return nil
        }

        let closeTag = "</\(element)>"
        guard let closeRange = html.range(of: closeTag, options: [.caseInsensitive, .backwards]) else {
            return nil
        }

        guard openRange.upperBound < closeRange.lowerBound else {
            return nil
        }

        return String(html[openRange.upperBound..<closeRange.lowerBound])
    }

    /// Strips all HTML tags from a string.
    ///
    /// - Parameter html: The HTML string to strip.
    /// - Returns: The text with all tags removed.
    private func stripHTMLTags(from html: String) -> String {
        var text = html
        text = text.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?p[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?div[^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "</?h[1-6][^>]*>", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "<li[^>]*>", with: "\n- ", options: .regularExpression)
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return text
    }

    /// Decodes common HTML entities to their text equivalents.
    ///
    /// - Parameter text: The text with HTML entities.
    /// - Returns: The decoded text.
    private func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text
        let entities: [(entity: String, replacement: String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&#39;", "'"),
            ("&apos;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "--"),
            ("&ndash;", "-"),
            ("&lsquo;", "'"),
            ("&rsquo;", "'"),
            ("&ldquo;", "\""),
            ("&rdquo;", "\""),
            ("&hellip;", "..."),
            ("&copy;", "(c)"),
            ("&reg;", "(R)"),
            ("&trade;", "(TM)")
        ]

        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }

        decoded = decodeNumericEntities(decoded)

        return decoded
    }

    /// Decodes numeric HTML entities (&#NNN; and &#xHHH;).
    private func decodeNumericEntities(_ text: String) -> String {
        var result = text

        let decimalPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let numRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }

        let hexPattern = "&#[xX]([0-9a-fA-F]+);"
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range).reversed()
            for match in matches {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[hexRange], radix: 16),
                   let scalar = Unicode.Scalar(code) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }

        return result
    }

    /// Collapses multiple whitespace characters into single spaces,
    /// and multiple newlines into double newlines (paragraph breaks).
    ///
    /// - Parameter text: The text to collapse.
    /// - Returns: The text with collapsed whitespace.
    private func collapseWhitespace(_ text: String) -> String {
        var result = text

        result = result.replacingOccurrences(of: "\t", with: " ")
        result = result.replacingOccurrences(of: "\r\n", with: "\n")
        result = result.replacingOccurrences(of: "\r", with: "\n")

        while result.contains("  ") {
            result = result.replacingOccurrences(of: "  ", with: " ")
        }

        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        result = result.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")

        return result
    }
}
