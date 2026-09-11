import SwiftUI

struct ExpandedPanelView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var bluetooth: any BluetoothServiceProtocol {
        self.env.bluetooth
    }

    @State private var selectedDetail: BluetoothObject?
    @State private var showingDetail: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color("BatterySubtitle").opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, Spacing.md)

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
                HStack(alignment: .top, spacing: Spacing.sm) {
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
                    .frame(minWidth: 160, maxWidth: 240)

                    SettingsTileGrid()
                }
                .padding(Spacing.md)
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
