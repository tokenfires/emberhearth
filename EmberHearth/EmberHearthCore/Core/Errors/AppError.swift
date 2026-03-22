// AppError.swift
// EmberHearth
//
// User-facing error states with friendly messaging.

import Foundation
import SwiftUI

/// Represents user-facing error states in EmberHearth.
///
/// Each case maps to a specific failure condition and carries all
/// the information needed to display a friendly error to the user:
/// an SF Symbol icon, a plain-language title, a helpful description,
/// and an optional action.
///
/// Design philosophy: No technical jargon. No error codes. No scary words
/// like "corrupt" or "fatal." Just clear, calm, helpful language.
enum AppError: Identifiable, Equatable {
    /// API key has not been configured yet.
    case noAPIKey
    /// API key exists but is invalid or expired.
    case apiKeyInvalid
    /// No internet connection detected.
    case noInternet
    /// LLM provider is overloaded (5xx errors).
    case llmOverloaded
    /// LLM rate limit exceeded (429).
    case llmRateLimited(retryAfterMinutes: Int)
    /// chat.db is not accessible (Full Disk Access not granted).
    case chatDbInaccessible
    /// Messages.app is not responding.
    case messagesAppUnavailable
    /// Memory database integrity check failed.
    case databaseCorrupt
    /// An unexpected error occurred.
    case unknownError(underlyingMessage: String?)

    var id: String {
        switch self {
        case .noAPIKey: return "noAPIKey"
        case .apiKeyInvalid: return "apiKeyInvalid"
        case .noInternet: return "noInternet"
        case .llmOverloaded: return "llmOverloaded"
        case .llmRateLimited: return "llmRateLimited"
        case .chatDbInaccessible: return "chatDbInaccessible"
        case .messagesAppUnavailable: return "messagesAppUnavailable"
        case .databaseCorrupt: return "databaseCorrupt"
        case .unknownError: return "unknownError"
        }
    }

    /// The SF Symbol name appropriate for this error type.
    var iconName: String {
        switch self {
        case .noAPIKey:
            return "key.fill"
        case .apiKeyInvalid:
            return "key.slash"
        case .noInternet:
            return "wifi.slash"
        case .llmOverloaded:
            return "cloud.fill"
        case .llmRateLimited:
            return "clock.fill"
        case .chatDbInaccessible:
            return "lock.shield.fill"
        case .messagesAppUnavailable:
            return "message.fill"
        case .databaseCorrupt:
            return "wrench.and.screwdriver.fill"
        case .unknownError:
            return "exclamationmark.circle.fill"
        }
    }

    /// The icon tint color for this error type.
    var iconColor: Color {
        switch self {
        case .noAPIKey, .chatDbInaccessible:
            return .blue
        case .apiKeyInvalid, .llmOverloaded, .llmRateLimited, .messagesAppUnavailable:
            return .orange
        case .noInternet:
            return .secondary
        case .databaseCorrupt, .unknownError:
            return .red
        }
    }

    /// A short, plain-language title for the error.
    var title: String {
        switch self {
        case .noAPIKey:
            return "API Key Needed"
        case .apiKeyInvalid:
            return "API Key Issue"
        case .noInternet:
            return "No Internet Connection"
        case .llmOverloaded:
            return "Service Busy"
        case .llmRateLimited:
            return "Taking a Short Break"
        case .chatDbInaccessible:
            return "Permission Needed"
        case .messagesAppUnavailable:
            return "Messages Not Responding"
        case .databaseCorrupt:
            return "Recovering Data"
        case .unknownError:
            return "Something Went Wrong"
        }
    }

    /// A helpful, jargon-free description of the error and what the user
    /// can expect. Written as if explaining to a non-technical family member.
    var description: String {
        switch self {
        case .noAPIKey:
            return "Set up your API key in Settings to get started. Ember needs this to think and respond to your messages."
        case .apiKeyInvalid:
            return "Your API key isn't working. It may have expired or been revoked. You can update it in Settings."
        case .noInternet:
            return "No internet connection. Ember will respond when you're back online."
        case .llmOverloaded:
            return "Claude is busy right now. Ember will try again in a moment."
        case .llmRateLimited(let minutes):
            return "You've sent a lot of messages. Ember will be back in \(minutes) minute\(minutes == 1 ? "" : "s")."
        case .chatDbInaccessible:
            return "EmberHearth needs Full Disk Access to read your messages. You can grant this in System Settings."
        case .messagesAppUnavailable:
            return "Messages app isn't responding. Make sure it's open and try again."
        case .databaseCorrupt:
            return "Something went wrong with Ember's memory. Attempting to recover your data now..."
        case .unknownError(let message):
            if let message = message, !message.isEmpty {
                return "Something unexpected happened. Ember is trying to fix it. (\(message))"
            }
            return "Something unexpected happened. Ember is trying to fix it."
        }
    }

    /// The label for the action button, if this error has a user action.
    /// Returns nil if no action is available (e.g., auto-recovery states).
    var actionLabel: String? {
        switch self {
        case .noAPIKey:
            return "Open Settings"
        case .apiKeyInvalid:
            return "Update API Key"
        case .noInternet:
            return nil
        case .llmOverloaded:
            return nil
        case .llmRateLimited:
            return nil
        case .chatDbInaccessible:
            return "Open System Settings"
        case .messagesAppUnavailable:
            return "Retry"
        case .databaseCorrupt:
            return nil
        case .unknownError:
            return "Get Help"
        }
    }

    /// Whether this error is expected to resolve on its own (transient)
    /// or requires user action (persistent).
    var isTransient: Bool {
        switch self {
        case .noInternet, .llmOverloaded, .llmRateLimited, .databaseCorrupt:
            return true
        case .noAPIKey, .apiKeyInvalid, .chatDbInaccessible,
             .messagesAppUnavailable, .unknownError:
            return false
        }
    }

    /// Equatable conformance (ignoring associated values for comparison).
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        return lhs.id == rhs.id
    }
}
