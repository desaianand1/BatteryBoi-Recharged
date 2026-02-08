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
        guard SettingsService.shared.enabledSoundEffects == .enabled || force else { return }

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
    case onboardingCompleted = "sd_onboarding_completed"

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
        case .onboardingCompleted: "Onboarding Completed"
        }

    }

}

@main
struct BatteryBoiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

}

class CustomView: NSView {}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    static let shared = AppDelegate()

    var status: NSStatusItem?
    var hosting: NSHostingView<AnyView>!

    private func createHostingView() {
        hosting = NSHostingView(rootView: AnyView(MenuContainer().withAppEnvironment()))
    }

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

        // Start ServiceContainer to begin state observation
        Task { @MainActor in
            await ServiceContainer.shared.start()
        }

        // Create hosting view with environment injected
        createHostingView()

        status = NSStatusBar.system.statusItem(withLength: 45)
        hosting.frame.size = NSSize(width: 45, height: 22)

        // Show icon immediately after status item creation
        applicationMenuBarIcon(true)

        if let window = NSApplication.shared.windows.first {
            window.close()

        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }

            _ = SettingsService.shared.enabledTheme
            _ = SettingsService.shared.enabledDisplay()

            _ = EventService.shared

            UpdateManager.shared.updateCheck()

            // Show onboarding on first launch, otherwise open HUD
            if OnboardingService.shared.shouldShowOnboarding {
                openOnboardingWindow()
            } else {
                WindowService.shared.open(.userLaunched, device: nil)
            }

            // Set initial display state
            switch SettingsService.shared.display {
            case .hidden: applicationMenuBarIcon(false)
            default: applicationMenuBarIcon(true)
            }

            // Observe display changes using async/await via UserDefaults
            displayObserverTask = Task { @MainActor [weak self] in
                for await key in UserDefaults.changedAsync() {
                    guard let self, !Task.isCancelled else { break }
                    if key == .enabledDisplay {
                        switch SettingsService.shared.display {
                        case .hidden: applicationMenuBarIcon(false)
                        default: applicationMenuBarIcon(true)
                        }
                    }
                }
            }

            if SettingsService.shared.enabledAutoLaunch == .undetermined {
                SettingsService.shared.enabledAutoLaunch = .enabled
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
        BLogger.app.debug("applicationMenuBarIcon called with visible: \(visible)")

        if visible == true {
            if let button = status?.button {
                button.title = ""
                button.addSubview(hosting)
                button.action = #selector(applicationStatusBarButtonClicked(sender:))
                button.target = self

                SettingsService.shared.enabledPinned = .disabled
                BLogger.app.debug("Menu bar icon added to status button")

            } else {
                BLogger.app.warning("Menu bar icon: status button is nil")
            }

        } else {
            if let button = status?.button {
                button.subviews.forEach { $0.removeFromSuperview() }
                BLogger.app.debug("Menu bar icon removed from status button")

            }

        }

    }

    @objc
    func applicationStatusBarButtonClicked(sender _: NSStatusBarButton) {
        if WindowService.shared.isVisible(.userInitiated) == false {
            WindowService.shared.open(.userInitiated, device: nil)

        } else {
            WindowService.shared.setState(.dismissed, animated: true)

        }

    }

    @objc
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        WindowService.shared.open(.userInitiated, device: nil)

        return false

    }

    @objc
    func applicationHandleURLEvent(event _: NSAppleEventDescriptor, reply _: NSAppleEventDescriptor) {}

    private func openOnboardingWindow() {
        let onboardingView = OnboardingView().withAppEnvironment()
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "onboarding"
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .fullSizeContentView])
        window.titlebarAppearsTransparent = true
        window.titleVisibility = NSWindow.TitleVisibility.hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(named: "BatteryBackground")
        window.center()
        window.makeKeyAndOrderFront(Any?.none)

        // Ensure window is retained
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationFocusDidMove(window: NSWindow) {
        if window.title == "modalwindow" {
            // Only add monitor if not already added
            if globalMouseMonitor == nil {
                globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
                    guard self != nil else { return }
                    window.animator().alphaValue = 1.0
                    window.animator().setFrame(
                        WindowService.shared.calculateFrame(moved: nil),
                        display: true,
                        animate: true
                    )
                }
            }

            _ = WindowService.shared.calculateFrame(moved: window.frame)

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
            BatteryService.shared.forceRefresh()
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
