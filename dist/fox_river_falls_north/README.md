# Fox River Falls North — Trimble Access DXF

## Control file (use this)

`FOX RIVER FALLS-PH5-STAKE-SAN INT & SILT REV 2026-01-27.txt`  
(PNEZD — sanitary interceptor + silt). The older interceptor-only TXT is disregarded.

## Downloads (survey coordinates)

| File | Contents |
| --- | --- |
| **`Fox_River_Falls_COMPLETE_survey.dxf`** | All PDF layers (best-fit) + exact SAN/SILT from TXT |
| `Fox_River_Falls_STAKE_PRIORITY_survey.dxf` | Key PDF layers + exact SAN/SILT |
| `Fox_River_Falls_SAN_SILT_staking_survey.dxf` | Exact staking linework/points only |

Exact layers from TXT: `SILT_FENCE`, `SILT_POINTS`, `SANITARY_ALIGN`, `SANITARY_OFFSET`, `SANITARY_BORE`.

PDF layers are similarity-transformed into the same CRS. The clearing exhibit only draws part of the sanitary clear zone, so residuals vary (see `GEOREF_COMPLETE_REPORT.txt`). Use `SANITARY_*` / `SILT_*` for stakeout.

## Local sheet-foot clearing DXFs

Still available for relative PDF linework without survey CRS: `Fox_River_Falls_North_Clearing_*.dxf`.
