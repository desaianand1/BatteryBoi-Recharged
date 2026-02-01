//
//  WindowServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Combine
import CoreGraphics
import Foundation

/// Protocol defining the window management service interface.
/// Enables dependency injection and testability for HUD window management.
@MainActor
protocol WindowServiceProtocol: AnyObject {
    // MARK: - Published Properties

    /// Whether the window is being hovered
    var hover: Bool { get set }

    /// Current HUD state
    var state: HUDState { get }

    /// Current window position
    var position: WindowPosition { get }

    /// Current window opacity
    var opacity: CGFloat { get set }

    // MARK: - Publishers

    /// Publisher for HUD state changes
    var statePublisher: AnyPublisher<HUDState, Never> { get }

    /// Publisher for hover state changes
    var hoverPublisher: AnyPublisher<Bool, Never> { get }

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
}
