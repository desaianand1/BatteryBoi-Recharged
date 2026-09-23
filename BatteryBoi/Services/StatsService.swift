//
//  StatsService.swift
//  BatteryBoi
//
//  Statistics service with @Observable @MainActor for reactive UI updates.
//  CoreData operations run off-MainActor via context.perform {}.
//

import CoreData
import Foundation
import Logging
import SwiftUI

#if canImport(Sentry)
    import Sentry
#endif

@Observable @MainActor
final class StatsService: StatsServiceProtocol {

    // MARK: - Dependencies

    private let battery: any BatteryServiceProtocol
    private let bluetooth: any BluetoothServiceProtocol
    private let settings: any SettingsServiceProtocol
    private let window: any WindowServiceProtocol
    private let events: any EventServiceProtocol
    private let app: any AppManagerProtocol

    // MARK: - Observable Properties

    var display: String?
    var overlay: String?

    var title: String {
        statsTitle
    }

    var subtitle: String {
        statsSubtitle
    }

    // MARK: - CoreData

    private let container: NSPersistentCloudKitContainer
    private let containerInfo: StatsContainerObject

    // MARK: - Observation Tasks

    private var userDefaultsTask: Task<Void, Never>?
    private var batteryObserverTask: Task<Void, Never>?
    private var bluetoothObserverTask: Task<Void, Never>?
    private var wattageTimerTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        battery: any BatteryServiceProtocol,
        bluetooth: any BluetoothServiceProtocol,
        settings: any SettingsServiceProtocol,
        window: any WindowServiceProtocol,
        events: any EventServiceProtocol,
        app: any AppManagerProtocol
    ) {
        self.battery = battery
        self.bluetooth = bluetooth
        self.settings = settings
        self.window = window
        self.events = events
        self.app = app

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

        startObservations()
    }

    isolated deinit {
        userDefaultsTask?.cancel()
        batteryObserverTask?.cancel()
        bluetoothObserverTask?.cancel()
        wattageTimerTask?.cancel()
    }

    // MARK: - Observation Setup

    private func startObservations() {
        self.display = self.statsDisplay
        self.overlay = self.statsOverlay
        BLogger.stats.debug("Initialized stats - title: \(self.title), subtitle: \(self.subtitle)")

        userDefaultsTask = Task { [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledDisplay {
                    self.display = self.statsDisplay
                    self.overlay = self.statsOverlay
                }
            }
        }

        batteryObserverTask = Task { [weak self] in
            guard let self else { return }
            var prevChargingState = self.battery.charging.state.charging
            var prevPercentage = self.battery.percentage
            var prevRemaining = self.battery.remaining

            for await (currentCharging, currentPercentage, currentRemaining) in ObservationStream.changes({
                (self.battery.charging.state.charging, self.battery.percentage, self.battery.remaining)
            }) {
                guard !Task.isCancelled else { break }

                var needsUpdate = false

                if currentCharging != prevChargingState {
                    needsUpdate = true

                    let state = self.battery.charging.state
                    switch state {
                    case .battery: await self.recordActivity(.disconnected, device: nil)
                    case .charging: await self.recordActivity(.connected, device: nil)
                    }

                    prevChargingState = currentCharging
                }

                if currentPercentage != prevPercentage {
                    needsUpdate = true

                    let state = self.battery.charging.state
                    switch state {
                    case .battery: await self.recordActivity(.depleted, device: nil)
                    case .charging: await self.recordActivity(.charging, device: nil)
                    }

                    prevPercentage = currentPercentage
                }

                if currentRemaining != prevRemaining {
                    needsUpdate = true
                    prevRemaining = currentRemaining
                }

                if needsUpdate {
                    self.display = self.statsDisplay
                    self.overlay = self.statsOverlay
                }
            }
        }

        bluetoothObserverTask = Task { [weak self] in
            guard let self else { return }
            var prevConnected = self.bluetooth.connected

            for await currentConnected in ObservationStream.changes({ self.bluetooth.connected }) {
                guard !Task.isCancelled else { break }

                if currentConnected != prevConnected {
                    self.overlay = self.statsOverlay

                    if let device = currentConnected.first(where: { $0.updated.now == true }) {
                        await self.recordActivity(.depleted, device: device)
                    }

                    prevConnected = currentConnected
                }
            }
        }

        wattageTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Constants.Timers.wattageRecord))
                guard let self, !Task.isCancelled else { break }
                await self.recordWattage()
            }
        }
    }

    // MARK: - Computed Properties (delegate to static pure functions)

    private var statsDisplay: String? {
        Self.computeDisplay(
            displayType: self.settings.enabledDisplay(false),
            chargingState: self.battery.charging.state,
            percentage: self.battery.percentage,
            countdown: Self.computeCountdown(remaining: self.battery.remaining),
            cycleFormatted: self.battery.metrics?.cycles.formatted
        )
    }

    private var statsOverlay: String? {
        Self.computeOverlay(
            displayType: self.settings.enabledDisplay(false),
            chargingState: self.battery.charging.state,
            percentage: self.battery.percentage,
            countdown: Self.computeCountdown(remaining: self.battery.remaining)
        )
    }

    private var statsTitle: String {
        if let device = self.window.currentDevice {
            switch self.window.currentAlert {
            case .deviceConnected: return "AlertDeviceConnectedTitle".localise()
            case .deviceRemoved: return "AlertDeviceDisconnectedTitle".localise()
            default: return device.device ?? device.type.type.name
            }
        }

        return Self.computeTitle(
            alert: self.window.currentAlert,
            chargingState: self.battery.charging.state,
            percentage: self.battery.percentage
        )
    }

    private var statsSubtitle: String {
        if let device = self.window.currentDevice {
            switch self.window.currentAlert {
            case .deviceConnected: return device.device ?? device.type.type.name
            case .deviceRemoved: return device.device ?? device.type.type.name
            default: break
            }

            if let battery = device.battery.percent {
                return "AlertSomePercentTitle".localise([Int(battery)])
            }

            return "BluetoothInvalidLabel".localise()
        }

        return Self.computeSubtitle(
            alert: self.window.currentAlert,
            chargingState: self.battery.charging.state,
            percentage: self.battery.percentage,
            remaining: self.battery.remaining,
            untilFull: self.battery.untilFull,
            latestEventName: self.events.events.max(by: { $0.start < $1.start })?.name
        )
    }

    // MARK: - Pure Static Computations

    static func computeCountdown(remaining: BatteryRemaining?) -> String? {
        guard let remaining,
              let hour = remaining.hours,
              let minute = remaining.minutes
        else {
            return nil
        }

        if hour > 0, minute > 0 {
            return "+\(hour)\("TimestampHourAbbriviatedLabel".localise())"
        } else if hour > 0, minute == 0 {
            return "\(hour)\("TimestampHourAbbriviatedLabel".localise())"
        } else if hour == 0, minute > 0 {
            return "\(minute)\("TimestampMinuteAbbriviatedLabel".localise())"
        }

        return nil
    }

    static func computeTitle(
        alert: HUDAlertTypes?,
        chargingState: BatteryChargingState,
        percentage: Double
    ) -> String {
        let percent = Int(percentage)

        switch alert {
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

        if chargingState == .charging, percent >= 100 {
            return "AlertChargingCompleteTitle".localise()
        }

        if chargingState == .battery {
            return "AlertSomePercentTitle".localise([percent])
        }

        return "AlertChargingTitle".localise()
    }

    // swiftlint:disable:next function_parameter_count
    static func computeSubtitle(
        alert: HUDAlertTypes?,
        chargingState: BatteryChargingState,
        percentage: Double,
        remaining: BatteryRemaining?,
        untilFull: Date?,
        latestEventName: String?
    ) -> String {
        let percent = Int(percentage)

        switch alert {
        case .chargingComplete: return "AlertChargedSummary".localise()
        case .chargingBegan: return Self.chargeTimeSummary(untilFull: untilFull)
        case .chargingStopped: return "AlertEstimateSummary"
            .localise([remaining?.formatted ?? "AlertDeviceCalculatingTitle".localise()])
        case .percentFive: return "AlertPercentSummary".localise()
        case .percentTen: return "AlertPercentSummary".localise()
        case .percentTwentyFive: return "AlertPercentSummary".localise()
        case .percentOne: return "AlertPercentSummary".localise()
        case .userEvent: return "AlertLimitedSummary".localise([latestEventName ?? "Unknown Event"])
        case .deviceOverheating: return "AlertOverheatingSummary".localise()
        default: break
        }

        if chargingState == .charging {
            switch percent {
            case 100: return "AlertChargedSummary".localise()
            default: return Self.chargeTimeSummary(untilFull: untilFull)
            }
        }

        return "AlertEstimateSummary".localise([remaining?.formatted ?? "AlertDeviceCalculatingTitle".localise()])
    }

    private static func chargeTimeSummary(untilFull: Date?) -> String {
        guard let untilFull, untilFull > Date() else {
            return "AlertStartedChargeSummary"
                .localise(["AlertDeviceCalculatingTitle".localise()])
        }
        if untilFull.isTomorrow {
            return "AlertStartedChargeTomorrowSummary"
                .localise([untilFull.time])
        }
        return "AlertStartedChargeSummary"
            .localise([untilFull.time])
    }

    static func computeDisplay(
        displayType: SettingsDisplayType,
        chargingState: BatteryChargingState,
        percentage: Double,
        countdown: String?,
        cycleFormatted: String?
    ) -> String? {
        if displayType == .hidden || displayType == .empty {
            return nil
        }

        if chargingState != .charging {
            if displayType == .countdown {
                return countdown ?? "\(Int(percentage))"
            } else if displayType == .cycle {
                if let cycle = cycleFormatted {
                    return cycle
                }
            }
        }

        return "\(Int(percentage))"
    }

    static func computeOverlay(
        displayType: SettingsDisplayType,
        chargingState: BatteryChargingState,
        percentage: Double,
        countdown: String?
    ) -> String? {
        if displayType == .hidden || chargingState == .charging {
            return nil
        }

        if displayType == .countdown || displayType == .empty {
            return "\(Int(percentage))"
        }

        return countdown
    }

    var statsIcon: StatsIcon {
        if let device = self.window.currentDevice {
            let tier = BatteryTier(percent: device.battery.percent ?? 100)
            return StatsIcon(name: device.type.icon, color: tier.dotColor, effect: .none)
        }

        switch self.window.currentAlert {
        case .chargingBegan:
            return StatsIcon(
                name: "bolt.fill",
                color: BatteryTier.chargingBoltColor,
                effect: .pulseByLayer
            )
        case .chargingComplete:
            return StatsIcon(
                name: "checkmark.circle.fill",
                color: Color(red: 0.357, green: 1.0, blue: 0.878),
                effect: .bounce
            )
        case .chargingStopped:
            return StatsIcon(
                name: "bolt.slash.fill",
                color: Color(red: 1.0, green: 0.722, blue: 0.0),
                effect: .none
            )
        case .percentOne:
            return StatsIcon(
                name: "battery.0percent",
                color: Color(red: 1.0, green: 0.176, blue: 0.333),
                effect: .pulseByLayer
            )
        case .percentFive:
            return StatsIcon(
                name: "battery.25percent",
                color: Color(red: 1.0, green: 0.231, blue: 0.188),
                effect: .pulse
            )
        case .percentTen:
            return StatsIcon(
                name: "battery.25percent",
                color: Color(red: 1.0, green: 0.420, blue: 0.0),
                effect: .none
            )
        case .percentTwentyFive:
            return StatsIcon(
                name: "battery.50percent",
                color: Color(red: 1.0, green: 0.722, blue: 0.0),
                effect: .none
            )
        case .deviceConnected:
            return StatsIcon(
                name: self.window.currentDevice?.type.icon ?? "antenna.radiowaves.left.and.right",
                color: Color(red: 0.290, green: 0.871, blue: 0.502),
                effect: .none
            )
        case .deviceRemoved:
            return StatsIcon(
                name: self.window.currentDevice?.type.icon ?? "antenna.radiowaves.left.and.right",
                color: .gray,
                effect: .none
            )
        case .deviceOverheating:
            return StatsIcon(
                name: "thermometer.sun.fill",
                color: Color(red: 1.0, green: 0.176, blue: 0.333),
                effect: .variableColor
            )
        case .userEvent:
            return StatsIcon(
                name: "calendar",
                color: .gray,
                effect: .none
            )
        case let .percentCustom(p):
            let tier = AlertThresholdTier.tier(for: p)
            return StatsIcon(
                name: tier == .critical ? "battery.0percent" : "battery.25percent",
                color: tier.dotColor,
                effect: tier == .critical ? .pulseByLayer : .none
            )
        case .userLaunched, .userInitiated, .none:
            let tier = BatteryTier(percent: self.battery.percentage)
            let iconName = self.batteryIconName(for: self.battery.percentage)
            return StatsIcon(name: iconName, color: tier.dotColor, effect: .none)
        }
    }

    private func batteryIconName(for percentage: Double) -> String {
        switch percentage {
        case ...10: "battery.0percent"
        case 11 ... 35: "battery.25percent"
        case 36 ... 65: "battery.50percent"
        case 66 ... 90: "battery.75percent"
        default: "battery.100percent"
        }
    }

    // MARK: - CoreData Operations

    func recordActivity(_ state: StatsStateType, device: BluetoothObject?) async {
        let stateRaw = state.rawValue
        let charge = if let device {
            Int64(device.battery.percent ?? 100)
        } else {
            Int64(self.battery.percentage)
        }
        let deviceAddress = device?.address ?? ""

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        await context.perform {
            let expiry = Date().addingTimeInterval(-2 * 60)

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
        let wattage = self.battery.fetchHourWattage() ?? 0.0
        let deviceName = self.app.appDeviceType.name

        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

        await context.perform {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour], from: Date())

            guard let hour = calendar.date(from: components) else { return }

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
