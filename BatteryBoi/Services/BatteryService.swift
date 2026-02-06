//
//  BatteryService.swift
//  BatteryBoi
//
//  Battery service with proper task lifecycle management.
//

import Foundation
import IOKit.ps
import IOKit.pwr_mgt

#if canImport(Sentry)
    import Sentry
#endif

/// Service for monitoring battery status.
/// MainActor isolated for Swift 6.2 strict concurrency compliance.
@Observable
@MainActor
final class BatteryService: BatteryServiceProtocol {
    // MARK: - Static Instance

    static let shared = BatteryService()

    // MARK: - Observable Properties

    var charging: BatteryCharging = .init(.battery)
    var percentage: Double = 100
    var remaining: BatteryRemaining?
    var saver: BatteryModeType = .unavailable
    var rate: BatteryEstimateObject?
    var metrics: BatteryMetricsObject?
    var thermal: BatteryThermalState = .optimal

    // MARK: - Private Properties

    // Note: nonisolated(unsafe) is justified for task properties that are only
    // accessed in deinit (which is always nonisolated) per SE-0371.

    nonisolated(unsafe) private var fallbackTimerTask: Task<Void, Never>?
    nonisolated(unsafe) private var initialDelayTask: Task<Void, Never>?
    nonisolated(unsafe) private var statusTask: Task<Void, Never>?
    nonisolated(unsafe) private var remainingTask: Task<Void, Never>?
    nonisolated(unsafe) private var metricsTask: Task<Void, Never>?
    nonisolated(unsafe) private var thermalTask: Task<Void, Never>?

    // MARK: - BatteryServiceProtocol Methods

    func forceRefresh() {
        powerForceRefresh()
    }

    func togglePowerSaveMode() {
        powerSaveMode()
    }

    var untilFull: Date? {
        powerUntilFull
    }

    func hourWattage() -> Double? {
        // Sync version returns nil - use fetchPowerHourWattage() for async access
        nil
    }

    // MARK: - Initialization

    init() {
        // Start initial delay timer
        initialDelayTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard let self, !Task.isCancelled else { return }
            powerUpdaterFallback()
        }

        startMonitoring()
        powerStatus(true)
    }

    deinit {
        initialDelayTask?.cancel()
        fallbackTimerTask?.cancel()
        statusTask?.cancel()
        remainingTask?.cancel()
        metricsTask?.cancel()
        thermalTask?.cancel()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        // Battery status check every 5 seconds
        statusTask = Task { [weak self] in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { break }
                tickCount += 1
                if tickCount > 1 {
                    powerStatus(true)
                }
            }
        }

        // Remaining time check every 30 seconds
        remainingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { break }
                remaining = await fetchPowerRemaining()
            }
        }

        // Thermal check every 90 seconds
        thermalTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(90))
                guard let self, !Task.isCancelled else { break }
                await powerThermalCheck()
            }
        }

        // Metrics check every 300 seconds
        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard let self, !Task.isCancelled else { break }
                saver = await fetchPowerSaveModeStatus()
                metrics = await fetchPowerProfilerDetails()
            }
        }
    }

    func powerForceRefresh() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            powerStatus(true)

            try? await Task.sleep(for: .seconds(4))
            saver = await fetchPowerSaveModeStatus()
            metrics = await fetchPowerProfilerDetails()
        }
    }

    private func powerUpdaterFallback() {
        fallbackTimerTask?.cancel()
        fallbackTimerTask = Task { [weak self] in
            var tickCount = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }

                tickCount += 1
                if tickCount.isMultiple(of: 1) {
                    powerStatus(true)
                }

                if tickCount.isMultiple(of: 6) {
                    remaining = await fetchPowerRemaining()
                }
            }
        }
    }

    private func powerStatus(_ force: Bool = false) {
        if force {
            percentage = powerPercentage

            if powerCharging != charging.state {
                charging = .init(powerCharging)
            }
        }
    }

    private var powerCharging: BatteryChargingState {
        guard let snapshotRef = IOPSCopyPowerSourcesInfo() else { return .battery }
        let snapshot = snapshotRef.takeRetainedValue()

        guard let sourceRef = IOPSGetProvidingPowerSourceType(snapshot) else { return .battery }
        let source = sourceRef.takeRetainedValue()

        switch source as String == kIOPSACPowerValue {
        case true: return .charging
        case false: return .battery
        }
    }

    private var powerPercentage: Double {
        guard let snapshotRef = IOPSCopyPowerSourcesInfo() else { return 100.0 }
        let snapshot = snapshotRef.takeRetainedValue()

        guard let sourcesRef = IOPSCopyPowerSourcesList(snapshot) else { return 100.0 }
        let sources = sourcesRef.takeRetainedValue() as Array

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                description["Type"] as? String == kIOPSInternalBatteryType
            {
                return description[kIOPSCurrentCapacityKey] as? Double ?? 0.0
            }
        }

        return 100.0
    }

    private func fetchPowerRemaining() async -> BatteryRemaining? {
        // Use native IOKit API instead of shell command
        if let timeRemaining = await IOKitBatteryService.shared.getTimeRemaining() {
            let hour = timeRemaining.hours
            let minute = timeRemaining.minutes
            powerDepletionAverage = (Double(hour) * 60.0 * 60.0) + (Double(minute) * 60.0)
            return .init(hour: hour, minute: minute)
        }

        // Fallback to depletion rate estimate if IOKit returns nil
        if let rate = powerDepletionAverage {
            let date = Date().addingTimeInterval(rate * percentage)
            let components = Calendar.current.dateComponents([.hour, .minute], from: Date(), to: date)
            return .init(hour: components.hour ?? 0, minute: components.minute ?? 0)
        }

        return .init(hour: 0, minute: 0)
    }

    var powerUntilFull: Date? {
        guard percentage < 100 else { return nil }
        guard charging.state == .charging else { return nil }

        let remainder = 100 - percentage

        if let exists = rate, percentage > exists.percent {
            let elapsed = Date().timeIntervalSince(exists.timestamp)
            let percentGained = percentage - exists.percent
            guard percentGained > 0 else {
                rate = .init(percentage)
                return nil
            }
            let secondsPerPercent = elapsed / percentGained
            UserDefaults.save(.batteryUntilFull, value: secondsPerPercent)
            rate = .init(percentage)
            return Date(timeIntervalSinceNow: secondsPerPercent * remainder)
        }

        rate = .init(percentage)

        // Use stored rate or fallback
        let stored = UserDefaults.main.double(forKey: SystemDefaultsKeys.batteryUntilFull.rawValue)
        if stored > 0 {
            return Date(timeIntervalSinceNow: stored * remainder)
        }
        return nil
    }

    private var powerDepletionAverage: Double? {
        get {
            if let averages = UserDefaults.main
                .object(forKey: SystemDefaultsKeys.batteryDepletionRate.rawValue) as? [Double],
                !averages.isEmpty
            {
                return averages.reduce(0.0, +) / Double(averages.count)
            }
            return nil
        }

        set {
            if let seconds = newValue {
                let averages = UserDefaults.main
                    .object(forKey: SystemDefaultsKeys.batteryDepletionRate.rawValue) as? [Double] ?? [Double]()

                guard percentage > 0.0, seconds > 0.0 else { return }
                let depletionRate = seconds / percentage
                guard depletionRate.isFinite, depletionRate > 0.0 else { return }

                if averages.contains(depletionRate) == false, charging.state == .battery {
                    var list = Array(averages.suffix(15))
                    list.append(depletionRate)
                    UserDefaults.save(.batteryDepletionRate, value: list)
                }
            }
        }
    }

    private func fetchPowerSaveModeStatus() async -> BatteryModeType {
        // Use native ProcessInfo API instead of shell command
        let isLowPowerMode = IOKitBatteryService.shared.isLowPowerModeEnabled()
        return isLowPowerMode ? .efficient : .normal
    }

    func powerSaveMode() {
        if saver != .unavailable {
            let command = "do shell script \"pmset -c lowpowermode \(saver.flag ? 0 : 1)\" with administrator privileges"

            if let script = NSAppleScript(source: command) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)

                if let error {
                    #if canImport(Sentry)
                        SentrySDK.capture(message: "Power save mode AppleScript failed") { scope in
                            scope.setExtra(
                                value: error["NSAppleScriptErrorMessage"] as? String ?? "Unknown error",
                                key: "message"
                            )
                            scope.setExtra(value: error["NSAppleScriptErrorNumber"] as? Int ?? -1, key: "errorNumber")
                        }
                    #endif
                }

                Task {
                    saver = await fetchPowerSaveModeStatus()
                }
            }
        }
    }

    private func powerThermalCheck() async {
        // Use native ProcessInfo API instead of shell command
        let isThrottled = IOKitBatteryService.shared.getThermalState()
        thermal = isThrottled ? .suboptimal : .optimal
    }

    private func fetchPowerProfilerDetails() async -> BatteryMetricsObject? {
        // Use native IOKit API instead of system_profiler command
        guard let metrics = await IOKitBatteryService.shared.getBatteryMetrics() else {
            return nil
        }
        return BatteryMetricsObject(cycleCount: metrics.cycleCount, condition: metrics.condition)
    }

    func fetchPowerHourWattage() async -> Double? {
        // Use native IOKit API instead of shell commands
        await IOKitBatteryService.shared.getWattHours()
    }
}
