# StakeDXF User Guide

Install · Usage · Help for the Trimble TSC5 app.

Companion PDFs:
- `dist/StakeDXF_User_Guide.pdf`
- `dist/StakeDXF_UI_Slide_Deck.pdf`

## 1. Installation (Trimble TSC5)

**File:** `dist/StakeDXF vX.Y.Z.apk` (~65 MB)  
**Package:** `com.stakedxf.stakedxf`

1. Copy `StakeDXF vX.Y.Z.apk` onto the TSC5 (USB File Transfer or your usual file share).
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

## 2. Usage — CONVERT (DWG → DXF)

1. Open **StakeDXF → CONVERT**
2. Tap the drawing slot → pick the DWG / DXF
3. Tap **RUN CONVERT**
4. Confirm stakeable entity count (and proxy explode count when present)
5. Review the **LAYERS** checklist (empty layers omitted)
6. Tap **SAVE DXF** to the TSC5 documents folder
7. Move it into `Trimble Data/Projects/<job>/`
8. Trimble Access: **Map → Layer manager → Map files → selectable → Stakeout**

### On-device pipeline
1. LibreDWG: DWG → DXF  
2. ezdxf: explode `ACAD_PROXY_ENTITY` / AEC proxies → LINE / ARC / POLYLINE  
3. Keep Trimble-stakeable types only; purge empty layer-table entries  
4. Optional: export a subset of layers from the LAYERS checklist  

**Tip:** Office DWGs should keep proxy graphics so Civil features can be recovered.

## 3. Usage — PLOT (Export Points)

1. Export points from Trimble Access as CSV/TXT (PNEZD)
2. **StakeDXF → PLOT**
3. Enter a **JOB** name
4. **IMPORT POINTS CSV / TXT**
5. (Optional) **LINK DXF LINEWORK** and pick layers
6. Set **MARKER**, **LABEL**, **SCALE**, **SHEET**
7. (Optional) place library objects — hydrant / MH / sign
8. Select points for the sheet
9. **CREATE STAKING PLOT PDF** or **EXPORT CSV**

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
| Point list table | Off by default; optional on |
| Linework | Optional linked DXF layers |
| Scale | Auto engineering scale, or fixed `1"=N'` |
| Sheet | ANSI A–D, portrait or landscape |
| Colors | Full ACI, CTB, HSV true-color |
| Layer lock | Lk column — locked layers can't be dragged |

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
  01  CONVERT       Recover Civil 3D linework
  02  PLOT          CSV + staking plot PDF

Convert
  Pick drawing → RUN CONVERT → tick layers → SAVE DXF → Trimble Map files

Plot
  Import CSV → (Link DXF) → Marker / Label / Scale / Sheet →
  Select points → CREATE STAKING PLOT PDF   or   EXPORT CSV

Good staking defaults
  Marker: Large X
  Label:  Number + elevation
  Table:  Off
  Layers: On (only what you need)
```

Runs on-device. No cloud. No tracking.
