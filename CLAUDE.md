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

Adding new fields to models requires updating BOTH iOS and watch copies.

### Data Migration (SwiftData VersionedSchema)
- Both targets have `ModelsMigration.swift` with `SchemaV1` (current schema) and `IntervalTimerMigrationPlan`
- ModelContainer is initialized with `migrationPlan: IntervalTimerMigrationPlan.self`
- When adding/removing/renaming model fields, create a new `SchemaV2` with model snapshots of the new schema, add a migration stage to `IntervalTimerMigrationPlan.stages`, and update both iOS and watch copies
- Lightweight migrations (adding optional fields, adding fields with defaults) use `.lightweight(fromVersion:toVersion:)`
- Custom migrations (renaming, data transforms) use `.custom(fromVersion:toVersion:willMigrate:didMigrate:)`
- Always keep the previous schema versions intact — they're needed for users upgrading from older versions

### CloudKit Sync
- Both targets use `ModelConfiguration(cloudKitDatabase: .automatic)` with shared container `iCloud.TypewriterMunky.IntervalTimer`
- `createdAt` and `updatedAt` are `Date?` (CloudKit requires non-optional properties to have static defaults; `Date()` is dynamic)
- Seed data guarded by `UserDefaults("hasSeededSampleData")` to prevent duplicates when devices sync
- Conflict resolution: last-writer-wins at property level (SwiftData/CloudKit default)
- Watch is read-only for templates, so conflicts are unlikely
- watchOS CloudKit sync can be slow (30s to several minutes) — this is normal Apple Watch behavior
- Users must be signed into iCloud for sync to work
- Switching to CloudKit-backed store creates a new store file; users must delete/reinstall after enabling

### Routine Sharing (CloudKit Public Database)
- Creator publishes routine as JSON to CloudKit public DB → generates `intervaltimer://routine/<recordName>` link
- Recipient opens link → routine downloaded into their private SwiftData store as a read-only "Downloaded" routine
- Downloaded routines sync to recipient's watch automatically (via existing `cloudKitDatabase: .automatic`)
- Two tabs in ContentView: "My Routines" (owned, editable) and "Downloaded" (from others, read-only)
- Update flow: on app launch, checks each downloaded routine's source for newer `updatedAt`
  - **Accept Update**: replaces blocks with new version, stays linked
  - **Keep Current Version**: unlinks routine, moves to My Routines, becomes editable. No future updates.
- **Make a Copy**: deep-copies a downloaded routine into My Routines as editable. Original stays in Downloaded.
- `originalTemplateID` (UUID) identifies "the same routine" across all users — preserved through publish, download, copy, and unlink. Used for future stats comparison feature.
- Sharing fields on WorkoutTemplate: `isDownloaded`, `sourceRecordName`, `sourceUpdatedAt`, `originalTemplateID`, `isPublished`, `publishedRecordName`, `creatorName`, `hasAvailableUpdate`
- URL scheme: `intervaltimer://` (custom scheme for dev; will migrate to Universal Links with a web domain before App Store submission)
- CloudKit operations are iOS-only; watch just sees results via private DB sync
- Stats comparison is a planned future feature (architecture supports it via `originalTemplateID`)

## Key Files

### iOS Target (IntervalTimer/)
| File | Purpose |
|------|---------|
| `IntervalTimerApp.swift` | @main entry, ModelContainer setup, `.onOpenURL` handler for share links |
| `ContentView.swift` | TabView: My Routines + Downloaded tabs, import flow for incoming links |
| `ViewsTemplateEditorView.swift` | Full editor: view/edit mode toggle, blocks, intervals, share button, update banner, Make a Copy |
| `WorkoutSessionView.swift` | iOS workout playback with controls, progress bar |
| `LocationManager.swift` | CoreLocation GPS distance tracking |
| `ModelsWorkoutTemplate.swift` | WorkoutTemplate @Model |
| `ModelsIntervalBlock.swift` | IntervalBlock @Model with nesting |
| `ModelsIntervalItem.swift` | IntervalItem @Model |
| `WorkoutPlayer.swift` | Flattens template hierarchy into linear PlaybackSteps, handles timing/controls |
| `ModelsMigration.swift` | VersionedSchema (SchemaV1) + SchemaMigrationPlan |
| `UtilitiesTimeFormatter.swift` | Time formatting utilities |
| `SharingModels.swift` | Codable transfer structs for JSON serialization |
| `SharingRoutineSerializer.swift` | Convert between SwiftData models and Codable payloads |
| `SharingCloudKitService.swift` | CloudKit public DB: publish, fetch, unpublish, update check |
| `SharingUpdateChecker.swift` | On-launch update checking, accept/unlink flows |
| `ShareRoutineView.swift` | Publishing UI: creator name, link copy/share, push update, unpublish |

### Watch Target (IntervalTimerWatch Watch App/)
| File | Purpose |
|------|---------|
| `IntervalTimerWatchApp.swift` | @main entry, ModelContainer setup |
| `WatchContentView.swift` | Routine list, seed data (5 sample routines) |
| `WorkoutSessionView.swift` | Watch workout: TabView (primary metrics + secondary metrics), inline controls, heart rate zone background |
| `HealthKitManager.swift` | HKWorkoutSession, heart rate, calories, distance, heart rate zones (220 - age) |
| `ModelsMigration.swift` | VersionedSchema (SchemaV1) + SchemaMigrationPlan (duplicated from iOS) |
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

### Untimed Intervals (Manual Advance)
- Duration of 0 means "no timer" — interval only advances when user presses Next
- `WorkoutPlayer.isCurrentStepUntimed` returns true when `currentStep.duration <= 0`
- Auto-advance logic skips untimed steps (`duration > 0` check)
- UI shows elapsed time counting up in gray (instead of countdown)
- DurationPickerView has "No Timer (manual advance)" toggle that sets duration to 0
- `formatDuration` returns "Manual" for duration ≤ 0

### Workout Playback (WorkoutPlayer)
- Flattens nested blocks into linear `[PlaybackStep]` array respecting repeatCount
- States: `.running`, `.paused`, `.ended`
- Skip to next/previous (previous rewinds if >3s into step)
- Auto-advances when step duration exceeded (skips untimed steps)
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
