//
//  AppEnvironmentTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

/// AppEnvironment is @Observable @MainActor — its synthesized deinit triggers
/// the StopLookupScope heap corruption crash via swift_task_deinitOnExecutorMainActorBackDeploy
/// when deployment target < macOS 15.4. Async tests with scoped `do` blocks let the runtime
/// marshal deallocation correctly. See ServiceCoordinator's nonisolated(unsafe) comment.
final class AppEnvironmentTests: XCTestCase {

    // MARK: - Testing Init Tests

    @MainActor
    func testTestingInitAcceptsMocks() async {
        do {
            let env = makeTestEnvironment()

            XCTAssertTrue(env.battery is MockBatteryService)
            XCTAssertTrue(env.bluetooth is MockBluetoothService)
            XCTAssertTrue(env.settings is MockSettingsService)
            XCTAssertTrue(env.window is MockWindowService)
            XCTAssertTrue(env.stats is MockStatsService)
            XCTAssertTrue(env.event is MockEventService)
            XCTAssertTrue(env.app is MockAppManager)
            XCTAssertTrue(env.update is MockUpdateManager)
            XCTAssertTrue(env.keepAwake is MockKeepAwakeService)
        }
        await Task.yield()
    }

    // MARK: - Start Tests

    @MainActor
    func testStartSetsMenuToSettingsWhenNoDevices() async {
        do {
            let mockBluetooth = MockBluetoothService()
            mockBluetooth.connected = []

            let env = makeTestEnvironment(bluetooth: mockBluetooth)

            env.start()

            XCTAssertEqual(env.app.menu, .settings)
        }
        await Task.yield()
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
    func testEnvironmentAcceptsMockOnboarding() async {
        do {
            let mockOnboarding = MockOnboardingService()
            let env = makeTestEnvironment(onboarding: mockOnboarding)

            XCTAssertTrue(env.onboarding is MockOnboardingService)
        }
        await Task.yield()
    }

    // MARK: - Start Tests (Devices)

    @MainActor
    func testStartSetsMenuToDevicesWhenDevicesConnected() async {
        do {
            let mockBluetooth = MockBluetoothService()
            mockBluetooth.connected = [BluetoothObject.testDevice()]

            let env = makeTestEnvironment(bluetooth: mockBluetooth)

            env.start()

            XCTAssertEqual(env.app.menu, .devices)
        }
        await Task.yield()
    }
}
