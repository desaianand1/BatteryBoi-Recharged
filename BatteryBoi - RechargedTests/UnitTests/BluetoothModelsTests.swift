//
//  BluetoothModelsTests.swift
//  BatteryBoi-RechargedTests
//
//  Unit tests for Bluetooth model types.
//

@testable import BatteryBoi___Recharged
import Testing
@preconcurrency import XCTest

// MARK: - Parameterized Bluetooth Tests

@Suite("BluetoothVendor raw value mapping")
struct BluetoothVendorTests {

    @Test(arguments: [
        ("0x004C", BluetoothVendor.apple),
        ("0x0050", BluetoothVendor.samsung),
        ("0x0052", BluetoothVendor.microsoft),
        ("0x1001", BluetoothVendor.bose),
        ("0x1002", BluetoothVendor.sennheiser),
        ("0x1003", BluetoothVendor.sony),
        ("0x1004", BluetoothVendor.jbl),
        ("0x1006", BluetoothVendor.beats),
        ("0x046D", BluetoothVendor.logitech),
        ("0x1532", BluetoothVendor.razer),
        ("0x1038", BluetoothVendor.steelseries),
        ("0x1B1C", BluetoothVendor.corsair),
    ])
    func `vendor from raw value`(rawValue: String, expected: BluetoothVendor) {
        #expect(BluetoothVendor(rawValue: rawValue) == expected)
    }

    @Test
    func `unknown vendor returns nil`() {
        #expect(BluetoothVendor(rawValue: "0x9999") == nil)
    }
}

@Suite("BluetoothDeviceType icon mapping")
@MainActor
struct BluetoothDeviceTypeTests {

    @Test(arguments: [
        (BluetoothDeviceType.mouse, "magicmouse.fill"),
        (BluetoothDeviceType.keyboard, "keyboard.fill"),
        (BluetoothDeviceType.headphones, "headphones"),
        (BluetoothDeviceType.gamepad, "gamecontroller.fill"),
        (BluetoothDeviceType.speaker, "hifispeaker.2.fill"),
        (BluetoothDeviceType.other, ""),
    ])
    func `device type icon`(type: BluetoothDeviceType, expectedIcon: String) {
        #expect(type.icon == expectedIcon)
    }
}

final class BluetoothModelsTests: XCTestCase {

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

    // MARK: - Vendor Display Name Tests

    @MainActor
    func testKnownVendorHasDisplayName() {
        XCTAssertEqual(BluetoothVendor.apple.name, "Apple")
        XCTAssertEqual(BluetoothVendor.sony.name, "Sony")
        XCTAssertEqual(BluetoothVendor.bose.name, "Bose")
    }

    @MainActor
    func testUnknownVendorHasNoDisplayName() {
        XCTAssertNil(BluetoothVendor.unknown.name)
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

    // MARK: - Multi-Battery Behavior Tests

    @MainActor
    func testMultiBatteryPercentUsesMinimum() {
        let battery = BluetoothBatteryObject(single: nil, left: 80, right: 60, chargingCase: 90)
        XCTAssertEqual(battery.percent, 60.0)
    }

    @MainActor
    func testSingleBatteryPercentUsesGeneral() {
        let battery = BluetoothBatteryObject(single: 90, left: nil, right: nil, chargingCase: nil)
        XCTAssertEqual(battery.percent, 90.0)
    }

    @MainActor
    func testAllNilBatteryReturnsNilPercent() {
        let battery = BluetoothBatteryObject(single: nil, left: nil, right: nil, chargingCase: nil)
        XCTAssertNil(battery.percent)
    }

    @MainActor
    func testChargingCaseDoesNotAffectPercent() {
        let battery = BluetoothBatteryObject(single: 70, left: nil, right: nil, chargingCase: 45)
        XCTAssertEqual(battery.percent, 70.0)
        XCTAssertEqual(battery.chargingCase, 45.0)
    }

    @MainActor
    func testLeftOnlyBatteryUsedAsPercent() {
        let battery = BluetoothBatteryObject(single: nil, left: 70, right: nil, chargingCase: nil)
        XCTAssertEqual(battery.percent, 70.0)
    }

    @MainActor
    func testRightOnlyBatteryUsedAsPercent() {
        let battery = BluetoothBatteryObject(single: nil, left: nil, right: 55, chargingCase: nil)
        XCTAssertEqual(battery.percent, 55.0)
    }

    @MainActor
    func testLeftRightAndSingleUsesOverallMinimum() {
        let battery = BluetoothBatteryObject(single: 50, left: 80, right: 60, chargingCase: nil)
        XCTAssertEqual(battery.percent, 50.0)
    }

    @MainActor
    func testBatteryEqualityIncludesChargingCase() {
        let a = BluetoothBatteryObject(single: 70, left: nil, right: nil, chargingCase: 90)
        let b = BluetoothBatteryObject(single: 70, left: nil, right: nil, chargingCase: 50)
        XCTAssertNotEqual(a, b)
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

    // MARK: - BluetoothDeviceType Computed Property Tests

    @MainActor
    func testAllDeviceTypeNamesAreNonEmpty() {
        for type in BluetoothDeviceType.allCases {
            XCTAssertFalse(type.name.isEmpty, "\(type) should have a non-empty name")
        }
    }

    @MainActor
    func testOtherDeviceTypeHasEmptyIcon() {
        XCTAssertEqual(BluetoothDeviceType.other.icon, "")
    }

    @MainActor
    func testKnownDeviceTypesHaveNonEmptyIcons() {
        for type in BluetoothDeviceType.allCases where type != .other {
            XCTAssertFalse(type.icon.isEmpty, "\(type) should have a non-empty icon")
        }
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

    // MARK: - Device Enrichment Tests

    @MainActor
    func testObjectWithVendorPopulatesCorrectly() {
        let device = BluetoothObject.testDevice(
            vendorID: 0x004C,
            productID: 0x200E
        )
        XCTAssertEqual(device.type.vendor, .apple)
        XCTAssertEqual(device.type.subtype, .airpodsProVersionOne)
    }

    @MainActor
    func testObjectWithNoBatteryIsValid() {
        let device = BluetoothObject.testDevice(batteryPercent: nil)
        XCTAssertNil(device.battery.percent)
        XCTAssertNotNil(device.device)
    }

    @MainActor
    func testObjectAddressUsesNormalizedExtension() {
        let device = BluetoothObject.testDevice(address: "AA:BB:CC:DD:EE:FF")
        XCTAssertEqual(device.address, "aa-bb-cc-dd-ee-ff")
    }
}
