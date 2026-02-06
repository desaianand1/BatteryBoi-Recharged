//
//  BatteryModels.swift
//  BatteryBoi
//
//  Battery-related model types extracted for Swift 6.2 architecture.
//

import Foundation

// MARK: - Thermal State

enum BatteryThermalState: Sendable {
    case optimal
    case suboptimal
}

// MARK: - Battery Condition

enum BatteryCondition: String, Sendable {
    case optimal = "Normal"
    case suboptimal = "Replace Soon"
    case malfunctioning = "Service Battery"
    case unknown = "Unknown"
}

// MARK: - Cycle Count

struct BatteryCycleObject: Sendable {
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

// MARK: - Battery Metrics

struct BatteryMetricsObject: Sendable {
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

enum BatteryModeType: Sendable {
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

enum BatteryChargingState: Sendable {
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

// MARK: - Battery Charging

struct BatteryCharging: Equatable, Sendable {
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

// MARK: - Battery Estimate

struct BatteryEstimateObject: Sendable {
    var timestamp: Date
    var percent: Double

    init(_ percent: Double) {
        timestamp = Date()
        self.percent = percent
    }
}

// MARK: - Battery Style

enum BatteryStyle: String, Sendable {
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
    enum BatteryMetricsCondition: Sendable {
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
