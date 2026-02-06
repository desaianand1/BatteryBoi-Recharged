//
//  WindowServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for window service functionality.
//

@testable import BatteryBoi___Recharged
import SwiftUI
@preconcurrency import XCTest

final class WindowServiceTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockWindowService: MockWindowService!

    // MARK: - Setup

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

    // MARK: - HUD State Machine Tests

    @MainActor
    func testHiddenToProgress() {
        // Given hidden state
        mockWindowService.state = .hidden

        // When transitioning to progress
        mockWindowService.setState(.progress, animated: true)

        // Then state should be progress
        XCTAssertEqual(mockWindowService.state, .progress)
    }

    @MainActor
    func testProgressToRevealed() {
        // Given progress state
        mockWindowService.state = .progress

        // When transitioning to revealed
        mockWindowService.setState(.revealed, animated: true)

        // Then state should be revealed
        XCTAssertEqual(mockWindowService.state, .revealed)
    }

    @MainActor
    func testRevealedToDetailed() {
        // Given revealed state
        mockWindowService.state = .revealed

        // When transitioning to detailed
        mockWindowService.setState(.detailed, animated: true)

        // Then state should be detailed
        XCTAssertEqual(mockWindowService.state, .detailed)
    }

    @MainActor
    func testDetailedToDismissed() {
        // Given detailed state
        mockWindowService.state = .detailed

        // When transitioning to dismissed
        mockWindowService.setState(.dismissed, animated: true)

        // Then state should be dismissed
        XCTAssertEqual(mockWindowService.state, .dismissed)
    }

    @MainActor
    func testDismissedToHidden() {
        // Given dismissed state
        mockWindowService.state = .dismissed

        // When transitioning to hidden
        mockWindowService.setState(.hidden, animated: false)

        // Then state should be hidden
        XCTAssertEqual(mockWindowService.state, .hidden)
    }

    // MARK: - Alert Tests

    @MainActor
    func testOpenWithPercentTwentyFive() {
        // When opening 25% alert
        mockWindowService.open(.percentTwentyFive, device: nil)

        // Then alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .percentTwentyFive)
        XCTAssertEqual(mockWindowService.state, .revealed)
    }

    @MainActor
    func testOpenWithPercentTen() {
        // When opening 10% alert
        mockWindowService.open(.percentTen, device: nil)

        // Then alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .percentTen)
    }

    @MainActor
    func testOpenWithPercentFive() {
        // When opening 5% alert
        mockWindowService.open(.percentFive, device: nil)

        // Then alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .percentFive)
    }

    @MainActor
    func testOpenWithPercentOne() {
        // When opening 1% alert
        mockWindowService.open(.percentOne, device: nil)

        // Then alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .percentOne)
    }

    @MainActor
    func testOpenWithChargingComplete() {
        // When opening charging complete alert
        mockWindowService.open(.chargingComplete, device: nil)

        // Then alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .chargingComplete)
    }

    @MainActor
    func testOpenWithDeviceOverheating() {
        // When opening overheat alert
        mockWindowService.open(.deviceOverheating, device: nil)

        // Then alert type should be tracked
        XCTAssertEqual(mockWindowService.lastOpenType, .deviceOverheating)
    }

    // MARK: - Positioning Tests

    @MainActor
    func testPositionCenter() {
        // Given center position
        mockWindowService.position = .center

        // Then alignment should be correct
        XCTAssertEqual(mockWindowService.position.alignment, .center)
    }

    @MainActor
    func testPositionTopLeft() {
        // Given top left position
        mockWindowService.position = .topLeft

        // Then alignment should be correct
        XCTAssertEqual(mockWindowService.position.alignment, .topLeading)
    }

    @MainActor
    func testPositionTopMiddle() {
        // Given top middle position
        mockWindowService.position = .topMiddle

        // Then alignment should be correct
        XCTAssertEqual(mockWindowService.position.alignment, .top)
    }

    @MainActor
    func testPositionTopRight() {
        // Given top right position
        mockWindowService.position = .topRight

        // Then alignment should be correct
        XCTAssertEqual(mockWindowService.position.alignment, .topTrailing)
    }

    @MainActor
    func testPositionBottomLeft() {
        // Given bottom left position
        mockWindowService.position = .bottomLeft

        // Then alignment should be correct
        XCTAssertEqual(mockWindowService.position.alignment, .bottomLeading)
    }

    @MainActor
    func testPositionBottomRight() {
        // Given bottom right position
        mockWindowService.position = .bottomRight

        // Then alignment should be correct
        XCTAssertEqual(mockWindowService.position.alignment, .bottomTrailing)
    }

    // MARK: - Dismiss Logic Tests

    @MainActor
    func testTimeoutAlertShouldAutoDismiss() {
        // Given a timeout alert type
        let alertType = HUDAlertTypes.chargingBegan

        // Then it should have timeout behavior
        XCTAssertTrue(alertType.timeout)
    }

    @MainActor
    func testUserInitiatedShouldNotAutoDismiss() {
        // Given a user-initiated alert
        let alertType = HUDAlertTypes.userInitiated

        // Then it should not have timeout behavior
        XCTAssertFalse(alertType.timeout)
    }

    // MARK: - Visibility Tests

    @MainActor
    func testHiddenStateNotVisible() {
        // Given hidden state
        mockWindowService.state = .hidden

        // Then visibility should be false
        XCTAssertFalse(mockWindowService.state.visible)
    }

    @MainActor
    func testProgressStateVisible() {
        // Given progress state
        mockWindowService.state = .progress

        // Then visibility should be true
        XCTAssertTrue(mockWindowService.state.visible)
    }

    @MainActor
    func testRevealedStateVisible() {
        // Given revealed state
        mockWindowService.state = .revealed

        // Then visibility should be true
        XCTAssertTrue(mockWindowService.state.visible)
    }

    @MainActor
    func testDetailedStateVisible() {
        // Given detailed state
        mockWindowService.state = .detailed

        // Then visibility should be true
        XCTAssertTrue(mockWindowService.state.visible)
    }

    @MainActor
    func testDismissedStateNotVisible() {
        // Given dismissed state
        mockWindowService.state = .dismissed

        // Then visibility should be false
        XCTAssertFalse(mockWindowService.state.visible)
    }

    // MARK: - Hover Tests

    @MainActor
    func testHoverPreventsAutoDismiss() {
        // Given a revealed window
        mockWindowService.state = .revealed

        // When user hovers
        mockWindowService.simulateHoverChange(true)

        // Then hover state should be tracked
        XCTAssertTrue(mockWindowService.hover)
    }

    @MainActor
    func testHoverExitAllowsDismiss() {
        // Given a hovered window
        mockWindowService.hover = true
        mockWindowService.state = .revealed

        // When user stops hovering
        mockWindowService.simulateHoverChange(false)

        // Then hover state should update
        XCTAssertFalse(mockWindowService.hover)
    }

    // MARK: - Edge Cases

    @MainActor
    func testRapidStateChanges() {
        // Given initial hidden state
        mockWindowService.state = .hidden

        // When rapidly changing states
        mockWindowService.setState(.progress, animated: false)
        mockWindowService.setState(.revealed, animated: false)
        mockWindowService.setState(.detailed, animated: false)
        mockWindowService.setState(.dismissed, animated: false)
        mockWindowService.setState(.hidden, animated: false)

        // Then final state should be hidden
        XCTAssertEqual(mockWindowService.state, .hidden)
        XCTAssertEqual(mockWindowService.setStateCallCount, 5)
    }

    @MainActor
    func testOpenWithNilDevice() {
        // When opening alert without device
        mockWindowService.open(.chargingBegan, device: nil)

        // Then device should be nil
        XCTAssertNil(mockWindowService.lastOpenDevice)
    }
}
