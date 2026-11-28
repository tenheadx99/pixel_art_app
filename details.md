# Pixel Art Suite — Complete Mac Migration & Technical Architecture Guide

This document provides a comprehensive reference for setting up both **`pixel_art_app`** (the client mobile app) and **`pixel_art_admin`** (the web/desktop admin panel) on a new **MacBook Air (Apple Silicon M-series)**.

---

## 1. System Overview & Architecture

The system consists of two interconnected Flutter projects sharing a central Firebase backend:

```
                      ┌──────────────────────────────────────┐
                      │    Firebase Project (om108-5c015)    │
                      │  - Firestore (Catalog & Config)      │
                      │  - Firebase Auth (Admin Allowlist)   │
                      │  - Remote Config (App Flags)         │
                      │  - Firebase Hosting (Web Admin/Ads)  │
                      └──────────────────┬───────────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
┌─────────────────────────────────┐             ┌─────────────────────────────────┐
│         pixel_art_app           │             │        pixel_art_admin          │
│   (Mobile Client App)           │             │     (Admin Control Panel)       │
│                                 │             │                                 │
│ • Platforms: Android, iOS       │             │ • Platforms: Web, macOS/Linux   │
│ • 15+ Flavors (Anime, Diamond,  │             │ • Controls Ads, Economy,        │
│   Devotional, Bead, Quilt, etc.)│             │   App Updates, Remote Artworks  │
│ • Custom Fragment Shaders       │             │ • Converts PNG/JPG to Pixel Art │
│ • Local SQLite + Remote Cache   │             │ • Syncs with Firestore Catalog  │
│ • AdMob + In-App Purchases      │             │                                 │
└─────────────────────────────────┘             └─────────────────────────────────┘
```

---

## 2. Essential Pre-Migration Checklist (DO NOT SKIP)

### ⚠️ Files That MUST Be Copied Manually from Your Linux Machine
Because these files are git-ignored, they will **not** be present after cloning your Git repository:

| File Path in Repo | Purpose | Critical Risk if Missing |
|-------------------|---------|--------------------------|
| `pixel_art_app/universal_signing_key.jks` | Google Play production keystore | **CRITICAL:** Without this, you cannot release app updates on Google Play! |
| `pixel_art_app/play-store-key.json` | Google Play Console Service Account API key | Fastlane and automated store uploads will fail. |
| `pixel_art_app/android/key.properties` | Passwords & alias for release signing | Keystore authentication will fail during release builds. |
| Any Firebase service account JSONs | Admin backend access for python tools | Firestore catalog seed scripts will fail without credentials. |

> [!IMPORTANT]
> **Check uncommitted git changes on your Linux machine before migrating!**
> Run `git status` in both `pixel_art_app` and `pixel_art_admin`. Commit and push all branches (e.g. `dev_v103_prod`), or create a backup archive of untracked files.

---

## 3. MacBook Air (Apple Silicon) Setup Guide

### Step 3.1: Install Command Line Tools & Rosetta 2
Open Terminal on your Mac:
```bash
# 1. Install Xcode Command Line Developer Tools
xcode-select --install

# 2. Install Rosetta 2 (required for older x86 CocoaPods and build binaries)
softwareupdate --install-rosetta --agree-to-license
```

### Step 3.2: Install Homebrew
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Follow the post-install instructions to add Homebrew to your PATH:
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Step 3.3: Install Flutter SDK & CocoaPods
```bash
# 1. Create development directory
mkdir -p ~/development && cd ~/development

# 2. Download and extract Flutter for Apple Silicon (ARM64)
# (Target: Flutter 3.50.x / Dart 3.14.x or latest stable)
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_3.50.0-stable.zip
unzip flutter_macos_arm64_3.50.0-stable.zip
rm flutter_macos_arm64_3.50.0-stable.zip

# 3. Add Flutter to PATH
echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> ~/.zshrc

# 4. Install CocoaPods (essential for iOS native plugins)
brew install cocoapods
```

### Step 3.4: Install Xcode & iOS Simulators
1. Open the **Mac App Store**, search for **Xcode**, and install it.
2. Accept the license and install additional components:
   ```bash
   sudo xcodebuild -license accept
   sudo xcodebuild -runFirstLaunch
   ```
3. Open **Xcode -> Settings -> Platforms** and install the latest **iOS Simulator runtime**.

### Step 3.5: Install Android Studio & Java JDK
1. Download and install **Android Studio** (Apple Silicon `.dmg`) from [developer.android.com](https://developer.android.com/studio).
2. Install **OpenJDK 17**:
   ```bash
   brew install openjdk@17
   ```
3. Open Android Studio -> **Settings -> Languages & Frameworks -> Android SDK**:
   - **SDK Platforms**: Install Android 14, 15, and 16 (API 34, 35, 36).
   - **SDK Tools**: Check **Android SDK Command-line Tools (latest)**, **Android SDK Build-Tools**, and **Android SDK Platform-Tools**.
4. Configure shell environment variables:
   ```bash
   cat << 'EOF' >> ~/.zshrc
   export JAVA_HOME=$(/usr/libexec/java_home -v 17)
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$PATH:$ANDROID_HOME/emulator
   export PATH=$PATH:$ANDROID_HOME/platform-tools
   export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
   EOF
   source ~/.zshrc
   ```
5. Accept Android licenses:
   ```bash
   flutter doctor --android-licenses
   ```

### Step 3.6: Install Fastlane, Python Tools, & Firebase CLI
```bash
# 1. Install Fastlane
brew install fastlane

# 2. Install Python 3 and script libraries
brew install python
pip3 install Pillow firebase-admin requests

# 3. Install Firebase CLI & Google Chrome
brew install --cask google-chrome
brew install firebase-cli
firebase login
```

### Step 3.7: Verify Environment
```bash
flutter doctor -v
```
All categories (Flutter, Android toolchain, Xcode, Chrome, CocoaPods) should show green checkmarks.

---

## 4. Project 1: `pixel_art_app` Details

### 4.1 Purpose
The consumer-facing Flutter application featuring color-by-number artwork, custom GPU fragment shaders, haptic feedback, audio playback, sound generation, multiple app flavors, offline SQLite persistence, AdMob monetization, and In-App Purchases.

### 4.2 Flavor Architecture
The app supports 15+ flavors configured via entry points and Gradle/Xcode schemes:
- `main.dart` (Original / Pixely)
- `main_devotional.dart` (Divine Pixels)
- `main_anime.dart` (Anime Pixels)
- `main_diamond.dart` (Gem Art)
- `main_pixelcalm.dart` (PixelCalm)
- `main_bible.dart` (Bible Pixels)
- `main_cross_stitch.dart` (Cross Stitch)
- `main_bead.dart`, `main_brick.dart`, `main_knit.dart`, `main_mosaic.dart`
- `main_glow.dart`, `main_sticker.dart`, `main_quilt.dart`, `main_voxel.dart`

### 4.3 Full Dependency Matrix

| Category | Package Name | Version | Functionality |
|----------|--------------|---------|---------------|
| **Core & Architecture** | `flutter` | SDK | Framework core |
| | `provider` | `^6.0.5` | State management (Catalog, Game state, Palette) |
| | `shared_preferences` | `^2.2.0` | Local key-value storage (Settings, unlocked flags) |
| | `uuid` | `^4.1.0` | Unique session & artwork ID generation |
| | `collection` | `^1.18.0` | High-performance collection helpers |
| | `http` | `^1.6.0` | Network requests & remote asset downloads |
| **Graphics & Shaders** | `image` | `^4.0.17` | Image decoding, quantization & color palette extraction |
| | Custom Shaders | Asset `.frag` | Hardware-accelerated grid rendering (see Shaders list) |
| **Local Storage** | `sqflite` | `^2.3.0` | SQLite database for user coloring progress & strokes |
| | `path_provider` | `^2.1.1` | Access to filesystem directories (Documents, Cache) |
| | `path` | `^1.8.3` | Filesystem path utilities |
| **Firebase Suite** | `firebase_core` | `^2.27.0` | Firebase SDK initialization |
| | `firebase_analytics` | `^10.8.0` | User engagement & event telemetry |
| | `cloud_firestore` | `^4.17.0` | Cloud database for dynamic artwork sync |
| | `firebase_remote_config` | `^4.3.8` | Feature flags, ad pacing, and remote parameters |
| | `firebase_crashlytics` | `^3.5.7` | Real-time crash reporting |
| | `firebase_auth` | `^4.16.0` | User authentication & guest-to-account migration |
| | `firebase_messaging` | `^14.7.10` | Push notifications & daily art reminders |
| **Monetization & Store** | `google_mobile_ads` | `^9.2.0` | Banner, Interstitial, & Rewarded video ads |
| | `in_app_purchase` | `^3.3.1` | In-App Purchases for Subscriptions & Diamond currency |
| | `in_app_purchase_android` | `^0.5.0` | Android Google Play Billing implementation |
| | `in_app_review` | `^2.0.9` | In-app store rating dialogue |
| | `in_app_update` | `^4.2.3` | Android in-app flexible/immediate app updates |
| **Audio & Device** | `audioplayers` | `^6.7.1` | Sound effects for pixel coloring and completed art |
| | `vibration` | `^3.2.0` | Tactile haptic feedback on pixel tap |
| | `flutter_local_notifications` | `^22.0.1` | Scheduled local daily reminders |
| | `timezone` / `flutter_timezone` | `^0.11.0` / `^4.1.1` | Device timezone detection for daily notifications |
| | `package_info_plus` | `^9.0.1` | App version and build number detection |
| | `share_plus` | `^7.1.0` | Native sharing of completed artwork images |
| | `url_launcher` | `^6.2.0` | External URL opening (Privacy policy, support) |
| | `image_picker` | `^1.0.4` | Selecting user photos to convert to pixel art |
| | `app_links` | `^7.0.0` | Deep link handling |
| **Localization & UI** | `flutter_localizations` | SDK | Multi-language support |
| | `intl` | `^0.20.2` | Date/currency formatting and translations |
| | `cupertino_icons` | `^1.0.8` | iOS style icons |
| **Dev & Build Tools** | `flutter_test` | SDK | Unit and widget tests |
| | `flutter_lints` | `^6.0.0` | Linting rules for Dart |
| | `flutter_launcher_icons` | `^0.13.1` | Multi-flavor app icon generation |

### 4.4 Shaders
Hardware fragment shaders compiled into the app for GPU rendering effects:
- `shaders/gem_grid.frag`
- `shaders/cross_stitch_grid.frag`
- `shaders/flat_grid.frag`
- `shaders/voxel_grid.frag`
- `shaders/brick_grid.frag`
- `shaders/bead_grid.frag`
- `shaders/glow_grid.frag`
- `shaders/mosaic_grid.frag`
- `shaders/sticker_grid.frag`
- `shaders/quilt_grid.frag`
- `shaders/knit_grid.frag`

### 4.5 Configuration Fix Required on Mac
In `android/key.properties`, replace the old Linux path:
```properties
# Change this:
# storeFile=/home/rameshx99/ramesh/pixel_art_app/universal_signing_key.jks

# To a relative path:
storeFile=../../universal_signing_key.jks
storePassword=tenhead
keyAlias=tenhead
keyPassword=tenhead
```

### 4.6 Mac Build & Run Commands
```bash
cd pixel_art_app

# Fetch dependencies
flutter pub get

# Setup iOS Pods
cd ios && pod install && cd ..

# Run Android on connected device or emulator (e.g. Diamond flavor)
flutter run --flavor diamond -t lib/main_diamond.dart --dart-define=FLAVOR=diamond

# Run iOS Simulator
open -a Simulator
flutter run -d ios -t lib/main.dart

# Build Android Release AppBundle (AAB)
flutter build appbundle --release --flavor diamond -t lib/main_diamond.dart --dart-define=FLAVOR=diamond

# Build iOS Release Archive
flutter build ipa --flavor devotional -t lib/main_devotional.dart --dart-define=FLAVOR=devotional
```

---

## 5. Project 2: `pixel_art_admin` Details

### 5.1 Purpose
A standalone Flutter **Web & Desktop** admin dashboard. It does **not** alter the client app code; instead, it writes directly to Firestore in project `om108-5c015` to manage live configurations:
- **Ads Configuration**: Toggle ads, change AdMob Unit IDs, adjust impression cooldowns.
- **Economy Control**: Reward milestones, diamond shop pricing, XP curves.
- **Force Update**: Set minimum app versions and store update URLs.
- **Artwork Catalog Management**: Show/hide categories, toggle premium tags, delete or upload remote artwork.
- **Pixel Art Creator**: Web-based converter turning JPG/PNG into quantized pixel art grids matching the client's rendering algorithm.

### 5.2 Full Dependency Matrix

| Category | Package Name | Version | Functionality |
|----------|--------------|---------|---------------|
| **Core** | `flutter` | SDK | Flutter Web framework |
| | `provider` | `^6.1.5+1` | UI state and flavor switching management |
| | `shared_preferences` | `^2.5.5` | Admin session and cache settings |
| | `collection` | `^1.19.1` | Collection utilities |
| | `cupertino_icons` | `^1.0.8` | Cupertino icon fonts |
| **Firebase & Auth** | `firebase_core` | `^4.11.0` | Firebase Web initialization |
| | `firebase_auth` | `^6.5.4` | Admin authentication (Email/Password allowlisted UID) |
| | `cloud_firestore` | `^6.6.0` | Live Firestore CRUD operations on app configs & catalog |
| **Image & Files** | `image` | `^4.9.1` | In-browser image processing, color reduction & quantization |
| | `file_picker` | `^11.0.2` | Selecting local artwork files from desktop / browser |
| **API & Cloud** | `http` | `^1.6.0` | HTTP client for remote asset validation |
| | `googleapis_auth` | `^2.3.4` | Google APIs OAuth authentication for backend administration |
| **Dev Tools** | `flutter_test` | SDK | Automated unit & widget tests |
| | `flutter_lints` | `^6.0.0` | Dart analysis rules |
| | `plugin_platform_interface` | `^2.1.8` | Cross-platform plugin interfaces |

### 5.3 How to Run `pixel_art_admin` on macOS

#### Option A: Run in Chrome (Standard / Fastest)
```bash
cd pixel_art_admin
flutter pub get
flutter run -d chrome
```

#### Option B: Run as Local Web Service
```bash
cd pixel_art_admin
flutter build web --release

# Serve locally
python3 -m http.server 58432 --directory build/web --bind 127.0.0.1
# Open http://localhost:58432 in Chrome
```

#### Option C: Native macOS Desktop App (Optional)
If you prefer a native macOS desktop window:
```bash
cd pixel_art_admin
flutter create --platforms=macos .
flutter run -d macos
```

### 5.4 Backend Seeding & Admin Tools (`tool/`)
To seed the Firestore catalog from bundled artworks on your Mac:
```bash
cd pixel_art_admin

# Requires service account or application-default login:
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account.json"
python3 tool/seed_firestore.py --app-repo ../pixel_art_app
```

---

## 6. Fastlane & Automated Deployment Reference

Both projects share automation tools located in `pixel_art_app/fastlane` and `pixel_art_app/tool`:

- **Fastlane lanes** (`fastlane/Fastfile`):
  - `build_all`: Builds release bundles for all flavors.
  - `upload_all_metadata`: Pushes localized metadata, titles, and release notes to Google Play.
- **Python Automation**:
  - `tool/build_and_upload_all_flavors.py`
  - `tool/upload_all_flavor_metadata.py`
  - `tool/generate_flavor_store_metadata.py`

Ensure you copy `play-store-key.json` to `pixel_art_app/` so Fastlane can authenticate with Google Play.

---

## 7. Quick Troubleshooting on Apple Silicon

1. **CocoaPods Podfile / Architecture Errors**:
   If `pod install` fails on Apple Silicon:
   ```bash
   sudo arch -x86_64 gem install ffi
   arch -x86_64 pod install
   ```
2. **Java Version Conflicts**:
   Ensure `java -version` reports OpenJDK 17 or 21. Android Gradle plugin requires at least Java 17.
3. **Gradle Keystore Path Failure**:
   If `./gradlew assembleRelease` fails with `Cannot find keystore file`:
   Verify `android/key.properties` has `storeFile=../../universal_signing_key.jks` and that `universal_signing_key.jks` is placed in the project root.
