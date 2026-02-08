import SwiftUI

struct BluetoothIcon: View {
    @Environment(\.appEnvironment) private var env

    @State private var item: BluetoothObject?
    @State private var icon: String
    @State private var animation: Namespace.ID

    @Binding private var style: RadialStyle

    private var manager: AppManager {
        env.app
    }

    init(_ item: BluetoothObject?, style: Binding<RadialStyle>, animation: Namespace.ID) {
        _item = State(initialValue: item)
        _icon = State(initialValue: item?.type.icon ?? "laptopcomputer") // Default icon, will be updated in onAppear
        _animation = State(initialValue: animation)

        _style = style

    }

    var body: some View {
        HStack {
            ZStack {
                if item == nil || item?.battery.percent != nil {
                    RadialProgressMiniContainer(item, style: $style)

                    Image(systemName: icon)
                        .font(Typography.bodyMedium)
                        .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatterySubtitle"))
                        .padding(2)
                        .background(
                            Circle()
                                .fill(style == .light ? Color("BatteryTitle") : Color("BatteryButton"))
                                .blur(radius: 2)

                        )
                        .matchedGeometryEffect(id: icon, in: animation)
                        .offset(x: 12, y: 12)

                } else {
                    Image(systemName: icon)
                        .font(Typography.title)
                        .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatterySubtitle"))
                        .padding(2)
                        .matchedGeometryEffect(id: item?.type.icon ?? "laptopcomputer", in: animation)

                }

            }

            Spacer().frame(width: 18)

        }

    }

}

struct BluetoothItem: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.serviceContainer) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var manager: AppManager {
        env.app
    }

    private var battery: any BatteryServiceProtocol {
        env.battery
    }

    @Binding var hover: Bool

    @State var item: BluetoothObject?
    @State var style: RadialStyle = .light
    @State private var isConnecting: Bool = false
    @State private var connectionError: BluetoothConnectionState?

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
                        container.state.selectedDevice = item
                    }
                } else {
                    container.state.selectedDevice = item
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
                    BluetoothIcon(item, style: $style, animation: animation)

                    VStack(alignment: .leading) {
                        if let item {
                            Text(item.device ?? item.type.type.rawValue)
                                .font(Typography.headingLarge)
                                .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatteryTitle"))
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

                                // Connection status indicator (always visible)
                                Circle()
                                    .fill(isConnecting ? Color
                                        .orange : (item.connected == .connected ? Color.green : Color.gray))
                                    .frame(width: 6, height: 6)
                            }
                            .font(Typography.small)
                            .foregroundColor(Color("BatterySubtitle"))

                        } else {
                            Text(manager.appDeviceType.name)
                                .font(Typography.headingLarge)
                                .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatteryTitle"))
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
                        .fill(style == .light ? Color("BatteryTitle") : Color("BatteryButton"))

                )
            }
        )
        .buttonStyle(.plain)
        .onHover { hover in
            switch hover {
            case true: NSCursor.pointingHand.push()
            default: NSCursor.pop()
            }

        }
        .onChange(of: container.state.selectedDevice) { _, newValue in
            if let animation = easeOutAnimation {
                withAnimation(animation) {
                    style = newValue == item ? .light : .dark
                }
            } else {
                style = newValue == item ? .light : .dark
            }

        }
        .onAppear {
            if container.state.selectedDevice == item {
                style = .light

            } else {
                style = .dark

            }

        }
        .accessibilityLabel(deviceName)
        .accessibilityValue(batteryInfo)
        .accessibilityHint("AccessibilityDoubleTapSelect".localise())
        .accessibilityAddTraits(container.state.selectedDevice == item ? .isSelected : [])

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
