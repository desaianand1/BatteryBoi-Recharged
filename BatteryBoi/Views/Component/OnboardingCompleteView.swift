//
//  OnboardingCompleteView.swift
//  BatteryBoi
//
//  Completion step of the onboarding flow.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var onboarding: any OnboardingServiceProtocol {
        self.env.onboarding
    }

    @State private var showCheckmark = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color("BBTitle").opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(Color("BBTitle"))
                    .scaleEffect(self.showCheckmark ? 1.0 : 0.5)
                    .opacity(self.showCheckmark ? 1.0 : 0.0)
                    .applySymbolEffect(self.showCheckmark ? .appear : .none)
            }

            VStack(spacing: Spacing.sm) {
                Text("OnboardingCompleteTitle".localise())
                    .font(Typography.title)
                    .foregroundStyle(Color("BBTitle"))
                    .multilineTextAlignment(.center)

                Text("OnboardingCompleteSubtitle".localise())
                    .font(Typography.body)
                    .foregroundStyle(Color("BBSubtitle"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            Button {
                self.completeOnboarding()
            } label: {
                Text("OnboardingCompleteButton".localise())
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBBackground"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: BatteryTier.full.gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(HoverButtonStyle())
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.md)
            .accessibilityLabel("OnboardingCompleteButton".localise())
        }
        .padding(.top, Spacing.xl)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                self.showCheckmark = true
            }
        }
    }

    private func completeOnboarding() {
        self.onboarding.complete()

        if let window = NSApp.windows.first(where: { $0.title == "onboarding" }) {
            window.close()
        }

        self.env.window.open(.userLaunched, device: nil)
    }
}
