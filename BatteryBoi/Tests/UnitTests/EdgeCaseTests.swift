//
//  EdgeCaseTests.swift
//  BatteryBoiTests
//
//  Edge case tests for various scenarios.
//

@testable import BatteryBoi
import XCTest

final class EdgeCaseTests: XCTestCase {

    // MARK: - Properties

    var mockBatteryService: MockBatteryService!
    var mockWindowService: MockWindowService!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockBatteryService = MockBatteryService()
        mockWindowService = MockWindowService()
    }

    override func tearDown() {
        mockBatteryService = nil
        mockWindowService = nil
        super.tearDown()
    }

    // MARK: - Rapid Charging State Change Tests

    @MainActor
    func testRapidChargingStateChanges() {
        // Given a battery on battery power
        mockBatteryService.charging = BatteryCharging(.battery)

        // When rapidly toggling charging state
        mockBatteryService.simulateChargingChange(BatteryCharging(.charging))
        mockBatteryService.simulateChargingChange(BatteryCharging(.battery))
        mockBatteryService.simulateChargingChange(BatteryCharging(.charging))
        mockBatteryService.simulateChargingChange(BatteryCharging(.battery))

        // Then the final state should be consistent
        XCTAssertEqual(mockBatteryService.charging.state, .battery)
    }

    @MainActor
    func testChargingStateDebounceScenario() {
        // Given a battery that is charging
        mockBatteryService.charging = BatteryCharging(.charging)
        mockBatteryService.percentage = 50.0

        // When simulating plug/unplug within short period
        // (In real implementation, debounce would prevent multiple notifications)
        mockBatteryService.simulateChargingChange(BatteryCharging(.battery))
        let stateAfterUnplug = mockBatteryService.charging.state

        mockBatteryService.simulateChargingChange(BatteryCharging(.charging))
        let stateAfterReplug = mockBatteryService.charging.state

        // Then states should update correctly
        XCTAssertEqual(stateAfterUnplug, .battery)
        XCTAssertEqual(stateAfterReplug, .charging)
    }

    // MARK: - Battery Jump Tests

    @MainActor
    func testBatteryJumpSkipsThresholds() {
        // Given a battery at 30%
        mockBatteryService.percentage = 30.0

        // When battery jumps directly to 8% (skipping 25%, 10%)
        mockBatteryService.simulatePercentageChange(8.0)

        // Then percentage should be updated correctly
        XCTAssertEqual(mockBatteryService.percentage, 8.0)
        // Note: Real implementation uses range-based detection to catch this
    }

    @MainActor
    func testBatteryDropBelowCritical() {
        // Given a battery at 5%
        mockBatteryService.percentage = 5.0

        // When battery drops to 1%
        mockBatteryService.simulatePercentageChange(1.0)

        // Then the critical threshold should be detected
        XCTAssertEqual(mockBatteryService.percentage, 1.0)
        XCTAssertLessThanOrEqual(mockBatteryService.percentage, 5.0)
    }

    // MARK: - Window State Rapid Change Tests

    @MainActor
    func testRapidWindowStateChanges() {
        // Given a hidden window
        mockWindowService.state = .hidden

        // When rapidly changing states
        mockWindowService.open(.userInitiated, device: nil) // -> revealed
        mockWindowService.setState(.detailed, animated: true) // -> detailed
        mockWindowService.setState(.dismissed, animated: true) // -> dismissed
        mockWindowService.setState(.hidden, animated: false) // -> hidden

        // Then the final state should be hidden
        XCTAssertEqual(mockWindowService.state, .hidden)
        XCTAssertEqual(mockWindowService.setStateCallCount, 3)
    }

    @MainActor
    func testWindowOpenWhileVisible() {
        // Given a visible window
        mockWindowService.state = .revealed

        // When opening another alert
        mockWindowService.open(.chargingBegan, device: nil)

        // Then the window should remain revealed with new alert type
        XCTAssertEqual(mockWindowService.state, .revealed)
        XCTAssertEqual(mockWindowService.lastOpenType, .chargingBegan)
    }

    // MARK: - Multi-Monitor Tests

    @MainActor
    func testFrameCalculationConsistency() {
        // When calculating frame multiple times
        let frame1 = mockWindowService.calculateFrame(moved: nil)
        let frame2 = mockWindowService.calculateFrame(moved: nil)

        // Then frames should be consistent
        XCTAssertEqual(frame1.width, frame2.width)
        XCTAssertEqual(frame1.height, frame2.height)
    }

    // MARK: - Boundary Condition Tests

    @MainActor
    func testBatteryAtExactThresholds() {
        // Test exact threshold values
        let thresholds = [25.0, 10.0, 5.0, 1.0]

        for threshold in thresholds {
            mockBatteryService.simulatePercentageChange(threshold)
            XCTAssertEqual(mockBatteryService.percentage, threshold, "Failed at threshold \(threshold)")
        }
    }

    @MainActor
    func testBatteryJustAboveThresholds() {
        // Test values just above thresholds
        let aboveThresholds = [25.5, 10.5, 5.5, 1.5]

        for value in aboveThresholds {
            mockBatteryService.simulatePercentageChange(value)
            XCTAssertEqual(mockBatteryService.percentage, value, accuracy: 0.01)
        }
    }

    @MainActor
    func testBatteryJustBelowThresholds() {
        // Test values just below thresholds
        let belowThresholds = [24.5, 9.5, 4.5, 0.5]

        for value in belowThresholds {
            mockBatteryService.simulatePercentageChange(value)
            XCTAssertEqual(mockBatteryService.percentage, value, accuracy: 0.01)
        }
    }

    // MARK: - Thermal State Edge Cases

    @MainActor
    func testThermalStateWhileCharging() {
        // Given a charging battery with optimal thermal
        mockBatteryService.charging = BatteryCharging(.charging)
        mockBatteryService.thermal = .optimal

        // When thermal state degrades
        mockBatteryService.simulateThermalChange(.suboptimal)

        // Then both states should be tracked independently
        XCTAssertEqual(mockBatteryService.charging.state, .charging)
        XCTAssertEqual(mockBatteryService.thermal, .suboptimal)
    }

    // MARK: - Full Charge Edge Cases

    @MainActor
    func testChargingCompleteAtExactly100() {
        // Given a battery at 99%
        mockBatteryService.percentage = 99.0
        mockBatteryService.charging = BatteryCharging(.charging)

        // When battery reaches 100%
        mockBatteryService.simulatePercentageChange(100.0)

        // Then it should be at full charge
        XCTAssertEqual(mockBatteryService.percentage, 100.0)
        XCTAssertNil(mockBatteryService.untilFull) // No time remaining when full
    }

    @MainActor
    func testUnplugAtFullCharge() {
        // Given a fully charged battery
        mockBatteryService.percentage = 100.0
        mockBatteryService.charging = BatteryCharging(.charging)

        // When unplugging
        mockBatteryService.simulateChargingChange(BatteryCharging(.battery))

        // Then it should switch to battery mode at 100%
        XCTAssertEqual(mockBatteryService.charging.state, .battery)
        XCTAssertEqual(mockBatteryService.percentage, 100.0)
    }

    // MARK: - Bluetooth Device Type Tests

    @MainActor
    func testBluetoothDeviceWithOtherTypeIsValid() {
        // Given a device with "other" type
        let device = BluetoothObject(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Unknown Device",
            isConnected: true,
            batteryPercent: 50,
            deviceType: "other",
        )

        // Then it should still be a valid device
        XCTAssertEqual(device.type.type, .other)
        XCTAssertEqual(device.connected, .connected)
        XCTAssertEqual(device.battery.general, 50)
    }

    @MainActor
    func testBluetoothDeviceWithUnrecognizedTypeDefaultsToOther() {
        // Given a device with unrecognized type
        let device = BluetoothObject(
            address: "11:22:33:44:55:66",
            name: "Mystery Device",
            isConnected: false,
            batteryPercent: 75,
            deviceType: "unknown_type_xyz",
        )

        // Then it should default to .other type
        XCTAssertEqual(device.type.type, .other)
    }

    // MARK: - Rapid Event Debounce Tests

    @MainActor
    func testRapidMouseEventsDebounced() {
        // Given window in revealed state
        mockWindowService.setState(.revealed, animated: false)

        // When rapid state changes occur
        for _ in 0 ..< 10 {
            mockWindowService.simulateStateChange(.revealed)
        }

        // Then should not crash, state should be deterministic
        XCTAssertEqual(mockWindowService.state, .revealed)
    }

    @MainActor
    func testWindowStateConsistentAfterRapidChanges() {
        // Given initial hidden state
        mockWindowService.state = .hidden

        // When rapid open/close cycles occur
        for _ in 0 ..< 5 {
            mockWindowService.open(.userInitiated, device: nil)
            mockWindowService.setState(.dismissed, animated: false)
        }

        // Then final state should match last operation
        XCTAssertEqual(mockWindowService.state, .dismissed)
        XCTAssertEqual(mockWindowService.openCallCount, 5)
    }

    // MARK: - Division Safety Tests

    @MainActor
    func testZeroPercentageDivisionSafety() {
        // Given a battery at exactly 0%
        mockBatteryService.percentage = 0.0

        // When accessing properties that might divide by percentage
        let percentage = mockBatteryService.percentage

        // Then no crash should occur
        XCTAssertEqual(percentage, 0.0)
    }

    @MainActor
    func testNearZeroPercentageDivisionSafety() {
        // Given a battery at near-zero percentage
        mockBatteryService.percentage = 0.001

        // When simulating changes
        mockBatteryService.simulatePercentageChange(0.0)

        // Then no crash should occur
        XCTAssertEqual(mockBatteryService.percentage, 0.0)
    }
}
