//
//  MockBluetoothService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock Bluetooth service for unit testing.
    @MainActor
    final class MockBluetoothService: BluetoothServiceProtocol {
        // MARK: - Observable Properties

        var list: [BluetoothObject]
        var connected: [BluetoothObject]
        var icons: [String]

        // MARK: - Test Helpers

        var updateConnectionCallCount = 0
        var refreshDeviceListCallCount = 0
        var lastUpdateConnectionDevice: BluetoothObject?
        var lastUpdateConnectionState: BluetoothState?

        // MARK: - Initialization

        nonisolated init(
            list: [BluetoothObject] = [],
            connected: [BluetoothObject] = [],
            icons: [String] = []
        ) {
            self.list = list
            self.connected = connected
            self.icons = icons
        }

        // MARK: - Methods

        func updateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
            updateConnectionCallCount += 1
            lastUpdateConnectionDevice = device
            lastUpdateConnectionState = state

            // Actually update device state in list (behavior testing)
            if let index = list.firstIndex(where: { $0.address == device.address }) {
                var updatedDevice = list[index]
                updatedDevice.connected = state
                updatedDevice.updated = Date()
                list[index] = updatedDevice

                // Update connected array automatically
                if state == .connected {
                    if !connected.contains(where: { $0.address == device.address }) {
                        connected.append(updatedDevice)
                    }
                } else {
                    connected.removeAll { $0.address == device.address }
                }
            }

            return state == .connected ? .connected : .disconnected
        }

        func refreshDeviceList() async {
            refreshDeviceListCallCount += 1
        }

        // MARK: - Test Simulation

        var forceRefreshCallCount = 0

        func forceRefresh() {
            forceRefreshCallCount += 1
        }

        func simulateListChange(_ newList: [BluetoothObject]) {
            list = newList
        }

        func simulateConnectedChange(_ newConnected: [BluetoothObject]) {
            connected = newConnected
        }

        func simulateDeviceConnected(_ device: BluetoothObject) {
            // Add to list if not already present
            if !list.contains(where: { $0.address == device.address }) {
                list.append(device)
            }
            // Add to connected if not already present
            if !connected.contains(where: { $0.address == device.address }) {
                connected.append(device)
            }
        }

        func simulateDeviceDisconnected(address: String) {
            let normalizedAddress = address.lowercased().replacingOccurrences(of: ":", with: "-")
            connected.removeAll { $0.address == normalizedAddress }
        }

        func simulateBatteryUpdate(_ device: BluetoothObject) {
            // Update battery in list
            if let index = list.firstIndex(where: { $0.address == device.address }) {
                list[index] = device
            }
            // Update battery in connected
            if let index = connected.firstIndex(where: { $0.address == device.address }) {
                connected[index] = device
            }
        }
    }

#endif
