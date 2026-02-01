//
//  BBWindowManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 8/5/23.
//

import Cocoa
import Combine
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

class WindowManager: ObservableObject {
    nonisolated(unsafe) static var shared = WindowManager()

    private var updates = Set<AnyCancellable>()
    private var triggered: Int = 0
    private var notifiedThresholds: Set<Int> = []
    private var screen: CGSize {
        if let activeScreen = NSScreen.screens.first(where: {
            NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
        }) ?? NSScreen.main {
            return activeScreen.frame.size
        }
        return CGSize(width: 1920, height: 1080)
    }

    @Published var hover: Bool = false
    @Published var state: HUDState = .hidden
    @Published var position: WindowPosition = .topMiddle
    @Published var opacity: CGFloat = 1.0

    init() {
        BatteryManager.shared.$charging.dropFirst().removeDuplicates().sink { charging in
            if charging.state == .charging {
                self.notifiedThresholds.removeAll()
            }
        }.store(in: &updates)

        BatteryManager.shared.$charging
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { charging in
                switch charging.state {
                case .battery: self.windowOpen(.chargingStopped, device: nil)
                case .charging: self.windowOpen(.chargingBegan, device: nil)
                }

            }.store(in: &updates)

        BatteryManager.shared.$percentage.dropFirst().removeDuplicates().sink { percent in
            if BatteryManager.shared.charging.state == .battery {
                let thresholds: [(Int, HUDAlertTypes)] = [
                    (25, .percentTwentyFive),
                    (10, .percentTen),
                    (5, .percentFive),
                    (1, .percentOne),
                ]

                for (threshold, alertType) in thresholds {
                    if percent <= Double(threshold), !self.notifiedThresholds.contains(threshold) {
                        self.notifiedThresholds.insert(threshold)
                        self.windowOpen(alertType, device: nil)
                        break
                    }
                }

            } else {
                if percent >= 100, SettingsManager.shared.enabledChargeEighty == .disabled {
                    self.windowOpen(.chargingComplete, device: nil)

                } else if percent >= 80, SettingsManager.shared.enabledChargeEighty == .enabled {
                    self.windowOpen(.chargingComplete, device: nil)

                }

            }

        }.store(in: &updates)

        BatteryManager.shared.$thermal.dropFirst().removeDuplicates().sink { state in
            if state == .suboptimal {
                self.windowOpen(.deviceOverheating, device: nil)

            }

        }.store(in: &updates)

//        BluetoothManager.shared.$connected.removeDuplicates().dropFirst(1).receive(on: DispatchQueue.main).sink() { items in
//            if let latest = items.sorted(by: { $0.updated > $1.updated }).first {
//                if latest.updated.now == true {
//                    switch latest.connected {
//                        case .connected : self.windowOpen(.deviceConnected, device: latest)
//                        default : break //self.windowOpen(.deviceRemoved, device: latest)
//
//                    }
//
//                }
//
//            }
//
//        }.store(in: &updates)

        AppManager.shared.appTimer(60).dropFirst().receive(on: DispatchQueue.main).sink { _ in
            let connected = BluetoothManager.shared.list.filter { $0.connected == .connected }

            for device in connected {
                switch device.battery.general {
                case 25: self.windowOpen(.percentTwentyFive, device: device)
                case 10: self.windowOpen(.percentTen, device: device)
                case 5: self.windowOpen(.percentFive, device: device)
                case 1: self.windowOpen(.percentOne, device: device)
                default: break
                }

            }

        }.store(in: &updates)

        AppManager.shared.$alert.removeDuplicates().delay(for: .seconds(5.0), scheduler: RunLoop.main).sink { _ in
            if AppManager.shared.alert?.timeout == true, self.state == .revealed {
                self.windowSetState(.dismissed)

            }

        }.store(in: &updates)

        AppManager.shared.$alert.removeDuplicates().delay(for: .seconds(10.0), scheduler: RunLoop.main).sink { _ in
            if AppManager.shared.alert?.timeout == false, self.state == .revealed {
                self.windowSetState(.dismissed)

            }

        }.store(in: &updates)

        AppManager.shared.appTimer(30).dropFirst().sink { _ in
            if BatteryManager.shared.charging.state == .battery {
                if let now = EventManager.shared.events.max(by: { $0.start < $1.start }) {
                    if let minutes = Calendar.current.dateComponents([.minute], from: Date(), to: now.start).minute {
                        switch minutes {
                        case 2: self.windowOpen(.userEvent, device: nil)
                        default: break
                        }

                    }

                }

            }

        }.store(in: &updates)

        SettingsManager.shared.$pinned.sink { pinned in
            if pinned == .enabled {
                withAnimation(Animation.easeOut) {
                    self.opacity = 1.0

                }

            }

        }.store(in: &updates)

        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { _ in
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

        $state.sink { state in
            if state == .dismissed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    Self.shared.windowClose()

                }

            } else if state == .progress {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.windowSetState(.revealed)

                }

            } else if state == .revealed, AppManager.shared.alert?.timeout == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.windowSetState(.detailed)

                }

            }

        }.store(in: &updates)

        position = windowLastPosition

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
        if let window = windowExists(type) {
            window.contentView = WindowHostingView(rootView: HUDParent(type, device: device))

            DispatchQueue.main.async {
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

    }

    private func windowClose() {
        if let window = NSApplication.shared.windows.first(where: { $0.title == "modalwindow" }) {
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
        window?.title = "modalwindow"
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
        if let window = NSApplication.shared.windows.first(where: { $0.title == "modalwindow" }) {
            window
        } else {
            windowDefault(type)
        }
    }

    func windowHandleFrame(moved: NSRect? = nil) -> NSRect {
        let windowWidth = screen.width / 3
        let windowHeight = screen.height / 2
        let windowMargin: CGFloat = 40

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
