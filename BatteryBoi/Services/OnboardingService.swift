//
//  OnboardingService.swift
//  BatteryBoi
//
//  Onboarding state management for first-run experience.
//

import SwiftUI

@Observable @MainActor
final class OnboardingService: OnboardingServiceProtocol {
    typealias Step = OnboardingStep

    var currentStep: OnboardingStep = .welcome

    var isCompleted: Bool {
        get { UserDefaults.main.bool(forKey: SystemDefaultsKeys.onboardingCompleted.rawValue) }
        set { UserDefaults.save(.onboardingCompleted, value: newValue) }
    }

    var shouldShowOnboarding: Bool {
        !isCompleted
    }

    func advance() {
        if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            currentStep = nextStep
        }
    }

    func complete() {
        isCompleted = true
    }

    func reset() {
        currentStep = .welcome
        isCompleted = false
    }
}
