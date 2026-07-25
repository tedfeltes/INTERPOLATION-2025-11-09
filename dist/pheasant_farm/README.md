# Pheasant Farm — Trimble Access DXF

Source: `CIVIL BASE_PHEASANT FARM_2026-05-22.dwg` (Google Drive zip)

## Conversion result
- Engine: LibreDWG → ezdxf normalize (proxy explode + block explode + spline approx)
- Stakeable entities (cleaned to site extents): **34746**
- Types: {'ARC': 634, 'LINE': 19747, 'CIRCLE': 2638, 'LWPOLYLINE': 11151, 'POLYLINE': 244, 'INSERT': 298, 'POINT': 34}
- Site E range: 2414087.1 .. 2441869.7
- Site N range: 410123.8 .. 421032.3

## Files
- `PHEASANT_FARM_trimble_access.dxf` — use this in Trimble Access Map files
- Source DWG also copied for reference

## Notes
- Full drawing contained some exploded block geometry far outside the site; those outliers were filtered.
- Put the DXF in `Trimble Data/Projects/<job>/` and set it selectable for stakeout.
