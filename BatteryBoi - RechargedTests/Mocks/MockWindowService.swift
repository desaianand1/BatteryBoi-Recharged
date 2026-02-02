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

        var lastSetState: HUDState?
        var lastSetStateAnimated: Bool?
        var lastIsVisibleType: HUDAlertTypes?
        var lastOpenType: HUDAlertTypes?
        var lastOpenDevice: BluetoothObject?

        // MARK: - Initialization

        init(
            hover: Bool = false,
            state: HUDState = .hidden,
            position: WindowPosition = .topMiddle,
            opacity: CGFloat = 1.0,
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
            lastOpenType = type
            lastOpenDevice = device
            state = .revealed
        }

        func calculateFrame(moved: NSRect?) -> NSRect {
            calculateFrameCallCount += 1
            if let moved {
                return moved
            }
            return NSRect(x: 100, y: 100, width: 420, height: 220)
        }

        // MARK: - Test Simulation

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
