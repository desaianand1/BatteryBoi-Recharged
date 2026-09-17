import SwiftUI

// MARK: - Device Card Ring

struct DeviceCardRing: View {
    @Environment(AppEnvironment.self) private var env

    let device: BluetoothObject?
    @State private var progress: Double = 0

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    private var isMac: Bool {
        self.device == nil
    }

    private var percent: Double? {
        if let device = self.device {
            return device.battery.percent
        }
        return self.battery.percentage
    }

    private var isCharging: Bool {
        self.isMac && self.battery.charging.state == .charging
    }

    private var deviceIcon: String {
        if let device = self.device {
            return device.type.icon
        }
        return "laptopcomputer"
    }

    var body: some View {
        Group {
            if let percent = self.percent, percent > 0 {
                ZStack {
                    RadialProgressBar(
                        self.$progress,
                        size: CGSize(width: 36, height: 36),
                        line: 4,
                        percent: percent,
                        isCharging: self.isCharging,
                        isMini: true
                    )

                    Image(systemName: self.deviceIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color("BBSubtitle"))
                        .symbolRenderingMode(.hierarchical)
                }
                .frame(width: 36, height: 36)
            } else {
                Image(systemName: self.deviceIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color("BBSubtitle"))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 36, height: 36)
            }
        }
        .onAppear { self.syncProgress() }
        .onChange(of: self.percent) { self.syncProgress() }
    }

    private func syncProgress() {
        if let percent = self.percent {
            self.progress = percent / 100.0
        }
    }
}

// MARK: - Device Card

struct DeviceCard: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let device: BluetoothObject?
    let onSelect: () -> Void

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    private var manager: any AppManagerProtocol {
        self.env.app
    }

    private var isMac: Bool {
        self.device == nil
    }

    private var name: String {
        if let device = self.device {
            return device.device ?? device.type.type.rawValue
        }
        return self.manager.appDeviceType.name
    }

    private var percent: Double? {
        if let device = self.device {
            return device.battery.percent
        }
        return self.battery.percentage
    }

    private var isTWS: Bool {
        guard let device = self.device else { return false }
        return device.battery.left != nil && device.battery.right != nil
    }

    private var accessibilityBatteryDescription: String {
        guard let percent = self.percent else { return "DeviceDetailConnectedLabel".localise() }
        let pct = "\(Int(percent)) percent"
        if let device = self.device {
            return "\(pct), \(device.connected == .connected ? "connected" : "disconnected")"
        }
        return "\(pct), \(self.battery.charging.state == .charging ? "charging" : "on battery")"
    }

    var body: some View {
        Button(action: self.onSelect) {
            VStack(spacing: 0) {
                HStack(spacing: Spacing.smd) {
                    DeviceCardRing(device: self.device)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(self.name)
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBTitle"))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        self.deviceSubtitleView
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color("BBSubtitle").opacity(0.5))
                }
                .padding(.horizontal, Spacing.smd)
                .padding(.vertical, Spacing.smd)

                if self.isTWS, let device = self.device {
                    SettingsDivider()

                    HStack(spacing: Spacing.sm) {
                        if let left = device.battery.left {
                            self.twsBadge("L", percent: left)
                        }
                        if let right = device.battery.right {
                            self.twsBadge("R", percent: right)
                        }
                        if let caseBattery = device.battery.chargingCase {
                            self.twsBadge("Case", percent: caseBattery)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.smd)
                    .padding(.vertical, Spacing.sm)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButtonStyle())
        .surfaceCard()
        .accessibilityLabel(self.name)
        .accessibilityValue(self.accessibilityBatteryDescription)
        .accessibilityHint("Double-tap to view device details")
    }

    private var deviceSubtitleView: some View {
        HStack(spacing: Spacing.xs) {
            if let device = self.device, device.connected == .disconnected {
                Text("BluetoothNotConnectedLabel".localise())
            } else if let percent = self.percent {
                Text("\(Int(percent))%")
            } else {
                Text("DeviceDetailConnectedLabel".localise())
            }

            if let device = self.device {
                Circle()
                    .fill(device.connected == .connected ? SemanticColor.success : SemanticColor.info)
                    .frame(width: 5, height: 5)
            }
        }
        .font(Typography.caption)
        .foregroundStyle(Color("BBSubtitle"))
    }

    private func twsBadge(_ label: String, percent: Double) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle"))
            Text("\(Int(percent))%")
                .font(Typography.small)
                .foregroundStyle(Color("BBTitle"))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color("BBSubtitle").opacity(0.08))
        )
    }
}

// MARK: - Devices Empty State

struct DevicesEmptyStateView: View {
    var body: some View {
        VStack(spacing: Spacing.smd) {
            Image(systemName: "airpodspro")
                .font(.system(size: 28))
                .foregroundStyle(Color("BBSubtitle").opacity(0.4))

            Text("BluetoothNoDevicesTitle".localise())
                .font(Typography.heading)
                .foregroundStyle(Color("BBTitle"))

            Text("BluetoothNoDevicesBody".localise())
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle"))
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .surfaceCard()
        .accessibilityElement(children: .combine)
    }
}
