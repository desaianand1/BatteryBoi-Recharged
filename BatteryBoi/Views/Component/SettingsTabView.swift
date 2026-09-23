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

// MARK: - Settings Sub-View Navigation

enum SettingsSubView: Equatable {
    case main
    case lowBatteryAlerts
}

// MARK: - Settings Sync Modifier

struct SettingsForwardSyncModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var soundEnabled: Bool
    @Binding var chargeLimitEnabled: Bool
    @Binding var chargeLimitPercent: Double
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
            .onChange(of: self.chargeLimitEnabled) { _, new in
                guard self.isLoaded else { return }
                self.settings.chargeLimitEnabled = new
            }
            .onChange(of: self.chargeLimitPercent) { _, new in
                guard self.isLoaded else { return }
                self.settings.chargeLimitPercent = Int(new)
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

struct SettingsReverseSyncChargeLimitModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var chargeLimitEnabled: Bool
    @Binding var chargeLimitPercent: Double

    func body(content: Content) -> some View {
        content
            .onChange(of: self.env.settings.chargeLimitEnabled) { _, new in
                self.chargeLimitEnabled = new
            }
            .onChange(of: self.env.settings.chargeLimitPercent) { _, new in
                self.chargeLimitPercent = Double(new)
            }
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

// MARK: - Keep Awake Sync Modifiers

struct KeepAwakeForwardSyncModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var keepAwakeEnabled: Bool
    @Binding var keepAwakeDuration: KeepAwakeDuration
    @Binding var isLoaded: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: self.keepAwakeEnabled) { _, new in
                guard self.isLoaded else { return }
                if new {
                    self.env.keepAwake.activate()
                } else {
                    self.env.keepAwake.deactivate()
                }
            }
            .onChange(of: self.keepAwakeDuration) { _, new in
                guard self.isLoaded else { return }
                self.env.keepAwake.duration = new
            }
    }
}

struct KeepAwakeReverseSyncModifier: ViewModifier {
    @Environment(AppEnvironment.self) private var env
    @Binding var keepAwakeEnabled: Bool
    @Binding var keepAwakeDuration: KeepAwakeDuration

    func body(content: Content) -> some View {
        content
            .onChange(of: self.env.keepAwake.isActive) { _, new in
                self.keepAwakeEnabled = new
            }
            .onChange(of: self.env.keepAwake.duration) { _, new in
                self.keepAwakeDuration = new
            }
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

    @State private var settingsSubView: SettingsSubView = .main
    @State private var soundEnabled: Bool = false
    @State private var chargeLimitEnabled: Bool = false
    @State private var chargeLimitPercent: Double = 80
    @State private var showChargeLimitInfo: Bool = false
    @State private var pinEnabled: Bool = false
    @State private var launchAtLogin: Bool = false
    @State private var powerSaveEnabled: Bool = false
    @State private var keepAwakeEnabled: Bool = false
    @State private var keepAwakeDuration: KeepAwakeDuration = .thirtyMinutes
    @State private var selectedDisplay: SettingsDisplayType = .percent
    @State private var selectedPosition: WindowPosition = .topMiddle
    @State private var didLoad: Bool = false

    var body: some View {
        Group {
            switch self.settingsSubView {
            case .main:
                self.settingsContent
                    .transition(self.reduceMotion ? .identity : .move(edge: .leading))
            case .lowBatteryAlerts:
                LowBatteryAlertsView {
                    withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
                        self.settingsSubView = .main
                    }
                }
                .transition(self.reduceMotion ? .identity : .move(edge: .trailing))
            }
        }
        .onAppear { self.loadSettings() }
        .modifier(SettingsForwardSyncModifier(
            soundEnabled: self.$soundEnabled,
            chargeLimitEnabled: self.$chargeLimitEnabled,
            chargeLimitPercent: self.$chargeLimitPercent,
            pinEnabled: self.$pinEnabled,
            launchAtLogin: self.$launchAtLogin,
            powerSaveEnabled: self.$powerSaveEnabled,
            selectedDisplay: self.$selectedDisplay,
            selectedPosition: self.$selectedPosition,
            isLoaded: self.$didLoad
        ))
        .modifier(SettingsReverseSyncSoundModifier(soundEnabled: self.$soundEnabled))
        .modifier(SettingsReverseSyncChargeLimitModifier(
            chargeLimitEnabled: self.$chargeLimitEnabled,
            chargeLimitPercent: self.$chargeLimitPercent
        ))
        .modifier(SettingsReverseSyncPinModifier(pinEnabled: self.$pinEnabled))
        .modifier(SettingsReverseSyncDisplayModifier(selectedDisplay: self.$selectedDisplay))
        .modifier(KeepAwakeForwardSyncModifier(
            keepAwakeEnabled: self.$keepAwakeEnabled,
            keepAwakeDuration: self.$keepAwakeDuration,
            isLoaded: self.$didLoad
        ))
        .modifier(KeepAwakeReverseSyncModifier(
            keepAwakeEnabled: self.$keepAwakeEnabled,
            keepAwakeDuration: self.$keepAwakeDuration
        ))
    }

    private var settingsContent: some View {
        VStack(spacing: Spacing.md) {
            self.displaySection
            self.alertsSection
            self.chargingSection
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

    private var alertsDisclosureSubtitle: String {
        let thresholds = self.env.settings.alertThresholds.sorted()
        let percentList = thresholds.map { "\($0)%" }.joined(separator: ", ")
        let count = thresholds.count
        return "SettingsAlertsDisclosureSubtitle".localise([count]) + percentList
    }

    private var alertsSection: some View {
        SettingsSection(header: "SettingsAlertsHeader".localise()) {
            SettingsToggleRow(
                icon: "speaker.wave.2.fill",
                title: "SettingsSoundEffectsLabel".localise(),
                isOn: self.$soundEnabled
            )
            SettingsDivider()
            SettingsDisclosureRow(
                icon: "battery.25percent",
                title: "SettingsLowBatteryAlertsLabel".localise(),
                subtitle: self.alertsDisclosureSubtitle,
                action: {
                    withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
                        self.settingsSubView = .lowBatteryAlerts
                    }
                }
            )
        }
    }

    private var chargingSection: some View {
        SettingsSection(header: "SettingsChargingHeader".localise()) {
            SettingsToggleRow(
                icon: "battery.100percent.bolt",
                title: "SettingsChargeLimitLabel".localise(),
                isOn: self.$chargeLimitEnabled,
                accentColor: .orange
            )
            if self.chargeLimitEnabled {
                SettingsDivider()
                VStack(spacing: Spacing.smd) {
                    HStack(spacing: Spacing.sm) {
                        Button {
                            self.showChargeLimitInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Color("BBSubtitle").opacity(0.35))
                        }
                        .buttonStyle(HoverButtonStyle())
                        .popover(isPresented: self.$showChargeLimitInfo, arrowEdge: .bottom) {
                            self.chargeLimitInfoContent
                        }

                        Text("SettingsChargeLimitStopAt".localise())
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBSubtitle"))

                        Text("\(Int(self.chargeLimitPercent))%")
                            .font(Typography.heading)
                            .foregroundStyle(.orange)
                            .contentTransition(.numericText())
                            .padding(.horizontal, Spacing.xsm)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(Color.orange.opacity(0.12))
                            )

                        Spacer()
                    }

                    VStack(spacing: Spacing.xs) {
                        Slider(
                            value: self.$chargeLimitPercent,
                            in: 60 ... 100,
                            step: 5
                        )
                        .tint(.orange)

                        HStack {
                            Text("60%")
                                .font(Typography.caption)
                                .foregroundStyle(Color("BBSubtitle").opacity(0.4))
                            Spacer()
                            Text("100%")
                                .font(Typography.caption)
                                .foregroundStyle(Color("BBSubtitle").opacity(0.4))
                        }
                    }

                    ChargeLimitContextBar(
                        currentPercent: self.env.battery.percentage,
                        chargeLimit: Int(self.chargeLimitPercent),
                        isCharging: self.env.battery.charging.state == .charging
                    )
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.smd)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.chargeLimitEnabled)
    }

    private var chargeLimitInfoContent: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("SettingsChargeLimitInfoTitle".localise())
                .font(Typography.heading)
                .foregroundStyle(Color("BBTitle"))

            Text("SettingsChargeLimitInfoBody".localise([Int(self.chargeLimitPercent)]))
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(width: 240)
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
            SettingsDivider()
            SettingsToggleRow(
                icon: "cup.and.saucer.fill",
                title: "KeepAwakeLabel".localise(),
                isOn: self.$keepAwakeEnabled,
                subtitle: "KeepAwakeSubtitle".localise(),
                accentColor: .orange
            )
            .accessibilityLabel("AccessibilityKeepAwakeToggle".localise())
            if self.keepAwakeEnabled {
                SettingsDivider()
                SettingsPickerRow(
                    icon: "timer",
                    title: "KeepAwakeDurationLabel".localise(),
                    selection: self.$keepAwakeDuration,
                    options: KeepAwakeDuration.allCases.map { ($0, $0.displayName) }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            if self.keepAwakeEnabled {
                self.keepAwakeStatusRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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

    private var keepAwakeStatusRow: some View {
        HStack(spacing: Spacing.sm) {
            if let formatted = self.env.keepAwake.remainingFormatted {
                Text(formatted)
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
                    .contentTransition(.numericText())
            }
            Spacer()
            if self.env.battery.charging.state == .battery {
                Label {
                    Text("KeepAwakeBatteryWarningSubtitle".localise())
                        .font(Typography.caption)
                } icon: {
                    Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                        .font(.system(size: 10))
                }
                .foregroundStyle(.orange)
            }
            if self.env.settings.enabledPowerSave {
                Label {
                    Text("KeepAwakePowerSaveConflictSubtitle".localise())
                        .font(Typography.caption)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                }
                .foregroundStyle(Color("BBSubtitle"))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
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
            self.chargeLimitEnabled = self.settings.chargeLimitEnabled
            self.chargeLimitPercent = Double(self.settings.chargeLimitPercent)
            self.pinEnabled = self.settings.pinned == .enabled
            self.launchAtLogin = self.settings.autoLaunch == .enabled
            self.powerSaveEnabled = self.settings.enabledPowerSave
            self.keepAwakeEnabled = self.env.keepAwake.isActive
            self.keepAwakeDuration = self.env.keepAwake.duration
            self.selectedDisplay = self.settings.display
            self.selectedPosition = self.window.position
            self.didLoad = true
        }
    }
}

// MARK: - Charge Limit Context Bar

private struct ChargeLimitContextBar: View {
    let currentPercent: Double
    let chargeLimit: Int
    let isCharging: Bool

    private let barHeight: CGFloat = 6
    private let notchOvershoot: CGFloat = 4

    private var tier: BatteryTier {
        BatteryTier(percent: self.currentPercent)
    }

    private var normalizedCurrent: CGFloat {
        max(0, min(CGFloat(self.currentPercent) / 100.0, 1.0))
    }

    private var normalizedLimit: CGFloat {
        max(0, min(CGFloat(self.chargeLimit) / 100.0, 1.0))
    }

    private var isOverLimit: Bool {
        self.currentPercent >= Double(self.chargeLimit)
    }

    var body: some View {
        VStack(spacing: Spacing.xsm) {
            GeometryReader { geo in
                let barWidth = geo.size.width
                let limitX = self.normalizedLimit * barWidth
                let currentWidth = self.normalizedCurrent * barWidth
                let notchHeight = self.barHeight + (self.notchOvershoot * 2)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: self.barHeight / 2)
                        .fill(BatteryTier.trackColor)
                        .frame(height: self.barHeight)

                    if self.currentPercent > 0 {
                        if self.isOverLimit {
                            RoundedRectangle(cornerRadius: self.barHeight / 2)
                                .fill(LinearGradient(
                                    colors: self.tier.gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(
                                    width: max(self.barHeight, min(limitX, barWidth)),
                                    height: self.barHeight
                                )

                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 0,
                                bottomTrailingRadius: self.barHeight / 2,
                                topTrailingRadius: self.barHeight / 2
                            )
                            .fill(Color.orange.opacity(0.25))
                            .frame(
                                width: max(0, currentWidth - limitX),
                                height: self.barHeight
                            )
                            .offset(x: limitX)
                        } else {
                            RoundedRectangle(cornerRadius: self.barHeight / 2)
                                .fill(LinearGradient(
                                    colors: self.tier.gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                                .frame(
                                    width: max(self.barHeight, min(currentWidth, barWidth)),
                                    height: self.barHeight
                                )
                        }
                    }

                    if self.chargeLimit < 100 {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.orange)
                            .frame(width: 2.5, height: notchHeight)
                            .shadow(color: .orange.opacity(0.4), radius: 3, x: 0, y: 0)
                            .position(x: limitX, y: notchHeight / 2)
                    }
                }
                .frame(height: notchHeight)
            }
            .frame(height: self.barHeight + (self.notchOvershoot * 2))

            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(self.tier.dotColor)
                    .frame(width: 6, height: 6)

                Text("\(Int(self.currentPercent))%")
                    .font(Typography.small)
                    .foregroundStyle(Color("BBTitle"))
                    .contentTransition(.numericText())

                Text("·")
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle").opacity(0.4))

                Text(self.isCharging
                    ? "DashboardChargingLabel".localise()
                    : "DashboardOnBatteryLabel".localise())
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))

                Spacer()

                if self.isOverLimit {
                    Text("SettingsChargeLimitAboveLabel".localise())
                        .font(Typography.caption)
                        .foregroundStyle(Color.orange.opacity(0.7))
                }
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .animation(.easeInOut(duration: 0.3), value: self.chargeLimit)
        .animation(.easeInOut(duration: 0.5), value: self.currentPercent)
    }
}
