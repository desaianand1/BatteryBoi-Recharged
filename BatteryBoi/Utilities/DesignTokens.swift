//
//  DesignTokens.swift
//  BatteryBoi
//
//  Design system tokens for typography and spacing consistency.
//

import SwiftUI

enum Typography {
    static let largeTitle = Font.system(size: 26, weight: .bold)
    static let title = Font.system(size: 18, weight: .semibold)
    static let titleBold = Font.system(size: 18, weight: .bold)
    static let heading = Font.system(size: 14, weight: .medium)
    static let headingLarge = Font.system(size: 16, weight: .medium)
    static let body = Font.system(size: 12, weight: .regular)
    static let bodyMedium = Font.system(size: 12, weight: .medium)
    static let caption = Font.system(size: 10, weight: .regular)
    static let small = Font.system(size: 10, weight: .bold)
    static let icon = Font.system(size: 23, weight: .medium)
    static let progressLarge = Font.system(size: 20, weight: .bold)
}

enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let xsm: CGFloat = 6
    static let sm: CGFloat = 8
    static let smd: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 60
}

enum SemanticColor {
    static let success = Color("BBStatusSuccess")
    static let warning = Color("BBStatusWarning")
    static let error = Color("BBStatusError")
    static let info = Color("BBStatusInfo")
}

nonisolated enum RevealTiming {

    // MARK: Atomic — tweak only these; everything else derives

    static let circleBounce: Double = 0.6
    static let circlePause: Double = 0.85
    static let ringFadeIn: Double = 0.3
    static let glowPulse: Double = 0.4
    static let glowFade: Double = 0.4
    static let arcSweep: Double = 0.8
    static let pillExpansion: Double = 2.6
    static let contentFade: Double = 0.8
    static let ringSlide: Double = 0.35

    // MARK: Derived — calculated from atomics

    static let circlePhaseEnd: Double = circleBounce + circlePause
    static let arcSweepDelay: Double = 0.1
    static let glowStartDelay: Double = 0.1
    static let glowEnd: Double = glowStartDelay + glowPulse + glowFade
    static let arcSweepEnd: Double = arcSweepDelay + arcSweep
    static let ringSlideDelay: Double = circlePhaseEnd
    static let contentRevealDelay: Double = circlePhaseEnd + 0.25
    static let totalReveal: Double = circlePhaseEnd + pillExpansion

    // MARK: Dismiss

    static let dismissTextFade: Double = 0.15
    static let dismissContainerFade: Double = 0.3
    static let dismissMaskHold: Double = 0.35
    static let dismissPillContract: Double = 0.3
    static let dismissCircleShrink: Double = 0.3

    // MARK: Expand / Collapse

    static let expandDuration: Double = 0.3
    static let collapseDuration: Double = 0.3
}

nonisolated enum ChargingAnimation {
    static let glowPeriod: Double = 1.0
    static let shimmerPeriod: Double = 3.0
    static let dotPulsePeriod: Double = 2.0
    static let trackBreathePeriod: Double = 4.0
    static let fullBurstDuration: Double = 1.2
    static let glowMinOpacity: Double = 0.3
    static let glowMaxOpacity: Double = 0.5
    static let glowStaticOpacity: Double = 0.4
    static let dotMinScale: Double = 1.0
    static let dotMaxScale: Double = 1.3
    static let trackMinOpacity: Double = 0.08
    static let trackMaxOpacity: Double = 0.12
    static let burstMaxScale: Double = 1.15
    static let burstStartOpacity: Double = 0.4
}

enum DesignAnimation {
    static let hudSpring = Spring(response: 0.35, dampingRatio: 0.65)

    static func spring(
        response: Double = 0.4,
        dampingFraction: Double = 0.8,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : .spring(response: response, dampingFraction: dampingFraction)
    }

    static func easeOut(duration: Double = 0.3, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }

    static func easeIn(duration: Double = 0.3, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeIn(duration: duration)
    }

    static func interactiveSpring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .interactiveSpring(response: 0.6, dampingFraction: 0.9, blendDuration: 1)
    }

}

// MARK: - Battery Tier

enum BatteryTier: Equatable {
    case critical
    case low
    case medium
    case good
    case full

    init(percent: Double) {
        switch percent {
        case ...15: self = .critical
        case 16 ... 40: self = .low
        case 41 ... 70: self = .medium
        case 71 ... 99: self = .good
        default: self = .full
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .critical:
            [Color(red: 1.0, green: 0.176, blue: 0.333), Color(red: 1.0, green: 0.231, blue: 0.188)]
        case .low:
            [Color(red: 1.0, green: 0.420, blue: 0.0), Color(red: 1.0, green: 0.722, blue: 0.0)]
        case .medium:
            [Color(red: 0.831, green: 1.0, blue: 0.0), Color(red: 0.486, green: 1.0, blue: 0.0)]
        case .good:
            [
                Color(red: 0.486, green: 1.0, blue: 0.0),
                Color(red: 0.0, green: 1.0, blue: 0.533),
                Color(red: 0.0, green: 0.902, blue: 0.463)
            ]
        case .full:
            [
                Color(red: 0.0, green: 1.0, blue: 0.533),
                Color(red: 0.357, green: 1.0, blue: 0.878),
                Color(red: 0.0, green: 0.898, blue: 1.0)
            ]
        }
    }

    var dotColor: Color {
        switch self {
        case .critical: Color(red: 1.0, green: 0.176, blue: 0.333)
        case .low: Color(red: 1.0, green: 0.420, blue: 0.0)
        case .medium: Color(red: 0.831, green: 1.0, blue: 0.0)
        case .good: Color(red: 0.0, green: 1.0, blue: 0.533)
        case .full: Color(red: 0.357, green: 1.0, blue: 0.878)
        }
    }

    static let trackColor = Color.white.opacity(0.08)
    static let chargingBoltColor = Color(red: 0.0, green: 0.902, blue: 0.463)
}

// MARK: - HUD Icon Effect

enum HUDIconEffect: Equatable {
    case none
    case pulse
    case pulseByLayer
    case bounce
    case variableColor
    case appear
    case disappear
}

// MARK: - Symbol Effect Modifier

struct SymbolEffectModifier: ViewModifier {
    let effect: HUDIconEffect

    func body(content: Content) -> some View {
        switch self.effect {
        case .none:
            content
        case .pulse:
            content.symbolEffect(.pulse)
        case .pulseByLayer:
            content.symbolEffect(.pulse.byLayer)
        case .bounce:
            if #available(macOS 15, *) {
                content.symbolEffect(.bounce)
            } else {
                content
            }
        case .variableColor:
            content.symbolEffect(.variableColor)
        case .appear:
            if #available(macOS 15, *) {
                content.symbolEffect(.appear)
            } else {
                content.transition(.opacity)
            }
        case .disappear:
            if #available(macOS 15, *) {
                content.symbolEffect(.disappear)
            } else {
                content.transition(.opacity)
            }
        }
    }
}

struct SymbolReplaceTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15, *) {
            content.contentTransition(.symbolEffect(.replace))
        } else {
            content.contentTransition(.interpolate)
        }
    }
}

extension View {
    func applySymbolEffect(_ effect: HUDIconEffect) -> some View {
        self.modifier(SymbolEffectModifier(effect: effect))
    }

    func applySymbolReplaceTransition() -> some View {
        self.modifier(SymbolReplaceTransitionModifier())
    }
}

// MARK: - Hover Button Style

struct HoverButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : (self.isHovered ? 0.95 : 1.0))
            .scaleEffect(self.reduceMotion ? 1.0 : (configuration.isPressed ? 0.98 : 1.0))
            .animation(
                self.reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9),
                value: configuration.isPressed
            )
            .animation(
                self.reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9),
                value: self.isHovered
            )
            .onHover { hovering in
                self.isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

// MARK: - Blur Fade Transition

struct BlurFadeModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .blur(radius: self.isActive ? 0 : 4)
            .opacity(self.isActive ? 1 : 0)
    }
}

extension AnyTransition {
    static var blurFade: AnyTransition {
        .modifier(
            active: BlurFadeModifier(isActive: false),
            identity: BlurFadeModifier(isActive: true)
        )
    }
}
