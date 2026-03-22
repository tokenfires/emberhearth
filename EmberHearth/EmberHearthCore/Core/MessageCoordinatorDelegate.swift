// MessageCoordinatorDelegate.swift
// EmberHearth
//
// Protocol for receiving MessageCoordinator status updates.

import Foundation

/// Protocol for receiving status updates from the MessageCoordinator.
///
/// Implement this protocol to react to coordinator lifecycle events,
/// such as when message processing starts, succeeds, or fails.
protocol MessageCoordinatorDelegate: AnyObject {
    /// Called when the coordinator starts processing a new message.
    ///
    /// - Parameter phoneNumber: The sender's phone number (E.164 format).
    func coordinatorDidStartProcessing(from phoneNumber: String)

    /// Called when the coordinator finishes processing a message successfully.
    ///
    /// - Parameter phoneNumber: The sender's phone number.
    func coordinatorDidFinishProcessing(from phoneNumber: String)

    /// Called when the coordinator encounters an error processing a message.
    ///
    /// - Parameters:
    ///   - error: The error that occurred.
    ///   - phoneNumber: The sender's phone number.
    func coordinatorDidEncounterError(_ error: Error, from phoneNumber: String)

    /// Called when the coordinator's overall readiness state changes.
    ///
    /// - Parameter isReady: True if the coordinator is ready to process messages.
    func coordinatorReadinessChanged(isReady: Bool)
}
