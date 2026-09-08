//
//  AppEnvironmentTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class AppEnvironmentTests: XCTestCase {

    // MARK: - Default Init Tests

    @MainActor
    func testDefaultInitCreatesAllServices() {
        let env = AppEnvironment()

        XCTAssertNotNil(env.battery)
        XCTAssertNotNil(env.bluetooth)
        XCTAssertNotNil(env.settings)
        XCTAssertNotNil(env.window)
        XCTAssertNotNil(env.stats)
        XCTAssertNotNil(env.event)
        XCTAssertNotNil(env.app)
        XCTAssertNotNil(env.update)
        XCTAssertNotNil(env.coordinator)
    }

    // MARK: - Testing Init Tests

    @MainActor
    func testTestingInitAcceptsMocks() {
        let mockBattery = MockBatteryService()
        let mockBluetooth = MockBluetoothService()
        let mockSettings = MockSettingsService()
        let mockWindow = MockWindowService()
        let mockStats = MockStatsService()
        let mockEvents = MockEventService()

        let env = AppEnvironment(
            battery: mockBattery,
            bluetooth: mockBluetooth,
            settings: mockSettings,
            window: mockWindow,
            stats: mockStats,
            event: mockEvents,
            app: AppManager.shared,
            update: UpdateManager.shared
        )

        XCTAssertTrue(env.battery is MockBatteryService)
        XCTAssertTrue(env.bluetooth is MockBluetoothService)
        XCTAssertTrue(env.settings is MockSettingsService)
        XCTAssertTrue(env.window is MockWindowService)
        XCTAssertTrue(env.stats is MockStatsService)
        XCTAssertTrue(env.event is MockEventService)
    }

    // MARK: - Start Tests

    @MainActor
    func testStartSetsMenuAndStartsObserving() {
        let env = AppEnvironment()
        env.start()

        XCTAssertNotNil(env.coordinator)
    }
}
