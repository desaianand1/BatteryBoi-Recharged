//
//  MockSettingsService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock settings service for unit testing.
    @MainActor
    final class MockSettingsService: SettingsServiceProtocol {
        // MARK: - Observable Properties

        var menu: [SettingsActionObject]
        var display: SettingsDisplayType
        var sfx: SettingsSoundEffects
        var theme: SettingsTheme
        var pinned: SettingsPinned
        var charge: SettingsCharged

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
            display: SettingsDisplayType = .percent,
            sfx: SettingsSoundEffects = .enabled,
            theme: SettingsTheme = .system,
            pinned: SettingsPinned = .disabled,
            charge: SettingsCharged = .disabled,
            autoLaunch: SettingsStateValue = .enabled,
            style: BatteryStyle = .chunky,
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
            case .countdown:
                display = .percent
            case .percent:
                display = .empty
            case .empty:
                display = .cycle
            case .cycle:
                display = .hidden
            case .hidden:
                display = .countdown
            }
            return display
        }

        func performAction(_ action: SettingsActionObject) {
            performActionCallCount += 1
            lastPerformedAction = action
        }

        // MARK: - Test Simulation

        func simulateDisplayChange(_ newDisplay: SettingsDisplayType) {
            display = newDisplay
        }

        func simulatePinnedChange(_ newPinned: SettingsPinned) {
            pinned = newPinned
        }
    }

#endif
