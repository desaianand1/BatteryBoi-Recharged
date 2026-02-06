//
//  StatsModels.swift
//  BatteryBoi
//
//  Model types for statistics and activity tracking.
//

import Foundation

/// Stats state type for activity recording
enum StatsStateType: String, Sendable {
    case charging
    case depleted
    case connected
    case disconnected
}

/// CoreData container object
struct StatsContainerObject: Sendable {
    var directory: URL?
    var parent: URL?
}
