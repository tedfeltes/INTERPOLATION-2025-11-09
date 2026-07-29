# StakeDXF — source pack (v1.26.2)

Ground-up Flutter source for **StakeDXF** at the current app state
(Convert / Plot / Base — COGO not included).

This archive is intentionally lean: app source, Android native glue, assets,
and build docs. It excludes build caches, APKs, sample plot PDFs, and IDE junk.

## Layout

```text
StakeDXF-source-v1.26.2/
  README.md                 ← this file
  BUILD_IOS.md              ← build / sign / ship on Apple platforms
  BUILD_ANDROID.md          ← APK / TSC5 build notes
  VERSION.txt
  mobile/
    README.md
    stakedxf/               ← Flutter project (lib, android, ios, assets, test)
  native/
    stakedxf_convert.c      ← LibreDWG FFI wrapper (Android CONVERT)
    build_android.sh        ← rebuild libstakedxf.so for arm64-v8a
```

## What works where

| Feature | Android (TSC5) | iOS |
|---|---|---|
| **PLOT** — CSV/TXT points + DXF linework → staking PDF | Yes | Yes |
| **BASE** — combine DWG/DXF → base DXF | Yes (Chaquopy + ezdxf) | Not wired (Android-only Python) |
| **CONVERT** — Civil 3D DWG → Trimble DXF | Yes (`libstakedxf.so` + Python recover) | Not wired (no Chaquopy / no bundled LibreDWG) |

iOS is useful today for **Plot** (and sharing PDFs/CSVs). Convert/Base remain Android field tools until a native iOS recover path is added.

## Quick start

### iPhone / iPad (requires a Mac)

See **[BUILD_IOS.md](BUILD_IOS.md)**.

```bash
cd mobile/stakedxf
flutter pub get
open ios/Runner.xcworkspace   # after first `flutter build ios` / pod install
flutter run -d <your-iphone>
```

### Android / Trimble TSC5

See **[BUILD_ANDROID.md](BUILD_ANDROID.md)**.

```bash
cd mobile/stakedxf
flutter pub get
./tool/ship_apk.sh            # → dist/StakeDXF v1.26.2.apk (from full repo)
# or:
flutter build apk --release
```

## Requirements (summary)

- Flutter **3.32.x** stable (Dart **3.8**) — matches `pubspec.yaml` SDK constraint
- **iOS:** macOS + Xcode 15+ + CocoaPods + Apple Developer account (for device/IPA)
- **Android:** Android SDK / NDK, JDK 17, Python 3.12 (Chaquopy pip for ezdxf)

## Version

See `VERSION.txt` and `mobile/stakedxf/pubspec.yaml` (`1.26.2+34`).
