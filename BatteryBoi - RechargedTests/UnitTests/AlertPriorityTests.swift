//
//  AlertPriorityTests.swift
//  BatteryBoi-RechargedTests
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class AlertPriorityTests: XCTestCase {

    nonisolated(unsafe) var mockWindowService: MockWindowService!

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockWindowService()
        }
        mockWindowService = service
    }

    override nonisolated func tearDown() {
        mockWindowService = nil
        super.tearDown()
    }

    // MARK: - Priority Mapping

    @MainActor
    func testAllAlertTypesMapToExpectedPriority() {
        let expectations: [(HUDAlertTypes, AlertPriority)] = [
            (.percentOne, .critical), (.deviceOverheating, .critical),
            (.percentFive, .high), (.chargingComplete, .high),
            (.chargingBegan, .medium), (.chargingStopped, .medium),
            (.percentTen, .medium), (.percentTwentyFive, .medium),
            (.deviceConnected, .medium), (.deviceRemoved, .medium),
            (.userLaunched, .low), (.userEvent, .low), (.userInitiated, .low),
        ]
        for (alert, expected) in expectations {
            XCTAssertEqual(alert.priority, expected, "\(alert) should be \(expected)")
        }
    }

    // MARK: - Priority Replacement

    @MainActor
    func testCriticalAlertReplacesLowerPriorityAlert() {
        mockWindowService.open(.deviceConnected, device: nil)

        mockWindowService.open(.percentOne, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)
    }

    @MainActor
    func testHighAlertReplacesMediumAlert() {
        mockWindowService.open(.chargingBegan, device: nil)

        mockWindowService.open(.percentFive, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentFive)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    @MainActor
    func testLowerPriorityAlertIsQueuedWhenHigherIsShowing() {
        mockWindowService.open(.percentOne, device: nil)

        mockWindowService.open(.deviceConnected, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)
        XCTAssertEqual(mockWindowService.alertQueue.count, 1)
        XCTAssertEqual(mockWindowService.alertQueue.first?.type, .deviceConnected)
    }

    @MainActor
    func testEqualPriorityAlertReplacesCurrentAlert() {
        mockWindowService.open(.chargingBegan, device: nil)

        mockWindowService.open(.chargingStopped, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .chargingStopped)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    @MainActor
    func testSameAlertTypeReplacesItself() {
        mockWindowService.open(.percentFive, device: nil)

        mockWindowService.open(.percentFive, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentFive)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    // MARK: - Queue Processing

    @MainActor
    func testQueuedAlertShowsAfterCurrentDismisses() {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .deviceConnected)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    @MainActor
    func testMultipleQueuedAlertsDrainInFIFOOrder() {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)
        mockWindowService.open(.chargingBegan, device: nil)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .deviceConnected)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .chargingBegan)

        mockWindowService.simulateDismissal()
        XCTAssertNil(mockWindowService.currentAlert)
    }

    @MainActor
    func testDeviceDataPreservedThroughQueue() throws {
        let device = BluetoothObject.testDevice(
            address: "11:22:33:44:55:66",
            name: "AirPods Pro",
            batteryPercent: 15
        )

        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: device)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .deviceConnected)
        let deliveredDevice = try XCTUnwrap(mockWindowService.currentDevice)
        XCTAssertEqual(deliveredDevice.address, "11-22-33-44-55-66")
    }

    // MARK: - Queue Capacity

    @MainActor
    func testQueueCapsAtMaxSize() {
        mockWindowService.open(.percentOne, device: nil)

        for _ in 0 ..< 10 {
            mockWindowService.open(.deviceConnected, device: nil)
        }

        XCTAssertEqual(mockWindowService.alertQueue.count, 5)
    }

    @MainActor
    func testOverflowAlertIsSilentlyDropped() {
        mockWindowService.open(.percentOne, device: nil)

        for i in 0 ..< 6 {
            let device = BluetoothObject.testDevice(name: "Device \(i)")
            mockWindowService.open(.deviceConnected, device: device)
        }

        XCTAssertEqual(mockWindowService.alertQueue.count, 5)
        XCTAssertEqual(mockWindowService.alertQueue.last?.device?.device, "Device 4")
    }

    // MARK: - userInitiated Bypass

    @MainActor
    func testUserInitiatedBypassesPriorityQueue() {
        mockWindowService.open(.percentOne, device: nil)

        mockWindowService.open(.userInitiated, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .userInitiated)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    // MARK: - Wake Clears Queue

    @MainActor
    func testWakeClearsAlertQueue() {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)
        XCTAssertFalse(mockWindowService.alertQueue.isEmpty)

        mockWindowService.handleWake()
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
        XCTAssertNil(mockWindowService.currentAlert)
    }
}
