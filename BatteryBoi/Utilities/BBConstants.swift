import Foundation

/// Centralized constants for BatteryBoi application.
/// Consolidates hardcoded values for easier maintenance and configuration.
enum BBConstants {
    /// Timer intervals used throughout the app.
    enum Timers {
        /// Bluetooth device scan interval in seconds.
        static let bluetoothScan: TimeInterval = 15

        /// Battery status check interval in seconds.
        static let batteryStatus: TimeInterval = 5

        /// Battery remaining time check interval in seconds.
        static let batteryRemaining: TimeInterval = 30

        /// Battery metrics check interval in seconds (cycle count, health).
        static let metricsCheck: TimeInterval = 300

        /// Thermal state check interval in seconds.
        static let thermalCheck: TimeInterval = 90

        /// HUD auto-dismissal interval in seconds.
        static let hudDismissal: TimeInterval = 10

        /// Charging state debounce interval in seconds.
        static let chargingDebounce: TimeInterval = 2
    }

    /// Battery-related thresholds.
    enum BatteryThresholds {
        /// Percentage levels that trigger low battery alerts.
        static let alerts: [Int] = [25, 10, 5, 1]

        /// Default charge limit percentage for "charge to 80%" feature.
        static let chargeLimit: Int = 80
    }

    /// Animation durations.
    enum Animation {
        /// Standard transition duration.
        static let standard: Double = 0.3

        /// Spring animation response.
        static let springResponse: Double = 0.6

        /// Spring animation damping.
        static let springDamping: Double = 0.9
    }

    /// Progress indicator sizing constants.
    enum Progress {
        /// Mini progress indicator size (for device icons).
        static let miniSize: CGFloat = 28

        /// Normal progress indicator size.
        static let normalSize: CGFloat = 80

        /// Container size for progress indicators.
        static let containerSize: CGFloat = 90

        /// Battery bar padding for progress calculation.
        static let batteryBarPadding: CGFloat = 2.6

        /// Minimum display percentage for low battery (prevents bar from being invisible).
        static let lowBatteryMinDisplay: Double = 10.0

        /// Maximum display percentage for high battery (prevents visual overflow).
        static let highBatteryMaxDisplay: Double = 90.0
    }

    /// Window constants.
    enum Window {
        /// Default HUD width.
        static let hudWidth: CGFloat = 440

        /// Default HUD height.
        static let hudHeight: CGFloat = 240

        /// Menu bar icon width.
        static let menuBarWidth: CGFloat = 45

        /// Menu bar icon height.
        static let menuBarHeight: CGFloat = 22

        /// Modal window title identifier.
        static let modalWindowTitle = "modalwindow"

        /// Default window margin from screen edges.
        static let defaultMargin: CGFloat = 40
    }

    /// Bluetooth-related constants.
    enum Bluetooth {
        /// RSSI threshold for "proximate" distance (on desk/table).
        static let rssiProximateThreshold: Double = -50

        /// RSSI threshold for "near" distance (same room).
        static let rssiNearThreshold: Double = -70
    }
}
