# Flat patterns (DXF)

`feed_guide_patterns.dxf` is a laser/CNC-ready layout of the mount plate, jaws, and pinion blank.

Regenerate after measuring your machine:

```bash
python3 -m venv .venv && .venv/bin/pip install ezdxf
.venv/bin/python generate_dxf.py \
  --screw-spacing 140 \
  --centerline-z 55 \
  --max-wire-d 38 \
  -o feed_guide_patterns.dxf
```

Layers: `CUT` (profiles), `HOLES` (drills), `CENTER` (alignment), `NOTES` (text).

For 3D-printed parts, prefer the OpenSCAD models in [`../scad/`](../scad/) — they include rack teeth, rail slots, and the lead-in flare.
