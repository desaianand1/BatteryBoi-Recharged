import Cocoa
import CoreGraphics
import Foundation
import SwiftUI

struct WindowViewBlur: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()

        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .underWindowBackground

        return view

    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}

}

enum WindowPosition: String {
    case center
    case topLeft
    case topMiddle
    case topRight
    case bottomLeft
    case bottomRight

    var alignment: Alignment {
        switch self {
        case .center: .center
        case .topLeft: .topLeading
        case .topMiddle: .top
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }

    }

}

@Observable
@MainActor
final class WindowManager: WindowServiceProtocol {
    static let shared = WindowManager()

    private var triggered: Int = 0
    private var notifiedThresholds: Set<Int> = []
    private var notifiedBluetoothThresholds: [String: Set<Int>] = [:]
    nonisolated(unsafe) private var globalMouseMonitor: Any?
    /// Task for auto-dismissing the HUD after a timeout. Cancelled when a new alert appears.
    nonisolated(unsafe) private var dismissalTask: Task<Void, Never>?
    /// Task for handling state transitions. Cancelled when a new state change occurs.
    nonisolated(unsafe) private var stateTransitionTask: Task<Void, Never>?

    // Async observation tasks
    nonisolated(unsafe) private var chargingObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var percentageObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var thermalObserverTask: Task<Void, Never>?
    nonisolated(unsafe) private var bluetoothTimerTask: Task<Void, Never>?
    nonisolated(unsafe) private var eventTimerTask: Task<Void, Never>?
    nonisolated(unsafe) private var pinnedObserverTask: Task<Void, Never>?

    // Debounce tracking for charging state changes
    private var lastChargingState: BatteryChargingState?
    nonisolated(unsafe) private var chargingDebounceTask: Task<Void, Never>?

    // Mouse event debouncing
    private var lastMouseEventTime: Date = .distantPast
    private let mouseEventDebounceInterval: TimeInterval = 0.1

    // MARK: - WindowServiceProtocol Methods

    func setState(_ state: HUDState, animated: Bool) {
        self.windowSetState(state, animated: animated)
    }

    func isVisible(_ type: HUDAlertTypes) -> Bool {
        self.windowIsVisible(type)
    }

    func open(_ type: HUDAlertTypes, device: BluetoothObject?) {
        self.windowOpen(type, device: device)
    }

    func calculateFrame(moved: NSRect?) -> NSRect {
        self.windowHandleFrame(moved: moved)
    }

    private var screen: CGSize {
        if let activeScreen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main {
            return activeScreen.frame.size
        }
        return CGSize(width: 1920, height: 1080)
    }

    var hover: Bool = false
    var state: HUDState = .hidden {
        didSet {
            self.handleStateChange(self.state)
        }
    }

    var position: WindowPosition = .topMiddle
    var opacity: CGFloat = 1.0

    init() {
        self.lastChargingState = BatteryManager.shared.charging.state

        // Observe charging state changes with debounce
        self.chargingObserverTask = Task { @MainActor [weak self] in
            var previousCharging = BatteryManager.shared.charging
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { break }

                let currentCharging = BatteryManager.shared.charging
                if currentCharging != previousCharging {
                    // Reset thresholds when charging starts
                    if currentCharging.state == .charging {
                        self.notifiedThresholds.removeAll()
                    }

                    // Debounce the charging state change notification (2 seconds)
                    self.chargingDebounceTask?.cancel()
                    let newState = currentCharging.state
                    self.chargingDebounceTask = Task { @MainActor [weak self] in
                        do {
                            try await Task.sleep(for: .seconds(2))
                            guard let self, !Task.isCancelled else { return }
                            switch newState {
                            case .battery: self.windowOpen(.chargingStopped, device: nil)
                            case .charging: self.windowOpen(.chargingBegan, device: nil)
                            }
                        } catch {
                            // Task cancelled
                        }
                    }

                    previousCharging = currentCharging
                }
            }
        }

        // Observe percentage changes (optimized from 500ms to 2s)
        self.percentageObserverTask = Task { @MainActor [weak self] in
            var previousPercent = BatteryManager.shared.percentage
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { break }

                let currentPercent = BatteryManager.shared.percentage
                if currentPercent != previousPercent {
                    if BatteryManager.shared.charging.state == .battery {
                        let thresholds: [(Int, HUDAlertTypes)] = [
                            (25, .percentTwentyFive),
                            (10, .percentTen),
                            (5, .percentFive),
                            (1, .percentOne),
                        ]

                        for (threshold, alertType) in thresholds {
                            if currentPercent <= Double(threshold), !self.notifiedThresholds.contains(threshold) {
                                self.notifiedThresholds.insert(threshold)
                                self.windowOpen(alertType, device: nil)
                                break
                            }
                        }
                    } else {
                        if currentPercent >= 100, SettingsManager.shared.enabledChargeEighty == .disabled {
                            self.windowOpen(.chargingComplete, device: nil)
                        } else if currentPercent >= 80, SettingsManager.shared.enabledChargeEighty == .enabled {
                            self.windowOpen(.chargingComplete, device: nil)
                        }
                    }

                    previousPercent = currentPercent
                }
            }
        }

        // Observe thermal state changes
        self.thermalObserverTask = Task { @MainActor [weak self] in
            var previousThermal = BatteryManager.shared.thermal
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }

                let currentThermal = BatteryManager.shared.thermal
                if currentThermal != previousThermal, currentThermal == .suboptimal {
                    self.windowOpen(.deviceOverheating, device: nil)
                }
                previousThermal = currentThermal
            }
        }

        // Check Bluetooth device battery levels every 60 seconds
        self.bluetoothTimerTask = Task { @MainActor [weak self] in
            var skipFirst = true
            for await _ in AppManager.shared.appTimerAsync(60) {
                guard let self, !Task.isCancelled else { break }
                if skipFirst { skipFirst = false; continue }

                let connected = BluetoothManager.shared.list.filter { $0.connected == .connected }

                for device in connected {
                    guard let percent = device.battery.general else { continue }
                    let deviceId = device.address

                    if self.notifiedBluetoothThresholds[deviceId] == nil {
                        self.notifiedBluetoothThresholds[deviceId] = []
                    }

                    let thresholds: [(Int, HUDAlertTypes)] = [
                        (25, .percentTwentyFive),
                        (10, .percentTen),
                        (5, .percentFive),
                        (1, .percentOne),
                    ]

                    for (threshold, alertType) in thresholds {
                        if percent <= Double(threshold),
                           !(self.notifiedBluetoothThresholds[deviceId]?.contains(threshold) ?? false)
                        {
                            self.notifiedBluetoothThresholds[deviceId]?.insert(threshold)
                            self.windowOpen(alertType, device: device)
                            break
                        }
                    }

                    if percent > 30 {
                        self.notifiedBluetoothThresholds[deviceId]?.removeAll()
                    }
                }
            }
        }

        // Check for upcoming events every 30 seconds
        self.eventTimerTask = Task { @MainActor [weak self] in
            var skipFirst = true
            for await _ in AppManager.shared.appTimerAsync(30) {
                guard let self, !Task.isCancelled else { break }
                if skipFirst { skipFirst = false; continue }

                if BatteryManager.shared.charging.state == .battery {
                    if let now = EventManager.shared.events.max(by: { $0.start < $1.start }) {
                        if let minutes = Calendar.current.dateComponents([.minute], from: Date(), to: now.start)
                            .minute
                        {
                            if minutes == 2 {
                                self.windowOpen(.userEvent, device: nil)
                            }
                        }
                    }
                }
            }
        }

        // Observe pinned setting changes
        self.pinnedObserverTask = Task { @MainActor [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledPinned, SettingsManager.shared.pinned == .enabled {
                    withAnimation(Animation.easeOut) {
                        self.opacity = 1.0
                    }
                }
            }
        }

        self.globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseUp,
            .rightMouseUp,
        ]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Debounce mouse events
                let now = Date()
                guard now.timeIntervalSince(self.lastMouseEventTime) > self.mouseEventDebounceInterval else { return }
                self.lastMouseEventTime = now

                if NSRunningApplication.current == NSWorkspace.shared.frontmostApplication {
                    if self.state == .revealed || self.state == .progress {
                        self.windowSetState(.detailed)
                    }
                } else {
                    if SettingsManager.shared.enabledPinned == .disabled {
                        if self.state.visible == true {
                            self.windowSetState(.dismissed)
                        }
                    } else {
                        self.windowSetState(.revealed)
                    }
                }
            }
        }

        self.position = self.windowLastPosition
    }

    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        dismissalTask?.cancel()
        stateTransitionTask?.cancel()
        chargingObserverTask?.cancel()
        percentageObserverTask?.cancel()
        thermalObserverTask?.cancel()
        bluetoothTimerTask?.cancel()
        eventTimerTask?.cancel()
        pinnedObserverTask?.cancel()
        chargingDebounceTask?.cancel()
    }

    private func handleStateChange(_ state: HUDState) {
        // Cancel any pending state transition tasks from previous state changes
        self.stateTransitionTask?.cancel()

        if state == .dismissed {
            // Cancel any pending dismissal when manually dismissed
            self.dismissalTask?.cancel()
            self.dismissalTask = nil

            self.stateTransitionTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                Self.shared.windowClose()
            }
        } else if state == .progress {
            self.stateTransitionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.2))
                guard let self, !Task.isCancelled else { return }
                self.windowSetState(.revealed)
            }
        } else if state == .revealed {
            // Transition to detailed view for non-timeout alerts after 1 second
            let shouldTransitionToDetailed = AppManager.shared.alert?.timeout == false
            if shouldTransitionToDetailed {
                self.stateTransitionTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, !Task.isCancelled else { return }
                    self.windowSetState(.detailed)
                }
            }

            // Schedule auto-dismissal based on alert timeout setting
            self.scheduleDismissal()
        }
    }

    /// Schedules auto-dismissal of the HUD based on the current alert's timeout setting.
    /// Cancels any existing dismissal task before scheduling a new one.
    private func scheduleDismissal() {
        self.dismissalTask?.cancel()

        // Capture the current state at scheduling time to avoid race conditions
        let targetState: HUDState = .revealed
        let timeout: Duration = AppManager.shared.alert?.timeout == true ? .seconds(5) : .seconds(10)

        self.dismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: timeout)
                guard let self, !Task.isCancelled, state == targetState else { return }
                self.windowSetState(.dismissed)
            } catch {
                // Task was cancelled, don't dismiss
            }
        }
    }

    func windowSetState(_ state: HUDState, animated _: Bool = true) {
        if self.state != state {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 1.0)) {
                self.state = state

            }

        }

    }

    func windowIsVisible(_ type: HUDAlertTypes) -> Bool {
        if let window = windowExists(type) {
            if CGFloat(window.alphaValue) > 0.5 {
                return true

            }

        }

        return false

    }

    func windowOpen(_ type: HUDAlertTypes, device: BluetoothObject?) {
        // Cancel any pending dismissal from a previous alert
        self.dismissalTask?.cancel()
        self.dismissalTask = nil

        if let window = windowExists(type) {
            window.contentView = WindowHostingView(rootView: HUDParent(type, device: device))

            if window.canBecomeKeyWindow {
                window.makeKeyAndOrderFront(nil)
                window.alphaValue = 1.0

                if AppManager.shared.alert == nil {
                    if let sfx = type.sfx {
                        sfx.play()
                    }
                }

                if !BluetoothManager.shared.connected.isEmpty {
                    AppManager.shared.menu = .devices
                }

                AppManager.shared.device = device
                AppManager.shared.alert = type

                self.windowSetState(.progress)
            }
        }
    }

    private func windowClose() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == BBConstants.Window.modalWindowTitle }) {
            if AppManager.shared.alert != nil {
                AppManager.shared.alert = nil
                AppManager.shared.device = nil

                self.state = .hidden

                window.alphaValue = 0.0

            }

        }

    }

    private func windowDefault(_: HUDAlertTypes) -> NSWindow? {
        var window: NSWindow?
        window = NSWindow()
        window?.styleMask = [.borderless, .miniaturizable]
        window?.level = .statusBar
        window?.contentView?.translatesAutoresizingMaskIntoConstraints = false
        window?.center()
        window?.title = BBConstants.Window.modalWindowTitle
        window?.isMovableByWindowBackground = true
        window?.backgroundColor = .clear
        window?.setFrame(self.windowHandleFrame(), display: true)
        window?.titlebarAppearsTransparent = true
        window?.titleVisibility = .hidden
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window?.toolbarStyle = .unifiedCompact
        window?.isReleasedWhenClosed = false
        window?.alphaValue = 0.0

        return window

    }

    private func windowExists(_ type: HUDAlertTypes) -> NSWindow? {
        if let window = NSApplication.shared.windows.first(where: { $0.title == BBConstants.Window.modalWindowTitle }) {
            window
        } else {
            self.windowDefault(type)
        }
    }

    func windowHandleFrame(moved: NSRect? = nil) -> NSRect {
        let windowWidth = self.screen.width / 3
        let windowHeight = self.screen.height / 2
        let windowMargin = BBConstants.Window.defaultMargin

        let positionDefault = CGSize(width: 420, height: 220)

        if self.triggered > 5 {
            if let moved {
                _ = self.calculateWindowLastPosition(
                    moved: moved,
                    windowHeight: windowHeight,
                    windowWidth: windowWidth,
                    windowMargin: windowMargin
                )

                return NSRect(x: moved.origin.x, y: moved.origin.y, width: moved.width, height: moved.height)

            }

        } else {
            self.triggered += 1

        }

        return self.calculateInitialPosition(
            mode: self.windowLastPosition,
            defaultSize: positionDefault,
            windowMargin: windowMargin
        )

    }

    private var windowLastPosition: WindowPosition {
        get {
            if let position = UserDefaults.main
                .object(forKey: SystemDefaultsKeys.batteryWindowPosition.rawValue) as? String
            {
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5)) {
                    self.position = WindowPosition(rawValue: position) ?? .topMiddle

                }

            }

            return position

        }

        set {
            UserDefaults.save(.batteryWindowPosition, value: newValue.rawValue)

        }

    }

    private func calculateWindowLastPosition(
        moved: NSRect,
        windowHeight: CGFloat,
        windowWidth: CGFloat,
        windowMargin: CGFloat
    ) -> WindowPosition {
        var positionTop: CGFloat
        var positionMode: WindowPosition

        if moved.midY > windowHeight {
            positionTop = self.screen.height - windowMargin

        } else {
            positionTop = windowMargin

        }

        if moved.midX < windowWidth {
            positionMode = (positionTop == windowMargin) ? .bottomLeft : .topLeft

        } else if moved.midX > windowWidth, moved.midX < (windowWidth * 2) {
            positionMode = (positionTop == windowMargin) ? .center : .topMiddle

        } else if moved.midX > (windowWidth * 2) {
            positionMode = (positionTop == windowMargin) ? .bottomRight : .topRight

        } else {
            positionMode = .center

        }

        self.windowLastPosition = positionMode

        return positionMode

    }

    private func calculateInitialPosition(mode: WindowPosition, defaultSize: CGSize, windowMargin: CGFloat) -> NSRect {
        var positionLeft: CGFloat = windowMargin
        var positionTop: CGFloat = windowMargin

        switch mode {
        case .center:
            positionLeft = (self.screen.width / 2) - (defaultSize.width / 2)
            positionTop = (self.screen.height / 2) - (defaultSize.height / 2)

        case .topLeft, .bottomLeft:
            positionLeft = windowMargin
            positionTop = (mode == .topLeft) ? self.screen.height - (defaultSize.height + windowMargin) : windowMargin

        case .topMiddle:
            positionLeft = (self.screen.width / 2) - (defaultSize.width / 2)
            positionTop = self.screen.height - (defaultSize.height + windowMargin)

        case .topRight, .bottomRight:
            positionLeft = self.screen.width - (defaultSize.width + windowMargin)
            positionTop = (mode == .topRight) ? self.screen.height - (defaultSize.height + windowMargin) : windowMargin
        }

        return NSRect(x: positionLeft, y: positionTop, width: defaultSize.width, height: defaultSize.height)

    }

}

class WindowHostingView<Content: View>: NSHostingView<Content> {
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)

        if SettingsManager.shared.enabledPinned == .enabled {
            withAnimation(Animation.easeOut) {
                if WindowManager.shared.state == .revealed {
                    if event.deltaY < 0, WindowManager.shared.opacity > 0.4 {
                        WindowManager.shared.opacity += (event.deltaY / 100)

                    } else if event.deltaY > 0, WindowManager.shared.opacity < 1.0 {
                        WindowManager.shared.opacity += (event.deltaY / 100)

                    }

                }

            }

        }

    }

}
