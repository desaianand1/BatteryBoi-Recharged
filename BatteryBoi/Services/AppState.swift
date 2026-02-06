//
//  AppState.swift
//  BatteryBoi
//
//  Centralized observable state for all UI components.
//  Part of Swift 6.2 architecture redesign.
//

import Foundation

/// Centralized observable state container for all UI-bound data.
/// Views observe this single state object instead of multiple managers.
@Observable
@MainActor
final class AppState {
    // MARK: - Battery State

    /// Current battery percentage (0-100)
    var batteryPercentage: Double = 100

    /// Current charging state
    var batteryCharging: BatteryCharging = .init(.battery)

    /// Estimated time remaining
    var batteryTimeRemaining: BatteryRemaining?

    /// Power save mode status
    var batterySaver: BatteryModeType = .unavailable

    /// Battery health metrics
    var batteryMetrics: BatteryMetricsObject?

    /// Thermal state
    var batteryThermal: BatteryThermalState = .optimal

    /// Discharge/charge rate estimation
    var batteryRate: BatteryEstimateObject?

    // MARK: - Bluetooth State

    /// All known Bluetooth devices
    var bluetoothDevices: [BluetoothObject] = []

    /// Connected Bluetooth devices
    var bluetoothConnected: [BluetoothObject] = []

    /// Icons for connected devices
    var bluetoothIcons: [String] = []

    /// Currently selected device for display
    var selectedDevice: BluetoothObject?

    // MARK: - HUD State

    /// Current HUD display state
    var hudState: HUDState = .hidden

    /// Current alert being displayed
    var currentAlert: HUDAlertTypes?

    /// Window position preference
    var windowPosition: WindowPosition = .topMiddle

    /// Window opacity (for pinned mode)
    var windowOpacity: CGFloat = 1.0

    /// Whether user is hovering over window
    var windowHover: Bool = false

    // MARK: - Navigation State

    /// Current menu view
    var currentMenu: SystemMenuView = .devices

    // MARK: - Display State

    /// Menu bar display text
    var displayText: String?

    /// Overlay display text
    var overlayText: String?

    /// HUD title
    var hudTitle: String = ""

    /// HUD subtitle
    var hudSubtitle: String = ""

    // MARK: - Event State

    /// Upcoming calendar events with URLs
    var events: [EventObject] = []

    // MARK: - Initialization

    init() {}

    // MARK: - Convenience Computed Properties

    /// Whether battery is currently charging
    var isCharging: Bool {
        batteryCharging.state == .charging
    }

    /// Whether any Bluetooth devices are connected
    var hasConnectedDevices: Bool {
        !bluetoothConnected.isEmpty
    }

    /// Whether the HUD is currently visible
    var isHUDVisible: Bool {
        hudState.visible
    }
}
