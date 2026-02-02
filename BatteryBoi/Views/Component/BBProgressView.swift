import DynamicColor
import SwiftUI

enum RadialStyle {
    case dark
    case light
    case colour

    var background: Color {
        switch self {
        case .dark: Color("BatteryTitle")
        case .light: Color("BatteryDefault")
        case .colour: Color("BatteryProgressGreen")
        }

    }

}

struct RadialProgressBar: View {
    @Binding var progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var size: CGSize
    @State private var line: CGFloat
    @State private var position: Double = 0.0

    @Binding var style: RadialStyle

    init(_ progress: Binding<Double>, size: CGSize, line: CGFloat = 10, style: Binding<RadialStyle>) {
        _progress = progress
        _size = State(initialValue: size)
        _line = State(initialValue: line)

        _style = style

    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : Animation.easeOut(duration: 0.6)
    }

    var body: some View {
        ZStack {
            if style == .dark {
                Circle()
                    .trim(from: 0.0, to: CGFloat(position))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color("BatteryTitle"), Color("BatteryTitle").opacity(0.96)]),
                            center: .center,
                        ),
                        style: StrokeStyle(lineWidth: line, lineCap: .round),

                    )
                    .rotationEffect(.degrees(-90))

            } else if style == .light {
                Circle()
                    .trim(from: 0.0, to: CGFloat(position))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color("BatteryButton"), Color("BatteryButton").opacity(0.96)]),
                            center: .center,
                        ),
                        style: StrokeStyle(lineWidth: line, lineCap: .round),

                    )
                    .rotationEffect(.degrees(-90))

            } else {
                Circle()
                    .trim(from: 0.0, to: CGFloat(position))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color("BatteryProgressGreen"), Color.green, Color.green]),
                            center: .center,
                        ),
                        style: StrokeStyle(lineWidth: line, lineCap: .round),
                    )
                    .rotationEffect(.degrees(-90))

            }

            Circle()
                .fill(style.background)
                .frame(width: line, height: line)
                .rotationEffect(.degrees(Double(progress) * 360 - 90))
                .offset(y: -(size.height / 2))

        }
        .frame(width: size.width, height: size.height, alignment: .center)
        .onAppear {
            if let animation = progressAnimation {
                withAnimation(animation.delay(0.1)) {
                    position = progress
                }
            } else {
                position = progress
            }

        }
        .onChange(of: progress) { _, newProgress in
            if let animation = progressAnimation {
                withAnimation(animation) {
                    position = newProgress
                }
            } else {
                position = newProgress
            }

        }
        .accessibilityHidden(true)

    }

}

struct RadialProgressMiniContainer: View {
    private var manager: AppManager {
        AppManager.shared
    }

    private var bluetooth: BluetoothManager {
        BluetoothManager.shared
    }

    private var battery: BatteryManager {
        BatteryManager.shared
    }

    @State private var device: BluetoothObject?
    @State private var progress: Double = 0.0
    @State private var percent: Int = 100

    @Binding private var style: RadialStyle

    init(_ device: BluetoothObject?, style: Binding<RadialStyle>) {
        _device = State(initialValue: device)
        _style = style

    }

    var body: some View {
        ZStack {
            Circle().stroke(Color("BatterySubtitle").opacity(0.08), style: StrokeStyle(lineWidth: 4, lineCap: .round))

            RadialProgressBar($progress, size: .init(width: 28, height: 28), line: 4, style: $style)

            VStack {
                Text("\(percent)")
                    .foregroundColor(style == .light ? Color("BatteryButton") : Color("BatteryTitle"))
                    .font(BBTypography.caption)

            }

        }
        .frame(width: 28, height: 28)
        .onAppear {
            if let device {
                if let percent = device.battery.percent {
                    progress = percent / 100
                    self.percent = Int(percent)

                }

            } else {
                percent = Int(battery.percentage)
                progress = battery.percentage / 100

            }

        }
        .onChange(of: bluetooth.list.first(where: { $0.address == device?.address })) { device in
            if let battery = device?.battery {
                if let percent = battery.percent {
                    progress = percent / 100
                    self.percent = Int(percent)

                }

            } else {
                percent = Int(battery.percentage)
                progress = battery.percentage / 100

            }

        }

    }

}

struct RadialProgressContainer: View {
    private var manager: AppManager {
        AppManager.shared
    }

    private var window: WindowManager {
        WindowManager.shared
    }

    private var battery: BatteryManager {
        BatteryManager.shared
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var percent: Int?
    @State private var progress: Double = 0.0
    @State private var animate: Bool

    init(_ animate: Bool) {
        _animate = State(initialValue: animate)

    }

    private var deviceChangeAnimation: Animation? {
        reduceMotion ? nil : Animation.easeOut(duration: 0.4)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color("BatterySubtitle").opacity(0.08), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .padding(5)

            RadialProgressBar($progress, size: .init(width: 80, height: 80), style: .constant(.colour))

            ZStack(alignment: .center) {
                Text("\(percent ?? 0)")
                    .foregroundColor(Color("BatteryTitle"))
                    .font(BBTypography.progressLarge)
                    .blur(radius: percent == nil ? 5.0 : 0.0)
                    .opacity(percent == nil ? 0.0 : 1.0)

                Text("N/A")
                    .foregroundColor(Color("BatteryTitle").opacity(0.4))
                    .font(BBTypography.heading)
                    .blur(radius: percent == nil ? 0.0 : 5.0)
                    .opacity(percent == nil ? 1.0 : 0.0)

            }
            .frame(width: 90)

        }
        .frame(width: 90, height: 90)
        .padding(10)
        .onAppear {
            let animationDuration = (animate && !reduceMotion) ? 1.2 : 0.0
            if animationDuration > 0 {
                withAnimation(Animation.easeOut(duration: animationDuration)) {
                    updateProgress()
                }
            } else {
                updateProgress()
            }

        }
        .onChange(of: battery.percentage) { _, newPercentage in
            if let devicePercent = manager.device?.battery.percent {
                progress = devicePercent / 100
                percent = Int(devicePercent)

            } else {
                percent = Int(newPercentage)
                progress = newPercentage / 100

            }

        }
        .onChange(of: manager.device) { _, newDevice in
            if let animation = deviceChangeAnimation {
                withAnimation(animation) {
                    updateProgressForDevice(newDevice)
                }
            } else {
                updateProgressForDevice(newDevice)
            }

        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("AccessibilityBatteryProgress".localise())
        .accessibilityValue(percent.map { "\($0) percent" } ?? "Not available")

    }

    private func updateProgress() {
        if let device = manager.device {
            if let percent = device.battery.percent {
                progress = percent / 100
                self.percent = Int(percent)
            } else {
                progress = 0.0
                percent = nil
            }
        } else {
            progress = battery.percentage / 100
            percent = Int(battery.percentage)
        }
    }

    private func updateProgressForDevice(_ device: BluetoothObject?) {
        if let device {
            if let devicePercent = device.battery.percent {
                progress = devicePercent / 100
                percent = Int(devicePercent)
            } else {
                progress = 0.0
                percent = nil
            }
        } else {
            progress = battery.percentage / 100
            percent = Int(battery.percentage)
        }
    }

}
