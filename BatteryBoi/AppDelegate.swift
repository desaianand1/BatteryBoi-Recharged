import SwiftUI

#if canImport(Sentry)
    import Sentry
#endif

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    let env = AppEnvironment()

    var status: NSStatusItem?
    var hosting: NSHostingView<AnyView>!

    private func createHostingView() {
        hosting = NSHostingView(rootView: AnyView(MenuContainer().environment(self.env)))
    }

    private var windowMoveObserver: NSObjectProtocol?
    private var displayObserverTask: Task<Void, Never>?
    private var wakeRefreshTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    private var delayedInitTask: Task<Void, Never>?

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

        startTask = Task {
            self.env.start()
        }

        // Create hosting view with environment injected
        createHostingView()

        status = NSStatusBar.system.statusItem(withLength: 45)
        hosting.frame.size = NSSize(width: 45, height: 22)

        // Show icon immediately after status item creation
        applicationMenuBarIcon(true)

        // Close any leftover SwiftUI Settings windows, but NOT the status bar window.
        // Before this fix, windows.first was the NSStatusBarWindow (created when the
        // status item was set up above), and closing it silently removed the menu bar icon.
        let statusBarWindow = status?.button?.window
        for window in NSApplication.shared.windows where window !== statusBarWindow {
            window.close()
        }

        delayedInitTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            guard let self else { return }

            _ = self.env.settings.theme
            _ = self.env.settings.enabledDisplay()

            self.env.update.updateCheck()

            // Show onboarding on first launch, otherwise open HUD
            if self.env.onboarding.shouldShowOnboarding {
                openOnboardingWindow()
            } else {
                self.env.window.open(.userLaunched, device: nil)
            }

            // Set initial display state
            switch self.env.settings.display {
            case .hidden: applicationMenuBarIcon(false)
            default: applicationMenuBarIcon(true)
            }

            // Observe display changes using async/await via UserDefaults
            displayObserverTask = Task { [weak self] in
                for await key in UserDefaults.changedAsync() {
                    guard let self, !Task.isCancelled else { break }
                    if key == .enabledDisplay {
                        switch self.env.settings.display {
                        case .hidden: applicationMenuBarIcon(false)
                        default: applicationMenuBarIcon(true)
                        }
                    }
                }
            }

            if self.env.settings.autoLaunch == .undetermined {
                self.env.settings.autoLaunch = .enabled
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
            guard let window = notification.object as? NSWindow,
                  window.title == Constants.Window.modalWindowTitle else { return }
            // Ephemeral MainActor hop for notification callback — completes synchronously
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
                if hosting.superview == nil {
                    button.addSubview(hosting)
                }
                button.action = #selector(applicationStatusBarButtonClicked(sender:))
                button.target = self

                self.env.settings.pinned = .disabled
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
        if self.env.window.isVisible(.userInitiated) == false {
            self.env.window.open(.userInitiated, device: nil)
        } else {
            self.env.window.setState(.dismissed, animated: true)
        }
    }

    @objc
    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        self.env.window.open(.userInitiated, device: nil)

        return false
    }

    @objc
    func applicationHandleURLEvent(event _: NSAppleEventDescriptor, reply _: NSAppleEventDescriptor) {}

    private func openOnboardingWindow() {
        let onboardingView = OnboardingView().environment(self.env)
        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "onboarding"
        window.styleMask = NSWindow.StyleMask([.titled, .closable, .fullSizeContentView])
        window.titlebarAppearsTransparent = true
        window.titleVisibility = NSWindow.TitleVisibility.hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor(named: "BBBackground")
        window.center()
        window.makeKeyAndOrderFront(Any?.none)

        // Ensure window is retained
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationFocusDidMove(window: NSWindow) {
        if window.title == Constants.Window.modalWindowTitle {
            _ = self.env.window.calculateFrame(moved: window.frame)
        }
    }

    @objc
    private func applicationDidWakeNotification(_: Notification) {
        wakeRefreshTask?.cancel()
        wakeRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self, !Task.isCancelled else { return }
            self.env.window.handleWake()
            self.env.battery.forceRefresh()
            self.env.bluetooth.forceRefresh()
            self.env.coordinator.handleWake()
        }
    }

    @objc
    private func applicationDidSleepNotification(_: Notification) {
        self.env.window.handleSleep()
        self.env.coordinator.handleSleep()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_: Notification) {
        self.env.coordinator.stopObserving()

        // Remove notification observers
        if let observer = windowMoveObserver {
            NotificationCenter.default.removeObserver(observer)
            windowMoveObserver = nil
        }

        startTask?.cancel()
        delayedInitTask?.cancel()
        displayObserverTask?.cancel()
        wakeRefreshTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}
