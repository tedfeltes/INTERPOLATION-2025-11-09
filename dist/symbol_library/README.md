# StakeDXF plot object library

## Built-in symbols (civil details / signage)

Plan-view symbols curated from the **Three Pillars – Phase 1C** civil set:

| Source sheet | Objects taken |
| --- | --- |
| `C7.00 DETAILS` | Fire hydrant, sanitary/storm manholes, cleanout, catch basin / inlets, silt fence, inlet protection |
| `C7.01 DETAILS` | Rip-rap, flared end / pipe grate, handicap parking sign |
| `C7.02 DETAILS` | Bollard, dewatering / filter bag, inline drain |
| `C7.03 DETAILS` | Additional construction detail annotations |
| `C6.11 SIGNAGE PLAN` | STOP, YIELD, DO NOT ENTER, ONE WAY, speed limit, NO OUTLET, ped/bike crossing |
| `C3.0 EROS CTRL` | Silt fence / wattle patterns |

## DWG blocks (every named BLOCK)

`dwg_blocks.json` — named BLOCK definitions with drawable geometry, extracted from
the project DWG (Google Drive file `1tzP9JiEe1epklN-1jtv18FHxNmZBH6mN`) via
LibreDWG → DXF → ezdxf.

See `dwg_blocks_inventory.md` for the full name list.

In the app these appear under **Plot objects → DWG blocks** (searchable).

## In the app

**Export Points → Plot objects → Add from object library**

- Snap to a stake point or enter N/E
- Nudge N/S/E/W
- Scale (0.25×–5×)
- Rotate (−180°–180°)
- Recolor (preset palette)
- Optional custom label

## Full catalog PDF

`StakeDXF_Object_Library.pdf`

- Page 1: all built-in symbols by category
- Following pages: every extracted DWG BLOCK

Regenerate:
```bash
cd mobile/stakedxf
dart run tool/generate_symbol_catalog.dart
```

## Source thumbnails

`source_C7.*.png`, `source_C6.11_SIGNAGE.png`, `source_C3.0_EROS_CTRL.png` are low-res
overviews of the source sheets used to curate the built-in library.
