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
@Observable @MainActor
final class BatteryService: BatteryServiceProtocol {

    // MARK: - Observable Properties

    var charging: BatteryCharging = .init(.battery)
    var percentage: Double = 100
    var remaining: BatteryRemaining?
    var saver: BatteryModeType = .unavailable
    var rate: BatteryEstimateObject?
    var metrics: BatteryMetricsObject?
    var thermal: BatteryThermalState = .optimal

    // MARK: - Private Charge State

    private var ioKitChargeMinutes: Int?

    // MARK: - Private Properties

    private var metricsTask: Task<Void, Never>?
    private var thermalTask: Task<Void, Never>?
    private var forceRefreshTask: Task<Void, Never>?
    private var saveModeFetchTask: Task<Void, Never>?

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
        nil
    }

    func fetchHourWattage() -> Double? {
        fetchPowerHourWattage()
    }

    // MARK: - Initialization

    init() {
        startMonitoring()
    }

    isolated deinit {
        metricsTask?.cancel()
        thermalTask?.cancel()
        forceRefreshTask?.cancel()
        saveModeFetchTask?.cancel()
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        powerStatus()

        saver = fetchPowerSaveModeStatus()
        metrics = fetchPowerProfilerDetails()
        powerThermalCheck()

        IOKitBatteryService.shared.startPowerSourceNotifications { [weak self] in
            Task { @MainActor [weak self] in
                self?.powerStatus()
            }
        }

        thermalTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.Timers.thermalCheck))
                guard let self, !Task.isCancelled else { break }
                powerThermalCheck()
            }
        }

        metricsTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.Timers.metricsCheck))
                guard let self, !Task.isCancelled else { break }
                saver = fetchPowerSaveModeStatus()
                metrics = fetchPowerProfilerDetails()
            }
        }
    }

    func powerForceRefresh() {
        self.rate = nil
        self.ioKitChargeMinutes = nil
        forceRefreshTask?.cancel()
        forceRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.Timers.forceRefreshDelay))
            guard let self, !Task.isCancelled else { return }
            self.powerStatus()

            try? await Task.sleep(for: .seconds(Constants.Timers.forceRefreshSecondary))
            guard !Task.isCancelled else { return }
            self.saver = self.fetchPowerSaveModeStatus()
            self.metrics = self.fetchPowerProfilerDetails()
        }
    }

    private func powerStatus() {
        let info = IOKitBatteryService.shared.getBatteryInfo()
        let newCharging: BatteryChargingState = info.isACPowered ? .charging : .battery
        let newPercentage = Double(info.percentage)

        self.percentage = newPercentage
        if newCharging != self.charging.state {
            self.charging = .init(newCharging)
        }
        self.ioKitChargeMinutes = info.isCharging ? info.timeRemaining : nil
        self.remaining = self.buildRemaining(fromMinutes: info.timeRemaining)
        self.updateChargeRate(charging: newCharging, percentage: newPercentage)
        self.persistDepletionRate(totalMinutes: info.timeRemaining, charging: newCharging, percentage: newPercentage)
    }

    private func buildRemaining(fromMinutes totalMinutes: Int?) -> BatteryRemaining? {
        Self.buildRemaining(
            fromMinutes: totalMinutes,
            depletionAverage: self.depletionAverage,
            percentage: self.percentage
        )
    }

    static func buildRemaining(
        fromMinutes totalMinutes: Int?,
        depletionAverage: Double?,
        percentage: Double
    ) -> BatteryRemaining? {
        if let totalMinutes, totalMinutes > 0 {
            let hours = totalMinutes / Constants.Battery.minutesPerHour
            let minutes = totalMinutes % Constants.Battery.minutesPerHour
            guard hours > 0 || minutes > 0 else { return nil }
            return BatteryRemaining(hour: hours, minute: minutes)
        }
        if let rate = depletionAverage {
            let date = Date().addingTimeInterval(rate * percentage)
            let components = Calendar.current.dateComponents([.hour, .minute], from: Date(), to: date)
            let h = components.hour ?? 0
            let m = components.minute ?? 0
            guard h > 0 || m > 0 else { return nil }
            return BatteryRemaining(hour: h, minute: m)
        }
        return nil
    }

    var powerUntilFull: Date? {
        guard self.charging.state == .charging else { return nil }

        let stored = UserDefaults.main.double(forKey: SystemDefaultsKeys.batteryUntilFull.rawValue)
        return Self.chargeCompletionDate(
            percentage: self.percentage,
            ioKitMinutes: self.ioKitChargeMinutes,
            storedSecondsPerPercent: stored > 0 ? stored : nil
        )
    }

    static func chargeCompletionDate(
        percentage: Double,
        ioKitMinutes: Int?,
        storedSecondsPerPercent: Double?
    ) -> Date? {
        guard percentage < 100 else { return nil }

        let remainder = 100.0 - percentage

        if let minutes = ioKitMinutes, minutes > 0 {
            return Date(timeIntervalSinceNow: Double(minutes) * Constants.Battery.secondsPerMinute)
        }

        if let stored = storedSecondsPerPercent, stored > 0 {
            let seconds = stored * remainder
            guard seconds <= remainder * Constants.Battery.maxSecondsPerPercent else { return nil }
            return Date(timeIntervalSinceNow: seconds)
        }

        return nil
    }

    private func updateChargeRate(charging: BatteryChargingState, percentage: Double) {
        guard charging == .charging else {
            if self.rate != nil {
                self.rate = nil
            }
            return
        }
        if let existing = self.rate, percentage > existing.percent {
            let elapsed = Date().timeIntervalSince(existing.timestamp)
            let gained = percentage - existing.percent
            if gained > 0, elapsed > 0 {
                let secondsPerPercent = elapsed / gained
                if secondsPerPercent.isFinite, secondsPerPercent > 0 {
                    UserDefaults.save(.batteryUntilFull, value: secondsPerPercent)
                }
            }
        }
        self.rate = .init(percentage)
    }

    private var depletionAverage: Double? {
        if let averages = UserDefaults.main
            .object(forKey: SystemDefaultsKeys.batteryDepletionRate.rawValue) as? [Double],
            !averages.isEmpty
        {
            return averages.reduce(0.0, +) / Double(averages.count)
        }
        return nil
    }

    private func persistDepletionRate(totalMinutes: Int?, charging: BatteryChargingState, percentage: Double) {
        guard let totalMinutes, totalMinutes > 0, charging == .battery else { return }
        guard percentage > 0.0 else { return }

        let seconds = Double(totalMinutes) * Constants.Battery.secondsPerMinute
        let depletionRate = seconds / percentage
        guard depletionRate.isFinite, depletionRate > 0.0 else { return }

        let averages = UserDefaults.main
            .object(forKey: SystemDefaultsKeys.batteryDepletionRate.rawValue) as? [Double] ?? [Double]()

        if !averages.contains(depletionRate) {
            var list = Array(averages.suffix(Constants.Battery.depletionRateHistorySize))
            list.append(depletionRate)
            UserDefaults.save(.batteryDepletionRate, value: list)
        }
    }

    private func fetchPowerSaveModeStatus() -> BatteryModeType {
        let isLowPowerMode = IOKitBatteryService.shared.isLowPowerModeEnabled()
        return isLowPowerMode ? .efficient : .normal
    }

    func powerSaveMode() {
        #if DIRECT_DISTRIBUTION
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
                                scope.setExtra(
                                    value: error["NSAppleScriptErrorNumber"] as? Int ?? -1,
                                    key: "errorNumber"
                                )
                            }
                        #endif
                    }

                    saveModeFetchTask = Task { [weak self] in
                        guard let self else { return }
                        self.saver = self.fetchPowerSaveModeStatus()
                    }
                }
            }
        #endif
    }

    private func powerThermalCheck() {
        let isThrottled = IOKitBatteryService.shared.getThermalState()
        thermal = isThrottled ? .suboptimal : .optimal
    }

    private func fetchPowerProfilerDetails() -> BatteryMetricsObject? {
        guard let metrics = IOKitBatteryService.shared.getBatteryMetrics() else {
            return nil
        }
        return BatteryMetricsObject(
            cycleCount: metrics.cycleCount,
            condition: metrics.condition,
            temperature: metrics.temperature,
            voltage: metrics.voltage,
            amperage: metrics.amperage,
            maxCapacity: metrics.maxCapacity,
            designCapacity: metrics.designCapacity,
            nominalChargeCapacity: metrics.nominalChargeCapacity,
            appleRawMaxCapacity: metrics.appleRawMaxCapacity
        )
    }

    func fetchPowerHourWattage() -> Double? {
        IOKitBatteryService.shared.getWattHours()
    }
}
