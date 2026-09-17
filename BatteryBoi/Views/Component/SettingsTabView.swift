import ServiceManagement
import SwiftUI

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let header: String?
    @ViewBuilder let content: Content

    init(header: String? = nil, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = self.header {
                Text(header.uppercased())
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.xs)
            }

            VStack(spacing: 0) {
                self.content
            }
            .surfaceCard()
        }
    }
}

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var subtitle: String?
    var accentColor: Color?

    @State private var iconBounce: Int = 0

    var body: some View {
        HStack(spacing: Spacing.smd) {
            SettingsRowIcon(systemName: self.icon, color: self.accentColor ?? Color("BBSubtitle"))
                .symbolEffect(.bounce, value: self.iconBounce)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(self.title)
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))

                if let subtitle = self.subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Color("BBSubtitle"))
                }
            }

            Spacer()

            Toggle("", isOn: self.$isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .tint(self.accentColor ?? .accentColor)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .contentShape(Rectangle())
        .settingsRowHover()
        .onChange(of: self.isOn) {
            self.iconBounce += 1
            HapticUtility.toggle()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.title)
        .accessibilityValue(self.isOn ? "On" : "Off")
    }
}

// MARK: - Settings Picker Row

struct SettingsPickerRow<SelectionValue: Hashable>: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var selection: SelectionValue
    let options: [(value: SelectionValue, label: String)]

    private var currentLabel: String {
        self.options.first(where: { $0.value == self.selection })?.label ?? ""
    }

    var body: some View {
        HStack(spacing: Spacing.smd) {
            SettingsRowIcon(systemName: self.icon)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(self.title)
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))

                if let subtitle = self.subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(Color("BBSubtitle"))
                }
            }

            Spacer()

            Menu {
                ForEach(Array(self.options.enumerated()), id: \.offset) { _, option in
                    Button {
                        self.selection = option.value
                    } label: {
                        if option.value == self.selection {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Text(self.currentLabel)
                        .font(Typography.caption)
                        .foregroundStyle(Color("BBSubtitle"))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color("BBSubtitle"))
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .foregroundStyle(Color("BBSubtitle"))
            .fixedSize()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .settingsRowHover()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(self.title)
        .accessibilityValue(self.currentLabel)
    }
}

// MARK: - Settings Disclosure Row

struct SettingsDisclosureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: Spacing.smd) {
                SettingsRowIcon(systemName: self.icon)

                Text(self.title)
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))

                Spacer()

                Text(self.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color("BBSubtitle").opacity(0.5))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.smd)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButtonStyle())
    }
}

// MARK: - Settings Action Row

struct SettingsActionRow: View {
    let icon: String
    let title: String
    var iconColor: Color = .init("BBSubtitle")
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack(spacing: Spacing.smd) {
                SettingsRowIcon(systemName: self.icon, color: self.iconColor)

                Text(self.title)
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))

                Spacer()
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.smd)
            .contentShape(Rectangle())
        }
        .buttonStyle(HoverButtonStyle())
    }
}

// MARK: - Settings Sync Modifier

struct SettingsForwardSyncModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var soundEnabled: Bool
    @Binding var chargeAlertEnabled: Bool
    @Binding var pinEnabled: Bool
    @Binding var launchAtLogin: Bool
    @Binding var powerSaveEnabled: Bool
    @Binding var selectedDisplay: SettingsDisplayType
    @Binding var selectedPosition: WindowPosition
    @Binding var isLoaded: Bool

    private var settings: any SettingsServiceProtocol {
        self.env.settings
    }

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: self.soundEnabled) { _, new in
                guard self.isLoaded else { return }
                self.settings.soundEffects = new ? .enabled : .disabled
            }
            .onChange(of: self.chargeAlertEnabled) { _, new in
                guard self.isLoaded else { return }
                self.settings.charge = new ? .enabled : .disabled
            }
            .onChange(of: self.pinEnabled) { _, new in
                guard self.isLoaded else { return }
                self.settings.pinned = new ? .enabled : .disabled
            }
            .onChange(of: self.launchAtLogin) { _, new in
                guard self.isLoaded else { return }
                self.settings.autoLaunch = new ? .enabled : .disabled
            }
            .onChange(of: self.powerSaveEnabled) { _, new in
                guard self.isLoaded else { return }
                self.settings.enabledPowerSave = new
            }
            .onChange(of: self.selectedDisplay) { _, new in
                guard self.isLoaded else { return }
                self.settings.setDisplay(new)
            }
            .onChange(of: self.selectedPosition) { _, new in
                guard self.isLoaded else { return }
                self.window.setPosition(new)
            }
    }
}

struct SettingsReverseSyncSoundModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var soundEnabled: Bool

    func body(content: Content) -> some View {
        content.onChange(of: self.env.settings.sfx) { _, new in self.soundEnabled = (new == .enabled) }
    }
}

struct SettingsReverseSyncChargeModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var chargeAlertEnabled: Bool

    func body(content: Content) -> some View {
        content.onChange(of: self.env.settings.charge) { _, new in self.chargeAlertEnabled = (new == .enabled) }
    }
}

struct SettingsReverseSyncPinModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var pinEnabled: Bool

    func body(content: Content) -> some View {
        content.onChange(of: self.env.settings.pinned) { _, new in self.pinEnabled = (new == .enabled) }
    }
}

struct SettingsReverseSyncDisplayModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var selectedDisplay: SettingsDisplayType

    func body(content: Content) -> some View {
        content.onChange(of: self.env.settings.display) { _, new in self.selectedDisplay = new }
    }
}

// MARK: - Quit Keyboard Shortcut (moved from SettingsView)

struct QuitKeyboardShortcutModifier: ViewModifier {
    let isQuitButton: Bool

    func body(content: Content) -> some View {
        if self.isQuitButton {
            content.keyboardShortcut("q", modifiers: .command)
        } else {
            content
        }
    }
}

// MARK: - Settings Tab View

struct SettingsTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var settings: any SettingsServiceProtocol {
        self.env.settings
    }

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    private var update: any UpdateManagerProtocol {
        self.env.update
    }

    @State private var soundEnabled: Bool = false
    @State private var chargeAlertEnabled: Bool = false
    @State private var pinEnabled: Bool = false
    @State private var launchAtLogin: Bool = false
    @State private var powerSaveEnabled: Bool = false
    @State private var selectedDisplay: SettingsDisplayType = .percent
    @State private var selectedPosition: WindowPosition = .topMiddle
    @State private var didLoad: Bool = false

    var body: some View {
        self.settingsContent
            .onAppear { self.loadSettings() }
            .modifier(SettingsForwardSyncModifier(
                soundEnabled: self.$soundEnabled,
                chargeAlertEnabled: self.$chargeAlertEnabled,
                pinEnabled: self.$pinEnabled,
                launchAtLogin: self.$launchAtLogin,
                powerSaveEnabled: self.$powerSaveEnabled,
                selectedDisplay: self.$selectedDisplay,
                selectedPosition: self.$selectedPosition,
                isLoaded: self.$didLoad
            ))
            .modifier(SettingsReverseSyncSoundModifier(soundEnabled: self.$soundEnabled))
            .modifier(SettingsReverseSyncChargeModifier(chargeAlertEnabled: self.$chargeAlertEnabled))
            .modifier(SettingsReverseSyncPinModifier(pinEnabled: self.$pinEnabled))
            .modifier(SettingsReverseSyncDisplayModifier(selectedDisplay: self.$selectedDisplay))
    }

    private var settingsContent: some View {
        VStack(spacing: Spacing.md) {
            self.displaySection
            self.notificationsSection
            self.behaviorSection
            self.actionsSection
        }
        .padding(.bottom, Spacing.lg)
    }

    private var displaySection: some View {
        SettingsSection(header: "SettingsTileMenuBarLabel".localise()) {
            SettingsPickerRow(
                icon: "rectangle.dashed",
                title: "SettingsMenuBarIconLabel".localise(),
                subtitle: "SettingsMenuBarIconSubtitle".localise(),
                selection: self.$selectedDisplay,
                options: [
                    (.countdown, SettingsDisplayType.countdown.type),
                    (.percent, SettingsDisplayType.percent.type),
                    (.empty, SettingsDisplayType.empty.type),
                    (.cycle, SettingsDisplayType.cycle.type),
                    (.hidden, SettingsDisplayType.hidden.type),
                ]
            )
            SettingsDivider()
            SettingsPickerRow(
                icon: "rectangle.inset.filled",
                title: "SettingsTilePositionLabel".localise(),
                selection: self.$selectedPosition,
                options: WindowPosition.allCases.map { ($0, $0.displayName) }
            )
        }
    }

    private var notificationsSection: some View {
        SettingsSection(header: "SettingsNotificationsHeader".localise()) {
            SettingsToggleRow(
                icon: "speaker.wave.2.fill",
                title: "SettingsSoundEffectsLabel".localise(),
                isOn: self.$soundEnabled
            )
            SettingsDivider()
            SettingsToggleRow(
                icon: "bolt.fill",
                title: "SettingsEightyLabel".localise(),
                isOn: self.$chargeAlertEnabled,
                subtitle: "SettingsEightySubtitle".localise(),
                accentColor: .orange
            )
        }
    }

    private var behaviorSection: some View {
        SettingsSection(header: "SettingsGeneralHeader".localise()) {
            SettingsToggleRow(
                icon: "pin.fill",
                title: "SettingsPinnedLabel".localise(),
                isOn: self.$pinEnabled,
                subtitle: "SettingsPinnedSubtitle".localise()
            )
            SettingsDivider()
            self.launchAtLoginRow
            SettingsDivider()
            SettingsToggleRow(
                icon: "leaf.fill",
                title: "SettingsEfficiencyLabel".localise(),
                isOn: self.$powerSaveEnabled,
                subtitle: "SettingsEfficiencySubtitle".localise(),
                accentColor: .green
            )
        }
    }

    @ViewBuilder
    private var launchAtLoginRow: some View {
        let autoLaunchState = self.settings.autoLaunch
        let requiresApproval = autoLaunchState == .undetermined || autoLaunchState == .restricted

        if requiresApproval {
            Button {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: Spacing.smd) {
                    SettingsRowIcon(systemName: "arrow.right.circle")

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("OnboardingLaunchAtLoginLabel".localise())
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBTitle"))

                        Text("SettingsLoginRequiresApprovalSubtitle".localise())
                            .font(Typography.caption)
                            .foregroundStyle(Color("BBSubtitle"))
                    }

                    Spacer()

                    Toggle("", isOn: .constant(false))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .controlSize(.small)
                        .disabled(true)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.smd)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .settingsRowHover()
        } else {
            SettingsToggleRow(
                icon: "arrow.right.circle",
                title: "OnboardingLaunchAtLoginLabel".localise(),
                isOn: self.$launchAtLogin
            )
        }
    }

    private var actionsSection: some View {
        SettingsSection {
            SettingsDisclosureRow(
                icon: "arrow.triangle.2.circlepath",
                title: "SettingsCheckUpdatesLabel".localise(),
                subtitle: self.update.versionDisplay,
                action: { self.update.updateCheck() }
            )
            SettingsDivider()
            SettingsActionRow(
                icon: "power",
                title: "SettingsQuitLabel".localise(),
                iconColor: .red,
                action: { self.settings.performAction(.init(.appQuit)) }
            )
            .modifier(QuitKeyboardShortcutModifier(isQuitButton: true))
        }
    }

    private func loadSettings() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            self.soundEnabled = self.settings.sfx == .enabled
            self.chargeAlertEnabled = self.settings.charge == .enabled
            self.pinEnabled = self.settings.pinned == .enabled
            self.launchAtLogin = self.settings.autoLaunch == .enabled
            self.powerSaveEnabled = self.settings.enabledPowerSave
            self.selectedDisplay = self.settings.display
            self.selectedPosition = self.window.position
            self.didLoad = true
        }
    }
}
