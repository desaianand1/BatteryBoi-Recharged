import SwiftUI

struct AboutTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    private var updates: any UpdateManagerProtocol {
        self.env.update
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            self.appIdentitySection

            if self.env.app.appDeviceType.battery || self.battery.metrics != nil {
                self.batterySummaryCard
            }

            self.linksSection

            #if DIRECT_DISTRIBUTION
                self.updateSection
            #endif

            self.creditsFooter
        }
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - App Identity

    private var appIdentitySection: some View {
        HStack(spacing: Spacing.md) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("AboutAppName".localise())
                    .font(Typography.titleBold)
                    .foregroundStyle(Color("BBTitle"))

                Text(self.updates.versionDisplay)
                    .font(Typography.caption)
                    .foregroundStyle(Color("BBSubtitle"))
            }
        }
    }

    // MARK: - Battery Summary

    private var batterySummaryCard: some View {
        let healthPct = self.battery.metrics?.healthPercent
        let cycles = self.battery.metrics?.cycles
        let tier = BatteryTier(percent: healthPct ?? 100)

        return SettingsSection {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.md) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(tier.dotColor)
                        Text(healthPct.map { "AboutHealthLabel".localise([Int($0)]) } ?? "—")
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBTitle"))
                    }

                    Spacer()

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                            .foregroundStyle(Color("BBSubtitle"))
                        Text(cycles.map { "AboutCyclesLabel".localise([$0.numerical]) } ?? "—")
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBTitle"))
                    }
                }

                Text(self.batterySummaryAdvisory(healthPct))
                    .font(Typography.body)
                    .foregroundStyle(self.batterySummaryColor(healthPct))
            }
            .padding(Spacing.md)
        }
    }

    private func batterySummaryAdvisory(_ healthPct: Double?) -> String {
        guard let pct = healthPct else {
            return "AboutBatterySummaryUnavailable".localise()
        }
        if pct >= 90 {
            return "AboutBatterySummaryGreat".localise()
        }
        if pct >= 80 {
            return "AboutBatterySummaryNormal".localise()
        }
        if pct >= 70 {
            return "AboutBatterySummaryFair".localise()
        }
        return "AboutBatterySummaryPoor".localise()
    }

    private func batterySummaryColor(_ healthPct: Double?) -> Color {
        guard let pct = healthPct else { return Color("BBSubtitle") }
        if pct >= 80 {
            return Color("BBSubtitle")
        }
        if pct >= 70 {
            return SemanticColor.warning
        }
        return SemanticColor.error
    }

    // MARK: - Links

    private var linksSection: some View {
        SettingsSection(header: "AboutLinksHeader".localise()) {
            SettingsDisclosureRow(
                icon: "globe",
                title: "AboutWebsiteLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("GITHUB_REPO_URL") }

            SettingsDivider()

            SettingsDisclosureRow(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "AboutGitHubLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("GITHUB_REPO_URL") }

            SettingsDivider()

            SettingsDisclosureRow(
                icon: "star.fill",
                title: "AboutRateLabel".localise(),
                subtitle: ""
            ) { self.env.settings.performAction(.init(.appRate)) }

            SettingsDivider()

            SettingsDisclosureRow(
                icon: "cup.and.saucer.fill",
                title: "AboutBuyMeCoffeeLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("DONATE_BUYMEACOFFEE_URL") }

            SettingsDivider()

            SettingsDisclosureRow(
                icon: "heart.fill",
                title: "AboutKoFiLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("DONATE_KOFI_URL") }
        }
    }

    // MARK: - Update Section

    #if DIRECT_DISTRIBUTION
        private var updateSection: some View {
            SettingsSection {
                Button {
                    self.updates.updateCheck()
                } label: {
                    HStack(spacing: Spacing.smd) {
                        SettingsRowIcon(systemName: "arrow.triangle.2.circlepath")

                        Text("AboutCheckUpdatesLabel".localise())
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBTitle"))

                        Spacer()

                        if self.updates.state == .checking {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Text(self.updates.versionDisplay)
                                .font(Typography.caption)
                                .foregroundStyle(Color("BBSubtitle"))
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.smd)
                    .contentShape(Rectangle())
                }
                .buttonStyle(HoverButtonStyle())
                .disabled(self.updates.state == .checking)
            }
        }
    #endif

    // MARK: - Credits

    private var creditsFooter: some View {
        VStack(alignment: .center, spacing: Spacing.xs) {
            Text("AboutCreditsOriginal".localise())
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))

            Text("AboutBodyFooter".localise())
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Helpers

    private func openInfoPlistURL(_ key: String) {
        guard let str = Bundle.main.infoDictionary?[key] as? String,
              !str.isEmpty, let url = URL(string: str)
        else { return }
        NSWorkspace.shared.open(url)
    }
}

typealias AboutContainer = AboutTabView
