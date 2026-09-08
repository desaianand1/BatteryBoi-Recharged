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
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 60
}

enum DesignAnimation {
    /// Returns nil if reduce motion is enabled, otherwise returns the specified animation
    static func spring(
        response: Double = 0.4,
        dampingFraction: Double = 0.8,
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : .spring(response: response, dampingFraction: dampingFraction)
    }

    /// Returns nil if reduce motion is enabled, otherwise returns the specified easeOut animation
    static func easeOut(duration: Double = 0.3, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }

    /// Returns nil if reduce motion is enabled, otherwise returns the specified easeIn animation
    static func easeIn(duration: Double = 0.3, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeIn(duration: duration)
    }

    /// Returns nil if reduce motion is enabled, otherwise returns the standard interactive spring
    static func interactiveSpring(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .interactiveSpring(response: 0.6, dampingFraction: 0.9, blendDuration: 1)
    }

    enum Delays {
        static let contentReveal: Double = 0.9
        static let progressTrailing: Double = 0.75
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
