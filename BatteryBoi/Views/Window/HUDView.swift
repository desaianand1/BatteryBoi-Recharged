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
                .frame(width: Constants.Progress.miniSize, height: Constants.Progress.miniSize)
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

                ZStack(alignment: .leading) {
                    BoldStyledText(stats.subtitle)
                        .opacity(window.activeFlash == nil ? 1.0 : 0.0)

                    if let flash = window.activeFlash {
                        Text(flash.text)
                            .font(Typography.body)
                            .foregroundColor(flash.color)
                            .transition(.opacity.animation(.easeInOut(duration: FlashEvent.fadeIn)))
                    }
                }
                .animation(
                    DesignAnimation.easeOut(duration: 0.3, reduceMotion: reduceMotion),
                    value: window.activeFlash
                )

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    private var manager: any AppManagerProtocol {
        self.env.app
    }

    @State private var containerPaddingTop: CGFloat = 0
    @State private var containerPaddingBottom: CGFloat = 0
    @State private var containerOpacity: CGFloat = 1.0
    @State private var containerBlur: CGFloat = 0.0
    @State private var ringSlideTask: Task<Void, Never>?

    @Binding private var progress: HUDProgressLayout

    init(progress: Binding<HUDProgressLayout>) {
        self._progress = progress
    }

    var body: some View {
        HStack(alignment: .center) {
            HUDSummary()

            if self.window.state == .detailed {
                Spacer()

                Button(
                    action: { self.window.toggleExpanded() },
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
        .opacity(self.containerOpacity)
        .blur(radius: self.containerBlur)
        .padding(.top, self.containerPaddingTop)
        .padding(.bottom, self.containerPaddingBottom)
        .padding(.leading, Spacing.md + Spacing.xs)
        .padding(.trailing, self.window.state == .detailed ? Spacing.lg : Spacing.sm + Spacing.xxs)
        .padding(.vertical, self.window.state == .detailed ? Spacing.xs : 0)
        .onAppear {
            self.applyContainer(from: .hidden, to: self.window.state)
        }
        .onChange(of: self.window.state) { oldValue, newValue in
            self.applyContainer(from: oldValue, to: newValue)

            if newValue == .revealed, oldValue != .detailed {
                self.ringSlideTask?.cancel()
                self.ringSlideTask = Task {
                    try? await Task.sleep(for: .seconds(RevealTiming.ringSlideDelay))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: RevealTiming.ringSlide)) {
                        self.progress = .trailing
                    }
                }
            }

            if !newValue.visible {
                self.ringSlideTask?.cancel()
            }
        }
        .onDisappear {
            self.ringSlideTask?.cancel()
        }
    }

    private func applyContainer(from: HUDState, to: HUDState) {
        if from == .detailed, to == .revealed {
            let animation = DesignAnimation.easeOut(
                duration: RevealTiming.collapseDuration, reduceMotion: self.reduceMotion
            )
            withAnimation(animation) {
                self.containerPaddingTop = 0
                self.containerPaddingBottom = 0
            }
            return
        }
        switch to {
        case .detailed:
            let animation = DesignAnimation.easeOut(duration: 0.4, reduceMotion: self.reduceMotion)
            withAnimation(animation) {
                self.containerPaddingTop = 24
                self.containerPaddingBottom = 16
            }
        case .dismissed:
            let animation = DesignAnimation.easeOut(
                duration: RevealTiming.dismissContainerFade, reduceMotion: self.reduceMotion
            )
            withAnimation(animation) {
                self.containerOpacity = 0.0
                self.containerBlur = 5.0
            }
        default:
            break
        }
    }
}

struct HUDMaskView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    @State private var maskPhase: HUDMaskPhase = .idle
    @State private var maskGeneration: Int = 0

    @State private var staticWidth: CGFloat = 20
    @State private var staticHeight: CGFloat = 20
    @State private var staticRadius: CGFloat = 10
    @State private var staticOpacity: CGFloat = 1.0

    var body: some View {
        ZStack(alignment: .center) {
            if self.reduceMotion {
                RoundedRectangle(cornerRadius: self.staticRadius, style: .continuous)
                    .frame(width: self.staticWidth, height: self.staticHeight)
                    .opacity(self.staticOpacity)
            } else {
                self.maskAnimator
                    .id(self.maskPhase)
                    .transition(.identity)
                    .task(id: self.maskPhase) {
                        self.maskGeneration += 1
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if self.reduceMotion {
                self.applyMaskEndState(from: .hidden, to: self.window.state)
            } else if let phase = self.maskPhaseFor(from: .hidden, to: self.window.state) {
                self.maskPhase = phase
            }
        }
        .onChange(of: self.window.state) { oldValue, newValue in
            if self.reduceMotion {
                self.applyMaskEndState(from: oldValue, to: newValue)
            } else if let phase = self.maskPhaseFor(from: oldValue, to: newValue) {
                self.maskPhase = phase
            }
        }
    }

    // MARK: - Phase-specific keyframe animators

    @ViewBuilder
    private var maskAnimator: some View {
        switch self.maskPhase {
        case .idle:
            self.maskShape(initialValue: HUDMaskValues()) {
                KeyframeTrack(\.width) { LinearKeyframe(8, duration: 0.01) }
                KeyframeTrack(\.height) { LinearKeyframe(8, duration: 0.01) }
            }

        case .reveal:
            self.maskShape(initialValue: HUDMaskValues()) {
                KeyframeTrack(\.width) {
                    SpringKeyframe(120, duration: RevealTiming.circlePhaseEnd, spring: DesignAnimation.hudSpring)
                    SpringKeyframe(430, duration: RevealTiming.pillExpansion, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.height) {
                    SpringKeyframe(120, duration: RevealTiming.circlePhaseEnd, spring: DesignAnimation.hudSpring)
                    LinearKeyframe(120, duration: RevealTiming.pillExpansion)
                }
                KeyframeTrack(\.radius) {
                    SpringKeyframe(
                        Constants.CornerRadius.maskCircle,
                        duration: RevealTiming.circlePhaseEnd,
                        spring: DesignAnimation.hudSpring
                    )
                    LinearKeyframe(Constants.CornerRadius.maskCircle, duration: RevealTiming.pillExpansion)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: 0.15)
                }
            }

        case .expand:
            self.maskShape(initialValue: HUDMaskValues(
                width: 430, height: 120,
                radius: Constants.CornerRadius.maskCircle, opacity: 1.0
            )) {
                KeyframeTrack(\.width) {
                    SpringKeyframe(500, duration: RevealTiming.expandDuration, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.height) {
                    SpringKeyframe(460, duration: RevealTiming.expandDuration, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.radius) {
                    SpringKeyframe(
                        Constants.CornerRadius.hud,
                        duration: RevealTiming.expandDuration,
                        spring: DesignAnimation.hudSpring
                    )
                }
            }

        case .collapse:
            self.maskShape(initialValue: HUDMaskValues(
                width: 500, height: 460,
                radius: Constants.CornerRadius.hud, opacity: 1.0
            )) {
                KeyframeTrack(\.width) {
                    SpringKeyframe(430, duration: RevealTiming.collapseDuration, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.height) {
                    SpringKeyframe(120, duration: RevealTiming.collapseDuration, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.radius) {
                    SpringKeyframe(60, duration: RevealTiming.collapseDuration, spring: DesignAnimation.hudSpring)
                }
            }

        case .dismiss:
            self.maskShape(initialValue: HUDMaskValues(
                width: 430, height: 120,
                radius: Constants.CornerRadius.maskCircle, opacity: 1.0
            )) {
                KeyframeTrack(\.width) {
                    LinearKeyframe(430, duration: RevealTiming.dismissMaskHold)
                    SpringKeyframe(120, duration: RevealTiming.dismissPillContract, spring: DesignAnimation.hudSpring)
                    SpringKeyframe(40, duration: RevealTiming.dismissCircleShrink, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.height) {
                    LinearKeyframe(120, duration: RevealTiming.dismissMaskHold)
                    LinearKeyframe(120, duration: RevealTiming.dismissPillContract)
                    SpringKeyframe(40, duration: RevealTiming.dismissCircleShrink, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.radius) {
                    LinearKeyframe(Constants.CornerRadius.maskCircle, duration: RevealTiming.dismissMaskHold)
                    LinearKeyframe(Constants.CornerRadius.maskCircle, duration: RevealTiming.dismissPillContract)
                    SpringKeyframe(
                        Constants.CornerRadius.maskDismiss,
                        duration: RevealTiming.dismissCircleShrink,
                        spring: DesignAnimation.hudSpring
                    )
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1.0, duration: RevealTiming.dismissMaskHold + RevealTiming.dismissPillContract)
                    CubicKeyframe(0.0, duration: RevealTiming.dismissCircleShrink)
                }
            }
        }
    }

    private func maskShape<K: Keyframes>(
        initialValue: HUDMaskValues,
        @KeyframesBuilder<HUDMaskValues> keyframes: @escaping () -> K
    ) -> some View where K.Value == HUDMaskValues {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .keyframeAnimator(
                initialValue: initialValue,
                trigger: self.maskGeneration
            ) { content, values in
                content
                    .frame(width: values.width, height: values.height)
                    .clipShape(RoundedRectangle(cornerRadius: values.radius, style: .continuous))
                    .opacity(values.opacity)
            } keyframes: { _ in
                keyframes()
            }
    }

    // MARK: - Reduce motion

    private func applyMaskEndState(from: HUDState, to: HUDState) {
        switch self.maskPhaseFor(from: from, to: to) {
        case .reveal:
            self.staticWidth = 430; self.staticHeight = 120
            self.staticRadius = Constants.CornerRadius.maskCircle; self.staticOpacity = 1.0
        case .expand:
            self.staticWidth = 500; self.staticHeight = 460
            self.staticRadius = Constants.CornerRadius.hud; self.staticOpacity = 1.0
        case .collapse:
            self.staticWidth = 430; self.staticHeight = 120
            self.staticRadius = 60; self.staticOpacity = 1.0
        case .dismiss:
            self.staticWidth = 40; self.staticHeight = 40
            self.staticRadius = Constants.CornerRadius.maskDismiss; self.staticOpacity = 0.0
        case .idle, nil:
            break
        }
    }

    private func maskPhaseFor(from: HUDState, to: HUDState) -> HUDMaskPhase? {
        if from == .detailed, to == .revealed {
            return .collapse
        }
        switch to {
        case .revealed: return .reveal
        case .detailed: return .expand
        case .dismissed: return .dismiss
        default: return nil
        }
    }
}

struct HUDGlow: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    @State private var glowPhase: HUDGlowPhase = .idle
    @State private var glowGeneration: Int = 0

    var body: some View {
        if self.reduceMotion {
            Circle()
                .fill(Color("BBBackground"))
                .frame(width: 80, height: 80)
                .opacity(0)
        } else {
            self.glowAnimator
                .id(self.glowPhase)
                .transition(.identity)
                .task(id: self.glowPhase) {
                    self.glowGeneration += 1
                }
                .onAppear {
                    if let phase = self.glowPhaseFor(from: .hidden, to: self.window.state) {
                        self.glowPhase = phase
                    }
                }
                .onChange(of: self.window.state) { oldValue, newValue in
                    if let phase = self.glowPhaseFor(from: oldValue, to: newValue) {
                        self.glowPhase = phase
                    }
                }
        }
    }

    @ViewBuilder
    private var glowAnimator: some View {
        switch self.glowPhase {
        case .idle:
            self.glowShape(initialValue: HUDGlowValues()) {
                KeyframeTrack(\.opacity) { LinearKeyframe(0.0, duration: 0.01) }
            }

        case .reveal:
            self.glowShape(initialValue: HUDGlowValues()) {
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.0, duration: RevealTiming.glowStartDelay - 0.03)
                    CubicKeyframe(0.0, duration: 0.03)
                    SpringKeyframe(0.5, duration: RevealTiming.glowPulse, spring: DesignAnimation.hudSpring)
                    CubicKeyframe(0.0, duration: RevealTiming.glowFade)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.2, duration: RevealTiming.glowStartDelay)
                    SpringKeyframe(1.9, duration: RevealTiming.glowPulse, spring: DesignAnimation.hudSpring)
                    CubicKeyframe(1.0, duration: RevealTiming.glowFade)
                }
            }

        case .dismiss:
            self.glowShape(initialValue: HUDGlowValues()) {
                KeyframeTrack(\.opacity) {
                    CubicKeyframe(0.0, duration: 0.03)
                    CubicKeyframe(0.6, duration: 0.4)
                    SpringKeyframe(0.0, duration: 0.2, spring: DesignAnimation.hudSpring)
                }
                KeyframeTrack(\.scale) {
                    CubicKeyframe(0.2, duration: 0.03)
                    CubicKeyframe(1.4, duration: 0.4)
                    SpringKeyframe(0.2, duration: 0.2, spring: DesignAnimation.hudSpring)
                }
            }
        }
    }

    private func glowShape<K: Keyframes>(
        initialValue: HUDGlowValues,
        @KeyframesBuilder<HUDGlowValues> keyframes: @escaping () -> K
    ) -> some View where K.Value == HUDGlowValues {
        Circle()
            .fill(Color("BBBackground"))
            .frame(width: 80, height: 80)
            .keyframeAnimator(
                initialValue: initialValue,
                trigger: self.glowGeneration
            ) { content, values in
                content
                    .opacity(values.opacity)
                    .scaleEffect(values.scale)
            } keyframes: { _ in
                keyframes()
            }
    }

    private func glowPhaseFor(from: HUDState, to: HUDState) -> HUDGlowPhase? {
        if from == .detailed, to == .revealed {
            return nil
        }
        switch to {
        case .revealed: return .reveal
        case .dismissed: return .dismiss
        default: return nil
        }
    }
}

struct HUDProgress: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    @State private var progressOpacity: CGFloat = 0.0
    @State private var progressScale: CGFloat = 0.85
    @State private var progressBlur: CGFloat = 0.0

    var body: some View {
        RadialProgressContainer(true)
            .opacity(self.progressOpacity)
            .scaleEffect(self.progressScale)
            .blur(radius: self.progressBlur)
            .onAppear {
                self.applyProgress(from: .hidden, to: self.window.state)
            }
            .onChange(of: self.window.state) { oldValue, newValue in
                self.applyProgress(from: oldValue, to: newValue)
            }
    }

    private func applyProgress(from: HUDState, to: HUDState) {
        if from == .detailed, to == .revealed {
            return
        }

        switch to {
        case .revealed:
            self.progressOpacity = 0.0
            self.progressScale = 0.8
            self.progressBlur = 5.0
            let animation = DesignAnimation.easeOut(
                duration: RevealTiming.ringFadeIn, reduceMotion: self.reduceMotion
            )
            withAnimation(animation) {
                self.progressOpacity = 1.0
                self.progressScale = 1.0
                self.progressBlur = 0.0
            }
        case .dismissed:
            let animation = DesignAnimation.spring(reduceMotion: self.reduceMotion)
            withAnimation(animation) {
                self.progressOpacity = 0.0
                self.progressBlur = 12.0
                self.progressScale = 0.9
            }
        default:
            break
        }
    }
}

struct HUDView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    @State private var progress: HUDProgressLayout = .center

    @Namespace private var namespace

    var body: some View {
        ZStack(alignment: .center) {
            VStack {
                if self.window.state == .detailed {
                    HUDContainer(progress: self.$progress)
                        .matchedGeometryEffect(id: "hud", in: self.namespace)

                    NavigationContainer()

                    Spacer(minLength: 0)

                } else {
                    HUDContainer(progress: self.$progress)
                        .matchedGeometryEffect(id: "hud", in: self.namespace)
                }
            }

            HUDProgress()
                .opacity(self.window.state == .detailed ? 0.0 : 1.0)
                .scaleEffect(self.window.state == .detailed ? 0.85 : 1.0)
                .allowsHitTesting(self.window.state != .detailed)
                .animation(
                    self.reduceMotion ? nil : .easeOut(duration: RevealTiming.expandDuration),
                    value: self.window.state == .detailed
                )
                .frame(maxWidth: .infinity, alignment: self.progress == .trailing ? .trailing : .center)
                .padding(.trailing, self.progress == .trailing ? Spacing.sm + Spacing.xxs : 0)
        }
        .frame(minWidth: 380, idealWidth: 450, maxWidth: 520)
        .frame(minHeight: 200, idealHeight: 250, maxHeight: 500)
        .background(
            Color("BBBackground").opacity(self.window.opacity)
        )
        .mask(
            HUDMaskView()
        )
        .background(
            HUDGlow()
        )
        .onHover(perform: { hover in
            self.window.hover = hover
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
