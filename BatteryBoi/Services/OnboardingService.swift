//
//  OnboardingService.swift
//  BatteryBoi
//
//  Onboarding state management for first-run experience.
//

import SwiftUI

@Observable
@MainActor
final class OnboardingService {
    static let shared = OnboardingService()

    enum Step: Int, CaseIterable, Sendable {
        case welcome = 0
        case permissions = 1
        case preferences = 2
        case complete = 3
    }

    var currentStep: Step = .welcome

    var isCompleted: Bool {
        get { UserDefaults.main.bool(forKey: SystemDefaultsKeys.onboardingCompleted.rawValue) }
        set { UserDefaults.save(.onboardingCompleted, value: newValue) }
    }

    var shouldShowOnboarding: Bool {
        !isCompleted
    }

    func advance() {
        if let nextStep = Step(rawValue: currentStep.rawValue + 1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = nextStep
            }
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
