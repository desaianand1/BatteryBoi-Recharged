//
//  BBTriggerManager.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 9/1/23.
//

import Foundation

/// Placeholder manager for custom trigger actions based on battery events.
/// TODO: Implement trigger system for custom battery actions (e.g., run scripts,
/// send notifications, or execute automations when battery reaches certain levels).
@MainActor
final class TriggerClass {
    static let shared = TriggerClass()

    init() {}

    /// Trigger action for a specific battery percentage threshold.
    /// - Parameter percent: The battery percentage that triggered this call.
    func triggerPercent(_: Double) {
        // TODO: Implement percentage-based triggers
    }

    /// Trigger action for a specific HUD alert state.
    /// - Parameters:
    ///   - state: The HUD alert type that triggered this call.
    ///   - device: The Bluetooth device associated with the trigger, if any.
    func triggerState(_ state: HUDAlertTypes, device _: BluetoothObject) {
        guard state.trigger else {
            // Not a trigger state, ignore silently
            return
        }

        // TODO: Implement state-based triggers (e.g., charging began, charging stopped)
    }

}
