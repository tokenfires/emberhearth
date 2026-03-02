// ClaudeAPIClient.swift
// EmberHearth
//
// HTTP client for the Claude streaming API.

import Foundation
import os

/// Client for interacting with the Claude API over HTTP with SSE streaming.
final class ClaudeAPIClient: Sendable {

    private static let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "ClaudeAPIClient"
    )

    private let apiKey: String
    private let session: URLSession
    private let baseURL: URL

    init(
        apiKey: String,
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.anthropic.com")!
    ) {
        self.apiKey = apiKey
        self.session = session
        self.baseURL = baseURL
    }
}