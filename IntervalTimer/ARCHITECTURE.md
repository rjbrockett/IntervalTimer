# IntervalTimer - Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER DEVICES                             │
├─────────────────┬─────────────────┬─────────────────────────────┤
│                 │                 │                              │
│   📱 iPhone     │   💻 Mac       │   ⌚ Apple Watch            │
│                 │                 │                              │
│  ┌───────────┐  │  ┌───────────┐  │  ┌─────────────────────┐   │
│  │ContentView│  │  │ContentView│  │  │ WatchContentView    │   │
│  └─────┬─────┘  │  └─────┬─────┘  │  └──────────┬──────────┘   │
│        │        │        │        │             │               │
│  ┌─────▼─────┐  │  ┌─────▼─────┐  │  ┌──────────▼──────────┐   │
│  │ Template  │  │  │ Template  │  │  │  Template Picker    │   │
│  │  Editor   │  │  │  Editor   │  │  │                     │   │
│  └─────┬─────┘  │  └─────┬─────┘  │  └──────────┬──────────┘   │
│        │        │        │        │             │               │
│        │        │        │        │  ┌──────────▼──────────┐   │
│        │        │        │        │  │ WorkoutSessionView  │   │
│        │        │        │        │  │                     │   │
│        │        │        │        │  │ ┌─────────────────┐ │   │
│        │        │        │        │  │ │ WorkoutPlayer   │ │   │
│        │        │        │        │  │ └─────────────────┘ │   │
│        │        │        │        │  │ ┌─────────────────┐ │   │
│        │        │        │        │  │ │ HealthKitMgr    │ │   │
│        │        │        │        │  │ └─────────────────┘ │   │
│        │        │        │        │  └─────────────────────┘   │
└────────┼────────┴────────┼────────┴──────────┼─────────────────┘
         │                 │                   │
         └─────────────────┼───────────────────┘
                           │
                  ┌────────▼────────┐
                  │   SwiftData     │
                  │  Model Context  │
                  └────────┬────────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────▼─────┐    ┌─────▼──────┐    ┌────▼─────┐
    │ Workout  │    │ Interval   │    │ Interval │
    │ Template │───▶│   Block    │───▶│   Item   │
    └──────────┘    └────────────┘    └──────────┘
         │                                    
         │          Model Relationships:
         │          Template → Blocks (cascade)
         │          Block → Items (cascade)
         │
         └──────────────┐
                        │
                  ┌─────▼─────┐
                  │ CloudKit  │
                  │ Container │
                  └─────┬─────┘
                        │
                  ┌─────▼─────┐
                  │   iCloud  │
                  └───────────┘


═══════════════════════════════════════════════════════════════════
                         DATA FLOW
═══════════════════════════════════════════════════════════════════

CREATE TEMPLATE (iPhone/Mac):
────────────────────────────
User creates template
         │
         ▼
ContentView adds WorkoutTemplate
         │
         ▼
SwiftData ModelContext.insert()
         │
         ▼
ModelConfiguration syncs to CloudKit
         │
         ▼
iCloud stores template
         │
         ▼
Other devices receive via CloudKit
         │
         ▼
SwiftData automatically updates @Query


RUN WORKOUT (Apple Watch):
────────────────────────────
User selects template
         │
         ▼
WorkoutSessionView created
         │
         ├─────────────────────┬──────────────────────┐
         ▼                     ▼                      ▼
  WorkoutPlayer          HealthKitManager       SwiftUI Views
         │                     │                      │
         ▼                     ▼                      │
  Flatten template      Request authorization        │
    into steps               │                        │
         │                   ▼                        │
         ▼             Start HKWorkoutSession         │
  Start timer                │                        │
         │                   ▼                        │
         ├──────────────▶ Collect HR data             │
         │                   │                        │
         ▼                   ▼                        │
  Update elapsed       Publish HR to view ────────────┘
    time & step              │
         │                   │
         ▼                   ▼
  currentStepName     currentHeartRate
  nextStepName        activeEnergyBurned
  elapsedTotal               │
         │                   │
         └───────────────────┴─────────▶ UI displays
                                         live metrics


PAUSE/RESUME:
─────────────
User swipes right
         │
         ▼
WorkoutSessionView.swipeGesture
         │
         ├─────────────────────┬──────────────────────┐
         ▼                     ▼                      ▼
  player.pause()      healthKit.pauseWorkout()  Show overlay
         │                     │                      │
         ▼                     ▼                      │
  state = .paused    session.pause()                 │
         │                     │                      │
         └─────────────────────┴──────────────────────┘


END WORKOUT:
────────────
User taps End (or completes)
         │
         ▼
player.end()
         │
         ▼
healthKit.endWorkout()
         │
         ▼
session.end()
         │
         ▼
builder.endCollection()
         │
         ▼
builder.finishWorkout()
         │
         ▼
HKWorkout saved to HealthKit
         │
         ▼
Appears in Health & Fitness apps


═══════════════════════════════════════════════════════════════════
                      COMPONENT DIAGRAM
═══════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│                         iOS / macOS                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ IntervalTimerApp.swift                                  │    │
│  │  • Entry point (@main)                                  │    │
│  │  • Sets up .modelContainer                              │    │
│  │  • Configures CloudKit sync                             │    │
│  └──────────────────────┬───────────────────────────────────┘    │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │ ContentView.swift                                         │   │
│  │  • Template list (@Query)                                │   │
│  │  • Add/delete templates                                  │   │
│  │  • NavigationSplitView                                   │   │
│  │  • Seeds sample data                                     │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │ TemplateEditorView.swift                                 │   │
│  │  • Edit template name                                    │   │
│  │  • Add/edit/delete/reorder blocks                        │   │
│  │  • For each block:                                       │   │
│  │    - BlockEditorSection                                  │   │
│  │      • Edit block name & repeat count                    │   │
│  │      • Add/edit/delete/reorder intervals                 │   │
│  │      • For each interval:                                │   │
│  │        - IntervalRowView                                 │   │
│  │          • Edit name & duration                          │   │
│  │          • Duplicate interval                            │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│                         watchOS                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ IntervalTimerWatchApp.swift                             │    │
│  │  • Entry point (@main)                                  │    │
│  │  • Sets up .modelContainer                              │    │
│  └──────────────────────┬───────────────────────────────────┘    │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │ WatchContentView.swift                                   │   │
│  │  • Template list (@Query)                                │   │
│  │  • Select to start workout                               │   │
│  │  • Empty state when no templates                         │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │ WorkoutSessionView.swift                                 │   │
│  │  • Full-screen workout UI                                │   │
│  │  • TabView with 2 pages:                                 │   │
│  │    - Page 1: Time, interval, next, HR                    │   │
│  │    - Page 2: Calories, progress                          │   │
│  │  • Swipe gestures:                                       │   │
│  │    - Right → Pause                                       │   │
│  │    - Left → Resume (when paused)                         │   │
│  │  • Pause overlay:                                        │   │
│  │    - Skip Previous/Next                                  │   │
│  │    - Resume                                              │   │
│  │    - End Workout                                         │   │
│  └────────┬─────────────────────────────────┬───────────────┘   │
│           │                                 │                   │
│  ┌────────▼──────────────┐     ┌────────────▼──────────────┐   │
│  │ WorkoutPlayer.swift   │     │ HealthKitManager.swift    │   │
│  │  • @Observable        │     │  • @Observable            │   │
│  │  • State machine      │     │  • HKWorkoutSession       │   │
│  │  • Flatten template   │     │  • HKLiveWorkoutBuilder   │   │
│  │  • Timer updates      │     │  • Heart rate delegate    │   │
│  │  • Pause/resume/skip  │     │  • Start/pause/end        │   │
│  └───────────────────────┘     └───────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│                       Shared Models                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │ WorkoutTemplate.swift                                   │    │
│  │  @Model                                                 │    │
│  │  • id: UUID                                             │    │
│  │  • name: String                                         │    │
│  │  • createdAt, updatedAt: Date                           │    │
│  │  • blocks: [IntervalBlock] @Relationship(cascade)       │    │
│  └──────────────────────┬───────────────────────────────────┘    │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │ IntervalBlock.swift                                      │   │
│  │  @Model                                                  │   │
│  │  • id: UUID                                              │   │
│  │  • name: String?                                         │   │
│  │  • repeatCount: Int                                      │   │
│  │  • sortOrder: Int                                        │   │
│  │  • intervals: [IntervalItem] @Relationship(cascade)      │   │
│  │  • func duplicate() -> IntervalBlock                     │   │
│  └──────────────────────┬───────────────────────────────────┘   │
│                         │                                        │
│  ┌──────────────────────▼───────────────────────────────────┐   │
│  │ IntervalItem.swift                                       │   │
│  │  @Model                                                  │   │
│  │  • id: UUID                                              │   │
│  │  • name: String                                          │   │
│  │  • duration: TimeInterval                                │   │
│  │  • sortOrder: Int                                        │   │
│  │  • func duplicate() -> IntervalItem                      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│                        Utilities                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TimeFormatter.swift                                             │
│   • formatElapsed(_ seconds) -> "MM:SS"                          │
│   • formatDuration(_ seconds) -> "Xm Ys"                         │
│   • formatRemaining(_ seconds) -> countdown                      │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘


┌─────────────────────────────────────────────────────────────────┐
│                          Tests                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  WorkoutPlayerTests.swift                                        │
│   • @Suite with Swift Testing                                   │
│   • Tests for:                                                   │
│     - Template flattening (single/multiple blocks)               │
│     - Repeat expansion                                           │
│     - Pause/resume state                                         │
│     - Skip forward/backward                                      │
│     - Current/next step tracking                                 │
│     - Edge cases (last step, empty templates)                    │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

## Key Design Patterns

### 1. SwiftData + CloudKit
- **Single source of truth**: All devices read from SwiftData
- **Automatic sync**: `cloudKitDatabase: .automatic` handles everything
- **No manual queries**: `@Query` macro auto-updates views
- **Cascade deletes**: Deleting template removes all blocks/items

### 2. Observable Pattern
- **WorkoutPlayer**: Uses `@Observable` for automatic UI updates
- **HealthKitManager**: Publishes HR data reactively
- **No ObservableObject**: Modern Swift Observation (no @Published)

### 3. Separation of Concerns
- **Models**: Pure data structures
- **WorkoutPlayer**: Pure Swift state machine (no UIKit/SwiftUI)
- **Views**: SwiftUI presentation layer only
- **HealthKitManager**: Platform-specific HealthKit wrapper

### 4. Composition over Inheritance
- Templates contain Blocks contain Items (composition)
- No complex inheritance hierarchies
- Easy to test individual components

### 5. Immutable by Default
- IDs are UUID (never change)
- State changes through methods (pause/resume)
- SwiftData handles persistence mutations

## State Management

### WorkoutPlayer States
```
   ┌──────────┐
   │  .running │ ──pause()──▶ ┌─────────┐
   └──────────┘               │ .paused │
        ▲                     └─────────┘
        │                          │
        └─────────resume()─────────┘
        
        │
        └─────────end()────────▶ ┌────────┐
                                 │ .ended │
                                 └────────┘
```

### HealthKit Session States
```
HKWorkoutSession mirrors WorkoutPlayer:
- .running → session.startActivity()
- .paused → session.pause()
- .resumed → session.resume()
- .ended → session.end() + builder.finishWorkout()
```

## Thread Safety

- **SwiftData**: Main actor by default
- **WorkoutPlayer**: Main actor (uses Timer)
- **HealthKitManager**: Delegates run on background queue
  - Published properties are @MainActor
- **UI Updates**: Always on main thread

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Flatten template | O(n) | n = total intervals, done once at start |
| Get current step | O(1) | Index into array |
| Skip forward/back | O(1) | Increment/decrement index |
| Timer update | O(1) | Simple timestamp math |
| SwiftData insert | O(1) | Background sync to CloudKit |
| CloudKit sync | Variable | Depends on network, async |

## Memory Footprint

- **Flattened steps**: ~100 bytes per step
- **Typical workout**: 10-50 steps = 1-5 KB
- **Models in memory**: Only active template loaded
- **CloudKit cache**: Managed by system

## Future Architecture Considerations

### For Milestone 8 (Watch Template Editor):
- Reuse existing `TemplateEditorView` logic
- Adapt UI for smaller watch screen
- Use `NavigationStack` for drill-down editing
- Same SwiftData context = instant sync

### For Complications:
- Create `WidgetExtension` target
- Use App Groups to share data
- Timeline provider queries SwiftData
- Show next scheduled workout

### For Export/Import:
- Add `Codable` conformance to models
- Export to JSON via `JSONEncoder`
- Import creates new UUIDs (no conflicts)
- Share via standard share sheet
