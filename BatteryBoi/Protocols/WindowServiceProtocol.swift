//
//  WindowServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import CoreGraphics
import Foundation

enum NavigationRequest: Equatable {
    case tab(ExpandedTab)
    case deviceDetail(String?)
}

/// Protocol defining the window management service interface.
/// Enables dependency injection and testability for HUD window management.
@MainActor
protocol WindowServiceProtocol: AnyObject {

    // MARK: - Observable Properties

    /// Whether the window is being hovered
    var hover: Bool { get set }

    /// Current HUD state
    var state: HUDState { get }

    /// Current window position
    var position: WindowPosition { get set }

    /// Current window opacity
    var opacity: CGFloat { get set }

    /// Current alert type being displayed
    var currentAlert: HUDAlertTypes? { get }

    /// Current device for Bluetooth alerts
    var currentDevice: BluetoothObject? { get set }

    /// Queued alerts waiting to be shown after the current alert dismisses
    var alertQueue: [(type: HUDAlertTypes, device: BluetoothObject?)] { get }

    /// Pending navigation request for programmatic tab/detail switches
    var navigationRequest: NavigationRequest? { get set }

    // MARK: - Methods

    /// Set the HUD state with optional animation
    /// - Parameters:
    ///   - state: The new state
    ///   - animated: Whether to animate the transition
    func setState(_ state: HUDState, animated: Bool)

    /// Check if the window is visible for a given alert type
    /// - Parameter type: The alert type
    /// - Returns: Whether the window is visible
    func isVisible(_ type: HUDAlertTypes) -> Bool

    /// Open the HUD window with an alert
    /// - Parameters:
    ///   - type: The alert type
    ///   - device: Optional Bluetooth device associated with the alert
    func open(_ type: HUDAlertTypes, device: BluetoothObject?)

    /// Calculate the window frame
    /// - Parameter moved: Optional new position from user drag
    /// - Returns: The calculated frame
    func calculateFrame(moved: NSRect?) -> NSRect

    /// Handle system sleep — cancel pending timers and transitions
    func handleSleep()

    /// Handle system wake — reset window state for clean restart
    func handleWake()

    /// Toggle between .revealed and .detailed states
    func toggleExpanded()

    /// Set the window anchor position, persist it, and animate the window if visible
    func setPosition(_ position: WindowPosition)

    /// Navigate to a specific tab or device detail, opening/expanding the HUD as needed
    func navigate(to request: NavigationRequest)

    /// Currently active flash event for subtitle overlay
    var activeFlash: FlashEvent? { get }

    /// Display a transient flash event in the subtitle area (only fires in .revealed state)
    func showFlash(_ event: FlashEvent)

    /// Update the current device reference to trigger reactive UI updates
    func updateCurrentDevice(_ device: BluetoothObject)

    /// Queue an alert for delivery after the current alert dismisses
    func enqueueAlert(_ type: HUDAlertTypes, device: BluetoothObject?)
}
