//
//  MockSettingsService.swift
//  BatteryBoi
//
//  Mock implementation for unit testing.
//

import Combine
import Foundation

#if DEBUG

    /// Mock settings service for unit testing.
    @MainActor
    final class MockSettingsService: SettingsServiceProtocol {
        // MARK: - Published Properties

        var menu: [SettingsActionObject]
        var display: SettingsDisplayType
        var sfx: SettingsSoundEffects
        var theme: SettingsTheme
        var pinned: SettingsPinned
        var charge: SettingsCharged

        // MARK: - Publishers

        private let displaySubject = PassthroughSubject<SettingsDisplayType, Never>()
        private let sfxSubject = PassthroughSubject<SettingsSoundEffects, Never>()
        private let pinnedSubject = PassthroughSubject<SettingsPinned, Never>()

        var displayPublisher: AnyPublisher<SettingsDisplayType, Never> {
            displaySubject.eraseToAnyPublisher()
        }

        var sfxPublisher: AnyPublisher<SettingsSoundEffects, Never> {
            sfxSubject.eraseToAnyPublisher()
        }

        var pinnedPublisher: AnyPublisher<SettingsPinned, Never> {
            pinnedSubject.eraseToAnyPublisher()
        }

        // MARK: - Computed Properties

        var autoLaunch: SettingsStateValue
        var style: BatteryStyle
        var chargeEighty: SettingsCharged
        var progressBar: Bool
        var soundEffects: SettingsSoundEffects
        var bluetoothStatus: SettingsStateValue

        // MARK: - Test Helpers

        var toggleDisplayCallCount = 0
        var performActionCallCount = 0
        var lastPerformedAction: SettingsActionObject?

        // MARK: - Initialization

        init(
            menu: [SettingsActionObject] = [],
            display: SettingsDisplayType = .percentage,
            sfx: SettingsSoundEffects = .enabled,
            theme: SettingsTheme = .system,
            pinned: SettingsPinned = .disabled,
            charge: SettingsCharged = .disabled,
            autoLaunch: SettingsStateValue = .enabled,
            style: BatteryStyle = .modern,
            chargeEighty: SettingsCharged = .disabled,
            progressBar: Bool = true,
            soundEffects: SettingsSoundEffects = .enabled,
            bluetoothStatus: SettingsStateValue = .enabled,
        ) {
            self.menu = menu
            self.display = display
            self.sfx = sfx
            self.theme = theme
            self.pinned = pinned
            self.charge = charge
            self.autoLaunch = autoLaunch
            self.style = style
            self.chargeEighty = chargeEighty
            self.progressBar = progressBar
            self.soundEffects = soundEffects
            self.bluetoothStatus = bluetoothStatus
        }

        // MARK: - Methods

        @discardableResult
        func toggleDisplay() -> SettingsDisplayType {
            toggleDisplayCallCount += 1
            // Cycle through display types
            switch display {
            case .percentage:
                display = .time
            case .time:
                display = .hidden
            case .hidden:
                display = .percentage
            }
            displaySubject.send(display)
            return display
        }

        func performAction(_ action: SettingsActionObject) {
            performActionCallCount += 1
            lastPerformedAction = action
        }

        // MARK: - Test Simulation

        func simulateDisplayChange(_ newDisplay: SettingsDisplayType) {
            display = newDisplay
            displaySubject.send(newDisplay)
        }

        func simulatePinnedChange(_ newPinned: SettingsPinned) {
            pinned = newPinned
            pinnedSubject.send(newPinned)
        }
    }

#endif
