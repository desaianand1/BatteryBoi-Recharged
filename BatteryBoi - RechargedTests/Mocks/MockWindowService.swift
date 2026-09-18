//
//  MockWindowService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import CoreGraphics
import Foundation

#if DEBUG

    /// Mock window service for unit testing.
    @Observable
    @MainActor
    final class MockWindowService: WindowServiceProtocol {

        // MARK: - Observable Properties

        var hover: Bool
        var state: HUDState
        var position: WindowPosition
        var opacity: CGFloat

        // MARK: - Test Helpers

        var setStateCallCount = 0
        var isVisibleCallCount = 0
        var openCallCount = 0
        var calculateFrameCallCount = 0
        var handleSleepCallCount = 0
        var handleWakeCallCount = 0

        var lastSetState: HUDState?
        var lastSetStateAnimated: Bool?
        var lastIsVisibleType: HUDAlertTypes?
        var lastOpenType: HUDAlertTypes?
        var lastOpenDevice: BluetoothObject?
        var openHistory: [HUDAlertTypes] = []

        // MARK: - Initialization

        init(
            hover: Bool = false,
            state: HUDState = .hidden,
            position: WindowPosition = .topMiddle,
            opacity: CGFloat = 1.0
        ) {
            self.hover = hover
            self.state = state
            self.position = position
            self.opacity = opacity
        }

        // MARK: - Methods

        func setState(_ state: HUDState, animated: Bool) {
            setStateCallCount += 1
            lastSetState = state
            lastSetStateAnimated = animated
            self.state = state
        }

        func isVisible(_ type: HUDAlertTypes) -> Bool {
            isVisibleCallCount += 1
            lastIsVisibleType = type
            return state.visible
        }

        func open(_ type: HUDAlertTypes, device: BluetoothObject?) {
            openCallCount += 1

            if type != .userInitiated {
                if let current = currentAlert, current != type, type.priority < current.priority {
                    if alertQueue.count < maxQueueSize {
                        alertQueue.append((type: type, device: device))
                    }
                    return
                }
            }

            openHistory.append(type)
            lastOpenType = type
            lastOpenDevice = device
            currentAlert = type
            currentDevice = device
            state = .revealed
        }

        func calculateFrame(moved: NSRect?) -> NSRect {
            calculateFrameCallCount += 1
            if let moved {
                return moved
            }
            return NSRect(x: 100, y: 100, width: 450, height: 250)
        }

        func handleSleep() {
            handleSleepCallCount += 1
            navigationRequest = nil
        }

        func handleWake() {
            handleWakeCallCount += 1
            state = .hidden
            currentAlert = nil
            alertQueue.removeAll()
            openHistory.removeAll()
        }

        var setPositionCallCount = 0
        var lastSetPosition: WindowPosition?

        func setPosition(_ position: WindowPosition) {
            setPositionCallCount += 1
            lastSetPosition = position
            self.position = position
        }

        var toggleExpandedCallCount = 0

        func toggleExpanded() {
            toggleExpandedCallCount += 1
            if state == .revealed {
                state = .detailed
            } else if state == .detailed {
                state = .revealed
            }
        }

        // MARK: - Navigation

        var navigationRequest: NavigationRequest?
        var navigateCallCount = 0
        var lastNavigateRequest: NavigationRequest?

        func navigate(to request: NavigationRequest) {
            navigateCallCount += 1
            lastNavigateRequest = request
            navigationRequest = request
            if !state.visible {
                open(.userInitiated, device: nil)
            }
            if state != .detailed {
                state = .detailed
            }
        }

        // MARK: - Alert Tracking

        var currentAlert: HUDAlertTypes?
        var currentDevice: BluetoothObject?

        // MARK: - Alert Queue

        var alertQueue: [(type: HUDAlertTypes, device: BluetoothObject?)] = []
        private let maxQueueSize = 5

        // MARK: - Test Simulation

        func simulateDismissal() {
            currentAlert = nil
            currentDevice = nil
            navigationRequest = nil
            state = .hidden

            if let next = alertQueue.first {
                alertQueue.removeFirst()
                open(next.type, device: next.device)
            }
        }

        func simulateHoverChange(_ newHover: Bool) {
            hover = newHover
        }

        func simulateStateChange(_ newState: HUDState) {
            state = newState
        }

        /// Simulates a mouse event (for testing debounce behavior)
        func simulateMouseEvent() {
            // In real implementation, this would trigger state changes
            // Here we just track that it was called
            if state == .revealed || state == .progress {
                setState(.detailed, animated: false)
            }
        }
    }

#endif
