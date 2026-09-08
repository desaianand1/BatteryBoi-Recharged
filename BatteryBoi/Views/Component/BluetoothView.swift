import SwiftUI

struct BluetoothIcon: View {
    @Environment(AppEnvironment.self) private var env

    @State private var item: BluetoothObject?
    @State private var icon: String
    @State private var animation: Namespace.ID

    private let isSelected: Bool

    private var manager: AppManager {
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
                        .foregroundColor(self.isSelected ? Color("BatteryButton") : Color("BatterySubtitle"))
                        .padding(2)
                        .background(
                            Circle()
                                .fill(self.isSelected ? Color("BatteryTitle") : Color("BatteryButton"))
                                .blur(radius: 2)
                        )
                        .matchedGeometryEffect(id: self.icon, in: self.animation)
                        .offset(x: 12, y: 12)

                } else {
                    Image(systemName: self.icon)
                        .font(Typography.title)
                        .foregroundColor(self.isSelected ? Color("BatteryButton") : Color("BatterySubtitle"))
                        .padding(2)
                        .matchedGeometryEffect(id: self.item?.type.icon ?? "laptopcomputer", in: self.animation)
                }
            }

            Spacer().frame(width: 18)
        }
    }
}

struct BluetoothItem: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var manager: AppManager {
        env.app
    }

    private var battery: any BatteryServiceProtocol {
        env.battery
    }

    @Binding var hover: Bool

    @State var item: BluetoothObject?
    @State var isSelected: Bool = true
    @State private var isConnecting: Bool = false
    @State private var connectionError: BluetoothConnectionState?
    @State private var connectionDotOpacity: Double = 1.0

    @Namespace private var animation

    init(_ item: BluetoothObject?, hover: Binding<Bool>) {
        _item = State(initialValue: item)
        _hover = hover

    }

    private var easeOutAnimation: Animation? {
        reduceMotion ? nil : Animation.easeOut
    }

    private var deviceName: String {
        if let item {
            return item.device ?? item.type.type.rawValue
        }
        return manager.appDeviceType.name
    }

    private var batteryInfo: String {
        if let item {
            if item.connected == .disconnected {
                return "Disconnected"
            } else if let left = item.battery.left, let right = item.battery.right {
                return "Left \(Int(left)) percent, Right \(Int(right)) percent"
            } else if let percent = item.battery.percent {
                return "\(Int(percent)) percent"
            } else {
                return "Battery level unavailable"
            }
        }
        return "\(Int(battery.percentage)) percent"
    }

    var body: some View {
        Button(
            action: {
                guard !isConnecting else { return }

                if let animation = easeOutAnimation {
                    withAnimation(animation) {
                        env.window.currentDevice = item
                    }
                } else {
                    env.window.currentDevice = item
                }

                // Handle connection for disconnected devices
                if let item, item.connected == .disconnected {
                    isConnecting = true
                    connectionError = nil

                    Task {
                        let result = env.bluetooth.updateConnection(item, state: .connected)
                        await MainActor.run {
                            isConnecting = false
                            if result != .connected {
                                connectionError = result
                            }
                        }
                    }
                }
            },
            label: {
                HStack(alignment: .center) {
                    BluetoothIcon(item, isSelected: self.isSelected, animation: self.animation)

                    VStack(alignment: .leading) {
                        if let item {
                            Text(item.device ?? item.type.type.rawValue)
                                .font(Typography.headingLarge)
                                .foregroundColor(self.isSelected ? Color("BatteryButton") : Color("BatteryTitle"))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(0)

                            HStack(spacing: 4) {
                                // Show connecting state with spinner
                                if isConnecting {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                        .frame(width: 12, height: 12)
                                    Text("BluetoothConnectingLabel".localise())
                                } else if item.connected == .disconnected {
                                    Text("BluetoothNotConnectedLabel".localise())
                                } else {
                                    // Show left/right battery for AirPods-style devices
                                    if let left = item.battery.left, let right = item.battery.right {
                                        Text("L: \(Int(left))%  R: \(Int(right))%")
                                    } else if let percent = item.battery.percent {
                                        Text("AlertSomePercentTitle".localise([Int(percent)]))
                                    } else {
                                        Text("BluetoothInvalidLabel".localise())
                                    }
                                }

                                Circle()
                                    .fill(
                                        self.isConnecting
                                            ? Color.orange
                                            : (item.connected == .connected ? Color.green : Color.gray)
                                    )
                                    .frame(width: 6, height: 6)
                                    .opacity(self.isConnecting ? self.connectionDotOpacity : 1.0)
                            }
                            .font(Typography.small)
                            .foregroundColor(Color("BatterySubtitle"))

                        } else {
                            Text(manager.appDeviceType.name)
                                .font(Typography.headingLarge)
                                .foregroundColor(self.isSelected ? Color("BatteryButton") : Color("BatteryTitle"))
                                .padding(0)

                            // Always show battery percentage for Mac device
                            Text("AlertSomePercentTitle".localise([Int(battery.percentage)]))
                                .font(Typography.small)
                                .foregroundColor(Color("BatterySubtitle"))

                        }

                    }

                }
                .frame(minHeight: 60)
                .padding(.leading, 16)
                .padding(.trailing, 26)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                        .fill(self.isSelected ? Color("BatteryTitle") : Color("BatteryButton"))

                )
            }
        )
        .buttonStyle(HoverButtonStyle())
        .onChange(of: self.env.window.currentDevice) { _, newValue in
            if let animation = self.easeOutAnimation {
                withAnimation(animation) {
                    self.isSelected = newValue == self.item
                }
            } else {
                self.isSelected = newValue == self.item
            }
        }
        .onAppear {
            self.isSelected = self.env.window.currentDevice == self.item
        }
        .onChange(of: self.isConnecting) { _, connecting in
            if connecting, !self.reduceMotion {
                self.connectionDotOpacity = 0.3
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    self.connectionDotOpacity = 1.0
                }
            } else {
                self.connectionDotOpacity = 1.0
            }
        }
        .accessibilityLabel(self.deviceName)
        .accessibilityValue(batteryInfo)
        .accessibilityHint("AccessibilityDoubleTapSelect".localise())
        .accessibilityAddTraits(env.window.currentDevice == item ? .isSelected : [])

    }

}

struct BluetoothEmptyStateView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "airpodspro")
                .font(.system(size: 24))
                .foregroundColor(Color("BatterySubtitle").opacity(0.6))

            VStack(alignment: .leading, spacing: 4) {
                Text("BluetoothNoDevicesTitle".localise())
                    .font(Typography.headingLarge)
                    .foregroundColor(Color("BatteryTitle"))

                Text("BluetoothNoDevicesBody".localise())
                    .font(Typography.small)
                    .foregroundColor(Color("BatterySubtitle"))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BatteryButton"))
        )
        .accessibilityElement(children: .combine)
    }
}

struct BluetoothPermissionDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 32))
                    .foregroundColor(Color("BatterySubtitle").opacity(0.4))

                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .offset(x: 16, y: 12)
            }

            VStack(spacing: 6) {
                Text("BluetoothPermissionDeniedTitle".localise())
                    .font(Typography.headingLarge)
                    .foregroundColor(Color("BatteryTitle"))

                Text("BluetoothPermissionDeniedBody".localise())
                    .font(Typography.small)
                    .foregroundColor(Color("BatterySubtitle"))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }

            Button(action: openSystemPreferences) {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                    Text("BluetoothOpenSettingsButton".localise())
                }
                .font(Typography.heading)
                .foregroundColor(Color("BatteryButton"))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                        .fill(Color("BatteryTitle"))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BatteryButton"))
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
        VStack(spacing: 12) {
            Image(systemName: errorIcon)
                .font(.system(size: 24))
                .foregroundColor(errorColor)

            VStack(spacing: 4) {
                Text(deviceName)
                    .font(Typography.heading)
                    .foregroundColor(Color("BatteryTitle"))

                Text(errorMessage)
                    .font(Typography.small)
                    .foregroundColor(Color("BatterySubtitle"))
                    .multilineTextAlignment(.center)
            }

            if errorType != .restricted {
                Button(action: retryAction) {
                    Text("BluetoothRetryButton".localise())
                        .font(Typography.small)
                        .foregroundColor(Color("BatteryTitle"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                                .stroke(Color("BatterySubtitle"), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                .fill(Color("BatteryButton"))
        )
    }

    private var errorIcon: String {
        switch errorType {
        case .restricted: "lock.shield"
        case .failed: "exclamationmark.triangle"
        case .unavailable: "questionmark.circle"
        default: "xmark.circle"
        }
    }

    private var errorColor: Color {
        switch errorType {
        case .restricted: .orange
        case .failed: .red
        default: Color("BatterySubtitle")
        }
    }

    private var errorMessage: String {
        switch errorType {
        case .restricted: "BluetoothRestrictedError".localise()
        case .failed: "BluetoothConnectionFailedError".localise()
        case .unavailable: "BluetoothUnavailableError".localise()
        default: "BluetoothGenericError".localise()
        }
    }
}
