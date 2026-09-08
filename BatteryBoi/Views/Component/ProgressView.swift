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

    @State private var glowOpacity: Double = 0.0
    @State private var shimmerPhase: Double = 0.0
    @State private var dotScale: CGFloat = 1.0
    @State private var trackBreathOpacity: Double = 0.08
    @State private var burstScale: CGFloat = 1.0
    @State private var burstOpacity: Double = 0.0

    init(
        _ progress: Binding<Double>,
        size: CGSize,
        line: CGFloat = 10,
        percent: Double,
        isCharging: Bool,
        isMini: Bool = false
    ) {
        _progress = progress
        _size = State(initialValue: size)
        _line = State(initialValue: line)
        self.percent = percent
        self.isCharging = isCharging
        self.isMini = isMini
    }

    private var tier: BatteryTier {
        BatteryTier(percent: self.percent)
    }

    private var progressAnimation: Animation? {
        self.reduceMotion ? nil : Animation.easeOut(duration: 0.6)
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
                        center: .center
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

            if !self.isMini, self.isCharging, self.percent < 100, !self.reduceMotion, self.position > 0 {
                Circle()
                    .trim(
                        from: max(0, self.shimmerPhase * self.position - 0.04),
                        to: min(self.position, self.shimmerPhase * self.position + 0.04)
                    )
                    .stroke(
                        Color.white.opacity(0.2),
                        style: StrokeStyle(lineWidth: self.line, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .fill(self.tier.dotColor)
                .frame(width: self.line, height: self.line)
                .scaleEffect(self.isMini ? 1.0 : self.dotScale)
                .rotationEffect(.degrees(Double(self.position) * 360 - 90))
                .offset(y: -(self.size.height / 2))

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
                withAnimation(animation.delay(0.1)) {
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
        }
        .accessibilityHidden(true)
    }

    private func startChargingAnimations() {
        guard !self.isMini else { return }

        if self.isCharging, self.percent < 100 {
            guard !self.reduceMotion else {
                self.glowOpacity = 0.4
                return
            }
            self.glowOpacity = 0.3
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                self.glowOpacity = 0.5
            }
            self.shimmerPhase = 0.0
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                self.shimmerPhase = 1.0
            }
            self.dotScale = 1.0
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                self.dotScale = 1.3
            }
            self.trackBreathOpacity = 0.08
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                self.trackBreathOpacity = 0.12
            }
        } else if self.percent >= 100 {
            if self.reduceMotion {
                self.glowOpacity = 0.4
            } else {
                withAnimation(.easeInOut(duration: 0.6)) {
                    self.glowOpacity = 0.5
                }
            }
            self.dotScale = 1.0
            self.trackBreathOpacity = 0.08
            self.shimmerPhase = 0.0
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                self.glowOpacity = 0.0
            }
            self.dotScale = 1.0
            self.trackBreathOpacity = 0.08
            self.shimmerPhase = 0.0
        }
    }

    private func triggerFullBurst() {
        self.burstScale = 1.0
        self.burstOpacity = 0.4
        withAnimation(.easeOut(duration: 1.2)) {
            self.burstScale = 1.15
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
                size: .init(width: 28, height: 28),
                line: 4,
                percent: Double(self.percent),
                isCharging: false,
                isMini: true
            )

            VStack {
                Text("\(self.percent)")
                    .foregroundColor(self.isSelected ? Color("BatteryButton") : Color("BatteryTitle"))
                    .font(Typography.caption)
            }
        }
        .frame(width: 28, height: 28)
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

    var body: some View {
        ZStack {
            Circle()
                .stroke(BatteryTier.trackColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .padding(5)

            RadialProgressBar(
                self.$progress,
                size: .init(width: 80, height: 80),
                percent: self.currentPercent,
                isCharging: self.isCharging
            )

            ZStack(alignment: .center) {
                Text("\(self.percent ?? 0)")
                    .foregroundColor(Color("BatteryTitle"))
                    .font(Typography.progressLarge)
                    .blur(radius: self.percent == nil ? 5.0 : 0.0)
                    .opacity(self.percent == nil ? 0.0 : 1.0)

                Text("AlertDeviceUnknownTitle".localise())
                    .foregroundColor(Color("BatteryTitle").opacity(0.4))
                    .font(Typography.heading)
                    .blur(radius: self.percent == nil ? 0.0 : 5.0)
                    .opacity(self.percent == nil ? 1.0 : 0.0)
            }
            .frame(width: 90)
        }
        .frame(width: 90, height: 90)
        .padding(10)
        .onAppear {
            let animationDuration = (self.animate && !self.reduceMotion) ? 1.2 : 0.0
            if animationDuration > 0 {
                withAnimation(Animation.easeOut(duration: animationDuration)) {
                    self.updateProgress()
                }
            } else {
                self.updateProgress()
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
                self.progress = devicePercent / 100
                self.percent = Int(devicePercent)
            } else {
                self.progress = 0.0
                self.percent = nil
            }
        } else {
            self.progress = self.battery.percentage / 100
            self.percent = Int(self.battery.percentage)
        }
    }
}
