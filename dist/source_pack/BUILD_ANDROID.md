# Building StakeDXF for Android (TSC5)

Companion to **BUILD_IOS.md**. App version in this pack: **1.26.2**.

## Prerequisites

- Flutter **3.32.x** stable (Dart 3.8)
- Android SDK + platform tools; **NDK 27** (or the NDK pinned in
  `android/app/build.gradle.kts`)
- JDK **17**
- **Python 3.12** on the build machine (Chaquopy `buildPython` + pip `ezdxf==1.4.2`)

## Build APK (prebuilt native lib included)

This pack includes `android/app/src/main/jniLibs/arm64-v8a/libstakedxf.so`
so you can ship without rebuilding LibreDWG:

```bash
cd mobile/stakedxf
flutter pub get

# Release APK
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Or use the ship helper (writes versioned name under repo dist/ when
# the full monorepo layout is present):
./tool/ship_apk.sh
```

ABI: **arm64-v8a only** (Trimble TSC5). Install with unknown sources allowed.

## Rebuild the native converter (optional)

Needs a LibreDWG Android static library prefix:

```bash
# From pack root
export ANDROID_HOME=~/Android/Sdk
export LIBREDWG_ANDROID_PREFIX=/path/to/libredwg-android-prefix
./native/build_android.sh
# → mobile/stakedxf/android/app/src/main/jniLibs/arm64-v8a/libstakedxf.so
```

Python recover lives in `android/app/src/main/python/linework.py` (Chaquopy).

## Install on TSC5

1. Copy the APK to the collector  
2. Open → install  
3. CONVERT → DWG → Save DXF into `Trimble Data/Projects/<job>/`
