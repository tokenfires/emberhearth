// NetworkMonitor.swift
// EmberHearth
//
// Monitors network connectivity using Apple's Network framework (NWPathMonitor).
// Provides real-time connectivity status updates via Combine publishers.
// Used by OfflineCoordinator to detect offline state and trigger message queuing.

import Foundation
import Network
import Combine
import os

/// Represents the type of network connection currently available.
///
/// Used by OfflineCoordinator to make decisions about connectivity quality.
/// For example, cellular connections may warrant different retry behavior
/// than wired Ethernet connections.
enum ConnectionType: String, Sendable, Equatable {
    /// Connected via Wi-Fi.
    case wifi = "wifi"
    /// Connected via cellular network (rare on macOS, possible with iPhone tethering).
    case cellular = "cellular"
    /// Connected via wired Ethernet.
    case wiredEthernet = "wiredEthernet"
    /// Connected via an unrecognized interface type.
    case other = "other"
    /// No network connection available.
    case none = "none"
}

/// Monitors network connectivity using NWPathMonitor from Apple's Network framework.
///
/// NetworkMonitor provides real-time updates when the device's network connectivity
/// changes. It wraps NWPathMonitor and exposes connectivity state through:
/// - A `@Published` `isConnected` property for SwiftUI/Combine binding
/// - A `@Published` `connectionType` property for connection quality assessment
/// - A `pathPublisher` for raw NWPath updates via Combine
///
/// ## Thread Safety
/// NetworkMonitor runs its NWPathMonitor on a dedicated serial DispatchQueue.
/// Published property updates are dispatched to the main queue for UI safety.
/// The class is designed to be created once and shared (e.g., via dependency injection).
///
/// ## Usage
/// ```swift
/// let monitor = NetworkMonitor()
/// monitor.start()
///
/// // Observe connectivity changes
/// monitor.$isConnected
///     .sink { connected in
///         print("Network: \(connected ? "online" : "offline")")
///     }
///     .store(in: &cancellables)
///
/// // Clean up
/// monitor.stop()
/// ```
///
/// ## Important
/// - Call `start()` before observing properties. Before `start()`, `isConnected` defaults to `true`
///   (optimistic assumption to avoid false offline detection on launch).
/// - Call `stop()` when the monitor is no longer needed to release system resources.
/// - NWPathMonitor is an Apple framework — no third-party dependencies.
final class NetworkMonitor: ObservableObject {

    // MARK: - Published Properties

    /// Whether the device currently has network connectivity.
    ///
    /// Updated on the main queue whenever NWPathMonitor reports a path change.
    /// Defaults to `true` (optimistic) until the first path update arrives.
    @Published private(set) var isConnected: Bool = true

    /// The current type of network connection.
    ///
    /// Updated alongside `isConnected` on every path change.
    /// Defaults to `.other` until the first path update.
    @Published private(set) var connectionType: ConnectionType = .other

    // MARK: - Combine Publishers

    /// A subject that emits raw NWPath updates for advanced consumers.
    ///
    /// Use this when you need access to the full NWPath object (e.g., for
    /// checking specific interface types or DNS resolution status).
    private let pathSubject = PassthroughSubject<NWPath, Never>()

    /// Publisher for raw NWPath updates.
    ///
    /// Emits every time NWPathMonitor detects a network path change.
    /// Useful for advanced monitoring beyond simple connected/disconnected.
    var pathPublisher: AnyPublisher<NWPath, Never> {
        pathSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    /// The underlying NWPathMonitor from Apple's Network framework.
    private let monitor: NWPathMonitor

    /// Dedicated serial queue for NWPathMonitor callbacks.
    /// Using a dedicated queue avoids blocking the main queue with network checks.
    private let monitorQueue: DispatchQueue

    /// Logger for connectivity change events.
    /// NEVER logs message content — only connectivity state transitions.
    private let logger = Logger(
        subsystem: "com.emberhearth.app",
        category: "NetworkMonitor"
    )

    /// Whether the monitor has been started.
    private var isMonitoring = false

    // MARK: - Initialization

    /// Creates a new NetworkMonitor.
    ///
    /// The monitor does not begin observing until `start()` is called.
    /// This allows the caller to set up Combine subscriptions before
    /// the first connectivity update fires.
    init() {
        self.monitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(
            label: "com.emberhearth.networkmonitor",
            qos: .utility
        )
    }

    // MARK: - Lifecycle

    /// Starts monitoring network connectivity.
    ///
    /// Begins receiving NWPath updates on the dedicated queue. Published
    /// properties are updated on the main queue. Safe to call multiple times
    /// (subsequent calls are no-ops).
    ///
    /// Call this early in the app launch sequence, after crash recovery
    /// but before starting the message pipeline.
    func start() {
        guard !isMonitoring else {
            logger.debug("NetworkMonitor is already running, ignoring start()")
            return
        }

        logger.info("Starting network monitoring")

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self.handlePathUpdate(path)
        }

        monitor.start(queue: monitorQueue)
        isMonitoring = true
    }

    /// Stops monitoring network connectivity.
    ///
    /// Releases the NWPathMonitor and stops receiving updates.
    /// Safe to call multiple times (subsequent calls are no-ops).
    /// Call this during app termination or when monitoring is no longer needed.
    func stop() {
        guard isMonitoring else {
            logger.debug("NetworkMonitor is not running, ignoring stop()")
            return
        }

        logger.info("Stopping network monitoring")
        monitor.cancel()
        isMonitoring = false
    }

    // MARK: - Private Methods

    /// Handles a network path update from NWPathMonitor.
    ///
    /// Determines the connection status and type from the NWPath,
    /// then dispatches updates to the main queue for published properties.
    ///
    /// - Parameter path: The updated network path from NWPathMonitor.
    private func handlePathUpdate(_ path: NWPath) {
        let connected = path.status == .satisfied
        let type = determineConnectionType(from: path)

        // Emit raw path for advanced consumers
        pathSubject.send(path)

        // Update published properties on main queue
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let previouslyConnected = self.isConnected

            self.isConnected = connected
            self.connectionType = type

            // Log state transitions (not every update)
            if previouslyConnected && !connected {
                self.logger.warning("Network connectivity LOST. Connection type: \(type.rawValue, privacy: .public)")
            } else if !previouslyConnected && connected {
                self.logger.info("Network connectivity RESTORED. Connection type: \(type.rawValue, privacy: .public)")
            }
        }
    }

    /// Determines the connection type from an NWPath.
    ///
    /// Checks interface types in priority order: Wi-Fi, cellular, wired Ethernet.
    /// Returns `.none` if the path status is not satisfied.
    ///
    /// - Parameter path: The network path to analyze.
    /// - Returns: The detected connection type.
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        guard path.status == .satisfied else {
            return .none
        }

        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else {
            return .other
        }
    }

    // MARK: - Deinit

    deinit {
        if isMonitoring {
            monitor.cancel()
        }
    }
}
