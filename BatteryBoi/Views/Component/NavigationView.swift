import SwiftUI

struct ExpandedPanelView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bluetooth: any BluetoothServiceProtocol {
        self.env.bluetooth
    }

    @State private var selectedDetail: BluetoothObject?
    @State private var showingDetail: Bool = false
    @State private var selectedTab: ExpandedTab = .devices

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color("BBSubtitle").opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, Spacing.lg)

            if self.showingDetail {
                DeviceDetailView(
                    device: self.selectedDetail,
                    onBack: {
                        if self.reduceMotion {
                            self.showingDetail = false
                        } else {
                            withAnimation(.easeOut(duration: RevealTiming.collapseDuration)) {
                                self.showingDetail = false
                            }
                        }
                    }
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .transition(self.reduceMotion ? .identity : .move(edge: .trailing).combined(with: .opacity))
            } else {
                VStack(spacing: 0) {
                    CapsuleTabBar(selection: self.$selectedTab)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.xs)

                    Group {
                        switch self.selectedTab {
                        case .devices:
                            ScrollView(.vertical, showsIndicators: false) {
                                DevicesColumnView(onSelectDevice: { device in
                                    self.selectedDetail = device
                                    if self.reduceMotion {
                                        self.showingDetail = true
                                    } else {
                                        withAnimation(.easeOut(duration: RevealTiming.expandDuration)) {
                                            self.showingDetail = true
                                        }
                                    }
                                })
                            }
                        case .settings:
                            ScrollView(.vertical, showsIndicators: false) {
                                SettingsTabView()
                            }
                        case .about:
                            ScrollView(.vertical, showsIndicators: false) {
                                AboutTabView()
                            }
                        }
                    }
                    .id(self.selectedTab)
                    .transition(.opacity)
                    .animation(DesignAnimation.spring(reduceMotion: self.reduceMotion), value: self.selectedTab)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                }
                .padding(.bottom, Spacing.sm)
                .transition(self.reduceMotion ? .identity : .opacity)
            }
        }
    }
}

// MARK: - Legacy NavigationContainer (bridges to ExpandedPanelView)

struct NavigationContainer: View {
    var body: some View {
        ExpandedPanelView()
    }
}
