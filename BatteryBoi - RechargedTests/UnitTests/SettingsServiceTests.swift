//
//  SettingsServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for settings service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class SettingsServiceTests: XCTestCase {

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

    // MARK: - Display Toggle Tests

    @MainActor
    func testToggleDisplayCycles() {
        // Given countdown display
        mockSettingsService.display = .countdown

        // When toggling display
        var result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .percent)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .empty)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .cycle)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .hidden)

        result = mockSettingsService.toggleDisplay()
        XCTAssertEqual(result, .countdown)
    }

    // MARK: - Style Tests

    @MainActor
    func testBatteryStyleChange() {
        // Given chunky style
        mockSettingsService.style = .chunky

        // When changing to basic
        mockSettingsService.style = .basic

        // Then style should update
        XCTAssertEqual(mockSettingsService.style, .basic)
    }

}
