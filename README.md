# StakeDXF

Convert **AutoCAD Civil 3D DWG** linework into **DXF** files ready for **Trimble Access** stakeout.

## What it does

1. Accepts Civil 3D `.dwg` or `.dxf` uploads
2. Decodes DWG with [ezdwg](https://github.com/monozukuri-ai/ezdwg)
3. Filters geometry to entities Trimble Access can select and stake:
   - `LINE`, `LWPOLYLINE`, `POLYLINE`, `ARC`, `CIRCLE`, `POINT`, `INSERT`
4. Optionally explodes blocks, converts splines → polylines, filters layers
5. Writes **R2010 ASCII DXF** (configurable) for the collector

## Civil 3D requirement

Trimble Access does **not** stake Civil 3D custom objects (`AECC_*` feature lines, alignments, corridors, etc.). Before uploading:

1. Open the drawing in Civil 3D
2. Run **`EXPORTTOAUTOCAD`** (explodes AEC objects into standard AutoCAD entities)
3. Or manually explode the feature lines / alignments you need
4. Confirm modelspace uses the same grid coordinate system as the Trimble job
5. Save DWG/DXF and convert with StakeDXF

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m app
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000).

### CLI conversion

```bash
python -m app.cli path/to/design.dwg -o design_trimble_access.dxf
```

### API

```bash
curl -F file=@design.dxf -F dxf_version=R2010 http://127.0.0.1:8000/api/convert
```

## Trimble Access import

1. Copy `*_trimble_access.dxf` into the project folder
2. Map toolbar → **Layer manager** → **Map files**
3. Tap the DXF once (visible), twice (selectable)
4. Enable needed layers
5. Optional Map data controls: **Create nodes**, **Explode polylines**
6. Tap linework → **Stakeout**

## Tests

```bash
pip install -r requirements.txt
pytest -q
```

## Project layout

```
app/           FastAPI backend + conversion pipeline
static/        Web UI
tests/         Pytest suite
data/          Upload / output workspace (gitignored contents)
```

## Notes

- White CAD colors display as black in Trimble Access
- Set **Null elevation** in Trimble if CAD uses sentinel Z values (e.g. `-9999`)
- Large Civil 3D drawings may need layer filtering so field controllers stay responsive
