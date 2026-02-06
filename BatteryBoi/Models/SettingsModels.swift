//
//  SettingsModels.swift
//  BatteryBoi
//
//  Settings-related model types extracted for Swift 6.2 architecture.
//

import Foundation

// MARK: - Sound Effects

enum SettingsSoundEffects: String, Sendable {
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

// MARK: - Pinned Mode

enum SettingsPinned: String, Sendable {
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

// MARK: - Charge Notification

enum SettingsCharged: String, Sendable {
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

// MARK: - Beta Mode

enum SettingsBeta: String, Sendable {
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

// MARK: - Display Type

enum SettingsDisplayType: String, Sendable {
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

// MARK: - Action Object

struct SettingsActionObject: Hashable, Sendable {
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

// MARK: - Action Type

enum SettingsActionType: Sendable {
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

// MARK: - Theme

enum SettingsTheme: Int, Sendable {
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

// MARK: - State Value

enum SettingsStateValue: String, Sendable {
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
