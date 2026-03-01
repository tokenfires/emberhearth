// KeychainError.swift
// EmberHearth
//
// Domain-specific error types for Keychain operations.

import Foundation

/// Errors that can occur during Keychain operations.
public enum KeychainError: Error, Equatable {
    /// The API key format is invalid (empty, whitespace-only, too short, or wrong prefix).
    case invalidKeyFormat(reason: String)

    /// The requested Keychain item was not found.
    case itemNotFound

    /// An unexpected Keychain error occurred, wrapping the OSStatus code.
    case unexpectedStatus(OSStatus)

    /// The data retrieved from the Keychain could not be decoded as a UTF-8 string.
    case dataCorrupted

    public static func == (lhs: KeychainError, rhs: KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidKeyFormat(let l), .invalidKeyFormat(let r)):
            return l == r
        case (.itemNotFound, .itemNotFound):
            return true
        case (.unexpectedStatus(let l), .unexpectedStatus(let r)):
            return l == r
        case (.dataCorrupted, .dataCorrupted):
            return true
        default:
            return false
        }
    }
}

extension KeychainError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidKeyFormat(let reason):
            return "Invalid API key format: \(reason)"
        case .itemNotFound:
            return "The requested Keychain item was not found."
        case .unexpectedStatus(let status):
            return "An unexpected Keychain error occurred (OSStatus: \(status))."
        case .dataCorrupted:
            return "The Keychain data is corrupted or unreadable."
        }
    }
}