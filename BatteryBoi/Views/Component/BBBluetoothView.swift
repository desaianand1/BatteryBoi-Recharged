import SwiftUI

struct BluetoothIcon: View {
    @State private var item: BluetoothObject?
    @State private var icon: String
    @State private var animation: Namespace.ID

    @Binding private var style: RadialStyle

    init(_ item: BluetoothObject?, style: Binding<RadialStyle>, animation: Namespace.ID) {
        _item = State(initialValue: item)
        _icon = State(initialValue: item?.type.icon ?? AppManager.shared.appDeviceType.icon)
        _animation = State(initialValue: animation)

        _style = style

    }

    var body: some View {
        HStack {
            ZStack {
                if item == nil || item?.battery.percent != nil {
                    RadialProgressMiniContainer(item, style: $style)

                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatterySubtitle"))
                        .padding(2)
                        .background(
                            Circle()
                                .fill(style == .light ? Color("BatteryTitle") : Color("BatteryButton"))
                                .blur(radius: 2),

                        )
                        .matchedGeometryEffect(id: icon, in: animation)
                        .offset(x: 12, y: 12)

                } else {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
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
    @EnvironmentObject var manager: AppManager
    @EnvironmentObject var battery: BatteryManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var hover: Bool

    @State var item: BluetoothObject?
    @State var style: RadialStyle = .light

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
        return AppManager.shared.appDeviceType.name
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
                if let animation = easeOutAnimation {
                    withAnimation(animation) {
                        manager.device = item
                    }
                } else {
                    manager.device = item
                }
            },
            label: {
                HStack(alignment: .center) {
                    BluetoothIcon(item, style: $style, animation: animation)

                    VStack(alignment: .leading) {
                        if let item {
                            Text(item.device ?? item.type.type.rawValue)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatteryTitle"))
                                .padding(0)

                            HStack(spacing: 4) {
                                if hover == true {
                                    if item.connected == .disconnected {
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

                                    // Connection status indicator
                                    Circle()
                                        .fill(item.connected == .connected ? Color.green : Color.gray)
                                        .frame(width: 6, height: 6)
                                }
                            }
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color("BatterySubtitle"))

                        } else {
                            Text(AppManager.shared.appDeviceType.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatteryTitle"))
                                .padding(0)

                            if hover == true {
                                Text("AlertSomePercentTitle".localise([Int(battery.percentage)]))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color("BatterySubtitle"))

                            }

                        }

                    }

                }
                .frame(height: 60)
                .padding(.leading, 16)
                .padding(.trailing, 26)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(style == .light ? Color("BatteryTitle") : Color("BatteryButton")),

                )
            },
        )
        .buttonStyle(.plain)
        .onHover { hover in
            switch hover {
            case true: NSCursor.pointingHand.push()
            default: NSCursor.pop()
            }

        }
        .onChange(of: manager.device) { newValue in
            if let animation = easeOutAnimation {
                withAnimation(animation) {
                    style = newValue == item ? .light : .dark
                }
            } else {
                style = newValue == item ? .light : .dark
            }

        }
        .onAppear {
            if AppManager.shared.device == item {
                style = .light

            } else {
                style = .dark

            }

        }
        .accessibilityLabel(deviceName)
        .accessibilityValue(batteryInfo)
        .accessibilityHint("Double tap to select this device")
        .accessibilityAddTraits(manager.device == item ? .isSelected : [])

    }

}
