import SwiftUI

// Types (HUDState, HUDAlertTypes, HUDProgressLayout) are now defined in BatteryBoi/Models/HUDModels.swift

struct HUDIcon: View {
    @Environment(\.appEnvironment) private var env

    private var stats: StatsService {
        env.stats
    }

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
    @Environment(\.appEnvironment) private var env
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var stats: StatsService {
        env.stats
    }

    private var updates: UpdateManager {
        env.update
    }

    private var window: any WindowServiceProtocol {
        env.window
    }

    @State private var title = ""
    @State private var subtitle = ""
    @State private var visible: Bool = false

    var body: some View {
        HStack(alignment: .center) {
            HUDIcon()

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.titleBold)
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
            visible = window.state.visible

        }
        .onChange(of: stats.title) { _, newValue in
            title = newValue

        }
        .onChange(of: stats.subtitle) { _, newValue in
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
    @Environment(\.appEnvironment) private var env

    private var battery: any BatteryServiceProtocol {
        env.battery
    }

    private var window: any WindowServiceProtocol {
        env.window
    }

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
    @Environment(\.appEnvironment) private var env

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
    @Environment(\.appEnvironment) private var env

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
    @Environment(\.appEnvironment) private var env

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
            .onChange(of: window.state) { _, newValue in
                if let animation = newValue.progress {
                    timeline = animation

                }

            }

    }

}

struct HUDView: View {
    @Environment(\.appEnvironment) private var env

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
        .frame(minWidth: 380, idealWidth: 440, maxWidth: 500)
        .frame(minHeight: 200, idealHeight: 240, maxHeight: 280)
        .background(
            Color("BatteryBackground").opacity(window.opacity)

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
