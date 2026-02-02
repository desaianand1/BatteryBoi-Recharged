//
//  BatteryServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the battery monitoring service interface.
/// Enables dependency injection and testability for battery-related functionality.
@MainActor
protocol BatteryServiceProtocol: AnyObject {
    // MARK: - Observable Properties

    /// Current charging state
    var charging: BatteryCharging { get }

    /// Current battery percentage (0-100)
    var percentage: Double { get }

    /// Estimated time remaining on battery or until full charge
    var remaining: BatteryRemaining? { get }

    /// Current power save mode status
    var saver: BatteryModeType { get }

    /// Battery discharge/charge rate estimation
    var rate: BatteryEstimateObject? { get }

    /// Battery health metrics (cycle count, condition)
    var metrics: BatteryMetricsObject? { get }

    /// Current thermal state
    var thermal: BatteryThemalState { get }

    // MARK: - Methods

    /// Force refresh battery status
    func forceRefresh()

    /// Toggle power save mode
    func togglePowerSaveMode()

    /// Get estimated date until battery is full
    var untilFull: Date? { get }

    /// Get watt-hour capacity
    func hourWattage() -> Double?
}
