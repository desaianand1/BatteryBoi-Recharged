//
//  AppManagerProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Protocol defining the app manager interface.
/// Enables dependency injection and testability for app lifecycle management.
/// Note: device/alert state has moved to AppState. Menu remains here for view compatibility.
@MainActor
protocol AppManagerProtocol: AnyObject {
    // MARK: - Observable Properties

    /// Uptime counter in seconds since app launch
    var counter: Int { get }

    /// Current menu view state (for view compatibility)
    var menu: SystemMenuView { get set }

    /// Device type of this Mac
    var appDeviceType: SystemDeviceTypes { get }

    /// App installation date
    var appInstalled: Date { get }

    /// Unique app identifier
    var appIdentifyer: String { get }

    // MARK: - Methods

    /// Toggle between menu views
    /// - Parameter animate: Whether to animate the transition
    func appToggleMenu(_ animate: Bool)

    /// Get app distribution type
    /// - Returns: Distribution type (App Store or Direct)
    func appDistribution() async -> SystemDistribution
}
