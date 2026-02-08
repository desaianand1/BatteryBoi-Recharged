//
//  OnboardingView.swift
//  BatteryBoi
//
//  Main onboarding container with step navigation.
//

import SwiftUI

struct OnboardingView: View {
    @State private var onboarding = OnboardingService.shared

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $onboarding.currentStep) {
                OnboardingWelcomeView()
                    .tag(OnboardingService.Step.welcome)

                OnboardingPermissionsView()
                    .tag(OnboardingService.Step.permissions)

                OnboardingPreferencesView()
                    .tag(OnboardingService.Step.preferences)

                OnboardingCompleteView()
                    .tag(OnboardingService.Step.complete)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut(duration: 0.3), value: onboarding.currentStep)

            // Progress dots
            HStack(spacing: 8) {
                ForEach(OnboardingService.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(step == onboarding.currentStep ? Color("BatteryTitle") : Color("BatterySubtitle")
                            .opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: onboarding.currentStep)
                }
            }
            .padding(.bottom, 24)
        }
        .frame(width: 400, height: 480)
        .background(Color("BatteryBackground"))
    }
}
