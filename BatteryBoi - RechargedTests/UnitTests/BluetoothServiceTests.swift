//
//  BluetoothServiceTests.swift
//  BatteryBoi-RechargedTests
//
//  Behavioral tests for bluetooth service functionality.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BluetoothServiceTests: XCTestCase {

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

    // MARK: - Device Discovery Tests

    @MainActor
    func testDeviceDiscoveryAddsToList() {
        // Given an empty device list
        XCTAssertTrue(mockBluetoothService.list.isEmpty)

        // When a device is discovered
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods Pro",
            batteryPercent: 85
        )
        mockBluetoothService.simulateDeviceConnected(device)

        // Then device should appear in list
        XCTAssertEqual(mockBluetoothService.list.count, 1)
        XCTAssertEqual(mockBluetoothService.list.first?.device, "AirPods Pro")
    }

    @MainActor
    func testMultipleDeviceDiscovery() {
        // Given empty device list
        XCTAssertTrue(mockBluetoothService.list.isEmpty)

        // When multiple devices are discovered
        let airpods = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods Pro",
            batteryPercent: 85
        )
        let mouse = BluetoothObject.testDevice(
            address: "11:22:33:44:55:66",
            name: "Magic Mouse",
            batteryPercent: 60
        )
        mockBluetoothService.simulateDeviceConnected(airpods)
        mockBluetoothService.simulateDeviceConnected(mouse)

        // Then both devices should be in list
        XCTAssertEqual(mockBluetoothService.list.count, 2)
    }

    // MARK: - Battery Tracking Tests

    @MainActor
    func testDeviceBatteryLevelTracking() {
        // Given a connected device with 80% battery
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )
        mockBluetoothService.simulateDeviceConnected(device)

        // When checking battery level
        let connectedDevice = mockBluetoothService.connected.first

        // Then battery level should be tracked
        XCTAssertEqual(connectedDevice?.battery.percent, 80)
    }

    @MainActor
    func testDeviceBatteryLevelUpdate() {
        // Given a connected device
        var device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )
        mockBluetoothService.simulateDeviceConnected(device)

        // When battery level changes
        device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 75
        )
        mockBluetoothService.simulateBatteryUpdate(device)

        // Then the new level should be reflected
        let updatedDevice = mockBluetoothService.list.first { $0.address == "aa-bb-cc-dd-ee-ff" }
        XCTAssertEqual(updatedDevice?.battery.percent, 75)
    }

    // MARK: - Connection State Tests

    @MainActor
    func testDeviceConnectionState() {
        // Given a connected device
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )
        mockBluetoothService.simulateDeviceConnected(device)

        // Then device should appear in connected list
        XCTAssertEqual(mockBluetoothService.connected.count, 1)
    }

    @MainActor
    func testDeviceDisconnection() {
        // Given a connected device
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )
        mockBluetoothService.simulateDeviceConnected(device)
        XCTAssertEqual(mockBluetoothService.connected.count, 1)

        // When device disconnects
        mockBluetoothService.simulateDeviceDisconnected(address: "aa-bb-cc-dd-ee-ff")

        // Then device should be removed from connected list
        XCTAssertEqual(mockBluetoothService.connected.count, 0)
    }

    // MARK: - Device Type Tests

    @MainActor
    func testDeviceTypeDetection() {
        // Given devices of different types
        let airpods = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods Pro",
            batteryPercent: 85,
            type: .headphones
        )
        let mouse = BluetoothObject.testDevice(
            address: "11:22:33:44:55:66",
            name: "Magic Mouse",
            batteryPercent: 60,
            type: .mouse
        )

        mockBluetoothService.simulateDeviceConnected(airpods)
        mockBluetoothService.simulateDeviceConnected(mouse)

        // Then device types should be correctly identified
        let foundAirpods = mockBluetoothService.list.first { $0.address == "aa-bb-cc-dd-ee-ff" }
        let foundMouse = mockBluetoothService.list.first { $0.address == "11-22-33-44-55-66" }

        XCTAssertEqual(foundAirpods?.type.type, .headphones)
        XCTAssertEqual(foundMouse?.type.type, .mouse)
    }

    // MARK: - Icon Tests

    @MainActor
    func testDeviceIcons() {
        // Given connected devices
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods Pro",
            batteryPercent: 85
        )
        mockBluetoothService.simulateDeviceConnected(device)

        // When checking icons
        let icons = mockBluetoothService.icons

        // Then icons should be populated
        // Note: Icon generation is tested through integration tests
        XCTAssertNotNil(icons)
    }

    // MARK: - Force Refresh Tests

    @MainActor
    func testForceRefresh() {
        // Given initial state
        XCTAssertEqual(mockBluetoothService.forceRefreshCallCount, 0)

        // When force refresh is called
        mockBluetoothService.forceRefresh()

        // Then refresh should be tracked
        XCTAssertEqual(mockBluetoothService.forceRefreshCallCount, 1)
    }

    // MARK: - Edge Cases

    @MainActor
    func testDuplicateDeviceConnection() {
        // Given a connected device
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "AirPods",
            batteryPercent: 80
        )
        mockBluetoothService.simulateDeviceConnected(device)
        XCTAssertEqual(mockBluetoothService.list.count, 1)

        // When same device connects again
        mockBluetoothService.simulateDeviceConnected(device)

        // Then should not duplicate
        XCTAssertEqual(mockBluetoothService.list.count, 1)
    }

    @MainActor
    func testDisconnectNonExistentDevice() {
        // Given an empty device list
        XCTAssertTrue(mockBluetoothService.connected.isEmpty)

        // When disconnecting a non-existent device
        mockBluetoothService.simulateDeviceDisconnected(address: "XX:YY:ZZ:AA:BB:CC")

        // Then should handle gracefully
        XCTAssertTrue(mockBluetoothService.connected.isEmpty)
    }

    @MainActor
    func testDeviceWithNilBattery() {
        // Given a device with unknown battery
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Unknown Device",
            batteryPercent: nil
        )
        mockBluetoothService.simulateDeviceConnected(device)

        // Then device should still be tracked
        XCTAssertEqual(mockBluetoothService.list.count, 1)
        XCTAssertNil(mockBluetoothService.list.first?.battery.percent)
    }
}
