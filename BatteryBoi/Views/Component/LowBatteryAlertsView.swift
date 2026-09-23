import SwiftUI

// MARK: - Low Battery Alerts View

struct LowBatteryAlertsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onBack: () -> Void

    @State private var thresholds: [Int] = []
    @State private var isAddingAlert: Bool = false
    @State private var newAlertValue: Int = 5
    @State private var testPreview: AlertThresholdItem?
    @State private var testPreviewTask: Task<Void, Never>?

    private var sortedItems: [AlertThresholdItem] {
        self.thresholds.sorted().map { AlertThresholdItem(percent: $0) }
    }

    private var canAddMore: Bool {
        self.thresholds.count < Constants.BatteryThresholds.alertCountMax
    }

    private var isDuplicate: Bool {
        self.thresholds.contains(self.newAlertValue)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                self.headerRow
                self.testPreviewBanner
                self.descriptionRow
                self.alertCardsList
                self.addAlertSection
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

    // MARK: - Test Preview Banner

    @ViewBuilder
    private var testPreviewBanner: some View {
        if let preview = self.testPreview {
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(preview.tier.dotColor)
                    .frame(width: 6, height: 6)

                Text("\"\(preview.subtitle)\"")
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBTitle"))
            }
            .padding(.horizontal, Spacing.smd)
            .padding(.vertical, Spacing.xsm)
            .background(
                Capsule()
                    .fill(preview.tier.dotColor.opacity(0.1))
            )
            .transition(.opacity)
        }
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
                    onTest: { self.showTestPreview(for: item) },
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
                Text("SettingsAlertDuplicate".localise())
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
            }

            Button {
                self.addThreshold(self.newAlertValue)
            } label: {
                Text("SettingsAlertAddLabel".localise())
                    .font(Typography.caption)
                    .foregroundStyle(Color.accentColor)
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
                    .foregroundStyle(Color("BBSubtitle"))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
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

    private func showTestPreview(for item: AlertThresholdItem) {
        self.testPreviewTask?.cancel()
        withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
            self.testPreview = item
        }
        HapticUtility.toggle()
        self.testPreviewTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            withAnimation(DesignAnimation.easeOut(reduceMotion: self.reduceMotion)) {
                self.testPreview = nil
            }
        }
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
    let onTest: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.smd) {
            Circle()
                .fill(self.item.tier.dotColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text("\(self.item.percent)%")
                        .font(Typography.heading)
                        .foregroundStyle(Color("BBTitle"))

                    Text(self.item.tier.label)
                        .font(Typography.caption)
                        .foregroundStyle(Color("BBSubtitle"))
                }

                Text("\"\(self.item.subtitle)\"")
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
            }

            Spacer()

            if self.item.isRemovable {
                Button(action: self.onTest) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 8))
                        Text("SettingsAlertTestLabel".localise())
                            .font(Typography.caption)
                    }
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Button(action: self.onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color("BBSubtitle"))
                }
                .buttonStyle(.plain)
            } else {
                Text("SettingsAlertAlwaysOnLabel".localise())
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
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
