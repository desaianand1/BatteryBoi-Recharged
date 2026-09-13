//
//  BluetoothModels.swift
//  BatteryBoi
//
//  Bluetooth-related model types extracted for Swift 6.2 architecture.
//

import Foundation

// MARK: - Connection State

enum BluetoothConnectionState {
    case connected
    case disconnected
    case failed
    case unavailable
    case restricted
}

// MARK: - Permission Status

enum BluetoothPermissionStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

// MARK: - Vendor Identification

enum BluetoothVendor: String {
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

    var name: String? {
        switch self {
        case .apple: "Apple"
        case .samsung: "Samsung"
        case .microsoft: "Microsoft"
        case .bose: "Bose"
        case .sennheiser: "Sennheiser"
        case .sony: "Sony"
        case .jbl: "JBL"
        case .skullcandy: "Skullcandy"
        case .beats: "Beats"
        case .jabra: "Jabra"
        case .audioTechnica: "Audio-Technica"
        case .earfun: "EarFun"
        case .akg: "AKG"
        case .plantronics: "Plantronics"
        case .logitech: "Logitech"
        case .corsair: "Corsair"
        case .anker: "Anker"
        case .bangOlufsen: "Bang & Olufsen"
        case .shure: "Shure"
        case .beyerdynamic: "Beyerdynamic"
        case .razer: "Razer"
        case .steelseries: "SteelSeries"
        case .hyperx: "HyperX"
        case .unknown: nil
        }
    }
}

// MARK: - Distance Type

enum BluetoothDistanceType: Int {
    case proximate
    case near
    case far
    case unknown
}

// MARK: - Device Object

struct BluetoothDeviceObject {
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

enum BluetoothDeviceSubtype: String {
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

enum BluetoothDeviceType: String, CaseIterable, Decodable {
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

struct BluetoothBatteryObject: Decodable, Equatable {
    var general: Double?
    var left: Double?
    var right: Double?
    var chargingCase: Double?
    var percent: Double?

    private static let numericRegex: NSRegularExpression = // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: "[^0-9]")

    private static func extractNumericValue(_ string: String) -> Double? {
        let range = NSRange(string.startIndex..., in: string)
        let stripped = numericRegex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
        return Double(stripped)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        general = nil
        left = nil
        right = nil
        chargingCase = nil
        percent = nil

        if let value = try? values.decode(String.self, forKey: .general) {
            general = Self.extractNumericValue(value)
        }

        if let value = try? values.decode(String.self, forKey: .right) {
            right = Self.extractNumericValue(value)
        }

        if let value = try? values.decode(String.self, forKey: .left) {
            left = Self.extractNumericValue(value)
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
        self.general = percent.map { Double($0) }
        self.left = nil
        self.right = nil
        self.chargingCase = nil
        self.percent = self.general
    }

    /// Initializer for multi-battery devices (TWS earbuds, AirPods with case)
    init(single: Int?, left: Int?, right: Int?, chargingCase: Int?) {
        self.general = single.map { Double($0) }
        self.left = left.map { Double($0) }
        self.right = right.map { Double($0) }
        self.chargingCase = chargingCase.map { Double($0) }
        let values = [self.general, self.left, self.right].compactMap(\.self)
        self.percent = values.min()
    }
}

// MARK: - Bluetooth Object

struct BluetoothObject: Decodable, Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.address == rhs.address && lhs.connected == rhs.connected && lhs.distance == rhs.distance
            && lhs.battery == rhs.battery
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
        address = try values.decode(String.self, forKey: .address).normalizedBluetoothAddress
        firmware = try? values.decode(String.self, forKey: .firmware)
        connected = .disconnected
        device = nil
        updated = Date.distantPast

        if let distance = try? values.decode(String.self, forKey: .rssi) {
            if let value = Double(distance) {
                if value >= Constants.Bluetooth.rssiProximateThreshold,
                   value <= Constants.Bluetooth.rssiMinimumThreshold
                {
                    self.distance = .proximate
                } else if value >= Constants.Bluetooth.rssiNearThreshold,
                          value < Constants.Bluetooth.rssiProximateThreshold
                {
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
        deviceType: String,
        batteryLeft: Int? = nil,
        batteryRight: Int? = nil,
        batteryCase: Int? = nil,
        vendorID: Int? = nil,
        productID: Int? = nil
    ) {
        self.address = address.normalizedBluetoothAddress
        self.firmware = nil
        self.battery = BluetoothBatteryObject(
            single: batteryPercent,
            left: batteryLeft,
            right: batteryRight,
            chargingCase: batteryCase
        )
        self.type = BluetoothDeviceObject(
            deviceType,
            subtype: productID.map { String(format: "0x%04X", $0) },
            vendor: vendorID.map { String(format: "0x%04X", $0) }
        )
        self.distance = .unknown
        self.updated = Date()
        self.device = name
        self.connected = isConnected ? .connected : .disconnected
    }
}

typealias BluetoothObjectContainer = [String: BluetoothObject]

// MARK: - Bluetooth State

enum BluetoothState: Int {
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
