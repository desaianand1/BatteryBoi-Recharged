//
//  BBBatteryManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/4/23.
//

import Combine
import Foundation
import IOKit.ps
import IOKit.pwr_mgt

enum BatteryWattageType {
    case current
    case max
    case voltage

}

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
    var heath: BatteryCondition

    init(cycles: String, health: String) {
        self.cycles = BatteryCycleObject(Int(cycles) ?? 0)
        heath = BatteryCondition(rawValue: health) ?? .optimal

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
        if self == .charging {
            min(100 * (width - 2.6), width - 2.6)

        } else {
            if percent > 0, percent < 10 {
                min(CGFloat(10 / 100) * (width - 2.6), width - 2.6)

            } else if percent >= 90, percent < 100 {
                min(CGFloat(90 / 100) * (width - 2.6), width - 2.6)

            } else {
                min(CGFloat(percent / 100) * (width - 2.6), width - 2.6)

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
    var mode: Bool = false
    var saver: BatteryModeType = .unavailable
    var rate: BatteryEstimateObject?
    var metrics: BatteryMetricsObject?
    var thermal: BatteryThemalState = .optimal

    private var counter: Int?
    private var fallbackTimer: Timer?
    private var initialTimer: Timer?
    private var statusTask: Task<Void, Never>?
    private var remainingTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    #if DEBUG
        private var thermalTask: Task<Void, Never>?
    #endif

    // MARK: - BatteryServiceProtocol Publishers

    var chargingPublisher: AnyPublisher<BatteryCharging, Never> {
        $charging.eraseToAnyPublisher()
    }

    var percentagePublisher: AnyPublisher<Double, Never> {
        $percentage.eraseToAnyPublisher()
    }

    var thermalPublisher: AnyPublisher<BatteryThemalState, Never> {
        $thermal.eraseToAnyPublisher()
    }

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
            guard let self else { return }
            if counter == nil {
                powerUpdaterFallback()
            }
        }

        // Battery status check every 1 second (skip first 5 ticks)
        statusTask = Task { @MainActor [weak self] in
            var tickCount = 0
            for await _ in AppManager.shared.appTimerAsync(1) {
                guard let self, !Task.isCancelled else { break }
                tickCount += 1
                if tickCount > 5 {
                    powerStatus(true)
                    counter = nil
                }
            }
        }

        // Remaining time check every 6 seconds
        remainingTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(6) {
                guard let self, !Task.isCancelled else { break }
                remaining = await fetchPowerRemaining()
                counter = nil
            }
        }

        #if DEBUG
            // Thermal check every 90 seconds (DEBUG only)
            thermalTask = Task { @MainActor [weak self] in
                for await _ in AppManager.shared.appTimerAsync(90) {
                    guard let self, !Task.isCancelled else { break }
                    await powerThermalCheck()
                }
            }
        #endif

        // Metrics check every 60 seconds
        metricsTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(60) {
                guard let self, !Task.isCancelled else { break }
                saver = await fetchPowerSaveModeStatus()
                metrics = await fetchPowerProfilerDetails()
                counter = nil
            }
        }

        powerStatus(true)
    }

    deinit {
        initialTimer?.invalidate()
        fallbackTimer?.invalidate()
        statusTask?.cancel()
        remainingTask?.cancel()
        metricsTask?.cancel()
        #if DEBUG
            thermalTask?.cancel()
        #endif
    }

    func powerForceRefresh() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            self.powerStatus(true)
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            self.saver = await self.fetchPowerSaveModeStatus()
            self.metrics = await self.fetchPowerProfilerDetails()
        }

    }

    private func powerUpdaterFallback() {
        fallbackTimer?.invalidate()
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let counter = self.counter {
                if counter.isMultiple(of: 1) {
                    self.powerStatus(true)

                }

                if counter.isMultiple(of: 6) {
                    Task { @MainActor in
                        self.remaining = await self.fetchPowerRemaining()
                    }

                }

            }

            self.counter = (self.counter ?? 0) + 1

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
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let source = IOPSGetProvidingPowerSourceType(snapshot).takeRetainedValue()

        switch source as String == kIOPSACPowerValue {
        case true: return .charging
        case false: return .battery
        }

    }

    private var powerPercentage: Double {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array
        for source in sources {
            if let description = IOPSGetPowerSourceDescription(snapshot, source)
                .takeUnretainedValue() as? [String: Any],
                description["Type"] as? String == kIOPSInternalBatteryType
            {
                return description[kIOPSCurrentCapacityKey] as? Double ?? 0.0
            }
        }

        return 100.0

    }

    private func fetchPowerRemaining() async -> BatteryRemaining? {
        do {
            let output = try await ProcessRunner.shared.runShell(
                command: "pmset -g batt | grep -o '[0-9]\\{1,2\\}:[0-9]\\{2\\}'",
                timeout: .seconds(10),
            )

            let components = output.components(separatedBy: ":")
            if let hour = components.first.flatMap({ Int($0) }),
               let minute = components.last.flatMap({ Int($0) })
            {
                await MainActor.run {
                    self.powerDepetionAverage = (Double(hour) * 60.0 * 60.0) + (Double(minute) * 60.0)
                }
                return .init(hour: hour, minute: minute)
            } else if let rate = powerDepetionAverage {
                let date = Date().addingTimeInterval(rate * percentage)
                let components = Calendar.current.dateComponents([.hour, .minute], from: Date(), to: date)
                return .init(hour: components.hour ?? 0, minute: components.minute ?? 0)
            }

            return .init(hour: 0, minute: 0)
        } catch {
            if let rate = powerDepetionAverage {
                let date = Date().addingTimeInterval(rate * percentage)
                let components = Calendar.current.dateComponents([.hour, .minute], from: Date(), to: date)
                return .init(hour: components.hour ?? 0, minute: components.minute ?? 0)
            }
            return nil
        }
    }

    var powerUntilFull: Date? {
        guard percentage < 100 else { return nil }
        guard charging.state == .charging else { return nil }

        var seconds = 180.0
        let remainder = 100 - percentage

        if let exists = rate {
            if percentage > exists.percent {
                seconds = Date().timeIntervalSince(exists.timestamp)

                UserDefaults.save(.batteryUntilFull, value: seconds)

            }

        }

        rate = .init(percentage)

        return Date(timeIntervalSinceNow: Double(seconds) * Double(remainder))

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

                guard percentage > 0 else { return }
                if averages.contains(seconds / percentage) == false, charging.state == .battery {
                    if (seconds / percentage) > 0.0 {
                        var list = Array(averages.suffix(15))
                        list.append(seconds / percentage)

                        UserDefaults.save(.batteryDepletionRate, value: list)

                    }

                }

            }

        }

    }

    private func fetchPowerSaveModeStatus() async -> BatteryModeType {
        do {
            let output = try await ProcessRunner.shared.run(
                executable: "/usr/bin/env",
                arguments: ["bash", "-c", "pmset -g | grep lowpowermode"],
                timeout: .seconds(10),
            )

            if output.contains("lowpowermode") {
                if output.contains("1") {
                    return .efficient
                } else if output.contains("0") {
                    return .normal
                }
            }

            return .unavailable
        } catch {
            return .unavailable
        }
    }

    func powerSaveMode() {
        if saver != .unavailable {
            let command = "do shell script \"pmset -c lowpowermode \(saver.flag ? 0 : 1)\" with administrator privileges"

            if let script = NSAppleScript(source: command) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)

                Task { @MainActor in
                    self.saver = await self.fetchPowerSaveModeStatus()
                }

            }

        }

    }

    private func powerThermalCheck() async {
        do {
            let output = try await ProcessRunner.shared.run(
                executable: "/usr/bin/env",
                arguments: ["pmset", "-g", "therm"],
                timeout: .seconds(10),
            )

            let cores = await fetchCPUCores()
            var isSuboptimal = false

            if let match = output.range(of: "CPU_Scheduler_Limit\\s+=\\s+(\\d+)", options: .regularExpression) {
                let value = Int(output[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ??
                    0

                if value < 100 {
                    isSuboptimal = true

                }

            }

            if let match = output.range(of: "CPU_Available_CPUs\\s+=\\s+(\\d+)", options: .regularExpression) {
                let value = Int(output[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ??
                    0

                if value < cores {
                    isSuboptimal = true

                }

            }

            if let match = output.range(of: "CPU_Speed_Limit\\s+=\\s+(\\d+)", options: .regularExpression) {
                let value = Int(output[match].components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ??
                    0

                if value < 100 {
                    isSuboptimal = true

                }

            }

            await MainActor.run {
                self.thermal = isSuboptimal ? .suboptimal : .optimal
            }

        } catch {
            print("Thermal check failed: \(error)")
        }

    }

    private func fetchCPUCores() async -> Int {
        do {
            let output = try await ProcessRunner.shared.run(
                executable: "/usr/bin/env",
                arguments: ["sysctl", "-n", "hw.physicalcpu"],
                timeout: .seconds(5),
            )
            return Int(output) ?? 1
        } catch {
            return 1
        }
    }

    private func fetchPowerProfilerDetails() async -> BatteryMetricsObject? {
        do {
            let output = try await ProcessRunner.shared.run(
                executable: "/usr/bin/env",
                arguments: ["system_profiler", "SPPowerDataType"],
                timeout: .seconds(30),
            )

            let lines = output.split(separator: "\n")

            var cycles: String?
            var health: String?

            for line in lines {
                if line.contains("Cycle Count") {
                    cycles = String(line.split(separator: ":").last ?? "").trimmingCharacters(in: .whitespaces)
                }

                if line.contains("Condition") {
                    health = String(line.split(separator: ":").last ?? "").trimmingCharacters(in: .whitespaces)
                }

                if let cycles, let health {
                    return .init(cycles: cycles, health: health)
                }
            }

            return nil
        } catch {
            return nil
        }
    }

    private func fetchPowerWattage(_ type: BatteryWattageType) async -> Int? {
        let command = switch type {
        case .current: "ioreg -l | grep CurrentCapacity | awk '{print $5}'"
        case .max: "ioreg -l | grep MaxCapacity | awk '{print $5}'"
        case .voltage: "ioreg -l | grep Voltage | awk '{print $5}'"
        }

        do {
            let output = try await ProcessRunner.shared.runShell(command: command, timeout: .seconds(10))
            return Int(output)
        } catch {
            return nil
        }
    }

    func fetchPowerHourWattage() async -> Double? {
        async let mAh = fetchPowerWattage(.max)
        async let mV = fetchPowerWattage(.voltage)

        if let maxCapacity = await mAh, let voltage = await mV {
            return (Double(maxCapacity) / 1000.0) * (Double(voltage) / 1000.0)
        }

        return nil
    }

}
