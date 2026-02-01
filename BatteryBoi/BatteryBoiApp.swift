//
//  BatteryBoiApp.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/4/23.
//

import Combine
import Foundation
import Sparkle
import SwiftUI

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

    public func play(_ force: Bool = false) {
        if SettingsManager.shared.enabledSoundEffects == .enabled || force == true {
            NSSound(named: rawValue)?.play()

        }

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

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate, ObservableObject {
    static var shared = AppDelegate()

    var status: NSStatusItem?
    var hosting: NSHostingView = .init(rootView: MenuContainer())
    var updates = Set<AnyCancellable>()

    private var globalMouseMonitor: Any?
    private var windowMoveObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_: Notification) {
        status = NSStatusBar.system.statusItem(withLength: 45)
        hosting.frame.size = NSSize(width: 45, height: 22)

        if let window = NSApplication.shared.windows.first {
            window.close()

        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            _ = SettingsManager.shared.enabledTheme
            _ = SettingsManager.shared.enabledDisplay()

            _ = EventManager.shared

            print("\n\nApp Installed: \(AppManager.shared.appInstalled)\n\n")
            print("App Usage (Days): \(AppManager.shared.appUsage?.day ?? 0)\n\n")

            UpdateManager.shared.updateCheck()

            WindowManager.shared.windowOpen(.userLaunched, device: nil)

            SettingsManager.shared.$display.sink { type in
                switch type {
                case .hidden: self.applicationMenuBarIcon(false)
                default: self.applicationMenuBarIcon(true)
                }

            }.store(in: &self.updates)

            if SettingsManager.shared.enabledAutoLaunch == .undetermined {
                SettingsManager.shared.enabledAutoLaunch = .enabled
            }

        }

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(applicationHandleURLEvent(event:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL),
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidWakeNotification(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil,
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidSleepNotification(_:)),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil,
        )
        windowMoveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: nil,
            queue: .main,
        ) { [weak self] notification in
            self?.applicationFocusDidMove(notification: notification)
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
    func applicationHandleURLEvent(event _: NSAppleEventDescriptor, reply _: NSAppleEventDescriptor) {

//        if let path = event.paramDescriptor(forKeyword:
//        AEKeyword(keyDirectObject))?.stringValue?.components(separatedBy: "://").last {
//
//        }

    }

    func applicationFocusDidMove(notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window.title == "modalwindow" {
                // Only add monitor if not already added
                if globalMouseMonitor == nil {
                    globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
                        guard self != nil else { return }
                        window.animator().alphaValue = 1.0
                        window.animator().setFrame(
                            WindowManager.shared.windowHandleFrame(),
                            display: true,
                            animate: true,
                        )
                    }
                }

                _ = WindowManager.shared.windowHandleFrame(moved: window.frame)

            }

        }

    }

    @objc
    private func applicationDidWakeNotification(_: Notification) {
        BatteryManager.shared.powerForceRefresh()

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

        NSWorkspace.shared.notificationCenter.removeObserver(self)
        updates.forEach { $0.cancel() }
    }

}
