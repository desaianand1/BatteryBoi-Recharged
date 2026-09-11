//
//  OnboardingView.swift
//  BatteryBoi
//
//  Main onboarding container with step navigation.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var onboarding: OnboardingService {
        self.env.onboarding
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch self.onboarding.currentStep {
                case .welcome:
                    OnboardingWelcomeView()
                case .permissions:
                    OnboardingPermissionsView()
                case .preferences:
                    OnboardingPreferencesView()
                case .complete:
                    OnboardingCompleteView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(
                self.reduceMotion
                    ? .identity
                    : .move(edge: .trailing).combined(with: .opacity)
            )
            .animation(
                DesignAnimation.easeOut(duration: 0.3, reduceMotion: self.reduceMotion),
                value: self.onboarding.currentStep
            )

            HStack(spacing: Spacing.sm) {
                ForEach(OnboardingService.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(
                            step == self.onboarding.currentStep
                                ? Color("BBTitle")
                                : Color("BBSubtitle").opacity(0.3)
                        )
                        .frame(width: Spacing.sm, height: Spacing.sm)
                        .animation(
                            DesignAnimation.easeOut(duration: 0.2, reduceMotion: self.reduceMotion),
                            value: self.onboarding.currentStep
                        )
                }
            }
            .padding(.bottom, Spacing.lg)
        }
        .frame(width: 400, height: 520)
        .background(Color("BBBackground"))
    }
}
