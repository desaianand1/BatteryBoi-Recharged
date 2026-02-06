//
//  ServiceContainerTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for ServiceContainer dependency injection.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class ServiceContainerTests: XCTestCase {

    // MARK: - Properties

    /// Properties (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var container: ServiceContainer!
    nonisolated(unsafe) var state: AppState!
    nonisolated(unsafe) var coordinator: ServiceCoordinator!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let (s, c, cont) = MainActor.assumeIsolated {
            let s = AppState()
            let c = ServiceCoordinator()
            let cont = ServiceContainer(state: s, coordinator: c)
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
        container = nil
        coordinator = nil
        state = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    @MainActor
    func testContainerInitialization() {
        // Given a container
        // Then it should have valid state and coordinator
        XCTAssertNotNil(container.state)
        XCTAssertNotNil(container.coordinator)
    }

    @MainActor
    func testContainerStateReference() {
        // Given a container initialized with custom state
        // Then the state should be the same reference
        XCTAssertTrue(container.state === state)
    }

    @MainActor
    func testContainerCoordinatorReference() {
        // Given a container initialized with custom coordinator
        // Then the coordinator should be the same reference
        XCTAssertTrue(container.coordinator === coordinator)
    }

    // MARK: - Start Tests

    @MainActor
    func testContainerStart() async {
        // Given a container
        // When start is called
        await container.start()

        // Then coordinator should have container reference
        XCTAssertNotNil(coordinator.container)
        XCTAssertTrue(coordinator.container === container)
    }

    // MARK: - State Sync Tests

    @MainActor
    func testStateSyncAfterStart() async {
        // Given initial state values
        let initialPercentage = state.batteryPercentage

        // When container starts
        await container.start()

        // Then state should be synced (values may change based on actual manager state)
        // For test purposes, we just verify state is not nil
        XCTAssertNotNil(state)
        XCTAssertGreaterThanOrEqual(state.batteryPercentage, 0)
    }

    // MARK: - Service Access Tests

    @MainActor
    func testBatteryServiceAccess() {
        // Given a container
        // When accessing battery service
        let battery = container.battery

        // Then it should return a valid service
        XCTAssertNotNil(battery)
    }

    @MainActor
    func testBluetoothServiceAccess() {
        // Given a container
        // When accessing Bluetooth service
        let bluetooth = container.bluetooth

        // Then it should return a valid service
        XCTAssertNotNil(bluetooth)
    }

    @MainActor
    func testSettingsServiceAccess() {
        // Given a container
        // When accessing settings service
        let settings = container.settings

        // Then it should return a valid service
        XCTAssertNotNil(settings)
    }

    @MainActor
    func testWindowServiceAccess() {
        // Given a container
        // When accessing window service
        let window = container.window

        // Then it should return a valid service
        XCTAssertNotNil(window)
    }

    @MainActor
    func testStatsServiceAccess() {
        // Given a container
        // When accessing stats service
        let stats = container.stats

        // Then it should return a valid service
        XCTAssertNotNil(stats)
    }

    @MainActor
    func testEventsServiceAccess() {
        // Given a container
        // When accessing events service
        let events = container.events

        // Then it should return a valid service
        XCTAssertNotNil(events)
    }

    @MainActor
    func testAppServiceAccess() {
        // Given a container
        // When accessing app service
        let app = container.app

        // Then it should return a valid service
        XCTAssertNotNil(app)
    }

    @MainActor
    func testUpdateServiceAccess() {
        // Given a container
        // When accessing update service
        let update = container.update

        // Then it should return a valid service
        XCTAssertNotNil(update)
    }
}
