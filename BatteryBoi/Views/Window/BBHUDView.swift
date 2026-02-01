//
//  BBHUDView.swift
//  BatteryBoi
//
//  Created by Joe Barbour on 9/12/23.
//

import SwiftUI

enum HUDAlertTypes: Int {
    case chargingComplete
    case chargingBegan
    case chargingStopped
    case percentFive
    case percentTen
    case percentTwentyFive
    case percentOne
    case userInitiated
    case userLaunched
    case userEvent
    case deviceOverheating
    case deviceConnected
    case deviceRemoved
    case deviceDistance

    var sfx: SystemSoundEffects? {
        switch self {
        case .chargingBegan: .high
        case .chargingComplete: .high
        case .chargingStopped: .low
        case .percentTwentyFive: .low
        case .percentTen: .low
        case .percentFive: .low
        case .percentOne: .low
        case .userLaunched: nil
        case .userInitiated: nil
        case .userEvent: .low
        case .deviceOverheating: .low
        case .deviceRemoved: .low
        case .deviceConnected: .high
        case .deviceDistance: .low
        }

    }

    var trigger: Bool {
        switch self {
        case .chargingBegan: true
        case .chargingComplete: true
        case .chargingStopped: true
        case .deviceRemoved: true
        case .deviceConnected: true
        default: false
        }

    }

    var timeout: Bool {
        switch self {
        case .userLaunched: false
        case .userInitiated: false
        default: true
        }

    }

}

enum HUDProgressLayout {
    case center
    case trailing

}

enum HUDState: Equatable {
    case hidden
    case progress
    case revealed
    case detailed
    case dismissed

    var visible: Bool {
        switch self {
        case .detailed: true
        case .revealed: true
        default: false
        }

    }

    var mask: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.6, delay: 0.2, easing: .bounce, width: 120, height: 120, blur: 0, radius: 66),
                .init(2.9, easing: .bounce, width: 430, height: 120, blur: 0, radius: 66),
            ], id: "initial")

        } else if self == .detailed {
            return .init([.init(0.0, easing: .bounce, width: 440, height: 220, radius: 42)], id: "expand_out")

        } else if self == .dismissed {
            return .init(
                [
                    .init(0.2, easing: .bounce, width: 430, height: 120, radius: 66),
                    .init(0.2, easing: .easeout, width: 120, height: 120, radius: 66),
                    .init(0.3, delay: 1.0, easing: .bounce, width: 40, height: 40, opacity: 0, radius: 66),
                ],
                id: "expand_close",
            )

        }

        return nil

    }

    var glow: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.03, easing: .easeout, opacity: 0.0, scale: 0.2),
                .init(0.4, easing: .bounce, opacity: 0.4, scale: 1.9),
                .init(0.4, easing: .easein, opacity: 0.0, blur: 2.0),
            ])

        } else if self == .dismissed {
            return .init([
                .init(0.03, easing: .easeout, opacity: 0.0, scale: 0.2),
                .init(0.4, easing: .easein, opacity: 0.6, scale: 1.4),
                .init(0.2, easing: .bounce, opacity: 0.0, scale: 0.2),
            ])

        }

        return nil

    }

    var progress: AnimationObject? {
        if self == .revealed {
            return .init([
                .init(0.2, easing: .bounce, opacity: 0.0, blur: 0.0, scale: 0.8),
                .init(0.4, delay: 0.4, easing: .easeout, opacity: 1.0, scale: 1.0),
            ])

        } else if self == .dismissed {
            return .init([.init(0.6, easing: .bounce, opacity: 0.0, blur: 12.0, scale: 0.9)])

        }

        return nil

    }

    var container: AnimationObject? {
        if self == .detailed {
            return .init([.init(0.4, easing: .easeout, padding: .init(top: 24, bottom: 16))], id: "hud_expand")

        } else if self == .dismissed {
            return .init([.init(0.6, delay: 0.2, easing: .easeout, opacity: 0.0, blur: 5.0)])

        }

        return nil

    }

}

struct HUDIcon: View {
    @EnvironmentObject var stats: StatsManager

    @Namespace private var animation

    var body: some View {
        VStack {
            ZStack {
                if stats.statsIcon.system == true {
                    Image(systemName: stats.statsIcon.name)
                        .resizable()
                        .aspectRatio(contentMode: .fit).matchedGeometryEffect(id: "icon", in: animation)

                } else {
                    Image(stats.statsIcon.name)
                        .resizable()
                        .aspectRatio(contentMode: .fit).matchedGeometryEffect(id: "icon", in: animation)

                }

            }
            .frame(width: 28, height: 28)
            .foregroundColor(Color("BatterySubtitle"))
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
    @EnvironmentObject var stats: StatsManager
    @EnvironmentObject var updates: UpdateManager
    @EnvironmentObject var window: WindowManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var title = ""
    @State private var subtitle = ""
    @State private var visible: Bool = false

    var body: some View {
        HStack(alignment: .center) {
            HUDIcon()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                ViewMarkdown($subtitle)

                if updates.available != nil {
                    UpdatePromptView()

                }

            }

            Spacer()

        }
        .blur(radius: visible ? 0.0 : 4.0)
        .opacity(visible ? 1.0 : 0.0)
        .onAppear {
            title = stats.title
            subtitle = stats.subtitle
            visible = WindowManager.shared.state.visible

        }
        .onChange(of: stats.title) { newValue in
            title = newValue

        }
        .onChange(of: stats.subtitle) { newValue in
            subtitle = newValue

        }
        .onChange(of: window.state) { _, newValue in
            if reduceMotion {
                visible = newValue.visible
            } else {
                withAnimation(Animation.easeOut(duration: 0.6).delay(visible == false ? 0.9 : 0.0)) {
                    visible = newValue.visible
                }
            }

        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")

    }

}

struct HUDContainer: View {
    @EnvironmentObject var battery: BatteryManager
    @EnvironmentObject var window: WindowManager

    @State private var timeline: AnimationObject
    @State private var namespace: Namespace.ID
    @State private var animation: AnimationState = .waiting

    @Binding private var progress: HUDProgressLayout

    init(animation: Namespace.ID, progress: Binding<HUDProgressLayout>) {
        _namespace = State(initialValue: animation)
        _timeline = State(initialValue: .init([]))
        _progress = progress

    }

    var body: some View {
        HStack(alignment: .center) {
            HUDSummary()

            if progress == .trailing {
                HUDProgress().matchedGeometryEffect(id: "progress", in: namespace)

            }

        }
        .timeline($timeline, state: $animation)
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .onAppear {
            if let animation = window.state.container {
                timeline = animation

            }

        }
        .onChange(of: window.state) { _, newValue in
            if let animation = newValue.container {
                timeline = animation

            }

            if newValue == .revealed {
                withAnimation(Animation.easeOut.delay(0.75)) {
                    progress = .trailing

                }

            }

        }

    }

}

struct HUDMaskView: View {
    @EnvironmentObject var window: WindowManager

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting

    var keyframes = [AnimationKeyframeObject]()

    init() {
        _timeline = State(initialValue: .init([]))

    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .timeline($timeline, state: $animation)
                .frame(width: 20, height: 20)

        }
        .onAppear {
            if let animation = window.state.mask {
                timeline = animation

            }

        }
        .onChange(of: window.state) { _, newValue in
            if let animation = newValue.mask {
                timeline = animation

            }

        }

    }

}

struct HUDGlow: View {
    @EnvironmentObject var window: WindowManager

    @State private var timeline: AnimationObject
    @State private var animation: AnimationState = .waiting

    init() {
        _timeline = State(initialValue: .init([]))

    }

    var body: some View {
        Circle()
            .fill(Color("BatteryBackground"))
            .frame(width: 80, height: 80)
            .timeline($timeline, state: $animation)
            .onAppear {
                if let animation = window.state.glow {
                    timeline = animation

                }

            }
            .onChange(of: window.state) { _, newValue in
                if let animation = newValue.glow {
                    timeline = animation

                }

            }

    }

}

struct HUDProgress: View {
    @EnvironmentObject var window: WindowManager

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
            .onChange(of: window.state) { _, newValue in
                if let animation = newValue.progress {
                    timeline = animation

                }

            }

    }

}

struct HUDView: View {
    @EnvironmentObject var window: WindowManager

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
                    HUDContainer(animation: namespace, progress: $progress)
                        .matchedGeometryEffect(id: "hud", in: namespace)

                    NavigationContainer()

                } else {
                    HUDContainer(animation: namespace, progress: $progress)
                        .matchedGeometryEffect(id: "hud", in: namespace)

                }

            }

            if progress == .center {
                HUDProgress().matchedGeometryEffect(id: "progress", in: namespace)

            }

        }
        .frame(width: 440, height: 240)
        .background(
            Color("BatteryBackground").opacity(window.opacity),

        )
        .timeline($timeline, state: $animation)
        .mask(
            HUDMaskView(),

        )
        .background(
            HUDGlow(),

        )
        .onHover(perform: { hover in
            window.hover = hover

        })
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Battery status notification")
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
        .environmentObject(WindowManager.shared)
        .environmentObject(AppManager.shared)
        .environmentObject(BatteryManager.shared)
        .environmentObject(SettingsManager.shared)
        .environmentObject(UpdateManager.shared)
        .environmentObject(StatsManager.shared)
        .environmentObject(BluetoothManager.shared)

    }

}
