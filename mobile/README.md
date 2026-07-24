# StakeDXF mobile app (Android TSC5 + iOS)

Installable on-device converter. **No cloud.**

1. Import a Civil 3D DWG → recover stakeable linework → save a Trimble Access DXF  
2. **Export Points** → select points → CSV or control-note-style staking plot PDF (auto-scaled)

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

Also copied for distribution as `dist/StakeDXF-tsc5.apk`.

### Install on TSC5

1. Copy the APK onto the TSC5
2. Open the APK and install (allow unknown sources if prompted)
3. Open **StakeDXF**
4. Choose DWG → **Convert for Trimble Access** → **Save DXF**
5. Put the DXF in `Trimble Data/Projects/<job>/`
6. Trimble Access → Map files → selectable → Stakeout

## What runs on-device

1. `libstakedxf.so` — LibreDWG DWG → DXF
2. **Python (Chaquopy + ezdxf)** — explode Civil 3D / AEC `ACAD_PROXY_ENTITY` proxy graphics into `LINE` / `ARC` / `POLYLINE`
3. Keep Trimble-selectable entities only → export DXF

## iPhone

The Flutter iOS project is included. Building an IPA requires a Mac with Xcode and an Apple developer certificate. Proxy explode on iOS is not wired the same way yet (Android uses Chaquopy).
