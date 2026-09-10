# IntervalTimer — Project Spec & Build Instructions

## What this app is

A multiplatform Apple app (iOS + macOS + watchOS) for building and running
custom run/rest interval workouts. Templates can be created or edited on
iPhone, Mac, or directly on the Watch. The Watch app plays back a template
during a workout, showing live heart rate, and supports pause/resume and
manual interval navigation via swipe gestures.

Use this document as the spec. Work through the milestones in order — each
one should build and run before moving to the next. Ask before making
architectural decisions not covered here; don't guess on data model shape,
sync strategy, or entitlements.

---

## Target platforms & project setup

- **Xcode 26.3+**, deployment targets: iOS 18+, macOS 15+, watchOS 11+.
- Single Xcode project, multiplatform (iOS/macOS) app target + a companion
  watchOS app target. Use SwiftUI throughout — no UIKit/AppKit unless
  something is genuinely unreachable from SwiftUI.
- Enable **iCloud (CloudKit)** and **HealthKit** capabilities on both the
  main app target and the watchOS target.
- Bundle identifiers should share a prefix so the watch app is recognized as
  a companion to the iOS app (e.g. `com.yourname.intervalrun` and
  `com.yourname.intervalrun.watchkitapp`).
- Set up an App Group shared between iOS/macOS/watchOS targets for any
  local (non-CloudKit) shared state if needed later.

---

## Data model

Use **SwiftData**, synced via CloudKit (`ModelConfiguration` with
`cloudKitDatabase: .automatic`). This is the shared source of truth across
all three platforms — templates created on any device should sync to the
others automatically.

Three model types, nested:

```swift
@Model
final class IntervalItem {
    var id: UUID
    var name: String            // user-defined, freeform ("Sprint", "Walk", "Recovery")
    var duration: TimeInterval  // seconds
    var sortOrder: Int
    // no fixed "type" enum — name is freeform per the product requirement
}

@Model
final class IntervalBlock {
    var id: UUID
    var name: String?           // optional label for the block
    var repeatCount: Int        // default 1
    var sortOrder: Int
    @Relationship(deleteRule: .cascade) var intervals: [IntervalItem]
}

@Model
final class WorkoutTemplate {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var blocks: [IntervalBlock]
}
```

Key requirements this model must support:
- **Duplicating a single IntervalItem** within a block (deep copy with a new
  UUID, inserted after the original, sortOrder shifted).
- **Duplicating an entire IntervalBlock** (deep copy of the block and all
  its intervals, new UUIDs throughout).
- **Reordering** intervals within a block and blocks within a template
  (drive off `sortOrder`).
- A block with `repeatCount > 1` expands at playback time into that many
  repetitions — do **not** duplicate the underlying IntervalItems in storage
  to represent repeats; the repeat count is a property of the block, and the
  playback engine (below) expands it at runtime.

---

## Playback engine (shared logic, used by watchOS)

Build this as a plain Swift state machine, **independent of any UI/view
code**, so it's testable and so pausing/resuming/skipping is just state
mutation:

```swift
@Observable
final class WorkoutPlayer {
    enum State { case running, paused, ended }

    private(set) var state: State = .running
    private(set) var elapsedTotal: TimeInterval = 0
    private(set) var currentStepIndex: Int   // index into the flattened step list

    // Flatten the template's blocks/repeats into a linear list of steps up front:
    // e.g. Block(repeat: 3, [A, B]) -> [A, B, A, B, A, B]
    private var flattenedSteps: [PlaybackStep]

    func pause()
    func resume()
    func skipToNext()
    func skipToPrevious()
    func end()

    var currentStepName: String
    var nextStepName: String?   // nil if this is the last step
}
```

Flatten `WorkoutTemplate` → `[PlaybackStep]` once when a session starts
(`PlaybackStep` = interval name + duration + originating IntervalItem id).
This keeps "current" and "next" lookups trivial (`flattenedSteps[currentStepIndex]`
/ `flattenedSteps[currentStepIndex + 1]`) and makes next/previous navigation
during pause a simple index increment/decrement with bounds checking.

Timing: drive elapsed time off `Date` timestamps (start time + accumulated
paused duration), not a naive incrementing counter, so the display stays
accurate if the app is backgrounded/foregrounded.

---

## watchOS: HealthKit workout session

Continuous, reliable on-wrist heart rate requires a real workout session —
not polling `HKQuery`. Use `HKWorkoutSession` + `HKLiveWorkoutBuilder`:

- Request HealthKit authorization for heart rate (read) and workout data
  (share) on first launch of the watch app.
- Start an `HKWorkoutSession` (`.running` or `.other` activity type — ask
  the user which fits, default to `.running`) when a workout begins.
  Pausing the interval playback should call `session.pause()`;
  resuming calls `session.resume()`. Ending calls `session.end()` and
  finishes the workout via `HKLiveWorkoutBuilder`.
- Enable the **Workout Processing** background mode in the watchOS target's
  capabilities so this keeps running with the wrist down / app backgrounded.
- Surface live heart rate via the builder's `HKLiveWorkoutBuilderDelegate`
  callback, publish it into the `WorkoutPlayer` (or a sibling observable) for
  the UI to read.
- Note for the user: this will create a real entry in the Fitness/Health
  apps each time a session is run. That's expected/desired here, not a bug.

---

## watchOS UI

**Workout screen (root-level, NOT inside a NavigationStack):**
This is important — if this view is pushed onto a `NavigationStack`, the
system's edge-swipe-to-go-back gesture will conflict with the custom
swipe-to-pause gesture. Present this as the app's root view (or a
full-screen cover), not as a pushed navigation destination.

Display: total elapsed time, current interval name, next interval name,
live heart rate (BPM). Use a `TabView` with `.tabViewStyle(.page)` if you
want multiple metric pages later (matches the system Workout app's swipe-
between-pages pattern) — but the primary screen with all four values at
once should be the default landing page.

Gestures on this screen (plain `DragGesture`, not NavigationStack-driven):
- Swipe right → pause (`player.pause()`), show the pause overlay.
- Swipe left (while paused) → resume (`player.resume()`), dismiss overlay.

**Pause overlay:**
Full-screen overlay (not a `.sheet`), four controls:
- Next interval → `player.skipToNext()`
- Previous interval → `player.skipToPrevious()`
- Resume → `player.resume()`, dismiss overlay
- End session → confirmation (long-press or a confirm step) → `player.end()`,
  ends the HKWorkoutSession, navigates back to template selection.

**Template creation on-watch:** a simple list-based editor (name a template,
add/edit/duplicate/reorder intervals and blocks). Reuse the same SwiftData
models — no separate watch-only data shape.

---

## iOS / macOS UI

Template list → template editor. Editor needs:
- Add/rename/reorder/delete intervals within a block.
- Add/rename/reorder/delete blocks within a template.
- Duplicate button on both individual intervals and whole blocks.
- A `repeatCount` stepper on each block.
- Should feel like a single shared SwiftUI codebase between iOS and macOS
  (use `NavigationSplitView` so it adapts reasonably to both).

---

## Build order (do these as separate milestones, confirm each builds before moving on)

1. Project scaffolding: multiplatform app target + watchOS target, shared
   Swift package/module for the data model and playback engine, capabilities
   (iCloud/CloudKit, HealthKit, background modes) configured.
2. SwiftData models (`IntervalItem`, `IntervalBlock`, `WorkoutTemplate`) with
   CloudKit sync configured; a couple of sample templates seeded for testing.
3. iOS/macOS template list + editor UI (create, rename, reorder, duplicate,
   set repeat counts).
4. `WorkoutPlayer` state machine with unit tests (flattening logic, pause/
   resume/skip/end, elapsed time correctness) — no UI yet.
5. watchOS HealthKit workout session wrapper (start/pause/resume/end,
   live heart rate publishing).
6. watchOS workout screen (root-level view, live display of the four
   values) wired to `WorkoutPlayer` + heart rate.
7. watchOS swipe gestures + pause overlay (four buttons).
8. watchOS on-device template creation/editing screen, reusing the SwiftData
   models from step 2.
9. Polish pass: end-session confirmation, empty states, error handling for
   HealthKit authorization denial.

---

## Open questions to raise with the user before/while building

- Preferred `HKWorkoutActivityType` default (`.running` assumed above).
- Whether elapsed time shown on the watch is total session time or
  time-remaining-in-current-interval (or both, e.g. via the page-swipe
  metric pages).
- Whether ending a session early should still save a Health app entry, or
  only completed sessions should.
