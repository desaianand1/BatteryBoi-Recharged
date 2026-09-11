//
//  OnboardingPermissionsView.swift
//  BatteryBoi
//
//  Permissions step of the onboarding flow.
//

import CoreBluetooth
import SwiftUI
import UserNotifications

struct OnboardingPermissionsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var onboarding: OnboardingService {
        self.env.onboarding
    }

    @State private var bluetoothEnabled = false
    @State private var notificationsEnabled = false

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("OnboardingPermissionsTitle".localise())
                    .font(Typography.title)
                    .foregroundStyle(Color("BBTitle"))
                    .multilineTextAlignment(.center)

                Text("OnboardingPermissionsSubtitle".localise())
                    .font(Typography.body)
                    .foregroundStyle(Color("BBSubtitle"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)

            VStack(spacing: Spacing.smd) {
                OnboardingPermissionCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "OnboardingBluetoothTitle".localise(),
                    description: "OnboardingBluetoothBody".localise(),
                    isEnabled: self.$bluetoothEnabled,
                    reduceMotion: self.reduceMotion,
                    action: self.requestBluetoothPermission
                )

                OnboardingPermissionCard(
                    icon: "bell.badge",
                    title: "OnboardingNotificationsTitle".localise(),
                    description: "OnboardingNotificationsBody".localise(),
                    isEnabled: self.$notificationsEnabled,
                    reduceMotion: self.reduceMotion,
                    action: self.requestNotificationPermission
                )
            }
            .padding(.horizontal, Spacing.xl)

            Spacer()

            VStack(spacing: Spacing.smd) {
                Button {
                    self.onboarding.advance()
                } label: {
                    Text("OnboardingPermissionsContinue".localise())
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
                .accessibilityLabel("OnboardingPermissionsContinue".localise())

                Button {
                    self.onboarding.advance()
                } label: {
                    Text("OnboardingPermissionsSkip".localise())
                        .font(Typography.caption)
                        .foregroundStyle(Color("BBSubtitle"))
                }
                .buttonStyle(HoverButtonStyle())
                .accessibilityLabel("OnboardingPermissionsSkip".localise())
            }
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.md)
        }
        .padding(.top, Spacing.xl)
        .onAppear {
            self.checkCurrentPermissions()
        }
    }

    private func checkCurrentPermissions() {
        let btAuth = CBCentralManager.authorization
        self.bluetoothEnabled = btAuth == .allowedAlways

        UNUserNotificationCenter.current().getNotificationSettings { notificationSettings in
            let isAuthorized = notificationSettings.authorizationStatus == .authorized
            Task { @MainActor in
                self.notificationsEnabled = isAuthorized
            }
        }
    }

    private func requestBluetoothPermission() {
        self.bluetoothEnabled = true
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                self.notificationsEnabled = granted
            }
        }
    }
}

private struct OnboardingPermissionCard: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: self.icon)
                .font(Typography.icon)
                .foregroundStyle(self.isEnabled ? Color("BBTitle") : Color("BBSubtitle"))
                .frame(width: 40)
                .applySymbolEffect(self.isEnabled ? .pulse : .variableColor)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(self.title)
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))

                Text(self.description)
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: self.$isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: self.isEnabled) { _, newValue in
                    if newValue {
                        self.action()
                    }
                }
                .accessibilityLabel(self.title)
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BBSurface"))
        )
    }
}
