//
//  OnboardingPreferencesView.swift
//  BatteryBoi
//
//  Preferences step of the onboarding flow.
//

import SwiftUI

struct OnboardingPreferencesView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var onboarding: any OnboardingServiceProtocol {
        self.env.onboarding
    }

    private var settings: any SettingsServiceProtocol {
        self.env.settings
    }

    @State private var selectedDisplay: SettingsDisplayType = .percent
    @State private var soundEffectsEnabled = true
    @State private var launchAtLoginEnabled = true

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Text("OnboardingPreferencesTitle".localise())
                .font(Typography.title)
                .foregroundStyle(Color("BBTitle"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            VStack(spacing: Spacing.smd) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("OnboardingDisplayModeLabel".localise())
                        .font(Typography.heading)
                        .foregroundStyle(Color("BBTitle"))

                    OnboardingDisplayTileGrid(
                        selected: self.$selectedDisplay,
                        reduceMotion: self.reduceMotion
                    )
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                        .fill(Color("BBSurface"))
                )

                OnboardingPreferenceToggle(
                    icon: "speaker.wave.2",
                    title: "OnboardingSoundEffectsLabel".localise(),
                    isEnabled: self.$soundEffectsEnabled
                )

                OnboardingPreferenceToggle(
                    icon: "power",
                    title: "OnboardingLaunchAtLoginLabel".localise(),
                    isEnabled: self.$launchAtLoginEnabled
                )
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            Button {
                self.saveAndAdvance()
            } label: {
                Text("OnboardingPreferencesButton".localise())
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
            .accessibilityLabel("OnboardingPreferencesButton".localise())
        }
        .padding(.top, Spacing.xl)
        .onAppear {
            self.loadCurrentSettings()
        }
    }

    private func loadCurrentSettings() {
        self.selectedDisplay = self.settings.display
        self.soundEffectsEnabled = self.settings.sfx == .enabled
        self.launchAtLoginEnabled = self.settings.autoLaunch == .enabled
    }

    private func saveAndAdvance() {
        self.settings.setDisplay(self.selectedDisplay)
        self.settings.soundEffects = self.soundEffectsEnabled ? .enabled : .disabled
        self.settings.autoLaunch = self.launchAtLoginEnabled ? .enabled : .disabled
        self.onboarding.advance()
    }
}

// MARK: - Display Tile Grid

private struct OnboardingDisplayTileGrid: View {
    @Binding var selected: SettingsDisplayType
    let reduceMotion: Bool

    private let displayOptions: [(type: SettingsDisplayType, label: String)] = [
        (.countdown, "SettingsDisplayEstimateLabel"),
        (.percent, "SettingsDisplayPercentLabel"),
        (.cycle, "SettingsDisplayCycleLabel"),
        (.empty, "SettingsDisplayNoneLabel"),
    ]

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                self.tile(for: self.displayOptions[0])
                self.tile(for: self.displayOptions[1])
            }

            HStack(spacing: Spacing.sm) {
                self.tile(for: self.displayOptions[2])
                self.tile(for: self.displayOptions[3])
            }
        }
    }

    private func tile(for option: (type: SettingsDisplayType, label: String)) -> some View {
        Button {
            self.selected = option.type
        } label: {
            VStack(spacing: Spacing.xsm) {
                Image(systemName: option.type.icon)
                    .font(Typography.icon)
                    .foregroundStyle(Color("BBSubtitle"))
                    .frame(height: 28)
                    .applySymbolReplaceTransition()

                Text(option.label.localise())
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                    .fill(Color("BBBackground"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                    .strokeBorder(
                        Color("BBTitle").opacity(self.selected == option.type ? 0.3 : 0.0),
                        lineWidth: 2
                    )
            )
            .animation(
                DesignAnimation.easeOut(duration: 0.2, reduceMotion: self.reduceMotion),
                value: self.selected
            )
        }
        .buttonStyle(HoverButtonStyle())
        .accessibilityLabel(option.label.localise())
        .accessibilityValue(self.selected == option.type ? "Selected" : "")
        .accessibilityAddTraits(self.selected == option.type ? .isSelected : [])
    }
}

// MARK: - Preference Toggle

private struct OnboardingPreferenceToggle: View {
    let icon: String
    let title: String
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: self.icon)
                .font(Typography.icon)
                .foregroundStyle(Color("BBSubtitle"))
                .frame(width: 28)

            Text(self.title)
                .font(Typography.heading)
                .foregroundStyle(Color("BBTitle"))

            Spacer()

            Toggle("", isOn: self.$isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .accessibilityLabel(self.title)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BBSurface"))
        )
    }
}
