//
//  BluetoothModelsTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for Bluetooth model types.
//

@testable import BatteryBoi___Recharged
@preconcurrency import XCTest

final class BluetoothModelsTests: XCTestCase {

    // MARK: - BluetoothConnectionState Tests

    @MainActor
    func testConnectionStateConnected() {
        let state: BluetoothConnectionState = .connected
        XCTAssertEqual(state, .connected)
    }

    @MainActor
    func testConnectionStateDisconnected() {
        let state: BluetoothConnectionState = .disconnected
        XCTAssertEqual(state, .disconnected)
    }

    @MainActor
    func testConnectionStateFailed() {
        let state: BluetoothConnectionState = .failed
        XCTAssertEqual(state, .failed)
    }

    @MainActor
    func testConnectionStateUnavailable() {
        let state: BluetoothConnectionState = .unavailable
        XCTAssertEqual(state, .unavailable)
    }

    // MARK: - BluetoothVendor Tests

    func testVendorApple() {
        let vendor = BluetoothVendor(rawValue: "0x004C")
        XCTAssertEqual(vendor, .apple)
    }

    func testVendorSamsung() {
        let vendor = BluetoothVendor(rawValue: "0x0050")
        XCTAssertEqual(vendor, .samsung)
    }

    func testVendorMicrosoft() {
        let vendor = BluetoothVendor(rawValue: "0x0052")
        XCTAssertEqual(vendor, .microsoft)
    }

    func testVendorBose() {
        let vendor = BluetoothVendor(rawValue: "0x1001")
        XCTAssertEqual(vendor, .bose)
    }

    func testVendorSennheiser() {
        let vendor = BluetoothVendor(rawValue: "0x1002")
        XCTAssertEqual(vendor, .sennheiser)
    }

    func testVendorSony() {
        let vendor = BluetoothVendor(rawValue: "0x1003")
        XCTAssertEqual(vendor, .sony)
    }

    func testVendorJBL() {
        let vendor = BluetoothVendor(rawValue: "0x1004")
        XCTAssertEqual(vendor, .jbl)
    }

    func testVendorBeats() {
        let vendor = BluetoothVendor(rawValue: "0x1006")
        XCTAssertEqual(vendor, .beats)
    }

    func testVendorLogitech() {
        let vendor = BluetoothVendor(rawValue: "0x046D")
        XCTAssertEqual(vendor, .logitech)
    }

    func testVendorRazer() {
        let vendor = BluetoothVendor(rawValue: "0x1532")
        XCTAssertEqual(vendor, .razer)
    }

    func testVendorSteelseries() {
        let vendor = BluetoothVendor(rawValue: "0x1038")
        XCTAssertEqual(vendor, .steelseries)
    }

    func testVendorCorsair() {
        let vendor = BluetoothVendor(rawValue: "0x1B1C")
        XCTAssertEqual(vendor, .corsair)
    }

    func testVendorUnknown() {
        let vendor = BluetoothVendor(rawValue: "0x9999")
        XCTAssertNil(vendor)
    }

    // MARK: - BluetoothDistanceType Tests

    func testDistanceProximate() {
        let distance: BluetoothDistanceType = .proximate
        XCTAssertEqual(distance.rawValue, 0)
    }

    func testDistanceNear() {
        let distance: BluetoothDistanceType = .near
        XCTAssertEqual(distance.rawValue, 1)
    }

    func testDistanceFar() {
        let distance: BluetoothDistanceType = .far
        XCTAssertEqual(distance.rawValue, 2)
    }

    func testDistanceUnknown() {
        let distance: BluetoothDistanceType = .unknown
        XCTAssertEqual(distance.rawValue, 3)
    }

    // MARK: - BluetoothDeviceType Tests

    @MainActor
    func testDeviceTypeMouse() {
        let type: BluetoothDeviceType = .mouse
        XCTAssertEqual(type.rawValue, "mouse")
        XCTAssertEqual(type.icon, "magicmouse.fill")
    }

    @MainActor
    func testDeviceTypeHeadphones() {
        let type: BluetoothDeviceType = .headphones
        XCTAssertEqual(type.rawValue, "headphones")
        XCTAssertEqual(type.icon, "headphones")
    }

    @MainActor
    func testDeviceTypeGamepad() {
        let type: BluetoothDeviceType = .gamepad
        XCTAssertEqual(type.rawValue, "gamepad")
        XCTAssertEqual(type.icon, "gamecontroller.fill")
    }

    @MainActor
    func testDeviceTypeSpeaker() {
        let type: BluetoothDeviceType = .speaker
        XCTAssertEqual(type.rawValue, "speaker")
        XCTAssertEqual(type.icon, "hifispeaker.2.fill")
    }

    @MainActor
    func testDeviceTypeKeyboard() {
        let type: BluetoothDeviceType = .keyboard
        XCTAssertEqual(type.rawValue, "keyboard")
        XCTAssertEqual(type.icon, "keyboard.fill")
    }

    @MainActor
    func testDeviceTypeOther() {
        let type: BluetoothDeviceType = .other
        XCTAssertEqual(type.rawValue, "other")
        XCTAssertEqual(type.icon, "")
    }

    // MARK: - BluetoothDeviceSubtype Tests

    @MainActor
    func testSubtypeAirpodsMax() {
        let subtype: BluetoothDeviceSubtype = .airpodsMax
        XCTAssertEqual(subtype.rawValue, "0x200A")
        XCTAssertEqual(subtype.icon, "headphones")
    }

    @MainActor
    func testSubtypeAirpodsPro() {
        let subtype: BluetoothDeviceSubtype = .airpodsProVersionOne
        XCTAssertEqual(subtype.rawValue, "0x200E")
        XCTAssertEqual(subtype.icon, "airpods.gen3")
    }

    @MainActor
    func testSubtypeAirpodsVersionOne() {
        let subtype: BluetoothDeviceSubtype = .airpodsVersionOne
        XCTAssertEqual(subtype.rawValue, "0x2002")
        XCTAssertEqual(subtype.icon, "airpods")
    }

    @MainActor
    func testSubtypeAirpodsVersionTwo() {
        let subtype: BluetoothDeviceSubtype = .airpodsVersionTwo
        XCTAssertEqual(subtype.rawValue, "0x200F")
        XCTAssertEqual(subtype.icon, "airpods")
    }

    // MARK: - BluetoothDeviceObject Tests

    @MainActor
    func testDeviceObjectWithType() {
        let deviceObj = BluetoothDeviceObject("mouse")
        XCTAssertEqual(deviceObj.type, .mouse)
        XCTAssertEqual(deviceObj.icon, "magicmouse.fill")
    }

    @MainActor
    func testDeviceObjectWithUnknownType() {
        let deviceObj = BluetoothDeviceObject("unknowntype")
        XCTAssertEqual(deviceObj.type, .other)
    }

    @MainActor
    func testDeviceObjectWithVendor() {
        let deviceObj = BluetoothDeviceObject("headphones", vendor: "0x004C")
        XCTAssertEqual(deviceObj.vendor, .apple)
    }

    // MARK: - BluetoothBatteryObject Tests

    @MainActor
    func testBatteryObjectWithPercent() {
        let battery = BluetoothBatteryObject(percent: 80)
        XCTAssertEqual(battery.general, 80.0)
        XCTAssertEqual(battery.percent, 80.0)
        XCTAssertNil(battery.left)
        XCTAssertNil(battery.right)
    }

    @MainActor
    func testBatteryObjectWithNilPercent() {
        let battery = BluetoothBatteryObject(percent: nil)
        XCTAssertNil(battery.general)
        XCTAssertNil(battery.percent)
    }

    // MARK: - BluetoothState Tests

    @MainActor
    func testBluetoothStateConnected() {
        let state: BluetoothState = .connected
        XCTAssertEqual(state.rawValue, 1)
        XCTAssertEqual(state.status, "Connected")
        XCTAssertTrue(state.boolean)
    }

    @MainActor
    func testBluetoothStateDisconnected() {
        let state: BluetoothState = .disconnected
        XCTAssertEqual(state.rawValue, 0)
        XCTAssertEqual(state.status, "Not Connected")
        XCTAssertFalse(state.boolean)
    }

    // MARK: - BluetoothObject Tests

    @MainActor
    func testBluetoothObjectInitialization() {
        let device = BluetoothObject(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Test Device",
            isConnected: true,
            batteryPercent: 75,
            deviceType: "headphones"
        )

        XCTAssertEqual(device.address, "aa-bb-cc-dd-ee-ff")
        XCTAssertEqual(device.device, "Test Device")
        XCTAssertEqual(device.connected, .connected)
        XCTAssertEqual(device.battery.percent, 75.0)
        XCTAssertEqual(device.type.type, .headphones)
    }

    @MainActor
    func testBluetoothObjectDisconnected() {
        let device = BluetoothObject(
            address: "11:22:33:44:55:66",
            name: "Disconnected Device",
            isConnected: false,
            batteryPercent: nil,
            deviceType: "mouse"
        )

        XCTAssertEqual(device.connected, .disconnected)
        XCTAssertNil(device.battery.percent)
    }

    @MainActor
    func testBluetoothObjectEquality() {
        let device1 = BluetoothObject(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Device 1",
            isConnected: true,
            batteryPercent: 80,
            deviceType: "headphones"
        )

        let device2 = BluetoothObject(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Device 2 (different name)",
            isConnected: true,
            batteryPercent: 50,
            deviceType: "mouse"
        )

        // Same address and connection state = equal (by design)
        XCTAssertEqual(device1.address, device2.address)
        XCTAssertEqual(device1.connected, device2.connected)
    }

    @MainActor
    func testBluetoothObjectAddressNormalization() {
        let device = BluetoothObject(
            address: "AA:BB:CC:DD:EE:FF",
            name: "Test",
            isConnected: true,
            batteryPercent: 50,
            deviceType: "headphones"
        )

        // Address should be normalized to lowercase with dashes
        XCTAssertEqual(device.address, "aa-bb-cc-dd-ee-ff")
    }

    // MARK: - Test Helpers Tests

    @MainActor
    func testTestDeviceHelper() {
        let device = BluetoothObject.testDevice()

        XCTAssertNotNil(device.device)
        XCTAssertEqual(device.connected, .connected)
        XCTAssertEqual(device.battery.percent, 75.0)
    }

    @MainActor
    func testTestDeviceWithCustomValues() {
        let device = BluetoothObject.testDevice(
            address: "11:22:33:44:55:66",
            name: "Custom Device",
            isConnected: false,
            batteryPercent: 25,
            type: .keyboard
        )

        XCTAssertEqual(device.device, "Custom Device")
        XCTAssertEqual(device.connected, .disconnected)
        XCTAssertEqual(device.battery.percent, 25.0)
        XCTAssertEqual(device.type.type, .keyboard)
    }
}
