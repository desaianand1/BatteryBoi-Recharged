//
//  OnboardingServiceProtocol.swift
//  BatteryBoi
//
//  Created for architecture modernization.
//

import Foundation

/// Onboarding step progression.
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case permissions = 1
    case preferences = 2
    case complete = 3
}

/// Protocol defining the onboarding service interface.
/// Enables dependency injection and testability for first-run experience.
@MainActor
protocol OnboardingServiceProtocol: AnyObject {

    // MARK: - Observable Properties

    /// Current onboarding step
    var currentStep: OnboardingStep { get set }

    /// Whether onboarding has been completed
    var isCompleted: Bool { get set }

    /// Whether onboarding should be shown (convenience inverse of isCompleted)
    var shouldShowOnboarding: Bool { get }

    // MARK: - Methods

    /// Advance to the next onboarding step
    func advance()

    /// Mark onboarding as complete
    func complete()

    /// Reset onboarding to the beginning
    func reset()
}
