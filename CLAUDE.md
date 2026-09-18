# IntervalTimer - Project Context

## Overview
A multiplatform interval timer app (iOS, macOS, watchOS) built with SwiftUI and SwiftData. Users create reusable workout/study routines with nested interval blocks, then play them back with real-time tracking.

## Architecture

### Targets
- **IntervalTimer** (iOS/macOS) — Full template editor + workout playback with GPS distance
- **IntervalTimerWatch Watch App** (watchOS) — Read-only template list + workout playback with HealthKit

### Shared files are duplicated (not a shared framework)
Models and WorkoutPlayer are copied into both targets. The project uses Xcode objectVersion 77 (file-system-synchronized groups), so cross-target file sharing would require fragile pbxproj edits. These can be migrated to a Swift Package later.

## Data Model (SwiftData)

```
WorkoutTemplate
├── name: String
├── sortOrder: Int
├── showHeartRateZones: Bool
├── blocks: [IntervalBlock]  (@Relationship, cascade delete)

IntervalBlock
├── name: String?
├── repeatCount: Int
├── sortOrder: Int
├── intervals: [IntervalItem]  (cascade delete)
├── childBlocks: [IntervalBlock]  (nested, up to 4 levels)
├── parentBlock: IntervalBlock?

IntervalItem
├── name: String
├── duration: TimeInterval
├── sortOrder: Int
├── trackDistance: Bool
├── distanceGoal: Double?  (meters, nil = no goal)
```

Adding new fields to models requires updating BOTH iOS and watch copies, and users must delete/reinstall the app (no migration schema set up).

## Key Files

### iOS Target (IntervalTimer/)
| File | Purpose |
|------|---------|
| `IntervalTimerApp.swift` | @main entry, ModelContainer setup |
| `ContentView.swift` | Routines list with reorder/delete, seed data |
| `ViewsTemplateEditorView.swift` | Full editor: view/edit mode toggle, blocks, intervals, NumericTextField/DecimalTextField (UIViewRepresentable) |
| `WorkoutSessionView.swift` | iOS workout playback with controls, progress bar |
| `LocationManager.swift` | CoreLocation GPS distance tracking |
| `ModelsWorkoutTemplate.swift` | WorkoutTemplate @Model |
| `ModelsIntervalBlock.swift` | IntervalBlock @Model with nesting |
| `ModelsIntervalItem.swift` | IntervalItem @Model |
| `WorkoutPlayer.swift` | Flattens template hierarchy into linear PlaybackSteps, handles timing/controls |
| `UtilitiesTimeFormatter.swift` | Time formatting utilities |

### Watch Target (IntervalTimerWatch Watch App/)
| File | Purpose |
|------|---------|
| `IntervalTimerWatchApp.swift` | @main entry, ModelContainer setup |
| `WatchContentView.swift` | Routine list, seed data (5 sample routines) |
| `WorkoutSessionView.swift` | Watch workout: TabView (primary metrics + secondary metrics), inline controls, heart rate zone background |
| `HealthKitManager.swift` | HKWorkoutSession, heart rate, calories, distance, heart rate zones (220 - age) |
| Model/Player files | Duplicated from iOS |

### Legacy files in iOS target (unused, wrapped in #if os(watchOS))
`WatchHealthKitManager.swift`, `WatchIntervalTimerWatchApp.swift`, `WatchWatchContentView.swift`, `WatchWorkoutSessionView.swift` — These predate the watch target and are dead code.

## Key Features & Implementation Details

### View/Edit Mode (ViewsTemplateEditorView)
- `@State private var isEditing` toggles between read-only view and full editor
- Edit mode: pencil toolbar button enters, Done saves + exits, Cancel reverts via child ModelContext
- `.environment(\.editMode, .constant(.active))` enables drag handles in edit mode
- `.navigationBarBackButtonHidden(isEditing)` prevents accidental navigation

### Transactional Editing
- TemplateEditorView creates a child `ModelContext` for editing
- Cancel discards by re-fetching from the container
- Done saves the child context

### Keyboard Handling (iOS)
- `NumericTextField` and `DecimalTextField` are `UIViewRepresentable` wrappers
- Use UIKit `UIToolbar` as `inputAccessoryView` with bold "Done" button
- Must use explicit `title: "Done"` (not `.barButtonSystemItem: .done` which renders as checkmark in iOS 26)
- `.scrollDismissesKeyboard(.immediately)` on the editor list

### Heart Rate Zones (Watch)
- Enabled per-template via `showHeartRateZones: Bool`
- HealthKitManager reads date of birth → calculates max HR (220 - age)
- 5 zones: Zone 1 (<60%, blue) → Zone 5 (90%+, red)
- Background color animates between zones at 30% opacity
- Zone label shown in top-left corner

### Distance Tracking
- iOS: CoreLocation (`LocationManager`), 5m filter, ignores >20m accuracy and >100m jumps
- Watch: HealthKit `distanceWalkingRunning` from HKWorkoutSession
- Per-interval toggle + optional distance goal (stored in meters, displayed in miles)
- Primary page shows goal progress; secondary page shows total distance only

### Workout Playback (WorkoutPlayer)
- Flattens nested blocks into linear `[PlaybackStep]` array respecting repeatCount
- States: `.running`, `.paused`, `.ended`
- Skip to next/previous (previous rewinds if >3s into step)
- Auto-advances when step duration exceeded
- Timer fires every 0.1 seconds

### Watch Workout UI
- Primary page: interval name, countdown (48pt), info row (HR · elapsed · step), NEXT label, backward/pause/forward buttons
- Secondary page (swipe right): calories, heart rate, total distance, elapsed time
- Pause overlay: Resume + End Workout buttons (swipe left to resume)
- Navigation bar hidden (`.toolbar(.hidden, for: .navigationBar)`)
- End Workout dismisses fullScreenCover back to routine list

## Code Style
- SwiftUI with @Observable (not Combine)
- PascalCase types, camelCase properties
- 4-space indentation
- `#if os(iOS)` / `#if os(macOS)` for platform-specific code
- Testing framework: Swift Testing (not XCTest)

## Naming
- User-facing: "Routines" (not "Templates" or "Workouts")
- Internal code still uses `template`/`WorkoutTemplate` variable names
