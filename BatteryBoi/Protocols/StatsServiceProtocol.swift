//
//  StatsServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the statistics service interface.
/// Enables dependency injection and testability for stats functionality.
/// Note: The actual StatsService is an actor, but this protocol is used
/// for MainActor-isolated views and mocks.
@MainActor
protocol StatsServiceProtocol: AnyObject {
    // MARK: - Observable Properties

    /// Display text for menu bar
    var display: String? { get }

    /// Overlay text for menu bar
    var overlay: String? { get }

    /// HUD title
    var title: String { get }

    /// HUD subtitle
    var subtitle: String { get }

    /// Icon for stats display
    var statsIcon: StatsIcon { get }

    // MARK: - Methods

    /// Record an activity event
    /// - Parameters:
    ///   - state: The type of state change
    ///   - device: Optional Bluetooth device associated with the event
    func recordActivity(_ state: StatsStateType, device: BluetoothObject?) async
}
