//
//  BluetoothService.swift
//  BatteryBoi
//
//  Bluetooth service with proper task lifecycle management.
//

import Cocoa
import CoreBluetooth
import Foundation
import IOBluetooth
import IOKit.ps

#if canImport(Sentry)
    import Sentry
#endif

/// Service for monitoring Bluetooth devices.
/// MainActor isolated for Swift 6.2 strict concurrency compliance.
@Observable
@MainActor
final class BluetoothService: BluetoothServiceProtocol {
    // MARK: - Static Instance

    static let shared = BluetoothService()

    // MARK: - Observable Properties

    var list = [BluetoothObject]()
    var connected = [BluetoothObject]()
    var icons = [String]()

    // MARK: - Private Properties

    /// Bridge for @objc callbacks
    private let bridge = BluetoothBridge()

    /// Scan timer task (nonisolated(unsafe) for deinit access per SE-0371)
    nonisolated(unsafe) private var scanTimerTask: Task<Void, Never>?

    /// Device observer task (nonisolated(unsafe) for deinit access per SE-0371)
    nonisolated(unsafe) private var deviceObserverTask: Task<Void, Never>?

    /// Update debounce task (nonisolated(unsafe) for deinit access per SE-0371)
    nonisolated(unsafe) private var bluetoothUpdateDebounceTask: Task<Void, Never>?

    // MARK: - BluetoothServiceProtocol Methods

    func updateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        bluetoothUpdateConnection(device, state: state)
    }

    func refreshDeviceList() async {
        await bluetoothListNative()
    }

    // MARK: - Initialization

    init() {
        setupBridge()
        startMonitoring()

        // Initial scan using native IOKit
        Task {
            await bluetoothListNative(initialize: true)

            // Update menu state based on connected devices
            switch list.filter({ $0.connected == .connected }).count {
            case 0: ServiceContainer.shared.state.currentMenu = .settings
            default: ServiceContainer.shared.state.currentMenu = .devices
            }
        }
    }

    deinit {
        // Note: bridge cleanup is handled by BluetoothBridge's own deinit
        // since calling MainActor-isolated methods from deinit is not allowed
        scanTimerTask?.cancel()
        deviceObserverTask?.cancel()
        bluetoothUpdateDebounceTask?.cancel()
    }

    // MARK: - Private Methods

    private func setupBridge() {
        bridge.onDeviceConnected = { [weak self] in
            self?.handleDeviceUpdated()
        }

        bridge.onDeviceDisconnected = { [weak self] in
            self?.handleDeviceUpdated()
        }
    }

    private func startMonitoring() {
        // Scan for Bluetooth devices every 15 seconds using native IOKit
        scanTimerTask = Task { [weak self] in
            var skipFirst = true
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { break }
                if skipFirst { skipFirst = false; continue }

                await bluetoothListNative()
            }
        }

        // Observe device selection changes to auto-connect
        deviceObserverTask = Task { [weak self] in
            var previousDevice: BluetoothObject?
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { break }

                let currentDevice = ServiceContainer.shared.state.selectedDevice
                if let device = currentDevice, device.address != previousDevice?.address {
                    if device.connected == .disconnected {
                        _ = bluetoothUpdateConnection(device, state: .connected)
                    }
                }
                previousDevice = currentDevice
            }
        }
    }

    /// Updates derived state after list modifications
    private func updateDerivedState() {
        connected = list.filter { $0.connected == .connected }
        icons = connected.map(\.type.icon)

        // Clean up disconnection notifications for devices no longer in list
        let currentAddresses = Set(list.map(\.address))
        bridge.cleanupStaleNotifications(currentAddresses: currentAddresses)
    }

    func bluetoothUpdateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        if let btDevice = IOBluetoothDevice(addressString: device.address) {
            if btDevice.isConnected() {
                if state == .connected {
                    return .connected
                } else {
                    let result = btDevice.closeConnection()
                    if result == kIOReturnSuccess {
                        return .disconnected
                    } else {
                        #if canImport(Sentry)
                            SentrySDK.capture(message: "Bluetooth disconnect failed") { scope in
                                scope.setExtra(value: device.address, key: "address")
                                scope.setExtra(value: result, key: "ioReturn")
                            }
                        #endif
                        return .failed
                    }
                }
            } else {
                if state == .connected {
                    let result = btDevice.openConnection()
                    if result == kIOReturnSuccess {
                        return .connected
                    } else {
                        #if canImport(Sentry)
                            SentrySDK.capture(message: "Bluetooth connect failed") { scope in
                                scope.setExtra(value: device.address, key: "address")
                                scope.setExtra(value: result, key: "ioReturn")
                            }
                        #endif
                        return .failed
                    }
                }
            }
        }

        return .unavailable
    }

    /// Refreshes the Bluetooth device list using native IOKit APIs
    private func bluetoothListNative(initialize: Bool = false) async {
        // Get device info from native IOKit service
        let devices = await IOKitBluetoothService.shared.getConnectedDevices()

        for deviceInfo in devices {
            let normalizedAddress = deviceInfo.address

            // Check if device already exists in the list
            if let listIndex = list.firstIndex(where: { $0.address == normalizedAddress }) {
                // Update existing device
                var updated = list[listIndex]
                updated.device = deviceInfo.name
                updated.connected = deviceInfo.isConnected ? .connected : .disconnected

                // Update battery if we have new data
                if let percent = deviceInfo.batteryPercent, updated.battery.general == nil {
                    updated.battery = BluetoothBatteryObject(percent: percent)
                }

                updated.updated = Date()
                list[listIndex] = updated
            } else {
                // Add new device
                let newDevice = BluetoothObject(
                    address: normalizedAddress,
                    name: deviceInfo.name,
                    isConnected: deviceInfo.isConnected,
                    batteryPercent: deviceInfo.batteryPercent,
                    deviceType: deviceInfo.deviceType
                )

                list.append(newDevice)

                // Register for disconnect notifications
                bridge.registerForDisconnect(address: normalizedAddress)
            }
        }

        if initialize {
            bridge.startListening()
        }

        updateDerivedState()
    }

    private func handleDeviceUpdated() {
        // Debounce rapid callbacks to prevent race conditions
        bluetoothUpdateDebounceTask?.cancel()
        bluetoothUpdateDebounceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, !Task.isCancelled else { return }

            var didUpdate = false
            for item in IOBluetoothDevice.pairedDevices() {
                if let device = item as? IOBluetoothDevice {
                    if let index = list
                        .firstIndex(where: { $0.address == device.addressString?.normalizedBluetoothAddress })
                    {
                        let status: BluetoothState = device.isConnected() ? .connected : .disconnected
                        var update = list[index]

                        if update.connected != status {
                            update.updated = Date()
                            update.connected = status
                            list[index] = update
                            didUpdate = true
                        }
                    }
                }
            }

            if didUpdate {
                updateDerivedState()
            }
        }
    }
}
