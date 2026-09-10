# IntervalTimer

A multiplatform Apple app for creating and running custom interval workouts with live heart rate tracking on Apple Watch.

## Features

### iOS & macOS
- ✅ Create custom workout templates with multiple blocks
- ✅ Add intervals with custom names and durations
- ✅ Duplicate intervals and entire blocks
- ✅ Set repeat counts on blocks (e.g., repeat 5x)
- ✅ Automatic iCloud sync via CloudKit
- ✅ Reorder intervals and blocks with drag & drop

### watchOS
- ✅ Select and start workouts directly from your wrist
- ✅ Live heart rate monitoring during workouts
- ✅ Real-time interval tracking with current/next display
- ✅ Swipe gestures for pause/resume
- ✅ Manual interval navigation (skip forward/back)
- ✅ Automatic workout saving to Apple Health
- ✅ Background workout processing

## Architecture

### Data Layer
- **SwiftData** models with CloudKit sync
- Three model types: `WorkoutTemplate` → `IntervalBlock` → `IntervalItem`
- Automatic cross-device sync via `ModelConfiguration(cloudKitDatabase: .automatic)`

### Playback Engine
- `WorkoutPlayer`: Platform-independent state machine
- Flattens nested blocks/repeats into linear playback steps
- Timestamp-based timing (resilient to backgrounding)
- Supports pause/resume/skip operations

### HealthKit Integration (watchOS)
- `HKWorkoutSession` for continuous heart rate access
- `HKLiveWorkoutBuilder` for real-time metrics
- Automatic workout saving to Health app
- Background processing during workout sessions

## Project Structure

```
IntervalTimer/
├── Models/                    # SwiftData models (shared)
│   ├── WorkoutTemplate.swift
│   ├── IntervalBlock.swift
│   └── IntervalItem.swift
├── WorkoutPlayer.swift        # Playback engine (shared)
├── IntervalTimerApp.swift     # iOS/Mac app entry
├── ContentView.swift          # Template list
└── Views/
    └── TemplateEditorView.swift

Watch/
├── IntervalTimerWatchApp.swift
├── WatchContentView.swift     # Template selection
├── WorkoutSessionView.swift   # Live workout UI
└── HealthKitManager.swift     # HealthKit integration

Tests/
└── WorkoutPlayerTests.swift   # Unit tests for playback engine
```

## Setup

See [SETUP.md](SETUP.md) for detailed configuration instructions.

**Quick start:**
1. Open the project in Xcode 15.3+
2. Enable iCloud and HealthKit capabilities
3. Configure bundle identifiers with matching prefixes
4. Add privacy descriptions for HealthKit (watchOS)
5. Build and run on iOS, macOS, or watchOS

## Requirements

- **Xcode:** 15.3 or later
- **Deployment Targets:**
  - iOS 18.0+
  - macOS 15.0+
  - watchOS 11.0+
- **Capabilities:**
  - iCloud (CloudKit)
  - HealthKit (watchOS)
  - Background Modes: Workout Processing (watchOS)

## Usage

### Creating a Template (iOS/Mac)

1. Tap **+** to create a new template
2. Add blocks with the "Add Block" button
3. Add intervals to each block
4. Set durations (tap the time to edit)
5. Set repeat counts using the stepper
6. Duplicate intervals or blocks as needed
7. Templates sync automatically via iCloud

### Running a Workout (Watch)

1. Open IntervalTimer on Apple Watch
2. Select a template
3. Grant HealthKit permissions if prompted
4. **Swipe right** to pause during workout
5. While paused:
   - Tap **Next** or **Previous** to navigate intervals
   - Tap **Resume** to continue
   - Tap **End Workout** to finish
6. Workout is saved to Health app automatically

## Sample Templates

Two sample templates are created on first launch:

**5x Sprint Intervals:**
- Warmup: 5 min easy jog
- Main Set (5x): 1 min sprint + 1.5 min recovery
- Cooldown: 5 min walk

**Tabata 4 Minutes:**
- 8x (20 sec work + 10 sec rest)

## Testing

Run unit tests with `Cmd+U`:

```bash
# Tests cover:
- Template flattening logic
- Block repeat expansion
- Pause/resume state management  
- Skip forward/backward navigation
- Current/next step tracking
```

## Roadmap

Completed (Milestones 1-7):
- ✅ Project setup with multiplatform targets
- ✅ SwiftData models with CloudKit sync
- ✅ iOS/Mac template editor UI
- ✅ WorkoutPlayer state machine with tests
- ✅ HealthKit workout session integration
- ✅ watchOS workout screen with live metrics
- ✅ Swipe gestures and pause overlay

Future enhancements (Milestones 8-9):
- ⏳ watchOS on-device template creation/editing
- ⏳ End session confirmation dialog
- ⏳ Improved error handling UI
- ⏳ Haptic feedback on interval transitions
- ⏳ Workout summary screen post-session

## License

Created following the spec in `interval-app-spec.md`.

## Design Decisions

### Why timestamp-based timing?
The `WorkoutPlayer` uses `Date()` timestamps instead of a simple counter to handle backgrounding correctly. When the app goes to background and returns, elapsed time is calculated from the session start time minus any accumulated pause duration.

### Why flatten blocks at session start?
Pre-flattening the template into a linear array of steps makes current/next lookups O(1) and simplifies skip forward/backward logic. The trade-off is slightly more memory usage, but workout templates are small.

### Why a root-level workout view on watchOS?
The workout screen is presented as a full-screen cover, not pushed onto a `NavigationStack`. This prevents the system's edge-swipe-to-go-back gesture from conflicting with our custom swipe-to-pause gesture.

### Why no Combine/Dispatch?
The project uses modern Swift Concurrency (async/await, @Observable) throughout for cleaner, more maintainable code. The timer in `WorkoutPlayer` uses a simple `Timer` which is sufficient for UI updates.
