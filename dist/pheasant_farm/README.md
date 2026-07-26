# Pheasant Farm — Trimble Access DXF + staking plots

Source: `CIVIL BASE_PHEASANT FARM_2026-05-22.dwg` (Google Drive zip)

## Conversion result
- Engine: LibreDWG → ezdxf normalize (proxy explode + block explode + spline approx)
- Stakeable entities (cleaned to site extents): **34746**
- Empty layer-table entries purged (only layers with data remain)
- Types: `ARC`, `LINE`, `CIRCLE`, `LWPOLYLINE`, `POLYLINE`, `INSERT`, `POINT`
- Site E range: 2414087.1 .. 2441869.7
- Site N range: 410123.8 .. 421032.3

## Files
| File | Purpose |
| --- | --- |
| `PHEASANT_FARM_trimble_access.dxf` | Full converted DXF for Trimble Access Map files |
| `PHEASANT_FARM_staking_layers_clip.dxf` | Layer-selected + window-clipped subset for demo plots |
| `PHEASANT_FARM-STAKE-ROCK_PROBE_2026-07-16.txt` | 40 rock probe points (PNEZD) |
| `PHEASANT_FARM_staking_plot.pdf` | Primary example staking sheet |
| `plot_examples/` | Additional plots showing layer selection + marker options |

## Layer selection (app)
After **Convert DWG → DXF**, StakeDXF lists only layers that contain stakeable
entities. Uncheck layers (for example the dense `0` catch-all or amenity
linework) before saving the DXF used in Trimble Access or Export Points.

Useful staking layers on this job include:
- `P-CURB`, `P-SW`
- `P-U-STM`, `P-U-SAN`, `P-U-WAT`, `P-(FUTURE)-U-STM`
- `RES_SURVEY$0$P-LOTLINE`, `RES_SURVEY$0$P-CL`, `RES_SURVEY$0$E-ROW`

## Regenerate plot examples
```bash
cd mobile/stakedxf
dart run tool/generate_pheasant_farm_plots.dart
```

## Notes
- Full drawing contained some exploded block geometry far outside the site; those outliers were filtered.
- Put the DXF in `Trimble Data/Projects/<job>/` and set it selectable for stakeout.
