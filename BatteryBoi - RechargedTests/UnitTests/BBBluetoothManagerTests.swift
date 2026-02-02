//
//  BBBluetoothManagerTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for Bluetooth manager functionality.
//

@testable import BatteryBoi___Recharged
import XCTest

final class BBBluetoothManagerTests: XCTestCase {

    // MARK: - Properties

    var mockBluetoothService: MockBluetoothService!

    // MARK: - Setup

    @MainActor
    override func setUp() {
        super.setUp()
        mockBluetoothService = MockBluetoothService()
    }

    override func tearDown() {
        mockBluetoothService = nil
        super.tearDown()
    }

    // MARK: - Device Type Tests

    func testDeviceTypeMouseFromClassName() {
        // Given a device class that represents a mouse
        let deviceType = BluetoothDeviceType.mouse

        // Then the type should have the correct icon
        XCTAssertEqual(deviceType.icon, "magicmouse.fill")
    }

    func testDeviceTypeKeyboardFromClassName() {
        // Given a device class that represents a keyboard
        let deviceType = BluetoothDeviceType.keyboard

        // Then the type should have the correct icon
        XCTAssertEqual(deviceType.icon, "keyboard.fill")
    }

    func testDeviceTypeHeadphonesFromClassName() {
        // Given a device class that represents headphones
        let deviceType = BluetoothDeviceType.headphones

        // Then the type should have the correct icon
        XCTAssertEqual(deviceType.icon, "headphones")
    }

    func testDeviceTypeGamepadFromClassName() {
        // Given a device class that represents a gamepad
        let deviceType = BluetoothDeviceType.gamepad

        // Then the type should have the correct icon
        XCTAssertEqual(deviceType.icon, "gamecontroller.fill")
    }

    func testDeviceTypeSpeakerFromClassName() {
        // Given a device class that represents a speaker
        let deviceType = BluetoothDeviceType.speaker

        // Then the type should have the correct icon
        XCTAssertEqual(deviceType.icon, "hifispeaker.2.fill")
    }

    // MARK: - Vendor Detection Tests

    func testVendorDetectionApple() {
        // Given an Apple vendor code
        let vendor = BluetoothVendor(rawValue: "0x004C")

        // Then it should be identified as Apple
        XCTAssertEqual(vendor, .apple)
    }

    func testVendorDetectionSony() {
        // Given a Sony vendor code
        let vendor = BluetoothVendor(rawValue: "0x1003")

        // Then it should be identified as Sony
        XCTAssertEqual(vendor, .sony)
    }

    func testVendorDetectionBose() {
        // Given a Bose vendor code
        let vendor = BluetoothVendor(rawValue: "0x1001")

        // Then it should be identified as Bose
        XCTAssertEqual(vendor, .bose)
    }

    func testVendorDetectionLogitech() {
        // Given a Logitech vendor code
        let vendor = BluetoothVendor(rawValue: "0x046D")

        // Then it should be identified as Logitech
        XCTAssertEqual(vendor, .logitech)
    }

    func testVendorDetectionRazer() {
        // Given a Razer vendor code
        let vendor = BluetoothVendor(rawValue: "0x1532")

        // Then it should be identified as Razer
        XCTAssertEqual(vendor, .razer)
    }

    func testVendorDetectionUnknown() {
        // Given an unknown vendor code
        let vendor = BluetoothVendor(rawValue: "0x9999")

        // Then it should be nil (unknown)
        XCTAssertNil(vendor)
    }

    // MARK: - Connection Tests

    @MainActor
    func testUpdateConnectionCallCount() {
        // Given a mock Bluetooth service
        let device = BluetoothObject.testDevice(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Test Device",
            batteryPercent: 75,
        )

        // When updating connection
        _ = mockBluetoothService.updateConnection(device, state: .connected)

        // Then the call should be tracked
        XCTAssertEqual(mockBluetoothService.updateConnectionCallCount, 1)
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
                batteryPercent: 80,
            ),
        ]
        mockBluetoothService.simulateListChange(devices)

        // Then the list should be updated
        XCTAssertEqual(mockBluetoothService.list.count, 1)
        XCTAssertEqual(mockBluetoothService.list.first?.device, "AirPods Pro")
    }

    // MARK: - Battery Left/Right Parsing Tests

    func testBatteryLeftRightParsing() {
        // Given a device with L/R battery info (AirPods-style)
        let battery = BluetoothBatteryObject(percent: 80.0, left: 85.0, right: 75.0)

        // Then left and right values should be accessible
        XCTAssertEqual(battery.left, 85.0)
        XCTAssertEqual(battery.right, 75.0)
        XCTAssertEqual(battery.percent, 75.0) // Minimum of all values
    }

    func testBatteryWithoutLeftRight() {
        // Given a device without L/R battery (single battery device)
        let battery = BluetoothBatteryObject(percent: 60.0)

        // Then left and right should be nil
        XCTAssertNil(battery.left)
        XCTAssertNil(battery.right)
        XCTAssertEqual(battery.percent, 60.0)
    }

    // MARK: - Refresh Tests

    @MainActor
    func testRefreshDeviceListCallCount() async {
        // Given a mock Bluetooth service
        XCTAssertEqual(mockBluetoothService.refreshDeviceListCallCount, 0)

        // When refreshing device list
        await mockBluetoothService.refreshDeviceList()

        // Then the call should be tracked
        XCTAssertEqual(mockBluetoothService.refreshDeviceListCallCount, 1)
    }
}
