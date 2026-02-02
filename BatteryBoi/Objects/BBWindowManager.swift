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
        windowSetState(state, animated: animated)
    }

    func isVisible(_ type: HUDAlertTypes) -> Bool {
        windowIsVisible(type)
    }

    func open(_ type: HUDAlertTypes, device: BluetoothObject?) {
        windowOpen(type, device: device)
    }

    func calculateFrame(moved: NSRect?) -> NSRect {
        windowHandleFrame(moved: moved)
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
            handleStateChange(state)
        }
    }

    var position: WindowPosition = .topMiddle
    var opacity: CGFloat = 1.0

    init() {
        lastChargingState = BatteryManager.shared.charging.state

        // Observe charging state changes with debounce
        chargingObserverTask = Task { @MainActor [weak self] in
            var previousCharging = BatteryManager.shared.charging
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { break }

                let currentCharging = BatteryManager.shared.charging
                if currentCharging != previousCharging {
                    // Reset thresholds when charging starts
                    if currentCharging.state == .charging {
                        notifiedThresholds.removeAll()
                    }

                    // Debounce the charging state change notification (2 seconds)
                    chargingDebounceTask?.cancel()
                    let newState = currentCharging.state
                    chargingDebounceTask = Task { @MainActor [weak self] in
                        do {
                            try await Task.sleep(for: .seconds(2))
                            guard let self, !Task.isCancelled else { return }
                            switch newState {
                            case .battery: windowOpen(.chargingStopped, device: nil)
                            case .charging: windowOpen(.chargingBegan, device: nil)
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
        percentageObserverTask = Task { @MainActor [weak self] in
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
                            if currentPercent <= Double(threshold), !notifiedThresholds.contains(threshold) {
                                notifiedThresholds.insert(threshold)
                                windowOpen(alertType, device: nil)
                                break
                            }
                        }
                    } else {
                        if currentPercent >= 100, SettingsManager.shared.enabledChargeEighty == .disabled {
                            windowOpen(.chargingComplete, device: nil)
                        } else if currentPercent >= 80, SettingsManager.shared.enabledChargeEighty == .enabled {
                            windowOpen(.chargingComplete, device: nil)
                        }
                    }

                    previousPercent = currentPercent
                }
            }
        }

        // Observe thermal state changes
        thermalObserverTask = Task { @MainActor [weak self] in
            var previousThermal = BatteryManager.shared.thermal
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }

                let currentThermal = BatteryManager.shared.thermal
                if currentThermal != previousThermal, currentThermal == .suboptimal {
                    windowOpen(.deviceOverheating, device: nil)
                }
                previousThermal = currentThermal
            }
        }

        // Check Bluetooth device battery levels every 60 seconds
        bluetoothTimerTask = Task { @MainActor [weak self] in
            var skipFirst = true
            for await _ in AppManager.shared.appTimerAsync(60) {
                guard let self, !Task.isCancelled else { break }
                if skipFirst { skipFirst = false; continue }

                let connected = BluetoothManager.shared.list.filter { $0.connected == .connected }

                for device in connected {
                    guard let percent = device.battery.general else { continue }
                    let deviceId = device.address

                    if notifiedBluetoothThresholds[deviceId] == nil {
                        notifiedBluetoothThresholds[deviceId] = []
                    }

                    let thresholds: [(Int, HUDAlertTypes)] = [
                        (25, .percentTwentyFive),
                        (10, .percentTen),
                        (5, .percentFive),
                        (1, .percentOne),
                    ]

                    for (threshold, alertType) in thresholds {
                        if percent <= Double(threshold),
                           !(notifiedBluetoothThresholds[deviceId]?.contains(threshold) ?? false)
                        {
                            notifiedBluetoothThresholds[deviceId]?.insert(threshold)
                            windowOpen(alertType, device: device)
                            break
                        }
                    }

                    if percent > 30 {
                        notifiedBluetoothThresholds[deviceId]?.removeAll()
                    }
                }
            }
        }

        // Check for upcoming events every 30 seconds
        eventTimerTask = Task { @MainActor [weak self] in
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
                                windowOpen(.userEvent, device: nil)
                            }
                        }
                    }
                }
            }
        }

        // Observe pinned setting changes
        pinnedObserverTask = Task { @MainActor [weak self] in
            for await key in UserDefaults.changedAsync() {
                guard let self, !Task.isCancelled else { break }
                if key == .enabledPinned, SettingsManager.shared.pinned == .enabled {
                    withAnimation(Animation.easeOut) {
                        self.opacity = 1.0
                    }
                }
            }
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseUp,
            .rightMouseUp,
        ]) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Debounce mouse events
                let now = Date()
                guard now.timeIntervalSince(lastMouseEventTime) > mouseEventDebounceInterval else { return }
                lastMouseEventTime = now

                if NSRunningApplication.current == NSWorkspace.shared.frontmostApplication {
                    if state == .revealed || state == .progress {
                        windowSetState(.detailed)
                    }
                } else {
                    if SettingsManager.shared.enabledPinned == .disabled {
                        if state.visible == true {
                            windowSetState(.dismissed)
                        }
                    } else {
                        windowSetState(.revealed)
                    }
                }
            }
        }

        position = windowLastPosition
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
        stateTransitionTask?.cancel()

        if state == .dismissed {
            // Cancel any pending dismissal when manually dismissed
            dismissalTask?.cancel()
            dismissalTask = nil

            stateTransitionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.8))
                guard let self, !Task.isCancelled else { return }
                Self.shared.windowClose()
            }
        } else if state == .progress {
            stateTransitionTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.2))
                guard let self, !Task.isCancelled else { return }
                windowSetState(.revealed)
            }
        } else if state == .revealed {
            // Transition to detailed view for non-timeout alerts after 1 second
            let shouldTransitionToDetailed = AppManager.shared.alert?.timeout == false
            if shouldTransitionToDetailed {
                stateTransitionTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, !Task.isCancelled else { return }
                    windowSetState(.detailed)
                }
            }

            // Schedule auto-dismissal based on alert timeout setting
            scheduleDismissal()
        }
    }

    /// Schedules auto-dismissal of the HUD based on the current alert's timeout setting.
    /// Cancels any existing dismissal task before scheduling a new one.
    private func scheduleDismissal() {
        dismissalTask?.cancel()

        // Capture the current state at scheduling time to avoid race conditions
        let targetState: HUDState = .revealed
        let timeout: Duration = AppManager.shared.alert?.timeout == true ? .seconds(5) : .seconds(10)

        dismissalTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: timeout)
                guard let self, !Task.isCancelled, state == targetState else { return }
                windowSetState(.dismissed)
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
        dismissalTask?.cancel()
        dismissalTask = nil

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

                windowSetState(.progress)
            }
        }
    }

    private func windowClose() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == BBConstants.Window.modalWindowTitle }) {
            if AppManager.shared.alert != nil {
                AppManager.shared.alert = nil
                AppManager.shared.device = nil

                state = .hidden

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
        window?.setFrame(windowHandleFrame(), display: true)
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
            windowDefault(type)
        }
    }

    func windowHandleFrame(moved: NSRect? = nil) -> NSRect {
        let windowWidth = screen.width / 3
        let windowHeight = screen.height / 2
        let windowMargin = BBConstants.Window.defaultMargin

        let positionDefault = CGSize(width: 420, height: 220)

        if triggered > 5 {
            if let moved {
                _ = calculateWindowLastPosition(
                    moved: moved,
                    windowHeight: windowHeight,
                    windowWidth: windowWidth,
                    windowMargin: windowMargin,
                )

                return NSRect(x: moved.origin.x, y: moved.origin.y, width: moved.width, height: moved.height)

            }

        } else {
            triggered += 1

        }

        return calculateInitialPosition(
            mode: windowLastPosition,
            defaultSize: positionDefault,
            windowMargin: windowMargin,
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
        windowMargin: CGFloat,
    ) -> WindowPosition {
        var positionTop: CGFloat
        var positionMode: WindowPosition

        if moved.midY > windowHeight {
            positionTop = screen.height - windowMargin

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

        windowLastPosition = positionMode

        return positionMode

    }

    private func calculateInitialPosition(mode: WindowPosition, defaultSize: CGSize, windowMargin: CGFloat) -> NSRect {
        var positionLeft: CGFloat = windowMargin
        var positionTop: CGFloat = windowMargin

        switch mode {
        case .center:
            positionLeft = (screen.width / 2) - (defaultSize.width / 2)
            positionTop = (screen.height / 2) - (defaultSize.height / 2)

        case .topLeft, .bottomLeft:
            positionLeft = windowMargin
            positionTop = (mode == .topLeft) ? screen.height - (defaultSize.height + windowMargin) : windowMargin

        case .topMiddle:
            positionLeft = (screen.width / 2) - (defaultSize.width / 2)
            positionTop = screen.height - (defaultSize.height + windowMargin)

        case .topRight, .bottomRight:
            positionLeft = screen.width - (defaultSize.width + windowMargin)
            positionTop = (mode == .topRight) ? screen.height - (defaultSize.height + windowMargin) : windowMargin
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
