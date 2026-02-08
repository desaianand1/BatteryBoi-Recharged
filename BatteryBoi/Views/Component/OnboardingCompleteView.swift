//
//  OnboardingCompleteView.swift
//  BatteryBoi
//
//  Completion step of the onboarding flow.
//

import SwiftUI

struct OnboardingCompleteView: View {
    @State private var onboarding = OnboardingService.shared
    @State private var showCheckmark: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Animated checkmark
            ZStack {
                Circle()
                    .fill(Color("BatteryTitle").opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color("BatteryTitle"))
                    .scaleEffect(showCheckmark ? 1.0 : 0.5)
                    .opacity(showCheckmark ? 1.0 : 0.0)
            }

            // Success message
            VStack(spacing: 8) {
                Text("OnboardingCompleteTitle".localise())
                    .font(Typography.title)
                    .foregroundColor(Color("BatteryTitle"))
                    .multilineTextAlignment(.center)

                Text("OnboardingCompleteSubtitle".localise())
                    .font(Typography.body)
                    .foregroundColor(Color("BatterySubtitle"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            // CTA button
            Button(
                action: completeOnboarding,
                label: {
                    Text("OnboardingCompleteButton".localise())
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
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showCheckmark = true
            }
        }
    }

    private func completeOnboarding() {
        onboarding.complete()

        // Close onboarding window and open HUD
        if let window = NSApp.windows.first(where: { $0.title == "onboarding" }) {
            window.close()
        }

        WindowService.shared.open(.userLaunched, device: nil)
    }
}
