import Foundation
import IOKit.ps
import IOKit.pwr_mgt

#if canImport(Sentry)
    import Sentry
#endif

enum BatteryThemalState {
    case optimal
    case suboptimal

}

enum BatteryCondition: String {
    case optimal = "Normal"
    case suboptimal = "Replace Soon"
    case malfunctioning = "Service Battery"
    case unknown = "Unknown"

}

struct BatteryCycleObject {
    var numerical: Int
    var formatted: String

    init(_ count: Int) {
        numerical = count

        if count > 999 {
            let divisor = pow(10.0, Double(1))
            let string = ((Double(count) / 1000.0) * divisor).rounded() / divisor

            formatted = "\(string)k"

        } else {
            formatted = "\(Int(count))"

        }

    }

}

struct BatteryMetricsObject {
    var cycles: BatteryCycleObject
    var health: BatteryCondition

    init(cycles: String, health: String) {
        self.cycles = BatteryCycleObject(Int(cycles) ?? 0)
        self.health = BatteryCondition(rawValue: health) ?? .optimal
    }

    init(cycleCount: Int, condition: String) {
        cycles = BatteryCycleObject(cycleCount)
        health = BatteryCondition(rawValue: condition) ?? .optimal
    }
}

enum BatteryModeType {
    case normal
    case efficient
    case unavailable

    var flag: Bool {
        switch self {
        case .normal: false
        case .efficient: true
        case .unavailable: false
        }

    }

}

enum BatteryChargingState {
    case charging
    case battery

    var charging: Bool {
        switch self {
        case .charging: true
        case .battery: false
        }

    }

    func progress(_ percent: Double, width: CGFloat) -> CGFloat {
        let padding = BBConstants.Progress.batteryBarPadding
        let minDisplay = BBConstants.Progress.lowBatteryMinDisplay
        let maxDisplay = BBConstants.Progress.highBatteryMaxDisplay
        let adjustedWidth = width - padding

        if self == .charging {
            return min(100 * adjustedWidth, adjustedWidth)
        } else {
            if percent > 0, percent < minDisplay {
                return min(CGFloat(minDisplay / 100) * adjustedWidth, adjustedWidth)
            } else if percent >= maxDisplay, percent < 100 {
                return min(CGFloat(maxDisplay / 100) * adjustedWidth, adjustedWidth)
            } else {
                return min(CGFloat(percent / 100) * adjustedWidth, adjustedWidth)
            }
        }
    }

}

struct BatteryCharging: Equatable {
    var state: BatteryChargingState
    var started: Date?
    var ended: Date?

    init(_ charging: BatteryChargingState) {
        state = charging

        switch charging {
        case .charging: started = Date()
        case .battery: ended = Date()
        }

    }

}

struct BatteryRemaining: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date

    }

    var date: Date
    var hours: Int?
    var minutes: Int?
    var formatted: String?

    init(hour: Int, minute: Int) {
        hours = hour
        minutes = minute
        date = Date(timeIntervalSinceNow: 60 * 2)

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        if let date = Calendar.current.date(byAdding: components, to: Date()) {
            let units = Calendar.current.dateComponents([.minute, .hour], from: Date(), to: date)

            if let hours = units.hour, let minutes = units.minute {
                if hours == 0, minutes == 0 {
                    formatted = "AlertDeviceCalculatingTitle".localise()

                } else if hours != 0, minutes != 0 {
                    formatted = "\("TimestampHourFullLabel".localise([hours]))  \("TimestampMinuteFullLabel".localise([minutes]))"

                } else if hours == 0 {
                    formatted = "TimestampMinuteFullLabel".localise([minutes])

                } else if minute == 0 {
                    formatted = "TimestampHourFullLabel".localise([hour])

                }

            }

            self.date = date

        }

    }

}

struct BatteryEstimateObject {
    var timestamp: Date
    var percent: Double

    init(_ percent: Double) {
        timestamp = Date()
        self.percent = percent

    }

}

@Observable
@MainActor
final class BatteryManager: BatteryServiceProtocol {
    static let shared = BatteryManager()

    var charging: BatteryCharging = .init(.battery)
    var percentage: Double = 100
    var remaining: BatteryRemaining?
    var saver: BatteryModeType = .unavailable
    var rate: BatteryEstimateObject?
    var metrics: BatteryMetricsObject?
    var thermal: BatteryThemalState = .optimal

    nonisolated(unsafe) private var fallbackTimerTask: Task<Void, Never>?
    nonisolated(unsafe) private var initialTimer: Timer?
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

    init() {
        initialTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.powerUpdaterFallback()
            }
        }

        // Battery status check every 5 seconds (optimized from 1s)
        statusTask = Task { @MainActor [weak self] in
            var tickCount = 0
            for await _ in AppManager.shared.appTimerAsync(5) {
                guard let self, !Task.isCancelled else { break }
                tickCount += 1
                if tickCount > 1 {
                    powerStatus(true)
                }
            }
        }

        // Remaining time check every 30 seconds (optimized from 6s)
        remainingTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(30) {
                guard let self, !Task.isCancelled else { break }
                remaining = await fetchPowerRemaining()
            }
        }

        // Thermal check every 90 seconds
        thermalTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(90) {
                guard let self, !Task.isCancelled else { break }
                await powerThermalCheck()
            }
        }

        // Metrics check every 300 seconds (optimized from 60s)
        metricsTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(300) {
                guard let self, !Task.isCancelled else { break }
                saver = await fetchPowerSaveModeStatus()
                metrics = await fetchPowerProfilerDetails()
            }
        }

        powerStatus(true)
    }

    deinit {
        initialTimer?.invalidate()
        fallbackTimerTask?.cancel()
        statusTask?.cancel()
        remainingTask?.cancel()
        metricsTask?.cancel()
        thermalTask?.cancel()
    }

    func powerForceRefresh() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.powerStatus(true)

            try? await Task.sleep(for: .seconds(4))
            self.saver = await self.fetchPowerSaveModeStatus()
            self.metrics = await self.fetchPowerProfilerDetails()
        }
    }

    private func powerUpdaterFallback() {
        fallbackTimerTask?.cancel()
        fallbackTimerTask = Task { @MainActor [weak self] in
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
        if force == true {
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
            powerDepetionAverage = (Double(hour) * 60.0 * 60.0) + (Double(minute) * 60.0)
            return .init(hour: hour, minute: minute)
        }

        // Fallback to depletion rate estimate if IOKit returns nil (calculating)
        if let rate = powerDepetionAverage {
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

    private var powerDepetionAverage: Double? {
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

                Task { @MainActor in
                    self.saver = await self.fetchPowerSaveModeStatus()
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
