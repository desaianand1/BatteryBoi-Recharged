//
//  UpdateManagerProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the update manager interface.
/// Enables dependency injection and testability for update functionality.
@MainActor
protocol UpdateManagerProtocol: AnyObject {
    // MARK: - Observable Properties

    /// Current update state
    var state: UpdateStateType { get }

    /// Available update info
    var available: UpdatePayloadObject? { get }

    /// Last update check date
    var checked: Date? { get }

    /// Whether automatic updates are enabled
    var automaticUpdates: Bool { get set }

    /// Current app version
    var currentVersion: String { get }

    /// Current app build number
    var currentBuild: String { get }

    /// Formatted version display string
    var versionDisplay: String { get }

    // MARK: - Methods

    /// Check for available updates
    func updateCheck()
}
