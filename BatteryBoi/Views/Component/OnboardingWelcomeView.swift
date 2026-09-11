//
//  OnboardingWelcomeView.swift
//  BatteryBoi
//
//  Welcome step of the onboarding flow.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var onboarding: OnboardingService {
        self.env.onboarding
    }

    @State private var iconAppeared = false
    @State private var cardsAppeared: [Bool] = [false, false, false]

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable().scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .scaleEffect(self.iconAppeared ? 1.0 : 0.8)
                .opacity(self.iconAppeared ? 1.0 : 0.0)

            VStack(spacing: Spacing.sm) {
                Text("OnboardingWelcomeTitle".localise())
                    .font(Typography.title)
                    .foregroundStyle(Color("BBTitle"))
                    .multilineTextAlignment(.center)

                Text("OnboardingWelcomeSubtitle".localise())
                    .font(Typography.body)
                    .foregroundStyle(Color("BBSubtitle"))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Spacing.smd) {
                OnboardingFeatureCard(
                    icon: "battery.100",
                    effect: .variableColor,
                    title: "OnboardingWelcomeFeature1".localise(),
                    appeared: self.cardsAppeared[0]
                )

                OnboardingFeatureCard(
                    icon: "bell.badge",
                    effect: .pulse,
                    title: "OnboardingWelcomeFeature2".localise(),
                    appeared: self.cardsAppeared[1]
                )

                OnboardingFeatureCard(
                    icon: "chart.line.uptrend.xyaxis",
                    effect: .variableColor,
                    title: "OnboardingWelcomeFeature3".localise(),
                    appeared: self.cardsAppeared[2]
                )
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            Button {
                self.onboarding.advance()
            } label: {
                Text("OnboardingWelcomeButton".localise())
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBSurface"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                            .fill(Color("BBTitle"))
                    )
            }
            .buttonStyle(HoverButtonStyle())
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.md)
            .accessibilityLabel("OnboardingWelcomeButton".localise())
        }
        .padding(.top, Spacing.xl)
        .onAppear {
            withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
                self.iconAppeared = true
            }
            for index in self.cardsAppeared.indices {
                let delay = Double(index) * 0.1
                withAnimation(
                    DesignAnimation.spring(reduceMotion: self.reduceMotion)?
                        .delay(delay)
                ) {
                    self.cardsAppeared[index] = true
                }
            }
        }
    }
}

private struct OnboardingFeatureCard: View {
    let icon: String
    let effect: HUDIconEffect
    let title: String
    let appeared: Bool

    var body: some View {
        HStack(spacing: Spacing.smd) {
            Image(systemName: self.icon)
                .font(Typography.icon)
                .foregroundStyle(Color("BBSubtitle"))
                .frame(width: 32)
                .applySymbolEffect(self.effect)

            Text(self.title)
                .font(Typography.heading)
                .foregroundStyle(Color("BBTitle"))

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BBSurface"))
        )
        .opacity(self.appeared ? 1.0 : 0.0)
        .offset(y: self.appeared ? 0 : 8)
    }
}
