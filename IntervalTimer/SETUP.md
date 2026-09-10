# IntervalTimer - Setup Instructions

## Project Configuration Checklist

Since I cannot directly modify your Xcode project file, please follow these steps to configure your project:

### 1. Create the Xcode Project

1. Open Xcode and create a new **App** project
2. Name it **IntervalTimer**
3. Choose **SwiftUI** for the interface
4. Enable **SwiftData** storage
5. Select **Multiplatform** (iOS, macOS) for the product

### 2. Add watchOS Target

1. File → New → Target
2. Choose **Watch App** 
3. Name it **IntervalTimer Watch App**
4. Ensure the bundle identifier follows the pattern:
   - iOS/Mac: `com.yourname.intervaltimer`
   - Watch: `com.yourname.intervaltimer.watchkitapp`

### 3. Configure Capabilities

#### For iOS/macOS target:
1. Select your main app target
2. Go to **Signing & Capabilities**
3. Click **+ Capability** and add:
   - **iCloud** → Enable CloudKit, check "Use default container"
   - **App Groups** → Add group: `group.com.yourname.intervaltimer`

#### For watchOS target:
1. Select the Watch App target
2. Add the same capabilities:
   - **iCloud** → Enable CloudKit, check "Use default container"
   - **HealthKit** (required for heart rate)
   - **App Groups** → Use the same group: `group.com.yourname.intervaltimer`
   - **Background Modes** → Enable "Workout Processing"

### 4. Add Privacy Descriptions

#### watchOS Info.plist
Add these privacy usage strings:

```xml
<key>NSHealthShareUsageDescription</key>
<string>IntervalTimer needs access to your heart rate and workout data to track your interval training sessions.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>IntervalTimer saves workout sessions to your Health app.</string>
```

### 5. Organize Files in Xcode

Create these groups and add the files I've created:

```
IntervalTimer/
├── IntervalTimerApp.swift
├── ContentView.swift
├── WorkoutPlayer.swift
├── Models/
│   ├── IntervalItem.swift
│   ├── IntervalBlock.swift
│   └── WorkoutTemplate.swift
└── Views/
    └── TemplateEditorView.swift

IntervalTimer Watch App/
├── IntervalTimerWatchApp.swift
├── WatchContentView.swift
├── WorkoutSessionView.swift
└── HealthKitManager.swift

Tests/
└── WorkoutPlayerTests.swift
```

### 6. Shared Code

Since both targets use the same SwiftData models and WorkoutPlayer:

**Option A (Simple):** Add the Models folder and WorkoutPlayer.swift to both targets
- Select each file → File Inspector → Target Membership → Check both iOS and watchOS

**Option B (Recommended):** Create a Swift Package for shared code
1. File → New → Package → Name it "IntervalTimerShared"
2. Move models and WorkoutPlayer to the package
3. Add package dependency to both targets

### 7. Deployment Targets

Set minimum deployment targets:
- iOS: 18.0
- macOS: 15.0  
- watchOS: 11.0

### 8. Build and Run

1. Build the iOS/Mac target first to verify SwiftData models work
2. Build the Watch target (you'll need a paired Apple Watch or simulator)
3. Run tests with Cmd+U

## CloudKit Setup

After first launch:
1. Sign in with your Apple ID in Xcode
2. The app will automatically create a CloudKit container
3. Templates created on any device will sync via iCloud

## Testing the Watch App

1. Open the Watch app on simulator or device
2. Grant HealthKit permissions when prompted
3. Select a template (sync from iOS first, or the sample data will appear)
4. The workout session will:
   - Track heart rate live
   - Show current/next intervals
   - Support swipe-to-pause gesture
   - Save to Health app when complete

## Known Limitations

- First launch requires HealthKit authorization on watchOS
- CloudKit sync requires being signed into iCloud
- Heart rate only updates during active workout sessions
- Background workout processing requires a real Apple Watch (not fully functional in simulator)

## Next Steps / Polish Items

The app now covers milestones 1-7 from your spec. For milestone 8-9, consider adding:

- **watchOS template editor** (create/edit templates directly on watch)
- **End session confirmation dialog** (long-press to confirm)
- **Empty state improvements** when no templates exist
- **Error handling UI** for CloudKit sync failures
- **Haptic feedback** when intervals change on watch
- **Workout summary screen** showing stats after completion
