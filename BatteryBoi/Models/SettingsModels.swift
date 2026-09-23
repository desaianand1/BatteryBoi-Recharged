//
//  SettingsModels.swift
//  BatteryBoi
//
//  Settings-related model types extracted for Swift 6.2 architecture.
//

import Foundation
import SwiftUI

// MARK: - Settings Toggle Protocol

protocol SettingsToggle: RawRepresentable where RawValue == String {
    static var enabledIcon: String { get }
    static var disabledIcon: String { get }
}

extension SettingsToggle {
    var subtitle: String {
        rawValue == "enabled" ? "SettingsEnabledLabel".localise() : "SettingsDisabledLabel".localise()
    }

    var icon: String {
        rawValue == "enabled" ? Self.enabledIcon : Self.disabledIcon
    }
}

// MARK: - Sound Effects

enum SettingsSoundEffects: String, SettingsToggle {
    case enabled
    case disabled

    static let enabledIcon = "speaker.wave.2.fill"
    static let disabledIcon = "speaker.slash.fill"
}

// MARK: - Pinned Mode

enum SettingsPinned: String, SettingsToggle {
    case enabled
    case disabled

    static let enabledIcon = "pin.fill"
    static let disabledIcon = "pin.slash"
}

// MARK: - Charge Notification

enum SettingsCharged: String, SettingsToggle {
    case enabled
    case disabled

    static let enabledIcon = "bolt.fill"
    static let disabledIcon = "bolt.slash"
}

// MARK: - Display Type

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
        case .hidden: "SettingsDisplayMenuBarHiddenLabel".localise()
        }
    }

    var icon: String {
        switch self {
        case .countdown: "clock.fill"
        case .percent: "percent"
        case .cycle: "arrow.triangle.2.circlepath"
        case .empty: "rectangle.dashed"
        case .hidden: "eye.slash"
        }
    }
}

// MARK: - Action Object

struct SettingsActionObject: Hashable {
    var type: SettingsActionType
    var title: String

    init(_ type: SettingsActionType) {
        switch type {
        case .appWebsite: title = "SettingsWebsiteLabel".localise()
        case .appQuit: title = "SettingsQuitLabel".localise()
        case .appEfficiencyMode: title = "SettingsEfficiencyLabel".localise()
        case .appRate: title = "SettingsRateLabel".localise()
        case .appUpdateCheck: title = "SettingsCheckUpdatesLabel".localise()
        case .appInstallUpdate: title = "SettingsNewUpdateLabel".localise()
        case .appPinned: title = "SettingsPinnedLabel".localise()
        case .customiseDisplay: title = "SettingsDisplayLabel".localise()
        case .customiseSoundEffects: title = "SettingsSoundEffectsLabel".localise()
        case .customiseCharge: title = "SettingsEightyLabel".localise()
        }

        self.type = type
    }
}

// MARK: - Action Type

enum SettingsActionType {
    case appWebsite
    case appQuit
    case appPinned
    case appUpdateCheck
    case appRate
    case appEfficiencyMode
    case appInstallUpdate
    case customiseSoundEffects
    case customiseDisplay
    case customiseCharge
}

// MARK: - Theme

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

// MARK: - Alert Threshold Tier

enum AlertThresholdTier: String, CaseIterable {
    case critical
    case urgent
    case standard

    static func tier(for percent: Int) -> Self {
        switch percent {
        case 1 ... 3: .critical
        case 4 ... 9: .urgent
        default: .standard
        }
    }

    var dotColor: Color {
        switch self {
        case .critical: SemanticColor.error
        case .urgent: SemanticColor.warning
        case .standard: Color("BBSubtitle")
        }
    }

    var label: String {
        switch self {
        case .critical: "AlertTierCriticalLabel".localise()
        case .urgent: "AlertTierUrgentLabel".localise()
        case .standard: "AlertTierStandardLabel".localise()
        }
    }

    static func subtitle(for percent: Int) -> String {
        switch percent {
        case 1 ... 3: "AlertSubtitle_Critical".localise()
        case 4 ... 9: "AlertSubtitle_Urgent".localise()
        case 10 ... 19: "AlertSubtitle_Standard_Low".localise()
        default: "AlertSubtitle_Standard_Info".localise()
        }
    }

    var priority: AlertPriority {
        switch self {
        case .critical: .critical
        case .urgent: .high
        case .standard: .medium
        }
    }
}

// MARK: - Alert Threshold Item

struct AlertThresholdItem: Identifiable, Equatable {
    let percent: Int
    var id: Int {
        self.percent
    }

    var tier: AlertThresholdTier {
        AlertThresholdTier.tier(for: self.percent)
    }

    var isRemovable: Bool {
        self.percent != 1
    }

    var subtitle: String {
        AlertThresholdTier.subtitle(for: self.percent)
    }
}

// MARK: - State Value

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
        case .enabled: "SettingsStateEnabled".localise()
        case .disabled: "SettingsStateDisabled".localise()
        case .undetermined: "SettingsStateNotSet".localise()
        case .restricted: "SettingsStateRestricted".localise()
        }
    }
}
