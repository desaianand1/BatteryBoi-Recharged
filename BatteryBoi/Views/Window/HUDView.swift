import SwiftUI

// Types (HUDState, HUDAlertTypes, HUDProgressLayout) are now defined in BatteryBoi/Models/HUDModels.swift

struct HUDIcon: View {
    @Environment(AppEnvironment.self) private var env

    private var stats: any StatsServiceProtocol {
        self.env.stats
    }

    @Namespace private var animation

    var body: some View {
        VStack {
            Image(systemName: self.stats.statsIcon.name)
                .resizable().scaledToFit()
                .matchedGeometryEffect(id: "icon", in: self.animation)
                .frame(width: 28, height: 28)
                .foregroundColor(self.stats.statsIcon.color)
                .applySymbolEffect(self.stats.statsIcon.effect)
                .offset(y: 1)
        }
        .frame(width: 50, height: 50)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .background(Color.clear)
        .accessibilityHidden(true)
    }
}

struct HUDSummary: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stats: any StatsServiceProtocol {
        env.stats
    }

    private var updates: any UpdateManagerProtocol {
        env.update
    }

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State private var visible: Bool = false

    var body: some View {
        HStack(alignment: .center) {
            HUDIcon()

            VStack(alignment: .leading, spacing: 2) {
                Text(stats.title)
                    .font(Typography.titleBold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                BoldStyledText(stats.subtitle)

                if updates.available != nil {
                    UpdatePromptView()

                }

            }

            Spacer()

        }
        .blur(radius: self.visible ? 0.0 : (window.state == .hidden ? 0.0 : 4.0))
        .opacity(visible ? 1.0 : 0.0)
        .onAppear {
            if window.state == .revealed || window.state == .detailed {
                visible = true
            }
        }
        .onChange(of: window.state) { oldValue, newValue in
            if oldValue == .detailed, newValue == .revealed {
                return
            }
            if reduceMotion {
                visible = newValue.visible
            } else {
                let duration = newValue.visible
                    ? RevealTiming.contentFade
                    : RevealTiming.dismissTextFade
                let delay = visible == false ? RevealTiming.contentRevealDelay : 0.0
                withAnimation(Animation.easeOut(duration: duration).delay(delay)) {
                    visible = newValue.visible
                }
            }

        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stats.title). \(stats.subtitle)")

    }

}

struct HUDContainer: View {
    @Environment(AppEnvironment.self) private var env

    private var battery: any BatteryServiceProtocol {
        env.battery
    }

    private var window: any WindowServiceProtocol {
        env.window
    }

    private var manager: any AppManagerProtocol {
        env.app
    }

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting
    @State private var ringSlideTask: Task<Void, Never>?

    @Binding private var progress: HUDProgressLayout

    init(progress: Binding<HUDProgressLayout>) {
        _timeline = State(initialValue: .init([]))
        _progress = progress

    }

    var body: some View {
        HStack(alignment: .center) {
            HUDSummary()

            if window.state == .detailed {
                Spacer()

                Button(
                    action: { window.toggleExpanded() },
                    label: {
                        Image(systemName: "xmark")
                            .font(Typography.heading)
                            .foregroundStyle(Color("BBSubtitle"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color("BBSurface")))
                    }
                )
                .buttonStyle(HoverButtonStyle())
                .transition(.blurFade)
            }
        }
        .timeline($timeline, state: $animation)
        .padding(.leading, Spacing.md + Spacing.xs)
        .padding(.trailing, window.state == .detailed ? Spacing.lg : Spacing.sm + Spacing.xxs)
        .padding(.vertical, window.state == .detailed ? Spacing.xs : 0)
        .onAppear {
            if let animation = window.state.container {
                timeline = animation

            }

        }
        .onChange(of: window.state) { oldValue, newValue in
            if let animation = HUDState.containerTransition(from: oldValue, to: newValue) {
                timeline = animation

            }

            if newValue == .revealed, oldValue != .detailed {
                ringSlideTask?.cancel()
                ringSlideTask = Task {
                    try? await Task.sleep(for: .seconds(RevealTiming.ringSlideDelay))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: RevealTiming.ringSlide)) {
                        progress = .trailing
                    }
                }

            }

            if !newValue.visible {
                ringSlideTask?.cancel()
            }

        }
        .onDisappear {
            ringSlideTask?.cancel()
        }

    }

}

struct HUDMaskView: View {
    @Environment(AppEnvironment.self) private var env

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting

    var keyframes = [AnimationKeyframeObject]()

    init() {
        _timeline = State(initialValue: .init([]))

    }

    var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .timeline($timeline, state: $animation)
                .frame(width: 20, height: 20)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let animation = window.state.mask {
                timeline = animation

            }

        }
        .onChange(of: window.state) { oldValue, newValue in
            if let animation = HUDState.maskTransition(from: oldValue, to: newValue) {
                timeline = animation

            }

        }

    }

}

struct HUDGlow: View {
    @Environment(AppEnvironment.self) private var env

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting

    init() {
        _timeline = State(initialValue: .init([]))

    }

    var body: some View {
        Circle()
            .fill(Color("BBBackground"))
            .frame(width: 80, height: 80)
            .timeline($timeline, state: $animation)
            .onAppear {
                if let animation = window.state.glow {
                    timeline = animation

                }

            }
            .onChange(of: window.state) { oldValue, newValue in
                if let animation = HUDState.glowTransition(from: oldValue, to: newValue) {
                    timeline = animation

                }

            }

    }

}

struct HUDProgress: View {
    @Environment(AppEnvironment.self) private var env

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting

    init() {
        _timeline = State(initialValue: .init([]))

    }

    var body: some View {
        RadialProgressContainer(true)
            .timeline($timeline, state: $animation)
            .onAppear {
                if let animation = window.state.progress {
                    timeline = animation

                }

            }
            .onChange(of: window.state) { oldValue, newValue in
                if let animation = HUDState.progressTransition(from: oldValue, to: newValue) {
                    timeline = animation

                }

            }

    }

}

struct HUDView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting
    @State private var progress: HUDProgressLayout = .center

    @Namespace private var namespace

    init() {
        _timeline = State(initialValue: .init([]))

    }

    var body: some View {
        ZStack(alignment: .center) {
            VStack {
                if window.state == .detailed {
                    HUDContainer(progress: $progress)
                        .matchedGeometryEffect(id: "hud", in: namespace)

                    NavigationContainer()

                    Spacer(minLength: 0)

                } else {
                    HUDContainer(progress: $progress)
                        .matchedGeometryEffect(id: "hud", in: namespace)

                }

            }

            HUDProgress()
                .opacity(window.state == .detailed ? 0.0 : 1.0)
                .scaleEffect(window.state == .detailed ? 0.85 : 1.0)
                .allowsHitTesting(window.state != .detailed)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: RevealTiming.expandDuration),
                    value: window.state == .detailed
                )
                .frame(maxWidth: .infinity, alignment: progress == .trailing ? .trailing : .center)
                .padding(.trailing, progress == .trailing ? Spacing.sm + Spacing.xxs : 0)

        }
        .frame(minWidth: 380, idealWidth: 450, maxWidth: 520)
        .frame(minHeight: 200, idealHeight: 250, maxHeight: 500)
        .background(
            Color("BBBackground").opacity(window.opacity)

        )
        .timeline($timeline, state: $animation)
        .mask(
            HUDMaskView()

        )
        .background(
            HUDGlow()

        )
        .onHover(perform: { hover in
            window.hover = hover

        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("AccessibilityBatteryNotification".localise())
        .accessibilityAddTraits(.isModal)

    }

}

struct HUDParent: View {
    @State var type: HUDAlertTypes
    @State var device: BluetoothObject?

    init(_ type: HUDAlertTypes, device: BluetoothObject?) {
        _type = State(initialValue: type)
        _device = State(initialValue: device)

    }

    var body: some View {
        VStack {
            HUDView()

        }

    }

}
