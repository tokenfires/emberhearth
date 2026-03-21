// AppState.swift
// EmberHearth
//
// Central observable state for the entire application.

import Foundation
import SwiftUI
import os

/// The central observable state object for EmberHearth.
///
/// AppState is the single source of truth for the application's current
/// health, activity, and statistics. It is observed by the menu bar,
/// settings views, and error displays to present consistent status information.
///
/// ## Thread Safety
/// All published properties must be updated on the main actor since
/// they drive UI updates.
///
/// ## Usage
/// ```swift
/// let appState = AppState()
/// // inject via AppDelegate or environment
/// ```
@MainActor
final class AppState: ObservableObject {

    // MARK: - Published Properties

    /// The current operational status of the application.
    @Published var status: AppStatus = .starting

    /// The timestamp of the last message received from the user.
    @Published var lastMessageTime: Date?

    /// Total messages processed in the current session.
    @Published var messageCount: Int = 0

    /// Total facts stored in the memory database.
    @Published var factCount: Int = 0

    /// Whether the onboarding flow has been completed.
    @Published var isOnboardingComplete: Bool

    /// Current active errors (may have multiple simultaneous issues).
    @Published var errors: [AppError] = []

    /// Whether Ember is paused (user manually paused responses).
    @Published var isPaused: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.emberhearth.app", category: "AppState")

    // MARK: - Initialization

    /// Creates a new AppState, checking onboarding completion from UserDefaults.
    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
        logger.info("AppState initialized. Onboarding complete: \(self.isOnboardingComplete)")
    }

    // MARK: - Status Transitions

    /// Transitions the app to a new status, logging the change.
    ///
    /// - Parameter newStatus: The new status to transition to.
    func transition(to newStatus: AppStatus) {
        let oldStatus = status
        status = newStatus
        logger.info("Status transition: \(oldStatus.logDescription) -> \(newStatus.logDescription)")
    }

    /// Records a processed message, updating counts and timestamp.
    func recordMessage() {
        messageCount += 1
        lastMessageTime = Date()
        logger.debug("Message recorded. Count: \(self.messageCount)")
    }

    /// Adds an error to the active errors list.
    ///
    /// If an error with the same ID already exists, it is replaced.
    /// Transient errors set status to `.degraded`; persistent errors set `.error`.
    ///
    /// - Parameter error: The error to add.
    func addError(_ error: AppError) {
        errors.removeAll { $0.id == error.id }
        errors.append(error)
        logger.info("Error added: \(error.id). Active errors: \(self.errors.count)")

        recalculateStatusFromErrors()
    }

    /// Removes an error from the active errors list.
    ///
    /// If no errors remain, transitions back to `.ready`.
    /// If errors remain, recalculates status from the most severe remaining error.
    ///
    /// - Parameter errorId: The ID of the error to remove.
    func removeError(withId errorId: String) {
        errors.removeAll { $0.id == errorId }
        logger.info("Error removed: \(errorId). Active errors: \(self.errors.count)")

        recalculateStatusFromErrors()
    }

    /// Clears all errors and transitions to `.ready`.
    func clearErrors() {
        errors.removeAll()
        transition(to: .ready)
        logger.info("All errors cleared")
    }

    /// Recalculates the current status based on the active errors list.
    ///
    /// Persistent (non-transient) errors take precedence over transient ones.
    /// If no errors remain, transitions to `.ready`.
    private func recalculateStatusFromErrors() {
        guard let worstError = errors.first(where: { !$0.isTransient }) ?? errors.first else {
            transition(to: .ready)
            return
        }

        if !worstError.isTransient {
            transition(to: .error(worstError.title))
        } else {
            transition(to: .degraded(worstError.title))
        }
    }

    /// Updates the fact count from the memory system.
    ///
    /// - Parameter count: The current number of stored facts.
    func updateFactCount(_ count: Int) {
        factCount = count
    }

    /// Toggles the paused state.
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            logger.info("Ember paused by user")
        } else {
            logger.info("Ember resumed by user")
        }
    }

    /// A human-readable string describing the time since the last message.
    var lastMessageDescription: String {
        guard let lastTime = lastMessageTime else {
            return "No messages yet"
        }

        let interval = Date().timeIntervalSince(lastTime)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

// MARK: - AppStatus Enum

/// The operational status of the EmberHearth application.
///
/// Maps to the health state machine from the autonomous operation spec:
/// - `.starting` → Initial boot
/// - `.ready` → HEALTHY (connected, waiting for messages)
/// - `.processing` → HEALTHY (actively handling a message)
/// - `.degraded` → DEGRADED (working with issues)
/// - `.error` → IMPAIRED (not working)
/// - `.offline` → Special case of DEGRADED (no internet)
enum AppStatus: Equatable {
    /// App is starting up, running health checks.
    case starting
    /// Fully operational, waiting for messages.
    case ready
    /// Currently processing a message.
    case processing
    /// Working but with non-critical issues.
    case degraded(String)
    /// Not working due to a critical error.
    case error(String)
    /// No internet connection.
    case offline

    /// A short human-readable description for logging.
    var logDescription: String {
        switch self {
        case .starting: return "starting"
        case .ready: return "ready"
        case .processing: return "processing"
        case .degraded(let reason): return "degraded(\(reason))"
        case .error(let reason): return "error(\(reason))"
        case .offline: return "offline"
        }
    }

    /// The SF Symbol name for the menu bar icon in this status.
    var menuBarIcon: String {
        switch self {
        case .starting: return "flame.fill"
        case .ready: return "flame.fill"
        case .processing: return "flame.fill"
        case .degraded: return "flame.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .offline: return "flame.fill"
        }
    }

    /// A short status line for the menu bar dropdown.
    var statusLine: String {
        switch self {
        case .starting: return "Starting up..."
        case .ready: return "Ready"
        case .processing: return "Thinking..."
        case .degraded(let reason): return "Limited: \(reason)"
        case .error(let reason): return "Issue: \(reason)"
        case .offline: return "Offline"
        }
    }

    /// Equatable conformance for associated-value cases.
    static func == (lhs: AppStatus, rhs: AppStatus) -> Bool {
        switch (lhs, rhs) {
        case (.starting, .starting), (.ready, .ready),
             (.processing, .processing), (.offline, .offline):
            return true
        case (.degraded(let a), .degraded(let b)):
            return a == b
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}
