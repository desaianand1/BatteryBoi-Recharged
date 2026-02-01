import Foundation
import SwiftUI

enum AnimationState {
    case waiting
    case playing
    case complete
    case paused

}

enum AnimationControls {
    case play
    case reset

}

enum AnimationEasingType {
    case linear
    case easein
    case easeout
    case bounce

}

struct AnimationPadding: Equatable {
    var top: CGFloat = 0.0
    var leading: CGFloat = 0.0
    var trailing: CGFloat = 0.0
    var bottom: CGFloat = 0.0

}

struct AnimationKeyframeObject: Equatable {
    var width: CGFloat?
    var height: CGFloat?
    var opacity: CGFloat = 1.0
    var blur: CGFloat = 0.0
    var radius: CGFloat = 0.0
    var scale: CGFloat = 1.0
    var rotate: CGFloat = 0.0
    var duration: CGFloat
    var delay: CGFloat
    var padding: AnimationPadding
    var easing: AnimationEasingType

    init(
        _ duration: CGFloat,
        delay: CGFloat = 0.0,
        easing: AnimationEasingType = .linear,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        opacity: CGFloat = 1.0,
        blur: CGFloat = 0.0,
        radius: CGFloat = 0.0,
        scale: CGFloat = 1.0,
        rotate: CGFloat = 0.0,
        padding: AnimationPadding? = nil,
    ) {
        self.width = width
        self.height = height
        self.opacity = opacity
        self.blur = blur
        self.radius = radius
        self.scale = scale
        self.rotate = rotate
        self.duration = duration
        self.delay = delay
        self.easing = easing
        self.padding = padding ?? .init()

    }

}

struct AnimationObject: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id

    }

    var loop: Int
    var keyframes: [AnimationKeyframeObject]
    var id: String?
    var autoplay: Bool

    init(
        _ keyframes: [AnimationKeyframeObject],
        loop: Int = 1,
        easing _: AnimationEasingType = .linear,
        id: String? = nil,
        autoplay: Bool = true,
    ) {
        self.loop = loop
        self.keyframes = keyframes
        self.id = id ?? UUID().uuidString
        self.autoplay = autoplay

    }

}

struct AnimationModifier: ViewModifier {
    @Binding var keyframes: AnimationObject
    @Binding var state: AnimationState

    @State private var width: CGFloat?
    @State private var height: CGFloat?
    @State private var opacity: CGFloat = 1.0
    @State private var blur: CGFloat = 0.0
    @State private var radius: CGFloat = 0.0
    @State private var scale: CGFloat = 1.0
    @State private var rotate: CGFloat = 0.0

    @State private var paddingTop: CGFloat = 0.0
    @State private var paddingLeading: CGFloat = 0.0
    @State private var paddingTrailing: CGFloat = 0.0
    @State private var paddingBottom: CGFloat = 0.0

    /// Task for running keyframe animations. Cancelled when view disappears.
    @State private var animationTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .frame(width: width, height: height)
            .opacity(opacity)
            .cornerRadius(radius)
            .blur(radius: blur)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotate))
            .padding(.top, paddingTop)
            .padding(.leading, paddingLeading)
            .padding(.trailing, paddingTrailing)
            .padding(.bottom, paddingBottom)
            .onAppear {
                if keyframes.autoplay == true {
                    state = .playing
                    startAnimation(index: 0)
                }
            }
            .onDisappear {
                // Cancel any pending animation when view disappears
                animationTask?.cancel()
                animationTask = nil
            }
            .onChange(of: keyframes) { _, newKeyframes in
                // Cancel previous animation before starting new one
                animationTask?.cancel()
                if newKeyframes.autoplay == true {
                    state = .playing
                    startAnimation(index: 0)
                }
            }
    }

    /// Starts the animation sequence using a cancellable Task
    private func startAnimation(index: Int) {
        animationTask?.cancel()
        animationTask = Task { @MainActor in
            await animateAsync(index: index)
        }
    }

    /// Async version of animate that uses Task.sleep instead of DispatchQueue
    func animateAsync(index: Int = 0) async {
        guard !Task.isCancelled, index < keyframes.keyframes.count else {
            if !Task.isCancelled {
                state = .complete
            }
            return
        }

        let current = keyframes.keyframes[index]

        // Apply animation based on easing type
        applyKeyframe(current)

        // Wait for animation to complete using Task.sleep
        let totalDuration = current.duration + current.delay
        do {
            try await Task.sleep(for: .seconds(totalDuration))
            guard !Task.isCancelled else { return }
            await animateAsync(index: index + 1)
        } catch {
            // Task was cancelled, stop animation
        }
    }

    /// Applies a single keyframe animation
    private func applyKeyframe(_ current: AnimationKeyframeObject) {
        let animation: Animation = switch current.easing {
        case .linear:
            .linear(duration: current.duration)
        case .easein:
            .easeIn(duration: current.duration)
        case .easeout:
            .easeOut(duration: current.duration)
        case .bounce:
            .interactiveSpring(response: 0.4, dampingFraction: 0.7, blendDuration: current.duration)
        }

        withAnimation(animation) {
            width = current.width
            height = current.height
            opacity = current.opacity
            blur = current.blur
            radius = current.radius
            scale = current.scale
            rotate = current.rotate
            paddingTop = current.padding.top
            paddingLeading = current.padding.leading
            paddingTrailing = current.padding.trailing
            paddingBottom = current.padding.bottom
        }
    }

}

extension View {
    func timeline(_ animation: Binding<AnimationObject>, state: Binding<AnimationState>) -> some View {
        modifier(AnimationModifier(keyframes: animation, state: state))

    }

}
