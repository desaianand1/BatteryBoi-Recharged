import SwiftUI

struct NavigationContainer: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.serviceContainer) private var container

    private var manager: AppManager {
        env.app
    }

    private var updates: UpdateManager {
        env.update
    }

    private var settings: any SettingsServiceProtocol {
        env.settings
    }

    private var bluetooth: any BluetoothServiceProtocol {
        env.bluetooth
    }

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State
    var update: Bool = false
    @State
    var hover: Bool = false
    @State
    var scroll: CGPoint = .zero
    @State
    var size: CGSize = .zero

    var body: some View {
        ZStack {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(self.settings.menu, id: \.self) { item in
                                if self.manager.menu == .settings {
                                    SettingsItem(hover: self.$hover, item: item)

                                }

                            }

                            if self.manager.menu == .devices {
                                if self.container.state.selectedDevice != nil {
                                    BluetoothItem(nil, hover: self.$hover)

                                }

                            }

                            ForEach(self.bluetooth.connected, id: \.address) { item in
                                if self.manager.menu == .devices {
                                    BluetoothItem(item, hover: self.$hover)

                                }

                            }

                            // Show appropriate state when in devices tab
                            if self.manager.menu == .devices {
                                if self.bluetooth.permissionStatus == .denied || self.bluetooth
                                    .permissionStatus == .restricted
                                {
                                    BluetoothPermissionDeniedView()
                                } else if self.bluetooth.connected.isEmpty {
                                    BluetoothEmptyStateView()
                                }
                            }

                            if !self.bluetooth.connected.isEmpty {
                                Spacer().frame(width: self.size.width)

                            } else {
                                Spacer().frame(width: self.size.width / 2)

                            }

                        }
                        .animation(Animation.bouncy, value: self.manager.menu)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: SettingsScrollOffsetKey.self,
                                value: geometry.frame(in: .named("scroll")).origin
                            )

                        })
                        .onPreferenceChange(SettingsScrollOffsetKey.self) { value in
                            Task { @MainActor in
                                if window.state == .detailed {
                                    self.scroll = value

                                }
                            }

                        }

                    }
                    .coordinateSpace(name: "scroll")
                    .mask(30, scroll: self.$scroll)
                    .frame(width: geo.size.width)

                    ZStack(alignment: .trailing) {
                        HStack(spacing: 8) {
                            SettingsOverlayItem(.appDevices)

                            SettingsOverlayItem(.appQuit)

                        }

                    }
                    .frame(height: 60)
                    .background(
                        HStack(alignment: .center, spacing: 0) {
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color("BatteryBackground").opacity(0.0),
                                    Color("BatteryBackground"),
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 30)

                            Rectangle().fill(Color("BatteryBackground"))

                        }
                        .frame(width: self.size.width + 16)
                        .offset(x: !self.bluetooth.connected.isEmpty ? -8.0 : 48.0)

                    )
                    .overlay(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                self.size = geo.size

                            }

                        }

                    )
                    .offset(x: -(self.size.width))

                }

            }

        }
        .padding(.horizontal, 14)
        .frame(height: 86)
        .onHover { hover in
            withAnimation(Animation.easeOut.delay(self.hover ? 1.2 : 0.1)) {
                self.hover = hover

            }

        }
        .onAppear {
            self.update = self.updates.available != nil ? true : false

        }
        .onChange(of: self.bluetooth.connected) { _, _ in
            // Empty state is now shown via BluetoothEmptyStateView
            // No longer auto-switch to settings when devices disconnect
        }
        .onChange(of: self.updates.available) { _, newValue in
            withAnimation(Animation.easeOut.delay(0.1)) {
                self.update = newValue != nil ? true : false

            }

        }

    }

}
