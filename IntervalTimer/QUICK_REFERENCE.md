# IntervalTimer - Quick Reference

## 📱 iOS / Mac

### Creating Your First Template

1. **Launch app** → Tap **+** button
2. **Name template** → "My Workout"
3. **Tap template** → Opens editor
4. **Add Block** → Names the set (e.g., "Warmup")
5. **Add Interval** → Set name and duration
6. **Add more intervals** as needed
7. **Set repeat count** on block (e.g., "5x")
8. **Add another block** for different phase

### Editing Templates

- **Rename template**: Tap "Edit" next to name
- **Rename interval**: Tap on the interval name
- **Change duration**: Use stepper (increments of 5 seconds)
- **Duplicate interval**: Tap copy icon on interval
- **Duplicate block**: Tap copy icon on block header
- **Reorder**: Tap "Edit" → Drag handles to reorder
- **Delete**: Swipe left (iOS) or Edit → Delete

### Understanding Blocks

A **block** is a group of intervals that can repeat:

```
Block: "Sprint Set" (Repeat: 5x)
  ├─ Sprint: 60s
  └─ Rest: 90s

Result: Sprint → Rest → Sprint → Rest → ... (5 times)
```

Multiple blocks run in sequence:

```
1. Warmup Block (1x)
   └─ Jog: 5min

2. Main Block (8x)
   ├─ Work: 20s
   └─ Rest: 10s

3. Cooldown Block (1x)
   └─ Walk: 5min
```

## ⌚ Apple Watch

### Starting a Workout

1. **Open IntervalTimer** on watch
2. **Select template** from list
3. **Grant HealthKit permission** (first time only)
4. **Workout starts automatically**

### During Workout

**Main Screen Shows:**
- ⏱️ Total elapsed time
- 🏃 Current interval name
- ⏭️ Next interval name
- ❤️ Heart rate (BPM)
- Time remaining in current step

**Swipe between pages:**
- Page 1: Main metrics
- Page 2: Calories & progress (X/Y)

### Pause Controls

**Swipe RIGHT** → Pause workout

**Pause Menu:**
- ⏮️ **Previous** - Go back one interval
- ⏭️ **Next** - Skip to next interval
- ▶️ **Resume** - Continue workout
- ⏹️ **End Workout** - Finish session

**Swipe LEFT** (while paused) → Quick resume

### Navigation Tips

- **Skip ahead**: Pause → Next
- **Restart interval**: Pause → Previous (within 3 sec)
- **Go back**: Pause → Previous (after 3 sec)
- **End early**: Pause → End Workout

### After Workout

- Workout **automatically saved** to Health app
- View in **Fitness** or **Health** app
- Includes:
  - Duration
  - Heart rate data
  - Calories burned
  - Workout type (Running)

## 🔄 Syncing

### Automatic iCloud Sync

Templates sync automatically between:
- ✅ iPhone
- ✅ Mac
- ✅ Apple Watch

**No action required** - just ensure:
- Same Apple ID on all devices
- iCloud enabled
- Internet connection available

### Sync Timing

- **Create/edit**: Syncs within seconds
- **Offline edits**: Sync when back online
- **Conflicts**: Latest update wins

## 🎯 Sample Workflows

### Tabata (4 minutes)

```
Template: "Tabata"
  └─ Block (8x)
      ├─ Work: 20s
      └─ Rest: 10s
```

### 5K Training

```
Template: "5K Intervals"
  ├─ Warmup Block (1x)
  │   └─ Easy Jog: 10min
  ├─ Intervals Block (5x)
  │   ├─ Fast: 3min
  │   └─ Recovery: 2min
  └─ Cooldown Block (1x)
      └─ Walk: 5min
```

### HIIT Pyramid

```
Template: "Pyramid HIIT"
  ├─ Build Up (1x)
  │   ├─ Work: 20s → Rest: 10s
  │   ├─ Work: 30s → Rest: 15s
  │   └─ Work: 40s → Rest: 20s
  └─ Build Down (1x)
      ├─ Work: 30s → Rest: 15s
      └─ Work: 20s → Rest: 10s
```

## ⚙️ Settings & Permissions

### HealthKit (Watch Only)

**Required for:**
- Heart rate monitoring
- Workout tracking
- Saving to Health app

**To authorize:**
1. Start a workout
2. Tap "Allow" when prompted
3. Select data types to share

**To change later:**
- Watch: Settings → Privacy → Health
- iPhone: Settings → Health → Data Access & Devices

### iCloud

**Required for:**
- Syncing templates across devices

**To enable:**
- Settings → [Your Name] → iCloud
- Enable "iCloud Drive"

## 📊 Metrics Explained

### Heart Rate (BPM)
- Real-time from Apple Watch sensor
- Updates continuously during workout
- Saved to Health app

### Elapsed Time
- Total time since workout started
- Pauses are **not** counted
- Accurate to the second

### Time Remaining
- Countdown for current interval
- Auto-advances at 0:00
- Shown in orange on watch

### Calories
- Active energy burned
- Calculated by HealthKit
- Based on HR and movement

### Progress (X/Y)
- Current step / Total steps
- Each interval = 1 step
- Repeats are flattened (5x means 5 steps)

## 🐛 Troubleshooting

### Templates not syncing
- Check iCloud sign-in
- Verify internet connection
- Wait 30 seconds for sync
- Force quit and reopen app

### Heart rate showing 0
- Grant HealthKit permission
- Ensure watch is snug on wrist
- Check HR in Apple Workout app
- Restart watch if needed

### Workout won't start
- Check HealthKit authorization
- Update watchOS to latest
- Restart watch app
- Delete and reinstall app

### Background stops working
- Enable Workout Processing in settings
- Don't force quit app during workout
- Check battery isn't in Low Power mode
- Use real device (simulator limited)

## 💡 Pro Tips

1. **Test on phone first**: Create templates on iPhone (easier than watch)
2. **Use descriptive names**: "Hill Sprint" vs "Interval 1"
3. **Round durations**: 30s/60s easier to track than 27s/54s
4. **Start simple**: Single block, add complexity later
5. **Duplicate smartly**: Create one interval, duplicate, edit duration
6. **Preview on watch**: Check template before starting workout
7. **Pause liberally**: Use pause to drink water, tie shoes, etc.
8. **Skip if needed**: Don't feel bad skipping an interval
9. **End if exhausted**: Listen to your body
10. **Check Health app**: Review HR zones post-workout

## 🏃 Workout Etiquette

- **Pause for safety**: Traffic, obstacles, etc.
- **Skip if needed**: Better than injury
- **End early if sick**: Don't push through illness
- **HR zones**: Keep eye on max heart rate
- **Hydration**: Pause to drink as needed

## 📱 Supported Platforms

- ✅ iPhone (iOS 18+)
- ✅ Mac (macOS 15+)
- ✅ Apple Watch (watchOS 11+)
- ❌ iPad (not optimized, but works)
- ❌ Apple TV (not supported)
- ❌ Vision Pro (not supported)

## 🔐 Privacy

### Data Storage
- Templates: iCloud (encrypted)
- Workouts: Health app (local + iCloud)
- No third-party servers
- No analytics or tracking

### Sharing
- Templates: Not shareable (yet)
- Workouts: Via Health app sharing only
- No social features
- No public leaderboards

---

**Need more help?** Check README.md for detailed documentation.
