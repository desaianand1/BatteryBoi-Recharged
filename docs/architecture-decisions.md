# Architecture Decisions

> Record of architectural decisions for BatteryBoi-Recharged.
> This is a living document — update it when decisions change.
> Last updated: 2026-09-15

---

## Current Architecture

```
SwiftUI Views (@Environment(AppEnvironment.self))
        │
AppEnvironment (@Observable @MainActor) — single DI container
├── coordinator: ServiceCoordinator (reactive via ObservationStream)
└── protocol-typed services (battery, bluetooth, window, settings, events, stats)
        │
   ┌────┼─────────────────┐
   ▼    ▼                 ▼
 @MainActor Services   Background Actors    @objc Bridges
 ├── SettingsService   ├── IOKitBattery     └── BluetoothBridge
 ├── WindowService     └── IOKitBluetooth
 ├── BatteryService
 ├── BluetoothService
 ├── EventService
 └── StatsService
```

All services are `@Observable @MainActor` and accessed via protocol interfaces for testability. Background IOKit work is isolated in dedicated actors (`IOKitBatteryService`, `IOKitBluetoothService`). The `BluetoothBridge` handles `@objc` callbacks that can't be made async. `ServiceCoordinator` uses `ObservationStream` for reactive cross-service observation instead of polling loops.

**Key files:**
- `Services/AppEnvironment.swift` — DI container, holds all services
- `Services/ServiceCoordinator.swift` — cross-service communication, alert thresholds
- `Utilities/ObservationStream.swift` — reactive bridge from `@Observable` to `AsyncStream`
- `Protocols/` — protocol definitions for each service

---

## Key Design Decisions

### 1. @MainActor @Observable over Actors for Services

Services are `@MainActor` rather than actors because this is a menu bar app where nearly all state flows to SwiftUI views. Using actors would require constant `await` at every property access in views, adding complexity without benefit. Background IOKit work is handled by separate actor wrappers.

### 2. ~~Centralized AppState~~ — SUPERSEDED

> **Decision superseded.** `AppState` will be eliminated entirely, not slimmed. See `improvements-prd.md` Chunk 6.

**Original rationale:** A single `AppState` object held all UI-relevant state. Views observed this one object rather than individual services.

**Why superseded:** SwiftUI's `@Observable` tracking works at property granularity — views reading `battery.percentage` directly get the same or better invalidation behavior as reading `appState.batteryPercentage`. The ~20 mirrored properties and 7+ polling loops that mirror service state into `AppState` generate ~1,545 CPU wake-ups/minute. The remaining 3 properties (`currentMenu`, `selectedDevice`, `currentAlert`) belong elsewhere:

- `currentMenu` stays on `AppManager.menu` — services already write to it (`WindowService.windowOpen()`, `BluetoothService.init()`), and views already read `manager.menu` via `@Environment`
- `selectedDevice` moves to `@State` in the Bluetooth view hierarchy — no service writes to it; it's set only by user tap
- `currentAlert` is already on `WindowService` (which has `currentAlert` and `currentDevice` as local properties) — the `AppState` copy is redundant

**Migration:** Delete `AppState.swift` and `ServiceContainer.swift`. Views read `@Observable` services directly via `AppEnvironment`. See Decision #5 and `improvements-prd.md` Chunk 6.

### 3. ServiceCoordinator for Cross-Service Logic

Alert threshold logic (e.g., "show HUD when battery drops below 25%") lives in `ServiceCoordinator`, not in individual services. This prevents circular dependencies between services and makes the alert logic testable in isolation.

### 4. Settings-First UI Design

The default menu view is `.settings` (not `.devices`). This matches the original BatteryBoi design intent — the app is primarily a battery monitor with settings controls, not a Bluetooth device manager. The Bluetooth device list is a secondary view.

### 5. Protocol-Based DI via Single Container

Each service implements a protocol (`BatteryServiceProtocol`, `BluetoothServiceProtocol`, etc.) to enable mock-based testing. Tests use mock implementations; production uses real services.

**Done.** `AppEnvironment` is the single DI container. `ServiceContainer.swift` and `AppState.swift` have been deleted. All views use type-based `@Environment(AppEnvironment.self)` injection (macOS 14+).

**WindowHostingView DI:** `WindowHostingView` uses a `scrollHandler: (NSEvent) -> Void` closure set by `WindowService`, avoiding direct singleton access from NSView callbacks.

### 6. NSPanel for HUD Window (not MenuBarExtra or UtilityWindow)

**Decision:** The HUD uses `NSPanel` with `.nonactivatingPanel` style, not SwiftUI's `MenuBarExtra`, `UtilityWindow`, or a plain `NSWindow`.

**Intent:** The HUD must appear autonomously for system events (battery low, charger plug/unplug, device overheating), remain visible while the user works in other apps, support free positioning across 6 anchor points (topLeft, topMiddle, topRight, bottomLeft, bottomMiddle, bottomRight), be draggable with magnetic snap-on-release, support pinned mode, and dismiss only when the app's own mouse monitor detects a click outside.

**Positioning:** `WindowPosition` is a `CaseIterable` enum with 6 cases. The original `.center` case was renamed to `.bottomMiddle` (it was always placed at bottom-center, not true screen-center). Positions use `NSScreen.visibleFrame` (not `.frame`) to respect the menu bar, Dock, notch, and Stage Manager strip. On drag release, the window snaps to the nearest anchor via `WindowPosition.nearest(to:excluding:)` with a minimum drag distance threshold (60pt) to prevent accidental repositioning. Persisted `"center"` values from prior versions are migrated to `.bottomMiddle` on load. Users can also set position via the settings dropdown tile.

**Why not MenuBarExtra (.window style)?** `MenuBarExtra` with `.window` style creates a popover panel that dismisses when focus moves to another app ([Apple docs: MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra); validated against swiftui-expert-skill/macos-scenes.md). This is fatal for a HUD that must appear independently of user interaction — a battery-low alert while the user is typing in Xcode would immediately vanish when they click back.

**Why not UtilityWindow?** `UtilityWindow` explicitly hides when the app is no longer active ([Apple docs: UtilityWindow](https://developer.apple.com/documentation/swiftui/utilitywindow); validated against swiftui-expert-skill/macos-scenes.md). A menu bar app is "inactive" most of the time — the HUD would disappear the moment the user clicks any other window.

**Why not plain NSWindow?** A plain `NSWindow` subclass with `canBecomeKey/canBecomeMain = true` steals focus from the user's frontmost app when clicked. This is wrong for a floating HUD — interacting with battery settings shouldn't deactivate the user's editor or terminal.

**Why NSPanel?** `NSPanel` with the following configuration satisfies all requirements:

| Property | Value | Purpose |
|----------|-------|---------|
| `styleMask` | `[.borderless, .nonactivatingPanel]` | No title bar; clicking doesn't activate the app |
| `hidesOnDeactivate` | `false` | Stays visible when user clicks other apps |
| `isFloatingPanel` | `true` | Floats above normal windows |
| `level` | `.floating` | Above normal windows, below `.statusBar` — won't cover system dialogs |
| `becomesKeyOnlyIfNeeded` | `true` | Accepts key status only for scroll/keyboard events when a view requests it |
| `canBecomeKey` | `true` (override) | Required for scroll wheel events in pinned mode and button clicks |
| `canBecomeMain` | `false` (override) | Prevents document-centric events (Save, Print) which are meaningless for a HUD |
| `animationBehavior` | `.utilityWindow` | Correct Mission Control grouping |

**Behavioral guarantees:**
- Buttons inside the HUD work normally — NSPanel does not auto-dismiss on internal clicks. Dismiss is controlled entirely by the app's own mouse monitor code that checks for clicks *outside* the window.
- `.nonactivatingPanel` means clicking the HUD doesn't steal focus — other apps stay active while the user interacts with battery settings.
- `hidesOnDeactivate = false` is essential for menu bar apps — without it, the HUD disappears whenever the user clicks another app.
- `canBecomeKey = true` allows scroll wheel events (required for the existing `WindowHostingView.scrollWheel` opacity control in pinned mode).
- The existing `setupMouseMonitor()` click-outside detection continues to control dismiss behavior unchanged.

**What remains correct:** `NSStatusItem` + `NSHostingView` for the menu bar icon. The custom battery shape rendering in the status bar doesn't need any of the scene-based APIs — `NSStatusItem` provides the correct abstraction for a fixed menu bar presence.

**References:**
- Apple: [NSPanel](https://developer.apple.com/documentation/appkit/nspanel), [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra), [UtilityWindow](https://developer.apple.com/documentation/swiftui/utilitywindow)
- swiftui-expert-skill/macos-scenes.md — evaluation of SwiftUI scene types for menu bar apps
- swiftui-expert-skill/macos-window-styling.md — NSPanel configuration for floating HUDs
- See `improvements-prd.md` Chunk 7 for the `HUDPanel` design rationale

### 7. Reactive Observation over Polling

**Decision:** Replaced `AppState` property mirroring via polling loops with reactive observation for cross-service state tracking. Views read service properties directly instead of through a centralized mirror.

**Intent:** The current architecture has 7+ polling loops in `ServiceCoordinator` and `AppState` that manually copy ~20 service properties every 1-5 seconds, generating ~1,545 CPU wake-ups/minute. In a battery monitoring app, this polling overhead is counterproductive. Reactive observation eliminates the polling entirely — the coordinator reacts only when a tracked property actually changes.

**Critical availability constraint:** The `Observations` API requires **macOS 26+** (Tahoe). It is NOT back-ported to macOS 14 or 15. The app's minimum target is macOS 14.0, so `Observations` cannot be the primary mechanism.

**Approach:** Use a reusable `ObservationStream` utility (`Utilities/ObservationStream.swift`) that encapsulates two reactive patterns behind a single API:

- **Primary (macOS 14+):** `withObservationTracking` + `AsyncStream` with `@Sendable func track()` re-registration pattern
- **Automatic upgrade (macOS 26+):** `Observations` API gated behind `#available(macOS 26, *)`

```swift
// Usage — identical regardless of macOS version:
for await percentage in ObservationStream.changes(of: battery, keyPath: \.percentage) {
    handlePercentageChange(to: percentage)
}
```

See Decision #12 for full `ObservationStream` design rationale. See `improvements-prd.md` Chunk 6 for the full migration plan.

**Unsafe patterns to avoid:**
- `withCheckedContinuation` + `withObservationTracking` — `onChange` can fire before the continuation resumes, causing a double-resume crash
- Inline `withObservationTracking` boilerplate at each site — error-prone, makes the `#available(macOS 26, *)` upgrade path harder

**References:**
- swift-concurrency/observation.md — correct reactive patterns, `Observations` API availability
- swiftui-expert-skill/performance-patterns.md — SwiftUI tracks `@Observable` at the property level

### 8. Isolated Deinit for Task Cleanup

**Decision (planned):** Replace all 22 `nonisolated(unsafe)` annotations on Task properties with Swift 6.2's `isolated deinit` (SE-0371).

**Intent:** The current `nonisolated(unsafe)` workaround exists because `deinit` runs in a nonisolated context, but Task properties are `@MainActor`-isolated. `isolated deinit` runs the deinitializer on the actor's isolation domain, making access to actor-isolated stored properties safe without annotation:
```swift
@MainActor final class BatteryService {
    private var statusTask: Task<Void, Never>?  // no nonisolated(unsafe) needed
    isolated deinit { statusTask?.cancel() }     // runs on @MainActor
}
```

**Compile-time feature, not runtime:** `isolated deinit` is a compile-time feature (SE-0371). The compiler emits a hop-to-executor in the deinit body. The Swift concurrency runtime has been back-deployed since macOS 13, so a binary compiled with Swift 6.2 using `isolated deinit` works on macOS 14.0. No `#if swift(>=6.2)` gating needed for deployment target reasons.

**Dependency on service lifecycle:** Since all services are currently immortal singletons (`static let shared`), they never deallocate — `deinit` (isolated or not) never fires in production. `isolated deinit` becomes meaningful only after Chunk 16 (Service Lifecycle Ownership) replaces singletons with `AppEnvironment`-owned instances. Until then, the annotation cleanup is still worthwhile for code correctness and testability, but the runtime behavior is unchanged.

**Target:** Reduce `nonisolated(unsafe)` from 37 → 2 (IOKit C callback + PreferenceKey default — both structurally required).

**References:**
- swift-concurrency/actors.md — `isolated deinit` semantics
- See `improvements-prd.md` Chunk 15 for the full cleanup plan and annotation-by-annotation reduction table

### 9. KeyframeAnimator over Custom Animation System

**Decision (done):** Replaced the custom `AnimationManager.swift` (~226 lines) with SwiftUI's native `keyframeAnimator(initialValue:trigger:)` for mask and glow channels. Progress and container use `withAnimation`. `AnimationManager.swift` deleted.

**Why:** The old system used `Task.sleep` for timing (not frame-synced, can drift), manual `@State` properties for interpolation, and a bespoke `AnimationModifier: ViewModifier`. This bypassed SwiftUI's animation transaction system and caused jerky animations. `KeyframeAnimator` (macOS 14+, our minimum target) provides frame-synced, cancellable, multi-track keyframe animations that participate in the transaction system.

**Why NOT `PhaseAnimator`:** `PhaseAnimator` applies a single `Animation` per phase transition shared across all properties. The glow and progress channels have multiple properties changing with different easings per keyframe (e.g., glow has `easeOut` for first step but spring for second). `keyframeAnimator` with `KeyframeTrack` per property is required.

**Spring configuration:** `DesignAnimation.hudSpring = Spring(response: 0.35, dampingRatio: 0.65)` — snappy attack with visible elastic overshoot. Used by all `SpringKeyframe` instances in mask and glow channels.

**Key implementation details:**
- `Spring` API: `Spring(response:dampingRatio:)` — NOT `.interactiveSpring(...)`, NOT `dampingFraction`
- Each HUD channel (mask, glow) uses a phase enum + generation counter to trigger re-animation on state change
- Reveal mask starts at 8×8 (opacity 0.0), springs to 120×120 with a 0.15s opacity fade-in for a "materializing" effect, then expands to 430×120 pill
- Dismiss mask uses `LinearKeyframe` holds (zero velocity) to prevent oval distortion at `SpringKeyframe` handoffs
- Progress ring uses `withAnimation` with blur-to-sharp (5pt → 0pt) and scale (0.8 → 1.0) during reveal

**References:**
- swiftui-expert-skill/animation-advanced.md — KeyframeAnimator with `KeyframeTrack`
- PRD 05 Chunk 21 amendments — timing fix details and feel tuning rationale

### 10. Alert Priority System

**Decision (planned):** Add priority levels to `HUDAlertTypes` and implement priority-based replacement logic in `WindowService.open()`.

**Why:** Currently, when `ServiceCoordinator` detects an alert condition, it calls `WindowService.open(alertType, device)` immediately. If the HUD is already showing an alert, the new one replaces it with no priority logic. A 1% battery alert (critical) should not be replaced by a Bluetooth device connected alert (informational). If the user unplugs the charger at 1%, both `chargingStopped` and `percentOne` alerts fire with no defined winner.

**Priority levels:**
- `critical` — 1% battery, device overheating
- `high` — 5%, 10% battery thresholds
- `medium` — charging state changes, device connect/disconnect
- `low` — calendar events, user-initiated opens

**Behavior:** `WindowService.open()` only replaces the current alert if the new alert's priority >= the current alert's priority. Lower-priority alerts are queued and shown after the current alert dismisses.

See `improvements-prd.md` Chunk 22 for the full implementation plan.

### 11. System Notification Fallback for Critical Alerts

**Decision (planned):** Send `UNNotificationRequest` via `UNUserNotificationCenter` for critical and high-priority alerts as a fallback when the HUD may not be visible.

**Why:** The HUD is currently the only notification mechanism. If the HUD is at low opacity (pinned mode with scroll-wheel dimming), hidden, or obscured by a full-screen app, critical alerts like 1% battery or device overheating are invisible. A battery monitoring app's primary job is to alert the user about critical conditions. The onboarding already requests notification permissions (`OnboardingPermissionsView`) but no code sends notifications.

**Behavior:**
- Only send system notification if HUD is not visible or opacity < 0.6
- Use `UNNotificationCategory` with actions: "Open BatteryBoi" (brings HUD to front), "Dismiss"
- Respect the user's notification permission status — if denied, HUD is the only mechanism (existing behavior)

See `improvements-prd.md` Chunk 23 for the full implementation plan.

### 12. ObservationStream Utility for Cross-Version Reactive Observation

**Decision:** Centralized `Utilities/ObservationStream.swift` utility instead of inlining `withObservationTracking` + `AsyncStream` boilerplate at each observation site.

**Why a utility, not inline boilerplate:**
- **Consistency:** All 10+ observation sites use the same correct pattern. No risk of one site forgetting re-registration or the MainActor hop.
- **Single upgrade path:** When macOS 14/15 are dropped in the future, the `#available(macOS 26, *)` gate inside `ObservationStream` switches all sites to `Observations` automatically. No per-site migration needed.
- **Testability:** `ObservationStream` can be verified in isolation — one test covers the tracking/re-registration behavior for all consumers.
- **Ergonomics:** Reduces each observation site from ~15 lines (polling loop with sleep, guard, compare, mirror) to ~8 lines (`for await` with handler call).

**Two entry points:**
```swift
// Single property:
ObservationStream.changes(of: battery, keyPath: \.percentage)
// Multi-property / derived:
ObservationStream.changes { self.battery.charging.state == .charging && self.battery.percentage >= 100 }
```

**Design constraints:**
- Does NOT use `withCheckedContinuation` — the unsafe double-resume pattern
- Uses `@Sendable func track()` re-registration pattern for `withObservationTracking` (macOS 14+)
- Emits current value immediately on subscription (no separate initial read needed)
- Zombie-tracking prevention: `TerminationFlag` checked at top of `track()` and inside `onChange` Task
- `onTermination` cleanup ensures no leaked observation registrations when the consuming Task is cancelled

See `improvements-prd.md` Chunk 6 for the full `ObservationStream` implementation and usage examples.

### 13. Percentage-Adaptive Battery Tier Gradient System

**Decision:** Replace the static `RadialStyle` enum (dark/light/colour) with a `BatteryTier` enum that maps battery percentage to 5 color tiers (Critical, Low, Medium, Good, Full). Each tier defines 2–3 gradient stops for the radial ring's `AngularGradient`.

| Tier | Percent Range | Gradient Stop 1 | Gradient Stop 2 | Gradient Stop 3 | Dot/Glow Color |
|------|--------------|-----------------|-----------------|-----------------|----------------|
| **Critical** | 0–15% | `#FF2D55` | `#FF3B30` | — | `#FF2D55` |
| **Low** | 16–40% | `#FF6B00` | `#FFB800` | — | `#FF6B00` |
| **Medium** | 41–70% | `#D4FF00` | `#7CFF00` | — | `#D4FF00` |
| **Good** | 71–99% | `#7CFF00` | `#00FF88` | `#00E676` | `#00FF88` |
| **Full** | 100% | `#00FF88` | `#5BFFE0` | `#00E5FF` | `#5BFFE0` |

**Key design choices:**
- Colors are mode-independent (same in light and dark mode) — the dark HUD background provides natural contrast
- Glow uses `.shadow()` not blurred overlay rings — performant single-pass rendering
- Tier transitions animate via SwiftUI's native `Color` interpolation (0.6s easeInOut)
- Charging effects (shimmer, pulse, glow) are layered on top of the tier gradient, not baked into it
- Mini rings (28×28 for Bluetooth devices) get tier colors but skip glow/shimmer (too small)
- `BatteryTier` is the single source of truth for all battery-related colors across the app
- `RadialStyle` enum is superseded and deleted

Reference: `docs/prd/03-ux-polish.md` Chunks 12G, 12H, 12I

### 14. Centralized Symbol Effect Utility for Version-Gated Animations

**Decision:** All SF Symbol effects that require macOS 15+ (`.appear`, `.disappear`, `.replace`) are applied through a single reusable `SymbolEffectModifier` view modifier in `DesignTokens.swift`. This modifier:
- Takes an `HUDIconEffect` enum value
- On macOS 15+: applies the native `.symbolEffect()` or `.contentTransition(.symbolEffect(.replace))`
- On macOS 14: applies a graceful fallback (opacity transition for appear/disappear, crossfade for replace)
- Effects that work on macOS 14+ (`.pulse`, `.bounce`, `.variableColor`) are applied directly with no fallback needed

**Why centralized, not inline `#available`:** Prevents scattered version checks across 5+ view files. A single utility means: (a) one place to test the fallback behavior, (b) one place to remove the gate when the deployment target is raised to macOS 15+, (c) call sites stay clean: `.applySymbolEffect(.pulseByLayer)` rather than multi-line `if #available` blocks.

**Usage:** `Image(systemName: icon).applySymbolEffect(.pulseByLayer)` — the modifier decides the implementation.

Reference: `docs/prd/03-ux-polish.md` Chunk 12H

### 15. ~~Three-State HUD System (Progress → Revealed → Detailed)~~ — SUPERSEDED

> **Decision superseded.** Replaced by four-state Glance/Shelf/Panel system. See Decision #21.

**Why superseded:** Common quick actions (Keep Awake, Sound, Display) require opening the full Panel and navigating to the Settings tab — too many steps for frequent operations. The Shelf provides hover-activated quick actions without leaving the pill context.

**Original rationale:** The HUD used a three-state system where `.revealed` was a minimal "glanceable" pill (battery info + ring + gear icon) and `.detailed` was an expanded panel triggered only by explicit user action (gear click). The previous auto-transition from `.revealed` to `.detailed` was removed because it caused buttons appearing unsolicited during passive notifications, layout cramping, and the HUD expanding before the user could read the battery summary.

**Migration:** `.revealed` renamed to `.glance`, `.detailed` renamed to `.panel`, new `.shelf` state inserted between them. See Decision #21 for the full state machine.

### 16. ~~NSImage Menu Bar Icon Rendering~~ — REJECTED

**Decision:** Keep the current `NSHostingView` subview approach for the menu bar icon.

**Why rejected:** The NSImage snapshot approach would lose live SwiftUI animations (hover rollover, charging pulsation, spring transitions) that are core to the menu bar UX. The "full-screen white blob" issue cited as motivation was never reproduced or reported by users, and no Apple documentation confirms the alleged alternate rendering path for `NSHostingView` in full-screen mode.

**Current approach:** `NSHostingView` containing `MenuContainer` is added as a subview of `NSStatusBarButton`. This provides live SwiftUI rendering with full animation support, `SettingsDisplayType`-driven content, and hover rollover transitions.

### 17. Scroll-to-Cycle Pill Layers

**Decision:** The revealed pill gains three information layers (Battery, Power, Health) that the user cycles through by scrolling. Only the text content and ring visualization change — the pill shape and size remain constant.

**Why:** Rich IOKit data (temperature, voltage, amperage, health) is already collected but only visible after expanding the HUD and navigating to the Mac battery detail view. The pill has unused potential — scroll-to-cycle surfaces this data at-a-glance without requiring full expansion. The ring naturally adapts to show different metrics (battery %, wattage proportion, health %).

**Scroll handling:** `WindowHostingView.scrollWheel(_:)` already captures scroll events (used for opacity in pinned mode). In non-pinned revealed state, scroll cycles layers with 0.3s debounce. In pinned mode, existing opacity behavior is preserved.

**Discoverability:** Always-visible page dots (4pt, below subtitle). First-time animated hint stored in UserDefaults. These are persistent cues, not hover-dependent — users who don't hover over the pill must still discover scrollability.

Reference: `docs/prd/06-hud-overhaul-features.md` Chunk 31

### 18. Keep Awake via IOPMAssertionCreateWithName

**Decision:** Use `IOPMAssertionCreateWithName` with `kIOPMAssertionTypeNoDisplaySleep` to prevent display sleep. Managed by a `KeepAwakeService` with configurable duration and countdown.

**Why not `caffeinate` subprocess:** Spawning a child process is fragile (must manage its lifecycle, handle orphaning) and doesn't integrate with the app's service architecture. `IOPMAssertion` is the same API `caffeinate` uses internally, and the OS releases the assertion automatically when the process exits.

**Why `NoDisplaySleep` over `NoIdleSleep`:** Users who want "keep awake" overwhelmingly mean the display. `kIOPMAssertionTypeNoIdleSleep` prevents idle sleep but still allows the display to dim/sleep, which surprises users. `kIOPMAssertionTypeNoDisplaySleep` prevents both display sleep and idle sleep — the stronger guarantee matches user expectations.

**Safety:** The assertion only prevents *idle* sleep, not user-initiated sleep (closing the lid, Apple menu > Sleep). Auto-deactivates on timer expiry and on low battery (< 10%).

Reference: `docs/prd/06-hud-overhaul-features.md` Chunk 34

### 19. Tabbed Expanded View over Side-by-Side Layout

**Decision:** Replace the `.panel` state's (formerly `.detailed`) side-by-side `HStack` layout (DevicesColumnView + SettingsTileGrid) with a tabbed layout using a capsule selector and three full-width content tabs (Devices, Settings, About).

**Why:** The side-by-side layout is cramped — the settings tile grid forces every option into "tap to cycle" behavior, and the narrow device column can't fit device cards with radial rings. A tabbed layout gives each section full panel width, enabling proper native controls (toggles, pickers) for settings and richer device cards with visual battery indicators.

**Tab bar:** Capsule-shaped selector with `matchedGeometryEffect` for smooth sliding animation. Positioned below the divider, above content. Respects `accessibilityReduceMotion`.

**Sub-navigation:** Device detail views and threshold editor replace their tab's content (slide from trailing edge) rather than the entire panel. Tab bar remains visible and interactive.

Reference: `docs/prd/06-hud-overhaul-features.md` Chunks 26, 27, 28

### 20. Grouped Settings List over Tile Grid

**Decision:** Replace the 2×3 `SettingsTileGrid` with grouped list rows using native controls matched to each setting's intent — `Toggle` for booleans, `Menu` picker for multi-option settings, disclosure rows for sub-views.

**Why:** The tile grid forces every setting into "tap to cycle" behavior. This is wrong for:
- Booleans (Launch at Login, Sound Effects) — a toggle is the standard macOS control
- Multi-option settings (Display has 5 options, Position has 6) — a picker lets the user see all options and jump directly
- Settings with sub-configuration (Alert Thresholds, Keep Awake duration) — disclosure rows and conditional rows can't fit in a fixed grid

**Reusable components:** `SettingsToggleRow`, `SettingsPickerRow`, `SettingsSection`, `SettingsDisclosureRow`, `SettingsFooterView` — designed for consistency and reuse across the Settings tab.

Reference: `docs/prd/06-hud-overhaul-features.md` Chunk 27

### 21. Four-State HUD System (Glance / Shelf / Panel)

**Decision:** The HUD uses a four-state system. `.revealed` is renamed to `.glance`, `.detailed` is renamed to `.panel`, and a new `.shelf` state is inserted between them. The Shelf is a continuous capsule extension of the Glance pill — not a separate floating window — providing hover-activated quick-action buttons without leaving the pill context.

**Supersedes:** Decision #15 (Three-State HUD System)

**State flow:**
```
.hidden → .progress → .glance (was .revealed) → .dismissed → .hidden
                          │
                          ├── (hover 300ms) → .shelf
                          │                      │
                          │                      ├── (mouse exit) → .glance
                          │                      ├── (gear click) → .panel (was .detailed)
                          │                      └── (dismiss) → .dismissed
                          │
                          ├── (gear click) → .panel
                          │                    │
                          │                    ├── (X / click outside) → .glance
                          │                    └── (dismiss) → .dismissed
                          │
                          └── (dismiss timer / click outside) → .dismissed → .hidden
```

**Layout:**
- `.glance` (pill): Battery icon + summary text + radial ring + gear icon. No buttons, no settings. Scroll-to-cycle layers (Decision #17).
- `.shelf` (extended pill): The pill capsule stretches vertically ~60pt to include a row of 4 quick-action buttons (Keep Awake, Sound, Display, Settings gear). See Decision #22.
- `.panel` (expanded): Full-width tabbed dashboard (Devices, Settings, About). See Decisions #19, #20.

**Why a continuous capsule, not a separate bar:** The Shelf extends the existing Glance pill's `RoundedRectangle(cornerRadius: CornerRadius.hud)` shape downward. This preserves visual continuity, avoids managing a second floating window, and eliminates gap hit-testing between two separate views.

**Shelf entry/exit mechanics:**
- Enter Shelf: mouse hovers over Glance pill for 300ms continuous dwell. `WindowService` starts a cancellable `Task.sleep(for: .milliseconds(300))` on hover. If mouse is still hovering when the task completes, transition to `.shelf`.
- Exit Shelf: mouse exits the capsule bounds. After 100ms grace period (prevents flicker on edge-crossing), transition back to `.glance`.
- Pinned mode: dwell time increases to 500ms. Shelf auto-collapses after 5s of no interaction within the shelf bounds.
- Fast hover-in/out (< 300ms): no Shelf activation. Dwell timer cancels on mouse exit.

**Dismiss/Hover behavior (inherited from Decision #15, adapted for four states):**
- Dismiss timer pauses on hover during `.glance` and during `.shelf` (the entire capsule is considered "hovered")
- No auto-dismiss during `.panel` state
- Timer resumes on mouse exit from `.glance` or `.shelf` with remaining time (min 3s)
- Click inside `.glance` pill resets timer to full duration
- Shelf button taps (Keep Awake, Sound, Display) reset the dismiss timer (user is actively interacting)
- Gear click transitions to `.panel` (timer paused, no auto-dismiss)
- 30s max hover hold in `.glance`, then resume with 3s remaining. For `.shelf`: 5s idle auto-collapse (no interaction within shelf bounds), then `.glance` 30s rule applies
- Pinned mode: no dismiss timer in `.glance`, `.shelf`, or `.panel`
- On shelf collapse → `.glance`: timer resumes with remaining time (min 3s)

**Window sizing:**
- `.glance`: 450×250
- `.shelf`: 450×310 (approximately +60pt for button row)
- `.panel`: 520×500

**Animation:** Shelf capsule morph uses `DesignAnimation.spring(response: 0.4, dampingRatio: 0.8)` from `DesignTokens.swift`. Button entrance is staggered 60ms left-to-right. Collapse reverses (staggered right-to-left, then capsule contracts). Two-phase dismiss: shelf collapses first (~400ms), then pill dismisses normally.

**References:**
- `docs/prd/06-hud-overhaul-features.md` Chunk 36
- Decision #22 (Shelf Quick-Actions Pattern)

### 22. Shelf Quick-Actions Pattern

**Decision:** Shelf quick-action buttons follow a "labeled pill with hover subtitle" pattern. Each button is a capsule containing an SF Symbol icon and a short text label. On hover, the button expands its width to reveal a contextual subtitle providing current-state information.

**Button specifications:**

| Button | Icon (off) | Icon (on) | Label | Hover subtitle (off) | Hover subtitle (on/active) |
|--------|-----------|----------|-------|---------------------|---------------------------|
| Keep Awake | `cup.and.saucer` | `cup.and.saucer.fill` | "Awake" | Duration: "30 min" | Countdown: "28 min left" |
| Sound | `speaker.slash` | `speaker.wave.2.fill` | "Sound" | "Off" | "On" |
| Display | `number` | `number` | "Display" | Current mode name | Cycles on tap |
| Settings | `gearshape` | — | — (icon only) | "Settings" | — |

**Why labeled pills, not bare icons:** The Shelf is a transient hover layer. Without labels, users must memorize icon meanings across sessions. Labels make buttons self-documenting. The hover subtitle provides state context (e.g., "28 min left") that would otherwise require opening the Panel.

**Active state indicators:**
- Filled SF Symbol variant (e.g., `cup.and.saucer.fill` when active)
- Glow halo: 8pt blur radius `Circle()` behind the active button, colored with `BatteryTier` gradient (reuses `.shadow(color:radius:)` pattern from `RadialProgressBar` in `ProgressView.swift`)
- 2pt accent-color underline pill below each active toggle, animated in with `.transition(.scale.combined(with: .opacity))`

**SF Symbol effects (via `SymbolEffectModifier` from `DesignTokens.swift`):**
- On tap: `.symbolEffect(.bounce)` for all buttons
- On state change: `.contentTransition(.symbolEffect(.replace))` for icon swap (cup ↔ cup.fill, speaker variants)
- Display cycle: `.symbolEffect(.variableColor.iterative)` — ripple through symbol layers
- Gear hover: `.symbolEffect(.rotate)` (macOS 15+ via `SymbolEffectModifier`, no-op fallback on macOS 14)
- All icons: `.symbolRenderingMode(.hierarchical)` for depth — primary layer is accent color, secondary at 50% opacity

**Shelf → Panel morph:** The gear button uses `matchedGeometryEffect(id: "settingsGear", in: namespace)` so its position and icon morph into the Settings tab indicator when the Panel opens. Panel opens with Settings tab pre-selected. Pattern: same `@Namespace` + `matchedGeometryEffect` approach used in `HUDView.swift` and `BluetoothView.swift`.

**Ring response to shelf interactions:**
- Keep Awake hover: ring border pulses amber (using `ChargingAnimation` timing from `DesignTokens.swift`)
- Display cycle: ring percentage text crossfades via `.contentTransition(.numericText())` (macOS 14+, no gating needed)

**Accessibility:** Each button has `.accessibilityLabel` with full state description (e.g., "Keep Awake, active, 28 minutes remaining"). `.accessibilityAddTraits(.isButton)`. Reduce Motion: no staggered entrance, all buttons appear simultaneously with `nil` animation.

**Existing utilities reused:** `DesignAnimation.spring()`, `BlurFade` transition, `HoverButtonStyle`, `SymbolEffectModifier`, `BatteryTier.gradientColors` — all from `DesignTokens.swift`.

Reference: `docs/prd/06-hud-overhaul-features.md` Chunk 36

### 23. Combined Battery Limits View

**Decision:** Replace the separate Custom Alert Thresholds editor (Chunk 35) and the simple 80% charge limit toggle with a unified "Battery Limits" sub-view that presents both concepts on a single dual-handle slider.

**Why combined:** The charge limit (80%) and the low-battery alert threshold (e.g., 20%) are conceptually the two ends of the "usable battery range." Presenting them together on a single track makes their relationship visually obvious and eliminates the need for users to configure them in separate places.

**Dual-handle slider:**
- Custom SwiftUI view (SwiftUI has no native dual-handle slider)
- Horizontal slider track representing 0–100%
- Left handle (20pt circle, `BatteryTier.low.dotColor` tint): low alert threshold, default 20%, range 1–50%. Also functions as the lowest popup alert threshold — battery dropping below this value triggers a HUD alert in addition to the ring visual shift. Thresholds in the below-slider list must be below this value
- Right handle (20pt circle, accent color tint): max charge limit, default 80%, range 50–100%
- Minimum gap: 10% (handles cannot cross or get closer than 10 percentage points)
- Snap: 5% increments via `DragGesture` with rounding
- Track between handles: filled with `BatteryTier` gradient (tier of the midpoint percentage)
- Notches: 2pt × 8pt vertical tick marks at 5% intervals, `BBSubtitle` at 10% opacity

**Dynamic contextual text:** Below the slider: "Alerts fire when battery drops below X%. Charging pauses at Y%." — updates live as the user drags handles. Shows the effect of the setting, not a description of the control.

**Ring integration:** Two notches on the radial ring reflecting both limits (extends Chunk 33's single-notch system):
- Low-alert notch: subtle amber tick at the left handle's percentage angle
- Charge-limit notch: accent-colored tick at the right handle's percentage angle
- "Safe zone" tint between the notches: `BatteryTier` gradient at 8% opacity on the ring track

**Below-slider alert threshold list:** Editable list of specific alert thresholds below the left handle value. Add/remove capability. 1% critical threshold is non-removable. Max 10 thresholds. This preserves all original Chunk 35 functionality.

**Reset to Defaults:** Resets everything — both slider handles (low alert → 20%, charge limit → 80%) and the threshold list (→ `[5, 10, 25]`).

**Storage and migration:**
- New `lowAlertThreshold` UserDefaults key (Int, default 20)
- Charge limit: existing boolean toggle extended to store actual percentage. Migration: `true` → 80%, `false` → 100%
- Alert thresholds array: unchanged `[Int]` in UserDefaults

**VoiceOver accessibility:** Separate `Stepper` controls for each handle when VoiceOver is active — no standard dual-handle VO pattern exists.

**Surface point:** "Battery Limits" disclosure row in Settings tab (Chunk 27).

Reference: `docs/prd/06-hud-overhaul-features.md` Chunk 35

### 24. Dark Aqua Appearance on HUD Panel

**Decision:** The `HUDPanel` (`NSPanel`) sets `self.appearance = NSAppearance(named: .darkAqua)` directly, forcing all native AppKit/SwiftUI controls within it to render in dark mode.

**Why:** The HUD is a dark-themed panel with custom dark color assets (`BBSurface`, `BBTitle`, `BBSubtitle`). Native controls rendered inside it — SwiftUI `Menu` triggers, `Toggle` switches, system chevrons — inherit the app-level or system-level appearance by default. When the system is in light mode, these controls render with dark-on-light chrome (black chevrons, light toggle tracks) that clash with the dark card backgrounds. Setting `.darkAqua` on the panel itself makes all native controls render dark-appropriate without affecting the menu bar status item or any other app-level appearance.

**What this fixes:** `Menu` trigger chevrons (`.menuStyle(.borderlessButton)` system chrome), toggle switch tracks, and any other AppKit-rendered widget within the panel.

**What this does NOT fix:** `NSMenu` dropdown popups spawned from pickers. These create their own window and inherit from `NSApp.appearance`, not the panel. They will follow the system/app theme.

**Scope:** Panel-only. Does not override the app's theme setting (dark/light/system in `SettingsService.enabledTheme`), which controls `NSApp.appearance` for the rest of the app.

---

## Patterns & Conventions

### @objc Bridge Pattern (BluetoothBridge)

IOBluetooth requires `@objc` selectors for device connection/disconnection notifications. These are incompatible with Swift actors. The solution is a `@MainActor` bridge class (`BluetoothBridge`) that:
1. Registers for IOBluetooth notifications via `@objc` methods
2. Forwards events to closures (`onDeviceConnected`, `onDeviceDisconnected`)
3. Is owned by `BluetoothService` which sets up the closures

This pattern is required for any Apple framework that uses `@objc` callback selectors. Do not try to make IOBluetooth callbacks work directly on an actor.

### Bluetooth Battery Data Sources

Battery data for Bluetooth devices comes from two layers, read in priority order:

1. **KVC on `IOBluetoothDevice`** (primary) — Undocumented but stable ObjC properties
   (`batteryPercentSingle`, `batteryPercentLeft/Right/Case`) accessed via `value(forKey:)`.
   Covers ALL device types including non-Apple headphones, AirPods L/R/Case, and speakers.
   This is the same source macOS System Settings uses. **Requires direct/notarized distribution
   — not Mac App Store safe** (Guideline 2.5.1). Guarded by `responds(to:)` for forward safety.
   Compiled only when `DIRECT_DISTRIBUTION` flag is set.

2. **IOKit IORegistry** (fallback) — Queries both `AppleDeviceManagementHIDEventService` and
   `IOHIDDevice` classes for `BatteryPercent` property. Fully public API, no entitlement needed.
   Covers classic BT HID devices (keyboards, mice, trackpads). Some third-party headsets also
   publish here.

**Invalid battery values:** 0 and values outside 1-100 (including 255, a known sentinel) are
treated as "no data available." This prevents false "0%" display for battery-less devices
like wired Bluetooth speakers.

**`DIRECT_DISTRIBUTION` compile flag:** Gates all KVC code via `#if DIRECT_DISTRIBUTION`. Set in
Xcode project build settings, Fastlane lanes (test/build/release), and Taskfile dev task. A
future App Store configuration would omit this flag — KVC battery and vendor/product data would
be unavailable, with the IORegistry path as the only source.

**Future:** CoreBluetooth GATT Battery Service (0x180F) for pure-BLE devices is not yet
implemented. It is the only App Store–safe path for BLE accessory battery, but adds
significant complexity (CBCentralManager delegation, BLE scan lifecycle).

### Task Lifecycle

Services own `Task` properties for polling loops. The pattern:
1. Store as `nonisolated(unsafe) private var someTask: Task<Void, Never>?`
2. Cancel previous task before creating a new one: `someTask?.cancel(); someTask = Task { ... }`
3. Cancel in `deinit` using `nonisolated(unsafe)` access (justified per SE-0371)
4. Always check `Task.isCancelled` inside loops

The `nonisolated(unsafe)` is necessary because `deinit` runs in a nonisolated context, but the task properties are `@MainActor`-isolated. Until isolated deinit (SE-0371) is fully stable with `-default-isolation MainActor`, this is the correct workaround.

See `improvements-prd.md` Chunk 9 for the comprehensive task lifecycle audit addressing fire-and-forget tasks and entry isolation.

### nonisolated(unsafe) Annotations — Current State

37 annotations across 14 files. Categories:

| Category | Count | Files | Justification |
|----------|-------|-------|---------------|
| Task properties for deinit cleanup | 22 | BatteryService, BluetoothService, EventService, WindowService, ServiceCoordinator, SettingsService, StatsService, AppManager, UpdateManager | SE-0371 workaround — needed until isolated deinit works with default MainActor isolation |
| Logger static properties | 8 | Logger.swift | `os.Logger` is thread-safe; `nonisolated(unsafe)` lets it be accessed from any isolation domain |
| IOBluetooth notification storage | 2 | BluetoothBridge | Stored notifications cleaned up in deinit |
| Combine infrastructure | 2 | Extensions.swift | `PassthroughSubject` used for UserDefaults change notification |
| IOKit callback | 1 | IOKitBatteryService | Static callback for power source change notifications |
| Preferences key default | 1 | SettingsView | `PreferenceKey` conformance requires nonisolated static |
| EKEventStore | 1 | EventService | EventKit store created in init, used across isolation boundaries |

See `improvements-prd.md` Chunk 15 for the cleanup plan and Decision #8 above for the `isolated deinit` adoption plan.

---

## Previous Problems & Why We Changed

### Singleton + nonisolated(unsafe) Anti-Pattern

The original architecture used singleton managers (`SomeManager.shared`) with `nonisolated(unsafe)` to bypass Swift's compile-time isolation checks. This caused:
- No clear ownership of async operations
- Difficult-to-test global state
- Initialization order dependencies between singletons
- Runtime crashes when callbacks crossed isolation boundaries

The fix was `ServiceContainer` as a single owner of all services, with protocol-based interfaces for testing.

### Callback-Based APIs in @MainActor Context

Apple APIs like EventKit and IOBluetooth use callback patterns that conflict with `@MainActor` isolation. For example, `eventStore.requestFullAccessToEvents` takes a callback that runs on an arbitrary thread — accessing `@MainActor` state from that callback is an isolation violation.

The fix depends on the API:
- **EventKit:** Wrap callbacks in `withCheckedContinuation` for async/await
- **IOBluetooth:** Use the `@objc` Bridge pattern (see above)
- **IOKit:** Use a dedicated actor (`IOKitBatteryService`) with `@Sendable` callbacks

### Sleep/Wake Stale Handles

IOBluetooth device handles and notification registrations can go stale after macOS sleep/wake. Attempting to use stale handles causes crashes or freezes. Services must:
1. Listen for `NSWorkspace.willSleepNotification` and `didWakeNotification`
2. Tear down IOBluetooth state before sleep
3. Re-initialize with a 1-second delay after wake (hardware needs time to reinitialize)

---

## Risks & Known Gotchas

| Risk | Detail | Mitigation |
|------|--------|------------|
| **IOBluetooth + actors** | IOBluetooth uses `@objc` selectors incompatible with actors | Use BluetoothBridge pattern; never try to make IOBluetooth callbacks work on actors directly |
| **CoreData cross-actor** | NSManagedObjectContext is not Sendable | Always use `performBackgroundTask` for background work; `viewContext` only on MainActor |
| **IOKit on main thread** | `IOPSCopyPowerSourcesInfo()` and Bluetooth enumeration are synchronous and can block 2000ms+ (Sentry BATTERYBOI-RECHARGED-1) | Run IOKit calls on background actors; cache results |
| **Bluetooth permission error** | Error code `-536870186` (`0xE00002C6` = `kIOReturnNotPermitted`) means Bluetooth permissions are denied | Check `CBCentralManager.authorization` before attempting connections; show permission-denied UI |
| **Status bar with notch** | Laptops with notch have less menu bar space; long time strings may be truncated | Use `NSStatusItem.variableLength`; test on notch displays |
| **UserDefaults observation** | Rapid UserDefaults changes can cause excessive UI updates | Debounce settings observation in SettingsService |
| **`Observations` availability** | `Observations` API requires macOS 26+, NOT macOS 14/15. The app's minimum target is macOS 14.0 | Use `withObservationTracking` + `AsyncStream` via `ObservationStream` utility as primary pattern; gate `Observations` behind `#available(macOS 26, *)` inside the utility. See Decision #7 and #12 |
| **`@Entry` + `MainActor.assumeIsolated` crash** | Both `@Entry` defaults use `MainActor.assumeIsolated { ... }` — a runtime assertion that crashes if called from a non-MainActor context. SwiftUI's environment infrastructure may access defaults from internal contexts with no MainActor guarantee | Replace with type-based `@Environment(AppEnvironment.self)` injection (macOS 14+), which avoids `@Entry` entirely. See Decision #5 |
| **Alert priority gap** | No priority system for HUD alerts — a critical 1% battery alert can be replaced by an informational Bluetooth device connected alert | Add `AlertPriority` levels to `HUDAlertTypes`; only replace current alert if new priority >= current. See Decision #10 |
| **Animation migration visual regression** | Replacing `AnimationManager` with `keyframeAnimator` changed timing semantics — `LinearKeyframe` holds caused visible delays, `CubicKeyframe` holds caused oval dismiss shapes | Fixed: reveal springs start at t=0, dismiss uses `LinearKeyframe` holds (zero velocity) + `SpringKeyframe` contraction. Frame-by-frame verified. See Decision #9 and PRD 05 Chunk 21 amendments |
| **`.symbolEffect` availability** | `.appear`, `.disappear`, `.replace` require macOS 15+. Deployment target is 14.0 | Centralized `SymbolEffectModifier` utility gates all version-dependent effects behind a single `#available` check. Call sites never use inline `#available`. See Decision #14 |
| **Shelf hover flicker** | Mouse crossing the capsule boundary rapidly (e.g., moving diagonally through a corner) can cause rapid shelf expand/collapse cycles | 100ms grace period on mouse-exit before collapsing. 300ms dwell requirement on enter. See Decision #21 |
| **Shelf + pinned mode interaction** | In pinned mode, the Glance pill is always visible. Shelf hover activation could be disruptive if the user's cursor frequently crosses the pill | In pinned mode, Shelf activation requires 500ms dwell instead of 300ms. Shelf auto-collapses after 5s of no interaction. See Decision #21 |
| **Dual-handle slider accessibility** | Dual-handle sliders are not natively supported by SwiftUI and have no standard VoiceOver pattern | Provide two separate `Stepper` controls as an accessibility alternative when VoiceOver is running. See Decision #23 |

---

## Swift 6.2 Concurrency Status

### Features In Use
- **SE-0461** — Nonisolated async runs on caller's actor (no unexpected thread hops)
- **SE-0469** — Task naming (tasks named in Instruments and debugger)
- **SE-0472** — Task.immediate (starts without queuing for immediate UI updates)
- **SE-0371** — Isolated deinit (justification for current `nonisolated(unsafe)` task properties; planned: use `isolated deinit` directly to eliminate 22 annotations — see Decision #8). Compile-time feature; works on macOS 14.0+ deployment targets.
- **SE-0466** — Default MainActor isolation via `-default-isolation MainActor` compiler flag. All declarations default to `@MainActor`; background actors and pure utility extensions must opt out with `nonisolated`. See `improvements-prd.md` Chunk 15.
- **`withObservationTracking` + `AsyncStream`** — Reactive observation via the `ObservationStream` utility (see Decision #12). Primary mechanism for replacing polling loops. Available macOS 14+.

### Gated behind `#available(macOS 26, *)`
- **`Observations` API** — Reactive `AsyncSequence` over `@Observable` property changes. Cleaner API than `withObservationTracking` but requires macOS 26+ (Tahoe). Gated inside `ObservationStream` utility — all observation sites automatically upgrade when the minimum target is raised. See Decision #7 and Decision #12.

### Build Configuration
- Swift version: 6.2 (set in project.pbxproj)
- `SWIFT_STRICT_CONCURRENCY`: `complete`
- `OTHER_SWIFT_FLAGS`: `-DMACOS_13_AND_ABOVE -default-isolation MainActor`
- `SWIFT_ACTIVE_COMPILATION_CONDITIONS`: `DIRECT_DISTRIBUTION` (Debug adds `DEBUG`). Gates KVC battery/vendor data access on `IOBluetoothDevice` — see "Bluetooth Battery Data Sources" section.
- Xcode: 16.3+ required for Swift 6.2

**SE-0466 implications:** With `-default-isolation MainActor`, all declarations default to `@MainActor` unless explicitly opted out. Pure utility extensions on value types (e.g., `String` computed properties) and background actors (`IOKitBatteryService`, `IOKitBluetoothService`) must use `nonisolated` to avoid unintended MainActor isolation. See `improvements-prd.md` Chunk 15.

---

## UI/UX Design Principles

### Reference Design (Original BatteryBoi)

| Feature | Intended Behavior |
|---------|-------------------|
| Time remaining | Shows actual estimate ("15 hours 3 minutes"), not "Unknown" |
| Default view | Settings buttons visible at bottom, NOT Bluetooth devices |
| Menu bar icon | Shows compact time badge ("+15h") |
| Button style | Clean pills with icon + title; subtitle appears on hover |
| Quit button | Power icon on far right |
| Hover behavior | Subtitles hidden by default, shown on hover |

### State Display Guidelines

| State | Display Text | Rationale |
|-------|-------------|-----------|
| Time remaining unknown | "Calculating..." | Less alarming than "Unknown"; implies temporary |
| No Bluetooth devices | Empty state view with "No Devices Connected" | Guides user to connect devices |
| Bluetooth permission denied | Permission-denied view with "Open Settings" CTA | Actionable, not a dead end |
| Battery at 100% + charging | Show "Fully Charged" | Not "Charging..." which implies it's still going |

### Empty State Design Tokens

| Element | Specification |
|---------|---------------|
| Icon | SF Symbols, 20-24pt, 60% opacity |
| Title | `Typography.headingLarge`, `BatteryTitle` color |
| Body | `Typography.small`, `BatterySubtitle` color, max 2 lines |
| Background | `BatteryButton` color with `CornerRadius.container` |
| Padding | Horizontal: 20pt, Vertical: 16pt |
| Action | Primary pill button below body text |

---

## Feature Regression Checklist

Use this before any release to verify all features work.

### Battery
- [ ] Battery percentage monitoring (IOKit)
- [ ] Charging state detection (AC/Battery)
- [ ] Time remaining calculation
- [ ] Battery health metrics (cycle count, condition)
- [ ] Thermal state monitoring
- [ ] Power save mode toggle (AppleScript)
- [ ] Charge limit setting (configurable 50–100%)
- [ ] Wattage/energy metrics

### Bluetooth
- [ ] Device discovery and enumeration
- [ ] Battery level tracking per device
- [ ] Device type detection (headphones, mice, keyboards, AirPods, etc.)
- [ ] Connection/disconnection notifications
- [ ] RSSI signal strength tracking
- [ ] Vendor identification (Apple, Samsung, Bose, etc.)

### HUD/Window
- [ ] HUD state machine (hidden, progress, glance, shelf, panel, dismissed)
- [ ] Shelf hover activation (300ms dwell) and collapse (mouse exit + 100ms grace)
- [ ] Shelf quick-action buttons (Keep Awake, Sound, Display, Settings)
- [ ] Shelf → Panel morph (gear matchedGeometryEffect into Settings tab)
- [ ] Two-phase dismiss (shelf collapses first, then pill dismisses)
- [ ] Battery threshold alerts (1%, 5%, 10%, 25%)
- [ ] Charging state change alerts
- [ ] Device overheating alerts
- [ ] Bluetooth device alerts
- [ ] Calendar event notifications
- [ ] Window positioning (6 positions)
- [ ] Mouse monitoring for dismiss
- [ ] Sound effects

### Settings
- [ ] Display type (countdown, percent, cycle, empty, hidden)
- [ ] Theme (light, dark, system)
- [ ] Sound effects toggle
- [ ] Combined Battery Limits dual-handle slider (low alert + charge limit)
- [ ] Dual-notch radial ring (low alert + charge limit notches)
- [ ] Pinned mode toggle
- [ ] Icon style (chunky, basic)
- [ ] Launch at login (SMAppService)
- [ ] Progress bar visibility

### Integration
- [ ] URL scheme (batteryboi://)
- [ ] Sentry crash reporting
- [ ] Sparkle auto-updates
- [ ] CoreData statistics
- [ ] EventKit calendar integration
- [ ] Localization (15+ languages)

### UI Components
- [ ] Menu bar icon rendering
- [ ] Charging animation
- [ ] Radial progress bars
- [ ] Bluetooth device list (connected only)
- [ ] Settings menu
- [ ] Navigation tabs
- [ ] About view
- [ ] Onboarding flow (4 screens)

### Smoke Test
1. Launch app — menu bar icon visible
2. Click icon — HUD opens with settings view
3. Plug/unplug charger — HUD alert triggers
4. Bluetooth devices appear with battery levels
5. Settings toggle works (gear icon)
6. Close/reopen lid (sleep/wake) — no crash
7. Navigation between settings and devices views
8. Hover over pill — Shelf appears with quick-action buttons
9. Click gear in Shelf — Panel opens with Settings tab

---

## Upstream Issues Cross-Reference

Issues from the [original BatteryBoi repo](https://github.com/thebarbican19/BatteryBoi/issues) and their status in Recharged:

| Upstream | Description | Status in Recharged |
|----------|-------------|---------------------|
| #44, #46, #43, #42 | Crash on sleep/wake | ServiceContainer architecture prevents most; explicit wake handling in improvements-prd.md Chunk 2 |
| #49 | Recurring notification fatigue | Root cause: hysteresis threshold. Fix in improvements-prd.md Chunk 11A |
| #64 | "Charging..." shown at 100% | Fix in improvements-prd.md Chunk 1G |
| #60 | Battery % shows "%d" in Turkish | Locale-sensitive formatting in improvements-prd.md Chunk 11B |
| #57 | Pop-up window not showing | Addressed by WindowService HUD state machine |
| #55 | Demands Command Line Tools | Not applicable (different build setup) |
| #66 | Battery % hard to read past 50% | Open — contrast/visibility improvement needed |
| #41 | Menu bar icon too large | Partially addressed by dynamic status item sizing (Chunk 14B) |
| #39 | Window off-center with notch | Addressed by 6-position window system in WindowService |
| #37 | Bluetooth devices not detected | Root cause: battery never updates (Chunk 1C), stale pruning (Chunk 1D) |
| #35 | Animation stops working | Addressed by animation debouncing in WindowService |
| #30 | In-app update mechanism | Done — Sparkle 2 integrated |
| #29 | Crash after restart on Sonoma | Addressed by ServiceContainer lifecycle |
| #26 | Different icons on dual displays | Open — display-specific icon rendering |
| #23 | Mini mode for notch MacBooks | Open — aspirational feature |
| #22 | Mouse wheel scroll in settings | Open — clamshell mode support |
| #21 | Hardware battery percentage | IOKitBatteryService provides raw IOKit values |
| #20 | Cycle count and health | Done — `SettingsDisplayType.cycle` and BatteryMetricsObject |
| #1 | Power mode indicator/switcher | Partially done — `BatteryModeType` exists, power save toggle via AppleScript |
