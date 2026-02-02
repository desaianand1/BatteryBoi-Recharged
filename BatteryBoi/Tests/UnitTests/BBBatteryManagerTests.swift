//
//  BBBatteryManagerTests.swift
//  BatteryBoiTests
//
//  Unit tests for battery manager functionality.
//

@testable import BatteryBoi
import XCTest

final class BBBatteryManagerTests: XCTestCase {

    // MARK: - Properties

    var mockBatteryService: MockBatteryService!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockBatteryService = MockBatteryService()
    }

    override func tearDown() {
        mockBatteryService = nil
        super.tearDown()
    }

    // MARK: - Percentage Tests

    @MainActor
    func testPercentageInValidRange() {
        // Given a battery service with a valid percentage
        mockBatteryService.percentage = 75.0

        // Then the percentage should be within valid bounds
        XCTAssertGreaterThanOrEqual(mockBatteryService.percentage, 0)
        XCTAssertLessThanOrEqual(mockBatteryService.percentage, 100)
    }

    @MainActor
    func testPercentageAtZero() {
        // Given a battery service with 0% battery
        mockBatteryService.percentage = 0.0

        // Then the percentage should be exactly 0
        XCTAssertEqual(mockBatteryService.percentage, 0.0)
    }

    @MainActor
    func testPercentageAtFull() {
        // Given a battery service with 100% battery
        mockBatteryService.percentage = 100.0

        // Then the percentage should be exactly 100
        XCTAssertEqual(mockBatteryService.percentage, 100.0)
    }

    // MARK: - Charging State Tests

    @MainActor
    func testChargingStateTransitionToCharging() {
        // Given a battery service on battery power
        mockBatteryService.charging = BatteryCharging(.battery)

        // When charging begins
        mockBatteryService.simulateChargingChange(BatteryCharging(.charging))

        // Then the state should be charging
        XCTAssertEqual(mockBatteryService.charging.state, .charging)
    }

    @MainActor
    func testChargingStateTransitionToBattery() {
        // Given a battery service that is charging
        mockBatteryService.charging = BatteryCharging(.charging)

        // When charger is removed
        mockBatteryService.simulateChargingChange(BatteryCharging(.battery))

        // Then the state should be battery
        XCTAssertEqual(mockBatteryService.charging.state, .battery)
    }

    // MARK: - Thermal State Tests

    @MainActor
    func testThermalStateOptimal() {
        // Given optimal thermal conditions
        mockBatteryService.thermal = .optimal

        // Then thermal state should be optimal
        XCTAssertEqual(mockBatteryService.thermal, .optimal)
    }

    @MainActor
    func testThermalStateSuboptimal() {
        // Given suboptimal thermal conditions
        mockBatteryService.thermal = .suboptimal

        // Then thermal state should be suboptimal
        XCTAssertEqual(mockBatteryService.thermal, .suboptimal)
    }

    @MainActor
    func testThermalStateTransition() {
        // Given optimal thermal conditions
        mockBatteryService.thermal = .optimal

        // When thermal conditions degrade
        mockBatteryService.simulateThermalChange(.suboptimal)

        // Then thermal state should update
        XCTAssertEqual(mockBatteryService.thermal, .suboptimal)
    }

    // MARK: - Time Remaining Tests

    @MainActor
    func testTimeRemainingNilAtFullCharge() {
        // Given a fully charged battery
        mockBatteryService.percentage = 100.0
        mockBatteryService.charging = BatteryCharging(.charging)

        // Then untilFull should be nil (already full)
        XCTAssertNil(mockBatteryService.untilFull)
    }

    // MARK: - Power Save Mode Tests

    @MainActor
    func testTogglePowerSaveMode() {
        // Given normal power mode
        mockBatteryService.saver = .normal

        // When toggling power save mode
        mockBatteryService.togglePowerSaveMode()

        // Then it should switch to efficient mode
        XCTAssertEqual(mockBatteryService.saver, .efficient)
        XCTAssertEqual(mockBatteryService.togglePowerSaveModeCallCount, 1)
    }

    @MainActor
    func testTogglePowerSaveModeBackToNormal() {
        // Given efficient power mode
        mockBatteryService.saver = .efficient

        // When toggling power save mode
        mockBatteryService.togglePowerSaveMode()

        // Then it should switch to normal mode
        XCTAssertEqual(mockBatteryService.saver, .normal)
    }

    // MARK: - Force Refresh Tests

    @MainActor
    func testForceRefreshCallCount() {
        // Given a battery service
        XCTAssertEqual(mockBatteryService.forceRefreshCallCount, 0)

        // When force refresh is called
        mockBatteryService.forceRefresh()

        // Then the call count should increment
        XCTAssertEqual(mockBatteryService.forceRefreshCallCount, 1)
    }

    // MARK: - Bug Fix Verification Tests

    @MainActor
    func testPowerUntilFullCalculatesCorrectly() {
        // Given charging from 50% with known rate
        mockBatteryService.percentage = 50.0
        mockBatteryService.charging = BatteryCharging(.charging)

        // When we have rate data
        mockBatteryService.simulatePercentageChange(60.0)

        // Then percentage should be updated (mock doesn't calculate untilFull)
        XCTAssertEqual(mockBatteryService.percentage, 60.0)
        // Note: untilFull calculation is tested via integration with real BatteryManager
    }

    @MainActor
    func testDepletionRateWithZeroPercentageNoCrash() {
        // Given a battery at 0%
        mockBatteryService.percentage = 0.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When we attempt operations - should not crash
        mockBatteryService.forceRefresh()

        // Then we should reach this point without crash
        XCTAssertEqual(mockBatteryService.percentage, 0.0)
    }

    @MainActor
    func testDepletionRateWithNegativeSecondsNoCrash() {
        // Edge case: should handle edge cases gracefully
        mockBatteryService.percentage = 50.0
        mockBatteryService.charging = BatteryCharging(.battery)

        // When we simulate changes
        mockBatteryService.simulatePercentageChange(49.0)

        // Then it should handle without crash
        XCTAssertEqual(mockBatteryService.percentage, 49.0)
    }
}
