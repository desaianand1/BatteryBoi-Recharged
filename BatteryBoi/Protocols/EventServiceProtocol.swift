//
//  EventServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the calendar event service interface.
/// Enables dependency injection and testability for event monitoring.
@MainActor
protocol EventServiceProtocol: AnyObject {
    // MARK: - Observable Properties

    /// Current calendar events containing URLs (video calls, etc.)
    var events: [EventObject] { get }

    // MARK: - Methods

    /// Force refresh of calendar events
    func refreshEvents()
}
