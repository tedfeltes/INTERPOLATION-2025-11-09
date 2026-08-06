# Fox River Falls North — Trimble Access DXF

Source Drive folder files:

1. `Fox RIver Falls North-Clearing Exhibit_2025-12-01.pdf` — Civil 3D clearing exhibit  
2. `FOX RIVER FALLS STAKE-INTERCEPTOR-SILT 2026-02-20.txt` — PNEZD silt fence stakes

## Survey-coordinate silt fence (use this for stakeout)

Built directly from the staking TXT (same E/N as the points file):

| File | Contents |
| --- | --- |
| **`Fox_River_Falls_SILT_FENCE_trimble_access.dxf`** | **Primary** — 9 silt fence LWPOLYLINEs + POINT nodes |
| `Fox_River_Falls_SILT_FENCE_world.dxf` | Same + point-number labels |

Layers:

- `SILT_FENCE` — connected fence runs (split at END / ditch-check ends)
- `SILT_FENCE_POINTS` — intermediate stake points
- `SILT_FENCE_ENDS` — END / ditch-check points

Coordinates: **survey feet**, PNEZD order from the TXT  
(`Point, Northing, Easting, Elevation, Description`)

Easting ≈ 2,485,914 … 2,489,885  
Northing ≈ 415,577 … 417,641  
Total fence length ≈ **7,989 ft** (9 segments, 84 points)

### TSC5

1. Copy `Fox_River_Falls_SILT_FENCE_trimble_access.dxf` → `Trimble Data/Projects/<job>/`
2. Map → Layer manager → Map files → enable `SILT_FENCE` / points → Stakeout

## Complete DXF in survey coordinates (best-fit)

**`Fox_River_Falls_COMPLETE_survey.dxf`** — all PDF layers transformed into the silt TXT survey CRS, plus exact `SILT_FENCE` from the TXT.

Georeference is a best-fit similarity of PDF linework to the silt stakes (the clearing exhibit has no dedicated silt-fence CAD layer). Typical stake-to-linework residual ~tens of feet — fine for context, not for centimeter stakeout of PDF geometry. Use `SILT_FENCE*` layers for exact stakeout.

See `GEOREF_COMPLETE_REPORT.txt`.

## Clearing exhibit linework (local sheet feet)

The clearing PDF has **no silt fence linework** (no SILT/FENCE labels or matching geometry), so it cannot be tightly locked to the silt TXT by feature matching.

These remain in **local sheet feet** (1″ = 150′, north-up, arbitrary SW origin):

| File | Use |
| --- | --- |
| `Fox_River_Falls_North_Clearing_STAKE_PRIORITY.dxf` | Clearing / sanitary / wetlands (local) |
| `Fox_River_Falls_North_Clearing_trimble_access.dxf` | Full sheet linework (local) |

Do **not** mix the local clearing DXF with a GPS job that uses the silt TXT coordinates unless you transform it with field control.

## Regenerate silt DXF from TXT

```bash
python scripts/pdf_exhibit_to_dxf.py --help   # clearing PDF → local DXF
# silt world DXF is produced from the PNEZD TXT (see scripts or rebuild from this README workflow)
```
