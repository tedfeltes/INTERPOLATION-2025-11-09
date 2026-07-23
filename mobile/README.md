# StakeDXF mobile app (Android TSC5 + iOS)

Installable on-device converter. **No cloud.** Pick a DWG → convert on the device → share/save a Trimble Access DXF.

## Android (Trimble TSC5)

### Build APK

```bash
# 1) Build LibreDWG for Android arm64 (once)
#    (see native/build_android.sh prerequisites)

# 2) Build native converter .so into jniLibs
./native/build_android.sh

# 3) Build release APK
cd mobile/stakedxf
flutter pub get
flutter build apk --release
```

APK output:

```text
mobile/stakedxf/build/app/outputs/flutter-apk/app-release.apk
```

### Install on TSC5

1. Copy `app-release.apk` to the TSC5 (OneDrive / USB)
2. On the TSC5, open the APK and install (allow unknown sources if prompted)
3. Open **StakeDXF**
4. Choose DWG from OneDrive/Files → **Convert for Trimble Access** → **Share / Save DXF**
5. Save into `Trimble Data/Projects/<job>/`
6. Trimble Access → Map files → selectable → Stakeout

## iPhone

The Flutter iOS project is included. Building an IPA requires a Mac with Xcode and an Apple developer certificate. The same UI/FFI code is used; LibreDWG must be compiled for `ios-arm64` and linked into the Runner target (mirror of the Android `libstakedxf.so` step).

```bash
cd mobile/stakedxf
flutter build ios --release   # Mac + Xcode only
```

## What runs on-device

- `libstakedxf.so` — LibreDWG-based DWG → DXF
- Dart filter — keeps Trimble-selectable entities (`LINE`, `LWPOLYLINE`, `POLYLINE`, `ARC`, `CIRCLE`, `POINT`, `INSERT`)

Civil 3D AECC recovery depends on proxy graphics present in the office-saved DWG.
