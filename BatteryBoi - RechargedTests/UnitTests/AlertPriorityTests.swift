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

    // MARK: - Priority Level Tests

    @MainActor
    func testCriticalAlertsHaveHighestPriority() {
        XCTAssertEqual(HUDAlertTypes.percentOne.priority, .critical)
        XCTAssertEqual(HUDAlertTypes.deviceOverheating.priority, .critical)
    }

    @MainActor
    func testHighPriorityAlerts() {
        XCTAssertEqual(HUDAlertTypes.percentFive.priority, .high)
        XCTAssertEqual(HUDAlertTypes.chargingComplete.priority, .high)
    }

    @MainActor
    func testMediumPriorityAlerts() {
        XCTAssertEqual(HUDAlertTypes.chargingBegan.priority, .medium)
        XCTAssertEqual(HUDAlertTypes.chargingStopped.priority, .medium)
        XCTAssertEqual(HUDAlertTypes.percentTen.priority, .medium)
        XCTAssertEqual(HUDAlertTypes.percentTwentyFive.priority, .medium)
        XCTAssertEqual(HUDAlertTypes.deviceConnected.priority, .medium)
        XCTAssertEqual(HUDAlertTypes.deviceRemoved.priority, .medium)
    }

    @MainActor
    func testLowPriorityAlerts() {
        XCTAssertEqual(HUDAlertTypes.userLaunched.priority, .low)
        XCTAssertEqual(HUDAlertTypes.userEvent.priority, .low)
        XCTAssertEqual(HUDAlertTypes.userInitiated.priority, .low)
    }

    @MainActor
    func testPriorityComparison() {
        XCTAssertTrue(AlertPriority.low < .medium)
        XCTAssertTrue(AlertPriority.medium < .high)
        XCTAssertTrue(AlertPriority.high < .critical)
        XCTAssertFalse(AlertPriority.critical < .low)
    }

    // MARK: - Priority Replacement Tests

    @MainActor
    func testCriticalAlertReplacesLowerPriorityAlert() {
        mockWindowService.open(.deviceConnected, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .deviceConnected)

        mockWindowService.open(.percentOne, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)
    }

    @MainActor
    func testLowerPriorityAlertIsQueuedWhenHigherIsShowing() {
        mockWindowService.open(.percentOne, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)

        mockWindowService.open(.deviceConnected, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)
        XCTAssertEqual(mockWindowService.alertQueue.count, 1)
        XCTAssertEqual(mockWindowService.alertQueue.first?.type, .deviceConnected)
    }

    @MainActor
    func testEqualPriorityAlertReplacesCurrentAlert() {
        mockWindowService.open(.chargingBegan, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .chargingBegan)

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

    // MARK: - Queue Processing Tests

    @MainActor
    func testQueuedAlertShowsAfterCurrentDismisses() {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)
        XCTAssertEqual(mockWindowService.alertQueue.count, 1)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .deviceConnected)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    @MainActor
    func testMultipleQueuedAlertsFireSequentially() {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)
        mockWindowService.open(.chargingBegan, device: nil)
        XCTAssertEqual(mockWindowService.alertQueue.count, 2)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .deviceConnected)

        mockWindowService.simulateDismissal()
        XCTAssertEqual(mockWindowService.currentAlert, .chargingBegan)

        mockWindowService.simulateDismissal()
        XCTAssertNil(mockWindowService.currentAlert)
    }

    @MainActor
    func testQueueIsFIFO() throws {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)
        mockWindowService.open(.chargingStopped, device: nil)
        mockWindowService.open(.userEvent, device: nil)

        let first = try XCTUnwrap(mockWindowService.currentAlert)
        XCTAssertEqual(first, .percentOne)

        mockWindowService.simulateDismissal()
        let second = try XCTUnwrap(mockWindowService.currentAlert)
        XCTAssertEqual(second, .deviceConnected)

        mockWindowService.simulateDismissal()
        let third = try XCTUnwrap(mockWindowService.currentAlert)
        XCTAssertEqual(third, .chargingStopped)

        mockWindowService.simulateDismissal()
        let fourth = try XCTUnwrap(mockWindowService.currentAlert)
        XCTAssertEqual(fourth, .userEvent)

        mockWindowService.simulateDismissal()
        XCTAssertNil(mockWindowService.currentAlert)
    }

    // MARK: - Queue Capacity Tests

    @MainActor
    func testQueueDoesNotExceedMaxSize() {
        mockWindowService.open(.percentOne, device: nil)

        for _ in 0 ..< 10 {
            mockWindowService.open(.deviceConnected, device: nil)
        }

        XCTAssertEqual(mockWindowService.alertQueue.count, 5)
    }

    // MARK: - userInitiated Bypass Tests

    @MainActor
    func testUserInitiatedBypassesPriorityQueue() {
        mockWindowService.open(.percentOne, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .percentOne)

        mockWindowService.open(.userInitiated, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .userInitiated)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    // MARK: - Wake Clears Queue Tests

    @MainActor
    func testWakeClearsAlertQueue() {
        mockWindowService.open(.percentOne, device: nil)
        mockWindowService.open(.deviceConnected, device: nil)
        XCTAssertFalse(mockWindowService.alertQueue.isEmpty)

        mockWindowService.handleWake()
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
        XCTAssertNil(mockWindowService.currentAlert)
    }

    // MARK: - No Current Alert Tests

    @MainActor
    func testAlertShowsImmediatelyWhenNothingIsShowing() {
        XCTAssertNil(mockWindowService.currentAlert)

        mockWindowService.open(.userEvent, device: nil)
        XCTAssertEqual(mockWindowService.currentAlert, .userEvent)
        XCTAssertTrue(mockWindowService.alertQueue.isEmpty)
    }

    @MainActor
    func testDismissalWithEmptyQueueClearsState() {
        mockWindowService.open(.chargingBegan, device: nil)

        mockWindowService.simulateDismissal()
        XCTAssertNil(mockWindowService.currentAlert)
        XCTAssertEqual(mockWindowService.state, .hidden)
    }
}
