//
//  SettingsService.swift
//  BatteryBoi
//
//  Settings service with proper task lifecycle management.
//

import AppKit
import Foundation
import ServiceManagement
import SwiftUI

/// Service for managing user settings and preferences.
/// MainActor isolated for Swift 6.2 strict concurrency compliance.
@Observable
@MainActor
final class SettingsService: SettingsServiceProtocol {
    // MARK: - Static Instance

    static let shared = SettingsService()

    // MARK: - Observable Properties

    var menu: [SettingsActionObject] = []
    var display: SettingsDisplayType = .countdown
    var sfx: SettingsSoundEffects = .enabled
    var theme: SettingsTheme = .dark
    var pinned: SettingsPinned = .disabled
    var charge: SettingsCharged = .disabled

    // MARK: - Private Properties

    /// Cached distribution type to avoid async call in computed property
    private let isDirectDistribution: Bool

    /// Settings observation task (nonisolated(unsafe) for deinit access per SE-0371)
    nonisolated(unsafe) private var settingsTask: Task<Void, Never>?

    // MARK: - SettingsServiceProtocol Computed Properties

    var autoLaunch: SettingsStateValue {
        get { enabledAutoLaunch }
        set { enabledAutoLaunch = newValue }
    }

    var style: BatteryStyle {
        get { enabledStyle }
        set { enabledStyle = newValue }
    }

    var chargeEighty: SettingsCharged {
        get { enabledChargeEighty }
        set { enabledChargeEighty = newValue }
    }

    var progressBar: Bool {
        get { enabledProgressBar }
        set { enabledProgressBar = newValue }
    }

    var soundEffects: SettingsSoundEffects {
        get { enabledSoundEffects }
        set { enabledSoundEffects = newValue }
    }

    var bluetoothStatus: SettingsStateValue {
        get { enabledBluetoothStatus }
        set { enabledBluetoothStatus = newValue }
    }

    // MARK: - Initialization

    init() {
        // Cache distribution type synchronously at init
        isDirectDistribution = !Self.isAppStoreDistribution()

        menu = settingsMenu
        display = enabledDisplay(false)
        theme = enabledTheme
        sfx = enabledSoundEffects
        pinned = enabledPinned
        charge = enabledChargeEighty

        startObserving()
    }

    deinit {
        settingsTask?.cancel()
    }

    // MARK: - SettingsServiceProtocol Methods

    @discardableResult
    func toggleDisplay() -> SettingsDisplayType {
        let newDisplay = enabledDisplay()
        display = newDisplay
        return newDisplay
    }

    func performAction(_ action: SettingsActionObject) {
        settingsAction(action)
    }

    // MARK: - Private Methods

    private func startObserving() {
        settingsTask = Task(name: "SettingsService.observe") { [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                switch key {
                case .enabledDisplay: display = enabledDisplay(false)
                case .enabledTheme: theme = enabledTheme
                case .enabledSoundEffects: sfx = enabledSoundEffects
                case .enabledPinned: pinned = enabledPinned
                case .enabledChargeEighty: charge = enabledChargeEighty
                default: break
                }
            }
        }
    }

    private static func isAppStoreDistribution() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }

    // MARK: - Auto Launch

    var enabledAutoLaunch: SettingsStateValue {
        get {
            if UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledLogin.rawValue) == nil {
                .undetermined
            } else {
                switch SMAppService.mainApp.status == .enabled {
                case true: .enabled
                case false: .disabled
                }
            }
        }

        set {
            if enabledAutoLaunch != .undetermined {
                do {
                    if newValue == .disabled {
                        if SMAppService.mainApp.status == .enabled {
                            try SMAppService.mainApp.unregister()
                        }
                    } else {
                        if SMAppService.mainApp.status != .enabled {
                            try SMAppService.mainApp.register()
                        }
                    }

                    UserDefaults.save(.enabledLogin, value: newValue.enabled)
                } catch {
                    // Error registering/unregistering login item
                }
            }
        }
    }

    // MARK: - Display

    func enabledDisplay(_ toggle: Bool = false) -> SettingsDisplayType {
        var output: SettingsDisplayType = .percent

        if let type = UserDefaults.main.string(forKey: SystemDefaultsKeys.enabledDisplay.rawValue) {
            output = SettingsDisplayType(rawValue: type) ?? .percent
        }

        if toggle {
            switch output {
            case .countdown: output = .percent
            case .percent: output = .empty
            case .empty: output = .cycle
            case .cycle: output = .hidden
            default: output = .countdown
            }

            UserDefaults.save(.enabledDisplay, value: output.rawValue)
        }

        switch output {
        case .hidden: NSApp.setActivationPolicy(.regular)
        default: NSApp.setActivationPolicy(.accessory)
        }

        return output
    }

    // MARK: - Style

    var enabledStyle: BatteryStyle {
        get {
            if let style = UserDefaults.main.string(forKey: SystemDefaultsKeys.enabledStyle.rawValue) {
                return BatteryStyle(rawValue: style) ?? .chunky
            }
            return .chunky
        }

        set {
            if enabledStyle != newValue {
                UserDefaults.save(.enabledStyle, value: newValue)
            }
        }
    }

    // MARK: - Theme

    var enabledTheme: SettingsTheme {
        get {
            if let value = UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledTheme.rawValue) as? Int {
                if let theme = SettingsTheme(rawValue: value) {
                    if theme == .light {
                        NSApp.appearance = NSAppearance(named: .aqua)
                        return .light
                    } else if theme == .dark {
                        NSApp.appearance = NSAppearance(named: .darkAqua)
                        return .dark
                    }
                }
            } else {
                if (UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light") == "Light" {
                    return .light
                } else {
                    return .dark
                }
            }

            return .dark
        }

        set {
            if newValue == .dark { NSApp.appearance = NSAppearance(named: .darkAqua) }
            else if newValue == .light { NSApp.appearance = NSAppearance(named: .aqua) } else {
                if (UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light") == "Light" {
                    NSApp.appearance = NSAppearance(named: .aqua)
                } else {
                    NSApp.appearance = NSAppearance(named: .darkAqua)
                }
            }

            UserDefaults.save(.enabledTheme, value: newValue.rawValue)
        }
    }

    // MARK: - Charge Eighty

    var enabledChargeEighty: SettingsCharged {
        get {
            if let key = UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledChargeEighty.rawValue) as? String {
                return SettingsCharged(rawValue: key) ?? .disabled
            }
            return .disabled
        }

        set {
            UserDefaults.save(.enabledChargeEighty, value: newValue.rawValue)
        }
    }

    // MARK: - Progress Bar

    var enabledProgressBar: Bool {
        get {
            if UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledProgressState.rawValue) == nil {
                false
            } else {
                UserDefaults.main.bool(forKey: SystemDefaultsKeys.enabledProgressState.rawValue)
            }
        }

        set {
            UserDefaults.save(.enabledProgressState, value: newValue)
        }
    }

    // MARK: - Pinned

    var enabledPinned: SettingsPinned {
        get {
            if let key = UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledPinned.rawValue) as? String {
                return SettingsPinned(rawValue: key) ?? .disabled
            }
            return .disabled
        }

        set {
            UserDefaults.save(.enabledPinned, value: newValue.rawValue)
        }
    }

    // MARK: - Sound Effects

    var enabledSoundEffects: SettingsSoundEffects {
        get {
            if let key = UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledSoundEffects.rawValue) as? String {
                return SettingsSoundEffects(rawValue: key) ?? .enabled
            }
            return .enabled
        }

        set {
            if enabledSoundEffects == .disabled, newValue == .enabled {
                SystemSoundEffects.high.play(true)
            }

            UserDefaults.save(.enabledSoundEffects, value: newValue.rawValue)
        }
    }

    // MARK: - Bluetooth Status

    var enabledBluetoothStatus: SettingsStateValue {
        get {
            if UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledBluetooth.rawValue) == nil {
                .undetermined
            } else {
                switch UserDefaults.main.bool(forKey: SystemDefaultsKeys.enabledBluetooth.rawValue) {
                case true: .enabled
                case false: .disabled
                }
            }
        }

        set {
            if enabledBluetoothStatus != newValue {
                UserDefaults.save(.enabledBluetooth, value: newValue.enabled)
            }
        }
    }

    // MARK: - Actions

    func settingsAction(_ action: SettingsActionObject) {
        if action.type == .appWebsite {
            // Try Buy Me a Coffee first, then Ko-fi
            if let urlString = Bundle.main.infoDictionary?["DONATE_BUYMEACOFFEE_URL"] as? String,
               !urlString.isEmpty,
               let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            } else if let urlString = Bundle.main.infoDictionary?["DONATE_KOFI_URL"] as? String,
                      !urlString.isEmpty,
                      let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            } else if let urlString = Bundle.main.infoDictionary?["GITHUB_REPO_URL"] as? String,
                      !urlString.isEmpty,
                      let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            }
        } else if action.type == .appRate {
            if let urlString = Bundle.main.infoDictionary?["GITHUB_REPO_URL"] as? String,
               !urlString.isEmpty,
               let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            }
        } else if action.type == .appQuit {
            WindowService.shared.state = .dismissed

            Task {
                try? await Task.sleep(for: .seconds(0.8))
                NSApp.terminate(self)
            }
        } else if action.type == .appInstallUpdate {
            if UpdateManager.shared.available != nil {
                UpdateManager.shared.updateCheck()
            }
        } else if action.type == .appUpdateCheck {
            UpdateManager.shared.updateCheck()
        } else if action.type == .appEfficencyMode {
            BatteryService.shared.powerSaveMode()
        } else if action.type == .appBeta {} else if action.type == .appPinned {
            switch enabledPinned {
            case .enabled: enabledPinned = .disabled
            case .disabled: enabledPinned = .enabled
            }
        } else if action.type == .customiseDisplay {
            _ = enabledDisplay(true)
        } else if action.type == .customiseSoundEffects {
            switch enabledSoundEffects {
            case .enabled: enabledSoundEffects = .disabled
            case .disabled: enabledSoundEffects = .enabled
            }
        } else if action.type == .customiseCharge {
            switch enabledChargeEighty {
            case .enabled: enabledChargeEighty = .disabled
            case .disabled: enabledChargeEighty = .enabled
            }
        }
    }

    private var settingsMenu: [SettingsActionObject] {
        var output = [SettingsActionObject]()

        output.append(.init(.customiseDisplay))
        output.append(.init(.customiseSoundEffects))
        output.append(.init(.customiseCharge))

        if isDirectDistribution {
            output.append(.init(.appUpdateCheck))
        }

        output.append(.init(.appWebsite))
        output.append(.init(.appRate))

        return output
    }
}
