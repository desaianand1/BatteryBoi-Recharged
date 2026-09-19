enum SystemDefaultsKeys: String {
    case enabledAnalytics = "sd_settings_analytics"
    case enabledLogin = "sd_settings_login"
    case enabledEstimate = "sd_settings_estimate"
    case enabledBluetooth = "sd_bluetooth_state"
    case enabledDisplay = "sd_settings_display"
    case enabledStyle = "sd_settings_style"
    case enabledTheme = "sd_settings_theme"
    case enabledSoundEffects = "sd_settings_sfx"
    case enabledChargeEighty = "sd_charge_eighty"
    case enabledProgressState = "sd_progress_state"
    case enabledPinned = "sd_pinned_mode"

    case batteryUntilFull = "sd_charge_full"
    case batteryLastCharged = "sd_charge_last"
    case batteryDepletionRate = "sd_depletion_rate"
    case batteryWindowPosition = "sd_window_position"

    case versionInstalled = "sd_version_installed"
    case versionCurrent = "sd_version_current"
    case versionIdentifier = "sd_version_id"

    case usageDay = "sd_usage_days"
    case usageTimestamp = "sd_usage_date"

    case profileChecked = "sd_profiles_checked"
    case profilePayload = "sd_profiles_payload"
    case onboardingCompleted = "sd_onboarding_completed"
    case keepAwakeDuration = "sd_keep_awake_duration"

    var name: String {
        switch self {
        case .enabledAnalytics: "Analytics"
        case .enabledLogin: "Launch at Login"
        case .enabledEstimate: "Battery Time Estimate"
        case .enabledBluetooth: "Bluetooth"
        case .enabledStyle: "Icon Style"
        case .enabledDisplay: "Icon Display Text"
        case .enabledTheme: "Theme"
        case .enabledSoundEffects: "SFX"
        case .enabledChargeEighty: "Show complete at 80%"
        case .enabledProgressState: "Show Progress"
        case .enabledPinned: "Pinned"
        case .batteryUntilFull: "Seconds until Charged"
        case .batteryLastCharged: "Seconds until Charged"
        case .batteryDepletionRate: "Battery Depletion Rate"
        case .batteryWindowPosition: "Battery Window Position"
        case .versionInstalled: "Installed on"
        case .versionCurrent: "Active Version"
        case .versionIdentifier: "App ID"
        case .usageDay: "sd_usage_days"
        case .usageTimestamp: "sd_usage_timestamp"
        case .profileChecked: "Profile Validated"
        case .profilePayload: "Profile Payload"
        case .onboardingCompleted: "Onboarding Completed"
        case .keepAwakeDuration: "Keep Awake Duration"
        }
    }
}
