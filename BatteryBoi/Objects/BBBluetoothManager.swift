import Cocoa
import CoreBluetooth
import Foundation
import IOBluetooth
import IOKit.ps

#if canImport(Sentry)
    import Sentry
#endif

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
    // Additional audiophile/gaming brands
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

    /// Initializer for creating from native IOKit battery percent
    init(percent: Int?) {
        general = percent.map { Double($0) }
        left = nil
        right = nil
        self.percent = general
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

    var list = [BluetoothObject]()
    var connected = [BluetoothObject]()
    var icons = [String]()

    /// Updates derived state (connected devices, icons) after list modifications.
    /// Also cleans up disconnection notifications for devices no longer in list.
    /// Call this after batch updates to the list are complete.
    private func updateDerivedState() {
        connected = list.filter { $0.connected == .connected }
        icons = connected.map(\.type.icon)

        // Clean up disconnection notifications for devices no longer in the list
        let currentAddresses = Set(list.map(\.address))
        let staleAddresses = disconnectionNotifications.keys
            .filter { !currentAddresses.contains($0.lowercased().replacingOccurrences(
                of: ":",
                with: "-"
            )) }
        for address in staleAddresses {
            disconnectionNotifications[address]?.unregister()
            disconnectionNotifications.removeValue(forKey: address)
        }
    }

    nonisolated(unsafe) private var connectionNotification: IOBluetoothUserNotification?
    nonisolated(unsafe) private var disconnectionNotifications: [String: IOBluetoothUserNotification] = [:]
    nonisolated private var scanTimerTask: Task<Void, Never>?
    nonisolated private var deviceObserverTask: Task<Void, Never>?
    nonisolated private var bluetoothUpdateDebounceTask: Task<Void, Never>?

    // MARK: - BluetoothServiceProtocol Methods

    func updateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        bluetoothUpdateConnection(device, state: state)
    }

    func refreshDeviceList() async {
        await bluetoothListNative()
    }

    init() {
        // Scan for Bluetooth devices every 15 seconds using native IOKit
        scanTimerTask = Task { @MainActor [weak self] in
            var skipFirst = true
            for await _ in AppManager.shared.appTimerAsync(15) {
                guard let self, !Task.isCancelled else { break }
                if skipFirst { skipFirst = false; continue }

                await bluetoothListNative()
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
                        _ = bluetoothUpdateConnection(device, state: .connected)
                    }
                }
                previousDevice = currentDevice
            }
        }

        // Initial scan using native IOKit
        Task { @MainActor in
            await self.bluetoothListNative(initialize: true)

            switch self.list.filter({ $0.connected == .connected }).count {
            case 0: AppManager.shared.menu = .settings
            default: AppManager.shared.menu = .devices
            }
        }
    }

    deinit {
        connectionNotification?.unregister()
        disconnectionNotifications.values.forEach { $0.unregister() }
        scanTimerTask?.cancel()
        deviceObserverTask?.cancel()
        bluetoothUpdateDebounceTask?.cancel()
    }

    func bluetoothUpdateConnection(_ device: BluetoothObject, state: BluetoothState) -> BluetoothConnectionState {
        if let btDevice = IOBluetoothDevice(addressString: device.address) {
            if btDevice.isConnected() {
                if state == .connected {
                    return .connected

                } else {
                    let result = btDevice.closeConnection()
                    if result == kIOReturnSuccess {
                        return .disconnected

                    } else {
                        #if canImport(Sentry)
                            SentrySDK.capture(message: "Bluetooth disconnect failed") { scope in
                                scope.setExtra(value: device.address, key: "address")
                                scope.setExtra(value: result, key: "ioReturn")
                            }
                        #endif
                        return .failed

                    }

                }

            } else {
                if state == .connected {
                    let result = btDevice.openConnection()
                    if result == kIOReturnSuccess {
                        return .connected

                    } else {
                        #if canImport(Sentry)
                            SentrySDK.capture(message: "Bluetooth connect failed") { scope in
                                scope.setExtra(value: device.address, key: "address")
                                scope.setExtra(value: result, key: "ioReturn")
                            }
                        #endif
                        return .failed

                    }

                }

            }

        }

        return .unavailable

    }

    /// Refreshes the Bluetooth device list using native IOKit APIs.
    /// This replaces the Python script-based approach for better performance and reliability.
    private func bluetoothListNative(initialize: Bool = false) async {
        // Get device info from native IOKit service
        let devices = await IOKitBluetoothService.shared.getConnectedDevices()

        for deviceInfo in devices {
            // Include all devices regardless of type classification
            // Previously filtered out .other types, but users reported missing devices
            _ = BluetoothDeviceType(rawValue: deviceInfo.deviceType) ?? .other

            let normalizedAddress = deviceInfo.address

            // Check if device already exists in the list
            if let listIndex = list.firstIndex(where: { $0.address == normalizedAddress }) {
                // Update existing device
                var updated = list[listIndex]
                updated.device = deviceInfo.name
                updated.connected = deviceInfo.isConnected ? .connected : .disconnected

                // Update battery if we have new data
                if let percent = deviceInfo.batteryPercent, updated.battery.general == nil {
                    updated.battery = BluetoothBatteryObject(percent: percent)
                }

                updated.updated = Date()
                list[listIndex] = updated
            } else {
                // Add new device
                let newDevice = BluetoothObject(
                    address: normalizedAddress,
                    name: deviceInfo.name,
                    isConnected: deviceInfo.isConnected,
                    batteryPercent: deviceInfo.batteryPercent,
                    deviceType: deviceInfo.deviceType
                )

                list.append(newDevice)

                // Register for disconnect notifications
                if let btDevice = IOBluetoothDevice(addressString: normalizedAddress.replacingOccurrences(
                    of: "-",
                    with: ":"
                )),
                    disconnectionNotifications[normalizedAddress] == nil,
                    let notification = btDevice.register(
                        forDisconnectNotification: self,
                        selector: #selector(bluetoothDeviceUpdated)
                    )
                {
                    disconnectionNotifications[normalizedAddress] = notification
                }
            }
        }

        if initialize {
            connectionNotification = IOBluetoothDevice.register(
                forConnectNotifications: self,
                selector: #selector(bluetoothDeviceUpdated)
            )
        }

        updateDerivedState()
    }

    @objc
    private func bluetoothDeviceUpdated() {
        // Debounce rapid callbacks to prevent race conditions
        bluetoothUpdateDebounceTask?.cancel()
        bluetoothUpdateDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, !Task.isCancelled else { return }

            var didUpdate = false
            for item in IOBluetoothDevice.pairedDevices() {
                if let device = item as? IOBluetoothDevice {
                    if let index = list
                        .firstIndex(where: { $0.address == device.addressString?.normalizedBluetoothAddress })
                    {
                        let status: BluetoothState = device.isConnected() ? .connected : .disconnected
                        var update = list[index]

                        if update.connected != status {
                            update.updated = Date()
                            update.connected = status
                            list[index] = update
                            didUpdate = true
                        }
                    }
                }
            }

            if didUpdate {
                updateDerivedState()
            }
        }
    }

}
