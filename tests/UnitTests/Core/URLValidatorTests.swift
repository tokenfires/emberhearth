// URLValidatorTests.swift
// EmberHearth
//
// Unit tests for URLValidator.

import XCTest
@testable import EmberHearthCore

final class URLValidatorTests: XCTestCase {

    // MARK: - Valid URL Tests

    func test_validHTTPSURL_passesValidation() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/page"))
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_validHTTPURL_passesValidation() throws {
        let url = try XCTUnwrap(URL(string: "http://example.com"))
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_httpsWithPath_passesValidation() throws {
        let url = try XCTUnwrap(URL(string: "https://news.example.com/article/12345"))
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    // MARK: - Scheme Tests

    func test_fileScheme_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "file:///etc/passwd"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            if case WebFetcherError.invalidURL(let reason) = error {
                XCTAssertTrue(reason.contains("HTTPS"), "Error should mention HTTPS")
            } else {
                XCTFail("Expected WebFetcherError.invalidURL, got \(error)")
            }
        }
    }

    func test_ftpScheme_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "ftp://example.com/file.txt"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_dataScheme_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "data:text/html,<h1>test</h1>"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    // MARK: - Localhost Tests

    func test_localhostByName_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://localhost/api"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: [])) { error in
            if case WebFetcherError.invalidURL(let reason) = error {
                XCTAssertTrue(reason.lowercased().contains("localhost"))
            } else {
                XCTFail("Expected invalidURL error")
            }
        }
    }

    func test_localhostByLoopbackIP_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://127.0.0.1/api"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_localhostByIPv6_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://[::1]/api"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    // MARK: - Private IP Range Tests

    func test_privateNetwork10x_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://10.0.0.1/internal"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_privateNetwork192168_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://192.168.1.1/router"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_privateNetwork17216_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://172.16.0.1/internal"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_privateNetwork17231_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://172.31.255.255/internal"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_linkLocalAddress_throwsInvalidURL() throws {
        let url = try XCTUnwrap(URL(string: "http://169.254.1.1/metadata"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_publicIPOutsidePrivateRange_passesValidation() throws {
        // 172.32.x is just outside the private 172.16-31 range
        let url = try XCTUnwrap(URL(string: "http://172.32.0.1/page"))
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    // MARK: - Blocked Domain Tests

    func test_exactMatchBlockedDomain_throwsBlockedDomain() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/page"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: ["example.com"])) { error in
            if case WebFetcherError.blockedDomain(let domain) = error {
                XCTAssertEqual(domain, "example.com")
            } else {
                XCTFail("Expected blockedDomain error, got \(error)")
            }
        }
    }

    func test_subdomainOfBlockedDomain_throwsBlockedDomain() throws {
        let url = try XCTUnwrap(URL(string: "https://sub.example.com/page"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: ["example.com"])) { error in
            if case WebFetcherError.blockedDomain = error {
                // Expected
            } else {
                XCTFail("Expected blockedDomain error")
            }
        }
    }

    func test_differentDomainNotBlocked_passesValidation() throws {
        let url = try XCTUnwrap(URL(string: "https://other.com/page"))
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: ["example.com"]))
    }

    func test_emptyBlockedDomains_passesValidation() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/page"))
        XCTAssertNoThrow(try URLValidator.validate(url, blockedDomains: []))
    }

    func test_multipleBlockedDomains_correctDomainBlocked() throws {
        let url = try XCTUnwrap(URL(string: "https://blocked2.com/page"))
        XCTAssertThrowsError(try URLValidator.validate(url, blockedDomains: ["blocked1.com", "blocked2.com"]))
    }

    // MARK: - URL Detection Tests

    func test_detectURLsFindsHTTPSURL() {
        let text = "Check out https://example.com for more info."
        let urls = URLValidator.detectURLs(in: text)
        XCTAssertEqual(urls.count, 1, "Should find exactly one URL")
        XCTAssertEqual(urls.first?.host, "example.com")
    }

    func test_detectURLsFindsHTTPURL() {
        let text = "Visit http://example.com today."
        let urls = URLValidator.detectURLs(in: text)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.scheme, "http")
    }

    func test_detectURLsFindsMultipleURLs() {
        let text = "See https://example.com and also https://other.com/path"
        let urls = URLValidator.detectURLs(in: text)
        XCTAssertEqual(urls.count, 2, "Should detect both URLs")
    }

    func test_detectURLsIgnoresNonHTTPSchemes() {
        let text = "File at file:///Users/test/doc.txt or ftp://example.com"
        let urls = URLValidator.detectURLs(in: text)
        XCTAssertTrue(urls.isEmpty, "Should not detect non-HTTP/HTTPS URLs")
    }

    func test_detectURLsOnTextWithNoURLs_returnsEmpty() {
        let urls = URLValidator.detectURLs(in: "No URLs here at all")
        XCTAssertTrue(urls.isEmpty)
    }

    func test_detectURLsOnEmptyString_returnsEmpty() {
        let urls = URLValidator.detectURLs(in: "")
        XCTAssertTrue(urls.isEmpty)
    }

    func test_detectURLsExtractsURLWithPath() {
        let text = "Article at https://news.example.com/article/12345?ref=home"
        let urls = URLValidator.detectURLs(in: text)
        XCTAssertEqual(urls.count, 1)
        XCTAssertEqual(urls.first?.host, "news.example.com")
    }
}
