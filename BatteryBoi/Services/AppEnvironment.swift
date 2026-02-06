//
//  AppEnvironment.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//  Updated for Swift 6.2 ServiceContainer architecture.
//

import Foundation
import SwiftUI

/// Dependency injection container holding all service references.
/// Provides centralized access to app services for SwiftUI views.
/// Services are accessed via protocol types to enable testability.
///
/// Note: This class uses the new service architecture.
/// Old managers are kept for backward compatibility during migration.
@MainActor
@Observable
final class AppEnvironment {
    // MARK: - Shared Instance

    /// Shared environment instance for production use.
    static let shared = AppEnvironment()

    // MARK: - Services (Protocol Types for Testability)

    /// Battery monitoring service
    let battery: any BatteryServiceProtocol

    /// Bluetooth device service
    let bluetooth: any BluetoothServiceProtocol

    /// Settings service
    let settings: any SettingsServiceProtocol

    /// Window management service
    let window: any WindowServiceProtocol

    /// App lifecycle manager
    let app: AppManager

    /// Statistics aggregation service
    let stats: StatsService

    /// Update manager
    let update: UpdateManager

    /// Event service
    let event: EventService

    // MARK: - Initialization

    /// Initialize with default production services.
    init() {
        // Use new services for migrated components
        battery = BatteryService.shared
        bluetooth = BluetoothService.shared
        settings = SettingsService.shared
        window = WindowService.shared
        stats = StatsService.shared

        // Keep these as managers until services exist
        app = AppManager.shared
        update = UpdateManager.shared
        event = EventService.shared
    }

    /// Initialize with custom services for testing.
    /// - Parameters:
    ///   - battery: Custom battery service
    ///   - bluetooth: Custom bluetooth service
    ///   - settings: Custom settings service
    ///   - window: Custom window service
    ///   - app: Custom app manager
    ///   - stats: Custom stats service
    ///   - update: Custom update manager
    ///   - event: Custom event service
    init(
        battery: any BatteryServiceProtocol,
        bluetooth: any BluetoothServiceProtocol,
        settings: any SettingsServiceProtocol,
        window: any WindowServiceProtocol,
        app: AppManager,
        stats: StatsService,
        update: UpdateManager,
        event: EventService
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

extension EnvironmentValues {
    /// Access to the app environment container for dependency injection.
    @Entry var appEnvironment: AppEnvironment = // Create on main actor synchronously since app launch is on main thread
        MainActor.assumeIsolated {
            AppEnvironment.shared
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
