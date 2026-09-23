import SwiftUI

// MARK: - Low Battery Alerts View

struct LowBatteryAlertsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onBack: () -> Void

    @State private var thresholds: [Int] = []
    @State private var isAddingAlert: Bool = false
    @State private var newAlertValue: Int = 5

    private var sortedItems: [AlertThresholdItem] {
        self.thresholds.sorted().map { AlertThresholdItem(percent: $0) }
    }

    private var canAddMore: Bool {
        self.thresholds.count < Constants.BatteryThresholds.alertCountMax
    }

    private var isDefault: Bool {
        Set(self.thresholds) == Set(Constants.BatteryThresholds.defaultAlerts)
    }

    private var isDuplicate: Bool {
        self.thresholds.contains(self.newAlertValue)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                self.headerRow
                self.descriptionRow
                self.alertCardsList
                self.addAlertSection
                self.resetButton
            }
            .padding(.bottom, Spacing.lg)
        }
        .onAppear {
            self.thresholds = self.env.settings.alertThresholds
        }
        .onKeyPress(.escape) {
            self.onBack()
            return .handled
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                self.onBack()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                    Text("SettingsLowBatteryAlertsLabel".localise())
                        .font(Typography.heading)
                }
                .foregroundStyle(Color("BBTitle"))
            }
            .buttonStyle(HoverButtonStyle())

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Description

    private var descriptionRow: some View {
        Text("SettingsAlertDescription".localise())
            .font(Typography.caption)
            .foregroundStyle(Color("BBSubtitle"))
            .padding(.horizontal, Spacing.md)
    }

    // MARK: - Alert Cards List

    private var alertCardsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(self.sortedItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    SettingsDivider()
                }
                AlertCardRow(
                    item: item,
                    onRemove: { self.removeThreshold(item.percent) }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .surfaceCard()
        .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.thresholds)
    }

    // MARK: - Add Alert Section

    private var addAlertSection: some View {
        VStack(spacing: 0) {
            if self.isAddingAlert {
                self.addAlertStepperRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
                        self.advanceToNextAvailable()
                        self.isAddingAlert = true
                    }
                } label: {
                    HStack(spacing: Spacing.smd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.accentColor)

                        Text("SettingsAlertAddLabel".localise())
                            .font(Typography.heading)
                            .foregroundStyle(Color.accentColor)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.smd)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
                .disabled(!self.canAddMore)
            }

            if !self.canAddMore, !self.isAddingAlert {
                Text("SettingsAlertMaxReached".localise())
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
                    .padding(.horizontal, Spacing.md)
                    .padding(.bottom, Spacing.smd)
            }
        }
        .surfaceCard()
        .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.isAddingAlert)
    }

    private var addAlertStepperRow: some View {
        HStack(spacing: Spacing.smd) {
            Text("\(self.newAlertValue)%")
                .font(Typography.heading)
                .foregroundStyle(Color("BBTitle"))
                .contentTransition(.numericText())
                .frame(width: 40, alignment: .leading)

            Stepper(
                "",
                value: self.$newAlertValue,
                in: Constants.BatteryThresholds.alertMin ... Constants.BatteryThresholds.alertMax,
                step: Constants.BatteryThresholds.alertStep
            )
            .labelsHidden()

            Spacer()

            if self.isDuplicate {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                    Text("SettingsAlertDuplicate".localise())
                        .font(Typography.caption)
                }
                .foregroundStyle(SemanticColor.warning)
            }

            Button {
                self.addThreshold(self.newAlertValue)
            } label: {
                Text("SettingsAlertAddLabel".localise())
                    .font(Typography.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(self.isDuplicate ? Color("BBSubtitle") : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(self.isDuplicate || !self.canAddMore)

            Button {
                withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
                    self.isAddingAlert = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color("BBSubtitle").opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
    }

    // MARK: - Reset Button

    @ViewBuilder
    private var resetButton: some View {
        if !self.isDefault {
            Button {
                self.resetToDefaults()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .medium))
                    Text("SettingsAlertResetLabel".localise())
                        .font(Typography.caption)
                }
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))
            }
            .buttonStyle(HoverButtonStyle())
            .transition(.opacity)
        }
    }

    // MARK: - Actions

    private func addThreshold(_ value: Int) {
        guard !self.thresholds.contains(value) else { return }
        withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
            self.thresholds.append(value)
            self.env.settings.alertThresholds = self.thresholds
        }
        HapticUtility.toggle()
        self.advanceToNextAvailable()
    }

    private func removeThreshold(_ value: Int) {
        guard value != 1 else { return }
        withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
            self.thresholds.removeAll { $0 == value }
            self.env.settings.alertThresholds = self.thresholds
        }
        HapticUtility.toggle()
    }

    private func resetToDefaults() {
        withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
            self.thresholds = Constants.BatteryThresholds.defaultAlerts
            self.env.settings.alertThresholds = self.thresholds
            self.isAddingAlert = false
        }
        HapticUtility.toggle()
    }

    private func advanceToNextAvailable() {
        let step = Constants.BatteryThresholds.alertStep
        let min = Constants.BatteryThresholds.alertMin
        let max = Constants.BatteryThresholds.alertMax
        var candidate = min
        while candidate <= max {
            if !self.thresholds.contains(candidate) {
                self.newAlertValue = candidate
                return
            }
            candidate += step
        }
        self.newAlertValue = min
    }
}

// MARK: - Alert Card Row

private struct AlertCardRow: View {
    let item: AlertThresholdItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.smd) {
            Circle()
                .fill(self.item.tier.dotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                    Text("\(self.item.percent)%")
                        .font(Typography.heading)
                        .foregroundStyle(Color("BBTitle"))

                    Text(self.item.tier.label)
                        .font(Typography.caption)
                        .foregroundStyle(self.item.tier.dotColor.opacity(0.8))
                }

                Text(self.item.subtitle)
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle").opacity(0.7))
            }

            Spacer()

            if self.item.isRemovable {
                Button(action: self.onRemove) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("BBSubtitle").opacity(0.4))
                }
                .buttonStyle(HoverButtonStyle())
            } else {
                Text("SettingsAlertAlwaysOnLabel".localise())
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle").opacity(0.5))
                    .padding(.horizontal, Spacing.xsm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule().fill(Color("BBSubtitle").opacity(0.08))
                    )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
        .contentShape(Rectangle())
        .settingsRowHover()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.item.percent) percent, \(self.item.tier.label)")
    }
}
