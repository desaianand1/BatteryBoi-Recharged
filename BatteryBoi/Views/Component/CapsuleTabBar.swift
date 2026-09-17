import SwiftUI

enum ExpandedTab: String, CaseIterable, Identifiable {
    case devices, settings, about

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .devices: "SettingsDevicesLabel".localise()
        case .settings: "SettingsSettingsLabel".localise()
        case .about: "SettingsAboutLabel".localise()
        }
    }

    var icon: String {
        switch self {
        case .devices: "macbook.and.iphone"
        case .settings: "gearshape.fill"
        case .about: "info.circle"
        }
    }
}

struct CapsuleTabBar: View {
    @Binding var selection: ExpandedTab
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabNamespace
    @State private var bounceCounter: [ExpandedTab: Int] = [:]

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(ExpandedTab.allCases) { tab in
                Button {
                    self.bounceCounter[tab, default: 0] += 1
                    self.selection = tab
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if self.reduceMotion {
                            Image(systemName: tab.icon)
                                .symbolRenderingMode(.hierarchical)
                        } else {
                            Image(systemName: tab.icon)
                                .symbolRenderingMode(.hierarchical)
                                .symbolEffect(.bounce, value: self.bounceCounter[tab, default: 0])
                        }

                        Text(tab.label)
                    }
                    .font(Typography.heading)
                    .foregroundStyle(self.selection == tab ? Color("BBTitle") : Color("BBSubtitle").opacity(0.6))
                    .padding(.horizontal, Spacing.smd)
                    .padding(.vertical, Spacing.sm)
                    .background {
                        if self.selection == tab {
                            Capsule()
                                .fill(Color("BBSurface"))
                                .matchedGeometryEffect(id: "tabIndicator", in: self.tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(self.selection == tab ? [.isSelected, .isButton] : .isButton)
            }
        }
        .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tab bar")
    }
}
