import Logging

/// Centralized logging configuration using swift-log.
/// Provides structured logging for all app subsystems.
/// Logger is thread-safe and can be accessed from any isolation context.
/// Note: nonisolated(unsafe) is justified here because Logger is thread-safe
/// and we need these to be accessible from nonisolated contexts (like IOKit callbacks).
enum BLogger: Sendable {
    nonisolated(unsafe) static let battery = Logger(label: "com.nirnshard.batteryboirecharged.battery")
    nonisolated(unsafe) static let bluetooth = Logger(label: "com.nirnshard.batteryboirecharged.bluetooth")
    nonisolated(unsafe) static let stats = Logger(label: "com.nirnshard.batteryboirecharged.stats")
    nonisolated(unsafe) static let events = Logger(label: "com.nirnshard.batteryboirecharged.events")
    nonisolated(unsafe) static let app = Logger(label: "com.nirnshard.batteryboirecharged.app")
    nonisolated(unsafe) static let window = Logger(label: "com.nirnshard.batteryboirecharged.window")
    nonisolated(unsafe) static let settings = Logger(label: "com.nirnshard.batteryboirecharged.settings")
}
