//
//  TaskLifecycleTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class TaskLifecycleTests: XCTestCase {

    @MainActor
    func testEventServiceDeinit_noRetainCycle() async {
        weak var weakService: EventService?

        do {
            let service = EventService()
            weakService = service
            XCTAssertNotNil(weakService)
        }

        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(weakService, "EventService should deallocate — tasks must use [weak self]")
    }

    @MainActor
    func testSettingsServiceDeinit_noRetainCycle() async {
        weak var weakService: SettingsService?

        do {
            let service = SettingsService()
            weakService = service
            XCTAssertNotNil(weakService)
        }

        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(weakService, "SettingsService should deallocate — tasks must use [weak self]")
    }

    @MainActor
    func testServiceCoordinatorStopObserving_preventsAlerts() async {
        let mockBattery = MockBatteryService()
        let mockWindow = MockWindowService()
        let coordinator = ServiceCoordinator(
            battery: mockBattery,
            bluetooth: MockBluetoothService(),
            settings: MockSettingsService(),
            window: mockWindow,
            events: MockEventService()
        )

        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()

        coordinator.stopObserving()

        let countBefore = mockWindow.openCallCount
        mockBattery.percentage = 24
        try? await Task.sleep(for: .seconds(2))

        XCTAssertEqual(mockWindow.openCallCount, countBefore, "No alerts should fire after stopObserving")
    }

    @MainActor
    func testServiceCoordinatorDeinit_noRetainCycle() async {
        weak var weakCoordinator: ServiceCoordinator?

        do {
            let coordinator = ServiceCoordinator(
                battery: MockBatteryService(),
                bluetooth: MockBluetoothService(),
                settings: MockSettingsService(),
                window: MockWindowService(),
                events: MockEventService()
            )
            coordinator.startObserving()
            weakCoordinator = coordinator
            coordinator.stopObserving()
        }

        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(weakCoordinator, "ServiceCoordinator should deallocate — tasks must use [weak self]")
    }
}
