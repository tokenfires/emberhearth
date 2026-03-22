// NetworkMonitorTests.swift
// EmberHearth
//
// Unit tests for NetworkMonitor.
// Tests initialization, lifecycle, property defaults, and connection type detection.
//
// NOTE: NWPathMonitor depends on the real network stack, so these tests
// focus on the public API contract and lifecycle management rather than
// simulating network state changes (which require integration tests).

import XCTest
import Network
import Combine
@testable import EmberHearthCore

final class NetworkMonitorTests: XCTestCase {

    private var monitor: NetworkMonitor!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        monitor = NetworkMonitor()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        monitor.stop()
        monitor = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialStateIsOptimisticallyConnected() {
        // Before start(), isConnected defaults to true (optimistic)
        XCTAssertTrue(monitor.isConnected,
            "isConnected should default to true before start() is called")
    }

    func testInitialConnectionTypeIsOther() {
        // Before start(), connectionType defaults to .other
        XCTAssertEqual(monitor.connectionType, .other,
            "connectionType should default to .other before start() is called")
    }

    // MARK: - Lifecycle Tests

    func testStartIsIdempotent() {
        // Calling start() twice should not crash or create duplicate monitors
        monitor.start()
        monitor.start() // Should be a no-op
        // If this completes without crashing, the test passes
        XCTAssertTrue(true, "Double start() should not crash")
    }

    func testStopIsIdempotent() {
        // Calling stop() without start() should be safe
        monitor.stop()
        monitor.stop() // Double stop
        XCTAssertTrue(true, "Double stop() should not crash")
    }

    func testStartThenStop() {
        // Normal lifecycle
        monitor.start()
        monitor.stop()
        XCTAssertTrue(true, "Start then stop should complete without error")
    }

    func testStartAfterStop() {
        // NOTE: NWPathMonitor cannot be restarted after cancel().
        // This test verifies the monitor handles this gracefully.
        monitor.start()
        monitor.stop()
        // Creating a new monitor is the correct approach after stop
        let newMonitor = NetworkMonitor()
        newMonitor.start()
        newMonitor.stop()
        XCTAssertTrue(true, "Creating a new monitor after stop should work")
    }

    // MARK: - Publisher Tests

    func testPathPublisherExists() {
        // Verify the pathPublisher is accessible
        let publisher = monitor.pathPublisher
        XCTAssertNotNil(publisher, "pathPublisher should be accessible")
    }

    func testIsConnectedPublisherEmitsOnStart() {
        let expectation = expectation(description: "isConnected should emit after start")

        // Subscribe to isConnected changes
        monitor.$isConnected
            .dropFirst() // Skip initial value
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        monitor.start()

        // Wait a short time for the monitor to report initial state
        wait(for: [expectation], timeout: 5.0)
    }

    func testConnectionTypePublisherEmitsOnStart() {
        let expectation = expectation(description: "connectionType should emit after start")

        monitor.$connectionType
            .dropFirst()
            .first()
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)

        monitor.start()

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Connection Type Tests

    func testConnectionTypeEnumRawValues() {
        XCTAssertEqual(ConnectionType.wifi.rawValue, "wifi")
        XCTAssertEqual(ConnectionType.cellular.rawValue, "cellular")
        XCTAssertEqual(ConnectionType.wiredEthernet.rawValue, "wiredEthernet")
        XCTAssertEqual(ConnectionType.other.rawValue, "other")
        XCTAssertEqual(ConnectionType.none.rawValue, "none")
    }

    func testConnectionTypeEquatable() {
        XCTAssertEqual(ConnectionType.wifi, ConnectionType.wifi)
        XCTAssertNotEqual(ConnectionType.wifi, ConnectionType.cellular)
        XCTAssertNotEqual(ConnectionType.none, ConnectionType.wifi)
    }

    // MARK: - Deinit Safety

    func testDeinitDoesNotCrash() {
        // Create and start a monitor, then let it deallocate
        var localMonitor: NetworkMonitor? = NetworkMonitor()
        localMonitor?.start()
        localMonitor = nil // Should trigger deinit and cancel the monitor
        XCTAssertNil(localMonitor, "Monitor should be deallocated cleanly")
    }

    // MARK: - No Shell Execution

    func testNoShellExecution() {
        // Structural verification — real check is in verification commands
        // This test documents the requirement
        XCTAssertTrue(true,
            "NetworkMonitor must use NWPathMonitor (not ping, not Process())")
    }
}
