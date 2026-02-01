import CoreData
import Foundation
import Logging

#if canImport(Sentry)
    import Sentry
#endif

struct StatsIcon {
    var name: String
    var system: Bool

}

enum StatsStateType: String {
    case charging
    case depleted
    case connected
    case disconnected

}

struct StatsDisplayObject {
    var standard: String?
    var overlay: String?

}

struct StatsContainerObject {
    var container: NSPersistentCloudKitContainer?
    var directory: URL?
    var parent: URL?

}

@Observable
@MainActor
final class StatsManager {
    static let shared = StatsManager()

    var display: String?
    var overlay: String?
    var title: String
    var subtitle: String

    // Async observation tasks
    private var userDefaultsTask: Task<Void, Never>?
    private var batteryObserverTask: Task<Void, Never>?
    private var bluetoothObserverTask: Task<Void, Never>?
    private var wattageTimerTask: Task<Void, Never>?

    nonisolated(unsafe) static var container: StatsContainerObject = {
        let object = "BBDataObject"
        let container = NSPersistentCloudKitContainer(name: object)

        var directory: URL?
        var subdirectory: URL?

        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last {
            let parent = support.appendingPathComponent("BatteryBoi")

            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)

                let file = parent.appendingPathComponent("\(object).sqlite")
                directory = file
                container.persistentStoreDescriptions = [
                    NSPersistentStoreDescription(url: file),
                ]

                subdirectory = parent
            } catch {
                BBLogger.stats.error("Error creating or setting SQLite store URL: \(error)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif

            }

        } else {
            BBLogger.stats.error("Error retrieving Application Support directory URL.")
            #if canImport(Sentry)
                SentrySDK.capture(message: "Failed to retrieve Application Support directory URL")
            #endif

        }

        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        } else {
            BBLogger.stats.warning("No persistent store description found.")
            #if canImport(Sentry)
                SentrySDK.capture(message: "No persistent store description found")
            #endif
        }

        container.loadPersistentStores(completionHandler: { storeDescription, error in
            if let error {
                BBLogger.stats.error("Error loading persistent stores: \(error)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif

            }

            if let path = directory {
                directory = storeDescription.url
                BBLogger.stats.debug("CoreData directory: \(directory?.absoluteString ?? "nil")")

            }

        })

        container.viewContext.automaticallyMergesChangesFromParent = true

        return .init(container: container, directory: directory, parent: subdirectory)

    }()

    init() {
        display = nil
        title = ""
        subtitle = ""

        // Observe UserDefaults changes
        userDefaultsTask = Task { @MainActor [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledDisplay {
                    display = statsDisplay
                    overlay = statsOverlay
                }
            }
        }

        // Observe battery-related state changes with polling
        batteryObserverTask = Task { @MainActor [weak self] in
            var prevAlert = AppManager.shared.alert
            var prevCharging = BatteryManager.shared.charging
            var prevPercentage = BatteryManager.shared.percentage
            var prevSaver = BatteryManager.shared.saver
            var prevThermal = BatteryManager.shared.thermal
            var prevDevice = AppManager.shared.device

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { break }

                var needsUpdate = false

                // Check alert changes
                let currentAlert = AppManager.shared.alert
                if currentAlert != prevAlert {
                    needsUpdate = true
                    prevAlert = currentAlert
                }

                // Check charging state changes
                let currentCharging = BatteryManager.shared.charging
                if currentCharging != prevCharging {
                    needsUpdate = true

                    // Store activity
                    Task {
                        switch currentCharging.state {
                        case .battery: await self.statsStore(.disconnected, device: nil)
                        case .charging: await self.statsStore(.connected, device: nil)
                        }
                    }

                    prevCharging = currentCharging
                }

                // Check percentage changes
                let currentPercentage = BatteryManager.shared.percentage
                if currentPercentage != prevPercentage {
                    needsUpdate = true

                    // Store activity
                    Task {
                        switch BatteryManager.shared.charging.state {
                        case .battery: await self.statsStore(.depleted, device: nil)
                        case .charging: await self.statsStore(.charging, device: nil)
                        }
                    }

                    prevPercentage = currentPercentage
                }

                // Check saver changes
                let currentSaver = BatteryManager.shared.saver
                if currentSaver != prevSaver {
                    needsUpdate = true
                    prevSaver = currentSaver
                }

                // Check thermal changes
                let currentThermal = BatteryManager.shared.thermal
                if currentThermal != prevThermal {
                    needsUpdate = true
                    prevThermal = currentThermal
                }

                // Check device changes
                let currentDevice = AppManager.shared.device
                if currentDevice?.address != prevDevice?.address {
                    title = statsTitle
                    subtitle = statsSubtitle
                    prevDevice = currentDevice
                }

                if needsUpdate {
                    display = statsDisplay
                    overlay = statsOverlay
                    title = statsTitle
                    subtitle = statsSubtitle
                }
            }
        }

        // Observe Bluetooth connection changes
        bluetoothObserverTask = Task { @MainActor [weak self] in
            var prevConnected = BluetoothManager.shared.connected
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { break }

                let currentConnected = BluetoothManager.shared.connected
                if currentConnected != prevConnected {
                    overlay = statsOverlay
                    title = statsTitle
                    subtitle = statsSubtitle

                    if let device = currentConnected.first(where: { $0.updated.now == true }) {
                        Task {
                            await self.statsStore(.depleted, device: device)
                        }
                    }

                    prevConnected = currentConnected
                }
            }
        }

        // Store wattage every hour
        wattageTimerTask = Task { @MainActor [weak self] in
            for await _ in AppManager.shared.appTimerAsync(3600) {
                guard let self, !Task.isCancelled else { break }
                await statsWattageStore()
            }
        }
    }

    deinit {
        userDefaultsTask?.cancel()
        batteryObserverTask?.cancel()
        bluetoothObserverTask?.cancel()
        wattageTimerTask?.cancel()
    }

    private var statsDisplay: String? {
        let display = SettingsManager.shared.enabledDisplay(false)
        let state = BatteryManager.shared.charging.state

        if state == .charging {
            if display == .empty {
                return nil

            }

        } else {
            if display == .empty {
                return nil

            } else if SettingsManager.shared.enabledDisplay() == .countdown {
                return statsCountdown

            } else if SettingsManager.shared.enabledDisplay() == .cycle {
                if let cycle = BatteryManager.shared.metrics?.cycles.formatted {
                    return cycle

                }

            }

        }

        return "\(Int(BatteryManager.shared.percentage))"

    }

    private var statsOverlay: String? {
        let state = BatteryManager.shared.charging.state

        if state == .charging {
            return nil

        } else {
            if SettingsManager.shared.enabledDisplay() == .countdown {
                return "\(Int(BatteryManager.shared.percentage))"

            } else if SettingsManager.shared.enabledDisplay() == .empty {
                return "\(Int(BatteryManager.shared.percentage))"

            } else {
                return statsCountdown

            }

        }

    }

    private var statsCountdown: String? {
        if let remaining = BatteryManager.shared.remaining, let hour = remaining.hours, let minute = remaining.minutes {
            if hour > 0, minute > 0 {
                return "+\(hour)\("TimestampHourAbbriviatedLabel".localise())"

            } else if hour > 0, minute == 0 {
                return "\(hour)\("TimestampHourAbbriviatedLabel".localise())"

            } else if hour == 0, minute > 0 {
                return "\(minute)\("TimestampMinuteAbbriviatedLabel".localise())"

            }

        }

        return nil

    }

    private var statsTitle: String {
        if let device = AppManager.shared.device {
            switch AppManager.shared.alert {
            case .deviceConnected: return "AlertDeviceConnectedTitle".localise()
            case .deviceRemoved: return "AlertDeviceDisconnectedTitle".localise()
            default: return device.device ?? device.type.type.name
            }

        } else {
            let percent = Int(BatteryManager.shared.percentage)
            let state = BatteryManager.shared.charging.state

            switch AppManager.shared.alert {
            case .chargingComplete: return "AlertChargingCompleteTitle".localise()
            case .chargingBegan: return "AlertChargingTitle".localise()
            case .chargingStopped: return "AlertChargingStoppedTitle".localise()
            case .percentFive: return "AlertSomePercentTitle".localise([percent])
            case .percentTen: return "AlertSomePercentTitle".localise([percent])
            case .percentTwentyFive: return "AlertSomePercentTitle".localise([percent])
            case .percentOne: return "AlertOnePercentTitle".localise()
            case .deviceConnected: return "AlertDeviceConnectedTitle".localise()
            case .deviceRemoved: return "AlertDeviceDisconnectedTitle".localise()
            case .deviceOverheating: return "AlertOverheatingTitle".localise()
            case .userEvent: return "AlertLimitedTitle".localise()
            default: break
            }

            if state == .battery {
                return "AlertSomePercentTitle".localise([percent])

            }

            return "AlertChargingTitle".localise()

        }

    }

    private var statsSubtitle: String {
        if let device = AppManager.shared.device {
            switch AppManager.shared.alert {
            case .deviceConnected: return device.device ?? device.type.type.name
            case .deviceRemoved: return device.device ?? device.type.type.name
            default: break
            }

            if let battery = device.battery.percent {
                return "AlertSomePercentTitle".localise([Int(battery)])

            }

            return "BluetoothInvalidLabel".localise()

        } else {
            let state = BatteryManager.shared.charging.state
            let percent = Int(BatteryManager.shared.percentage)
            let remaining = BatteryManager.shared.remaining
            let full = BatteryManager.shared.powerUntilFull
            let event = EventManager.shared.events.max(by: { $0.start < $1.start })

            switch AppManager.shared.alert {
            case .chargingComplete: return "AlertChargedSummary".localise()
            case .chargingBegan: return "AlertStartedChargeSummary"
                .localise([full?.time ?? "AlertDeviceUnknownTitle".localise()])
            case .chargingStopped: return "AlertEstimateSummary"
                .localise([remaining?.formatted ?? "AlertDeviceUnknownTitle".localise()])
            case .percentFive: return "AlertPercentSummary".localise()
            case .percentTen: return "AlertPercentSummary".localise()
            case .percentTwentyFive: return "AlertPercentSummary".localise()
            case .percentOne: return "AlertPercentSummary".localise()
            case .userEvent: return "AlertLimitedSummary".localise([event?.name ?? "Unknown Event"])
            case .deviceOverheating: return "AlertOverheatingSummary".localise()
            default: break
            }

            if state == .charging {
                switch percent {
                case 100: return "AlertChargedSummary".localise()
                default: return "AlertStartedChargeSummary"
                    .localise([full?.time ?? "AlertDeviceUnknownTitle".localise()])
                }

            }

            return "AlertEstimateSummary".localise([remaining?.formatted ?? "AlertDeviceUnknownTitle".localise()])

        }

    }

    var statsIcon: StatsIcon {
        if let device = AppManager.shared.device {
            .init(name: device.type.icon, system: true)

        } else {
            switch AppManager.shared.alert {
            case .deviceOverheating: .init(name: "OverheatIcon", system: false)
            case .userEvent: .init(name: "EventIcon", system: false)
            default: .init(name: "ChargingIcon", system: false)
            }

        }

    }

    private func statsContext() -> NSManagedObjectContext? {
        if let container = Self.container.container {
            let context = container.newBackgroundContext()
            context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

            return context

        }

        return nil

    }

    private func statsStore(_ state: StatsStateType, device: BluetoothObject?) async {
        guard let context = statsContext() else { return }

        // Capture values from MainActor context before switching
        let charge = if let percent = device {
            Int64(percent.battery.percent ?? 100)
        } else {
            Int64(BatteryManager.shared.percentage)
        }
        let deviceAddress = device?.address ?? ""

        await context.perform {
            let expiry = Date().addingTimeInterval(-2 * 60)

            let fetch = Activity.fetchRequest() as NSFetchRequest<Activity>
            fetch.includesPendingChanges = true
            fetch.predicate = NSPredicate(
                format: "state == %@ && device == %@ && charge == %d && timestamp > %@",
                state.rawValue,
                deviceAddress,
                charge,
                expiry as NSDate,
            )

            do {
                if try context.fetch(fetch).first == nil {
                    let store = Activity(context: context)
                    store.timestamp = Date()
                    store.device = deviceAddress
                    store.state = state.rawValue
                    store.charge = charge

                    try context.save()
                }
            } catch {
                BBLogger.stats.error("Error storing activity: \(error)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif
            }
        }
    }

    private func statsWattageStore() async {
        guard let context = statsContext() else { return }

        // Fetch wattage asynchronously before CoreData operation
        let wattage = await BatteryManager.shared.fetchPowerHourWattage() ?? 0.0
        let deviceName = AppManager.shared.appDeviceType.name

        await context.perform {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())

            guard let hour = calendar.date(from: components) else { return }

            let fetch = Wattage.fetchRequest() as NSFetchRequest<Wattage>
            fetch.includesPendingChanges = true
            fetch.predicate = NSPredicate(format: "timestamp == %@", hour as CVarArg)

            do {
                if try context.fetch(fetch).first == nil {
                    let store = Wattage(context: context)
                    store.timestamp = Date()
                    store.device = deviceName
                    store.wattage = wattage

                    try context.save()
                }
            } catch {
                BBLogger.stats.error("Failed to save CoreData wattage: \(error.localizedDescription)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif
            }
        }
    }

}
