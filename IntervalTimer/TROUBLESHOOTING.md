# Troubleshooting Guide

Common issues and solutions for IntervalTimer.

## 🔧 Build Issues

### "Cannot find 'IntervalItem' in scope"

**Cause:** Model files not added to correct target.

**Solution:**
1. Select `IntervalItem.swift` in Project Navigator
2. Open File Inspector (right panel)
3. Under "Target Membership", check:
   - ✅ IntervalTimer (iOS/Mac)
   - ✅ IntervalTimer Watch App
   - ✅ IntervalTimerTests (if applicable)
4. Repeat for `IntervalBlock.swift` and `WorkoutTemplate.swift`

### "No such module 'SwiftData'"

**Cause:** Deployment target too low.

**Solution:**
1. Select project in Navigator
2. Select each target
3. Set deployment target:
   - iOS: 18.0+
   - macOS: 15.0+
   - watchOS: 11.0+

### "'Observable' requires Swift 6.0 or later"

**Cause:** Xcode version too old.

**Solution:**
- Update to Xcode 15.3 or later
- Or replace `@Observable` with `ObservableObject` (requires code changes)

### "Undefined symbol: WorkoutPlayer"

**Cause:** WorkoutPlayer.swift not in watch target.

**Solution:**
1. Select `WorkoutPlayer.swift`
2. Check "IntervalTimer Watch App" in Target Membership
3. Clean build folder (Cmd+Shift+K)
4. Rebuild

## 🔄 CloudKit Sync Issues

### Templates not syncing between devices

**Symptoms:** Create template on iPhone, doesn't appear on Mac/Watch.

**Diagnostic Steps:**
1. Check iCloud sign-in:
   - Settings → [Your Name]
   - Ensure same Apple ID on all devices
2. Check iCloud Drive enabled:
   - Settings → [Your Name] → iCloud
   - Toggle "iCloud Drive" ON
3. Check network:
   - Ensure WiFi or cellular data active
   - Try airplane mode toggle
4. Check container configuration:
   - Xcode → Target → Signing & Capabilities
   - Verify "iCloud" capability enabled
   - Verify same container ID on all targets

**Solutions:**

**Option 1: Force sync**
1. Make edit to template on one device
2. Wait 30 seconds
3. Check other devices

**Option 2: Reset CloudKit**
1. Delete app from all devices
2. Wait 5 minutes
3. Reinstall on primary device
4. Create test template
5. Install on other devices

**Option 3: Check CloudKit Console**
1. Open CloudKit Dashboard (developer.apple.com)
2. Select your container
3. Check for schema/data
4. Verify no errors in logs

### "CloudKit not available" error

**Cause:** Not signed into iCloud.

**Solution:**
1. Settings → [Your Name]
2. Sign in with Apple ID
3. Enable iCloud Drive
4. Restart device
5. Relaunch app

### Sync very slow (minutes)

**Normal behavior:** CloudKit can take 5-30 seconds to sync initially.

**If slower:**
1. Check network speed
2. Check iCloud storage not full (Settings → iCloud → Storage)
3. Force quit app and reopen
4. Wait up to 5 minutes for background sync

## ❤️ HealthKit Issues

### Heart rate always shows 0

**Symptoms:** During workout, HR stays at 0 BPM.

**Diagnostic Steps:**
1. Check authorization:
   - iPhone: Settings → Privacy & Security → Health → IntervalTimer
   - Or delete app and reinstall to re-trigger prompt
2. Check watch fit:
   - Ensure snug on wrist
   - Move watch higher up arm
   - Clean sensors
3. Check HR in Apple Workout:
   - Start system Workout app
   - If HR works there, problem is with IntervalTimer
   - If HR also 0, it's a hardware/fit issue

**Solutions:**

**Fix 1: Re-authorize HealthKit**
1. Delete IntervalTimer from watch
2. Delete from iPhone too (removes all settings)
3. Reinstall on iPhone
4. Reinstall on watch
5. Start workout → Tap "Allow" when prompted
6. Select all data types

**Fix 2: Reset HealthKit permissions**
1. iPhone: Settings → Privacy → Health
2. Find IntervalTimer
3. Tap to open
4. Toggle all permissions OFF
5. Force quit app
6. Reopen app
7. Toggle permissions back ON
8. Restart watch

**Fix 3: Check watch placement**
- Tighten band one notch
- Move watch to other wrist
- Wait 1-2 minutes for sensor to stabilize

### "HealthKit authorization denied" alert

**Cause:** User tapped "Don't Allow" when prompted.

**Solution:**
1. Delete app from watch
2. Reinstall
3. Start workout
4. Tap "Allow" this time

**Or:**
1. Settings → Privacy → Health (on watch or iPhone)
2. Find IntervalTimer
3. Enable all permissions

### Workout not saved to Health app

**Symptoms:** Finish workout, nothing appears in Fitness/Health.

**Diagnostic Steps:**
1. Check if workout actually completed:
   - Did you tap "End Workout"?
   - Or did app crash?
2. Check Health app on iPhone:
   - Open Health app
   - Tap "Browse" → "Activity" → "Workouts"
   - Look for recent entries
3. Check authorization:
   - Settings → Privacy → Health → IntervalTimer
   - "Write Workouts" should be ON

**Solutions:**

**If ended properly:**
- Workout should be saved automatically
- Check Health app after 1-2 minutes
- Force quit Health app and reopen

**If app crashed:**
- Workout may not be saved
- HealthKit only saves on clean `session.end()`

**If permissions issue:**
- Re-authorize (see above)

## ⌚ watchOS Specific Issues

### App not installing on watch

**Symptoms:** App installs on iPhone but not Watch.

**Diagnostic Steps:**
1. Check watch pairing:
   - iPhone Watch app → "My Watch" tab
   - Should show watch name
2. Check watch free space:
   - Watch app → General → About → Available
   - Need ~50MB free
3. Check bundle IDs:
   - iOS: `com.yourname.intervaltimer`
   - Watch: `com.yourname.intervaltimer.watchkitapp`
   - Watch must have iOS bundle ID as prefix

**Solutions:**
1. Restart watch
2. Restart iPhone
3. Unpair and re-pair watch (last resort)

### Swipe gestures not working

**Symptoms:** Swipe right doesn't pause workout.

**Cause 1:** View in NavigationStack (conflicts with back gesture).

**Solution:**
- Verify `WorkoutSessionView` presented via `.fullScreenCover`
- NOT via `NavigationLink`

**Cause 2:** Gesture sensitivity too low.

**Solution:**
- Swipe more aggressively (faster)
- Swipe from center of screen (not edge)
- Check code: `minimumDistance: 30` in gesture

### Background stops during workout

**Symptoms:** Lower wrist, workout pauses or HR stops updating.

**Diagnostic Steps:**
1. Check Background Modes enabled:
   - Target → Signing & Capabilities
   - "Background Modes" → "Workout Processing"
2. Check battery:
   - Low Power Mode disables background
   - Check watch battery level
3. Check session state:
   - `HKWorkoutSession` must be `.running`
   - Pausing session stops background

**Solutions:**
1. Enable Workout Processing background mode
2. Disable Low Power Mode
3. Don't manually pause before lowering wrist
4. Test on real device (simulator limited)

### Pause overlay doesn't dismiss

**Symptoms:** Tap Resume, overlay stays visible.

**Diagnostic Steps:**
1. Check state binding: `showingPauseOverlay` should update
2. Check player state: Should be `.running` after resume
3. Check animation: `withAnimation` block present?

**Solution:**
```swift
Button(action: {
    player.resume()
    healthKit.resumeWorkout()
    withAnimation {  // ← Make sure this is here
        showingPauseOverlay = false
    }
}) {
    Label("Resume", systemImage: "play.fill")
}
```

## 📱 iOS/Mac Issues

### Template editor not updating

**Symptoms:** Change interval duration, doesn't save.

**Cause:** SwiftData context not detecting change.

**Solution:**
1. Check `@Bindable var template: WorkoutTemplate`
2. Ensure using `$template.name` for bindings
3. Call `template.updatedAt = Date()` after changes
4. Verify `.modelContext` environment available

### Can't reorder intervals

**Symptoms:** Drag handles don't appear or dragging doesn't work.

**Solution:**
1. Tap "Edit" button (iOS) or EditButton in toolbar
2. Check `.onMove(perform:)` modifier present
3. Verify items in `ForEach` have stable `.id`

### Duplicate creates identical UUID

**Cause:** Forgot to generate new UUID in `duplicate()`.

**Solution:**
```swift
func duplicate() -> IntervalItem {
    IntervalItem(
        id: UUID(),  // ← New UUID, not self.id
        name: name,
        duration: duration,
        sortOrder: sortOrder
    )
}
```

### App crashes on launch

**Symptoms:** App opens then immediately crashes.

**Diagnostic Steps:**
1. Check crash log in Xcode
2. Look for SwiftData errors
3. Check model initialization

**Common causes:**
1. **Missing required properties:**
   - All model properties must have default values
   - Or initialize in `init()`

2. **Invalid model container:**
   ```swift
   // Wrong:
   .modelContainer(for: WorkoutTemplate.self)
   
   // Right:
   .modelContainer(
       for: [WorkoutTemplate.self, IntervalBlock.self, IntervalItem.self],
       configuration: ModelConfiguration(cloudKitDatabase: .automatic)
   )
   ```

3. **CloudKit not configured:**
   - Check Signing & Capabilities → iCloud enabled

## 🧪 Testing Issues

### Tests fail: "Could not cast value of type 'X' to 'Y'"

**Cause:** Models not in test target.

**Solution:**
1. Select model files
2. Check "IntervalTimerTests" in Target Membership
3. Clean build folder
4. Run tests again

### Tests pass but warning: "Published property..."

**Cause:** Using `@Observable` but test sees `@Published`.

**Solution:** Update to latest Xcode (15.3+) with Swift Testing support.

### Tests take very long to run

**Cause:** Creating real SwiftData container in tests.

**Solution:** Use in-memory store for tests:
```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(
    for: WorkoutTemplate.self,
    configurations: config
)
```

## 🔍 Debugging Tips

### Enable verbose logging

Add to `WorkoutPlayer.swift`:
```swift
private func updateElapsedTime() {
    // ... existing code ...
    
    #if DEBUG
    print("Elapsed: \(elapsedTotal), Step: \(currentStepName)")
    #endif
}
```

### Check SwiftData persistence

```swift
// In ContentView.swift
.onAppear {
    print("Template count: \(templates.count)")
    for template in templates {
        print("- \(template.name): \(template.blocks.count) blocks")
    }
}
```

### Monitor HealthKit authorization

```swift
// In HealthKitManager.swift
func requestAuthorization() async throws {
    print("Requesting HealthKit authorization...")
    // ... existing code ...
    print("Authorization granted: \(isAuthorized)")
}
```

### Track CloudKit sync

```swift
// Listen to SwiftData notifications
NotificationCenter.default.addObserver(
    forName: ModelContext.didSave,
    object: nil,
    queue: .main
) { notification in
    print("SwiftData saved, should sync to CloudKit")
}
```

## 📊 Performance Issues

### App feels laggy

**Possible causes:**
1. Too many templates in list
2. Timer update too frequent
3. UI rebuilding unnecessarily

**Solutions:**
1. Paginate template list if >100 items
2. Lower timer frequency (change 0.1 to 0.5)
3. Use `@State private` for local UI state
4. Profile with Instruments (Time Profiler)

### Watch battery drains fast

**Expected:** Background workout processing uses power.

**If excessive:**
1. Check timer interval (10 Hz = 0.1s is reasonable)
2. Don't use `.animation()` on every update
3. Limit HealthKit queries
4. Test workout duration (shorter = less drain)

### Slow sync (>1 minute)

**Check:**
1. Network speed
2. Template size (how many blocks/intervals?)
3. iCloud storage quota
4. Number of devices syncing

**Optimize:**
- Reduce number of intervals if hundreds
- Archive old templates instead of keeping all active

## 🆘 Last Resorts

### Nuclear option: Clean slate

1. **Delete app from all devices**
2. **Clean Xcode:** Cmd+Shift+K
3. **Delete derived data:**
   - Xcode → Settings → Locations
   - Click arrow next to Derived Data path
   - Delete `IntervalTimer-*` folder
4. **Sign out of iCloud** (on one test device)
5. **Sign back in**
6. **Rebuild from scratch**
7. **Install on primary device first**
8. **Wait 5 minutes for CloudKit to settle**
9. **Install on other devices**

### Still broken?

1. Check Xcode version (15.3+)
2. Check OS versions (iOS 18, macOS 15, watchOS 11)
3. Create new blank project with just models, verify SwiftData works
4. Compare code with this repo
5. File a bug with Apple (if framework issue)

## 📝 Reporting Issues

When asking for help, include:

1. **Environment:**
   - Xcode version
   - OS versions (iOS/macOS/watchOS)
   - Device models

2. **Steps to reproduce:**
   - What you did
   - What you expected
   - What actually happened

3. **Relevant code:**
   - Which file
   - Which function
   - Any modifications from original

4. **Logs:**
   - Console output
   - Crash logs
   - Error messages

5. **Screenshots/video:**
   - Show the issue visually

## ✅ Verification Checklist

After setup, verify each feature works:

- [ ] Create template on iPhone
- [ ] Edit template on Mac
- [ ] See template on Watch (synced from iPhone)
- [ ] Start workout on Watch
- [ ] See heart rate updating
- [ ] Swipe right to pause
- [ ] Tap Resume
- [ ] Skip to next interval
- [ ] End workout
- [ ] Check Health app for saved workout
- [ ] Check Fitness app for workout summary

All working? You're good! 🎉

## 🔗 Additional Resources

- **SETUP.md** - Initial configuration
- **ENTITLEMENTS_GUIDE.md** - Capabilities setup
- **ARCHITECTURE.md** - How it works
- **Apple Docs:**
  - SwiftData: developer.apple.com/documentation/swiftdata
  - CloudKit: developer.apple.com/documentation/cloudkit
  - HealthKit: developer.apple.com/documentation/healthkit
