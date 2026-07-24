# How to install StakeDXF on a Trimble TSC5

The file you need is:

```text
dist/StakeDXF-tsc5.apk
```

That is an **Android installer**. It goes on the **TSC5** (Android controller).

## What the app does

1. Import a Civil 3D `.dwg` / `.dxf`
2. **Recover stakeable linework** (including Civil 3D / AEC proxy graphics → LINE / ARC / POLYLINE)
3. Export a Trimble Access DXF you can stake

## Install the APK

1. Copy `StakeDXF-tsc5.apk` onto the TSC5 (USB, Files, or any file transfer you already use).
2. On the TSC5, open the APK from **Files** / **Downloads**.
3. If Android blocks it, enable **Allow from this source** for the app that opened the APK.
4. Tap **Install**, then open **StakeDXF**.

## If Install is greyed out / “not allowed”

Company MDM may block unknown APKs. Ask IT to allow unknown-source installs, or push the APK through managed distribution.

## Convert a DWG → stakeable DXF

1. Open **StakeDXF**
2. Tap **Choose DWG / DXF**
3. Pick the Civil 3D drawing
4. Tap **Convert for Trimble Access**
5. Confirm it reports stakeable entities (and proxy explode count when Civil 3D proxies were present)
6. Tap **Save DXF** and put it in:

```text
Trimble Data/Projects/<your project>/
```

7. In Trimble Access: Map → Layer manager → **Map files** → make the DXF selectable → Stakeout

## Confirm you have the right file

- Name ends with `.apk`
- Package id: `com.stakedxf.stakedxf`
- App label after install: **StakeDXF**
