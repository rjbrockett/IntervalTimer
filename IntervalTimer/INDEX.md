# 📦 IntervalTimer - Complete File Index

## 🎯 Start Here

New to the project? Read these in order:

1. **interval-app-spec.md** - Original specification (your requirements)
2. **BUILD_SUMMARY.md** - What's been built and current status
3. **SETUP.md** - Step-by-step Xcode configuration guide
4. **README.md** - Project overview and usage

## 📱 Source Code Files

### Main App (iOS/macOS)

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `IntervalTimerApp.swift` | App entry point | ~25 | SwiftData + CloudKit setup |
| `ContentView.swift` | Template list view | ~120 | CRUD operations, sample data |
| `Views/TemplateEditorView.swift` | Template editor | ~230 | Edit blocks/intervals, duplicate |

### Data Models (Shared)

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `Models/WorkoutTemplate.swift` | Top-level template | ~30 | Name, dates, blocks relationship |
| `Models/IntervalBlock.swift` | Block with repeats | ~40 | Name, repeat count, intervals |
| `Models/IntervalItem.swift` | Individual interval | ~25 | Name, duration, sort order |

### Playback Engine (Shared)

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `WorkoutPlayer.swift` | State machine | ~180 | Flatten, pause/resume, skip, timer |

### watchOS App

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `Watch/IntervalTimerWatchApp.swift` | Watch entry point | ~15 | SwiftData setup |
| `Watch/WatchContentView.swift` | Template picker | ~50 | List templates, empty state |
| `Watch/WorkoutSessionView.swift` | Live workout UI | ~250 | Metrics, gestures, pause overlay |
| `Watch/HealthKitManager.swift` | HealthKit wrapper | ~120 | Session, HR, authorization |

### Utilities

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `Utilities/TimeFormatter.swift` | Time formatting | ~50 | Format seconds as MM:SS, Xm Ys |

### Tests

| File | Purpose | Lines | Key Features |
|------|---------|-------|--------------|
| `Tests/WorkoutPlayerTests.swift` | Unit tests | ~150 | 10 test cases with Swift Testing |

## 📚 Documentation Files

### Configuration Guides

| File | Purpose | When to Read |
|------|---------|--------------|
| `SETUP.md` | Xcode project setup | **Before building** |
| `ENTITLEMENTS_GUIDE.md` | Capabilities & permissions | During setup |

### Reference Documentation

| File | Purpose | Audience |
|------|---------|----------|
| `README.md` | Project overview | Everyone |
| `BUILD_SUMMARY.md` | What's complete | Developers |
| `ARCHITECTURE.md` | System design | Developers |
| `QUICK_REFERENCE.md` | User guide | End users |

### Original Spec

| File | Purpose | Status |
|------|---------|--------|
| `interval-app-spec.md` | Requirements doc | ✅ Reference |

## 🗂️ Recommended File Organization in Xcode

```
IntervalTimer/
├── App/
│   └── IntervalTimerApp.swift
├── Views/
│   ├── ContentView.swift
│   └── TemplateEditorView.swift
├── Models/
│   ├── WorkoutTemplate.swift
│   ├── IntervalBlock.swift
│   └── IntervalItem.swift
├── Engine/
│   └── WorkoutPlayer.swift
└── Utilities/
    └── TimeFormatter.swift

IntervalTimer Watch App/
├── App/
│   └── IntervalTimerWatchApp.swift
├── Views/
│   ├── WatchContentView.swift
│   └── WorkoutSessionView.swift
└── Managers/
    └── HealthKitManager.swift

IntervalTimerTests/
└── WorkoutPlayerTests.swift

Documentation/
├── README.md
├── SETUP.md
├── BUILD_SUMMARY.md
├── ARCHITECTURE.md
├── QUICK_REFERENCE.md
├── ENTITLEMENTS_GUIDE.md
└── interval-app-spec.md
```

## 📊 Code Statistics

| Category | Files | Lines of Code | Percentage |
|----------|-------|---------------|------------|
| iOS/Mac Views | 2 | ~350 | 28% |
| watchOS Views | 2 | ~300 | 24% |
| Models | 3 | ~95 | 8% |
| Engine | 1 | ~180 | 14% |
| HealthKit | 1 | ~120 | 10% |
| Utilities | 1 | ~50 | 4% |
| Tests | 1 | ~150 | 12% |
| **Total** | **11** | **~1,245** | **100%** |

## 🎓 Learning Path

### For Beginners

Start with these smaller, simpler files:

1. `Models/IntervalItem.swift` - Simple data model
2. `Models/IntervalBlock.swift` - Relationship example
3. `Models/WorkoutTemplate.swift` - Complete model hierarchy
4. `Utilities/TimeFormatter.swift` - Pure functions
5. `Watch/WatchContentView.swift` - Simple list view

### For Intermediate Developers

Study these more complex implementations:

1. `WorkoutPlayer.swift` - State machine pattern
2. `Views/TemplateEditorView.swift` - Complex UI composition
3. `Watch/HealthKitManager.swift` - Framework integration
4. `Tests/WorkoutPlayerTests.swift` - Swift Testing examples

### For Advanced Developers

Deep dive into:

1. `Watch/WorkoutSessionView.swift` - Gestures, state, animation
2. `IntervalTimerApp.swift` - App architecture decisions
3. `ARCHITECTURE.md` - System design rationale
4. SwiftData + CloudKit sync mechanics

## 🔍 Quick Find

### Where is... ?

| Looking for | File | Section |
|-------------|------|---------|
| Template creation | `ContentView.swift` | `addTemplate()` |
| Template editing | `TemplateEditorView.swift` | Whole file |
| Block duplication | `TemplateEditorView.swift` | `BlockEditorSection.duplicateBlock()` |
| Interval duplication | `TemplateEditorView.swift` | `IntervalRowView.duplicateInterval()` |
| Flattening logic | `WorkoutPlayer.swift` | `flatten(template:)` |
| Pause/resume | `WorkoutPlayer.swift` | `pause()`, `resume()` |
| Skip controls | `WorkoutPlayer.swift` | `skipToNext()`, `skipToPrevious()` |
| Heart rate | `Watch/HealthKitManager.swift` | `HKLiveWorkoutBuilderDelegate` |
| Swipe gestures | `Watch/WorkoutSessionView.swift` | `swipeGesture`, `resumeSwipeGesture` |
| Sample data | `ContentView.swift` | `seedSampleData()` |
| Time formatting | `Utilities/TimeFormatter.swift` | All methods |
| CloudKit config | `IntervalTimerApp.swift` | `.modelContainer()` |
| HealthKit auth | `Watch/HealthKitManager.swift` | `requestAuthorization()` |

### What uses... ?

| Component | Used By | Purpose |
|-----------|---------|---------|
| `WorkoutTemplate` | All views | Data model |
| `WorkoutPlayer` | `WorkoutSessionView` | Playback logic |
| `HealthKitManager` | `WorkoutSessionView` | HR tracking |
| `TimeFormatter` | Views (optional) | Display time |
| SwiftData | App entry points | Persistence |
| CloudKit | SwiftData | Sync |
| `@Observable` | Player, HealthKit | State updates |
| `@Query` | List views | Data fetching |

## 🏗️ Build Order (from spec)

| Milestone | Status | Files Involved |
|-----------|--------|----------------|
| 1. Project scaffolding | ⏳ Manual | Xcode project |
| 2. SwiftData models | ✅ Done | `Models/*.swift` |
| 3. iOS/Mac UI | ✅ Done | `ContentView.swift`, `TemplateEditorView.swift` |
| 4. WorkoutPlayer | ✅ Done | `WorkoutPlayer.swift`, `WorkoutPlayerTests.swift` |
| 5. HealthKit | ✅ Done | `HealthKitManager.swift` |
| 6. watchOS UI | ✅ Done | `WorkoutSessionView.swift` |
| 7. Gestures | ✅ Done | `WorkoutSessionView.swift` |
| 8. Watch editor | ⏳ Future | TBD |
| 9. Polish | ⏳ Future | Multiple |

## 📝 File Dependencies

### Dependency Graph

```
IntervalTimerApp.swift
  └─▶ ContentView.swift
        └─▶ TemplateEditorView.swift
              └─▶ Models/ (WorkoutTemplate, IntervalBlock, IntervalItem)

IntervalTimerWatchApp.swift
  └─▶ WatchContentView.swift
        └─▶ WorkoutSessionView.swift
              ├─▶ WorkoutPlayer.swift
              │     └─▶ Models/
              └─▶ HealthKitManager.swift
                    └─▶ HealthKit framework

WorkoutPlayerTests.swift
  └─▶ WorkoutPlayer.swift
        └─▶ Models/
```

### No Dependencies
These files are standalone:
- `TimeFormatter.swift`
- All model files (they only depend on SwiftData)

## 🧪 Testing Coverage

| Component | Test File | Coverage |
|-----------|-----------|----------|
| `WorkoutPlayer` | `WorkoutPlayerTests.swift` | ✅ High (10 tests) |
| Models | None | ⏳ Future |
| HealthKitManager | None | ⏳ Future (requires mocking) |
| Views | None | ⏳ Future (UI tests) |

## 📦 Target Membership

| File | iOS/Mac | watchOS | Tests |
|------|---------|---------|-------|
| `IntervalTimerApp.swift` | ✅ | ❌ | ❌ |
| `ContentView.swift` | ✅ | ❌ | ❌ |
| `TemplateEditorView.swift` | ✅ | ❌ | ❌ |
| Models/*.swift | ✅ | ✅ | ✅ |
| `WorkoutPlayer.swift` | ✅ | ✅ | ✅ |
| `TimeFormatter.swift` | ✅ | ✅ | ❌ |
| Watch/*.swift | ❌ | ✅ | ❌ |
| `WorkoutPlayerTests.swift` | ❌ | ❌ | ✅ |

## 🎨 SwiftUI Views Hierarchy

### iOS/Mac
```
IntervalTimerApp
  └─ WindowGroup
      └─ ContentView
          └─ NavigationSplitView
              ├─ List (sidebar)
              └─ TemplateEditorView (detail)
                  └─ List
                      └─ ForEach(blocks)
                          └─ BlockEditorSection
                              └─ ForEach(intervals)
                                  └─ IntervalRowView
```

### watchOS
```
IntervalTimerWatchApp
  └─ WindowGroup
      └─ WatchContentView
          └─ NavigationStack
              └─ List
          
          └─ .fullScreenCover
              └─ WorkoutSessionView
                  ├─ TabView(.page)
                  │   ├─ Page 1: Main metrics
                  │   └─ Page 2: Secondary metrics
                  └─ if showingPauseOverlay
                      └─ ZStack (overlay)
                          └─ Pause controls
```

## 📖 Code Style

This project follows:
- ✅ Apple's Swift API Design Guidelines
- ✅ SwiftUI best practices
- ✅ Modern Swift (6.0+)
- ✅ Descriptive naming
- ✅ Type inference where clear
- ✅ Private by default
- ✅ Functional programming patterns

## 🚀 Next Steps

1. **Read SETUP.md** to configure Xcode project
2. **Add files** to appropriate targets
3. **Build iOS target** first (simpler, no HealthKit)
4. **Run tests** with Cmd+U
5. **Build Watch target** and test on simulator/device
6. **Grant HealthKit** permissions on watch
7. **Create template** on iPhone/Mac
8. **Start workout** on watch
9. **Celebrate!** 🎉

## 📞 Support

- **Bug in code?** Check inline comments and tests
- **Setup issues?** See SETUP.md and ENTITLEMENTS_GUIDE.md
- **Architecture questions?** See ARCHITECTURE.md
- **Usage help?** See QUICK_REFERENCE.md
- **Original spec?** See interval-app-spec.md

---

**Total Project Size:**
- 11 source files (~1,245 lines)
- 7 documentation files (~2,000 lines)
- 1 specification file
- 100% Swift, 100% SwiftUI, 100% modern Apple frameworks
