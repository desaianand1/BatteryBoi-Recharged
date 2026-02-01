//
//  BBBluetoothManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/22/23.
//

import Cocoa
import Combine
import CoreBluetooth
import Foundation
import IOBluetooth
import IOKit.ps

enum BluetoothConnectionState {
    case connected
    case disconnected
    case failed
    case unavailable

}

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
    case unknown = ""

}

enum BluetoothScriptType: String {
    case profiler = "BBProfilerList"
    case oreg = "BBIOREGList"

}

enum BluetoothDistanceType: Int {
    case proximate
    case near
    case far
    case unknown

}

struct BluetoothDeviceObject {
    var type: BluetoothDeviceType
    var subtype: BluetoothDeviceSubtype?
    var vendor: BluetoothVendor?
    var icon: String

    init(_ type: String, subtype: String? = nil, vendor: String? = nil) {
        self.type = BluetoothDeviceType(rawValue: type.lowercased()) ?? .other
        self.subtype = BluetoothDeviceSubtype(rawValue: subtype ?? "")
        self.vendor = BluetoothVendor(rawValue: vendor ?? "")

        if let subtype = self.subtype {
            icon = subtype.icon

        } else {
            icon = self.type.icon

        }

    }

}

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

enum BluetoothDeviceType: String, Decodable {
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

struct BluetoothBatteryObject: Decodable, Equatable {
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
            percent = nil

        } else if let min = [right, left, general].compactMap(\.self).min() {
            percent = min

        }

    }

    enum CodingKeys: String, CodingKey {
        case right = "device_batteryLevelRight"
        case left = "device_batteryLevelLeft"
        case enclosure = "device_batteryLevel"
        case general = "device_batteryLevelMain"

    }

}

struct BluetoothObject: Decodable, Equatable {
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
            with: "-",
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
            let vendor = try? values.decode(String.self, forKey: .product)

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

}

typealias BluetoothObjectContainer = [String: BluetoothObject]

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

@Observable
@MainActor
final class BluetoothManager: BluetoothServiceProtocol {
    static let shared = BluetoothManager()

    var list = [BluetoothObject]() {
        didSet {
            // Update connected and icons whenever list changes
            connected = list.filter { $0.connected == .connected }
            icons = connected.map(\.type.icon)

            for device in list {
                print("\n\(device.device ?? "") (\(device.address)) - \(device.connected.status)")
            }
        }
    }

    var connected = [BluetoothObject]()
    var icons = [String]()

    private var connectionNotification: IOBluetoothUserNotification?
    private var disconnectionNotifications: [IOBluetoothUserNotification] = []
    private var scanTimerTask: Task<Void, Never>?
    private var deviceObserverTask: Task<Void, Never>?

    // MARK: - BluetoothServiceProtocol Publishers

    var listPublisher: AnyPublisher<[BluetoothObject], Never> {
        $list.eraseToAnyPublisher()
    }

    var connectedPublisher: AnyPublisher<[BluetoothObject], Never> {
        $connected.eraseToAnyPublisher()
    }

    // MARK: - BluetoothServiceProtocol Methods

    func updateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        bluetoothUpdateConnection(device, state: state)
    }

    func refreshDeviceList() async {
        await bluetoothList(.oreg)
        await bluetoothList(.profiler)
    }

    init() {
        // Scan for Bluetooth devices every 15 seconds
        scanTimerTask = Task { @MainActor [weak self] in
            var skipFirst = true
            for await _ in AppManager.shared.appTimerAsync(15) {
                guard let self, !Task.isCancelled else { break }
                if skipFirst { skipFirst = false; continue }

                await bluetoothList(.oreg)
                await bluetoothList(.profiler)
            }
        }

        // Observe device selection changes to auto-connect
        deviceObserverTask = Task { @MainActor [weak self] in
            var previousDevice: BluetoothObject?
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { break }

                let currentDevice = AppManager.shared.device
                if let device = currentDevice, device.address != previousDevice?.address {
                    if device.connected == .disconnected {
                        _ = bluetoothUpdateConnetion(device, state: .connected)
                    }
                }
                previousDevice = currentDevice
            }
        }

        // Initial scan
        Task { @MainActor in
            await self.bluetoothList(.oreg, initialize: true)
            await self.bluetoothList(.profiler)

            switch self.list.filter({ $0.connected == .connected }).count {
            case 0: AppManager.shared.menu = .settings
            default: AppManager.shared.menu = .devices
            }
        }
    }

    deinit {
        connectionNotification?.unregister()
        disconnectionNotifications.forEach { $0.unregister() }
        scanTimerTask?.cancel()
        deviceObserverTask?.cancel()
    }

    func bluetoothUpdateConnetion(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        if let device = IOBluetoothDevice(addressString: device.address) {
            if device.isConnected() {
                if state == .connected {
                    return .connected

                } else {
                    let result = device.closeConnection()
                    if result == kIOReturnSuccess {
                        return .disconnected

                    } else {
                        print("Failed to disconnect from the device. Error: \(result)")
                        return .failed

                    }

                }

            } else {
                if state == .connected {
                    let result = device.openConnection()
                    if result == kIOReturnSuccess {
                        return .connected

                    } else {
                        print("Failed to connect to the device. Error: \(result)")
                        return .failed

                    }

                }

            }

        }

        return .unavailable

    }

    private func bluetoothList(_ type: BluetoothScriptType, initialize: Bool = false) async {
        guard FileManager.default.fileExists(atPath: "/usr/bin/python3") else {
            print("Python not found at /usr/bin/python3")
            return
        }

        guard let script = Bundle.main.path(forResource: type.rawValue, ofType: "py") else {
            print("Script not found: \(type.rawValue)")
            return
        }

        do {
            let output = try await ProcessRunner.shared.run(
                executable: "/usr/bin/python3",
                arguments: [script],
                timeout: .seconds(30),
            )

            guard let data = output.data(using: .utf8) else { return }

            let object = try JSONDecoder().decode([BluetoothObjectContainer].self, from: data)
            let values = object.flatMap(\.values)

            await MainActor.run {
                for item in IOBluetoothDevice.pairedDevices() {
                    if let device = item as? IOBluetoothDevice {
                        if let index = values.firstIndex(where: { $0.address == device.addressString }) {
                            let status: BluetoothState = device.isConnected() ? .connected : .disconnected

                            var updated = values[index]
                            updated.device = device.name

                            if status != updated.connected {
                                updated.connected = status
                                updated.updated = Date()

                            }

                            if let listIndex = self.list.firstIndex(where: { $0.address == device.addressString }) {
                                if self.list[listIndex].battery.general != nil, updated.battery.general == nil {
                                    updated.battery.general = self.list[listIndex].battery.general
                                    updated.updated = Date()

                                }

                                if self.list[listIndex].battery.left != nil, updated.battery.left == nil {
                                    updated.battery.left = self.list[listIndex].battery.left
                                    updated.updated = Date()

                                }

                                if self.list[listIndex].battery.right != nil, updated.battery.right == nil {
                                    updated.battery.right = self.list[listIndex].battery.right
                                    updated.updated = Date()

                                }

                                if self.list[listIndex].battery.percent != nil, updated.battery.percent == nil {
                                    updated.battery.percent = self.list[listIndex].battery.percent
                                    updated.updated = Date()

                                }

                                if self.list[listIndex].distance != updated.distance {
                                    updated.distance = self.list[listIndex].distance
                                    updated.updated = Date()

                                }

                                self.list[listIndex] = updated

                            } else {
                                if updated.type.type != .other {
                                    self.list.append(updated)

                                }

                                if let notification = device.register(
                                    forDisconnectNotification: self,
                                    selector: #selector(self.bluetoothDeviceUpdated),
                                ) {
                                    self.disconnectionNotifications.append(notification)
                                }

                            }

                        }

                    }

                }

                if initialize == true {
                    self.connectionNotification = IOBluetoothDevice.register(
                        forConnectNotifications: self,
                        selector: #selector(self.bluetoothDeviceUpdated),
                    )

                }
            }

        } catch {
            print("Bluetooth list error: \(error)")

        }

    }

    @objc
    private func bluetoothDeviceUpdated() {
        for item in IOBluetoothDevice.pairedDevices() {
            if let device = item as? IOBluetoothDevice {
                if let index = list.firstIndex(where: { $0.address == device.addressString }) {
                    DispatchQueue.main.async {
                        let status: BluetoothState = device.isConnected() ? .connected : .disconnected
                        var update = self.list[index]

                        if update.connected != status {
                            update.updated = Date()
                            update.connected = status

                            self.list[index] = update

                        }

                    }

                }

            }

        }

    }

}
