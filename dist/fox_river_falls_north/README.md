# Fox River Falls North — Clearing Exhibit → Trimble Access DXF

Source: Civil 3D PDF  
`Fox RIver Falls North-Clearing Exhibit_2025-12-01.pdf`  
(Drive folder: Fox River Falls North clearing exhibit)

## Use this file on the TSC5

**Recommended for stakeout linework:**

```text
Fox_River_Falls_North_Clearing_STAKE_PRIORITY.dxf
```

Optional (vertices as POINT entities on clearing / sanitary / boring):

```text
Fox_River_Falls_North_Clearing_STAKE_POINTS.dxf
```

Full sheet linework (includes lot lines / base map):

```text
Fox_River_Falls_North_Clearing_trimble_access.dxf
```

### Trimble Access steps

1. Copy the DXF into `Trimble Data/Projects/<your job>/`
2. Map → Layer manager → Map files → add the DXF
3. Enable the layers you need → select linework → Stakeout

## Layers

| Layer | Color | Meaning |
| --- | --- | --- |
| `CLEARING_LIMITS` | Cyan | Tree clearing limits |
| `SANITARY_CLEAR_ZONE` | Magenta | Clear zone along sanitary sewer route |
| `WETLANDS` | Blue | Wetland outlines / fill strokes |
| `WETLAND_EXPANSION` | Red | Potential wetland expansion pockets |
| `BUFFER_BORING` | Green | Buffer / sanitary boring location |
| `LANDSCAPE_POND` | Purple | Existing landscape ponds |
| `SITE_BASE` | White/black | Roads, RR, lot lines (full DXF only) |
| `EXISTING_DETAIL` | Gray | Secondary detail (full DXF only) |
| `STAKE_NODES` | Yellow | Vertex points (points DXF only) |

## Coordinate system (important)

- Units: **US survey feet** (local)
- Orientation: **north-up**
- Scale taken from the sheet / PDF Measure dictionary: **1″ = 150′**
- Origin: southwest corner of retained geometry (arbitrary local 0,0)

The source PDF is a **plotted Civil 3D layout**, not a GeoPDF. It has **no state-plane / WISCRS coordinates**.

For GPS stakeout that matches ground control, either:

1. Transform this DXF in Trimble Access using two or more known field points, or  
2. Convert the original Civil 3D **DWG** (model-space) with StakeDXF instead of the PDF.

Relative geometry (clearing limits, sanitary corridor, wetlands) is preserved at sheet scale.

## Regenerate

```bash
python scripts/pdf_exhibit_to_dxf.py \
  "dist/fox_river_falls_north/Fox RIver Falls North-Clearing Exhibit_2025-12-01.pdf" \
  -o dist/fox_river_falls_north/Fox_River_Falls_North_Clearing_Exhibit_local_ft.dxf \
  --no-text

python -m app.cli \
  dist/fox_river_falls_north/Fox_River_Falls_North_Clearing_Exhibit_local_ft.dxf \
  -o dist/fox_river_falls_north/Fox_River_Falls_North_Clearing_trimble_access.dxf
```

Requires: `ezdxf`, `pymupdf`.
