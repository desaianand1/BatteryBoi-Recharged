//
//  MockBatteryService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock battery service for unit testing.
    @MainActor
    final class MockBatteryService: BatteryServiceProtocol {
        // MARK: - Observable Properties

        var charging: BatteryCharging
        var percentage: Double
        var remaining: BatteryRemaining?
        var saver: BatteryModeType
        var rate: BatteryEstimateObject?
        var metrics: BatteryMetricsObject?
        var thermal: BatteryThemalState

        // MARK: - Test Helpers

        var forceRefreshCallCount = 0
        var togglePowerSaveModeCallCount = 0

        // MARK: - Initialization

        init(
            charging: BatteryCharging = BatteryCharging(.battery),
            percentage: Double = 75.0,
            remaining: BatteryRemaining? = nil,
            saver: BatteryModeType = .normal,
            rate: BatteryEstimateObject? = nil,
            metrics: BatteryMetricsObject? = nil,
            thermal: BatteryThemalState = .optimal
        ) {
            self.charging = charging
            self.percentage = percentage
            self.remaining = remaining
            self.saver = saver
            self.rate = rate
            self.metrics = metrics
            self.thermal = thermal
        }

        // MARK: - Methods

        func forceRefresh() {
            forceRefreshCallCount += 1
        }

        func togglePowerSaveMode() {
            togglePowerSaveModeCallCount += 1
            saver = saver == .efficient ? .normal : .efficient
        }

        var untilFull: Date? {
            nil
        }

        func hourWattage() -> Double? {
            nil
        }

        // MARK: - Test Simulation

        func simulateChargingChange(_ newCharging: BatteryCharging) {
            charging = newCharging
        }

        func simulatePercentageChange(_ newPercentage: Double) {
            percentage = newPercentage
        }

        func simulateThermalChange(_ newThermal: BatteryThemalState) {
            thermal = newThermal
        }
    }

#endif
