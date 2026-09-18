import SwiftUI

enum BatteryDisplayHelpers {

    static func batterySummaryAdvisory(_ healthPct: Double?) -> String {
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

    static func batterySummaryColor(_ healthPct: Double?) -> Color {
        guard let pct = healthPct else { return Color("BBSubtitle") }
        if pct >= 80 {
            return Color("BBSubtitle")
        }
        if pct >= 70 {
            return SemanticColor.warning
        }
        return SemanticColor.error
    }

    static func thermometerIcon(for temperature: Double?) -> String {
        guard let t = temperature else { return "thermometer.medium" }
        if t < 35 {
            return "thermometer.low"
        }
        if t <= 45 {
            return "thermometer.medium"
        }
        return "thermometer.high"
    }

    static func macBatterySubtitle(
        percentage: Double,
        chargingState: BatteryChargingState,
        untilFull: Date?,
        remaining: BatteryRemaining?
    ) -> String {
        if percentage >= 100 {
            return "DashboardFullyChargedLabel".localise()
        }

        let stateLabel = chargingState == .charging
            ? "DashboardChargingLabel".localise()
            : "DashboardOnBatteryLabel".localise()

        if chargingState == .charging {
            if let fullDate = untilFull {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "\(stateLabel) · "
                    + "DashboardFullAtLabel".localise([formatter.string(from: fullDate)])
            }
        } else if let short = remaining?.formattedShort {
            return "\(stateLabel) · "
                + "DashboardRemainingLabel".localise([short])
        }

        return stateLabel
    }
}
