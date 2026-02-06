//
//  HUDModels.swift
//  BatteryBoi
//
//  HUD and Window-related model types extracted for Swift 6.2 architecture.
//

import Foundation
import SwiftUI

// MARK: - HUD State

enum HUDState: Equatable, Sendable {
    case hidden
    case progress
    case revealed
    case detailed
    case dismissed

    var visible: Bool {
        switch self {
        case .hidden: false
        case .dismissed: false
        default: true
        }
    }

    var mask: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.6, delay: 0.2, easing: .bounce, width: 120, height: 120, blur: 0, radius: 66),
                .init(2.9, easing: .bounce, width: 430, height: 120, blur: 0, radius: 66),
            ], id: "initial")
        } else if self == .detailed {
            return .init([.init(0.0, easing: .bounce, width: 440, height: 220, radius: 42)], id: "expand_out")
        } else if self == .dismissed {
            return .init(
                [
                    .init(0.2, easing: .bounce, width: 430, height: 120, radius: 66),
                    .init(0.2, easing: .easeout, width: 120, height: 120, radius: 66),
                    .init(0.3, delay: 1.0, easing: .bounce, width: 40, height: 40, opacity: 0, radius: 66),
                ],
                id: "expand_close"
            )
        }
        return nil
    }

    var glow: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.03, easing: .easeout, opacity: 0.0, scale: 0.2),
                .init(0.4, easing: .bounce, opacity: 0.4, scale: 1.9),
                .init(0.4, easing: .easein, opacity: 0.0, blur: 2.0),
            ])
        } else if self == .dismissed {
            return .init([
                .init(0.03, easing: .easeout, opacity: 0.0, scale: 0.2),
                .init(0.4, easing: .easein, opacity: 0.6, scale: 1.4),
                .init(0.2, easing: .bounce, opacity: 0.0, scale: 0.2),
            ])
        }
        return nil
    }

    var progress: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.2, easing: .bounce, opacity: 0.0, blur: 0.0, scale: 0.8),
                .init(0.4, delay: 0.4, easing: .easeout, opacity: 1.0, scale: 1.0),
            ])
        } else if self == .dismissed {
            return .init([.init(0.6, easing: .bounce, opacity: 0.0, blur: 12.0, scale: 0.9)])
        }
        return nil
    }

    var container: AnimationObject? {
        if self == .detailed {
            return .init([.init(0.4, easing: .easeout, padding: .init(top: 24, bottom: 16))], id: "hud_expand")
        } else if self == .dismissed {
            return .init([.init(0.6, delay: 0.2, easing: .easeout, opacity: 0.0, blur: 5.0)])
        }
        return nil
    }
}

// MARK: - HUD Alert Types

enum HUDAlertTypes: Equatable, Sendable {
    case userLaunched
    case userInitiated
    case chargingBegan
    case chargingStopped
    case chargingComplete
    case percentOne
    case percentFive
    case percentTen
    case percentTwentyFive
    case deviceConnected
    case deviceRemoved
    case deviceOverheating
    case userEvent

    var timeout: Bool {
        switch self {
        case .userLaunched: true
        case .userInitiated: false
        case .chargingBegan: true
        case .chargingStopped: true
        case .chargingComplete: true
        case .percentOne: true
        case .percentFive: true
        case .percentTen: true
        case .percentTwentyFive: true
        case .deviceConnected: true
        case .deviceRemoved: true
        case .deviceOverheating: true
        case .userEvent: true
        }
    }

    var sfx: SystemSoundEffects? {
        switch self {
        case .chargingBegan: .high
        case .chargingStopped: .low
        case .chargingComplete: .high
        case .percentOne: .low
        case .percentFive: .low
        case .percentTen: .low
        case .percentTwentyFive: .low
        case .deviceOverheating: .low
        case .userEvent: .low
        default: nil
        }
    }
}

// MARK: - Window Position

enum WindowPosition: String, Sendable {
    case center
    case topLeft
    case topMiddle
    case topRight
    case bottomLeft
    case bottomRight

    var alignment: Alignment {
        switch self {
        case .center: .center
        case .topLeft: .topLeading
        case .topMiddle: .top
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        }
    }
}

// MARK: - HUD Progress Layout

enum HUDProgressLayout: Sendable {
    case center
    case trailing
}

// MARK: - Stats Display Object

struct StatsDisplayObject: Sendable {
    var standard: String?
    var overlay: String?
}

// MARK: - Stats Icon

struct StatsIcon: Sendable {
    var name: String
    var system: Bool
}
