# StakeDXF mobile app (Android TSC5 + iOS)

Installable on-device converter. **No cloud.**

1. Import a Civil 3D DWG → recover stakeable linework → save a Trimble Access DXF  
2. **Export Points** → select points → CSV or customizable staking plot PDF  
   - Marker styles, label formats, optional point table  
   - Optional linked DXF linework by layer  
   - Example PDFs: `dist/plot_examples/` (`dart run tool/generate_plot_examples.dart`)  
   - Docs: `dist/StakeDXF_UI_Slide_Deck.pdf`, `dist/StakeDXF_User_Guide.pdf`, `docs/USER_GUIDE.md`

## Android (Trimble TSC5)

### Build APK

```bash
# 1) Build LibreDWG for Android arm64 (once)
#    (see native/build_android.sh prerequisites)

# 2) Build native converter .so into jniLibs
./native/build_android.sh

# 3) Build + ship release APK
cd mobile/stakedxf
flutter pub get
./tool/ship_apk.sh
```

APK output:

```text
dist/StakeDXF vX.Y.Z.apk
```

(`tool/ship_apk.sh` names the file from `pubspec.yaml` version.)

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
