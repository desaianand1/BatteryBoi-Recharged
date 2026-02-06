//
//  BluetoothModels.swift
//  BatteryBoi
//
//  Bluetooth-related model types extracted for Swift 6.2 architecture.
//

import Foundation

// MARK: - Connection State

enum BluetoothConnectionState: Sendable {
    case connected
    case disconnected
    case failed
    case unavailable
}

// MARK: - Vendor Identification

enum BluetoothVendor: String, Sendable {
    case apple = "0x004C"
    case samsung = "0x0050"
    case microsoft = "0x0052"
    case bose = "0x1001"
    case sennheiser = "0x1002"
    case sony = "0x1003"
    case jbl = "0x1004"
    case skullcandy = "0x1005"
    case beats = "0x1006"
    case jabra = "0x1007"
    case audioTechnica = "0x1008"
    case earfun = "0x3535"
    case akg = "0x0087"
    case plantronics = "0x0047"
    case logitech = "0x046D"
    case corsair = "0x1B1C"
    case anker = "0x3536"
    case bangOlufsen = "0x0089"
    case shure = "0x0088"
    case beyerdynamic = "0x008A"
    case razer = "0x1532"
    case steelseries = "0x1038"
    case hyperx = "0x0951"
    case unknown = ""
}

// MARK: - Distance Type

enum BluetoothDistanceType: Int, Sendable {
    case proximate
    case near
    case far
    case unknown
}

// MARK: - Device Object

struct BluetoothDeviceObject: Sendable {
    var type: BluetoothDeviceType
    var subtype: BluetoothDeviceSubtype?
    var vendor: BluetoothVendor?
    var icon: String

    init(_ type: String, subtype: String? = nil, vendor: String? = nil) {
        self.type = BluetoothDeviceType(rawValue: type.lowercased()) ?? .other
        self.subtype = BluetoothDeviceSubtype(rawValue: subtype ?? "")
        self.vendor = BluetoothVendor(rawValue: vendor ?? "")

        if let subtype = self.subtype, subtype != .unknown {
            icon = subtype.icon
        } else {
            icon = self.type.icon
        }
    }
}

// MARK: - Device Subtype

enum BluetoothDeviceSubtype: String, Sendable {
    case airpodsMax = "0x200A"
    case airpodsProVersionOne = "0x200E"
    case airpodsVersionTwo = "0x200F"
    case airpodsVersionOne = "0x2002"
    case unknown = ""

    var icon: String {
        switch self {
        case .airpodsMax: "headphones"
        case .airpodsProVersionOne: "airpods.gen3"
        default: "airpods"
        }
    }
}

// MARK: - Device Type

enum BluetoothDeviceType: String, Decodable, Sendable {
    case mouse
    case headphones
    case gamepad
    case speaker
    case keyboard
    case other

    var name: String {
        switch self {
        case .mouse: "BluetoothDeviceMouseLabel".localise()
        case .headphones: "BluetoothDeviceHeadphonesLabel".localise()
        case .gamepad: "BluetoothDeviceGamepadLabel".localise()
        case .speaker: "BluetoothDeviceSpeakerLabel".localise()
        case .keyboard: "BluetoothDeviceKeyboardLabel".localise()
        case .other: "BluetoothDeviceOtherLabel".localise()
        }
    }

    var icon: String {
        switch self {
        case .mouse: "magicmouse.fill"
        case .headphones: "headphones"
        case .gamepad: "gamecontroller.fill"
        case .speaker: "hifispeaker.2.fill"
        case .keyboard: "keyboard.fill"
        case .other: ""
        }
    }
}

// MARK: - Battery Object

struct BluetoothBatteryObject: Decodable, Equatable, Sendable {
    var general: Double?
    var left: Double?
    var right: Double?
    var percent: Double?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        general = nil
        left = nil
        right = nil
        percent = nil

        if let percent = try? values.decode(String.self, forKey: .general) {
            let stripped = percent.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            general = Double(stripped)
        }

        if let percent = try? values.decode(String.self, forKey: .right) {
            let stripped = percent.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            right = Double(stripped)
        }

        if let percent = try? values.decode(String.self, forKey: .left) {
            let stripped = percent.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            left = Double(stripped)
        }

        if left == nil, right == nil, general == nil {
            self.percent = nil
        } else if let min = [right, left, general].compactMap(\.self).min() {
            self.percent = min
        }
    }

    enum CodingKeys: String, CodingKey {
        case right = "device_batteryLevelRight"
        case left = "device_batteryLevelLeft"
        case enclosure = "device_batteryLevel"
        case general = "device_batteryLevelMain"
    }

    /// Initializer for creating from native IOKit battery percent
    init(percent: Int?) {
        general = percent.map { Double($0) }
        left = nil
        right = nil
        self.percent = general
    }
}

// MARK: - Bluetooth Object

struct BluetoothObject: Decodable, Equatable, Sendable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.address == rhs.address && lhs.connected == rhs.connected && lhs.distance == rhs.distance
    }

    let address: String
    let firmware: String?
    var battery: BluetoothBatteryObject
    let type: BluetoothDeviceObject
    var distance: BluetoothDistanceType

    var updated: Date
    var device: String?
    var connected: BluetoothState

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        battery = try BluetoothBatteryObject(from: decoder)
        address = try values.decode(String.self, forKey: .address).lowercased().replacingOccurrences(
            of: ":",
            with: "-"
        )
        firmware = try? values.decode(String.self, forKey: .firmware)
        connected = .disconnected
        device = nil
        updated = Date.distantPast

        if let distance = try? values.decode(String.self, forKey: .rssi) {
            if let value = Double(distance) {
                if value >= -50, value <= -20 {
                    self.distance = .proximate
                } else if value >= -70, value < -50 {
                    self.distance = .near
                } else {
                    self.distance = .far
                }
            } else {
                self.distance = .unknown
            }
        } else {
            distance = .unknown
        }

        if let type = try? values.decode(String.self, forKey: .type) {
            let subtype = try? values.decode(String.self, forKey: .product)
            let vendor = try? values.decode(String.self, forKey: .vendor)

            self.type = BluetoothDeviceObject(type, subtype: subtype, vendor: vendor)
        } else {
            type = BluetoothDeviceObject("")
        }
    }

    enum CodingKeys: String, CodingKey {
        case address = "device_address"
        case firmware = "device_firmwareVersion"
        case type = "device_minorType"
        case vendor = "device_vendorID"
        case product = "device_productID"
        case rssi = "device_rssi"
    }

    /// Initializer for creating BluetoothObject from native IOKit data
    init(
        address: String,
        name: String?,
        isConnected: Bool,
        batteryPercent: Int?,
        deviceType: String
    ) {
        self.address = address.lowercased().replacingOccurrences(of: ":", with: "-")
        firmware = nil
        battery = BluetoothBatteryObject(percent: batteryPercent)
        type = BluetoothDeviceObject(deviceType)
        distance = .unknown
        updated = Date()
        device = name
        connected = isConnected ? .connected : .disconnected
    }
}

typealias BluetoothObjectContainer = [String: BluetoothObject]

// MARK: - Bluetooth State

enum BluetoothState: Int, Sendable {
    case connected = 1
    case disconnected = 0

    var status: String {
        switch self {
        case .connected: "Connected"
        case .disconnected: "Not Connected"
        }
    }

    var boolean: Bool {
        switch self {
        case .connected: true
        case .disconnected: false
        }
    }
}
