import SwiftUI

// BatteryStyle is now defined in BatteryBoi/Models/BatteryModels.swift

enum BatteryAnimationType {
    case charging
    case low

}

public struct BatteryPulsatingIcon: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var manager: any BatteryServiceProtocol {
        env.battery
    }

    @State private var visible: Bool = false
    @State private var icon: String = "ChargingIcon"
    @State private var pulsatingTask: Task<Void, Never>?

    init(_ icon: String) {
        _icon = State(initialValue: icon)

    }

    public var body: some View {
        Rectangle()
            .fill(Color("BatteryIconFill"))
            .mask(
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

            )
            .frame(width: 5, height: 8)
            .onAppear {
                if reduceMotion {
                    visible = true
                } else {
                    withAnimation(Animation.easeInOut) {
                        visible = true
                    }
                }
            }
            .offset(y: 0.4)
            .opacity(visible ? 1.0 : 0.0)
            .onChange(of: visible) { _, newVisible in
                // Skip pulsating animation if reduce motion is enabled
                guard !reduceMotion else { return }

                pulsatingTask?.cancel()
                pulsatingTask = Task { @MainActor in
                    do {
                        try await Task.sleep(for: .seconds(newVisible ? 2.0 : 0.8))
                        guard !Task.isCancelled else { return }
                        withAnimation(Animation.easeInOut) {
                            visible.toggle()
                        }
                    } catch {
                        // Task cancelled
                    }
                }
            }
            .onDisappear {
                pulsatingTask?.cancel()
                pulsatingTask = nil
            }
            .accessibilityHidden(true)

    }

}

public struct BatteryMask: Shape {
    private var radius: CGFloat

    init(_ value: CGFloat) {
        radius = value

    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: radius), control: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.width - radius, y: rect.height),
            control: CGPoint(x: rect.width, y: rect.height)
        )
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: .zero)

        return path

    }

}

private struct BatteryStatus: View {
    @Environment(\.appEnvironment) private var env

    private var manager: any BatteryServiceProtocol {
        env.battery
    }

    private var stats: StatsService {
        env.stats
    }

    @State private var size: CGSize
    @State private var font: CGFloat
    @State private var icon: String?

    @Binding private var hover: Bool

    init(_ size: CGSize, font: CGFloat, hover: Binding<Bool>) {
        _size = State(initialValue: size)
        _font = State(initialValue: font)
        _hover = hover

    }

    var body: some View {
        ZStack {
            if let overlay = stats.overlay {
                Text(overlay).style(font).offset(y: hover ? 0.0 : -size.height)

            }

            HStack(alignment: .center, spacing: 0.4) {
                if let icon {
                    BatteryPulsatingIcon(icon)

                }

                if let summary = stats.display {
                    Text(summary).style(font)

                }

            }
            .offset(y: hover ? size.height : 0.0)
            .foregroundColor(Color("BatteryIconFill"))
            .frame(width: size.width, height: size.height)

        }
        .onAppear {
            if manager.charging.state == .charging, manager.percentage != 100 {
                icon = "ChargingIcon"

            } else {
                icon = nil

            }

        }
        .onChange(of: manager.charging) { _, newValue in
            if newValue.state == .charging, manager.percentage != 100 {
                icon = "ChargingIcon"

            } else {
                icon = nil

            }

        }
        .onChange(of: manager.percentage) { _, newValue in
            if manager.charging.state == .charging, newValue != 100 {
                icon = "ChargingIcon"

            } else {
                icon = nil

            }

        }
        .frame(alignment: .center)
        .foregroundColor(Color("BatteryIconFill"))
        .animation(Animation.easeInOut, value: manager.charging)

    }

}

private struct BatteryStub: View {
    @State private var proxy: GeometryProxy
    @State private var size: CGSize

    init(_ proxy: GeometryProxy, size: CGSize) {
        _proxy = State(initialValue: proxy)
        _size = State(initialValue: size)

    }

    var body: some View {
        ZStack {
            BatteryMask(3.4).foregroundColor(Color("BatteryDefault"))

        }
        .position(x: proxy.size.width + 2, y: proxy.size.height / 2)
        .frame(width: 1.6, height: 6)
        .opacity(0.6)

    }

}

struct BatteryIcon: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var manager: any BatteryServiceProtocol {
        env.battery
    }

    @State var size: CGSize
    @State var radius: CGFloat = 25
    @State var max: CGFloat = 25
    @State var font: CGFloat
    @State var padding: CGFloat
    @State var progress: CGFloat

    @Binding var hover: Bool

    init(_ size: CGSize, radius: CGFloat, font: CGFloat, hover: Binding<Bool>) {
        _size = State(initialValue: size)
        _radius = State(initialValue: radius)
        _max = State(initialValue: radius)
        _font = State(initialValue: font)
        _padding = State(initialValue: 1.6)
        _progress = State(initialValue: 1.0)
        _hover = hover

    }

    private var springAnimation: Animation? {
        reduceMotion ? nil : .interactiveSpring(response: 0.6, dampingFraction: 0.9, blendDuration: 1)
    }

    var body: some View {
        ZStack {
            HStack(alignment: .center) {
                Rectangle()
                    .frame(width: progress, alignment: .leading)
                    .clipShape(BatteryMask(3.4))

            }
            .frame(maxWidth: size.width, alignment: .leading)
            .foregroundColor(Color("BatteryIconFill"))
            .overlay(
                BatteryStatus(size, font: font, hover: $hover)

            )

        }
        .animation(reduceMotion ? nil : .linear, value: manager.percentage)
        .inverse(
            BatteryStatus(size, font: font, hover: $hover).mask(
                Rectangle()
                    .fill(Color("BatteryIconFill"))
                    .frame(width: size.width)
                    .position(x: -(size.width / 2) + (progress + 2.0), y: size.height / 2)

            )

        )
        .clipShape(RoundedRectangle(cornerRadius: radius - padding, style: .continuous))
        .padding(padding)
        .onChange(of: manager.charging.state) { _, newValue in
            if let animation = springAnimation {
                withAnimation(animation) {
                    progress = newValue.progress(manager.percentage, width: size.width)
                }
            } else {
                progress = newValue.progress(manager.percentage, width: size.width)
            }

        }
        .onChange(of: manager.percentage) { _, newValue in
            if let animation = springAnimation {
                withAnimation(animation) {
                    progress = manager.charging.state.progress(newValue, width: size.width)
                }
            } else {
                progress = manager.charging.state.progress(newValue, width: size.width)
            }

        }
        .onAppear {
            if let animation = springAnimation {
                withAnimation(animation) {
                    progress = manager.charging.state.progress(manager.percentage, width: size.width)
                }
            } else {
                progress = manager.charging.state.progress(manager.percentage, width: size.width)
            }

        }

    }

}

struct BatteryContainer: View {
    @Environment(\.appEnvironment) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var manager: any BatteryServiceProtocol {
        env.battery
    }

    private var updates: UpdateManager {
        env.update
    }

    private var stats: StatsService {
        env.stats
    }

    @State private var size: CGSize
    @State private var radius: CGFloat
    @State private var font: CGFloat
    @State private var hover: Bool = false

    init(_ size: CGSize, radius: CGFloat, font: CGFloat) {
        _size = State(initialValue: size)
        _radius = State(initialValue: radius)
        _font = State(initialValue: font)

    }

    private var hoverAnimation: Animation? {
        reduceMotion ? nil : Animation.easeOut(duration: 0.3)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color("BatteryDefault"))
                .opacity(0.9)
                .frame(width: size.width, height: size.height)
                .mask(
                    Rectangle().inverse(BatteryIcon(size, radius: radius, font: font, hover: $hover))

                )

        }
        .onHover { hover in
            if stats.overlay != nil {
                if let animation = hoverAnimation {
                    withAnimation(animation.delay(self.hover ? 0.8 : 0.1)) {
                        self.hover = hover
                    }
                } else {
                    self.hover = hover
                }

            }

        }
        .onChange(of: manager.charging) { _, newValue in
            if newValue.state == .charging, hover == true {
                if let animation = hoverAnimation {
                    withAnimation(animation) {
                        hover = false
                    }
                } else {
                    hover = false
                }

            }

        }
        .overlay(
            GeometryReader { geo in
                if updates.available != nil {
                    Circle()
                        .fill(Color("BatteryEfficient"))
                        .frame(width: 5, height: 5)
                        .position(x: -5, y: (geo.size.height / 2) + 0.5)
                        .accessibilityLabel("Update available")

                }

                BatteryStub(geo, size: .init(width: 4, height: size.height / 2))

            }

        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Battery level")
        .accessibilityValue(
            "\(Int(manager.percentage)) percent\(manager.charging.state == .charging ? ", charging" : "")"
        )
        .accessibilityHint("Shows current battery status")

    }

}

struct MenuContainer: View {
    var body: some View {
        BatteryContainer(.init(width: 32, height: 15), radius: 5, font: 11)
    }

}

struct MenuViewRepresentable: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSHostingView<MenuContainer> {
        let hostingView = NSHostingView(rootView: MenuContainer())
        hostingView.frame.size = NSSize(width: 100, height: 20)
        return hostingView

    }

    func updateNSView(_: NSHostingView<MenuContainer>, context _: Context) {}

}
