//
//  TestHelpers.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
import Foundation
@preconcurrency import XCTest

#if DEBUG

    // MARK: - Test Environment Factory

    @MainActor
    func makeTestEnvironment(
        battery: MockBatteryService = MockBatteryService(),
        bluetooth: MockBluetoothService = MockBluetoothService(),
        settings: MockSettingsService = MockSettingsService(),
        window: MockWindowService = MockWindowService(),
        stats: MockStatsService = MockStatsService(),
        events: MockEventService = MockEventService(),
        app: MockAppManager = MockAppManager(),
        update: MockUpdateManager = MockUpdateManager(),
        onboarding: MockOnboardingService = MockOnboardingService()
    ) -> AppEnvironment {
        AppEnvironment(
            battery: battery,
            bluetooth: bluetooth,
            settings: settings,
            window: window,
            stats: stats,
            event: events,
            app: app,
            update: update,
            onboarding: onboarding
        )
    }

    // MARK: - BluetoothObject Test Helpers

    extension BluetoothObject {
        @MainActor
        static func testDevice(
            address: String = "AA:BB:CC:DD:EE:FF",
            name: String = "Test Device",
            isConnected: Bool = true,
            batteryPercent: Int? = 75,
            type: BluetoothDeviceType = .headphones,
            batteryLeft: Int? = nil,
            batteryRight: Int? = nil,
            batteryCase: Int? = nil,
            vendorID: Int? = nil,
            productID: Int? = nil
        ) -> BluetoothObject {
            BluetoothObject(
                address: address,
                name: name,
                isConnected: isConnected,
                batteryPercent: batteryPercent,
                deviceType: type.rawValue,
                batteryLeft: batteryLeft,
                batteryRight: batteryRight,
                batteryCase: batteryCase,
                vendorID: vendorID,
                productID: productID
            )
        }
    }

    // MARK: - BluetoothDeviceType Aliases for common types

    extension BluetoothDeviceType {
        static let airpodsPro: BluetoothDeviceType = .headphones
        static let airpods: BluetoothDeviceType = .headphones
    }

    // MARK: - BluetoothBatteryObject Test Helpers

    @MainActor
    func makeTestBattery(
        general: Double?,
        left: Double?,
        right: Double?,
        chargingCase: Double? = nil
    ) -> BluetoothBatteryObject {
        var battery = BluetoothBatteryObject(
            single: general.map { Int($0) },
            left: left.map { Int($0) },
            right: right.map { Int($0) },
            chargingCase: chargingCase.map { Int($0) }
        )

        if left == nil, right == nil, general == nil {
            battery.percent = nil
        } else if let min = [right, left, general].compactMap(\.self).min() {
            battery.percent = min
        }

        return battery
    }

    extension BluetoothBatteryObject {
        @MainActor
        init(percent: Double) {
            self.init(percent: Int(percent))
        }

        @MainActor
        init(percent: Double, left: Double, right: Double) {
            self = makeTestBattery(general: percent, left: left, right: right)
        }
    }

#endif
