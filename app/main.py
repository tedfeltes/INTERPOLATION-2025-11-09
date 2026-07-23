"""FastAPI application: Civil 3D DWG → Trimble Access DXF converter."""

from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles

from . import __version__
from .config import MAX_UPLOAD_BYTES, OUTPUT_DIR, STATIC_DIR, UPLOAD_DIR
from .converter import convert_for_trimble, inspect_file

app = FastAPI(
    title="StakeDXF — Civil 3D to Trimble Access",
    description=(
        "Convert AutoCAD Civil 3D DWG linework into DXF files optimized for "
        "Trimble Access stakeout."
    ),
    version=__version__,
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

SAFE_NAME = re.compile(r"[^A-Za-z0-9._-]+")


def _safe_filename(name: str) -> str:
    base = Path(name).name
    cleaned = SAFE_NAME.sub("_", base).strip("._")
    return cleaned or "drawing"


def _parse_layer_list(raw: str | None) -> list[str] | None:
    if not raw:
        return None
    raw = raw.strip()
    if not raw:
        return None
    # Allow JSON array or comma-separated
    if raw.startswith("["):
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                return [str(item).strip() for item in data if str(item).strip()]
        except json.JSONDecodeError:
            pass
    return [part.strip() for part in raw.split(",") if part.strip()]


@app.get("/", response_class=HTMLResponse)
async def index() -> HTMLResponse:
    index_path = STATIC_DIR / "index.html"
    return HTMLResponse(index_path.read_text(encoding="utf-8"))


@app.get("/api/health")
async def health() -> dict:
    return {"status": "ok", "version": __version__}


@app.post("/api/inspect")
async def inspect(file: UploadFile = File(...)) -> dict:
    filename = _safe_filename(file.filename or "drawing.dxf")
    suffix = Path(filename).suffix.lower()
    if suffix not in {".dwg", ".dxf"}:
        raise HTTPException(400, "Upload a .dwg or .dxf file.")

    job_id = uuid.uuid4().hex[:12]
    dest = UPLOAD_DIR / f"{job_id}_{filename}"
    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "File exceeds 200 MB upload limit.")
    dest.write_bytes(data)

    try:
        summary = inspect_file(dest)
    except Exception as exc:
        raise HTTPException(400, f"Could not inspect drawing: {exc}") from exc
    finally:
        dest.unlink(missing_ok=True)

    return {"filename": filename, **summary}


@app.post("/api/convert")
async def convert(
    file: UploadFile = File(...),
    dxf_version: str = Form("R2010"),
    include_display_only: bool = Form(False),
    explode_blocks: bool = Form(True),
    convert_splines: bool = Form(True),
    flatten_z: bool = Form(False),
    include_layers: str | None = Form(None),
    exclude_layers: str | None = Form(None),
) -> dict:
    filename = _safe_filename(file.filename or "drawing.dwg")
    suffix = Path(filename).suffix.lower()
    if suffix not in {".dwg", ".dxf"}:
        raise HTTPException(400, "Upload a .dwg or .dxf file.")

    allowed_versions = {"R12", "R2000", "R2004", "R2007", "R2010", "R2013", "R2018"}
    if dxf_version not in allowed_versions:
        raise HTTPException(400, f"Unsupported DXF version. Use one of {sorted(allowed_versions)}.")

    job_id = uuid.uuid4().hex[:12]
    upload_path = UPLOAD_DIR / f"{job_id}_{filename}"
    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "File exceeds 200 MB upload limit.")
    upload_path.write_bytes(data)

    stem = Path(filename).stem
    output_name = f"{stem}_trimble_access.dxf"
    output_path = OUTPUT_DIR / f"{job_id}_{output_name}"

    try:
        payload = convert_for_trimble(
            upload_path,
            output_path,
            dxf_version=dxf_version,
            include_display_only=include_display_only,
            explode_blocks=explode_blocks,
            convert_splines=convert_splines,
            include_layers=_parse_layer_list(include_layers),
            exclude_layers=_parse_layer_list(exclude_layers),
            flatten_z=flatten_z,
        )
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(500, f"Conversion failed: {exc}") from exc
    finally:
        upload_path.unlink(missing_ok=True)

    payload["job_id"] = job_id
    payload["download_url"] = f"/api/download/{job_id}"
    payload["output_name"] = output_name
    return payload


@app.get("/api/download/{job_id}")
async def download(job_id: str) -> FileResponse:
    if not re.fullmatch(r"[a-f0-9]{12}", job_id):
        raise HTTPException(400, "Invalid job id.")
    matches = list(OUTPUT_DIR.glob(f"{job_id}_*_trimble_access.dxf"))
    if not matches:
        # Also allow exact pattern from convert
        matches = list(OUTPUT_DIR.glob(f"{job_id}_*.dxf"))
        matches = [path for path in matches if not path.name.endswith(".raw.dxf")]
    if not matches:
        raise HTTPException(404, "Converted file not found or expired.")
    path = matches[0]
    # Strip job id prefix for download filename
    download_name = path.name.split("_", 1)[-1] if "_" in path.name else path.name
    return FileResponse(
        path,
        media_type="application/dxf",
        filename=download_name,
    )


@app.get("/api/guide")
async def guide() -> dict:
    return {
        "civil3d_prep": [
            "Open the drawing in AutoCAD Civil 3D.",
            "Run EXPORTTOAUTOCAD (or AECCEXPORTTOAUTOCAD) to explode Civil 3D objects into standard AutoCAD entities.",
            "Alternatively: explode feature lines / alignments you need for stakeout into polylines.",
            "Freeze or freeze-off annotation, hatches, and xref layers you do not need in the field.",
            "Confirm modelspace linework uses the project grid coordinate system expected by the Trimble job.",
            "Save as DWG (or DXF) and upload here.",
        ],
        "trimble_import": [
            "Copy the downloaded *_trimble_access.dxf into the Trimble Access project folder.",
            "Open the job → map toolbar → Layer manager → Map files.",
            "Tap the DXF once to make it visible, twice to make items selectable.",
            "Expand layers and enable only the stakeout layers you need.",
            "Optional Map data controls: enable Create nodes to stake vertices; enable Explode polylines for segment staking.",
            "Tap a line/arc/point on the map → Stakeout.",
        ],
        "stakeable_entities": [
            "ARC",
            "CIRCLE",
            "INSERT",
            "LINE",
            "POINT",
            "POLYLINE",
            "LWPOLYLINE",
        ],
        "display_only_entities": [
            "3DFACE",
            "SPLINE",
            "SOLID",
            "TEXT",
            "MTEXT",
            "HATCH",
            "ATTRIB",
        ],
        "notes": [
            "R2010 ASCII DXF is the default for broad Trimble Access compatibility.",
            "Civil 3D AECC proxy objects cannot be staked until exploded to standard entities.",
            "White CAD colors appear black in Trimble Access.",
            "Set Null elevation in Trimble if your CAD uses sentinel Z values such as -9999.",
        ],
    }
