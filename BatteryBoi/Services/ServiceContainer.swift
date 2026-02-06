//
//  ServiceContainer.swift
//  BatteryBoi
//
//  Central dependency injection container for all services.
//  Part of Swift 6.2 architecture redesign.
//

import Foundation
import SwiftUI

/// Central dependency injection container holding all service instances.
/// Provides centralized access to services and state for SwiftUI views.
@Observable
@MainActor
final class ServiceContainer {
    // MARK: - Shared Instance

    /// Shared container instance for production use
    static let shared = ServiceContainer()

    // MARK: - State

    /// Centralized observable state for all UI components
    let state: AppState

    /// Service coordinator handling cross-service communication
    let coordinator: ServiceCoordinator

    // MARK: - Services (using new services)

    /// Battery monitoring service
    var battery: BatteryService {
        BatteryService.shared
    }

    /// Bluetooth device service
    var bluetooth: BluetoothService {
        BluetoothService.shared
    }

    /// Settings service
    var settings: SettingsService {
        SettingsService.shared
    }

    /// Window management service
    var window: WindowService {
        WindowService.shared
    }

    /// Statistics service
    var stats: StatsService {
        StatsService.shared
    }

    /// Event service
    var events: EventService {
        EventService.shared
    }

    /// App lifecycle manager (keep as manager for now)
    var app: AppManager {
        AppManager.shared
    }

    /// Update manager (keep as manager for now)
    var update: UpdateManager {
        UpdateManager.shared
    }

    // MARK: - Initialization

    /// Initialize with default production services
    private init() {
        state = AppState()
        coordinator = ServiceCoordinator()
    }

    /// Initialize with custom state for testing
    init(state: AppState, coordinator: ServiceCoordinator) {
        self.state = state
        self.coordinator = coordinator
    }

    // MARK: - Lifecycle

    /// Start all services and begin observation
    func start() async {
        // Initialize coordinator with container reference
        coordinator.container = self

        // Start observing service changes
        await coordinator.startObserving()

        // Sync initial state
        syncState()
    }

    /// Sync current service state to AppState
    private func syncState() {
        state.batteryPercentage = battery.percentage
        state.batteryCharging = battery.charging
        state.batteryTimeRemaining = battery.remaining
        state.batterySaver = battery.saver
        state.batteryMetrics = battery.metrics
        state.batteryThermal = battery.thermal

        state.bluetoothDevices = bluetooth.list
        state.bluetoothConnected = bluetooth.connected
        state.bluetoothIcons = bluetooth.icons

        state.currentMenu = app.menu

        state.hudState = window.state
        state.windowPosition = window.position
        state.windowOpacity = window.opacity
        state.windowHover = window.hover

        state.events = events.events
    }
}

// MARK: - SwiftUI Environment

extension EnvironmentValues {
    /// Access to the service container for dependency injection
    @Entry var serviceContainer: ServiceContainer = MainActor.assumeIsolated {
        ServiceContainer.shared
    }
}

extension View {
    /// Inject the service container into the view hierarchy
    @MainActor
    func withServiceContainer(_ container: ServiceContainer = .shared) -> some View {
        environment(\.serviceContainer, container)
    }
}
