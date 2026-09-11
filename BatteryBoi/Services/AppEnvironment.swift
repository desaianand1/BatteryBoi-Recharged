//
//  AppEnvironment.swift
//  BatteryBoi
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class AppEnvironment {

    // MARK: - Shared Instance

    static let shared = AppEnvironment()

    // MARK: - Coordinator

    let coordinator: ServiceCoordinator

    // MARK: - Services (Protocol Types for Testability)

    let battery: any BatteryServiceProtocol
    let bluetooth: any BluetoothServiceProtocol
    let settings: any SettingsServiceProtocol
    let window: any WindowServiceProtocol
    let stats: any StatsServiceProtocol
    let event: any EventServiceProtocol

    // MARK: - Concrete-Typed (No Protocol Yet)

    let app: AppManager
    let update: UpdateManager
    let onboarding: OnboardingService

    // MARK: - Production Init

    init() {
        self.battery = BatteryService.shared
        self.bluetooth = BluetoothService.shared
        self.settings = SettingsService.shared
        self.window = WindowService.shared
        self.stats = StatsService.shared
        self.app = AppManager.shared
        self.update = UpdateManager.shared
        self.event = EventService.shared
        self.onboarding = OnboardingService.shared
        self.coordinator = ServiceCoordinator(
            battery: BatteryService.shared,
            bluetooth: BluetoothService.shared,
            settings: SettingsService.shared,
            window: WindowService.shared,
            events: EventService.shared
        )
    }

    // MARK: - Testing Init

    init(
        battery: any BatteryServiceProtocol,
        bluetooth: any BluetoothServiceProtocol,
        settings: any SettingsServiceProtocol,
        window: any WindowServiceProtocol,
        stats: any StatsServiceProtocol,
        event: any EventServiceProtocol,
        app: AppManager,
        update: UpdateManager,
        onboarding: OnboardingService = .shared,
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
        self.coordinator = coordinator ?? ServiceCoordinator(
            battery: battery,
            bluetooth: bluetooth,
            settings: settings,
            window: window,
            events: event
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
