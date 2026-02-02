//
//  IOKitBatteryService.swift
//  BatteryBoi
//
//  Native IOKit-based battery information service.
//  Replaces shell command calls with native macOS APIs.
//

import Foundation
@preconcurrency import IOKit
@preconcurrency import IOKit.ps

/// Battery information from IOPowerSources (high-level API)
struct IOKitBatteryInfo: Sendable {
    let percentage: Int
    let isCharging: Bool
    let timeRemaining: Int? // minutes, nil if calculating
    let isACPowered: Bool
}

/// Detailed battery metrics from IORegistry (AppleSmartBattery)
struct IOKitBatteryMetrics: Sendable {
    let cycleCount: Int
    let condition: String // "Normal", "Replace Soon", "Service Battery"
    let maxCapacity: Int
    let designCapacity: Int
    let temperature: Double? // Celsius
    let voltage: Int? // mV
    let amperage: Int? // mA (negative = discharging)
}

actor IOKitBatteryService {
    static let shared = IOKitBatteryService()

    // MARK: - High-Level Battery Info via IOPowerSources (§1.1)

    /// Gets basic battery information using the IOPowerSources API.
    /// This is the recommended approach for percentage, charging state, and time remaining.
    func getBatteryInfo() -> IOKitBatteryInfo {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source)?
              .takeUnretainedValue() as? [String: Any]
        else {
            return IOKitBatteryInfo(percentage: 100, isCharging: false, timeRemaining: nil, isACPowered: false)
        }

        let percentage = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let powerState = desc[kIOPSPowerSourceStateKey] as? String
        let isACPowered = powerState == kIOPSACPowerValue

        // Time remaining: -1 means calculating, we return nil in that case
        var timeRemaining: Int?
        if isCharging {
            if let time = desc[kIOPSTimeToFullChargeKey] as? Int, time >= 0 {
                timeRemaining = time
            }
        } else {
            if let time = desc[kIOPSTimeToEmptyKey] as? Int, time >= 0 {
                timeRemaining = time
            }
        }

        return IOKitBatteryInfo(
            percentage: percentage,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            isACPowered: isACPowered,
        )
    }

    // MARK: - Deep Detail via IORegistry AppleSmartBattery (§1.2)

    /// Gets detailed battery metrics from the AppleSmartBattery IORegistry entry.
    /// Replaces `system_profiler SPPowerDataType` for cycle count and condition.
    func getBatteryMetrics() -> IOKitBatteryMetrics? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault, // NOT kIOMasterPortDefault (deprecated macOS 12+)
            IOServiceMatching("AppleSmartBattery"),
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any]
        else { return nil }

        let cycleCount = dict["CycleCount"] as? Int ?? 0
        let maxCapacity = dict["MaxCapacity"] as? Int ?? 0
        let designCapacity = dict["DesignCapacity"] as? Int ?? 0

        // BatteryHealthCondition: nil = Normal, otherwise "Check Battery" or "Service Battery"
        let healthCondition = dict["BatteryHealthCondition"] as? String ?? "Normal"

        // Temperature is in centi-degrees Celsius (divide by 100)
        let temperature: Double? = (dict["Temperature"] as? Int).map { Double($0) / 100.0 }

        let voltage = dict["Voltage"] as? Int
        let amperage = dict["Amperage"] as? Int

        return IOKitBatteryMetrics(
            cycleCount: cycleCount,
            condition: healthCondition,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            temperature: temperature,
            voltage: voltage,
            amperage: amperage,
        )
    }

    // MARK: - Time Remaining Calculation

    /// Gets battery time remaining in hours and minutes format.
    /// Returns nil if the system is still calculating.
    func getTimeRemaining() -> (hours: Int, minutes: Int)? {
        let info = getBatteryInfo()
        guard let totalMinutes = info.timeRemaining, totalMinutes >= 0 else { return nil }
        return (hours: totalMinutes / 60, minutes: totalMinutes % 60)
    }

    // MARK: - Thermal State (replaces pmset -g therm)

    /// Checks if the device is in a thermal throttling state.
    /// Uses ProcessInfo which is the modern replacement for parsing pmset output.
    nonisolated func getThermalState() -> Bool {
        let state = ProcessInfo.processInfo.thermalState
        return state == .serious || state == .critical
    }

    // MARK: - Low Power Mode (replaces pmset -g | grep lowpowermode)

    /// Checks if Low Power Mode is enabled.
    nonisolated func isLowPowerModeEnabled() -> Bool {
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: - Power Source Notifications (§3.4)

    /// Stores the run loop source to keep it alive
    private var runLoopSource: CFRunLoopSource?

    /// Static callback storage for C function pointer compatibility
    nonisolated(unsafe) private static var powerSourceCallback: (@Sendable () -> Void)?

    /// Starts monitoring for power source changes (AC/battery, charge level).
    /// The callback fires on the main run loop when power source state changes.
    nonisolated func startPowerSourceNotifications(onChange: @escaping @Sendable () -> Void) {
        IOKitBatteryService.powerSourceCallback = onChange

        let source = IOPSNotificationCreateRunLoopSource({ _ in
            IOKitBatteryService.powerSourceCallback?()
        }, nil).takeRetainedValue()

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    // MARK: - Wattage Calculation

    /// Calculates the battery watt-hours from max capacity and voltage.
    func getWattHours() -> Double? {
        guard let metrics = getBatteryMetrics(),
              let voltage = metrics.voltage,
              metrics.maxCapacity > 0
        else { return nil }

        // maxCapacity is in mAh, voltage is in mV
        // Wh = (mAh / 1000) * (mV / 1000)
        return (Double(metrics.maxCapacity) / 1000.0) * (Double(voltage) / 1000.0)
    }
}
