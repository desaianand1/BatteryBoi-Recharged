//
//  EventModels.swift
//  BatteryBoi
//
//  Model types for calendar events.
//

import EventKit
import Foundation

/// Calendar event object for UI display
struct EventObject: Equatable, Sendable {
    var id: String
    var name: String
    var start: Date
    var end: Date

    init(_ event: EKEvent) {
        id = event.eventIdentifier
        name = event.title
        start = event.startDate
        end = event.endDate
    }

    /// Memberwise initializer for testing and manual construction
    init(id: String, name: String, start: Date, end: Date) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
    }
}
