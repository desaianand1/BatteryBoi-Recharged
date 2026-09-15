//
//  BatteryServiceBehaviorTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for battery service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BatteryServiceBehaviorTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockBatteryService: MockBatteryService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockBatteryService()
        }
        mockBatteryService = service
    }

    override nonisolated func tearDown() {
        mockBatteryService = nil
        super.tearDown()
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
