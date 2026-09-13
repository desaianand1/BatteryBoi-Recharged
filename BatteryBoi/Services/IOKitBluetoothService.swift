//
//  IOKitBluetoothService.swift
//  BatteryBoi
//
//  Native IOKit/IOBluetooth-based Bluetooth device service.
//  Replaces Python scripts with native macOS APIs.
//

import Foundation
@preconcurrency import IOBluetooth
@preconcurrency import IOKit

/// Bluetooth device information from IOKit/IOBluetooth
struct IOKitBluetoothDeviceInfo {
    let address: String
    let name: String?
    let isConnected: Bool
    let batteryPercent: Int?
    let batteryLeft: Int?
    let batteryRight: Int?
    let batteryCase: Int?
    let deviceType: String
    let vendorID: Int?
    let productID: Int?
}

actor IOKitBluetoothService {
    static let shared = IOKitBluetoothService()

    // MARK: - IORegistry Battery Scan (§2.2)

    /// Gets battery levels from IORegistry by scanning both AppleDeviceManagementHIDEventService
    /// (Apple peripherals) and IOHIDDevice (broader coverage for third-party HID devices).
    func getDeviceBatteries() -> [String: Int] {
        var batteries: [String: Int] = [:]
        let serviceClasses = [
            Constants.Bluetooth.appleHIDServiceClass,
            Constants.Bluetooth.hidDeviceServiceClass,
        ]

        for serviceClass in serviceClasses {
            var iterator: io_iterator_t = 0
            let matching = IOServiceMatching(serviceClass)
            guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
                continue
            }
            defer { IOObjectRelease(iterator) }

            var service = IOIteratorNext(iterator)
            while service != IO_OBJECT_NULL {
                defer {
                    IOObjectRelease(service)
                    service = IOIteratorNext(iterator)
                }

                guard let addressRef = IORegistryEntryCreateCFProperty(
                    service, Constants.Bluetooth.ioregDeviceAddress as CFString, kCFAllocatorDefault, 0
                ), let address = addressRef.takeRetainedValue() as? String else { continue }

                if let batteryRef = IORegistryEntryCreateCFProperty(
                    service, Constants.Bluetooth.ioregBatteryPercent as CFString, kCFAllocatorDefault, 0
                ), let battery = batteryRef.takeRetainedValue() as? Int,
                Constants.Bluetooth.validBatteryRange.contains(battery) {
                    let normalizedAddress = address.normalizedBluetoothAddress
                    if batteries[normalizedAddress] == nil {
                        batteries[normalizedAddress] = battery
                    }
                }
            }
        }

        return batteries
    }

    // MARK: - Enumerate Paired Devices via IOBluetooth (§2.1)

    /// Gets all paired Bluetooth devices with their connection status and battery levels.
    /// Uses two-layer battery reading: KVC (direct distribution) then IORegistry fallback.
    func getConnectedDevices() -> [IOKitBluetoothDeviceInfo] {
        let ioregBatteries = getDeviceBatteries()

        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        return pairedDevices.compactMap { device -> IOKitBluetoothDeviceInfo? in
            guard let addressString = device.addressString else { return nil }
            let address = addressString.normalizedBluetoothAddress

            var single: Int?
            var left: Int?
            var right: Int?
            var chargingCase: Int?
            var vendorID: Int?
            var productID: Int?

            #if DIRECT_DISTRIBUTION
                let kvc = self.readKVCBattery(from: device)
                single = kvc.single
                left = kvc.left
                right = kvc.right
                chargingCase = kvc.chargingCase
                let ids = self.readKVCVendorProduct(from: device)
                vendorID = ids.vendorID
                productID = ids.productID
            #endif

            // IORegistry fallback when KVC yielded nothing
            if single == nil, left == nil, right == nil {
                single = ioregBatteries[address]
            }

            return IOKitBluetoothDeviceInfo(
                address: address,
                name: device.name,
                isConnected: device.isConnected(),
                batteryPercent: single,
                batteryLeft: left,
                batteryRight: right,
                batteryCase: chargingCase,
                deviceType: classifyDevice(device),
                vendorID: vendorID,
                productID: productID
            )
        }
    }

    // MARK: - Device Classification

    /// Classifies a Bluetooth device using both device class codes and name patterns.
    /// This addresses GitHub #37 by using multiple classification strategies.
    private func classifyDevice(_ device: IOBluetoothDevice) -> String {
        // First, try Bluetooth device class codes (most reliable)
        let deviceClass = device.classOfDevice
        let majorClass = (deviceClass >> 8) & 0x1F
        let minorClass = (deviceClass >> 2) & 0x3F

        switch majorClass {
        case 0x05: // Peripheral
            switch minorClass {
            case 0x10:
                return "keyboard"
            case 0x20:
                return "mouse"
            case 0x30 ... 0x3F: // Combo devices
                return "keyboard"
            default:
                break
            }
        case 0x04: // Audio/Video
            // Check minor class for more specific types
            switch minorClass {
            case 0x01: // Wearable Headset
                return "headphones"
            case 0x02: // Hands-free
                return "headphones"
            case 0x04: // Microphone
                return "headphones"
            case 0x05: // Loudspeaker
                return "speaker"
            case 0x06: // Headphones
                return "headphones"
            case 0x07: // Portable Audio
                return "speaker"
            case 0x0B: // VCR
                return "other"
            default:
                return "headphones" // Default audio device to headphones
            }
        default:
            break
        }

        // Fallback: check device name for keywords (fixes GitHub #37)
        let name = (device.name ?? "").lowercased()

        if name.contains("keyboard") {
            return "keyboard"
        }
        if name.contains("mouse") || name.contains("trackpad") || name.contains("magic mouse") {
            return "mouse"
        }
        if name.contains("airpods") || name.contains("headphone") || name.contains("beats") ||
            name.contains("earbuds") || name.contains("buds")
        {
            return "headphones"
        }
        if name.contains("speaker") || name.contains("homepod") {
            return "speaker"
        }
        if name.contains("controller") || name.contains("gamepad") || name.contains("xbox") ||
            name.contains("playstation") || name.contains("dualsense") || name.contains("dualshock")
        {
            return "gamepad"
        }

        return "other"
    }

    // MARK: - KVC Battery Reader (Direct Distribution Only)

    #if DIRECT_DISTRIBUTION
        private func readKVCBattery(
            from device: IOBluetoothDevice
        ) -> (single: Int?, left: Int?, right: Int?, chargingCase: Int?) {
            func readKey(_ key: String) -> Int? {
                guard device.responds(to: NSSelectorFromString(key)),
                      let value = device.value(forKey: key) as? Int,
                      Constants.Bluetooth.validBatteryRange.contains(value)
                else { return nil }
                return value
            }

            return (
                single: readKey(Constants.Bluetooth.kvcBatterySingle),
                left: readKey(Constants.Bluetooth.kvcBatteryLeft),
                right: readKey(Constants.Bluetooth.kvcBatteryRight),
                chargingCase: readKey(Constants.Bluetooth.kvcBatteryCase)
            )
        }

        private func readKVCVendorProduct(from device: IOBluetoothDevice) -> (vendorID: Int?, productID: Int?) {
            func readKey(_ key: String) -> Int? {
                guard device.responds(to: NSSelectorFromString(key)) else { return nil }
                return device.value(forKey: key) as? Int
            }

            return (
                vendorID: readKey(Constants.Bluetooth.kvcVendorID),
                productID: readKey(Constants.Bluetooth.kvcProductID)
            )
        }
    #endif
}
