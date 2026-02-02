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
struct IOKitBluetoothDeviceInfo: Sendable {
    let address: String // Normalized to lowercase with dashes (xx-xx-xx-xx-xx-xx)
    let name: String?
    let isConnected: Bool
    let batteryPercent: Int?
    let deviceType: String // "keyboard", "mouse", "headphones", "speaker", "gamepad", "other"
    let vendorID: Int?
    let productID: Int?
}

actor IOKitBluetoothService {
    static let shared = IOKitBluetoothService()

    // MARK: - Apple Peripheral Battery via IORegistry (§2.2)

    /// Gets battery levels for Apple peripherals (Magic Keyboard, Mouse, Trackpad)
    /// from the AppleDeviceManagementHIDEventService IORegistry entries.
    func getDeviceBatteries() -> [String: Int] {
        var batteries: [String: Int] = [:]
        var iterator: io_iterator_t = 0

        let matching = IOServiceMatching("AppleDeviceManagementHIDEventService")
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return batteries
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }

            // Get device address
            guard let addressRef = IORegistryEntryCreateCFProperty(
                service, "DeviceAddress" as CFString, kCFAllocatorDefault, 0
            ), let address = addressRef.takeRetainedValue() as? String else { continue }

            // Get battery percentage
            if let batteryRef = IORegistryEntryCreateCFProperty(
                service, "BatteryPercent" as CFString, kCFAllocatorDefault, 0
            ), let battery = batteryRef.takeRetainedValue() as? Int {
                let normalizedAddress = address.lowercased().replacingOccurrences(of: ":", with: "-")
                batteries[normalizedAddress] = battery
            }
        }

        return batteries
    }

    // MARK: - Enumerate Paired Devices via IOBluetooth (§2.1)

    /// Gets all paired Bluetooth devices with their connection status and battery levels.
    func getConnectedDevices() -> [IOKitBluetoothDeviceInfo] {
        let batteryLevels = getDeviceBatteries()

        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }

        return pairedDevices.compactMap { device -> IOKitBluetoothDeviceInfo? in
            guard let addressString = device.addressString else { return nil }

            let address = addressString.lowercased().replacingOccurrences(of: ":", with: "-")

            return IOKitBluetoothDeviceInfo(
                address: address,
                name: device.name,
                isConnected: device.isConnected(),
                batteryPercent: batteryLevels[address],
                deviceType: classifyDevice(device),
                vendorID: nil, // Can be obtained from device properties if needed
                productID: nil
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

    // MARK: - AirPods Battery (§2.3 - Bluetooth Preferences Plist)

    /// Gets AirPods battery levels from the Bluetooth preferences plist.
    /// Note: This may not work in sandboxed apps without appropriate exceptions.
    func getAirPodsBattery() -> (left: Int?, right: Int?, chargingCase: Int?)? {
        guard let btPlist = NSDictionary(
            contentsOfFile: "/Library/Preferences/com.apple.Bluetooth.plist"
        ),
            let deviceCache = btPlist["DeviceCache"] as? [String: Any]
        else { return nil }

        // Find the device entry with AirPods battery keys
        for (_, deviceInfo) in deviceCache {
            guard let info = deviceInfo as? [String: Any] else { continue }

            // Check for AirPods-specific battery keys
            if info["BatteryPercentLeft"] != nil || info["BatteryPercentRight"] != nil {
                return (
                    left: info["BatteryPercentLeft"] as? Int,
                    right: info["BatteryPercentRight"] as? Int,
                    chargingCase: info["BatteryPercentCase"] as? Int
                )
            }
        }

        return nil
    }

    // MARK: - Device Battery by Address

    /// Gets battery level for a specific device by address.
    func getBatteryLevel(forAddress address: String) -> Int? {
        let normalizedAddress = address.lowercased().replacingOccurrences(of: ":", with: "-")
        let batteries = getDeviceBatteries()
        return batteries[normalizedAddress]
    }
}
