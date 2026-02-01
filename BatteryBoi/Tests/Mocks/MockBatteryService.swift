//
//  MockBatteryService.swift
//  BatteryBoi
//
//  Mock implementation for unit testing.
//

import Combine
import Foundation

#if DEBUG

/// Mock battery service for unit testing.
@MainActor
final class MockBatteryService: BatteryServiceProtocol {
    // MARK: - Published Properties

    var charging: BatteryCharging
    var percentage: Double
    var remaining: BatteryRemaining?
    var mode: Bool
    var saver: BatteryModeType
    var rate: BatteryEstimateObject?
    var metrics: BatteryMetricsObject?
    var thermal: BatteryThemalState

    // MARK: - Publishers

    private let chargingSubject = PassthroughSubject<BatteryCharging, Never>()
    private let percentageSubject = PassthroughSubject<Double, Never>()
    private let thermalSubject = PassthroughSubject<BatteryThemalState, Never>()

    var chargingPublisher: AnyPublisher<BatteryCharging, Never> {
        chargingSubject.eraseToAnyPublisher()
    }

    var percentagePublisher: AnyPublisher<Double, Never> {
        percentageSubject.eraseToAnyPublisher()
    }

    var thermalPublisher: AnyPublisher<BatteryThemalState, Never> {
        thermalSubject.eraseToAnyPublisher()
    }

    // MARK: - Test Helpers

    var forceRefreshCallCount = 0
    var togglePowerSaveModeCallCount = 0

    // MARK: - Initialization

    init(
        charging: BatteryCharging = BatteryCharging(state: .battery),
        percentage: Double = 75.0,
        remaining: BatteryRemaining? = nil,
        mode: Bool = false,
        saver: BatteryModeType = .disabled,
        rate: BatteryEstimateObject? = nil,
        metrics: BatteryMetricsObject? = nil,
        thermal: BatteryThemalState = .nominal
    ) {
        self.charging = charging
        self.percentage = percentage
        self.remaining = remaining
        self.mode = mode
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
        saver = saver == .enabled ? .disabled : .enabled
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
        chargingSubject.send(newCharging)
    }

    func simulatePercentageChange(_ newPercentage: Double) {
        percentage = newPercentage
        percentageSubject.send(newPercentage)
    }

    func simulateThermalChange(_ newThermal: BatteryThemalState) {
        thermal = newThermal
        thermalSubject.send(newThermal)
    }
}

#endif
