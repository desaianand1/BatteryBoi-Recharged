//
//  BBDesignTokens.swift
//  BatteryBoi
//
//  Design system tokens for typography and spacing consistency.
//

import SwiftUI

enum BBTypography {
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

enum BBSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 60
}

enum BBAnimation {
    /// Returns nil if reduce motion is enabled, otherwise returns the specified animation
    static func spring(
        response: Double = 0.4,
        dampingFraction: Double = 0.8,
        reduceMotion: Bool,
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
}
