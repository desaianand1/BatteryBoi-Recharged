//
//  ServiceCoordinatorTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for ServiceCoordinator alert and state logic.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class ServiceCoordinatorTests: XCTestCase {

    // MARK: - Properties

    /// Properties (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var coordinator: ServiceCoordinator!
    nonisolated(unsafe) var state: AppState!
    nonisolated(unsafe) var container: ServiceContainer!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let (s, c, cont) = MainActor.assumeIsolated {
            let s = AppState()
            let c = ServiceCoordinator()
            let cont = ServiceContainer(state: s, coordinator: c)
            c.container = cont
            return (s, c, cont)
        }
        state = s
        coordinator = c
        container = cont
    }

    override nonisolated func tearDown() {
        let coord = coordinator
        MainActor.assumeIsolated {
            coord?.stopObserving()
        }
        coordinator = nil
        state = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Battery Percentage Threshold Tests

    @MainActor
    func testBatteryPercentageInitialState() {
        // Given a new coordinator
        // Then state should have default values
        XCTAssertEqual(state.batteryPercentage, 100)
        XCTAssertEqual(state.batteryThermal, .optimal)
    }

    @MainActor
    func testBatteryStateSync() {
        // Given a state with updated values
        state.batteryPercentage = 50.0

        // Then the state should reflect the change
        XCTAssertEqual(state.batteryPercentage, 50.0)
    }

    // MARK: - Thermal State Tests

    @MainActor
    func testThermalStateOptimal() {
        // Given optimal thermal conditions
        state.batteryThermal = .optimal

        // Then thermal state should be optimal
        XCTAssertEqual(state.batteryThermal, .optimal)
    }

    @MainActor
    func testThermalStateSuboptimal() {
        // Given suboptimal thermal conditions
        state.batteryThermal = .suboptimal

        // Then thermal state should be suboptimal
        XCTAssertEqual(state.batteryThermal, .suboptimal)
    }

    // MARK: - Bluetooth State Tests

    @MainActor
    func testBluetoothDevicesEmpty() {
        // Given no Bluetooth devices
        // Then the list should be empty
        XCTAssertTrue(state.bluetoothDevices.isEmpty)
        XCTAssertTrue(state.bluetoothConnected.isEmpty)
        XCTAssertFalse(state.hasConnectedDevices)
    }

    @MainActor
    func testBluetoothDevicesConnected() {
        // Given connected devices
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Test AirPods",
            batteryPercent: 80
        )
        state.bluetoothDevices = [device]
        state.bluetoothConnected = [device]

        // Then hasConnectedDevices should be true
        XCTAssertTrue(state.hasConnectedDevices)
        XCTAssertEqual(state.bluetoothConnected.count, 1)
    }

    // MARK: - Charging State Tests

    @MainActor
    func testChargingStateProperty() {
        // Given battery power
        state.batteryCharging = BatteryCharging(.battery)

        // Then isCharging should be false
        XCTAssertFalse(state.isCharging)

        // When charging begins
        state.batteryCharging = BatteryCharging(.charging)

        // Then isCharging should be true
        XCTAssertTrue(state.isCharging)
    }

    // MARK: - HUD State Tests

    @MainActor
    func testHUDStateHidden() {
        // Given hidden HUD
        state.hudState = .hidden

        // Then isHUDVisible should be false
        XCTAssertFalse(state.isHUDVisible)
    }

    @MainActor
    func testHUDStateRevealed() {
        // Given revealed HUD
        state.hudState = .revealed

        // Then isHUDVisible should be true
        XCTAssertTrue(state.isHUDVisible)
    }

    // MARK: - Navigation State Tests

    @MainActor
    func testCurrentMenuDefault() {
        // Given default state
        // Then current menu should be devices
        XCTAssertEqual(state.currentMenu, .devices)
    }

    @MainActor
    func testCurrentMenuNavigation() {
        // Given default state
        state.currentMenu = .settings

        // Then current menu should be settings
        XCTAssertEqual(state.currentMenu, .settings)
    }

    // MARK: - Window State Tests

    @MainActor
    func testWindowPositionDefault() {
        // Given default state
        // Then window position should be topMiddle
        XCTAssertEqual(state.windowPosition, .topMiddle)
    }

    @MainActor
    func testWindowOpacityDefault() {
        // Given default state
        // Then window opacity should be 1.0
        XCTAssertEqual(state.windowOpacity, 1.0)
    }

    // MARK: - Coordinator Lifecycle Tests

    @MainActor
    func testCoordinatorStopObserving() {
        // Given a running coordinator
        // When stopObserving is called
        coordinator.stopObserving()

        // Then it should complete without crash
        // (implicitly tested - no assertion needed, just verifying no crash)
        XCTAssertNotNil(coordinator)
    }

    @MainActor
    func testCoordinatorStartObserving() async {
        // Given a coordinator
        // When startObserving is called
        await coordinator.startObserving()

        // Then it should start without crash
        XCTAssertNotNil(coordinator.container)
    }

    // MARK: - Event State Tests

    @MainActor
    func testEventsEmpty() {
        // Given no events
        // Then the events list should be empty
        XCTAssertTrue(state.events.isEmpty)
    }
}
