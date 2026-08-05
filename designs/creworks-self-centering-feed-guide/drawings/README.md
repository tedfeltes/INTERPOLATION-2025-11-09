# Engineering drawings

## Package

- **`sheets/WSFG_drawing_package.pdf`** — all PNG sheets as one printable PDF  
- **`sheets/WSFG-*.png`** — A3 landscape shop sheets (title block, views, dims, notes)  
- **`sheets/WSFG-*.dxf`** — CAD/laser/CNC geometry for interface + Concepts A–D  

## Generators

| Script | Output |
|--------|--------|
| `generate_engineering_drawings.py` | PNG shop sheets |
| `generate_dxf_engineering.py` | DXF fab patterns |
| `eng_drawing.py` | Shared border / dim helpers |

Provisional machine constants `A`, `B`, `C` live at the top of both generators — edit after measuring, then re-run.

Older cartoon diagrams under `../diagrams/` and the rack-pinion SCAD under `../scad/` are legacy experiments, not the design baseline.
