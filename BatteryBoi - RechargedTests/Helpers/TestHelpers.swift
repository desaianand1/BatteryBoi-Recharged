//
//  TestHelpers.swift
//  BatteryBoi-RechargedTests
//
//  Test convenience initializers and helpers
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    // MARK: - BluetoothObject Test Helpers

    extension BluetoothObject {
        /// Creates a test BluetoothObject with sensible defaults
        /// - Parameters:
        ///   - address: Bluetooth address (default: "AA:BB:CC:DD:EE:FF")
        ///   - name: Device name (default: "Test Device")
        ///   - isConnected: Connection state (default: true)
        ///   - batteryPercent: Battery percentage (default: 75)
        ///   - deviceType: Type of device (default: .headphones)
        /// - Returns: A configured BluetoothObject for testing
        static func testDevice(
            address: String = "AA:BB:CC:DD:EE:FF",
            name: String = "Test Device",
            isConnected: Bool = true,
            batteryPercent: Int? = 75,
            deviceType: BluetoothDeviceType = .headphones
        ) -> BluetoothObject {
            BluetoothObject(
                address: address,
                name: name,
                isConnected: isConnected,
                batteryPercent: batteryPercent,
                deviceType: deviceType.rawValue
            )
        }
    }

    // MARK: - BluetoothBatteryObject Test Helpers

    /// Helper function to create test battery objects with custom values
    func makeTestBattery(general: Double?, left: Double?, right: Double?) -> BluetoothBatteryObject {
        var battery = BluetoothBatteryObject(percent: general.map { Int($0) })
        battery.left = left
        battery.right = right
        battery.general = general

        // Calculate minimum percent for multi-battery devices
        if left == nil, right == nil, general == nil {
            battery.percent = nil
        } else if let min = [right, left, general].compactMap(\.self).min() {
            battery.percent = min
        }

        return battery
    }

    extension BluetoothBatteryObject {
        /// Creates a battery object for a single battery device
        /// - Parameter percent: Battery percentage as Double
        init(percent: Double) {
            self.init(percent: Int(percent))
        }

        /// Creates a battery object for dual-battery devices (e.g., AirPods)
        /// - Parameters:
        ///   - percent: General battery percent
        ///   - left: Left earbud battery percent
        ///   - right: Right earbud battery percent
        init(percent: Double, left: Double, right: Double) {
            self = makeTestBattery(general: percent, left: left, right: right)
        }
    }

#endif
