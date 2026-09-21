import Foundation

/// Centralized constants for BatteryBoi application.
/// Consolidates hardcoded values for easier maintenance and configuration.
nonisolated enum Constants {
    /// Timer intervals used throughout the app.
    enum Timers {

        // MARK: - Service Polling

        static let bluetoothScan: TimeInterval = 15
        static let metricsCheck: TimeInterval = 300
        static let thermalCheck: TimeInterval = 90
        static let chargingDebounce: TimeInterval = 0.3

        // MARK: - Periodic Checks

        static let bluetoothBatteryCheck: TimeInterval = 60
        static let eventCheck: TimeInterval = 30

        // MARK: - StatsService

        static let wattageRecord: TimeInterval = 3600

        // MARK: - EventService

        static let eventInitialDelay: TimeInterval = 10
        static let eventRefresh: TimeInterval = 1800

        // MARK: - BatteryService

        static let forceRefreshDelay: TimeInterval = 1
        static let forceRefreshSecondary: TimeInterval = 4

        // MARK: - HUD Window State Transitions

        static let hudDismissDelay: Double = 0.8
        static let hudProgressDelay: Double = 0.2
        static let hudRevealDelay: Double = RevealTiming.totalReveal
        static let hudTimeoutShort: Double = 5
        static let hudTimeoutLong: Double = 10
        static let stateChangeDebounce: Double = 0.15
        static let mouseEventDebounce: Double = 0.1
        static let clickGracePeriod: Double = 0.5
        static let hoverMaxHold: Double = 30
        static let hoverMinResume: Double = 3

        // MARK: - Scroll Opacity

        static let scrollOpacityMin: CGFloat = 0.4
        static let scrollOpacityMax: CGFloat = 1.0
        static let scrollOpacityDivisor: CGFloat = 100
    }

    /// Battery-related thresholds.
    enum BatteryThresholds {
        /// Percentage levels that trigger low battery alerts.
        static let alerts: [Int] = [25, 10, 5, 1]

        /// Default charge limit percentage for "charge to 80%" feature.
        static let chargeLimit: Int = 80

        /// Bluetooth battery must rise above this level to re-arm alerts (10-point gap above highest alert).
        static let bluetoothResetThreshold: Double = 50
    }

    /// Battery service constants.
    enum Battery {
        static let depletionRateHistorySize: Int = 15
        static let secondsPerMinute: Double = 60.0
        static let secondsPerHour: Double = 3600.0
        static let minutesPerHour: Int = 60
        static let maxSecondsPerPercent: Double = 300.0
    }

    /// Progress indicator sizing constants.
    enum Progress {
        /// Mini progress indicator size (for device icons).
        static let miniSize: CGFloat = 28

        /// Container size for progress indicators.
        static let containerSize: CGFloat = 90

        /// Battery bar padding for progress calculation.
        static let batteryBarPadding: CGFloat = 2.6

        /// Minimum display percentage for low battery (prevents bar from being invisible).
        static let lowBatteryMinDisplay: Double = 10.0

        /// Maximum display percentage for high battery (prevents visual overflow).
        static let highBatteryMaxDisplay: Double = 98.0
    }

    /// Window constants.
    enum Window {
        /// Modal window title identifier.
        static let modalWindowTitle = "modalwindow"

        /// Default window margin from screen edges.
        static let defaultMargin: CGFloat = 40

        /// Minimum drag distance (points) before snapping to a non-start anchor.
        static let minimumDragDistance: CGFloat = 60.0
    }

    /// Bluetooth-related constants.
    enum Bluetooth {
        /// RSSI threshold for "proximate" distance (on desk/table).
        static let rssiProximateThreshold: Double = -50

        /// RSSI threshold for "near" distance (same room).
        static let rssiNearThreshold: Double = -70

        /// RSSI floor — values above this are noise/invalid.
        static let rssiMinimumThreshold: Double = -20

        /// Time interval before pruning disconnected devices from the list.
        static let staleDeviceTimeout: TimeInterval = 300

        // IORegistry service class names
        static let appleHIDServiceClass = "AppleDeviceManagementHIDEventService"
        static let hidDeviceServiceClass = "IOHIDDevice"

        // IORegistry property keys
        static let ioregBatteryPercent = "BatteryPercent"
        static let ioregDeviceAddress = "DeviceAddress"
        static let ioregProduct = "Product"
        static let ioregTransport = "Transport"

        // IOBluetoothDevice KVC keys (undocumented, stable since macOS 11+)
        static let kvcBatterySingle = "batteryPercentSingle"
        static let kvcBatteryLeft = "batteryPercentLeft"
        static let kvcBatteryRight = "batteryPercentRight"
        static let kvcBatteryCase = "batteryPercentCase"
        static let kvcBatteryCombined = "batteryPercentCombined"
        static let kvcIsMultiBattery = "isMultiBatteryDevice"
        static let kvcIsAppleDevice = "isAppleDevice"
        static let kvcVendorID = "vendorID"
        static let kvcProductID = "productID"

        /// Valid battery percentage range — 0 and >100 are sentinels for "no data".
        static let validBatteryRange = 1 ... 100
    }

    /// Keep Awake feature constants.
    enum KeepAwake {
        static let lowBatteryAutoDisable: Double = 10
        static let expiryWarningMinutes: Double = 5
        static let defaultDuration: KeepAwakeDuration = .thirtyMinutes
    }

    /// Corner radius constants for UI elements.
    enum CornerRadius {
        /// Button corner radius.
        static let button: CGFloat = 30

        /// Container corner radius.
        static let container: CGFloat = 20

        /// HUD window corner radius.
        static let hud: CGFloat = 42

        /// HUD mask circle radius (half of 120pt circle).
        static let maskCircle: CGFloat = 60

        /// HUD dismiss shrink target radius.
        static let maskDismiss: CGFloat = 20
    }
}
