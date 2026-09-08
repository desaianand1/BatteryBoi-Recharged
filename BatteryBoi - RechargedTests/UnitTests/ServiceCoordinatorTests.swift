//
//  ServiceCoordinatorTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class ServiceCoordinatorTests: XCTestCase {

    // MARK: - Properties

    nonisolated(unsafe) var coordinator: ServiceCoordinator!
    nonisolated(unsafe) var mockBattery: MockBatteryService!
    nonisolated(unsafe) var mockBluetooth: MockBluetoothService!
    nonisolated(unsafe) var mockSettings: MockSettingsService!
    nonisolated(unsafe) var mockWindow: MockWindowService!
    nonisolated(unsafe) var mockEvents: MockEventService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let (b, bt, s, w, e, c) = MainActor.assumeIsolated {
            let b = MockBatteryService()
            let bt = MockBluetoothService()
            let s = MockSettingsService()
            let w = MockWindowService()
            let e = MockEventService()
            let c = ServiceCoordinator(
                battery: b, bluetooth: bt,
                settings: s, window: w, events: e
            )
            return (b, bt, s, w, e, c)
        }
        mockBattery = b
        mockBluetooth = bt
        mockSettings = s
        mockWindow = w
        mockEvents = e
        coordinator = c
    }

    override nonisolated func tearDown() {
        let coord = coordinator
        MainActor.assumeIsolated {
            coord?.stopObserving()
        }
        coordinator = nil
        mockBattery = nil
        mockBluetooth = nil
        mockSettings = nil
        mockWindow = nil
        mockEvents = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// Waits for observation tasks to register their tracking.
    private func waitForObservation() async {
        try? await Task.sleep(for: .milliseconds(100))
    }

    // MARK: - Lifecycle Tests

    @MainActor
    func testCoordinatorStopObserving() {
        coordinator.stopObserving()
        XCTAssertNotNil(coordinator)
    }

    @MainActor
    func testCoordinatorStartObserving() {
        coordinator.startObserving()
        XCTAssertNotNil(coordinator)
    }

    @MainActor
    func testCoordinatorHandleSleep() {
        coordinator.handleSleep()
        XCTAssertNotNil(coordinator)
    }

    @MainActor
    func testCoordinatorHandleWake() {
        coordinator.handleWake()
        XCTAssertNotNil(coordinator)
    }

    @MainActor
    func testStopObservingIdempotent() {
        coordinator.stopObserving()
        coordinator.stopObserving()
        XCTAssertNotNil(coordinator)
    }

    // MARK: - Battery Percentage Alert Tests

    @MainActor
    func testPercentageDropTo25TriggersAlert() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .percentTwentyFive)
    }

    @MainActor
    func testChargingStartResetsThresholds() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))
        let firstPercentAlerts = mockWindow.openHistory.filter { $0 == .percentTwentyFive }
        XCTAssertEqual(firstPercentAlerts.count, 1, "Should have fired one 25% alert")

        // Switch to charging (resets thresholds) — wait for debounce (2s)
        mockBattery.charging = BatteryCharging(.charging)
        try? await Task.sleep(for: .seconds(3))

        // Switch back to battery at 24% — threshold should re-fire
        mockBattery.charging = BatteryCharging(.battery)
        mockBattery.percentage = 26
        try? await Task.sleep(for: .seconds(3))
        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))

        let secondPercentAlerts = mockWindow.openHistory.filter { $0 == .percentTwentyFive }
        XCTAssertEqual(secondPercentAlerts.count, 2, "Threshold should re-fire after charging reset")
    }

    @MainActor
    func testThermalSuboptimalTriggersOverheatAlert() async {
        mockBattery.thermal = .optimal
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.thermal = .suboptimal
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .deviceOverheating)
    }

    // MARK: - Bluetooth Alert Tests

    @MainActor
    func testBluetoothDeviceConnectTriggersAlert() async {
        coordinator.startObserving()
        await waitForObservation()

        let device = BluetoothObject.testDevice(address: "11:22:33:44:55:66", name: "AirPods")
        mockBluetooth.simulateDeviceConnected(device)
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .deviceConnected)
    }

    @MainActor
    func testBluetoothDeviceDisconnectTriggersAlert() async {
        let device = BluetoothObject.testDevice(address: "11:22:33:44:55:66", name: "AirPods")
        mockBluetooth.simulateDeviceConnected(device)
        coordinator.startObserving()
        await waitForObservation()

        mockBluetooth.simulateDeviceDisconnected(address: "11:22:33:44:55:66")
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.lastOpenType, .deviceRemoved)
    }

    // MARK: - Charging Alert Tests

    @MainActor
    func testChargingCompleteAt100() async {
        mockBattery.charging = BatteryCharging(.charging)
        mockBattery.percentage = 99
        mockSettings.chargeEighty = .disabled
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 100
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.lastOpenType, .chargingComplete)
    }

    @MainActor
    func testChargingCompleteAt80WhenChargeEightyEnabled() async {
        mockBattery.charging = BatteryCharging(.charging)
        mockBattery.percentage = 79
        mockSettings.chargeEighty = .enabled
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 80
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.lastOpenType, .chargingComplete)
    }

    @MainActor
    func testChargingDebounce() async {
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        let countBefore = mockWindow.openCallCount

        // Rapid state changes — should coalesce
        mockBattery.charging = BatteryCharging(.charging)
        try? await Task.sleep(for: .milliseconds(50))
        mockBattery.charging = BatteryCharging(.battery)
        try? await Task.sleep(for: .milliseconds(50))
        mockBattery.charging = BatteryCharging(.charging)

        // Wait for debounce to settle (chargingDebounce = 2s)
        try? await Task.sleep(for: .seconds(3))

        let countAfter = mockWindow.openCallCount
        XCTAssertEqual(countAfter - countBefore, 1, "Debounce should coalesce rapid changes into one alert")
    }

    // MARK: - Event Alert Tests

    @MainActor
    func testEventAlertWithin3Minutes() async {
        mockBattery.charging = BatteryCharging(.battery)
        let event = MockEventService.createMockEvent(
            id: "test-1",
            name: "Test Meeting",
            start: Date().addingTimeInterval(120)
        )
        mockEvents.events = [event]
        coordinator.startObserving()

        // Event check polls every 30 seconds
        try? await Task.sleep(for: .seconds(32))

        XCTAssertEqual(mockWindow.lastOpenType, .userEvent)
    }

    // MARK: - Additional Threshold Tests

    @MainActor
    func testPercentageDropTo10TriggersAlert() async {
        mockBattery.percentage = 12
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 9
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .percentTen)
    }

    @MainActor
    func testPercentageDropTo5TriggersAlert() async {
        mockBattery.percentage = 7
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 4
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .percentFive)
    }

    @MainActor
    func testPercentageDropTo1TriggersAlert() async {
        mockBattery.percentage = 3
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 0.5
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .percentOne)
    }

    @MainActor
    func testMultiThresholdSkipFiresHighestFirst() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 4
        try? await Task.sleep(for: .milliseconds(500))

        let percentAlerts = mockWindow.openHistory.filter {
            $0 == .percentTwentyFive || $0 == .percentTen || $0 == .percentFive || $0 == .percentOne
        }
        XCTAssertFalse(percentAlerts.isEmpty)
        XCTAssertEqual(percentAlerts.first, .percentTwentyFive, "First matching threshold should fire first")
    }

    // MARK: - Duplicate Alert Tests

    @MainActor
    func testDuplicateThresholdNotReNotified() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))
        let firstCount = mockWindow.openCallCount

        mockBattery.percentage = 25
        try? await Task.sleep(for: .milliseconds(200))
        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, firstCount)
    }

    // MARK: - Boundary Threshold Tests

    @MainActor
    func testExactlyAt25PercentTriggersAlert() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 25.0
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(mockWindow.openCallCount, 1)
        XCTAssertEqual(mockWindow.lastOpenType, .percentTwentyFive)
    }

    @MainActor
    func testPercentageGoingUpDoesNotRetrigger() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(mockWindow.openCallCount, 1)

        mockBattery.percentage = 26
        try? await Task.sleep(for: .milliseconds(500))

        let percentAlerts = mockWindow.openHistory.filter { $0 == .percentTwentyFive }
        XCTAssertEqual(percentAlerts.count, 1, "Rising above threshold should not re-trigger")
    }

    // MARK: - Thermal Transition Tests

    @MainActor
    func testThermalReturnToOptimalAllowsRealert() async {
        mockBattery.thermal = .optimal
        coordinator.startObserving()
        await waitForObservation()

        mockBattery.thermal = .suboptimal
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(mockWindow.openCallCount, 1)

        mockBattery.thermal = .optimal
        try? await Task.sleep(for: .milliseconds(200))

        mockBattery.thermal = .suboptimal
        try? await Task.sleep(for: .milliseconds(500))

        let overheatAlerts = mockWindow.openHistory.filter { $0 == .deviceOverheating }
        XCTAssertEqual(overheatAlerts.count, 2, "Second transition to suboptimal should fire again")
    }

    // MARK: - Event Timing Edge Cases

    @MainActor
    func testEventUnder1MinuteDoesNotTrigger() async {
        mockBattery.charging = BatteryCharging(.battery)
        let event = MockEventService.createMockEvent(
            id: "close-event",
            name: "Imminent Meeting",
            start: Date().addingTimeInterval(30)
        )
        mockEvents.events = [event]
        coordinator.startObserving()

        try? await Task.sleep(for: .seconds(32))

        let eventAlerts = mockWindow.openHistory.filter { $0 == .userEvent }
        XCTAssertEqual(eventAlerts.count, 0, "Event under 1 minute away should not trigger")
    }

    @MainActor
    func testEventAt3MinBoundaryTriggers() async {
        mockBattery.charging = BatteryCharging(.battery)
        let event = MockEventService.createMockEvent(
            id: "boundary-event",
            name: "Boundary Meeting",
            start: Date().addingTimeInterval(180)
        )
        mockEvents.events = [event]
        coordinator.startObserving()

        try? await Task.sleep(for: .seconds(32))

        let eventAlerts = mockWindow.openHistory.filter { $0 == .userEvent }
        XCTAssertEqual(eventAlerts.count, 1, "Event at exactly 3 minutes should trigger")
    }

    @MainActor
    func testEventDedupSameIdNotReNotified() async {
        mockBattery.charging = BatteryCharging(.battery)
        let event = MockEventService.createMockEvent(
            id: "dedup-event",
            name: "Repeat Meeting",
            start: Date().addingTimeInterval(120)
        )
        mockEvents.events = [event]
        coordinator.startObserving()

        try? await Task.sleep(for: .seconds(32))
        let firstCount = mockWindow.openHistory.count(where: { $0 == .userEvent })
        XCTAssertEqual(firstCount, 1)

        try? await Task.sleep(for: .seconds(32))
        let secondCount = mockWindow.openHistory.count(where: { $0 == .userEvent })
        XCTAssertEqual(secondCount, 1, "Same event ID should not trigger twice")
    }

    // MARK: - Multiple Charging Cycle Tests

    @MainActor
    func testMultipleChargingCyclesResetThresholds() async {
        mockBattery.percentage = 30
        mockBattery.charging = BatteryCharging(.battery)
        coordinator.startObserving()
        await waitForObservation()

        // First cycle: trigger 25% alert
        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(mockWindow.openHistory.count(where: { $0 == .percentTwentyFive }), 1)

        // Charge — wait for debounce (2s)
        mockBattery.charging = BatteryCharging(.charging)
        try? await Task.sleep(for: .seconds(3))

        // Second cycle
        mockBattery.charging = BatteryCharging(.battery)
        mockBattery.percentage = 30
        try? await Task.sleep(for: .seconds(3))
        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(mockWindow.openHistory.count(where: { $0 == .percentTwentyFive }), 2)

        // Third cycle
        mockBattery.charging = BatteryCharging(.charging)
        try? await Task.sleep(for: .seconds(3))
        mockBattery.charging = BatteryCharging(.battery)
        mockBattery.percentage = 30
        try? await Task.sleep(for: .seconds(3))
        mockBattery.percentage = 24
        try? await Task.sleep(for: .milliseconds(500))

        XCTAssertEqual(
            mockWindow.openHistory.count(where: { $0 == .percentTwentyFive }), 3,
            "Each charging cycle should reset thresholds"
        )
    }

    // MARK: - Event Suppression While Charging

    @MainActor
    func testEventDoesNotTriggerWhileCharging() async {
        mockBattery.charging = BatteryCharging(.charging)
        let event = MockEventService.createMockEvent(
            id: "charging-event",
            name: "Meeting While Charging",
            start: Date().addingTimeInterval(120)
        )
        mockEvents.events = [event]
        coordinator.startObserving()

        try? await Task.sleep(for: .seconds(32))

        let eventAlerts = mockWindow.openHistory.filter { $0 == .userEvent }
        XCTAssertEqual(eventAlerts.count, 0, "Events should not trigger while charging")
    }
}
