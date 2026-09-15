//
//  PowerSaveIntegrationTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class PowerSaveIntegrationTests: XCTestCase {

    nonisolated(unsafe) var mockBattery: MockBatteryService!
    nonisolated(unsafe) var settingsService: SettingsService!

    override nonisolated func setUp() {
        super.setUp()
        let (battery, settings) = MainActor.assumeIsolated {
            let battery = MockBatteryService()
            let settings = SettingsService(
                window: { MockWindowService() },
                battery: battery,
                update: MockUpdateManager()
            )
            return (battery, settings)
        }
        mockBattery = battery
        settingsService = settings
    }

    override nonisolated func tearDown() {
        settingsService = nil
        mockBattery = nil
        super.tearDown()
    }

    // MARK: - Getter Tests

    @MainActor
    func testPowerSaveTrueWhenBatteryIsEfficient() {
        mockBattery.saver = .efficient

        XCTAssertTrue(settingsService.enabledPowerSave)
    }

    @MainActor
    func testPowerSaveFalseWhenBatteryIsNormal() {
        mockBattery.saver = .normal

        XCTAssertFalse(settingsService.enabledPowerSave)
    }

    @MainActor
    func testPowerSaveFalseWhenBatteryIsUnavailable() {
        mockBattery.saver = .unavailable

        XCTAssertFalse(settingsService.enabledPowerSave)
    }

    // MARK: - Setter Guard Tests

    @MainActor
    func testEnablingPowerSaveWhenNormalTogglesOnce() {
        mockBattery.saver = .normal

        settingsService.enabledPowerSave = true

        XCTAssertEqual(mockBattery.togglePowerSaveModeCallCount, 1)
    }

    @MainActor
    func testEnablingPowerSaveWhenAlreadyEfficientIsNoOp() {
        mockBattery.saver = .efficient

        settingsService.enabledPowerSave = true

        XCTAssertEqual(mockBattery.togglePowerSaveModeCallCount, 0)
    }

    @MainActor
    func testDisablingPowerSaveWhenEfficientTogglesOnce() {
        mockBattery.saver = .efficient

        settingsService.enabledPowerSave = false

        XCTAssertEqual(mockBattery.togglePowerSaveModeCallCount, 1)
    }

    @MainActor
    func testDisablingPowerSaveWhenAlreadyNormalIsNoOp() {
        mockBattery.saver = .normal

        settingsService.enabledPowerSave = false

        XCTAssertEqual(mockBattery.togglePowerSaveModeCallCount, 0)
    }
}
