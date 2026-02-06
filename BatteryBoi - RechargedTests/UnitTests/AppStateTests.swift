//
//  AppStateTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for AppState centralized state container.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class AppStateTests: XCTestCase {

    // MARK: - Properties

    /// State (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var state: AppState!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let s = MainActor.assumeIsolated {
            AppState()
        }
        state = s
    }

    override nonisolated func tearDown() {
        state = nil
        super.tearDown()
    }

    // MARK: - Battery State Tests

    @MainActor
    func testBatteryPercentageDefault() {
        // Given a new AppState
        // Then battery percentage should default to 100
        XCTAssertEqual(state.batteryPercentage, 100)
    }

    @MainActor
    func testBatteryPercentageUpdate() {
        // Given a new AppState
        // When percentage is updated
        state.batteryPercentage = 42.5

        // Then it should reflect the new value
        XCTAssertEqual(state.batteryPercentage, 42.5)
    }

    @MainActor
    func testBatteryChargingDefault() {
        // Given a new AppState
        // Then charging state should default to battery
        XCTAssertEqual(state.batteryCharging.state, .battery)
    }

    @MainActor
    func testBatteryThermalDefault() {
        // Given a new AppState
        // Then thermal state should default to optimal
        XCTAssertEqual(state.batteryThermal, .optimal)
    }

    @MainActor
    func testBatterySaverDefault() {
        // Given a new AppState
        // Then saver mode should default to unavailable
        XCTAssertEqual(state.batterySaver, .unavailable)
    }

    @MainActor
    func testBatteryTimeRemainingDefault() {
        // Given a new AppState
        // Then time remaining should be nil
        XCTAssertNil(state.batteryTimeRemaining)
    }

    @MainActor
    func testBatteryMetricsDefault() {
        // Given a new AppState
        // Then metrics should be nil
        XCTAssertNil(state.batteryMetrics)
    }

    // MARK: - Computed Property Tests

    @MainActor
    func testIsChargingWhenBattery() {
        // Given battery power state
        state.batteryCharging = BatteryCharging(.battery)

        // Then isCharging should be false
        XCTAssertFalse(state.isCharging)
    }

    @MainActor
    func testIsChargingWhenCharging() {
        // Given charging state
        state.batteryCharging = BatteryCharging(.charging)

        // Then isCharging should be true
        XCTAssertTrue(state.isCharging)
    }

    // MARK: - Bluetooth State Tests

    @MainActor
    func testBluetoothDevicesDefault() {
        // Given a new AppState
        // Then Bluetooth devices should be empty
        XCTAssertTrue(state.bluetoothDevices.isEmpty)
    }

    @MainActor
    func testBluetoothConnectedDefault() {
        // Given a new AppState
        // Then connected devices should be empty
        XCTAssertTrue(state.bluetoothConnected.isEmpty)
    }

    @MainActor
    func testBluetoothIconsDefault() {
        // Given a new AppState
        // Then icons should be empty
        XCTAssertTrue(state.bluetoothIcons.isEmpty)
    }

    @MainActor
    func testHasConnectedDevicesWhenEmpty() {
        // Given no connected devices
        state.bluetoothConnected = []

        // Then hasConnectedDevices should be false
        XCTAssertFalse(state.hasConnectedDevices)
    }

    @MainActor
    func testHasConnectedDevicesWhenNotEmpty() {
        // Given connected devices
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Test Device",
            batteryPercent: 50
        )
        state.bluetoothConnected = [device]

        // Then hasConnectedDevices should be true
        XCTAssertTrue(state.hasConnectedDevices)
    }

    // MARK: - HUD State Tests

    @MainActor
    func testHUDStateDefault() {
        // Given a new AppState
        // Then HUD state should be hidden
        XCTAssertEqual(state.hudState, .hidden)
    }

    @MainActor
    func testIsHUDVisibleWhenHidden() {
        // Given hidden HUD
        state.hudState = .hidden

        // Then isHUDVisible should be false
        XCTAssertFalse(state.isHUDVisible)
    }

    @MainActor
    func testIsHUDVisibleWhenRevealed() {
        // Given revealed HUD
        state.hudState = .revealed

        // Then isHUDVisible should be true
        XCTAssertTrue(state.isHUDVisible)
    }

    @MainActor
    func testIsHUDVisibleWhenProgress() {
        // Given progress HUD
        state.hudState = .progress

        // Then isHUDVisible should be true
        XCTAssertTrue(state.isHUDVisible)
    }

    @MainActor
    func testIsHUDVisibleWhenDetailed() {
        // Given detailed HUD
        state.hudState = .detailed

        // Then isHUDVisible should be true
        XCTAssertTrue(state.isHUDVisible)
    }

    @MainActor
    func testCurrentAlertDefault() {
        // Given a new AppState
        // Then current alert should be nil
        XCTAssertNil(state.currentAlert)
    }

    // MARK: - Window State Tests

    @MainActor
    func testWindowPositionDefault() {
        // Given a new AppState
        // Then window position should be topMiddle
        XCTAssertEqual(state.windowPosition, .topMiddle)
    }

    @MainActor
    func testWindowOpacityDefault() {
        // Given a new AppState
        // Then window opacity should be 1.0
        XCTAssertEqual(state.windowOpacity, 1.0)
    }

    @MainActor
    func testWindowHoverDefault() {
        // Given a new AppState
        // Then window hover should be false
        XCTAssertFalse(state.windowHover)
    }

    // MARK: - Navigation State Tests

    @MainActor
    func testCurrentMenuDefault() {
        // Given a new AppState
        // Then current menu should be devices
        XCTAssertEqual(state.currentMenu, .devices)
    }

    @MainActor
    func testCurrentMenuUpdate() {
        // Given a new AppState
        // When menu is changed to settings
        state.currentMenu = .settings

        // Then it should reflect the change
        XCTAssertEqual(state.currentMenu, .settings)
    }

    // MARK: - Display State Tests

    @MainActor
    func testDisplayTextDefault() {
        // Given a new AppState
        // Then display text should be nil
        XCTAssertNil(state.displayText)
    }

    @MainActor
    func testOverlayTextDefault() {
        // Given a new AppState
        // Then overlay text should be nil
        XCTAssertNil(state.overlayText)
    }

    @MainActor
    func testHUDTitleDefault() {
        // Given a new AppState
        // Then HUD title should be empty
        XCTAssertEqual(state.hudTitle, "")
    }

    @MainActor
    func testHUDSubtitleDefault() {
        // Given a new AppState
        // Then HUD subtitle should be empty
        XCTAssertEqual(state.hudSubtitle, "")
    }

    // MARK: - Event State Tests

    @MainActor
    func testEventsDefault() {
        // Given a new AppState
        // Then events should be empty
        XCTAssertTrue(state.events.isEmpty)
    }

    // MARK: - Selected Device Tests

    @MainActor
    func testSelectedDeviceDefault() {
        // Given a new AppState
        // Then selected device should be nil
        XCTAssertNil(state.selectedDevice)
    }

    @MainActor
    func testSelectedDeviceUpdate() {
        // Given a new AppState
        let device = BluetoothObject.testDevice(
            address: "11:22:33:44:55:66",
            name: "Selected Device",
            batteryPercent: 75
        )

        // When device is selected
        state.selectedDevice = device

        // Then it should reflect the selection
        XCTAssertEqual(state.selectedDevice?.address, "11-22-33-44-55-66")
        XCTAssertEqual(state.selectedDevice?.device, "Selected Device")
    }
}
