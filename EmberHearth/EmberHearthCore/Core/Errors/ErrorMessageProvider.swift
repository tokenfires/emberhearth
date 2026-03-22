// ErrorMessageProvider.swift
// EmberHearth
//
// Provides user-friendly iMessage responses when Ember cannot process a message.

import Foundation

/// Provides friendly iMessage text responses for when Ember encounters
/// an error while trying to respond to a user message.
///
/// When the MessageCoordinator detects an error, it uses this provider
/// to generate an appropriate iMessage to send back to the user, so
/// they know Ember is aware of the problem and working on it.
///
/// The messages are written in Ember's voice: warm, brief, honest,
/// no technical jargon.
struct ErrorMessageProvider {

    /// Returns an appropriate iMessage response for the given error.
    ///
    /// - Parameter error: The error that prevented Ember from responding normally.
    /// - Returns: A short, friendly iMessage string in Ember's voice,
    ///   or nil if sending an iMessage is impossible or inappropriate for this error.
    static func iMessageResponse(for error: AppError) -> String? {
        switch error {
        case .noAPIKey, .apiKeyInvalid, .chatDbInaccessible:
            // Configuration errors require action in the Mac app.
            // Sending an iMessage about these would confuse the user
            // since they can't fix them from their phone.
            return nil

        case .noInternet:
            return "Hey, I'm having trouble connecting right now. I'll get back to you when I can!"

        case .llmOverloaded:
            return "Give me a moment — the service I use to think is a bit busy right now. I'll respond soon!"

        case .llmRateLimited(let minutes):
            if minutes <= 1 {
                return "I need to take a short break. I'll be back in about a minute!"
            }
            return "I need to take a short break. I'll be back in about \(minutes) minutes!"

        case .messagesAppUnavailable:
            // Can't send a message if Messages itself is unavailable.
            return nil

        case .databaseCorrupt:
            return "Something went sideways on my end. Give me a moment to sort it out."

        case .unknownError:
            return "Something went sideways on my end. Give me a moment to sort it out."
        }
    }
}
