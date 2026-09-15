//
//  BluetoothServiceBehaviorTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for Bluetooth service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BluetoothServiceBehaviorTests: XCTestCase {

    // MARK: - Properties

    /// Mock service (nonisolated for setUp/tearDown compatibility with Swift 6)
    nonisolated(unsafe) var mockBluetoothService: MockBluetoothService!

    // MARK: - Setup

    override nonisolated func setUp() {
        super.setUp()
        let service = MainActor.assumeIsolated {
            MockBluetoothService()
        }
        mockBluetoothService = service
    }

    override nonisolated func tearDown() {
        mockBluetoothService = nil
        super.tearDown()
    }

    // MARK: - Connection Tests

    @MainActor
    func testUpdateConnectionTracksDevice() {
        // Given a mock Bluetooth service
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Test Device",
            batteryPercent: 75
        )

        // When updating connection
        _ = mockBluetoothService.updateConnection(device, state: .connected)

        // Then the device should be tracked
        XCTAssertEqual(mockBluetoothService.lastUpdateConnectionDevice?.address, device.address)
    }

    // MARK: - Device List Tests

    @MainActor
    func testDeviceListSimulation() {
        // Given an empty device list
        XCTAssertTrue(mockBluetoothService.list.isEmpty)

        // When devices are discovered
        let devices = [
            BluetoothObject.testDevice(
                address: "AA:BB:CC:DD:EE:FF",
                name: "AirPods Pro",
                batteryPercent: 80
            ),
        ]
        mockBluetoothService.simulateListChange(devices)

        // Then the list should be updated
        XCTAssertEqual(mockBluetoothService.list.count, 1)
        XCTAssertEqual(mockBluetoothService.list.first?.device, "AirPods Pro")
    }

    // MARK: - Battery Left/Right Parsing Tests

    @MainActor
    func testBatteryLeftRightParsing() {
        // Given a device with L/R battery info (AirPods-style)
        let battery = BluetoothBatteryObject(percent: 80.0, left: 85.0, right: 75.0)

        // Then left and right values should be accessible
        XCTAssertEqual(battery.left, 85.0)
        XCTAssertEqual(battery.right, 75.0)
        XCTAssertEqual(battery.percent, 75.0) // Minimum of all values
    }

    @MainActor
    func testBatteryWithoutLeftRight() {
        // Given a device without L/R battery (single battery device)
        let battery = BluetoothBatteryObject(percent: 60.0)

        // Then left and right should be nil
        XCTAssertNil(battery.left)
        XCTAssertNil(battery.right)
        XCTAssertEqual(battery.percent, 60.0)
    }

}
