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
final class BluetoothBridge: NSObject {

    // MARK: - Callbacks

    /// Called when a device connects
    var onDeviceConnected: (() -> Void)?

    /// Called when a device disconnects
    var onDeviceDisconnected: (() -> Void)?

    // MARK: - Notification Storage

    // SAFETY: nonisolated(unsafe) required because IOBluetoothUserNotification is a non-Sendable
    // Objective-C type that must be unregistered in deinit. BluetoothBridge is an NSObject subclass
    // (required for @objc selectors), so `isolated deinit` is not applicable — NSObject deinit
    // runs in a nonisolated context. These properties are only mutated on @MainActor (via
    // startListening/registerForDisconnect/unregisterAll, all MainActor-isolated under
    // -default-isolation MainActor). The deinit access is safe because NSObject deallocation
    // is deterministic and single-threaded.
    // REMOVAL: Cannot be removed while using IOBluetooth's @objc callback API. Would require
    // Apple to make IOBluetoothUserNotification Sendable, or a redesign to move notification
    // storage to a Swift actor (breaking the @objc bridge pattern — see architecture-decisions.md).
    // BLAST RADIUS: Removing causes compiler error in deinit. Moving to a different pattern risks
    // IOBluetooth crashes — the @objc bridge exists specifically because IOBluetooth callbacks
    // are incompatible with actor isolation (see architecture-decisions.md, @objc Bridge Pattern).
    nonisolated(unsafe) private(set) var connectionNotification: IOBluetoothUserNotification?
    nonisolated(unsafe) private(set) var disconnectionNotifications: [String: IOBluetoothUserNotification] = [:]

    // MARK: - Lifecycle

    override init() {
        super.init()
    }

    deinit {
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
