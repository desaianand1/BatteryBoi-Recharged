//
//  BluetoothBridge.swift
//  BatteryBoi
//
//  Bridge for IOBluetooth @objc callbacks with Swift 6.2 strict concurrency.
//  Handles the boundary between Objective-C callbacks and Swift async/await.
//

import Cocoa
import Foundation
import IOBluetooth

/// Bridge object for handling IOBluetooth Objective-C callbacks.
/// MainActor isolated for Swift 6.2 strict concurrency compliance.
@MainActor
final class BluetoothBridge: NSObject {
    // MARK: - Callbacks

    /// Called when a device connects
    var onDeviceConnected: (() -> Void)?

    /// Called when a device disconnects
    var onDeviceDisconnected: (() -> Void)?

    // MARK: - Notification Storage (nonisolated for deinit access)

    /// Connection notification (global)
    nonisolated(unsafe) private(set) var connectionNotification: IOBluetoothUserNotification?

    /// Per-device disconnection notifications
    nonisolated(unsafe) private(set) var disconnectionNotifications: [String: IOBluetoothUserNotification] = [:]

    // MARK: - Lifecycle

    override init() {
        super.init()
    }

    deinit {
        // Direct access to nonisolated(unsafe) properties
        connectionNotification?.unregister()
        connectionNotification = nil
        for (_, notification) in disconnectionNotifications {
            notification.unregister()
        }
        disconnectionNotifications.removeAll()
    }

    // MARK: - Registration

    /// Start listening for connection events
    func startListening() {
        connectionNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleDeviceUpdated)
        )
    }

    /// Register for disconnect notifications for a specific device
    func registerForDisconnect(address: String) {
        let colonAddress = address.replacingOccurrences(of: "-", with: ":")

        guard let btDevice = IOBluetoothDevice(addressString: colonAddress),
              disconnectionNotifications[address] == nil
        else {
            return
        }

        if let notification = btDevice.register(
            forDisconnectNotification: self,
            selector: #selector(handleDeviceUpdated)
        ) {
            disconnectionNotifications[address] = notification
        }
    }

    /// Unregister all notifications
    func unregisterAll() {
        connectionNotification?.unregister()
        connectionNotification = nil

        for (_, notification) in disconnectionNotifications {
            notification.unregister()
        }
        disconnectionNotifications.removeAll()
    }

    /// Unregister disconnect notification for a specific device
    func unregisterDisconnect(address: String) {
        disconnectionNotifications[address]?.unregister()
        disconnectionNotifications.removeValue(forKey: address)
    }

    /// Clean up stale disconnect notifications
    func cleanupStaleNotifications(currentAddresses: Set<String>) {
        let staleAddresses = disconnectionNotifications.keys
            .filter { !currentAddresses.contains($0.lowercased().replacingOccurrences(of: ":", with: "-")) }

        for address in staleAddresses {
            unregisterDisconnect(address: address)
        }
    }

    // MARK: - Callback Handlers

    @objc
    private func handleDeviceUpdated() {
        // Already on main actor with default isolation
        // Callbacks trigger the service to refresh
        onDeviceConnected?()
    }

    @objc
    private func handleDeviceDisconnected() {
        // Already on main actor with default isolation
        onDeviceDisconnected?()
    }
}
