//
//  ServiceCoordinator.swift
//  BatteryBoi
//
//  Handles cross-service communication and alert threshold logic.
//  Uses ObservationStream for reactive observation of @Observable services.
//

import Foundation

@MainActor
final class ServiceCoordinator {

    // MARK: - Dependencies

    private let battery: any BatteryServiceProtocol
    private let bluetooth: any BluetoothServiceProtocol
    private let settings: any SettingsServiceProtocol
    private let window: any WindowServiceProtocol
    private let events: any EventServiceProtocol

    // MARK: - Properties

    // SAFETY: nonisolated(unsafe) required because `isolated deinit` triggers a heap corruption
    // crash (StopLookupScope) on macOS 15.0–15.3 when back-deploying Swift 6.2 runtime features.
    // These properties are only accessed on @MainActor (read/written in startObserving/stopObserving/
    // deinit, all MainActor-isolated). The annotation bypasses the compiler's isolation check for
    // deinit access — the actual thread safety is guaranteed by MainActor serialization.
    // REMOVAL: Switch to `isolated deinit` when deployment target ≥ macOS 15.4.
    // BLAST RADIUS: Removing this without switching to `isolated deinit` causes a compiler error
    // (nonisolated deinit cannot access MainActor-isolated stored properties). Switching to
    // `isolated deinit` while min target < 15.4 risks the heap corruption crash at app teardown.
    nonisolated(unsafe) private var observationTasks: [Task<Void, Never>] = []
    private var notifiedBatteryThresholds: Set<Int> = []
    private var notifiedBluetoothThresholds: [String: Set<Int>] = [:]
    private var notifiedEventIdentifiers: Set<String> = []
    private var lastChargingState: BatteryChargingState?
    nonisolated(unsafe) private var chargingDebounceTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        battery: any BatteryServiceProtocol,
        bluetooth: any BluetoothServiceProtocol,
        settings: any SettingsServiceProtocol,
        window: any WindowServiceProtocol,
        events: any EventServiceProtocol
    ) {
        self.battery = battery
        self.bluetooth = bluetooth
        self.settings = settings
        self.window = window
        self.events = events
    }

    deinit {
        for task in observationTasks {
            task.cancel()
        }
        observationTasks.removeAll()
        chargingDebounceTask?.cancel()
    }

    // MARK: - Lifecycle

    func startObserving() {
        stopObserving()

        observeBatteryPercentage()
        observeBatteryCharging()
        observeBatteryThermal()
        observeBluetoothDevices()
        observeEvents()
        observeSettings()
    }

    func handleSleep() {
        stopObserving()
    }

    func handleWake() {
        stopObserving()
        notifiedBatteryThresholds.removeAll()
        notifiedBluetoothThresholds.removeAll()
        notifiedEventIdentifiers.removeAll()
        lastChargingState = nil
        chargingDebounceTask?.cancel()
        startObserving()
    }

    func stopObserving() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        chargingDebounceTask?.cancel()
        notifiedEventIdentifiers.removeAll()
    }

    // MARK: - Battery Observations

    private func observeBatteryPercentage() {
        let task = Task { [weak self] in
            guard let self else { return }
            var previousPercent = self.battery.percentage

            // Seed thresholds already crossed at observation start
            if self.battery.charging.state == .battery {
                for threshold in Constants.BatteryThresholds.alerts where previousPercent <= Double(threshold) {
                    self.notifiedBatteryThresholds.insert(threshold)
                }
            }

            for await currentPercent in ObservationStream.changes({ self.battery.percentage }) {
                guard !Task.isCancelled else { break }
                if currentPercent != previousPercent {
                    self.handlePercentageChange(to: currentPercent)
                    previousPercent = currentPercent
                }
            }
        }
        observationTasks.append(task)
    }

    private func observeBatteryCharging() {
        let task = Task { [weak self] in
            guard let self else { return }
            var previousCharging = self.battery.charging
            self.lastChargingState = previousCharging.state
            for await currentCharging in ObservationStream.changes({ self.battery.charging }) {
                guard !Task.isCancelled else { break }
                if currentCharging != previousCharging {
                    self.handleChargingChange(to: currentCharging)
                    previousCharging = currentCharging
                }
            }
        }
        observationTasks.append(task)
    }

    private func observeBatteryThermal() {
        let task = Task { [weak self] in
            guard let self else { return }
            var previousThermal = self.battery.thermal
            for await currentThermal in ObservationStream.changes({ self.battery.thermal }) {
                guard !Task.isCancelled else { break }
                if currentThermal != previousThermal {
                    if currentThermal == .suboptimal {
                        self.triggerAlert(.deviceOverheating, device: nil)
                    }
                    previousThermal = currentThermal
                }
            }
        }
        observationTasks.append(task)
    }

    // MARK: - Bluetooth Observations

    private func observeBluetoothDevices() {
        let task = Task { [weak self] in
            guard let self else { return }
            var previousConnected = self.bluetooth.connected
            for await currentConnected in ObservationStream.changes({ self.bluetooth.connected }) {
                guard !Task.isCancelled else { break }
                if currentConnected != previousConnected {
                    self.handleBluetoothChange(from: previousConnected, to: currentConnected)
                    previousConnected = currentConnected
                }
            }
        }
        observationTasks.append(task)

        let batteryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.Timers.bluetoothBatteryCheck))
            while !Task.isCancelled {
                guard let self, !Task.isCancelled else { break }
                self.checkBluetoothBatteryLevels()
                try? await Task.sleep(for: .seconds(Constants.Timers.bluetoothBatteryCheck))
            }
        }
        observationTasks.append(batteryTask)
    }

    // MARK: - Event Observations

    private func observeEvents() {
        let task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Constants.Timers.eventCheck))
            while !Task.isCancelled {
                guard let self, !Task.isCancelled else { break }
                self.checkUpcomingEvents()
                try? await Task.sleep(for: .seconds(Constants.Timers.eventCheck))
            }
        }
        observationTasks.append(task)
    }

    // MARK: - Settings Observations

    private func observeSettings() {
        let task = Task { [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledPinned, self.settings.pinned == .enabled {
                    self.window.opacity = 1.0
                }
            }
        }
        observationTasks.append(task)
    }

    // MARK: - Alert Threshold Logic

    private static let batteryAlertThresholds: [(Int, HUDAlertTypes)] = [
        (25, .percentTwentyFive),
        (10, .percentTen),
        (5, .percentFive),
        (1, .percentOne),
    ]

    private func handlePercentageChange(to current: Double) {
        if self.battery.charging.state == .battery {
            for (threshold, alertType) in Self.batteryAlertThresholds {
                if current <= Double(threshold), !notifiedBatteryThresholds.contains(threshold) {
                    notifiedBatteryThresholds.insert(threshold)
                    triggerAlert(alertType, device: nil)
                    break
                }
            }
        } else {
            if current >= 100, self.settings.chargeEighty == .disabled {
                triggerAlert(.chargingComplete, device: nil)
            } else if current >= 80, self.settings.chargeEighty == .enabled {
                triggerAlert(.chargingComplete, device: nil)
            }
        }
    }

    private func handleChargingChange(to current: BatteryCharging) {
        if current.state == .charging {
            notifiedBatteryThresholds.removeAll()
        }

        chargingDebounceTask?.cancel()
        chargingDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(Constants.Timers.chargingDebounce))
                guard let self, !Task.isCancelled else { return }
                let currentState = self.battery.charging.state
                switch currentState {
                case .battery: self.triggerAlert(.chargingStopped, device: nil)
                case .charging: self.triggerAlert(.chargingBegan, device: nil)
                }
            } catch {}
        }
    }

    private func handleBluetoothChange(from previous: [BluetoothObject], to current: [BluetoothObject]) {
        for device in current {
            if !previous.contains(where: { $0.address == device.address && $0.connected == .connected }),
               device.connected == .connected
            {
                triggerAlert(.deviceConnected, device: device)
            }
        }

        for device in previous where device.connected == .connected {
            if !current.contains(where: { $0.address == device.address && $0.connected == .connected }) {
                triggerAlert(.deviceRemoved, device: device)
            }
        }

        let currentAddresses = Set(current.map(\.address))
        notifiedBluetoothThresholds = notifiedBluetoothThresholds.filter { currentAddresses.contains($0.key) }
    }

    private func checkBluetoothBatteryLevels() {
        let connected = self.bluetooth.list.filter { $0.connected == .connected }

        for device in connected {
            guard let percent = device.battery.general else { continue }
            let deviceId = device.address

            if notifiedBluetoothThresholds[deviceId] == nil {
                notifiedBluetoothThresholds[deviceId] = []
            }

            for (threshold, alertType) in Self.batteryAlertThresholds {
                if percent <= Double(threshold),
                   !(notifiedBluetoothThresholds[deviceId]?.contains(threshold) ?? false)
                {
                    notifiedBluetoothThresholds[deviceId]?.insert(threshold)
                    triggerAlert(alertType, device: device)
                    break
                }
            }

            if percent > Constants.BatteryThresholds.bluetoothResetThreshold {
                notifiedBluetoothThresholds[deviceId]?.removeAll()
            }
        }
    }

    private func checkUpcomingEvents() {
        guard self.battery.charging.state == .battery else { return }
        let now = Date()
        guard let event = self.events.events
            .filter({ $0.start > now })
            .min(by: { $0.start < $1.start }) else { return }

        let minutes = event.start.timeIntervalSince(now) / 60.0
        if minutes >= 1, minutes <= 3, !notifiedEventIdentifiers.contains(event.id) {
            notifiedEventIdentifiers.insert(event.id)
            triggerAlert(.userEvent, device: nil)
        }
    }

    // MARK: - Alert Triggering

    private func triggerAlert(_ type: HUDAlertTypes, device: BluetoothObject?) {
        self.window.open(type, device: device)
    }
}
