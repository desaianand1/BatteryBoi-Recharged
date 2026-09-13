//
//  MockOnboardingService.swift
//  BatteryBoi - Recharged
//
//  Mock implementation for unit testing.
//

@testable import BatteryBoi___Recharged
import Foundation

#if DEBUG

    /// Mock onboarding service for unit testing.
    @Observable
    @MainActor
    final class MockOnboardingService: OnboardingServiceProtocol {

        // MARK: - Observable Properties

        var currentStep: OnboardingStep
        var isCompleted: Bool

        var shouldShowOnboarding: Bool {
            !isCompleted
        }

        // MARK: - Test Helpers

        var advanceCallCount = 0
        var completeCallCount = 0
        var resetCallCount = 0

        // MARK: - Initialization

        init(currentStep: OnboardingStep = .welcome, isCompleted: Bool = false) {
            self.currentStep = currentStep
            self.isCompleted = isCompleted
        }

        // MARK: - Methods

        func advance() {
            advanceCallCount += 1
            if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                currentStep = nextStep
            }
        }

        func complete() {
            completeCallCount += 1
            isCompleted = true
        }

        func reset() {
            resetCallCount += 1
            currentStep = .welcome
            isCompleted = false
        }
    }

#endif
