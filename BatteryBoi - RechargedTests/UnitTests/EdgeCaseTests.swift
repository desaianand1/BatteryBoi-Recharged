//
//  EdgeCaseTests.swift
//  BatteryBoi-RechargedTests
//
//  Edge case tests for various scenarios.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class EdgeCaseTests: XCTestCase {

    // MARK: - Properties

    /// Mock services (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockBatteryService: MockBatteryService!
    nonisolated(unsafe) var mockWindowService: MockWindowService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let (battery, window) = MainActor.assumeIsolated {
            (MockBatteryService(), MockWindowService())
        }
        mockBatteryService = battery
        mockWindowService = window
    }

    override nonisolated func tearDown() {
        mockBatteryService = nil
        mockWindowService = nil
        super.tearDown()
    }

    // MARK: - Window State Rapid Change Tests

    @MainActor
    func testRapidWindowStateChanges() {
        // Given a hidden window
        mockWindowService.state = .hidden

        // When rapidly changing states
        mockWindowService.open(.userInitiated, device: nil) // -> revealed
        mockWindowService.setState(.detailed, animated: true) // -> detailed
        mockWindowService.setState(.dismissed, animated: true) // -> dismissed
        mockWindowService.setState(.hidden, animated: false) // -> hidden

        // Then the final state should be hidden
        XCTAssertEqual(mockWindowService.state, .hidden)
        XCTAssertEqual(mockWindowService.setStateCallCount, 3)
    }

    @MainActor
    func testWindowOpenWhileVisible() {
        // Given a visible window
        mockWindowService.state = .revealed

        // When opening another alert
        mockWindowService.open(.chargingBegan, device: nil)

        // Then the window should remain revealed with new alert type
        XCTAssertEqual(mockWindowService.state, .revealed)
        XCTAssertEqual(mockWindowService.lastOpenType, .chargingBegan)
    }

    // MARK: - Multi-Monitor Tests

    @MainActor
    func testFrameCalculationConsistency() {
        // When calculating frame multiple times
        let frame1 = mockWindowService.calculateFrame(moved: nil)
        let frame2 = mockWindowService.calculateFrame(moved: nil)

        // Then frames should be consistent
        XCTAssertEqual(frame1.width, frame2.width)
        XCTAssertEqual(frame1.height, frame2.height)
    }

    // MARK: - Rapid Event Debounce Tests

    @MainActor
    func testRapidMouseEventsDebounced() {
        // Given window in revealed state
        mockWindowService.setState(.revealed, animated: false)

        // When rapid state changes occur
        for _ in 0 ..< 10 {
            mockWindowService.simulateStateChange(.revealed)
        }

        // Then should not crash, state should be deterministic
        XCTAssertEqual(mockWindowService.state, .revealed)
    }

    @MainActor
    func testWindowStateConsistentAfterRapidChanges() {
        // Given initial hidden state
        mockWindowService.state = .hidden

        // When rapid open/close cycles occur
        for _ in 0 ..< 5 {
            mockWindowService.open(.userInitiated, device: nil)
            mockWindowService.setState(.dismissed, animated: false)
        }

        // Then final state should match last operation
        XCTAssertEqual(mockWindowService.state, .dismissed)
        XCTAssertEqual(mockWindowService.openCallCount, 5)
    }

}
