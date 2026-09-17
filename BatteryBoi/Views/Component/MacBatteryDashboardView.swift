import SwiftUI

struct MacBatteryDashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onBack: () -> Void

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    private var metrics: BatteryMetricsObject? {
        self.battery.metrics
    }

    private var hasBattery: Bool {
        self.env.app.appDeviceType.battery || self.battery.metrics != nil
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                self.backButton

                if self.hasBattery {
                    self.dashboardContent
                } else {
                    self.noBatteryView
                }
            }
            .padding(.bottom, Spacing.md)
        }
    }

    // MARK: - Back Button

    private var backButton: some View {
        Button(action: self.onBack) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "chevron.left")
                Text("DeviceDetailBackLabel".localise())
            }
            .font(Typography.heading)
            .foregroundStyle(Color("BBSubtitle"))
        }
        .buttonStyle(HoverButtonStyle())
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            self.compactHero
            self.healthCard
            self.metricsSection
            self.batterySettingsLink
        }
    }

    // MARK: - Compact Hero

    private var compactHero: some View {
        HStack {
            Text("\(Int(self.battery.percentage))%")
                .font(Typography.largeTitle)
                .foregroundStyle(Color("BBTitle"))
                .contentTransition(.numericText())
                .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.battery.percentage)

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                self.chargingStateRow

                if let timeText = self.timeEstimateText {
                    Text(timeText)
                        .font(Typography.body)
                        .foregroundStyle(Color("BBSubtitle"))
                }
            }
        }
        .padding(Spacing.md)
        .surfaceCard()
    }

    private var chargingStateRow: some View {
        HStack(spacing: Spacing.xs) {
            if self.battery.charging.state == .charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(BatteryTier.chargingBoltColor)
                    .applySymbolEffect(.pulse)
                Text("DashboardChargingLabel".localise())
            } else if self.battery.percentage >= 100 {
                Text("DashboardFullyChargedLabel".localise())
            } else {
                Image(systemName: "battery.100percent")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color("BBSubtitle"))
                Text("DashboardOnBatteryLabel".localise())
            }
        }
        .font(Typography.heading)
        .foregroundStyle(Color("BBSubtitle"))
        .applySymbolReplaceTransition()
    }

    private var timeEstimateText: String? {
        if self.battery.charging.state == .charging {
            if let fullDate = self.battery.untilFull {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "DashboardFullAtLabel".localise([formatter.string(from: fullDate)])
            }
            return "DashboardCalculatingLabel".localise()
        } else if self.battery.percentage < 100 {
            if let remaining = self.battery.remaining?.formatted {
                return "DashboardRemainingLabel".localise([remaining])
            }
            return "DashboardCalculatingLabel".localise()
        }
        return nil
    }

    // MARK: - Health Card

    private var healthCard: some View {
        let healthPct = self.metrics?.healthPercent
        let tier = BatteryTier(percent: healthPct ?? 100)

        return VStack(alignment: .leading, spacing: Spacing.smd) {
            HStack {
                Image(systemName: "heart.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(tier.dotColor)

                Text(healthPct.map { String(format: "%.0f%%", $0) } ?? "—")
                    .font(Typography.title)
                    .foregroundStyle(tier.dotColor)

                Text(self.metrics?.health.displayName ?? "DashboardUnavailableValue".localise())
                    .font(Typography.body)
                    .foregroundStyle(Color("BBSubtitle"))

                Spacer()

                Text("\(self.metrics?.cycles.formatted ?? "—") / 1,000 \("DashboardCyclesLowercaseSuffix".localise())")
                    .font(Typography.body)
                    .foregroundStyle(Color("BBSubtitle"))
            }

            if let effectiveCap = self.metrics?.effectiveMaxCapacityMAh,
               let designCap = self.metrics?.designCapacity, designCap > 0
            {
                let barFraction = min(Double(effectiveCap) / Double(designCap), 1.0)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color("BBSubtitle").opacity(0.10))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: tier.gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * barFraction)
                            .animation(.spring, value: healthPct)
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
            }

            Text(self.metrics?.capacityFormatted ?? "—")
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle"))

            if let pct = healthPct, pct < 80, self.metrics?.health != .optimal {
                self.healthAdvisory(healthPercent: pct)
            }
        }
        .padding(Spacing.md)
        .surfaceCard()
    }

    @ViewBuilder
    private func healthAdvisory(healthPercent: Double) -> some View {
        let isError = healthPercent < 70
        let color = isError ? SemanticColor.error : SemanticColor.warning
        let text = isError
            ? "DashboardHealthAdvisoryRed".localise()
            : "DashboardHealthAdvisoryAmber".localise()

        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(color)
                .applySymbolEffect(.pulse)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(color)
        }
        .transition(
            self.reduceMotion
                ? .opacity
                : .opacity.combined(with: .slide)
        )
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("DashboardMetricsSectionHeader".localise())
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle"))
                .tracking(0.5)

            VStack(spacing: 0) {
                self.powerRow
                SettingsDivider()
                self.temperatureRow
                SettingsDivider()
                self.voltageRow
                SettingsDivider()
                self.currentRow
                SettingsDivider()
                self.sourceRow

                if self.env.settings.chargeEighty == .enabled {
                    SettingsDivider()
                    self.chargeLimitRow
                }
            }
            .padding(.vertical, Spacing.smd)
            .surfaceCard()
        }
    }

    private var isCharging: Bool {
        self.battery.charging.state == .charging
    }

    private var powerRow: some View {
        self.metricRow(
            icon: "bolt.fill",
            iconColor: .accentColor,
            label: self.isCharging
                ? "DashboardChargingPowerLabel".localise()
                : "DashboardPowerLabel".localise(),
            value: self.metrics?.powerFormatted ?? "—",
            status: self.metrics?.powerStatusForState(isCharging: self.isCharging)
        )
    }

    private var temperatureRow: some View {
        self.metricRow(
            icon: self.thermometerIcon,
            iconColor: self.metrics?.temperatureStatus?.color ?? Color("BBSubtitle"),
            label: "DashboardTemperatureLabel".localise(),
            value: self.metrics?.temperatureFormatted ?? "—",
            status: self.metrics?.temperatureStatus
        )
    }

    private var voltageRow: some View {
        self.metricRow(
            icon: "bolt.circle",
            label: "DashboardVoltageLabel".localise(),
            value: self.metrics?.voltageFormatted ?? "—"
        )
    }

    private var currentRow: some View {
        self.metricRow(
            icon: self.metrics?.isDischarging ?? true ? "arrow.down.circle" : "arrow.up.circle",
            iconColor: self.metrics?.amperageColor ?? Color("BBSubtitle"),
            label: "DashboardCurrentLabel".localise(),
            value: self.metrics?.amperageFormatted ?? "—",
            valueColor: self.metrics?.amperageColor ?? Color("BBTitle")
        )
    }

    private var sourceRow: some View {
        self.metricRow(
            icon: self.battery.charging.state == .charging ? "powerplug" : "battery.100percent",
            label: "DashboardPowerSourceLabel".localise(),
            value: self.battery.charging.state == .charging
                ? "DashboardACPowerLabel".localise()
                : "DashboardBatteryPowerLabel".localise()
        )
    }

    private var chargeLimitRow: some View {
        self.metricRow(
            icon: "bolt.badge.checkmark",
            label: "DashboardChargeLimitLabel".localise(),
            value: "\(Constants.BatteryThresholds.chargeLimit)%"
        )
    }

    // MARK: - Metric Row

    private func metricRow(
        icon: String,
        iconColor: Color = Color("BBSubtitle"),
        label: String,
        value: String,
        valueColor: Color = Color("BBTitle"),
        status: (label: String, color: Color)? = nil
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 18, alignment: .center)
                .applySymbolReplaceTransition()
                .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: icon)

            Text(label)
                .font(Typography.heading)
                .foregroundStyle(Color("BBSubtitle"))

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xxs) {
                Text(value)
                    .font(Typography.headingLarge)
                    .foregroundStyle(valueColor)

                if let status {
                    Text(status.label)
                        .font(Typography.caption)
                        .foregroundStyle(status.color)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Battery Settings Link

    private var batterySettingsLink: some View {
        SettingsDisclosureRow(
            icon: "battery.100percent",
            title: "DashboardBatterySettingsLabel".localise(),
            subtitle: ""
        ) {
            let urlString = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13
                ? "x-apple.systempreferences:com.apple.Battery-Settings.extension"
                : "x-apple.systempreferences:com.apple.preference.battery"
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - No Battery View

    private var noBatteryView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: self.env.app.appDeviceType.icon)
                .font(.system(size: 48))
                .foregroundStyle(Color("BBSubtitle"))

            Text("DashboardNoBatteryTitle".localise())
                .font(Typography.heading)
                .foregroundStyle(Color("BBSubtitle"))

            Text("DashboardNoBatteryBody".localise())
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .surfaceCard()
    }

    // MARK: - Helpers

    private var thermometerIcon: String {
        guard let t = self.metrics?.temperature else { return "thermometer.medium" }
        if t < 35 {
            return "thermometer.low"
        }
        if t <= 45 {
            return "thermometer.medium"
        }
        return "thermometer.high"
    }
}
