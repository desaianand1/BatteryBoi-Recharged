//
//  AppEnvironmentTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class AppEnvironmentTests: XCTestCase {

    // MARK: - Testing Init Tests

    @MainActor
    func testTestingInitAcceptsMocks() {
        let mockBattery = MockBatteryService()
        let mockBluetooth = MockBluetoothService()
        let mockSettings = MockSettingsService()
        let mockWindow = MockWindowService()
        let mockStats = MockStatsService()
        let mockEvents = MockEventService()
        let mockApp = MockAppManager()
        let mockUpdate = MockUpdateManager()

        let env = AppEnvironment(
            battery: mockBattery,
            bluetooth: mockBluetooth,
            settings: mockSettings,
            window: mockWindow,
            stats: mockStats,
            event: mockEvents,
            app: mockApp,
            update: mockUpdate
        )

        XCTAssertTrue(env.battery is MockBatteryService)
        XCTAssertTrue(env.bluetooth is MockBluetoothService)
        XCTAssertTrue(env.settings is MockSettingsService)
        XCTAssertTrue(env.window is MockWindowService)
        XCTAssertTrue(env.stats is MockStatsService)
        XCTAssertTrue(env.event is MockEventService)
        XCTAssertTrue(env.app is MockAppManager)
        XCTAssertTrue(env.update is MockUpdateManager)
    }

    // MARK: - Start Tests

    @MainActor
    func testStartSetsMenuToSettingsWhenNoDevices() {
        let mockBluetooth = MockBluetoothService()
        mockBluetooth.connected = []

        let env = AppEnvironment(
            battery: MockBatteryService(),
            bluetooth: mockBluetooth,
            settings: MockSettingsService(),
            window: MockWindowService(),
            stats: MockStatsService(),
            event: MockEventService(),
            app: MockAppManager(),
            update: MockUpdateManager()
        )

        env.start()

        XCTAssertEqual(env.app.menu, .settings)
    }

    // MARK: - Ownership Tests

    @MainActor
    func testEnvironmentDeallocatesWhenUnreferenced() async {
        weak var weakEnv: AppEnvironment?

        do {
            let env = makeTestEnvironment()
            weakEnv = env
            XCTAssertNotNil(weakEnv)
        }

        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(weakEnv, "AppEnvironment should deallocate when no strong references remain")
    }

    @MainActor
    func testEnvironmentAcceptsMockOnboarding() {
        let mockOnboarding = MockOnboardingService()
        let env = makeTestEnvironment(onboarding: mockOnboarding)

        XCTAssertTrue(env.onboarding is MockOnboardingService)
    }

    // MARK: - Start Tests (Devices)

    @MainActor
    func testStartSetsMenuToDevicesWhenDevicesConnected() {
        let mockBluetooth = MockBluetoothService()
        mockBluetooth.connected = [BluetoothObject.testDevice()]

        let env = AppEnvironment(
            battery: MockBatteryService(),
            bluetooth: mockBluetooth,
            settings: MockSettingsService(),
            window: MockWindowService(),
            stats: MockStatsService(),
            event: MockEventService(),
            app: MockAppManager(),
            update: MockUpdateManager()
        )

        env.start()

        XCTAssertEqual(env.app.menu, .devices)
    }
}
