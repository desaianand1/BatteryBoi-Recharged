//
//  WindowService.swift
//  BatteryBoi
//
//  Window service with proper task lifecycle management.
//  Alert threshold logic has been moved to ServiceCoordinator.
//

import Cocoa
import CoreGraphics
import Foundation
import SwiftUI

/// Custom NSWindow that allows borderless windows to become key.
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

/// NSVisualEffectView wrapper for SwiftUI
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

/// NSHostingView with scroll wheel handling for opacity
class WindowHostingView<Content: View>: NSHostingView<Content> {
    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)

        if SettingsService.shared.enabledPinned == .enabled {
            withAnimation(Animation.easeOut) {
                if WindowService.shared.state == .revealed {
                    if event.deltaY < 0, WindowService.shared.opacity > 0.4 {
                        WindowService.shared.opacity += (event.deltaY / 100)
                    } else if event.deltaY > 0, WindowService.shared.opacity < 1.0 {
                        WindowService.shared.opacity += (event.deltaY / 100)
                    }
                }
            }
        }
    }
}

/// Service for managing HUD windows.
/// MainActor isolated for Swift 6.2 strict concurrency compliance.
/// Alert threshold logic has been moved to ServiceCoordinator.
@Observable
@MainActor
final class WindowService: WindowServiceProtocol {
    // MARK: - Static Instance

    static let shared = WindowService()

    // MARK: - Observable Properties

    var hover: Bool = false
    var state: HUDState = .hidden {
        didSet {
            handleStateChange(state)
        }
    }

    var position: WindowPosition = .topMiddle
    var opacity: CGFloat = 1.0

    // MARK: - Alert State (local tracking to avoid AppManager dependency)

    /// Current alert type being displayed
    private(set) var currentAlert: HUDAlertTypes?

    /// Current device for Bluetooth alerts
    private(set) var currentDevice: BluetoothObject?

    // MARK: - Private Properties

    private var triggered: Int = 0
    // Note: nonisolated(unsafe) is justified for properties accessed in deinit per SE-0371
    nonisolated(unsafe) private var globalMouseMonitor: Any?
    nonisolated(unsafe) private var dismissalTask: Task<Void, Never>?
    nonisolated(unsafe) private var stateTransitionTask: Task<Void, Never>?

    // Mouse event debouncing
    private var lastMouseEventTime: Date = .distantPast
    private let mouseEventDebounceInterval: TimeInterval = 0.1

    // State change debouncing
    private var lastStateChangeTime: Date = .distantPast
    private let stateChangeDebounceInterval: TimeInterval = 0.15

    private var screen: CGSize {
        if let activeScreen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main {
            return activeScreen.frame.size
        }
        return CGSize(width: 1920, height: 1080)
    }

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

    // MARK: - Initialization

    init() {
        setupMouseMonitor()
        position = windowLastPosition
    }

    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        dismissalTask?.cancel()
        stateTransitionTask?.cancel()
    }

    // MARK: - Private Methods

    private func setupMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseUp,
            .rightMouseUp,
        ]) { [weak self] _ in
            Task { [weak self] in
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
                    if SettingsService.shared.enabledPinned == .disabled {
                        if self.state.visible == true {
                            self.windowSetState(.dismissed)
                        }
                    } else {
                        self.windowSetState(.revealed)
                    }
                }
            }
        }
    }

    private func handleStateChange(_ state: HUDState) {
        // Cancel any pending state transition tasks
        stateTransitionTask?.cancel()

        if state == .dismissed {
            // Cancel any pending dismissal when manually dismissed
            dismissalTask?.cancel()
            dismissalTask = nil

            stateTransitionTask = Task {
                try? await Task.sleep(for: .seconds(0.8))
                guard !Task.isCancelled else { return }
                windowClose()
            }
        } else if state == .progress {
            stateTransitionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.2))
                guard let self, !Task.isCancelled else { return }
                windowSetState(.revealed)
            }
        } else if state == .revealed {
            // Transition to detailed view for non-timeout alerts after 1 second
            let shouldTransitionToDetailed = currentAlert?.timeout == false
            if shouldTransitionToDetailed {
                stateTransitionTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    guard let self, !Task.isCancelled else { return }
                    windowSetState(.detailed)
                }
            }

            // Schedule auto-dismissal
            scheduleDismissal()
        }
    }

    private func scheduleDismissal() {
        dismissalTask?.cancel()

        let targetState: HUDState = .revealed
        let timeout: Duration = currentAlert?.timeout == true ? .seconds(5) : .seconds(10)

        dismissalTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
                guard let self, !Task.isCancelled, state == targetState else { return }
                windowSetState(.dismissed)
            } catch {
                // Task was cancelled
            }
        }
    }

    func windowSetState(_ state: HUDState, animated _: Bool = true) {
        let now = Date()
        guard now.timeIntervalSince(lastStateChangeTime) > stateChangeDebounceInterval else { return }
        lastStateChangeTime = now

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

        guard let window = windowExists(type) else {
            BLogger.window.error("Failed to create window for alert: \(type)")
            return
        }

        window.contentView = WindowHostingView(rootView: HUDParent(type, device: device))
        window.makeKeyAndOrderFront(nil)
        window.alphaValue = 1.0

        // Play sound only on new alerts
        if currentAlert == nil {
            if let sfx = type.sfx {
                sfx.play()
            }
        }

        // Update menu to devices if Bluetooth devices are connected
        if !BluetoothService.shared.connected.isEmpty {
            ServiceContainer.shared.state.currentMenu = .devices
        }

        // Update local state
        currentDevice = device
        currentAlert = type

        // Update AppState for views
        ServiceContainer.shared.state.selectedDevice = device
        ServiceContainer.shared.state.currentAlert = type

        windowSetState(.progress)
    }

    private func windowClose() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == Constants.Window.modalWindowTitle }) {
            if currentAlert != nil {
                // Clear local state
                currentAlert = nil
                currentDevice = nil

                // Clear AppState
                ServiceContainer.shared.state.currentAlert = nil
                ServiceContainer.shared.state.selectedDevice = nil

                state = .hidden

                window.alphaValue = 0.0
            }
        }
    }

    private func windowDefault(_: HUDAlertTypes) -> NSWindow? {
        var window: NSWindow?
        window = KeyableWindow()
        window?.styleMask = [.borderless, .miniaturizable]
        window?.level = .statusBar
        window?.contentView?.translatesAutoresizingMaskIntoConstraints = false
        window?.center()
        window?.title = Constants.Window.modalWindowTitle
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
        if let window = NSApplication.shared.windows.first(where: { $0.title == Constants.Window.modalWindowTitle }) {
            window
        } else {
            windowDefault(type)
        }
    }

    func windowHandleFrame(moved: NSRect? = nil) -> NSRect {
        let windowWidth = screen.width / 3
        let windowHeight = screen.height / 2
        let windowMargin = Constants.Window.defaultMargin

        let positionDefault = CGSize(width: 420, height: 220)

        if triggered > 5 {
            if let moved {
                _ = calculateWindowLastPosition(
                    moved: moved,
                    windowHeight: windowHeight,
                    windowWidth: windowWidth,
                    windowMargin: windowMargin
                )

                return NSRect(x: moved.origin.x, y: moved.origin.y, width: moved.width, height: moved.height)
            }
        } else {
            triggered += 1
        }

        return calculateInitialPosition(
            mode: windowLastPosition,
            defaultSize: positionDefault,
            windowMargin: windowMargin
        )
    }

    private var windowLastPosition: WindowPosition {
        get {
            if let positionString = UserDefaults.main
                .object(forKey: SystemDefaultsKeys.batteryWindowPosition.rawValue) as? String
            {
                withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.5)) {
                    position = WindowPosition(rawValue: positionString) ?? .topMiddle
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
