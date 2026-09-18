import SwiftUI

struct AboutTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var copiedFeedback: Bool = false

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

            self.linksCard

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

                Text(BatteryDisplayHelpers.batterySummaryAdvisory(healthPct))
                    .font(Typography.body)
                    .foregroundStyle(BatteryDisplayHelpers.batterySummaryColor(healthPct))
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Links Card

    private var linksCard: some View {
        SettingsSection {
            // Rate on App Store
            SettingsDisclosureRow(
                icon: "star.fill",
                title: "AboutRateLabel".localise(),
                subtitle: ""
            ) { self.env.settings.performAction(.init(.appRate)) }

            SettingsDivider()

            // Website
            SettingsDisclosureRow(
                icon: "globe",
                title: "AboutWebsiteLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("WEBSITE_URL") }

            SettingsDivider()

            // Source Code
            SettingsDisclosureRow(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "AboutSourceCodeLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("GITHUB_REPO_URL") }

            SettingsDivider()

            // Buy Me a Coffee
            SettingsDisclosureRow(
                icon: "cup.and.saucer.fill",
                title: "AboutBuyMeCoffeeLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("DONATE_BUYMEACOFFEE_URL") }

            SettingsDivider()

            // Ko-fi
            SettingsDisclosureRow(
                icon: "heart.fill",
                title: "AboutKoFiLabel".localise(),
                subtitle: ""
            ) { self.openInfoPlistURL("DONATE_KOFI_URL") }

            self.sectionDivider

            // Report an Issue
            self.reportIssueRow

            #if DIRECT_DISTRIBUTION
                SettingsDivider()
                self.checkForUpdatesRow
            #endif

            self.sectionDivider

            // Legal
            self.legalRow
        }
    }

    // MARK: - Report an Issue

    private var reportIssueRow: some View {
        Button {
            self.openInfoPlistURL("SUPPORT_ISSUES_URL")
        } label: {
            HStack(spacing: Spacing.smd) {
                SettingsRowIcon(systemName: "ladybug")

                Text("AboutReportIssueLabel".localise())
                    .font(Typography.heading)
                    .foregroundStyle(Color("BBTitle"))

                Spacer()

                Button {
                    self.copySystemInfo()
                } label: {
                    Image(systemName: self.copiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(self.copiedFeedback ? SemanticColor.success : Color("BBSubtitle"))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Copy system info")

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

    // MARK: - Check for Updates

    #if DIRECT_DISTRIBUTION
        private var checkForUpdatesRow: some View {
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color("BBSubtitle").opacity(0.5))
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.smd)
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverButtonStyle())
            .disabled(self.updates.state == .checking)
        }
    #endif

    // MARK: - Legal

    private var legalRow: some View {
        HStack(spacing: 0) {
            Spacer()
            Button("AboutPrivacyLabel".localise()) { self.openInfoPlistURL("PRIVACY_POLICY_URL") }
                .buttonStyle(.plain)
            Text(" · ")
            Button("AboutTermsLabel".localise()) { self.openInfoPlistURL("TERMS_URL") }
                .buttonStyle(.plain)
            Text(" · ")
            Button("AboutDataPolicyLabel".localise()) { self.openInfoPlistURL("DATA_POLICY_URL") }
                .buttonStyle(.plain)
            Spacer()
        }
        .font(Typography.caption)
        .foregroundStyle(Color("BBSubtitle"))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.smd)
    }

    // MARK: - Credits

    private var creditsFooter: some View {
        VStack(alignment: .center, spacing: Spacing.xs) {
            Button("AboutMadeByLabel".localise()) { self.openInfoPlistURL("DEV_WEBSITE_URL") }
                .buttonStyle(.plain)
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))

            Button("AboutCreditsOriginal".localise()) { self.openInfoPlistURL("ORIGINAL_AUTHOR_URL") }
                .buttonStyle(.plain)
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))

            Text("© \(Calendar.current.component(.year, from: Date())) Nirnshard")
                .font(Typography.caption)
                .foregroundStyle(Color("BBSubtitle").opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }

    // MARK: - Helpers

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color("BBSubtitle").opacity(0.15))
            .frame(height: 2)
    }

    private func openInfoPlistURL(_ key: String) {
        guard let str = Bundle.main.infoDictionary?[key] as? String,
              !str.isEmpty, let url = URL(string: str)
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func copySystemInfo() {
        let info = SystemInfoCollector.collect(
            battery: self.battery,
            bluetooth: self.env.bluetooth,
            app: self.env.app,
            update: self.updates
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(info, forType: .string)

        withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
            self.copiedFeedback = true
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(DesignAnimation.spring(reduceMotion: self.reduceMotion)) {
                self.copiedFeedback = false
            }
        }
    }
}

typealias AboutContainer = AboutTabView
