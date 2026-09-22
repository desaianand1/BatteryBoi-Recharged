//
//  AppEnvironment.swift
//  BatteryBoi
//

import Foundation
import SwiftUI

@Observable @MainActor
final class AppEnvironment {

    // MARK: - Coordinator

    let coordinator: ServiceCoordinator

    // MARK: - Services (Protocol Types for Testability)

    let battery: any BatteryServiceProtocol
    let bluetooth: any BluetoothServiceProtocol
    let settings: any SettingsServiceProtocol
    let window: any WindowServiceProtocol
    let stats: any StatsServiceProtocol
    let event: any EventServiceProtocol

    let onboarding: any OnboardingServiceProtocol
    let keepAwake: any KeepAwakeServiceProtocol

    // MARK: - Services (Protocol Types)

    let app: any AppManagerProtocol
    let update: any UpdateManagerProtocol

    // MARK: - Production Init

    private final class Ref {
        unowned var env: AppEnvironment!
    }

    init() {
        let ref = Ref()

        let battery = BatteryService()
        let bluetooth = BluetoothService()
        let event = EventService()
        let app = AppManager()
        let update = UpdateManager()
        let onboarding = OnboardingService()
        let keepAwake = KeepAwakeService()

        let settings = SettingsService(
            window: { ref.env.window },
            battery: battery,
            update: update
        )

        let window = WindowService(
            settings: settings,
            environment: { ref.env }
        )

        let stats = StatsService(
            battery: battery,
            bluetooth: bluetooth,
            settings: settings,
            window: window,
            events: event,
            app: app
        )

        let coordinator = ServiceCoordinator(
            battery: battery,
            bluetooth: bluetooth,
            settings: settings,
            window: window,
            events: event,
            keepAwake: keepAwake
        )

        self.battery = battery
        self.bluetooth = bluetooth
        self.settings = settings
        self.window = window
        self.stats = stats
        self.event = event
        self.app = app
        self.update = update
        self.onboarding = onboarding
        self.keepAwake = keepAwake
        self.coordinator = coordinator

        ref.env = self
    }

    // MARK: - Testing Init

    init(
        battery: any BatteryServiceProtocol,
        bluetooth: any BluetoothServiceProtocol,
        settings: any SettingsServiceProtocol,
        window: any WindowServiceProtocol,
        stats: any StatsServiceProtocol,
        event: any EventServiceProtocol,
        app: any AppManagerProtocol,
        update: any UpdateManagerProtocol,
        onboarding: any OnboardingServiceProtocol = OnboardingService(),
        keepAwake: any KeepAwakeServiceProtocol = KeepAwakeService(),
        coordinator: ServiceCoordinator? = nil
    ) {
        self.battery = battery
        self.bluetooth = bluetooth
        self.settings = settings
        self.window = window
        self.stats = stats
        self.event = event
        self.app = app
        self.update = update
        self.onboarding = onboarding
        self.keepAwake = keepAwake
        self.coordinator = coordinator ?? ServiceCoordinator(
            battery: battery,
            bluetooth: bluetooth,
            settings: settings,
            window: window,
            events: event,
            keepAwake: keepAwake
        )
    }

    // MARK: - Lifecycle

    func start() {
        if bluetooth.connected.isEmpty {
            app.menu = .settings
        } else {
            app.menu = .devices
        }
        coordinator.startObserving()
    }
}
