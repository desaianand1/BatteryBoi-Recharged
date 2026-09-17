//
//  BatteryModels.swift
//  BatteryBoi
//
//  Battery-related model types extracted for Swift 6.2 architecture.
//

import Foundation
import SwiftUI

// MARK: - Thermal State

enum BatteryThermalState {
    case optimal
    case suboptimal
}

// MARK: - Battery Condition

enum BatteryCondition: String {
    case optimal = "Normal"
    case suboptimal = "Replace Soon"
    case malfunctioning = "Service Battery"
    case unknown = "Unknown"
}

// MARK: - Cycle Count

struct BatteryCycleObject: Equatable {
    var numerical: Int
    var formatted: String

    init(_ count: Int) {
        let count = max(0, count)
        numerical = count

        if count > 999 {
            formatted = String(format: "%.1fk", Double(count) / 1000.0)
        } else {
            formatted = "\(count)"
        }
    }
}

// MARK: - Battery Metrics

struct BatteryMetricsObject: Equatable {
    var cycles: BatteryCycleObject
    var health: BatteryCondition
    var temperature: Double?
    var voltage: Double?
    var amperage: Double?
    var maxCapacity: Int?
    var designCapacity: Int?
    var nominalChargeCapacity: Int?
    var appleRawMaxCapacity: Int?
    var healthPercent: Double?

    init(cycles: String, health: String) {
        self.cycles = BatteryCycleObject(Int(cycles) ?? 0)
        self.health = BatteryCondition(rawValue: health) ?? .optimal
    }

    init(cycleCount: Int, condition: String) {
        self.cycles = BatteryCycleObject(cycleCount)
        self.health = BatteryCondition(rawValue: condition) ?? .optimal
    }

    init(
        cycleCount: Int,
        condition: String,
        temperature: Double?,
        voltage: Int?,
        amperage: Int?,
        maxCapacity: Int?,
        designCapacity: Int?,
        nominalChargeCapacity: Int? = nil,
        appleRawMaxCapacity: Int? = nil
    ) {
        self.cycles = BatteryCycleObject(cycleCount)
        self.health = BatteryCondition(rawValue: condition) ?? .optimal

        self.temperature = (temperature == nil || temperature == 0.0) ? nil : temperature
        self.voltage = voltage.map { Double($0) / 1000.0 }
        self.amperage = amperage.map { Double($0) / 1000.0 }
        self.maxCapacity = (maxCapacity ?? 0) > 0 ? maxCapacity : nil
        self.designCapacity = (designCapacity ?? 0) > 0 ? designCapacity : nil
        self.nominalChargeCapacity = (nominalChargeCapacity ?? 0) > 0 ? nominalChargeCapacity : nil
        self.appleRawMaxCapacity = (appleRawMaxCapacity ?? 0) > 0 ? appleRawMaxCapacity : nil

        let effectiveCapacity: Int? = self.nominalChargeCapacity
            ?? self.appleRawMaxCapacity
            ?? self.maxCapacity

        if let cap = effectiveCapacity, let design = self.designCapacity, design > 0, cap > 0 {
            if cap <= 100, design > 1000 {
                // MaxCapacity is a percentage (Apple Silicon) and no mAh alternatives exist
                self.healthPercent = nil
            } else {
                self.healthPercent = min(Double(cap) / Double(design) * 100.0, 100.0)
            }
        }
    }
}

// MARK: - Battery Metrics Computed Properties

extension BatteryMetricsObject {
    var effectiveMaxCapacityMAh: Int? {
        let candidate = self.nominalChargeCapacity ?? self.appleRawMaxCapacity ?? self.maxCapacity
        guard let cap = candidate, cap > 0 else { return nil }
        if cap <= 100, let design = self.designCapacity, design > 1000 {
            return nil
        }
        return cap
    }
}

// MARK: - Battery Metrics Formatting

extension BatteryMetricsObject {
    var temperatureFormatted: String {
        guard let t = self.temperature else { return "—" }
        let measurement = Measurement(value: t, unit: UnitTemperature.celsius)
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.numberFormatter.minimumFractionDigits = 1
        return formatter.string(from: measurement)
    }

    var voltageFormatted: String {
        guard let v = self.voltage else { return "—" }
        return String(format: "%.1fV", v)
    }

    var amperageFormatted: String {
        guard let a = self.amperage else { return "—" }
        return String(format: "%d mA", Int(abs(a * 1000)))
    }

    var powerWatts: Double? {
        guard let v = self.voltage, let a = self.amperage else { return nil }
        return abs(v * a)
    }

    var powerFormatted: String {
        guard let w = self.powerWatts else { return "—" }
        return String(format: "%.1fW", w)
    }

    var isDischarging: Bool {
        (self.amperage ?? -1) < 0
    }

    var capacityFormatted: String {
        guard let max = self.effectiveMaxCapacityMAh, let design = self.designCapacity else { return "—" }
        return "\(max.formatted()) / \(design.formatted()) mAh \("DashboardCapacityLowercaseSuffix".localise())"
    }
}

// MARK: - Battery Metrics Status Helpers

extension BatteryMetricsObject {
    var temperatureStatus: (label: String, color: Color)? {
        guard let t = self.temperature else { return nil }
        if t < 35 {
            return ("DashboardStatusNormal".localise(), SemanticColor.success)
        }
        if t <= 45 {
            return ("DashboardStatusWarm".localise(), SemanticColor.warning)
        }
        return ("DashboardStatusHot".localise(), SemanticColor.error)
    }

    var powerStatus: (label: String, color: Color)? {
        self.powerStatusForState(isCharging: false)
    }

    func powerStatusForState(isCharging: Bool) -> (label: String, color: Color)? {
        guard let w = self.powerWatts else { return nil }
        if isCharging {
            if w < 30 {
                return ("DashboardStatusSlow".localise(), SemanticColor.warning)
            }
            if w <= 60 {
                return ("DashboardStatusNormal".localise(), SemanticColor.success)
            }
            return ("DashboardStatusFast".localise(), SemanticColor.success)
        }
        if w < 15 {
            return ("DashboardStatusEfficient".localise(), SemanticColor.success)
        }
        if w <= 30 {
            return ("DashboardStatusModerate".localise(), SemanticColor.warning)
        }
        return ("DashboardStatusHeavy".localise(), SemanticColor.error)
    }

    var amperageColor: Color {
        guard let a = self.amperage else { return Color("BBTitle") }
        if a >= 0 {
            return SemanticColor.success
        }
        let draw = abs(a)
        if draw > 3.0 {
            return SemanticColor.error
        }
        if draw > 2.0 {
            return SemanticColor.warning
        }
        return Color("BBTitle")
    }
}

// MARK: - Battery Condition Display

extension BatteryCondition {
    var displayName: String {
        switch self {
        case .optimal: "Good"
        case .suboptimal: "Fair"
        case .malfunctioning: "Service"
        case .unknown: "Unknown"
        }
    }
}

// MARK: - Power Save Mode

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

// MARK: - Charging State

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
        let padding = Constants.Progress.batteryBarPadding
        let minDisplay = Constants.Progress.lowBatteryMinDisplay
        let maxDisplay = Constants.Progress.highBatteryMaxDisplay
        let adjustedWidth = width - padding

        if self == .charging {
            return adjustedWidth
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

// MARK: - Battery Charging

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

// MARK: - Battery Remaining Time

struct BatteryRemaining: Equatable, Sendable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.hours == rhs.hours && lhs.minutes == rhs.minutes
    }

    var date: Date
    var hours: Int?
    var minutes: Int?
    var formatted: String?

    init(hour: Int, minute: Int) {
        self.hours = hour
        self.minutes = minute
        self
            .date = Date(timeIntervalSinceNow: Double(hour) * Constants.Battery
                .secondsPerHour + Double(minute) * Constants.Battery.secondsPerMinute)

        if hour > 0, minute > 0 {
            formatted = "\("TimestampHourFullLabel".localise([hour])) \("TimestampMinuteFullLabel".localise([minute]))"
        } else if hour == 0, minute > 0 {
            formatted = "TimestampMinuteFullLabel".localise([minute])
        } else if hour > 0 {
            formatted = "TimestampHourFullLabel".localise([hour])
        } else {
            formatted = nil
        }
    }

    var formattedShort: String? {
        guard let h = self.hours, let m = self.minutes else { return nil }
        let hLabel = "TimestampHourAbbriviatedLabel".localise()
        let mLabel = "TimestampMinuteAbbriviatedLabel".localise()
        if h > 0, m > 0 {
            return "\(h)\(hLabel) \(m)\(mLabel)"
        }
        if h > 0 {
            return "\(h)\(hLabel)"
        }
        if m > 0 {
            return "\(m)\(mLabel)"
        }
        return nil
    }
}

// MARK: - Battery Estimate

struct BatteryEstimateObject: Equatable {
    var timestamp: Date
    var percent: Double

    init(_ percent: Double) {
        timestamp = Date()
        self.percent = percent
    }
}

// MARK: - Battery Style

enum BatteryStyle: String {
    case chunky
    case basic

    var title: String {
        switch self {
        case .chunky: "SettingsStyleChunkyLabel".localise()
        case .basic: "SettingsStyleBasicLabel".localise()
        }
    }

    var radius: CGFloat {
        switch self {
        case .basic: 3
        case .chunky: 5
        }
    }

    var size: CGSize {
        switch self {
        case .basic: .init(width: 28, height: 13)
        case .chunky: .init(width: 32, height: 15)
        }
    }

    var padding: CGFloat {
        switch self {
        case .basic: 1
        case .chunky: 2
        }
    }
}

#if DEBUG

    // MARK: - Test Convenience Initializers

    extension BatteryThermalState {
        /// Alias for test compatibility: critical maps to suboptimal
        static let critical: BatteryThermalState = .suboptimal
    }

    extension BatteryCycleObject {
        /// Test convenience: access numerical as count
        var count: Int {
            numerical
        }

        /// Test convenience: limit is not tracked, return reasonable default
        var limit: Int {
            1000
        }

        /// Test initializer with count and limit (limit is ignored, for API compatibility)
        init(count: Int, limit _: Int) {
            self.init(count)
        }
    }

    /// Condition enum for test compatibility with old API
    enum BatteryMetricsCondition {
        case good
        case fair
        case service

        var toBatteryCondition: BatteryCondition {
            switch self {
            case .good: .optimal
            case .fair: .suboptimal
            case .service: .malfunctioning
            }
        }
    }

    extension BatteryMetricsObject {
        /// Test initializer with typed condition using BatteryCondition
        init(cycles: BatteryCycleObject, condition: BatteryCondition) {
            self.cycles = cycles
            self.health = condition
        }

        /// Test initializer with legacy condition enum
        init(cycles: BatteryCycleObject, condition: BatteryMetricsCondition) {
            self.cycles = cycles
            self.health = condition.toBatteryCondition
        }

        /// Test convenience: access health as condition
        var condition: BatteryCondition {
            health
        }
    }
#endif
