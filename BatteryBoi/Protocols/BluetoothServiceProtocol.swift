//
//  BluetoothServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the Bluetooth device monitoring service interface.
/// Enables dependency injection and testability for Bluetooth-related functionality.
@MainActor
protocol BluetoothServiceProtocol: AnyObject {
    // MARK: - Observable Properties

    /// All discovered Bluetooth devices
    var list: [BluetoothObject] { get }

    /// Currently connected Bluetooth devices
    var connected: [BluetoothObject] { get }

    /// Icons for connected devices
    var icons: [String] { get }

    /// Current Bluetooth permission status
    var permissionStatus: BluetoothPermissionStatus { get }

    // MARK: - Methods

    /// Update connection state for a device
    /// - Parameters:
    ///   - device: The Bluetooth device
    ///   - state: The desired connection state
    /// - Returns: The resulting connection state
    func updateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState

    /// Refresh the Bluetooth device list
    func refreshDeviceList() async
}
