//
//  BluetoothServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Combine
import Foundation

/// Protocol defining the Bluetooth device monitoring service interface.
/// Enables dependency injection and testability for Bluetooth-related functionality.
@MainActor
protocol BluetoothServiceProtocol: AnyObject {
    // MARK: - Published Properties

    /// All discovered Bluetooth devices
    var list: [BluetoothObject] { get }

    /// Currently connected Bluetooth devices
    var connected: [BluetoothObject] { get }

    /// Icons for connected devices
    var icons: [String] { get }

    // MARK: - Publishers

    /// Publisher for device list changes
    var listPublisher: AnyPublisher<[BluetoothObject], Never> { get }

    /// Publisher for connected device changes
    var connectedPublisher: AnyPublisher<[BluetoothObject], Never> { get }

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
