//
//  SettingsServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the settings service interface.
/// Enables dependency injection and testability for user preferences.
@MainActor
protocol SettingsServiceProtocol: AnyObject {
    // MARK: - Observable Properties

    /// Available menu actions
    var menu: [SettingsActionObject] { get }

    /// Current display type setting
    var display: SettingsDisplayType { get }

    /// Sound effects setting
    var sfx: SettingsSoundEffects { get }

    /// Theme setting
    var theme: SettingsTheme { get set }

    /// Pinned mode setting
    var pinned: SettingsPinned { get set }

    /// Charge notification setting
    var charge: SettingsCharged { get set }

    // MARK: - Computed Properties

    /// Auto-launch at login state
    var autoLaunch: SettingsStateValue { get set }

    /// Battery icon style
    var style: BatteryStyle { get set }

    /// Charge at 80% notification enabled
    var chargeEighty: SettingsCharged { get set }

    /// Progress bar enabled
    var progressBar: Bool { get set }

    /// Sound effects enabled
    var soundEffects: SettingsSoundEffects { get set }

    /// Bluetooth status
    var bluetoothStatus: SettingsStateValue { get set }

    // MARK: - Methods

    /// Toggle display type to the next option
    /// - Returns: The new display type
    @discardableResult
    func toggleDisplay() -> SettingsDisplayType

    /// Perform a settings action
    /// - Parameter action: The action to perform
    func performAction(_ action: SettingsActionObject)
}
