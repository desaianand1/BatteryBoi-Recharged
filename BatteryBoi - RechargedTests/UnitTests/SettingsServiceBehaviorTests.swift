//
//  SettingsServiceBehaviorTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for settings service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class SettingsServiceBehaviorTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockSettingsService: MockSettingsService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockSettingsService()
        }
        mockSettingsService = service
    }

    override nonisolated func tearDown() {
        mockSettingsService = nil
        super.tearDown()
    }

    // MARK: - Display Mode Tests

    @MainActor
    func testToggleDisplayFromCountdown() {
        // Given countdown display mode
        mockSettingsService.display = .countdown

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to percent
        XCTAssertEqual(newDisplay, .percent)
    }

    @MainActor
    func testToggleDisplayFromPercent() {
        // Given percent display mode
        mockSettingsService.display = .percent

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to empty
        XCTAssertEqual(newDisplay, .empty)
    }

    @MainActor
    func testToggleDisplayFromEmpty() {
        // Given empty display mode
        mockSettingsService.display = .empty

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to cycle
        XCTAssertEqual(newDisplay, .cycle)
    }

    @MainActor
    func testToggleDisplayFromCycle() {
        // Given cycle display mode
        mockSettingsService.display = .cycle

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should change to hidden
        XCTAssertEqual(newDisplay, .hidden)
    }

    @MainActor
    func testToggleDisplayFromHidden() {
        // Given hidden display mode
        mockSettingsService.display = .hidden

        // When toggling display
        let newDisplay = mockSettingsService.toggleDisplay()

        // Then it should wrap back to countdown
        XCTAssertEqual(newDisplay, .countdown)
    }

    @MainActor
    func testDisplayCycleComplete() {
        // Given countdown display mode
        mockSettingsService.display = .countdown

        // When toggling through all modes
        mockSettingsService.toggleDisplay() // -> percent
        mockSettingsService.toggleDisplay() // -> empty
        mockSettingsService.toggleDisplay() // -> cycle
        mockSettingsService.toggleDisplay() // -> hidden
        let finalDisplay = mockSettingsService.toggleDisplay() // -> countdown

        // Then it should be back to countdown
        XCTAssertEqual(finalDisplay, .countdown)
    }

    // MARK: - Pinned Setting Tests

    @MainActor
    func testPinnedSimulation() {
        // Given pinned disabled
        mockSettingsService.pinned = .disabled

        // When simulating pinned change
        mockSettingsService.simulatePinnedChange(.enabled)

        // Then pinned should be enabled
        XCTAssertEqual(mockSettingsService.pinned, .enabled)
    }

    // MARK: - Action Perform Tests

    @MainActor
    func testPerformAction() {
        // Given a settings action
        let action = SettingsActionObject(.appQuit)

        // When performing the action
        mockSettingsService.performAction(action)

        // Then the action should be tracked
        XCTAssertEqual(mockSettingsService.lastPerformedAction?.type, .appQuit)
    }
}
