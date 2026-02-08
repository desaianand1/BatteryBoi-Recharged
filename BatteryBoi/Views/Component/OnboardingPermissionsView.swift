//
//  OnboardingPermissionsView.swift
//  BatteryBoi
//
//  Permissions step of the onboarding flow.
//

import SwiftUI
import UserNotifications

struct OnboardingPermissionsView: View {
    @State private var onboarding = OnboardingService.shared
    @State private var bluetoothEnabled: Bool = false
    @State private var notificationsEnabled: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Title
            VStack(spacing: 8) {
                Text("OnboardingPermissionsTitle".localise())
                    .font(Typography.title)
                    .foregroundColor(Color("BatteryTitle"))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            // Permission cards
            VStack(spacing: 12) {
                PermissionCard(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "OnboardingBluetoothTitle".localise(),
                    description: "OnboardingBluetoothBody".localise(),
                    isEnabled: $bluetoothEnabled,
                    action: requestBluetoothPermission
                )

                PermissionCard(
                    icon: "bell.badge",
                    title: "OnboardingNotificationsTitle".localise(),
                    description: "OnboardingNotificationsBody".localise(),
                    isEnabled: $notificationsEnabled,
                    action: requestNotificationPermission
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button(
                    action: { onboarding.advance() },
                    label: {
                        Text("OnboardingPermissionsContinue".localise())
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

                Button(
                    action: { onboarding.advance() },
                    label: {
                        Text("OnboardingPermissionsSkip".localise())
                            .font(Typography.small)
                            .foregroundColor(Color("BatterySubtitle"))
                    }
                )
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .padding(.top, 32)
        .onAppear {
            checkCurrentPermissions()
        }
    }

    private func checkCurrentPermissions() {
        // Check Bluetooth authorization
        let btAuth = CBCentralManager.authorization
        bluetoothEnabled = btAuth == .allowedAlways

        // Check notification authorization
        UNUserNotificationCenter.current().getNotificationSettings { notificationSettings in
            let isAuthorized = notificationSettings.authorizationStatus == .authorized
            Task { @MainActor in
                notificationsEnabled = isAuthorized
            }
        }
    }

    private func requestBluetoothPermission() {
        // Bluetooth permission is triggered by accessing CBCentralManager
        // The system will prompt automatically when needed
        bluetoothEnabled = true
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                notificationsEnabled = granted
            }
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isEnabled: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isEnabled ? Color("BatteryTitle") : Color("BatterySubtitle"))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.heading)
                    .foregroundColor(Color("BatteryTitle"))

                Text(description)
                    .font(Typography.small)
                    .foregroundColor(Color("BatterySubtitle"))
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    if newValue {
                        action()
                    }
                }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BatteryButton"))
        )
    }
}

import CoreBluetooth
