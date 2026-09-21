import SwiftUI

struct RadialProgressBar: View {
    @Binding var progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var size: CGSize
    @State private var line: CGFloat
    @State private var position: Double = 0.0

    private let percent: Double
    private let isCharging: Bool
    private let isMini: Bool
    private let showChargeNotch: Bool

    @State private var glowOpacity: Double = 0.0
    @State private var shimmerPhase: Double = 0.0
    @State private var dotScale: CGFloat = 1.0
    @State private var trackBreathOpacity: Double = 0.08
    @State private var burstScale: CGFloat = 1.0
    @State private var burstOpacity: Double = 0.0
    @State private var notchGlowActive: Bool = false

    init(
        _ progress: Binding<Double>,
        size: CGSize,
        line: CGFloat = 10,
        percent: Double,
        isCharging: Bool,
        isMini: Bool = false,
        showChargeNotch: Bool = false
    ) {
        _progress = progress
        _size = State(initialValue: size)
        _line = State(initialValue: line)
        self.percent = percent
        self.isCharging = isCharging
        self.isMini = isMini
        self.showChargeNotch = showChargeNotch
    }

    private var showDot: Bool {
        if self.isMini {
            return true
        }
        if self.isCharging {
            return self.percent < 100
        }
        if self.percent < 20 {
            return true
        }
        if self.showChargeNotch, self.percent >= 75,
           self.percent < Double(Constants.BatteryThresholds.chargeLimit)
        {
            return true
        }
        return false
    }

    private var shimmerLength: Double {
        let minLength = ChargingAnimation.shimmerMinLength
        guard self.position > 0 else { return minLength }
        let proportional = self.position * 0.4
        return max(minLength, min(0.04, proportional))
    }

    private var tier: BatteryTier {
        BatteryTier(percent: self.percent)
    }

    private var progressAnimation: Animation? {
        self.reduceMotion ? nil : Animation.easeOut(duration: RevealTiming.arcSweep)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.white.opacity(self.isMini ? 0.08 : self.trackBreathOpacity),
                    style: StrokeStyle(lineWidth: self.line, lineCap: .round)
                )

            Circle()
                .trim(from: 0.0, to: CGFloat(self.position))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: self.tier.gradientColors),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(max(self.position, 0.001) * 360)
                    ),
                    style: StrokeStyle(lineWidth: self.line, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(
                    color: !self.isMini && (self.isCharging || self.percent >= 100)
                        ? self.tier.dotColor.opacity(self.glowOpacity)
                        : .clear,
                    radius: 8
                )

            if self.showChargeNotch, !self.isMini {
                let notchFraction = Double(Constants.BatteryThresholds.chargeLimit) / 100.0
                let notchAngle = notchFraction * 360.0
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.white.opacity(0.30))
                    .frame(width: 2, height: 6)
                    .offset(y: -(self.size.height / 2))
                    .rotationEffect(.degrees(notchAngle))
                    .shadow(
                        color: self.notchGlowActive
                            ? BatteryTier.chargingBoltColor.opacity(0.6) : .clear,
                        radius: 4
                    )
                    .allowsHitTesting(false)
            }

            if !self.isMini, self.isCharging, self.percent < 100, !self.reduceMotion, self.position > 0 {
                Circle()
                    .trim(
                        from: max(0, self.shimmerPhase * self.position - self.shimmerLength),
                        to: min(self.position, self.shimmerPhase * self.position + self.shimmerLength)
                    )
                    .stroke(
                        Color.white.opacity(0.2),
                        style: StrokeStyle(lineWidth: self.line, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            if self.showDot {
                Circle()
                    .fill(self.tier.dotColor)
                    .frame(width: self.line, height: self.line)
                    .scaleEffect(self.isMini ? 1.0 : self.dotScale)
                    .shadow(color: self.isMini ? .clear : self.tier.dotColor.opacity(0.5), radius: 4)
                    .offset(y: -(self.size.height / 2))
                    .rotationEffect(.degrees(Double(self.position) * 360))
            }

            if !self.isMini, self.burstOpacity > 0 {
                Circle()
                    .fill(self.tier.dotColor)
                    .frame(width: self.size.width, height: self.size.height)
                    .scaleEffect(self.burstScale)
                    .opacity(self.burstOpacity)
            }
        }
        .frame(width: self.size.width, height: self.size.height, alignment: .center)
        .animation(.easeInOut(duration: 0.6), value: self.tier)
        .onAppear {
            if let animation = self.progressAnimation {
                withAnimation(animation) {
                    self.position = self.progress
                }
            } else {
                self.position = self.progress
            }
            self.startChargingAnimations()
        }
        .onChange(of: self.progress) { _, newProgress in
            if let animation = self.progressAnimation {
                withAnimation(animation) {
                    self.position = newProgress
                }
            } else {
                self.position = newProgress
            }
        }
        .onChange(of: self.isCharging) { _, _ in
            self.startChargingAnimations()
        }
        .onChange(of: self.percent) { oldPercent, newPercent in
            if oldPercent < 100, newPercent >= 100, !self.isMini, !self.reduceMotion {
                self.triggerFullBurst()
            }
            // Transition glow state when crossing the 100% boundary in either direction
            if (oldPercent < 100) != (newPercent < 100) {
                self.startChargingAnimations()
            }
            if self.showChargeNotch, !self.isMini, !self.reduceMotion,
               oldPercent < Double(Constants.BatteryThresholds.chargeLimit),
               newPercent >= Double(Constants.BatteryThresholds.chargeLimit)
            {
                self.notchGlowActive = true
                withAnimation(.easeOut(duration: ChargingAnimation.notchGlowDuration)) {
                    self.notchGlowActive = false
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func startChargingAnimations() {
        guard !self.isMini else { return }

        if self.isCharging, self.percent < 100 {
            guard !self.reduceMotion else {
                self.glowOpacity = ChargingAnimation.glowStaticOpacity
                return
            }
            self.glowOpacity = ChargingAnimation.glowMinOpacity
            withAnimation(.easeInOut(duration: ChargingAnimation.glowPeriod).repeatForever(autoreverses: true)) {
                self.glowOpacity = ChargingAnimation.glowMaxOpacity
            }
            self.shimmerPhase = 0.0
            withAnimation(.linear(duration: ChargingAnimation.shimmerPeriod).repeatForever(autoreverses: false)) {
                self.shimmerPhase = 1.0
            }
            self.dotScale = ChargingAnimation.dotMinScale
            withAnimation(.easeInOut(duration: ChargingAnimation.dotPulsePeriod).repeatForever(autoreverses: true)) {
                self.dotScale = ChargingAnimation.dotMaxScale
            }
            self.trackBreathOpacity = ChargingAnimation.trackMinOpacity
            withAnimation(
                .easeInOut(duration: ChargingAnimation.trackBreathePeriod).repeatForever(autoreverses: true)
            ) {
                self.trackBreathOpacity = ChargingAnimation.trackMaxOpacity
            }
        } else if self.percent >= 100 {
            if self.reduceMotion {
                self.glowOpacity = ChargingAnimation.glowStaticOpacity
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.glowOpacity = ChargingAnimation.glowMaxOpacity
                }
            }
            self.dotScale = ChargingAnimation.dotMinScale
            self.trackBreathOpacity = ChargingAnimation.trackMinOpacity
            self.shimmerPhase = 0.0
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.glowOpacity = 0.0
            }
            self.dotScale = ChargingAnimation.dotMinScale
            self.trackBreathOpacity = ChargingAnimation.trackMinOpacity
            self.shimmerPhase = 0.0
        }
    }

    private func triggerFullBurst() {
        self.burstScale = 1.0
        self.burstOpacity = ChargingAnimation.burstStartOpacity
        withAnimation(.easeOut(duration: ChargingAnimation.fullBurstDuration)) {
            self.burstScale = ChargingAnimation.burstMaxScale
            self.burstOpacity = 0.0
        }
    }
}

struct RadialProgressMiniContainer: View {
    @Environment(AppEnvironment.self) private var env

    private var bluetooth: any BluetoothServiceProtocol {
        self.env.bluetooth
    }

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    @State private var device: BluetoothObject?
    @State private var progress: Double = 0.0
    @State private var percent: Int = 100

    private let isSelected: Bool

    init(_ device: BluetoothObject?, isSelected: Bool) {
        _device = State(initialValue: device)
        self.isSelected = isSelected
    }

    var body: some View {
        ZStack {
            RadialProgressBar(
                self.$progress,
                size: .init(width: Constants.Progress.miniSize, height: Constants.Progress.miniSize),
                line: 4,
                percent: Double(self.percent),
                isCharging: false,
                isMini: true
            )

            VStack {
                Text("\(self.percent)")
                    .foregroundColor(self.isSelected ? Color("BBSurface") : Color("BBTitle"))
                    .font(Typography.caption)
            }
        }
        .frame(width: Constants.Progress.miniSize, height: Constants.Progress.miniSize)
        .onAppear {
            if let device = self.device {
                if let percent = device.battery.percent {
                    self.progress = percent / 100
                    self.percent = Int(percent)
                }
            } else {
                self.percent = Int(self.battery.percentage)
                self.progress = self.battery.percentage / 100
            }
        }
        .onChange(of: self.bluetooth.list.first(where: { $0.address == self.device?.address })) { _, device in
            if let battery = device?.battery {
                if let percent = battery.percent {
                    self.progress = percent / 100
                    self.percent = Int(percent)
                }
            } else {
                self.percent = Int(self.battery.percentage)
                self.progress = self.battery.percentage / 100
            }
        }
    }
}

struct RadialProgressContainer: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var window: any WindowServiceProtocol {
        self.env.window
    }

    private var battery: any BatteryServiceProtocol {
        self.env.battery
    }

    @State private var percent: Int?
    @State private var progress: Double = 0.0
    @State private var animate: Bool
    @State private var textVisible: Bool = false
    @State private var isHovered: Bool = false
    @State private var showConnectionCheckmark: Bool = false

    init(_ animate: Bool) {
        _animate = State(initialValue: animate)
    }

    private var deviceChangeAnimation: Animation? {
        self.reduceMotion ? nil : Animation.easeOut(duration: 0.4)
    }

    private var currentPercent: Double {
        Double(self.percent ?? 0)
    }

    private var isCharging: Bool {
        self.env.window.currentDevice == nil && self.battery.charging.state == .charging
    }

    private var textRevealBlur: CGFloat {
        guard !self.textVisible else { return 0.0 }
        return self.window.state == .hidden ? 0.0 : 4.0
    }

    private var textRevealOpacity: Double {
        self.textVisible ? 1.0 : 0.0
    }

    var body: some View {
        ZStack {
            if self.showConnectionCheckmark {
                self.connectionCheckmarkView
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Circle()
                    .stroke(BatteryTier.trackColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .padding(5)

                RadialProgressBar(
                    self.$progress,
                    size: .init(width: 80, height: 80),
                    percent: self.currentPercent,
                    isCharging: self.isCharging,
                    showChargeNotch: self.env.settings.chargeEighty == .enabled
                )

                ZStack(alignment: .center) {
                    Text("\(self.percent ?? 0)")
                        .foregroundColor(Color("BBTitle"))
                        .font(Typography.progressLarge)
                        .blur(radius: self.percent == nil ? 5.0 : (self.isHovered ? 4.0 : 0.0))
                        .opacity(self.percent == nil ? 0.0 : (self.isHovered ? 0.0 : 1.0))

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color("BBSubtitle"))
                        .blur(radius: self.isHovered ? 0.0 : 4.0)
                        .opacity(self.isHovered ? 1.0 : 0.0)

                    Text("AlertDeviceUnknownTitle".localise())
                        .foregroundColor(Color("BBTitle").opacity(0.4))
                        .font(Typography.heading)
                        .blur(radius: (self.isHovered || self.percent != nil) ? 5.0 : 0.0)
                        .opacity((self.isHovered || self.percent != nil) ? 0.0 : 1.0)
                }
                .frame(width: Constants.Progress.containerSize)
                .blur(radius: self.textRevealBlur)
                .opacity(self.textRevealOpacity)
            }
        }
        .frame(width: 90, height: 90)
        .padding(10)
        .contentShape(Circle())
        .onHover { hovering in
            guard self.window.state == .revealed else { return }
            if self.reduceMotion {
                self.isHovered = hovering
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    self.isHovered = hovering
                }
            }
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onTapGesture {
            guard self.window.state == .revealed else { return }
            self.window.toggleExpanded()
        }
        .onAppear {
            self.updatePercentOnly()
            if !self.animate || self.window.state == .revealed || self.window.state == .detailed {
                self.textVisible = true
            }
        }
        .onChange(of: self.window.state) { _, newValue in
            if newValue == .revealed, self.animate {
                Task {
                    try? await Task.sleep(for: .milliseconds(Int(RevealTiming.arcSweepDelay * 1000)))
                    self.updateProgress()
                    if self.reduceMotion {
                        self.textVisible = true
                    } else {
                        withAnimation(.easeOut(duration: RevealTiming.arcSweep)) {
                            self.textVisible = true
                        }
                    }
                }
            }
            if newValue == .detailed || !newValue.visible {
                if self.isHovered {
                    self.isHovered = false
                    NSCursor.pop()
                }
            }
            if !newValue.visible {
                self.textVisible = false
            }
        }
        .onChange(of: self.battery.percentage) { _, newPercentage in
            if let devicePercent = self.env.window.currentDevice?.battery.percent {
                self.progress = devicePercent / 100
                self.percent = Int(devicePercent)
            } else {
                self.percent = Int(newPercentage)
                self.progress = newPercentage / 100
            }
        }
        .onChange(of: self.env.window.currentDevice) { _, newDevice in
            if let animation = self.deviceChangeAnimation {
                withAnimation(animation) {
                    self.updateProgressForDevice(newDevice)
                }
            } else {
                self.updateProgressForDevice(newDevice)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AccessibilityBatteryProgress".localise())
        .accessibilityValue(self.percent.map { "\($0) percent" } ?? "Not available")
        .accessibilityHint("AccessibilityOpenSettings".localise())
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { self.window.toggleExpanded() }
    }

    @ViewBuilder
    private var connectionCheckmarkView: some View {
        let isDisconnect = self.window.currentAlert == .deviceRemoved
        Image(systemName: isDisconnect ? "xmark.circle.fill" : "checkmark.circle.fill")
            .font(.system(size: 42, weight: .medium))
            .foregroundStyle(isDisconnect
                ? Color.gray
                : Color(red: 0.290, green: 0.871, blue: 0.502))
            .symbolEffect(.bounce, options: .nonRepeating, value: self.showConnectionCheckmark)
            .shadow(
                color: (isDisconnect ? Color.gray : Color(red: 0.290, green: 0.871, blue: 0.502))
                    .opacity(0.3),
                radius: 8
            )
    }

    private func updatePercentOnly() {
        if let device = self.env.window.currentDevice {
            if let percent = device.battery.percent {
                self.percent = Int(percent)
                self.showConnectionCheckmark = false
            } else {
                self.percent = nil
                let isDeviceAlert = self.window.currentAlert == .deviceConnected
                    || self.window.currentAlert == .deviceRemoved
                self.showConnectionCheckmark = isDeviceAlert
            }
        } else {
            self.percent = Int(self.battery.percentage)
            self.showConnectionCheckmark = false
        }
        if self.animate {
            self.progress = 0.0
        }
    }

    private func updateProgress() {
        if let device = self.env.window.currentDevice {
            if let percent = device.battery.percent {
                self.progress = percent / 100
                self.percent = Int(percent)
            } else {
                self.progress = 0.0
                self.percent = nil
            }
        } else {
            self.progress = self.battery.percentage / 100
            self.percent = Int(self.battery.percentage)
        }
    }

    private func updateProgressForDevice(_ device: BluetoothObject?) {
        if let device {
            if let devicePercent = device.battery.percent {
                if self.showConnectionCheckmark {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        self.showConnectionCheckmark = false
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(200))
                        guard !Task.isCancelled else { return }
                        self.progress = 0.0
                        self.percent = Int(devicePercent)
                        withAnimation(.easeOut(duration: RevealTiming.arcSweep)) {
                            self.progress = devicePercent / 100
                        }
                    }
                } else {
                    self.progress = devicePercent / 100
                    self.percent = Int(devicePercent)
                }
            } else {
                self.progress = 0.0
                self.percent = nil
                let isDeviceAlert = self.window.currentAlert == .deviceConnected
                    || self.window.currentAlert == .deviceRemoved
                self.showConnectionCheckmark = isDeviceAlert
            }
        } else {
            self.progress = self.battery.percentage / 100
            self.percent = Int(self.battery.percentage)
            self.showConnectionCheckmark = false
        }
    }
}
