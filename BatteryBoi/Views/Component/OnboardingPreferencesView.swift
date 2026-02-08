//
//  OnboardingPreferencesView.swift
//  BatteryBoi
//
//  Preferences step of the onboarding flow.
//

import SwiftUI

struct OnboardingPreferencesView: View {
    @State private var onboarding = OnboardingService.shared
    @State private var settings = SettingsService.shared
    @State private var selectedDisplay: SettingsDisplayType = .percent
    @State private var soundEffectsEnabled: Bool = true
    @State private var launchAtLoginEnabled: Bool = true

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            Text("OnboardingPreferencesTitle".localise())
                .font(Typography.title)
                .foregroundColor(Color("BatteryTitle"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Preference cards
            VStack(spacing: 12) {
                // Display mode picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("OnboardingDisplayModeLabel".localise())
                        .font(Typography.heading)
                        .foregroundColor(Color("BatteryTitle"))

                    Picker("", selection: $selectedDisplay) {
                        Text("SettingsDisplayPercentLabel".localise()).tag(SettingsDisplayType.percent)
                        Text("SettingsDisplayEstimateLabel".localise()).tag(SettingsDisplayType.countdown)
                        Text("SettingsDisplayCycleLabel".localise()).tag(SettingsDisplayType.cycle)
                        Text("SettingsDisplayNoneLabel".localise()).tag(SettingsDisplayType.empty)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                        .fill(Color("BatteryButton"))
                )

                // Sound effects toggle
                PreferenceToggle(
                    icon: "speaker.wave.2",
                    title: "OnboardingSoundEffectsLabel".localise(),
                    isEnabled: $soundEffectsEnabled
                )

                // Launch at login toggle
                PreferenceToggle(
                    icon: "power",
                    title: "OnboardingLaunchAtLoginLabel".localise(),
                    isEnabled: $launchAtLoginEnabled
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // CTA button
            Button(
                action: saveAndAdvance,
                label: {
                    Text("OnboardingPreferencesButton".localise())
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
            loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        selectedDisplay = settings.display
        soundEffectsEnabled = settings.enabledSoundEffects == .enabled
        launchAtLoginEnabled = settings.enabledAutoLaunch == .enabled
    }

    private func saveAndAdvance() {
        // Save display preference
        settings.display = selectedDisplay

        // Save sound effects preference
        settings.enabledSoundEffects = soundEffectsEnabled ? .enabled : .disabled

        // Save launch at login preference
        settings.enabledAutoLaunch = launchAtLoginEnabled ? .enabled : .disabled

        onboarding.advance()
    }
}

private struct PreferenceToggle: View {
    let icon: String
    let title: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color("BatterySubtitle"))
                .frame(width: 28)

            Text(title)
                .font(Typography.heading)
                .foregroundColor(Color("BatteryTitle"))

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BatteryButton"))
        )
    }
}
