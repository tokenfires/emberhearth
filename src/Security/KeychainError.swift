// KeychainError.swift
// EmberHearth
//
// Domain-specific error types for Keychain operations.

import Foundation

/// Errors that can occur during Keychain operations.
enum KeychainError: Error, LocalizedError {

    /// The requested item was not found in the Keychain.
    case itemNotFound

    /// The Keychain returned a duplicate item error.
    case duplicateItem

    /// The data could not be encoded or decoded.
    case encodingError(String)

    /// An underlying Keychain error with an OS status code.
    case keychainError(status: OSStatus)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "The requested item was not found in the Keychain."
        case .duplicateItem:
            return "A duplicate item already exists in the Keychain."
        case .encodingError(let message):
            return "Encoding error: \(message)"
        case .keychainError(let status):
            return "Keychain error with status: \(status)"
        }
    }
}