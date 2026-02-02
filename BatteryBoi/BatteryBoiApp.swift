import Foundation
import Sparkle
import SwiftUI

#if canImport(Sentry)
    import Sentry
#endif

public enum SystemDistribution {
    case direct
    case appstore

}

public struct SystemProfileObject: Codable {
    var id: String
    var display: String

}

public enum SystemMenuView: String {
    case settings
    case stats
    case devices

}

public struct SystemAppUsage {
    var day: Int
    var timestamp: Date

}

public enum SystemSoundEffects: String {
    case high = "highnote"
    case low = "lownote"

    @MainActor
    public func play(_ force: Bool = false) {
        guard SettingsManager.shared.enabledSoundEffects == .enabled || force else { return }

        guard let sound = NSSound(named: rawValue) else {
            return
        }

        _ = sound.play()
    }
}

enum SystemDeviceTypes: String, Codable {
    case macbook
    case macbookPro
    case macbookAir
    case imac
    case macMini
    case macPro
    case macStudio
    case unknown

    var name: String {
        if let name = Host.current().localizedName {
            name

        } else {
            switch self {
            case .macbook: "Macbook"
            case .macbookPro: "Macbook Pro"
            case .macbookAir: "Macbook Air"
            case .imac: "iMac"
            case .macMini: "Mac Mini"
            case .macPro: "Mac Pro"
            case .macStudio: "Mac Pro"
            case .unknown: "AlertDeviceUnknownTitle".localise()
            }

        }

    }

    var battery: Bool {
        switch self {
        case .macbook: true
        case .macbookPro: true
        case .macbookAir: true
        case .imac: false
        case .macMini: false
        case .macPro: false
        case .macStudio: false
        case .unknown: false
        }

    }

    var icon: String {
        switch self {
        case .imac: "desktopcomputer"
        case .macMini: "macmini"
        case .macPro: "macpro.gen3"
        case .macStudio: "macstudio"
        default: "laptopcomputer"
        }

    }

}

enum SystemEvents: String {
    case fatalError = "fatal.error"
    case userInstalled = "user.installed"
    case userUpdated = "user.updated"
    case userActive = "user.active"
    case userProfile = "user.profile.detected"
    case userTerminated = "user.quit"
    case userClicked = "user.cta"
    case userPreferences = "user.preferences"
    case userLaunched = "user.launched"

}

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
    case versionIdenfiyer = "sd_version_id"

    case usageDay = "sd_usage_days"
    case usageTimestamp = "sd_usage_date"

    case profileChecked = "sd_profiles_checked"
    case profilePayload = "sd_profiles_payload"

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
        case .versionIdenfiyer: "App ID"
        case .usageDay: "sd_usage_days"
        case .usageTimestamp: "sd_usage_timestamp"
        case .profileChecked: "Profile Validated"
        case .profilePayload: "Profile Payload"
        }

    }

}

@main
struct BatteryBoiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            EmptyView()

        }
        .handlesExternalEvents(matching: ["*"])

    }

}

class CustomView: NSView {}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    static let shared = AppDelegate()

    var status: NSStatusItem?
    var hosting: NSHostingView = .init(rootView: MenuContainer())

    private var globalMouseMonitor: Any?
    private var windowMoveObserver: NSObjectProtocol?
    private var displayObserverTask: Task<Void, Never>?
    private var wakeRefreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_: Notification) {
        // Initialize Sentry FIRST for crash reporting
        #if canImport(Sentry)
            if let dsn = Bundle.main.infoDictionary?["SentryDSN"] as? String, !dsn.isEmpty {
                SentrySDK.start { options in
                    options.dsn = dsn
                    options.debug = false

                    // Crash reporting (critical for macOS)
                    options.enableCrashHandler = true
                    options.enableUncaughtNSExceptionReporting = true

                    // Performance monitoring
                    if let traceRate = Bundle.main.infoDictionary?["SentryTracesSampleRate"] as? String,
                       let rate = Double(traceRate)
                    {
                        options.tracesSampleRate = NSNumber(value: rate)
                    }
                    options.enableAutoPerformanceTracing = true

                    // UI Profiling (SDK 9.0+ API)
                    if let profileRate = Bundle.main.infoDictionary?["SentryProfilesSampleRate"] as? String,
                       let rate = Float(profileRate)
                    {
                        options.configureProfiling = {
                            $0.sessionSampleRate = rate
                            $0.lifecycle = .trace
                        }
                    }

                    // Release version
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
                    {
                        options.releaseName = "\(version)+\(build)"
                    }

                    // Environment
                    if let env = Bundle.main.infoDictionary?["SentryEnvironment"] as? String, !env.isEmpty {
                        options.environment = env
                    }
                }
            }
        #endif

        status = NSStatusBar.system.statusItem(withLength: 45)
        hosting.frame.size = NSSize(width: 45, height: 22)

        if let window = NSApplication.shared.windows.first {
            window.close()

        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }

            _ = SettingsManager.shared.enabledTheme
            _ = SettingsManager.shared.enabledDisplay()

            _ = EventManager.shared

            UpdateManager.shared.updateCheck()

            WindowManager.shared.windowOpen(.userLaunched, device: nil)

            // Set initial display state
            switch SettingsManager.shared.display {
            case .hidden: applicationMenuBarIcon(false)
            default: applicationMenuBarIcon(true)
            }

            // Observe display changes using async/await via UserDefaults
            displayObserverTask = Task { @MainActor [weak self] in
                for await key in UserDefaults.changedAsync() {
                    guard let self, !Task.isCancelled else { break }
                    if key == .enabledDisplay {
                        switch SettingsManager.shared.display {
                        case .hidden: applicationMenuBarIcon(false)
                        default: applicationMenuBarIcon(true)
                        }
                    }
                }
            }

            if SettingsManager.shared.enabledAutoLaunch == .undetermined {
                SettingsManager.shared.enabledAutoLaunch = .enabled
            }
        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(applicationHandleURLEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidWakeNotification(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidSleepNotification(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract window before crossing actor boundary to avoid Sendable issues
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor [weak self] in
                self?.applicationFocusDidMove(window: window)
            }
        }

    }

    private func applicationMenuBarIcon(_ visible: Bool) {
        if visible == true {
            if let button = status?.button {
                button.title = ""
                button.addSubview(hosting)
                button.action = #selector(applicationStatusBarButtonClicked(sender:))
                button.target = self

                SettingsManager.shared.enabledPinned = .disabled

            }

        } else {
            if let button = status?.button {
                button.subviews.forEach { $0.removeFromSuperview() }

            }

        }

    }

    @objc
    func applicationStatusBarButtonClicked(sender _: NSStatusBarButton) {
        if WindowManager.shared.windowIsVisible(.userInitiated) == false {
            WindowManager.shared.windowOpen(.userInitiated, device: nil)

        } else {
            WindowManager.shared.windowSetState(.dismissed)

        }

    }

    @objc
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        WindowManager.shared.windowOpen(.userInitiated, device: nil)

        return false

    }

    @objc
    func applicationHandleURLEvent(event _: NSAppleEventDescriptor, reply _: NSAppleEventDescriptor) {}

    func applicationFocusDidMove(window: NSWindow) {
        if window.title == "modalwindow" {
            // Only add monitor if not already added
            if globalMouseMonitor == nil {
                globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
                    guard self != nil else { return }
                    window.animator().alphaValue = 1.0
                    window.animator().setFrame(
                        WindowManager.shared.windowHandleFrame(),
                        display: true,
                        animate: true
                    )
                }
            }

            _ = WindowManager.shared.windowHandleFrame(moved: window.frame)

        }

    }

    @objc
    private func applicationDidWakeNotification(_: Notification) {
        // Cancel any pending wake refresh task
        wakeRefreshTask?.cancel()
        wakeRefreshTask = Task { @MainActor [weak self] in
            // Short delay to let system stabilize after wake
            try? await Task.sleep(for: .seconds(0.5))
            guard self != nil, !Task.isCancelled else { return }
            BatteryManager.shared.powerForceRefresh()
        }
    }

    @objc
    private func applicationDidSleepNotification(_: Notification) {}

    func applicationWillTerminate(_: Notification) {
        // Remove global mouse monitor
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }

        // Remove notification observers
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
            windowMoveObserver = nil
        }

        displayObserverTask?.cancel()
        wakeRefreshTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

}
