//
//  AppEnvironment.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Combine
import Foundation
import SwiftUI

/// Dependency injection container holding all service references.
/// Provides centralized access to app services for SwiftUI views.
@MainActor
@Observable
final class AppEnvironment {
    // MARK: - Shared Instance

    /// Shared environment instance for production use.
    static let shared = AppEnvironment()

    // MARK: - Services

    /// Battery monitoring service
    let battery: BatteryManager

    /// Bluetooth device service
    let bluetooth: BluetoothManager

    /// Settings service
    let settings: SettingsManager

    /// Window management service
    let window: WindowManager

    /// App lifecycle manager
    let app: AppManager

    /// Statistics aggregation manager
    let stats: StatsManager

    /// Update manager
    let update: UpdateManager

    /// Event manager
    let event: EventManager

    // MARK: - Initialization

    /// Initialize with default production services.
    init() {
        self.battery = BatteryManager.shared
        self.bluetooth = BluetoothManager.shared
        self.settings = SettingsManager.shared
        self.window = WindowManager.shared
        self.app = AppManager.shared
        self.stats = StatsManager.shared
        self.update = UpdateManager.shared
        self.event = EventManager.shared
    }

    /// Initialize with custom services for testing.
    /// - Parameters:
    ///   - battery: Custom battery service
    ///   - bluetooth: Custom bluetooth service
    ///   - settings: Custom settings service
    ///   - window: Custom window service
    ///   - app: Custom app manager
    ///   - stats: Custom stats manager
    ///   - update: Custom update manager
    ///   - event: Custom event manager
    init(
        battery: BatteryManager,
        bluetooth: BluetoothManager,
        settings: SettingsManager,
        window: WindowManager,
        app: AppManager,
        stats: StatsManager,
        update: UpdateManager,
        event: EventManager
    ) {
        self.battery = battery
        self.bluetooth = bluetooth
        self.settings = settings
        self.window = window
        self.app = app
        self.stats = stats
        self.update = update
        self.event = event
    }
}

// MARK: - Environment Key

/// Environment key for accessing the app environment container.
private struct AppEnvironmentKey: EnvironmentKey {
    // Using nonisolated(unsafe) as EnvironmentKey requires a non-isolated defaultValue
    // but AppEnvironment is @MainActor. This is safe because SwiftUI views always
    // access Environment values on the main thread.
    nonisolated(unsafe) static let defaultValue: AppEnvironment = {
        // Create on main actor synchronously since app launch is on main thread
        MainActor.assumeIsolated {
            AppEnvironment.shared
        }
    }()
}

extension EnvironmentValues {
    /// Access to the app environment container for dependency injection.
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Inject the app environment into the view hierarchy.
    /// - Parameter environment: The environment to inject (defaults to shared)
    /// - Returns: The modified view with environment injected
    @MainActor
    func withAppEnvironment(_ environment: AppEnvironment = .shared) -> some View {
        self.environment(\.appEnvironment, environment)
    }
}
