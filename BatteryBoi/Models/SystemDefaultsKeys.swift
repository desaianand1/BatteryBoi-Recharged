enum SystemDefaultsKeys: String {
    case enabledLogin = "sd_settings_login"
    case enabledBluetooth = "sd_bluetooth_state"
    case enabledDisplay = "sd_settings_display"
    case enabledStyle = "sd_settings_style"
    case enabledTheme = "sd_settings_theme"
    case enabledSoundEffects = "sd_settings_sfx"
    case enabledChargeEighty = "sd_charge_eighty"
    case enabledProgressState = "sd_progress_state"
    case enabledPinned = "sd_pinned_mode"

    case batteryUntilFull = "sd_charge_full"
    case batteryDepletionRate = "sd_depletion_rate"
    case batteryWindowPosition = "sd_window_position"

    case versionInstalled = "sd_version_installed"
    case versionCurrent = "sd_version_current"
    case versionIdentifier = "sd_version_id"

    case usageDay = "sd_usage_days"
    case usageTimestamp = "sd_usage_date"

    case onboardingCompleted = "sd_onboarding_completed"
    case keepAwakeDuration = "sd_keep_awake_duration"
    case alertThresholds = "sd_alert_thresholds"
    case chargeLimitPercent = "sd_charge_limit_percent"
    case chargeLimitEnabled = "sd_charge_limit_enabled"

    var name: String {
        switch self {
        case .enabledLogin: "Launch at Login"
        case .enabledBluetooth: "Bluetooth"
        case .enabledStyle: "Icon Style"
        case .enabledDisplay: "Icon Display Text"
        case .enabledTheme: "Theme"
        case .enabledSoundEffects: "SFX"
        case .enabledChargeEighty: "Show complete at 80%"
        case .enabledProgressState: "Show Progress"
        case .enabledPinned: "Pinned"
        case .batteryUntilFull: "Seconds until Charged"
        case .batteryDepletionRate: "Battery Depletion Rate"
        case .batteryWindowPosition: "Battery Window Position"
        case .versionInstalled: "Installed on"
        case .versionCurrent: "Active Version"
        case .versionIdentifier: "App ID"
        case .usageDay: "sd_usage_days"
        case .usageTimestamp: "sd_usage_timestamp"
        case .onboardingCompleted: "Onboarding Completed"
        case .keepAwakeDuration: "Keep Awake Duration"
        case .alertThresholds: "Alert Thresholds"
        case .chargeLimitPercent: "Charge Limit Percent"
        case .chargeLimitEnabled: "Charge Limit Enabled"
        }
    }
}
