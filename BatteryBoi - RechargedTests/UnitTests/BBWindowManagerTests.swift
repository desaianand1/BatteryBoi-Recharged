//
//  BBWindowManagerTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for window manager functionality.
//

@testable import BatteryBoi___Recharged
import XCTest

final class BBWindowManagerTests: XCTestCase {

    // MARK: - Properties

    var mockWindowService: MockWindowService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        mockWindowService = MockWindowService()
    }

    override func tearDown() {
        mockWindowService = nil
        super.tearDown()
    }

    // MARK: - State Transition Tests

    @MainActor
    func testStateTransitionToRevealed() {
        // Given a hidden window
        mockWindowService.state = .hidden

        // When opening a notification
        mockWindowService.open(.userInitiated, device: nil)

        // Then the state should be revealed
        XCTAssertEqual(mockWindowService.state, .revealed)
        XCTAssertEqual(mockWindowService.openCallCount, 1)
    }

    @MainActor
    func testStateTransitionToDismissed() {
        // Given a revealed window
        mockWindowService.state = .revealed

        // When dismissing
        mockWindowService.setState(.dismissed, animated: true)

        // Then the state should be dismissed
        XCTAssertEqual(mockWindowService.state, .dismissed)
        XCTAssertEqual(mockWindowService.lastSetStateAnimated, true)
    }

    @MainActor
    func testStateTransitionToDetailed() {
        // Given a revealed window
        mockWindowService.state = .revealed

        // When expanding to detailed view
        mockWindowService.setState(.detailed, animated: true)

        // Then the state should be detailed
        XCTAssertEqual(mockWindowService.state, .detailed)
    }

    @MainActor
    func testStateTransitionToHidden() {
        // Given a dismissed window
        mockWindowService.state = .dismissed

        // When hiding
        mockWindowService.setState(.hidden, animated: false)

        // Then the state should be hidden
        XCTAssertEqual(mockWindowService.state, .hidden)
        XCTAssertEqual(mockWindowService.lastSetStateAnimated, false)
    }

    // MARK: - Visibility Tests

    @MainActor
    func testIsVisibleWhenRevealed() {
        // Given a revealed window
        mockWindowService.state = .revealed

        // When checking visibility
        let isVisible = mockWindowService.isVisible(.userInitiated)

        // Then it should be visible
        XCTAssertTrue(isVisible)
    }

    @MainActor
    func testIsVisibleWhenDetailed() {
        // Given a detailed window
        mockWindowService.state = .detailed

        // When checking visibility
        let isVisible = mockWindowService.isVisible(.userInitiated)

        // Then it should be visible
        XCTAssertTrue(isVisible)
    }

    @MainActor
    func testIsNotVisibleWhenHidden() {
        // Given a hidden window
        mockWindowService.state = .hidden

        // When checking visibility
        let isVisible = mockWindowService.isVisible(.userInitiated)

        // Then it should not be visible
        XCTAssertFalse(isVisible)
    }

    @MainActor
    func testIsNotVisibleWhenDismissed() {
        // Given a dismissed window
        mockWindowService.state = .dismissed

        // When checking visibility
        let isVisible = mockWindowService.isVisible(.userInitiated)

        // Then it should not be visible
        XCTAssertFalse(isVisible)
    }

    // MARK: - Alert Type Tests

    @MainActor
    func testOpenWithChargingAlert() {
        // When opening a charging alert
        mockWindowService.open(.chargingBegan, device: nil)

        // Then the alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .chargingBegan)
        XCTAssertNil(mockWindowService.lastOpenDevice)
    }

    @MainActor
    func testOpenWithDeviceConnectedAlert() {
        // Given a connected device
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )

        // When opening a device connected alert
        mockWindowService.open(.deviceConnected, device: device)

        // Then the alert type and device should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .deviceConnected)
        // Address is normalized to lowercase with dashes
        XCTAssertEqual(mockWindowService.lastOpenDevice?.address, "aa-bb-cc-dd-ee-ff")
    }

    // MARK: - Hover Tests

    @MainActor
    func testHoverChange() {
        // Given a window that is not hovered
        XCTAssertFalse(mockWindowService.hover)

        // When hovering
        mockWindowService.simulateHoverChange(true)

        // Then hover state should update
        XCTAssertTrue(mockWindowService.hover)
    }

    // MARK: - Frame Calculation Tests

    @MainActor
    func testCalculateFrameDefault() {
        // When calculating frame without a moved position
        let frame = mockWindowService.calculateFrame(moved: nil)

        // Then a default frame should be returned
        XCTAssertEqual(frame.width, 420)
        XCTAssertEqual(frame.height, 220)
    }

    @MainActor
    func testCalculateFrameWithMovedPosition() {
        // Given a moved position
        let movedFrame = NSRect(x: 200, y: 300, width: 420, height: 220)

        // When calculating frame
        let frame = mockWindowService.calculateFrame(moved: movedFrame)

        // Then the moved frame should be returned
        XCTAssertEqual(frame.origin.x, 200)
        XCTAssertEqual(frame.origin.y, 300)
    }
}
