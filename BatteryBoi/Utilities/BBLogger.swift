import Logging

/// Centralized logging configuration using swift-log.
/// Provides structured logging for all app subsystems.
enum BBLogger {
    static let battery = Logger(label: "com.nirnshard.batteryboirecharged.battery")
    static let bluetooth = Logger(label: "com.nirnshard.batteryboirecharged.bluetooth")
    static let stats = Logger(label: "com.nirnshard.batteryboirecharged.stats")
    static let events = Logger(label: "com.nirnshard.batteryboirecharged.events")
    static let app = Logger(label: "com.nirnshard.batteryboirecharged.app")
    static let window = Logger(label: "com.nirnshard.batteryboirecharged.window")
    static let settings = Logger(label: "com.nirnshard.batteryboirecharged.settings")
}
