//
//  OnboardingWelcomeView.swift
//  BatteryBoi
//
//  Welcome step of the onboarding flow.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @State private var onboarding = OnboardingService.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            // Welcome text
            VStack(spacing: 8) {
                Text("OnboardingWelcomeTitle".localise())
                    .font(Typography.title)
                    .foregroundColor(Color("BatteryTitle"))
                    .multilineTextAlignment(.center)

                Text("OnboardingWelcomeSubtitle".localise())
                    .font(Typography.body)
                    .foregroundColor(Color("BatterySubtitle"))
                    .multilineTextAlignment(.center)
            }

            // Feature list
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "battery.100", text: "OnboardingWelcomeFeature1".localise())
                FeatureRow(icon: "bell.badge", text: "OnboardingWelcomeFeature2".localise())
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "OnboardingWelcomeFeature3".localise())
            }
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()

            // CTA button
            Button(
                action: { onboarding.advance() },
                label: {
                    Text("OnboardingWelcomeButton".localise())
                        .font(Typography.heading)
                        .foregroundColor(Color("BatteryButton"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                                .fill(Color("BatteryTitle"))
                        )
                }
            )
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .padding(.top, 32)
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color("BatteryTitle"))
                .frame(width: 24)

            Text(text)
                .font(Typography.body)
                .foregroundColor(Color("BatterySubtitle"))
        }
    }
}
