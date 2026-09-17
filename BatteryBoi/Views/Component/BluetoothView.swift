import SwiftUI

struct BluetoothIcon: View {
    @Environment(AppEnvironment.self) private var env

    @State private var item: BluetoothObject?
    @State private var icon: String
    @State private var animation: Namespace.ID

    private let isSelected: Bool

    private var manager: any AppManagerProtocol {
        self.env.app
    }

    init(_ item: BluetoothObject?, isSelected: Bool, animation: Namespace.ID) {
        _item = State(initialValue: item)
        _icon = State(initialValue: item?.type.icon ?? "laptopcomputer")
        _animation = State(initialValue: animation)
        self.isSelected = isSelected
    }

    var body: some View {
        HStack {
            ZStack {
                if self.item == nil || self.item?.battery.percent != nil {
                    RadialProgressMiniContainer(self.item, isSelected: self.isSelected)

                    Image(systemName: self.icon)
                        .font(Typography.bodyMedium)
                        .foregroundColor(self.isSelected ? Color("BBSurface") : Color("BBSubtitle"))
                        .padding(2)
                        .background(
                            Circle()
                                .fill(self.isSelected ? Color("BBTitle") : Color("BBSurface"))
                                .blur(radius: 2)
                        )
                        .matchedGeometryEffect(id: self.icon, in: self.animation)
                        .offset(x: 12, y: 12)

                } else {
                    Image(systemName: self.icon)
                        .font(Typography.title)
                        .foregroundColor(self.isSelected ? Color("BBSurface") : Color("BBSubtitle"))
                        .padding(2)
                        .matchedGeometryEffect(id: self.item?.type.icon ?? "laptopcomputer", in: self.animation)
                }
            }

            Spacer().frame(width: Spacing.sm)
        }
    }
}

// MARK: - Devices Column

struct DevicesColumnView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bluetooth: any BluetoothServiceProtocol {
        self.env.bluetooth
    }

    let onSelectDevice: (BluetoothObject?) -> Void

    var body: some View {
        VStack(spacing: Spacing.sm) {
            DeviceCard(device: nil, onSelect: { self.onSelectDevice(nil) })

            if self.bluetooth.permissionStatus == .denied || self.bluetooth.permissionStatus == .restricted {
                BluetoothPermissionDeniedView()
            } else if self.bluetooth.connected.isEmpty {
                DevicesEmptyStateView()
            } else {
                ForEach(self.bluetooth.connected, id: \.address) { device in
                    DeviceCard(device: device, onSelect: { self.onSelectDevice(device) })
                }
            }
        }
        .padding(.vertical, Spacing.sm)
        .padding(.bottom, Spacing.lg)
        .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.bluetooth.connected.count)
    }
}

// MARK: - Device Detail View

struct DeviceDetailView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    private var manager: any AppManagerProtocol {
        self.env.app
    }

    let device: BluetoothObject?
    let onBack: () -> Void

    @State private var isConnecting: Bool = false
    @State private var connectionError: BluetoothConnectionState?
    @Namespace private var animation

    private var isMacDevice: Bool {
        self.device == nil
    }

    private var name: String {
        if let device = self.device {
            return device.device ?? device.type.type.rawValue
        }
        return self.manager.appDeviceType.name
    }

    private var deviceIcon: String {
        if let device = self.device {
            return device.type.icon
        }
        return "laptopcomputer"
    }

    private var deviceSubtitle: String {
        if let device = self.device {
            if let percent = device.battery.percent {
                return "AlertSomePercentTitle".localise([Int(percent)])
            }
            return device.connected == .connected
                ? "DeviceDetailConnectedLabel".localise()
                : "DeviceDetailDisconnectedLabel".localise()
        }
        return "AlertSomePercentTitle".localise([Int(self.battery.percentage)])
    }

    var body: some View {
        if self.isMacDevice {
            MacBatteryDashboardView(onBack: self.onBack)
        } else {
            self.bluetoothDetailContent
        }
    }

    private var bluetoothDetailContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Button(action: self.onBack) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("DeviceDetailBackLabel".localise())
                }
                .font(Typography.heading)
                .foregroundStyle(Color("BBSubtitle"))
            }
            .buttonStyle(HoverButtonStyle())

            HStack(spacing: Spacing.smd) {
                VStack {
                    ZStack {
                        BluetoothIcon(self.device, isSelected: false, animation: self.animation)
                    }
                    .frame(width: 48, height: 48)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(self.name)
                        .font(Typography.titleBold)
                        .foregroundStyle(Color("BBTitle"))

                    Text(self.deviceSubtitle)
                        .font(Typography.heading)
                        .foregroundStyle(Color("BBSubtitle"))
                }
            }

            VStack(alignment: .leading, spacing: Spacing.smd) {
                self.bluetoothDetailRows
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                    .fill(Color("BBSurface"))
            )

            if let device = self.device {
                if let error = self.connectionError {
                    BluetoothConnectionFailedView(
                        deviceName: self.name,
                        errorType: error,
                        retryAction: {
                            self.connectionError = nil
                            self.isConnecting = true
                            Task {
                                let result = self.env.bluetooth.updateConnection(device, state: .connected)
                                await MainActor.run {
                                    self.isConnecting = false
                                    if result != .connected {
                                        self.connectionError = result
                                    }
                                }
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .blurReplace))
                } else {
                    self.connectionButton(for: device)
                        .transition(.opacity.combined(with: .blurReplace))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: self.connectionError) {
            guard self.connectionError != nil else { return }
            try? await Task.sleep(for: .seconds(5))
            self.connectionError = nil
        }
        .animation(DesignAnimation.easeOut(reduceMotion: self.reduceMotion), value: self.connectionError)
    }

    @ViewBuilder
    private var bluetoothDetailRows: some View {
        if let device = self.device {
            VStack(alignment: .leading, spacing: Spacing.smd) {
                self.detailRow(
                    "antenna.radiowaves.left.and.right",
                    "DeviceDetailStatusLabel".localise(),
                    device.connected == .connected
                        ? "DeviceDetailConnectedLabel".localise()
                        : "DeviceDetailDisconnectedLabel".localise(),
                    effect: device.connected == .connected ? .variableColor : .none
                )
                self.detailRow(
                    device.type.icon,
                    "DeviceDetailTypeLabel".localise(),
                    device.type.type.name
                )

                if let left = device.battery.left, let right = device.battery.right {
                    self.detailRow(
                        "battery.75percent",
                        "DeviceDetailBatteryLabel".localise(),
                        "BluetoothBatteryLeftRightDisplay".localise([Int(left), Int(right)])
                    )
                } else if let percent = device.battery.percent {
                    self.detailRow(
                        "battery.75percent",
                        "DeviceDetailBatteryLabel".localise(),
                        "AlertSomePercentTitle".localise([Int(percent)])
                    )
                }

                if let caseBattery = device.battery.chargingCase {
                    self.detailRow(
                        "case.fill",
                        "DeviceDetailCaseLabel".localise(),
                        "AlertSomePercentTitle".localise([Int(caseBattery)])
                    )
                }

                if let vendorName = device.type.vendor?.name {
                    self.detailRow(
                        "building.2",
                        "DeviceDetailBrandLabel".localise(),
                        vendorName
                    )
                }
            }
        }
    }

    private func detailRow(
        _ icon: String,
        _ label: String,
        _ value: String,
        effect: HUDIconEffect = .none
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(Typography.heading)
                .foregroundStyle(Color("BBSubtitle"))
                .frame(width: 18, alignment: .center)
                .applySymbolEffect(effect)
            Text(label)
                .font(Typography.heading)
                .foregroundStyle(Color("BBSubtitle"))
            Spacer()
            Text(value)
                .font(Typography.headingLarge)
                .foregroundStyle(Color("BBTitle"))
        }
    }

    @ViewBuilder
    private func connectionButton(for device: BluetoothObject) -> some View {
        let isConnected = device.connected == .connected
        Button(
            action: {
                guard !self.isConnecting else { return }
                self.isConnecting = true
                Task {
                    let targetState: BluetoothState = isConnected ? .disconnected : .connected
                    let result = self.env.bluetooth.updateConnection(device, state: targetState)
                    await MainActor.run {
                        self.isConnecting = false
                        if result != .connected, result != .disconnected {
                            self.connectionError = result
                        }
                    }
                }
            },
            label: {
                HStack(spacing: Spacing.xsm) {
                    if self.isConnecting {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: isConnected ? "xmark.circle" : "link")
                            .font(Typography.heading)
                    }
                    Text(isConnected
                        ? "BluetoothDisconnectLabel".localise()
                        : "BluetoothConnectLabel".localise())
                        .font(Typography.heading)
                }
                .foregroundStyle(Color("BBSubtitle"))
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                        .fill(Color("BBSurface"))
                )
            }
        )
        .buttonStyle(HoverButtonStyle())
        .disabled(self.isConnecting)
    }
}

struct BluetoothPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32))
                    .foregroundColor(Color("BBSubtitle").opacity(0.4))

                Image(systemName: "exclamationmark.circle.fill")
                    .font(Typography.heading)
                    .foregroundStyle(SemanticColor.warning)
                    .offset(x: 16, y: 12)
            }

            VStack(spacing: Spacing.xsm) {
                Text("BluetoothPermissionDeniedTitle".localise())
                    .font(Typography.headingLarge)
                    .foregroundColor(Color("BBTitle"))

                Text("BluetoothPermissionDeniedBody".localise())
                    .font(Typography.small)
                    .foregroundColor(Color("BBSubtitle"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: openSystemPreferences) {
                HStack(spacing: Spacing.xsm) {
                    Image(systemName: "gear")
                    Text("BluetoothOpenSettingsButton".localise())
                }
                .font(Typography.heading)
                .foregroundColor(Color("BBSurface"))
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                        .fill(Color("BBTitle"))
                )
            }
            .buttonStyle(HoverButtonStyle())
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BBSurface"))
        )
        .accessibilityElement(children: .combine)
    }

    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct BluetoothConnectionFailedView: View {
    let deviceName: String
    let errorType: BluetoothConnectionState
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: Spacing.smd) {
            Image(systemName: self.errorIcon)
                .font(Typography.icon)
                .foregroundColor(self.errorColor)
                .applySymbolEffect(.pulse)

            VStack(spacing: Spacing.xs) {
                Text(self.deviceName)
                    .font(Typography.heading)
                    .foregroundColor(Color("BBTitle"))

                Text(self.errorMessage)
                    .font(Typography.small)
                    .foregroundColor(Color("BBSubtitle"))
                    .multilineTextAlignment(.center)
            }

            if self.errorType == .restricted {
                Button(action: self.openSystemPreferences) {
                    HStack(spacing: Spacing.xsm) {
                        Image(systemName: "gear")
                        Text("BluetoothOpenSettingsButton".localise())
                    }
                    .font(Typography.heading)
                    .foregroundColor(Color("BBSurface"))
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                            .fill(Color("BBTitle"))
                    )
                }
                .buttonStyle(HoverButtonStyle())
                .accessibilityLabel("BluetoothOpenSettingsButton".localise())
                .accessibilityHint("BluetoothOpenSettingsHint".localise())
            } else {
                Button(action: self.retryAction) {
                    Text("BluetoothRetryButton".localise())
                        .font(Typography.heading)
                        .foregroundColor(Color("BBTitle"))
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                                .stroke(Color("BBSubtitle"), lineWidth: 1)
                        )
                }
                .buttonStyle(HoverButtonStyle())
                .accessibilityLabel("BluetoothRetryButton".localise())
                .accessibilityHint("BluetoothRetryHint".localise())
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BBSurface"))
        )
        .accessibilityElement(children: .combine)
    }

    private var errorIcon: String {
        switch self.errorType {
        case .restricted: "lock.shield"
        case .failed: "exclamationmark.triangle"
        case .unavailable: "questionmark.circle"
        default: "xmark.circle"
        }
    }

    private var errorColor: Color {
        switch self.errorType {
        case .failed: SemanticColor.error
        case .restricted: SemanticColor.warning
        default: SemanticColor.info
        }
    }

    private var errorMessage: String {
        switch self.errorType {
        case .restricted: "BluetoothRestrictedError".localise()
        case .failed: "BluetoothConnectionFailedError".localise()
        case .unavailable: "BluetoothUnavailableError".localise()
        default: "BluetoothGenericError".localise()
        }
    }

    private func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth") {
            NSWorkspace.shared.open(url)
        }
    }
}
