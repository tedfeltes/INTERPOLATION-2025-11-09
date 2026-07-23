# StakeDXF

Convert **AutoCAD Civil 3D DWG** linework into **DXF** files ready for **Trimble Access** stakeout — **without AutoCAD in the field**.

## Field workflow (no AutoCAD)

1. Office saves the Civil 3D DWG with **`PROXYGRAPHICS=1`** (typical default) onto the project network share
2. In the field, mount the share and convert with StakeDXF (UI **Network path**, API, or CLI)
3. StakeDXF recovers **AECC_*** objects from embedded **proxy graphics** and writes stakeable `LINE` / `LWPOLYLINE` / `ARC` / `POINT` entities
4. Copy `*_trimble_access.dxf` into the Trimble Access project folder and stake

Civil 3D object *intelligence* is not reconstructed — you get the saved display linework, which is what Trimble Access needs for map stakeout.

If a DWG was saved with `PROXYGRAPHICS=0` (empty proxies), ask the office to re-save once. You still do not need AutoCAD on the collector.

## What it does

1. Reads `.dwg` / `.dxf` from upload **or a mounted network path**
2. Decodes DWG with the best available engine:
   - **ODA File Converter** (if installed)
   - **LibreDWG `dwg2dxf`** (if installed)
   - **ezdwg** (always available)
3. Explodes `ACAD_PROXY_ENTITY` / proxy graphic carriers into Trimble-selectable entities
4. Filters to: `LINE`, `LWPOLYLINE`, `POLYLINE`, `ARC`, `CIRCLE`, `POINT`, `INSERT`
5. Writes **R2010 ASCII DXF** (configurable)

## Quick start

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
# Optional but recommended for Civil 3D DWGs:
#   install LibreDWG (dwg2dxf) and/or ODA File Converter
python -m app
```

Open [http://127.0.0.1:8000](http://127.0.0.1:8000).

### Convert from a network share (CLI)

```bash
python -m app.cli /mnt/projects/Job42/design.dwg -o ~/trimble/design_trimble_access.dxf
# Windows-style mounts work when the OS exposes them as a path:
python -m app.cli //server/projects/Job42/design.dwg --engine libredwg
```

### API — path (no upload)

```bash
curl -X POST http://127.0.0.1:8000/api/convert-path \
  -H 'Content-Type: application/json' \
  -d '{"path":"/mnt/projects/Job42/design.dwg","explode_proxies":true}'
```

### API — upload

```bash
curl -F file=@design.dwg -F explode_proxies=true http://127.0.0.1:8000/api/convert
```

## Trimble Access import

1. Copy `*_trimble_access.dxf` into the project folder
2. Map toolbar → **Layer manager** → **Map files**
3. Tap the DXF once (visible), twice (selectable)
4. Optional: **Create nodes**, **Explode polylines**
5. Tap linework → **Stakeout**

## Tests

```bash
pip install -r requirements.txt
pytest -q
```

## Project layout

```
app/           FastAPI backend, DWG engines, proxy explode, normalize
static/        Web UI (upload + network path)
tests/         Pytest suite including AEC proxy fixture
samples/       Small public DWG smoke files
data/          Upload / output workspace
```

## Notes

- White CAD colors display as black in Trimble Access
- Set **Null elevation** in Trimble if CAD uses sentinel Z values (e.g. `-9999`)
- Large drawings: use layer include/exclude so controllers stay responsive
- Optional office prep still helped by `EXPORTTOAUTOCAD`, but it is **not required** for the field converter when proxy graphics are present
