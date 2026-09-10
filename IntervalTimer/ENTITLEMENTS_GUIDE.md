# Entitlements Configuration Guide

## iOS/macOS Entitlements

Your `IntervalTimer.entitlements` file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- CloudKit -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.$(CFBundleIdentifier)</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    
    <!-- App Groups (optional, for future features) -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourname.intervaltimer</string>
    </array>
</dict>
</plist>
```

## watchOS Entitlements

Your `IntervalTimer Watch App.entitlements` file should contain:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- CloudKit -->
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.yourname.intervaltimer</string>
    </array>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    
    <!-- HealthKit -->
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.background-delivery</key>
    <true/>
    
    <!-- App Groups -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.yourname.intervaltimer</string>
    </array>
</dict>
</plist>
```

## watchOS Info.plist

Add these keys to your watchOS target's `Info.plist`:

```xml
<!-- HealthKit Privacy Descriptions -->
<key>NSHealthShareUsageDescription</key>
<string>IntervalTimer needs access to your heart rate and workout data to track your interval training sessions.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>IntervalTimer saves workout sessions to your Health app so you can review your training history.</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>workout-processing</string>
</array>

<!-- Required for watchOS apps -->
<key>WKApplication</key>
<true/>
<key>WKWatchOnly</key>
<true/>
```

## Setting Up in Xcode (Automatic Method)

Instead of manually editing XML files, use Xcode's UI:

### For iOS/Mac Target:

1. Select your app target
2. **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **iCloud**
   - Check "CloudKit"
   - Use default container
5. Add **App Groups**
   - Click + and enter: `group.com.yourname.intervaltimer`

### For watchOS Target:

1. Select Watch App target
2. **Signing & Capabilities** tab
3. Add **iCloud** (same as above)
4. Add **HealthKit**
   - Check both "HealthKit" and "Background Delivery"
5. Add **Background Modes**
   - Check "Workout Processing"
6. Add **App Groups** (same group ID as iOS)

### Privacy Strings (Info tab):

1. Select Watch App target
2. **Info** tab
3. Click + under "Custom iOS Target Properties"
4. Add:
   - Key: `Privacy - Health Share Usage Description`
   - Value: `IntervalTimer needs access to your heart rate and workout data to track your interval training sessions.`
5. Add:
   - Key: `Privacy - Health Update Usage Description`
   - Value: `IntervalTimer saves workout sessions to your Health app so you can review your training history.`

## CloudKit Container

The default container ID will be:
- `iCloud.com.yourname.intervaltimer`

Make sure your bundle identifiers match:
- iOS/Mac: `com.yourname.intervaltimer`
- watchOS: `com.yourname.intervaltimer.watchkitapp`

**Important:** All targets must use the **same** CloudKit container to share data.

## App Groups

The App Group is optional for v1.0 but recommended for future features like:
- Sharing workout state between phone and watch
- Complications data
- Widget support

Use the same group ID across all targets:
- `group.com.yourname.intervaltimer`

## Testing Entitlements

After setup, verify:

1. **CloudKit**: Create a template on iPhone, check if it syncs to Mac/Watch
2. **HealthKit**: Start a workout on Watch, check if HR appears
3. **Background**: Lock watch during workout, check if it continues
4. **Saving**: Complete a workout, check Health app for new entry

## Troubleshooting

### CloudKit not syncing:
- Ensure signed into iCloud on all devices
- Check container ID matches bundle ID
- Try signing out/in to iCloud

### HealthKit not authorized:
- Check privacy strings are in Info.plist
- Delete app and reinstall to re-trigger permission prompt
- Check Settings → Privacy → Health on watch

### Background not working:
- Must enable "Workout Processing" in Background Modes
- Test on real device (simulator has limitations)
- Check battery settings allow background activity

## Production Notes

Before App Store submission:
- [ ] Update bundle identifiers with your actual domain
- [ ] Review and customize privacy descriptions
- [ ] Test CloudKit sync with multiple accounts
- [ ] Verify HealthKit authorization flow
- [ ] Test background workout on physical device
- [ ] Add App Privacy details in App Store Connect
