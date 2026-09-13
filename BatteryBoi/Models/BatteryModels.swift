//
//  BatteryModels.swift
//  BatteryBoi
//
//  Battery-related model types extracted for Swift 6.2 architecture.
//

import Foundation

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

    init(cycles: String, health: String) {
        self.cycles = BatteryCycleObject(Int(cycles) ?? 0)
        self.health = BatteryCondition(rawValue: health) ?? .optimal
    }

    init(cycleCount: Int, condition: String) {
        cycles = BatteryCycleObject(cycleCount)
        health = BatteryCondition(rawValue: condition) ?? .optimal
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
            formatted = "\("TimestampHourFullLabel".localise([hour]))  \("TimestampMinuteFullLabel".localise([minute]))"
        } else if hour == 0, minute > 0 {
            formatted = "TimestampMinuteFullLabel".localise([minute])
        } else if hour > 0 {
            formatted = "TimestampHourFullLabel".localise([hour])
        } else {
            formatted = nil
        }
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
