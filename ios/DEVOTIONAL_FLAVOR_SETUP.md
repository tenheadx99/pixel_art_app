# iOS setup for the "Divine Pixels" devotional flavor

The Android flavor is fully wired in `android/app/build.gradle.kts`. iOS flavors
require Xcode-side build configurations + a matching scheme, which must be done
in Xcode (these live in `Runner.xcodeproj/project.pbxproj`). Follow the steps
below once on a Mac. Estimated time: ~15 minutes.

The Flutter `--flavor <name>` flag maps to an Xcode **scheme** of the same name,
whose build configurations set the flavor's bundle id. We provide
[`Flutter/Devotional.xcconfig`](Flutter/Devotional.xcconfig) to hold the values.

## 1. Make the display name configurable
In `Runner/Info.plist`, change `CFBundleDisplayName` from the hardcoded
`Pixel Art App` to a variable:

```xml
<key>CFBundleDisplayName</key>
<string>$(APP_DISPLAY_NAME)</string>
```

Then add `APP_DISPLAY_NAME = Pixel Art App` to **both** `Flutter/Debug.xcconfig`
and `Flutter/Release.xcconfig` so the original app keeps its name.
(`Flutter/Devotional.xcconfig` already sets it to `Divine Pixels`.)

## 2. Create flavor build configurations (Xcode → Project → Info → Configurations)
Duplicate each existing configuration for the new flavor:
- `Debug`   → `Debug-devotional`
- `Release` → `Release-devotional`
- `Profile` → `Profile-devotional`

For each `*-devotional` configuration, set the Runner target's
**Based on Configuration File** to `Flutter/Devotional.xcconfig`. The original
configurations keep pointing at `Debug.xcconfig` / `Release.xcconfig`.

## 3. Set the bundle id per configuration
In the Runner target → Build Settings → **Product Bundle Identifier**, set the
three `*-devotional` configurations to `com.tenhead.divinepixels` (the original
configurations stay `com.europosit.pixelArtApp`, or align them to
`com.tenhead.pixelyart` for consistency with Android).

## 4. Create the scheme
Xcode → Product → Scheme → Manage Schemes → `+`:
- Name the scheme **`devotional`** (must match `--flavor devotional`).
- Set Run / Profile / Archive / Analyze to use the matching `*-devotional`
  build configurations.
- Mark it **Shared** so it lands in `xcshareddata/xcschemes/`.

## 5. App icon + Firebase
- Add a devotional app icon asset set (or a second `Assets.xcassets` icon) and
  point the `*-devotional` configs' `ASSETCATALOG_COMPILER_APPICON_NAME` at it.
- If using Firebase on iOS, add a `GoogleService-Info.plist` for the new bundle
  id (register `com.tenhead.divinepixels` in the Firebase console) and load the
  right plist per flavor in a Run Script build phase, or via flavor folders.

## 6. Build / run
```bash
flutter run        --flavor devotional -t lib/main_devotional.dart --dart-define=FLAVOR=devotional
flutter build ios  --flavor devotional -t lib/main_devotional.dart --dart-define=FLAVOR=devotional
```

The `--dart-define=FLAVOR=devotional` is what selects the saffron theme and the
deity catalog at runtime (see `lib/config/flavor.dart`); the `--flavor` flag +
scheme selects the iOS bundle id / icon / name.
