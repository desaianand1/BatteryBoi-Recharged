import SwiftUI

struct SettingsScrollOffsetKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGPoint = .zero

    static func reduce(value _: inout CGPoint, nextValue _: () -> CGPoint) {}
}

struct QuitKeyboardShortcutModifier: ViewModifier {
    let isQuitButton: Bool

    func body(content: Content) -> some View {
        if isQuitButton {
            content.keyboardShortcut("q", modifiers: .command)
        } else {
            content
        }
    }
}

// MARK: - Settings Tile

enum SettingsTileType {
    case display
    case sound
    case alerts
    case pin

    var label: String {
        switch self {
        case .display: "SettingsTileDisplayLabel".localise()
        case .sound: "SettingsTileSoundLabel".localise()
        case .alerts: "SettingsTileAlertsLabel".localise()
        case .pin: "SettingsTilePinLabel".localise()
        }
    }
}

struct SettingsTile: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var settings: any SettingsServiceProtocol {
        self.env.settings
    }

    @State private var tileType: SettingsTileType

    init(_ tileType: SettingsTileType) {
        _tileType = State(initialValue: tileType)
    }

    private var icon: String {
        switch self.tileType {
        case .display: self.settings.display.icon
        case .sound: self.settings.sfx.icon
        case .alerts: self.settings.charge.icon
        case .pin: self.settings.pinned.icon
        }
    }

    private var subtitle: String {
        switch self.tileType {
        case .display:
            self.settings.display.type
        case .sound:
            self.subtitleForToggle(self.settings.sfx == .enabled)
        case .alerts:
            self.subtitleForToggle(self.settings.charge == .enabled)
        case .pin:
            self.subtitleForToggle(self.settings.pinned == .enabled)
        }
    }

    private func subtitleForToggle(_ enabled: Bool) -> String {
        enabled ? "SettingsTileOnLabel".localise() : "SettingsTileOffLabel".localise()
    }

    private func handleTap() {
        switch self.tileType {
        case .display: self.settings.performAction(.init(.customiseDisplay))
        case .sound: self.settings.performAction(.init(.customiseSoundEffects))
        case .alerts: self.settings.performAction(.init(.customiseCharge))
        case .pin: self.settings.performAction(.init(.appPinned))
        }
    }

    var body: some View {
        Button(action: self.handleTap) {
            VStack(spacing: Spacing.xsm) {
                Image(systemName: self.icon)
                    .font(Typography.icon)
                    .foregroundStyle(Color("BBSubtitle"))
                    .frame(height: 28)
                    .applySymbolReplaceTransition()

                Text(self.tileType.label)
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))
                    .lineLimit(1)

                Text(self.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(
                RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                    .fill(Color("BBSurface"))
            )
        }
        .buttonStyle(HoverButtonStyle())
        .accessibilityLabel(self.tileType.label)
        .accessibilityValue(self.subtitle)
        .accessibilityHint("AccessibilityDoubleTapActivate".localise())
    }
}

// MARK: - Settings Tile Grid

struct SettingsTileGrid: View {
    @Environment(AppEnvironment.self) private var env

    private var settings: any SettingsServiceProtocol {
        self.env.settings
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                SettingsTile(.display)
                SettingsTile(.sound)
            }

            HStack(spacing: Spacing.sm) {
                SettingsTile(.alerts)
                SettingsTile(.pin)
            }

            Button(
                action: { self.settings.performAction(.init(.appQuit)) },
                label: {
                    HStack(spacing: Spacing.xsm) {
                        Image(systemName: "power")
                            .font(Typography.heading)
                        Text("SettingsQuitLabel".localise())
                            .font(Typography.heading)
                    }
                    .foregroundStyle(Color("BBSubtitle"))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.CornerRadius.container, style: .continuous)
                            .fill(Color("BBSurface"))
                    )
                }
            )
            .buttonStyle(HoverButtonStyle())
            .modifier(QuitKeyboardShortcutModifier(isQuitButton: true))
            .accessibilityLabel("AccessibilityQuitApplication".localise())
        }
    }
}

// MARK: - Legacy (kept for backward compat during transition)

struct SettingsItem: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var manager: AppManager {
        env.app
    }

    private var updates: UpdateManager {
        env.update
    }

    private var settings: any SettingsServiceProtocol {
        env.settings
    }

    private var battery: any BatteryServiceProtocol {
        env.battery
    }

    @Binding var hover: Bool

    @State var item: SettingsActionObject
    @State var subtitle: String?
    @State var color: String?
    @State var icon: String?

    private var changeAnimation: Animation? {
        reduceMotion ? nil : Animation.easeOut.delay(0.1)
    }

    private func handleAction() {
        settings.performAction(item)
    }

    var body: some View {
        Button(
            action: handleAction,
            label: {
                HStack(alignment: .center) {
                    Image(systemName: icon ?? item.type.icon)
                        .font(Typography.icon)
                        .foregroundColor(color == nil ? Color("BBSubtitle") : Color("BBAccent"))
                        .frame(height: 36)
                        .padding(.trailing, 6)

                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(Typography.headingLarge)
                            .foregroundColor(Color("BBTitle"))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(0)

                        if hover == true, subtitle != nil {
                            Text(subtitle ?? "")
                                .font(Typography.small)
                                .foregroundColor(Color("BBSubtitle"))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .frame(minHeight: 60)
                .padding(.leading, 18)
                .padding(.trailing, 26)
                .background(
                    RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                        .fill(Color("BBSurface"))
                )
            }
        )
        .buttonStyle(HoverButtonStyle())
        .onAppear {
            if item.type == .appEfficiencyMode {
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
                    if item.type == .appEfficiencyMode {
                        color = newSaver == .efficient ? "BatteryEfficient" : nil
                        subtitle = newSaver == .efficient ? "SettingsEnabledLabel".localise() : "SettingsDisabledLabel"
                            .localise()
                    }
                }
            } else {
                if item.type == .appEfficiencyMode {
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
        .accessibilityLabel(item.title)
        .accessibilityValue(subtitle ?? "")
        .accessibilityHint("AccessibilityDoubleTapActivate".localise())
    }
}

struct SettingsOverlayItem: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bluetooth: any BluetoothServiceProtocol {
        env.bluetooth
    }

    private var manager: AppManager {
        env.app
    }

    private var settings: any SettingsServiceProtocol {
        env.settings
    }

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
        case .appQuit:
            return "AccessibilityQuitApplication".localise()
        case .appDevices:
            if manager.menu == .settings {
                return "AccessibilityShowDevices".localise()
            }
            return "AccessibilityShowSettings".localise()
        default:
            return "AccessibilityToggleMenu".localise()
        }
    }

    private func handleOverlayAction() {
        switch item {
        case .appQuit: settings.performAction(.init(item))
        default: manager.appToggleMenu(true)
        }
    }

    var body: some View {
        Button(
            action: handleOverlayAction,
            label: {
                RoundedRectangle(cornerRadius: Constants.CornerRadius.button, style: .continuous)
                    .fill(Color("BBSurface"))
                    .frame(width: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(Typography.headingLarge)
                            .foregroundColor(Color("BBSubtitle"))
                    )
            }
        )
        .buttonStyle(HoverButtonStyle())
        .modifier(QuitKeyboardShortcutModifier(isQuitButton: item == .appQuit))
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
            guard !reduceMotion else { return }

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
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("AccessibilityDoubleTapActivate".localise())
    }
}
