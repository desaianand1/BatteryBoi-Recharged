//
//  ServiceCoordinator.swift
//  BatteryBoi
//
//  Handles cross-service communication and alert threshold logic.
//  Part of Swift 6.2 architecture redesign.
//

import Foundation

/// Coordinates cross-service communication and updates AppState.
/// Handles alert threshold logic that was previously in WindowManager.
@MainActor
final class ServiceCoordinator {
    // MARK: - Properties

    /// Reference to the service container (set during start)
    weak var container: ServiceContainer?

    /// Observation tasks (nonisolated for deinit access)
    nonisolated(unsafe) private var observationTasks: [Task<Void, Never>] = []

    /// Notified battery thresholds to avoid duplicate alerts
    private var notifiedBatteryThresholds: Set<Int> = []

    /// Notified Bluetooth device thresholds
    private var notifiedBluetoothThresholds: [String: Set<Int>] = [:]

    /// Last known charging state for debouncing
    private var lastChargingState: BatteryChargingState?

    /// Debounce task for charging state changes (nonisolated for deinit access)
    nonisolated(unsafe) private var chargingDebounceTask: Task<Void, Never>?

    // MARK: - Initialization

    init() {}

    deinit {
        // Cancel all tasks directly using nonisolated(unsafe) properties
        for task in observationTasks {
            task.cancel()
        }
        observationTasks.removeAll()
        chargingDebounceTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Start observing all service changes
    func startObserving() async {
        stopObserving()

        observeBatteryPercentage()
        observeBatteryCharging()
        observeBatteryThermal()
        observeBatteryMetrics()
        observeBluetoothDevices()
        observeEvents()
        observeSettings()
    }

    /// Stop all observation tasks
    func stopObserving() {
        observationTasks.forEach { $0.cancel() }
        observationTasks.removeAll()
        chargingDebounceTask?.cancel()
    }

    // MARK: - Battery Observations

    private func observeBatteryPercentage() {
        let task = Task { [weak self] in
            guard let self else { return }

            var previousPercent = BatteryService.shared.percentage
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }

                let currentPercent = BatteryService.shared.percentage

                // Update state
                guard let container = self.container else {
                    BLogger.app.warning("ServiceCoordinator: container not set, skipping percentage update")
                    continue
                }
                container.state.batteryPercentage = currentPercent

                if currentPercent != previousPercent {
                    self.handlePercentageChange(from: previousPercent, to: currentPercent)
                    previousPercent = currentPercent
                }
            }
        }
        observationTasks.append(task)
    }

    private func observeBatteryCharging() {
        let task = Task { [weak self] in
            // Small delay to let BatteryService initialize
            try? await Task.sleep(for: .milliseconds(100))
            guard let self, !Task.isCancelled else { return }

            var previousCharging = BatteryService.shared.charging
            self.lastChargingState = previousCharging.state

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }

                let currentCharging = BatteryService.shared.charging

                // Update state
                guard let container = self.container else {
                    BLogger.app.warning("ServiceCoordinator: container not set, skipping charging update")
                    continue
                }
                container.state.batteryCharging = currentCharging

                if currentCharging != previousCharging {
                    self.handleChargingChange(from: previousCharging, to: currentCharging)
                    previousCharging = currentCharging
                }
            }
        }
        observationTasks.append(task)
    }

    private func observeBatteryThermal() {
        let task = Task { [weak self] in
            var previousThermal = BatteryService.shared.thermal
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }

                let currentThermal = BatteryService.shared.thermal

                // Update state
                guard let container else {
                    BLogger.app.warning("ServiceCoordinator: container not set, skipping thermal update")
                    continue
                }
                container.state.batteryThermal = currentThermal

                if currentThermal != previousThermal {
                    if currentThermal == .suboptimal {
                        triggerAlert(.deviceOverheating, device: nil)
                    }
                    previousThermal = currentThermal
                }
            }
        }
        observationTasks.append(task)
    }

    private func observeBatteryMetrics() {
        let task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self, !Task.isCancelled else { break }

                // Update state
                guard let container else {
                    BLogger.app.warning("ServiceCoordinator: container not set, skipping metrics update")
                    continue
                }
                container.state.batteryTimeRemaining = BatteryService.shared.remaining
                container.state.batterySaver = BatteryService.shared.saver
                container.state.batteryMetrics = BatteryService.shared.metrics
                container.state.batteryRate = BatteryService.shared.rate
            }
        }
        observationTasks.append(task)
    }

    // MARK: - Bluetooth Observations

    private func observeBluetoothDevices() {
        let task = Task { [weak self] in
            var previousConnected = BluetoothService.shared.connected
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { break }

                // Update state
                guard let container else {
                    BLogger.app.warning("ServiceCoordinator: container not set, skipping Bluetooth update")
                    continue
                }
                container.state.bluetoothDevices = BluetoothService.shared.list
                container.state.bluetoothConnected = BluetoothService.shared.connected
                container.state.bluetoothIcons = BluetoothService.shared.icons

                let currentConnected = BluetoothService.shared.connected
                if currentConnected != previousConnected {
                    handleBluetoothChange(from: previousConnected, to: currentConnected)
                    previousConnected = currentConnected
                }
            }
        }
        observationTasks.append(task)

        // Check Bluetooth device battery levels every 60 seconds
        let batteryTask = Task { [weak self] in
            // Skip initial check
            try? await Task.sleep(for: .seconds(60))
            while !Task.isCancelled {
                guard let self, !Task.isCancelled else { break }
                checkBluetoothBatteryLevels()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        observationTasks.append(batteryTask)
    }

    // MARK: - Event Observations

    private func observeEvents() {
        let task = Task { [weak self] in
            // Skip initial check
            try? await Task.sleep(for: .seconds(30))
            while !Task.isCancelled {
                guard let self, !Task.isCancelled else { break }

                // Update state
                guard let container else {
                    BLogger.app.warning("ServiceCoordinator: container not set, skipping events update")
                    try? await Task.sleep(for: .seconds(30))
                    continue
                }
                container.state.events = EventService.shared.events

                // Check for upcoming events
                checkUpcomingEvents()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        observationTasks.append(task)
    }

    // MARK: - Settings Observations

    private func observeSettings() {
        let task = Task { [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledPinned, SettingsService.shared.pinned == .enabled {
                    guard let container else {
                        BLogger.app.warning("ServiceCoordinator: container not set, skipping settings update")
                        continue
                    }
                    container.state.windowOpacity = 1.0
                }
            }
        }
        observationTasks.append(task)
    }

    // MARK: - Alert Threshold Logic

    private func handlePercentageChange(from _: Double, to current: Double) {
        if BatteryService.shared.charging.state == .battery {
            // Low battery alerts
            let thresholds: [(Int, HUDAlertTypes)] = [
                (25, .percentTwentyFive),
                (10, .percentTen),
                (5, .percentFive),
                (1, .percentOne),
            ]

            for (threshold, alertType) in thresholds {
                if current <= Double(threshold), !notifiedBatteryThresholds.contains(threshold) {
                    notifiedBatteryThresholds.insert(threshold)
                    triggerAlert(alertType, device: nil)
                    break
                }
            }
        } else {
            // Charging complete alerts
            if current >= 100, SettingsService.shared.enabledChargeEighty == .disabled {
                triggerAlert(.chargingComplete, device: nil)
            } else if current >= 80, SettingsService.shared.enabledChargeEighty == .enabled {
                triggerAlert(.chargingComplete, device: nil)
            }
        }
    }

    private func handleChargingChange(from _: BatteryCharging, to current: BatteryCharging) {
        // Reset thresholds when charging starts
        if current.state == .charging {
            notifiedBatteryThresholds.removeAll()
        }

        // Debounce charging state change notification (2 seconds)
        chargingDebounceTask?.cancel()
        let newState = current.state
        chargingDebounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                switch newState {
                case .battery: triggerAlert(.chargingStopped, device: nil)
                case .charging: triggerAlert(.chargingBegan, device: nil)
                }
            } catch {
                // Task cancelled
            }
        }
    }

    private func handleBluetoothChange(from previous: [BluetoothObject], to current: [BluetoothObject]) {
        // Check for newly connected devices
        for device in current {
            if !previous.contains(where: { $0.address == device.address && $0.connected == .connected }),
               device.connected == .connected
            {
                triggerAlert(.deviceConnected, device: device)
            }
        }

        // Check for disconnected devices
        for device in previous where device.connected == .connected {
            if !current.contains(where: { $0.address == device.address && $0.connected == .connected }) {
                triggerAlert(.deviceRemoved, device: device)
            }
        }
    }

    private func checkBluetoothBatteryLevels() {
        let connected = BluetoothService.shared.list.filter { $0.connected == .connected }

        for device in connected {
            guard let percent = device.battery.general else { continue }
            let deviceId = device.address

            if notifiedBluetoothThresholds[deviceId] == nil {
                notifiedBluetoothThresholds[deviceId] = []
            }

            let thresholds: [(Int, HUDAlertTypes)] = [
                (25, .percentTwentyFive),
                (10, .percentTen),
                (5, .percentFive),
                (1, .percentOne),
            ]

            for (threshold, alertType) in thresholds {
                if percent <= Double(threshold),
                   !(notifiedBluetoothThresholds[deviceId]?.contains(threshold) ?? false)
                {
                    notifiedBluetoothThresholds[deviceId]?.insert(threshold)
                    triggerAlert(alertType, device: device)
                    break
                }
            }

            // Reset thresholds when battery is above 30%
            if percent > 30 {
                notifiedBluetoothThresholds[deviceId]?.removeAll()
            }
        }
    }

    private func checkUpcomingEvents() {
        if BatteryService.shared.charging.state == .battery {
            if let event = EventService.shared.events.max(by: { $0.start < $1.start }) {
                if let minutes = Calendar.current.dateComponents([.minute], from: Date(), to: event.start).minute {
                    if minutes == 2 {
                        triggerAlert(.userEvent, device: nil)
                    }
                }
            }
        }
    }

    // MARK: - Alert Triggering

    private func triggerAlert(_ type: HUDAlertTypes, device: BluetoothObject?) {
        WindowService.shared.open(type, device: device)
    }
}
