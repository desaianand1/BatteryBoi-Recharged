import AppKit
import Foundation
import ServiceManagement
import SwiftUI

enum SettingsSoundEffects: String {
    case enabled
    case disabled

    var subtitle: String {
        switch self {
        case .enabled: "SettingsEnabledLabel".localise()
        default: "SettingsDisabledLabel".localise()
        }

    }

    var icon: String {
        switch self {
        case .enabled: "AudioIcon"
        default: "MuteIcon"
        }

    }

}

enum SettingsPinned: String {
    case enabled
    case disabled

    var subtitle: String {
        switch self {
        case .enabled: "SettingsEnabledLabel".localise()
        default: "SettingsDisabledLabel".localise()
        }

    }

    var icon: String {
        switch self {
        case .enabled: "AudioIcon"
        default: "MuteIcon"
        }

    }

}

enum SettingsCharged: String {
    case enabled
    case disabled

    var subtitle: String {
        switch self {
        case .enabled: "SettingsEnabledLabel".localise()
        default: "SettingsDisabledLabel".localise()
        }

    }

    var icon: String {
        switch self {
        case .enabled: "AudioIcon"
        default: "MuteIcon"
        }

    }

}

enum SettingsBeta: String {
    case enabled
    case disabled

    var subtitle: String {
        switch self {
        case .enabled: "SettingsEnabledLabel".localise()
        default: "SettingsDisabledLabel".localise()
        }

    }

    var icon: String {
        switch self {
        case .enabled: "AudioIcon"
        default: "MuteIcon"
        }

    }

}

enum SettingsDisplayType: String {
    case countdown
    case empty
    case percent
    case cycle
    case hidden

    var type: String {
        switch self {
        case .countdown: "SettingsDisplayEstimateLabel".localise()
        case .percent: "SettingsDisplayPercentLabel".localise()
        case .empty: "SettingsDisplayNoneLabel".localise()
        case .cycle: "SettingsDisplayCycleLabel".localise()
        case .hidden: "SettingsDisplayHiddenLabel".localise()
        }

    }

    var icon: String {
        switch self {
        case .countdown: "TimeIcon"
        case .percent: "PercentIcon"
        case .cycle: "CycleIcon"
        case .empty: "EmptyIcon"
        case .hidden: "EmptyIcon"
        }

    }

}

struct SettingsActionObject: Hashable {
    var type: SettingsActionType
    var title: String

    init(_ type: SettingsActionType) {
        switch type {
        case .appWebsite: title = "SettingsWebsiteLabel".localise()
        case .appQuit: title = "SettingsQuitLabel".localise()
        case .appDevices: title = "SettingsDevicesLabel".localise()
        case .appSettings: title = "SettingsSettingsLabel".localise()
        case .appEfficencyMode: title = "SettingsEfficiencyLabel".localise()
        case .appBeta: title = "SettingsPrereleasesLabel".localise()
        case .appRate: title = "SettingsRateLabel".localise()
        case .appUpdateCheck: title = "SettingsCheckUpdatesLabel".localise()
        case .appInstallUpdate: title = "SettingsNewUpdateLabel".localise()
        case .appPinned: title = "SettingsPinnedLabel".localise()
        case .customiseTheme: title = "SettingsThemeLabel".localise()
        case .customiseDisplay: title = "SettingsDisplayLabel".localise()
        case .customiseNotifications: title = "SettingsDisplayPercentLabel".localise()
        case .customiseSoundEffects: title = "SettingsSoundEffectsLabel".localise()
        case .customiseCharge: title = "SettingsEightyLabel".localise()
        }

        self.type = type

    }

}

enum SettingsActionType {
    case appWebsite
    case appQuit
    case appDevices
    case appSettings
    case appPinned
    case appUpdateCheck
    case appRate
    case appEfficencyMode
    case appInstallUpdate
    case appBeta
    case customiseSoundEffects
    case customiseDisplay
    case customiseTheme
    case customiseNotifications
    case customiseCharge

    var icon: String {
        switch self {
        case .appEfficencyMode: "EfficiencyIcon"
        case .appUpdateCheck: "CycleIcon"
        case .appInstallUpdate: "CycleIcon"
        case .appWebsite: "WebsiteIcon"
        case .appBeta: "WebsiteIcon"
        case .appQuit: "WebsiteIcon"
        case .appDevices: "WebsiteIcon"
        case .appSettings: "WebsiteIcon"
        case .appPinned: "WebsiteIcon"
        case .appRate: "RateIcon"
        case .customiseDisplay: "PercentIcon"
        case .customiseTheme: "PercentIcon"
        case .customiseNotifications: "PercentIcon"
        case .customiseSoundEffects: "PercentIcon"
        case .customiseCharge: "PercentIcon"
        }

    }

}

enum SettingsTheme: Int {
    case system
    case light
    case dark

    var string: String {
        switch self {
        case .light: "light"
        case .dark: "dark"
        default: "system"
        }

    }

}

enum SettingsStateValue: String {
    case enabled
    case disabled
    case undetermined
    case restricted

    var enabled: Bool {
        switch self {
        case .disabled: false
        default: true
        }

    }

    var boolean: Bool {
        switch self {
        case .enabled: true
        default: false
        }

    }

    var title: String {
        switch self {
        case .enabled: "Enabled"
        case .disabled: "Disabled"
        case .undetermined: "Not Set"
        case .restricted: "Restricted"
        }

    }

}

@Observable
@MainActor
final class SettingsManager: SettingsServiceProtocol {
    static let shared = SettingsManager()

    var menu: [SettingsActionObject] = []
    var display: SettingsDisplayType = .countdown
    var sfx: SettingsSoundEffects = .enabled
    var theme: SettingsTheme = .dark
    var pinned: SettingsPinned = .disabled
    var charge: SettingsCharged = .disabled

    /// Cached distribution type to avoid async call in computed property.
    /// Direct distribution shows update check option; App Store handles updates itself.
    private let isDirectDistribution: Bool

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

    init() {
        // Cache distribution type synchronously at init.
        // App Store apps have a receipt; direct distribution doesn't.
        isDirectDistribution = !Self.isAppStoreDistribution()

        menu = settingsMenu
        display = enabledDisplay(false)
        theme = enabledTheme
        sfx = enabledSoundEffects
        pinned = enabledPinned
        charge = enabledChargeEighty

        // Observe UserDefaults changes using async/await
        settingsTask = Task { @MainActor [weak self] in
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

    /// Synchronous check for App Store distribution.
    /// Returns true if the app appears to be from the App Store (has valid receipt).
    private static func isAppStoreDistribution() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }

    deinit {
        settingsTask?.cancel()
    }

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
            if self.enabledAutoLaunch != .undetermined {
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

    var enabledStyle: BatteryStyle {
        get {
            if let style = UserDefaults.main.string(forKey: SystemDefaultsKeys.enabledStyle.rawValue) {
                return BatteryStyle(rawValue: style) ?? .chunky

            }

            return .chunky

        }

        set {
            if self.enabledStyle != newValue {
                UserDefaults.save(.enabledStyle, value: newValue)

            }

        }

    }

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

    var enabledSoundEffects: SettingsSoundEffects {
        get {
            if let key = UserDefaults.main.object(forKey: SystemDefaultsKeys.enabledSoundEffects.rawValue) as? String {
                return SettingsSoundEffects(rawValue: key) ?? .enabled

            }

            return .enabled

        }

        set {
            if self.enabledSoundEffects == .disabled, newValue == .enabled {
                SystemSoundEffects.high.play(true)

            }

            UserDefaults.save(.enabledSoundEffects, value: newValue.rawValue)

        }

    }

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
            if self.enabledBluetoothStatus != newValue {
                UserDefaults.save(.enabledBluetooth, value: newValue.enabled)

            }

        }

    }

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
                // Fallback to GitHub repo
                NSWorkspace.shared.open(url)
            }
        } else if action.type == .appRate {
            // Open GitHub repo for starring/feedback
            if let urlString = Bundle.main.infoDictionary?["GITHUB_REPO_URL"] as? String,
               !urlString.isEmpty,
               let url = URL(string: urlString)
            {
                NSWorkspace.shared.open(url)
            }
        } else if action.type == .appQuit {
            WindowManager.shared.state = .dismissed

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                NSApp.terminate(self)
            }
        } else if action.type == .appInstallUpdate {
            if UpdateManager.shared.available != nil {
                // Trigger Sparkle update
                UpdateManager.shared.updateCheck()
            }
        } else if action.type == .appUpdateCheck {
            UpdateManager.shared.updateCheck()
        } else if action.type == .appEfficencyMode {
            BatteryManager.shared.powerSaveMode()
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
