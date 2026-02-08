//
//  MockAppManager.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock app manager for unit testing.
    @MainActor
    final class MockAppManager: AppManagerProtocol {
        // MARK: - Observable Properties

        var counter: Int
        var device: BluetoothObject?
        var alert: HUDAlertTypes?
        var menu: SystemMenuView
        var appDeviceType: SystemDeviceTypes
        var appInstalled: Date
        var appIdentifyer: String

        // MARK: - Test Helpers

        var appToggleMenuCallCount = 0
        var lastToggleAnimated: Bool?
        var appDistributionCallCount = 0
        var mockDistribution: SystemDistribution = .direct

        // MARK: - Initialization

        init(
            counter: Int = 0,
            device: BluetoothObject? = nil,
            alert: HUDAlertTypes? = nil,
            menu: SystemMenuView = .devices,
            appDeviceType: SystemDeviceTypes = .macbookPro,
            appInstalled: Date = Date(),
            appIdentifyer: String = "TEST-\(UUID().uuidString)"
        ) {
            self.counter = counter
            self.device = device
            self.alert = alert
            self.menu = menu
            self.appDeviceType = appDeviceType
            self.appInstalled = appInstalled
            self.appIdentifyer = appIdentifyer
        }

        // MARK: - Methods

        func appToggleMenu(_ animate: Bool) {
            appToggleMenuCallCount += 1
            lastToggleAnimated = animate
            switch menu {
            case .devices: menu = .settings
            default: menu = .devices
            }
        }

        func appTimerAsync(_ intervalSeconds: Int) -> AsyncStream<Int> {
            AsyncStream { continuation in
                Task { [weak self] in
                    var current = 0
                    while !Task.isCancelled {
                        guard self != nil else {
                            continuation.finish()
                            return
                        }
                        if current % intervalSeconds == 0 {
                            continuation.yield(current)
                        }
                        current += 1
                        try? await Task.sleep(for: .seconds(1))
                    }
                    continuation.finish()
                }
            }
        }

        func appDistribution() async -> SystemDistribution {
            appDistributionCallCount += 1
            return mockDistribution
        }

        // MARK: - Test Simulation

        func simulateCounterAdvance(_ seconds: Int) {
            counter += seconds
        }

        func simulateAlertChange(_ newAlert: HUDAlertTypes?) {
            alert = newAlert
        }

        func simulateDeviceChange(_ newDevice: BluetoothObject?) {
            device = newDevice
        }
    }

#endif
