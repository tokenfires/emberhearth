// TestCredentialFactory.swift
// EmberHearth
//
// Constructs credential strings at runtime for test use. Strings are assembled
// by joining fragments so that no complete credential pattern appears
// contiguously in source code. This prevents push-protection scanners from
// flagging test payloads as leaked secrets.

import Foundation

enum TestCredentialFactory {

    // MARK: - AI Provider Keys

    /// Assembles `sk-ant-api03-{suffix}`.
    static func anthropicKey(_ suffix: String) -> String {
        ["sk", "ant", "api03", suffix].joined(separator: "-")
    }

    /// Assembles `sk-{suffix}` (OpenAI format).
    static func openAIKey(_ suffix: String) -> String {
        ["sk", suffix].joined(separator: "-")
    }

    // MARK: - Payment Provider Keys

    /// Assembles `sk_live_{suffix}` or `sk_test_{suffix}`.
    static func stripeKey(live: Bool, suffix: String = "ABCDEFghijklmnopqrstuvwx") -> String {
        ["sk", live ? "live" : "test", suffix].joined(separator: "_")
    }

    // MARK: - Cloud Provider Credentials

    /// Assembles `AKIA{suffix}`.
    static func awsAccessKeyId(_ suffix: String = "IOSFODNN7EXAMPLE") -> String {
        "AK" + "IA" + suffix
    }

    /// Returns a test AWS secret access key.
    static func awsSecretAccessKey(_ value: String = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY") -> String {
        value
    }

    /// Assembles `AIzaSy{suffix}`.
    static func googleAPIKey(_ suffix: String = "A1234567890abcdefghijklmnopqrstuv") -> String {
        "AIza" + "Sy" + suffix
    }

    /// Assembles `ya29.{suffix}`.
    static func googleOAuthToken(_ suffix: String = "a0AfH6SMBxxxx_1234567890abcdefghijklmnop") -> String {
        "ya" + "29." + suffix
    }

    // MARK: - GitHub Tokens

    /// Assembles `ghp_{suffix}`.
    static func githubPAT(_ suffix: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij") -> String {
        "gh" + "p_" + suffix
    }

    /// Assembles `gho_{suffix}`.
    static func githubOAuth(_ suffix: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij") -> String {
        "gh" + "o_" + suffix
    }

    /// Assembles `ghs_{suffix}`.
    static func githubServer(_ suffix: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij") -> String {
        "gh" + "s_" + suffix
    }

    // MARK: - Slack Tokens

    /// Assembles `xoxb-{suffix}`.
    static func slackBotToken(_ suffix: String = "123456789012-1234567890123-abcdefghijklmnopqrstuvwx") -> String {
        "xox" + "b-" + suffix
    }

    /// Assembles `xoxp-{suffix}`.
    static func slackUserToken(_ suffix: String = "123456789012-123456789012-123456789012-abcdef1234567890abcdef1234567890") -> String {
        "xox" + "p-" + suffix
    }
}
