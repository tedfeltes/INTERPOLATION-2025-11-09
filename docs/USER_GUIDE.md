# StakeDXF User Guide

Install · Usage · Help for the Trimble TSC5 app.

Companion PDFs:
- `dist/StakeDXF_User_Guide.pdf`
- `dist/StakeDXF_UI_Slide_Deck.pdf`

## 1. Installation (Trimble TSC5)

**File:** `dist/StakeDXF-tsc5.apk` (~65 MB)  
**Package:** `com.stakedxf.stakedxf`

1. Copy `StakeDXF-tsc5.apk` onto the TSC5 (USB File Transfer or your usual file share).
2. Open **Files / Downloads** and tap the APK.
3. If blocked, enable **Allow from this source** for the app that opened the APK.
4. Tap **Install**, then open **StakeDXF**.

### If Install is greyed out
Company MDM may block unknown APKs. Ask IT to allow unknown-source installs or push the APK through managed distribution.

### Common mistakes
- Opening the APK on **iPhone** (Android only)
- Opening a zip/repo instead of the `.apk`
- USB left on **Charging only** (use File Transfer)

Also see `dist/INSTALL_TSC5.md`.

## 2. Usage — Convert DWG → DXF

Recover Civil 3D linework into a Trimble-stakeable DXF on the controller.

1. Open **StakeDXF → Convert DWG → DXF**
2. **Choose DWG / DXF**
3. **Convert for Trimble Access**
4. Confirm stakeable entity count (and proxy explode count when present)
5. Review **Converted layers** (empty layers omitted) and select which to export
6. **Save DXF** into `Trimble Data/Projects/<job>/`
7. Trimble Access: **Map → Layer manager → Map files → selectable → Stakeout**

### On-device pipeline
1. LibreDWG: DWG → DXF  
2. ezdxf: explode `ACAD_PROXY_ENTITY` / AEC proxies → LINE / ARC / POLYLINE  
3. Keep Trimble-stakeable types only; purge empty layer-table entries  
4. Optional: export a subset of layers from the on-screen checklist  

**Tip:** Office DWGs should keep proxy graphics so Civil features can be recovered.

## 3. Usage — Export Points & staking plots

1. Export points from Trimble Access as CSV/TXT (PNEZD)
2. **StakeDXF → Export Points**
3. **Import points CSV / TXT**
4. (Optional) **Link DXF linework** and select layers
5. Choose **point marker** and **point label** format
6. Leave **Include point list table** off unless you want the coordinate table
7. (Optional) **Add from object library** — place, nudge, scale, rotate, recolor
8. Select points for the sheet
9. **Create staking plot PDF** (auto scale)  
   or **Export selected points CSV**

### Supported point formats
- PNEZD: Point, Northing, Easting, Elevation, Description (headered or not)
- Common header aliases (`Point #`, `Elev`, `Desc`, …)

### Linked DXF linework
Draws `LINE`, `LWPOLYLINE`, `POLYLINE`, `ARC`, `CIRCLE` for checked layers.

## 4. Plot customization

| Option | Choices |
| --- | --- |
| Markers | Filled triangle, triangle outline, cross (+), X, large X, circle, dot, large dot |
| Labels | Number · number+description · number+elevation · number+description+elevation · none |
| Point list table | Off by default (more plot space); optional on |
| Linework | Optional linked DXF layers |
| Scale | Auto engineering scale to fit ANSI B landscape sheet |

Examples: `dist/plot_examples/`  
Regenerate: `cd mobile/stakedxf && dart run tool/generate_plot_examples.dart`

## 5. Help & troubleshooting

**No stakeable entities after convert**  
Drawing may lack proxy graphics. Re-save from Civil 3D with proxies preserved.

**Plot has no linework**  
Link a DXF, enable **Draw linked DXF linework**, and check at least one layer.

**Points missing after import**  
Use PNEZD or a headered CSV with Northing/Easting columns.

**App will not install**  
Must be TSC5 (Android). Enable unknown sources or get IT MDM approval.

## 6. Quick reference

```
Home
  Convert DWG → DXF     Recover Civil 3D linework
  Export Points         CSV + staking plot PDF

Convert
  Choose drawing → Convert → Save DXF → Trimble Map files

Export Points
  Import CSV → (Link DXF) → Marker/Label → Select points
  → Create staking plot PDF   or   Export CSV

Good staking defaults
  Marker: Large X
  Label: Number + elevation
  Point list table: Off
  Linework: On (only layers you need)
```

Runs on-device. No cloud upload.
