# StakeDXF

**Installable app** for converting Civil 3D DWG → Trimble Access stakeout DXF  
**on your phone or Trimble TSC5**. Runs on-device. No cloud. No laptop.

## Get the Android app (TSC5)

Prebuilt APK:

```text
dist/StakeDXF-tsc5.apk
```

1. Copy the APK to the TSC5 (OneDrive or USB)
2. Install it (allow unknown apps if asked)
3. Open **StakeDXF** → choose a `.dwg` → **Convert for Trimble Access**
4. **Share / Save DXF** into `Trimble Data/Projects/<job>/`
5. Trimble Access → Map → Layer manager → Map files → tap DXF twice → Stakeout

## Build from source

```bash
# Native LibreDWG converter for Android arm64
./native/build_android.sh

cd mobile/stakedxf
flutter pub get
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

See [mobile/README.md](mobile/README.md).

## iPhone

Same Flutter app. Building/signing an IPA needs a Mac + Xcode + Apple developer account. iOS LibreDWG linkage instructions are in `mobile/README.md`.

## What it does on-device

1. Reads the DWG with LibreDWG (`libstakedxf.so`)
2. Writes R2010 DXF
3. Filters to Trimble-selectable linework: `LINE`, `LWPOLYLINE`, `POLYLINE`, `ARC`, `CIRCLE`, `POINT`, `INSERT`

Office tip: save Civil 3D DWGs with `PROXYGRAPHICS=1` (usual default) so AECC linework is present in the file.

## Repo layout

```
mobile/stakedxf/   Flutter app (Android + iOS)
native/            LibreDWG C wrapper + Android build script
dist/              Installable APK
app/               Optional desktop/server Python tools (not required in the field)
civil3d/           Civil 3D office LISP (ZHOVER live elevation readout)
```
