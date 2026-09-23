//
//  HUDModels.swift
//  BatteryBoi
//
//  HUD and Window-related model types extracted for Swift 6.2 architecture.
//

import Foundation
import SwiftUI

// MARK: - HUD Animation Value Types

struct HUDMaskValues {
    var width: CGFloat = 8
    var height: CGFloat = 8
    var radius: CGFloat = 4
    var opacity: CGFloat = 0.0
}

struct HUDGlowValues {
    var opacity: CGFloat = 0.0
    var scale: CGFloat = 0.2
}

// MARK: - HUD Animation Phases

enum HUDMaskPhase {
    case idle
    case reveal
    case expand
    case collapse
    case dismiss
}

enum HUDGlowPhase {
    case idle
    case reveal
    case dismiss
}

// MARK: - HUD State

enum HUDState: Equatable {
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
}

// MARK: - Alert Priority

enum AlertPriority: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - HUD Alert Types

enum HUDAlertTypes: Equatable {
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
    case percentCustom(Int)

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
        case .percentCustom: true
        case .deviceConnected: true
        case .deviceRemoved: true
        case .deviceOverheating: true
        case .userEvent: true
        }
    }

    var priority: AlertPriority {
        switch self {
        case .percentOne, .deviceOverheating: .critical
        case .percentFive, .chargingComplete: .high
        case .chargingBegan, .chargingStopped, .percentTen,
             .percentTwentyFive, .deviceConnected, .deviceRemoved: .medium
        case let .percentCustom(p): AlertThresholdTier.tier(for: p).priority
        case .userLaunched, .userEvent: .low
        case .userInitiated: .low
        }
    }

    var sfx: SystemSoundEffects? {
        switch self {
        case .chargingBegan: .high
        case .chargingStopped: .low
        case .chargingComplete: .high
        case .percentOne: .critical
        case .percentFive: .low
        case .percentTen: .low
        case .percentTwentyFive: .low
        case let .percentCustom(p):
            AlertThresholdTier.tier(for: p) == .critical ? .critical : .low
        case .deviceOverheating: .low
        case .userEvent: .low
        default: nil
        }
    }

    static func alertType(for threshold: Int) -> Self {
        switch threshold {
        case 1: .percentOne
        case 5: .percentFive
        case 10: .percentTen
        case 25: .percentTwentyFive
        default: .percentCustom(threshold)
        }
    }
}

// MARK: - Window Position

enum WindowPosition: String, CaseIterable {
    case topLeft
    case topMiddle
    case topRight
    case bottomLeft
    case bottomMiddle
    case bottomRight

    var alignment: Alignment {
        switch self {
        case .topLeft: .topLeading
        case .topMiddle: .top
        case .topRight: .topTrailing
        case .bottomLeft: .bottomLeading
        case .bottomMiddle: .bottom
        case .bottomRight: .bottomTrailing
        }
    }

    var isTop: Bool {
        switch self {
        case .topLeft, .topMiddle, .topRight: true
        case .bottomLeft, .bottomMiddle, .bottomRight: false
        }
    }

    var normalizedPoint: CGPoint {
        let x: CGFloat
        let y: CGFloat
        switch self {
        case .topLeft, .bottomLeft: x = 0.0
        case .topMiddle, .bottomMiddle: x = 0.5
        case .topRight, .bottomRight: x = 1.0
        }
        switch self {
        case .topLeft, .topMiddle, .topRight: y = 1.0
        case .bottomLeft, .bottomMiddle, .bottomRight: y = 0.0
        }
        return CGPoint(x: x, y: y)
    }

    var displayName: String {
        switch self {
        case .topLeft: "WindowPositionTopLeft".localise()
        case .topMiddle: "WindowPositionTopMiddle".localise()
        case .topRight: "WindowPositionTopRight".localise()
        case .bottomLeft: "WindowPositionBottomLeft".localise()
        case .bottomMiddle: "WindowPositionBottomMiddle".localise()
        case .bottomRight: "WindowPositionBottomRight".localise()
        }
    }

    var iconName: String {
        switch self {
        case .topLeft: "arrow.up.left"
        case .topMiddle: "arrow.up"
        case .topRight: "arrow.up.right"
        case .bottomLeft: "arrow.down.left"
        case .bottomMiddle: "arrow.down"
        case .bottomRight: "arrow.down.right"
        }
    }

    static func nearest(to point: CGPoint, excluding: Self? = nil) -> Self {
        let sorted = allCases.sorted { a, b in
            distance(from: point, to: a.normalizedPoint) < distance(from: point, to: b.normalizedPoint)
        }
        if let excluding, sorted.first == excluding {
            return sorted.dropFirst().first ?? .topMiddle
        }
        return sorted.first ?? .topMiddle
    }

    private static func distance(from a: CGPoint, to b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return (dx * dx) + (dy * dy)
    }
}

// MARK: - HUD Progress Layout

enum HUDProgressLayout {
    case center
    case trailing
}

// MARK: - Stats Icon

struct StatsIcon {
    var name: String
    var color: Color
    var effect: HUDIconEffect
}

// MARK: - Flash Event

struct FlashEvent: Equatable {
    let text: String
    let color: Color
    let priority: AlertPriority
    let duration: TimeInterval

    static let defaultDuration: TimeInterval = 4.5
    static let fadeIn: TimeInterval = 0.3
    static let fadeOut: TimeInterval = 0.3

    static func from(_ alert: HUDAlertTypes) -> Self? {
        switch alert {
        case .deviceOverheating:
            Self(
                text: "FlashOverheatingLabel".localise(),
                color: SemanticColor.error,
                priority: .critical,
                duration: 5.0
            )
        case .chargingComplete:
            Self(
                text: "FlashChargeLimitReachedLabel".localise(),
                color: .accentColor,
                priority: .high,
                duration: 5.0
            )
        case .chargingBegan:
            Self(
                text: "FlashChargingLabel".localise(),
                color: BatteryTier.chargingBoltColor,
                priority: .medium,
                duration: 4.0
            )
        case .chargingStopped:
            Self(
                text: "FlashOnBatteryLabel".localise(),
                color: Color("BBSubtitle"),
                priority: .medium,
                duration: 4.0
            )
        case let .percentCustom(p):
            Self(
                text: AlertThresholdTier.subtitle(for: p),
                color: AlertThresholdTier.tier(for: p).dotColor,
                priority: AlertThresholdTier.tier(for: p).priority,
                duration: Self.defaultDuration
            )
        default:
            nil
        }
    }

    static func keepAwakeExpiring(minutes: Int) -> Self {
        Self(
            text: "FlashKeepAwakeExpiringLabel".localise([minutes]),
            color: Color("BBSubtitle"),
            priority: .medium,
            duration: 4.5
        )
    }

    static let keepAwakeDisabledLowBattery = Self(
        text: "FlashKeepAwakeDisabledLowBatteryLabel".localise(),
        color: SemanticColor.warning,
        priority: .high,
        duration: 5.0
    )
}
