//
//  WindowService.swift
//  BatteryBoi
//

import Cocoa
import CoreGraphics
import Foundation
import SwiftUI

class HUDPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.hidesOnDeactivate = false
        self.isFloatingPanel = true
        self.level = .floating
        self.becomesKeyOnlyIfNeeded = true
        self.animationBehavior = .utilityWindow
    }
}

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

class WindowHostingView<Content: View>: NSHostingView<Content> {
    var scrollHandler: ((NSEvent) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        scrollHandler?(event)
    }
}

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

    // MARK: - Alert State

    private(set) var currentAlert: HUDAlertTypes?
    var currentDevice: BluetoothObject?

    // MARK: - Dependencies

    private let settings: any SettingsServiceProtocol
    private let environmentProvider: @MainActor () -> AppEnvironment

    // MARK: - Private Properties

    private var triggered: Int = 0
    nonisolated(unsafe) private var globalMouseMonitor: Any?
    nonisolated(unsafe) private var dismissalTask: Task<Void, Never>?
    nonisolated(unsafe) private var stateTransitionTask: Task<Void, Never>?
    nonisolated(unsafe) private var debounceDeferralTask: Task<Void, Never>?
    nonisolated(unsafe) private var mouseEventTask: Task<Void, Never>?

    private var lastMouseEventTime: Date = .distantPast
    private var lastOpenedTime: Date = .distantPast
    private var lastStateChangeTime: Date = .distantPast

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

    func handleSleep() {
        dismissalTask?.cancel()
        stateTransitionTask?.cancel()
        debounceDeferralTask?.cancel()
        mouseEventTask?.cancel()
    }

    func handleWake() {
        if state.visible {
            state = .hidden
            if let window = NSApplication.shared.windows.first(where: {
                $0.title == Constants.Window.modalWindowTitle
            }) {
                window.alphaValue = 0.0
            }
        }
        currentAlert = nil
        currentDevice = nil
        triggered = 0
    }

    // MARK: - Initialization

    init(
        settings: any SettingsServiceProtocol = SettingsService.shared,
        environment: @MainActor @escaping () -> AppEnvironment = { AppEnvironment.shared }
    ) {
        self.settings = settings
        self.environmentProvider = environment
        setupMouseMonitor()
        position = windowLastPosition
    }

    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
        dismissalTask?.cancel()
        stateTransitionTask?.cancel()
        debounceDeferralTask?.cancel()
        mouseEventTask?.cancel()
    }

    // MARK: - Private Methods

    private func setupMouseMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .leftMouseUp,
            .rightMouseUp,
        ]) { [weak self] _ in
            self?.mouseEventTask?.cancel()
            self?.mouseEventTask = Task { [weak self] in
                guard let self else { return }

                let now = Date()
                guard now.timeIntervalSince(self.lastOpenedTime) > Constants.Timers.clickGracePeriod else { return }

                guard now.timeIntervalSince(self.lastMouseEventTime) > Constants.Timers.mouseEventDebounce
                else { return }
                self.lastMouseEventTime = now

                let mouseLocation = NSEvent.mouseLocation
                let clickedInsideHUD = NSApplication.shared.windows
                    .first(where: { $0.title == Constants.Window.modalWindowTitle })
                    .map { NSMouseInRect(mouseLocation, $0.frame, false) } ?? false

                if clickedInsideHUD {
                    if self.state == .revealed || self.state == .progress {
                        self.windowSetState(.detailed)
                    }
                } else {
                    if self.settings.pinned == .disabled {
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
        stateTransitionTask?.cancel()

        if state == .dismissed {
            dismissalTask?.cancel()
            dismissalTask = nil

            stateTransitionTask = Task {
                try? await Task.sleep(for: .seconds(Constants.Timers.hudDismissDelay))
                guard !Task.isCancelled else { return }
                windowClose()
            }
        } else if state == .progress {
            stateTransitionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Constants.Timers.hudProgressDelay))
                guard let self, !Task.isCancelled else { return }
                windowSetState(.revealed)
            }
        } else if state == .revealed {
            stateTransitionTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Constants.Timers.hudRevealDelay))
                guard let self, !Task.isCancelled else { return }
                windowSetState(.detailed)
            }
            scheduleDismissal()
        }
    }

    private func scheduleDismissal() {
        dismissalTask?.cancel()

        guard self.settings.pinned != .enabled else { return }

        let timeout: Duration = currentAlert?.timeout == true
            ? .seconds(Constants.Timers.hudTimeoutShort)
            : .seconds(Constants.Timers.hudTimeoutLong)

        dismissalTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
                guard let self, !Task.isCancelled, state.visible else { return }
                windowSetState(.dismissed)
            } catch {}
        }
    }

    func windowSetState(_ state: HUDState, animated: Bool = true) {
        let now = Date()
        if now.timeIntervalSince(lastStateChangeTime) > Constants.Timers.stateChangeDebounce {
            applyStateChange(state, animated: animated)
        } else {
            debounceDeferralTask?.cancel()
            debounceDeferralTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Constants.Timers.stateChangeDebounce))
                guard let self, !Task.isCancelled else { return }
                self.applyStateChange(state, animated: animated)
            }
        }
    }

    private func applyStateChange(_ state: HUDState, animated: Bool) {
        lastStateChangeTime = Date()
        guard self.state != state else { return }
        if animated {
            withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: 1.0)) {
                self.state = state
            }
        } else {
            self.state = state
        }
    }

    func windowIsVisible(_: HUDAlertTypes) -> Bool {
        state.visible
    }

    func windowOpen(_ type: HUDAlertTypes, device: BluetoothObject?) {
        dismissalTask?.cancel()
        dismissalTask = nil

        guard let window = windowExists(type) else {
            BLogger.window.error("Failed to create window for alert: \(type)")
            return
        }

        let rootView = HUDParent(type, device: device).environment(self.environmentProvider())
        let hostingView = WindowHostingView(rootView: rootView)
        hostingView.scrollHandler = { [weak self] event in
            guard let self, self.settings.pinned == .enabled else { return }
            withAnimation(Animation.easeOut) {
                if self.state == .revealed {
                    if event.deltaY < 0, self.opacity > Constants.Timers.scrollOpacityMin {
                        self.opacity += (event.deltaY / Constants.Timers.scrollOpacityDivisor)
                    } else if event.deltaY > 0, self.opacity < Constants.Timers.scrollOpacityMax {
                        self.opacity += (event.deltaY / Constants.Timers.scrollOpacityDivisor)
                    }
                }
            }
        }
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.alphaValue = 1.0

        if currentAlert == nil || currentAlert != type {
            if let sfx = type.sfx {
                sfx.play()
            }
        }

        currentDevice = device
        currentAlert = type

        lastOpenedTime = Date()
        windowSetState(.progress)
    }

    private func windowClose() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == Constants.Window.modalWindowTitle }) {
            if currentAlert != nil {
                currentAlert = nil
                currentDevice = nil

                state = .hidden

                window.alphaValue = 0.0
            }
        }
    }

    private func windowDefault(_: HUDAlertTypes) -> NSWindow? {
        let frame = windowHandleFrame()
        let panel = HUDPanel(contentRect: frame)
        panel.contentView?.translatesAutoresizingMaskIntoConstraints = false
        panel.title = Constants.Window.modalWindowTitle
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.setFrame(frame, display: true)
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.alphaValue = 0.0
        return panel
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
