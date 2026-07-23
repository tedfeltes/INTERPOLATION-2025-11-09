# StakeDXF

Cloud converter: **Civil 3D DWG (OneDrive) → Trimble Access DXF** for stakeout on a **Trimble TSC5**, using only an **iPhone + data collector** — no laptop in the field.

## Field reality this is built for

| You have | You don't have |
| --- | --- |
| iPhone | Laptop |
| Trimble TSC5 (Android) | AutoCAD / Civil 3D outside the office |
| OneDrive with office DWGs | Desktop computer on site |

Conversion runs on a hosted StakeDXF URL. Phone/TSC5 only upload/download files.

## Quick field paths

1. **Best:** OneDrive auto-convert via Power Automate → DXF appears beside the DWG → copy DXF onto TSC5  
   → see [FIELD_KIT.md](FIELD_KIT.md) and [static/power-automate-onedrive.md](static/power-automate-onedrive.md)
2. **Manual:** iPhone Safari → Choose DWG from OneDrive → Convert → Save DXF to OneDrive → TSC5 copies it into `Trimble Data/Projects/<project>/`

## Run / host

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
export STAKEDXF_API_KEY='long-random-secret'   # for Power Automate
python -m app
```

Docker:

```bash
docker build -t stakedxf .
docker run -p 8000:8000 -e STAKEDXF_API_KEY='long-random-secret' stakedxf
```

Put HTTPS in front and bookmark the URL on the iPhone (Add to Home Screen).

## API for phone + automation

| Endpoint | Purpose |
| --- | --- |
| `POST /api/convert` | JSON summary + download URL (web UI) |
| `POST /api/convert-file` | Returns DXF bytes directly (iPhone save / Power Automate) |
| `GET /api/download/{job_id}` | Download a previous result |
| `GET /api/guide` | Device-specific workflow JSON |

`STAKEDXF_API_KEY` (optional): when set, `/api/convert-file` requires header `X-API-Key`.

## How AECC objects are handled

Civil 3D `AECC_*` objects are proprietary. StakeDXF recovers their **proxy graphics** (display linework embedded when the office saved the DWG with `PROXYGRAPHICS=1`) and writes Trimble-selectable `LINE` / `LWPOLYLINE` / `ARC` / `POINT` entities.

## TSC5 import

1. Copy `*_trimble_access.dxf` into `Trimble Data/Projects/<project>/`
2. Map → Layer manager → Map files
3. Tap DXF twice (selectable)
4. Optional: Create nodes / Explode polylines
5. Tap linework → Stakeout

## Tests

```bash
pytest -q
```

## Project layout

```
app/           Cloud converter API
static/        Mobile field UI + PWA + Power Automate notes
FIELD_KIT.md   Phone + TSC5 + OneDrive instructions
tests/         Pytest suite
```
