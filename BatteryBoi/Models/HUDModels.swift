//
//  HUDModels.swift
//  BatteryBoi
//
//  HUD and Window-related model types extracted for Swift 6.2 architecture.
//

import Foundation
import SwiftUI

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

    var mask: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(
                    RevealTiming.circleBounce,
                    delay: RevealTiming.circlePause,
                    easing: .bounce,
                    width: 120,
                    height: 120,
                    blur: 0,
                    radius: Constants.CornerRadius.maskCircle
                ),
                .init(
                    RevealTiming.pillExpansion,
                    easing: .bounce,
                    width: 430,
                    height: 120,
                    blur: 0,
                    radius: Constants.CornerRadius.maskCircle
                ),
            ], id: "initial")
        } else if self == .detailed {
            return .init(
                [.init(
                    RevealTiming.expandDuration, easing: .bounce,
                    width: 500, height: 460,
                    radius: Constants.CornerRadius.hud
                )],
                id: "expand_out"
            )
        } else if self == .dismissed {
            return .init(
                [
                    .init(
                        RevealTiming.dismissMaskHold, easing: .easeout,
                        width: 430, height: 120,
                        radius: Constants.CornerRadius.maskCircle
                    ),
                    .init(
                        RevealTiming.dismissPillContract, easing: .easeout,
                        width: 120, height: 120,
                        radius: Constants.CornerRadius.maskCircle
                    ),
                    .init(
                        RevealTiming.dismissCircleShrink,
                        easing: .bounce,
                        width: 40,
                        height: 40,
                        opacity: 0,
                        radius: Constants.CornerRadius.maskDismiss
                    ),
                ],
                id: "expand_close"
            )
        }
        return nil
    }

    var glow: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.03, delay: RevealTiming.glowStartDelay - 0.03, easing: .easeout, opacity: 0.0, scale: 0.2),
                .init(RevealTiming.glowPulse, easing: .bounce, opacity: 0.5, scale: 1.9),
                .init(RevealTiming.glowFade, easing: .easein, opacity: 0.0),
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
                .init(0.01, easing: .linear, opacity: 0.0, scale: 0.85),
                .init(RevealTiming.ringFadeIn, easing: .easeout, opacity: 1.0, scale: 1.0),
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
            return .init([.init(RevealTiming.dismissContainerFade, easing: .easeout, opacity: 0.0, blur: 5.0)])
        }
        return nil
    }
}

// MARK: - HUD State Transitions

extension HUDState {
    static func maskTransition(from: HUDState, to: HUDState) -> AnimationObject? {
        if from == .detailed, to == .revealed {
            return .init(
                [.init(RevealTiming.collapseDuration, easing: .bounce, width: 430, height: 120, radius: 60)],
                id: "collapse_to_pill"
            )
        }
        return to.mask
    }

    static func glowTransition(from: HUDState, to: HUDState) -> AnimationObject? {
        if from == .detailed, to == .revealed {
            return nil
        }
        return to.glow
    }

    static func progressTransition(from: HUDState, to: HUDState) -> AnimationObject? {
        if from == .detailed, to == .revealed {
            return nil
        }
        return to.progress
    }

    static func containerTransition(from: HUDState, to: HUDState) -> AnimationObject? {
        if from == .detailed, to == .revealed {
            return .init(
                [.init(RevealTiming.collapseDuration, easing: .easeout, padding: .init())],
                id: "collapse_container"
            )
        }
        return to.container
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

enum WindowPosition: String {
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

enum HUDProgressLayout {
    case center
    case trailing
}

// MARK: - Stats Display Object

struct StatsDisplayObject {
    var standard: String?
    var overlay: String?
}

// MARK: - Stats Icon

struct StatsIcon {
    var name: String
    var color: Color
    var effect: HUDIconEffect
}
