//
//  StatsService.swift
//  BatteryBoi
//
//  Statistics service with Swift 6.2 strict concurrency.
//  Uses actor for CoreData background operations.
//

import CoreData
import Foundation
import Logging

#if canImport(Sentry)
    import Sentry
#endif

/// Service for managing statistics and CoreData operations.
/// Uses actor isolation for thread-safe CoreData access.
actor StatsService {
    // MARK: - Static Instance

    static let shared = StatsService()

    // MARK: - Properties

    /// CoreData container
    private let container: NSPersistentCloudKitContainer

    /// Container info
    private let containerInfo: StatsContainerObject

    // MARK: - MainActor Observable State

    /// Display text for menu bar
    @MainActor var display: String?

    /// Overlay text for menu bar
    @MainActor var overlay: String?

    /// HUD title
    @MainActor var title: String = ""

    /// HUD subtitle
    @MainActor var subtitle: String = ""

    // MARK: - Observation Tasks

    // Note: nonisolated(unsafe) is justified for task properties accessed in deinit per SE-0371

    nonisolated(unsafe) private var userDefaultsTask: Task<Void, Never>?
    nonisolated(unsafe) private var batteryObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var bluetoothObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var wattageTimerTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {
        let objectName = "DataObject"
        let persistentContainer = NSPersistentCloudKitContainer(name: objectName)

        var directory: URL?
        var subdirectory: URL?

        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).last {
            let parent = support.appendingPathComponent("BatteryBoi")

            do {
                try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true, attributes: nil)

                let file = parent.appendingPathComponent("\(objectName).sqlite")
                directory = file
                persistentContainer.persistentStoreDescriptions = [
                    NSPersistentStoreDescription(url: file),
                ]

                subdirectory = parent
            } catch {
                BLogger.stats.error("Error creating or setting SQLite store URL: \(error)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif
            }
        } else {
            BLogger.stats.error("Error retrieving Application Support directory URL.")
            #if canImport(Sentry)
                SentrySDK.capture(message: "Failed to retrieve Application Support directory URL")
            #endif
        }

        if let description = persistentContainer.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        } else {
            BLogger.stats.warning("No persistent store description found.")
            #if canImport(Sentry)
                SentrySDK.capture(message: "No persistent store description found")
            #endif
        }

        // Load stores synchronously during init
        persistentContainer.loadPersistentStores { storeDescription, error in
            if let error {
                BLogger.stats.error("Error loading persistent stores: \(error)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif
                return
            }

            persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

            if directory != nil {
                BLogger.stats.debug("CoreData directory: \(storeDescription.url?.absoluteString ?? "nil")")
            }
        }

        container = persistentContainer
        containerInfo = StatsContainerObject(directory: directory, parent: subdirectory)

        // Start observations after init
        Task { [weak self] in
            await self?.startObservations()
        }
    }

    deinit {
        userDefaultsTask?.cancel()
        batteryObserverTask?.cancel()
        bluetoothObserverTask?.cancel()
        wattageTimerTask?.cancel()
    }

    // MARK: - Observation Setup

    private func startObservations() {
        // Initialize display values immediately on main actor
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.display = self.statsDisplay
            self.overlay = self.statsOverlay
            self.title = self.statsTitle
            self.subtitle = self.statsSubtitle
            BLogger.stats.debug("Initialized stats - title: \(self.title), subtitle: \(self.subtitle)")
        }

        // Observe UserDefaults changes
        userDefaultsTask = Task { @MainActor [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledDisplay {
                    self.display = self.statsDisplay
                    self.overlay = self.statsOverlay
                }
            }
        }

        // Observe battery-related state changes
        batteryObserverTask = Task { [weak self] in
            var prevChargingState: Bool = await MainActor.run { BatteryService.shared.charging.state.charging }
            var prevPercentage: Double = await MainActor.run { BatteryService.shared.percentage }

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                guard let self, !Task.isCancelled else { break }

                let (currentChargingState, currentPercentage, currentState) = await MainActor.run {
                    (
                        BatteryService.shared.charging.state.charging,
                        BatteryService.shared.percentage,
                        BatteryService.shared.charging.state
                    )
                }

                var needsUpdate = false

                if currentChargingState != prevChargingState {
                    needsUpdate = true

                    // Store activity
                    switch currentState {
                    case .battery: await recordActivity(.disconnected, device: nil)
                    case .charging: await recordActivity(.connected, device: nil)
                    }

                    prevChargingState = currentChargingState
                }

                if currentPercentage != prevPercentage {
                    needsUpdate = true

                    // Store activity
                    switch currentState {
                    case .battery: await recordActivity(.depleted, device: nil)
                    case .charging: await recordActivity(.charging, device: nil)
                    }

                    prevPercentage = currentPercentage
                }

                if needsUpdate {
                    await MainActor.run {
                        self.display = self.statsDisplay
                        self.overlay = self.statsOverlay
                        self.title = self.statsTitle
                        self.subtitle = self.statsSubtitle
                    }
                }
            }
        }

        // Observe Bluetooth connection changes
        bluetoothObserverTask = Task { [weak self] in
            var prevConnected = await MainActor.run { BluetoothService.shared.connected }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { break }

                let currentConnected = await MainActor.run { BluetoothService.shared.connected }
                if currentConnected != prevConnected {
                    await MainActor.run {
                        self.overlay = self.statsOverlay
                        self.title = self.statsTitle
                        self.subtitle = self.statsSubtitle
                    }

                    // Check for recently updated device on MainActor
                    let recentDevice = await MainActor.run {
                        currentConnected.first(where: { $0.updated.now == true })
                    }
                    if let device = recentDevice {
                        await recordActivity(.depleted, device: device)
                    }

                    prevConnected = currentConnected
                }
            }
        }

        // Store wattage every hour
        wattageTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                guard let self, !Task.isCancelled else { break }
                await recordWattage()
            }
        }
    }

    // MARK: - Computed Properties (MainActor)

    @MainActor
    private var statsDisplay: String? {
        let displayType = SettingsService.shared.enabledDisplay(false)
        let state = BatteryService.shared.charging.state

        if state == .charging {
            if displayType == .empty {
                return nil
            }
        } else {
            if displayType == .empty {
                return nil
            } else if SettingsService.shared.enabledDisplay() == .countdown {
                return statsCountdown
            } else if SettingsService.shared.enabledDisplay() == .cycle {
                if let cycle = BatteryService.shared.metrics?.cycles.formatted {
                    return cycle
                }
            }
        }

        return "\(Int(BatteryService.shared.percentage))"
    }

    @MainActor
    private var statsOverlay: String? {
        let state = BatteryService.shared.charging.state

        if state == .charging {
            return nil
        } else {
            if SettingsService.shared.enabledDisplay() == .countdown {
                return "\(Int(BatteryService.shared.percentage))"
            } else if SettingsService.shared.enabledDisplay() == .empty {
                return "\(Int(BatteryService.shared.percentage))"
            } else {
                return statsCountdown
            }
        }
    }

    @MainActor
    private var statsCountdown: String? {
        if let remaining = BatteryService.shared.remaining, let hour = remaining.hours, let minute = remaining.minutes {
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

    @MainActor
    private var statsTitle: String {
        let appState = ServiceContainer.shared.state
        if let device = appState.selectedDevice {
            switch appState.currentAlert {
            case .deviceConnected: return "AlertDeviceConnectedTitle".localise()
            case .deviceRemoved: return "AlertDeviceDisconnectedTitle".localise()
            default: return device.device ?? device.type.type.name
            }
        } else {
            let percent = Int(BatteryService.shared.percentage)
            let state = BatteryService.shared.charging.state

            switch appState.currentAlert {
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

    @MainActor
    private var statsSubtitle: String {
        let appState = ServiceContainer.shared.state
        if let device = appState.selectedDevice {
            switch appState.currentAlert {
            case .deviceConnected: return device.device ?? device.type.type.name
            case .deviceRemoved: return device.device ?? device.type.type.name
            default: break
            }

            if let battery = device.battery.percent {
                return "AlertSomePercentTitle".localise([Int(battery)])
            }

            return "BluetoothInvalidLabel".localise()
        } else {
            let state = BatteryService.shared.charging.state
            let percent = Int(BatteryService.shared.percentage)
            let remaining = BatteryService.shared.remaining
            let full = BatteryService.shared.powerUntilFull
            let event = EventService.shared.events.max(by: { $0.start < $1.start })

            switch appState.currentAlert {
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

    @MainActor
    var statsIcon: StatsIcon {
        let appState = ServiceContainer.shared.state
        if let device = appState.selectedDevice {
            return StatsIcon(name: device.type.icon, system: true)
        } else {
            switch appState.currentAlert {
            case .deviceOverheating: return StatsIcon(name: "OverheatIcon", system: false)
            case .userEvent: return StatsIcon(name: "EventIcon", system: false)
            default: return StatsIcon(name: "ChargingIcon", system: false)
            }
        }
    }

    // MARK: - CoreData Operations

    func recordActivity(_ state: StatsStateType, device: BluetoothObject?) async {
        // Capture values immediately
        let stateRaw = state.rawValue
        let charge = await MainActor.run {
            if let percent = device {
                Int64(percent.battery.percent ?? 100)
            } else {
                Int64(BatteryService.shared.percentage)
            }
        }
        let deviceAddress = device?.address ?? ""

        // Perform CoreData work
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        await context.perform {
            let expiry = Date().addingTimeInterval(-2 * 60)

            // Use NSFetchRequest directly to avoid MainActor-isolated fetchRequest() method
            let fetch = NSFetchRequest<Activity>(entityName: "Activity")
            fetch.includesPendingChanges = true
            fetch.predicate = NSPredicate(
                format: "state == %@ && device == %@ && charge == %d && timestamp > %@",
                stateRaw,
                deviceAddress,
                charge,
                expiry as NSDate
            )

            do {
                if try context.fetch(fetch).first == nil {
                    let store = Activity(context: context)
                    store.timestamp = Date()
                    store.device = deviceAddress
                    store.state = stateRaw
                    store.charge = charge

                    try context.save()
                }
            } catch {
                BLogger.stats.error("Error storing activity: \(error)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif
            }
        }
    }

    private func recordWattage() async {
        // Capture values
        let wattage = await BatteryService.shared.fetchPowerHourWattage() ?? 0.0
        let deviceName = await MainActor.run { AppManager.shared.appDeviceType.name }

        // Perform CoreData work
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        await context.perform {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())

            guard let hour = calendar.date(from: components) else { return }

            // Use NSFetchRequest directly to avoid MainActor-isolated fetchRequest() method
            let fetch = NSFetchRequest<Wattage>(entityName: "Wattage")
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
                BLogger.stats.error("Failed to save CoreData wattage: \(error.localizedDescription)")
                #if canImport(Sentry)
                    SentrySDK.capture(error: error)
                #endif
            }
        }
    }
}
