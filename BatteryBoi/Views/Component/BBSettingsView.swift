import SwiftUI

struct SettingsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value _: inout CGPoint, nextValue _: () -> CGPoint) {}

}

struct SettingsItem: View {
    @EnvironmentObject var manager: AppManager
    @EnvironmentObject var updates: UpdateManager
    @EnvironmentObject var settings: SettingsManager
    @EnvironmentObject var battery: BatteryManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var hover: Bool

    @State var item: SettingsActionObject
    @State var subtitle: String?
    @State var color: String?
    @State var icon: String?

    private var changeAnimation: Animation? {
        reduceMotion ? nil : Animation.easeOut.delay(0.1)
    }

    var body: some View {
        Button(
            action: {
                SettingsManager.shared.settingsAction(item)
            },
            label: {
                HStack(alignment: .center) {
                    Image(icon ?? item.type.icon)
                        .font(.system(size: 23, weight: .medium))
                        .foregroundColor(color == nil ? Color("BatterySubtitle") : Color("BatteryEfficient"))
                        .frame(height: 36)
                        .padding(.trailing, 6)

                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("BatteryTitle"))
                            .padding(0)

                        if hover == true, subtitle != nil {
                            Text(subtitle ?? "")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color("BatterySubtitle"))

                        }

                    }

                }
                .frame(height: 60)
                .padding(.leading, 18)
                .padding(.trailing, 26)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Color("BatteryButton")),

                )
            },
        )
        .buttonStyle(.plain)
        .onAppear {
            if item.type == .appEfficencyMode {
                color = battery.saver == .efficient ? "BatteryEfficient" : nil
                subtitle = battery.saver == .efficient ? "SettingsEnabledLabel".localise() : "SettingsDisabledLabel"
                    .localise()

            } else if item.type == .appPinned {
                subtitle = settings.pinned.subtitle
                icon = settings.pinned.icon

            } else if item.type == .appUpdateCheck {
                subtitle = updates.state.subtitle(updates.checked)

            } else if item.type == .customiseDisplay {
                subtitle = settings.enabledDisplay(false).type
                icon = settings.enabledDisplay(false).icon

            } else if item.type == .customiseSoundEffects {
                subtitle = settings.sfx.subtitle
                icon = settings.sfx.icon

            } else if item.type == .customiseCharge {
                subtitle = settings.charge.subtitle
                icon = settings.charge.icon

            }

        }
        .onChange(of: battery.saver) { _, newSaver in
            if let animation = changeAnimation {
                withAnimation(animation) {
                    if item.type == .appEfficencyMode {
                        color = newSaver == .efficient ? "BatteryEfficient" : nil
                        subtitle = newSaver == .efficient ? "SettingsEnabledLabel".localise() : "SettingsDisabledLabel"
                            .localise()
                    }
                }
            } else {
                if item.type == .appEfficencyMode {
                    color = newSaver == .efficient ? "BatteryEfficient" : nil
                    subtitle = newSaver == .efficient ? "SettingsEnabledLabel".localise() : "SettingsDisabledLabel"
                        .localise()
                }
            }

        }
        .onChange(of: updates.state) { _, newState in
            if let animation = changeAnimation {
                withAnimation(animation) {
                    if item.type == .appUpdateCheck {
                        subtitle = newState.subtitle(updates.checked)
                    }
                }
            } else {
                if item.type == .appUpdateCheck {
                    subtitle = newState.subtitle(updates.checked)
                }
            }

        }
        .onChange(of: settings.display) { _, newValue in
            if let animation = changeAnimation {
                withAnimation(animation) {
                    if item.type == .customiseDisplay {
                        subtitle = newValue.type
                        icon = newValue.icon
                    }
                }
            } else {
                if item.type == .customiseDisplay {
                    subtitle = newValue.type
                    icon = newValue.icon
                }
            }

        }
        .onChange(of: settings.sfx) { _, newSfx in
            if item.type == .customiseSoundEffects {
                subtitle = newSfx.subtitle
                icon = newSfx.icon

            }

        }
        .onChange(of: settings.pinned) { _, newPinned in
            if item.type == .appPinned {
                subtitle = newPinned.subtitle
                icon = newPinned.icon

            }

        }
        .onChange(of: settings.charge) { _, newCharge in
            if item.type == .customiseCharge {
                subtitle = newCharge.subtitle
                icon = newCharge.icon

            }

        }
        .onHover { hover in
            switch hover {
            case true: NSCursor.pointingHand.push()
            default: NSCursor.pop()
            }

        }
        .accessibilityLabel(item.title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityHint("Double tap to activate")

    }

}

struct SettingsOverlayItem: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var manager: AppManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var item: SettingsActionType
    @State private var icon: String = ""
    @State private var visible: Bool = true
    @State private var timeline = [String]()
    @State private var index: Int = 0

    init(_ item: SettingsActionType) {
        _item = State(initialValue: item)

    }

    private var accessibilityLabel: String {
        switch item {
        case .appQuit: "Quit application"
        case .appDevices: manager.menu == .settings ? "Show devices" : "Show settings"
        default: "Toggle menu"
        }
    }

    var body: some View {
        Button(
            action: {
                switch item {
                case .appQuit: SettingsManager.shared.settingsAction(.init(item))
                default: AppManager.shared.appToggleMenu(true)
                }
            },
            label: {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color("BatteryButton"))
                    .frame(width: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color("BatterySubtitle")),

                    )
            },
        )
        .buttonStyle(.plain)
        .keyboardShortcut(item == .appQuit ? "q" : nil, modifiers: item == .appQuit ? .command : [])
        .onAppear {
            index = 0
            timeline = bluetooth.connected.map(\.type.icon)

            if item == .appQuit {
                icon = "power"

            } else {
                switch manager.menu {
                case .settings: icon = timeline.index(index) ?? "headphones"
                default: icon = "gearshape.fill"
                }

            }

        }
        .onChange(of: manager.menu) { _, newMenu in
            if item == .appDevices {
                switch newMenu {
                case .settings: icon = timeline.index(index) ?? "headphones"
                default: icon = "gearshape.fill"
                }

            }

        }
        .onChange(of: bluetooth.connected) { _, newValue in
            if item == .appDevices {
                timeline = newValue.map(\.type.icon)

            }

        }
        .task {
            // Skip icon cycling animation if reduce motion is enabled
            guard !reduceMotion else { return }

            // Cycle through device icons every 2 seconds
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }

                if item == .appDevices {
                    switch timeline.index(index) {
                    case nil: index = 0
                    default: index += 1
                    }

                    if let newIcon = timeline.index(index) {
                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.9, blendDuration: 1)) {
                            icon = newIcon
                        }
                    }
                }
            }
        }
        .onHover { hover in
            switch hover {
            case true: NSCursor.pointingHand.push()
            default: NSCursor.pop()
            }

        }
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to activate")

    }

}
