"""FastAPI application: Civil 3D DWG → Trimble Access DXF converter."""

from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import __version__
from .config import MAX_UPLOAD_BYTES, OUTPUT_DIR, STATIC_DIR, UPLOAD_DIR
from .converter import convert_for_trimble, inspect_file, resolve_source_path
from .engines import available_engines

app = FastAPI(
    title="StakeDXF — Civil 3D to Trimble Access",
    description=(
        "Convert AutoCAD Civil 3D DWG linework into DXF files optimized for "
        "Trimble Access stakeout. Recovers AECC objects from proxy graphics "
        "without requiring AutoCAD in the field."
    ),
    version=__version__,
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

SAFE_NAME = re.compile(r"[^A-Za-z0-9._-]+")
ALLOWED_VERSIONS = {"R12", "R2000", "R2004", "R2007", "R2010", "R2013", "R2018"}


class PathConvertRequest(BaseModel):
    path: str = Field(..., description="Absolute or relative path to a .dwg/.dxf on a mounted network share")
    dxf_version: str = "R2010"
    include_display_only: bool = False
    explode_blocks: bool = True
    convert_splines: bool = True
    explode_proxies: bool = True
    flatten_z: bool = False
    include_layers: str | None = None
    exclude_layers: str | None = None
    prefer_engine: str | None = None
    output_dir: str | None = Field(
        None,
        description="Optional directory for the output DXF (defaults to app data/outputs)",
    )


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
    if raw.startswith("["):
        try:
            data = json.loads(raw)
            if isinstance(data, list):
                return [str(item).strip() for item in data if str(item).strip()]
        except json.JSONDecodeError:
            pass
    return [part.strip() for part in raw.split(",") if part.strip()]


def _validate_version(dxf_version: str) -> None:
    if dxf_version not in ALLOWED_VERSIONS:
        raise HTTPException(
            400, f"Unsupported DXF version. Use one of {sorted(ALLOWED_VERSIONS)}."
        )


@app.get("/", response_class=HTMLResponse)
async def index() -> HTMLResponse:
    index_path = STATIC_DIR / "index.html"
    return HTMLResponse(index_path.read_text(encoding="utf-8"))


@app.get("/api/health")
async def health() -> dict:
    return {
        "status": "ok",
        "version": __version__,
        "engines": available_engines(),
    }


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


@app.post("/api/inspect-path")
async def inspect_path(body: PathConvertRequest) -> dict:
    try:
        path = resolve_source_path(body.path)
        summary = inspect_file(path)
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(400, f"Could not inspect drawing: {exc}") from exc
    return {"filename": path.name, "path": str(path), **summary}


def _run_convert(
    source_path: Path,
    *,
    dxf_version: str,
    include_display_only: bool,
    explode_blocks: bool,
    convert_splines: bool,
    explode_proxies: bool,
    flatten_z: bool,
    include_layers: str | None,
    exclude_layers: str | None,
    prefer_engine: str | None,
    output_dir: Path | None = None,
) -> dict:
    _validate_version(dxf_version)
    job_id = uuid.uuid4().hex[:12]
    stem = source_path.stem
    output_name = f"{stem}_trimble_access.dxf"
    out_root = output_dir or OUTPUT_DIR
    out_root.mkdir(parents=True, exist_ok=True)
    output_path = out_root / f"{job_id}_{output_name}"

    try:
        payload = convert_for_trimble(
            source_path,
            output_path,
            dxf_version=dxf_version,
            include_display_only=include_display_only,
            explode_blocks=explode_blocks,
            convert_splines=convert_splines,
            explode_proxies=explode_proxies,
            include_layers=_parse_layer_list(include_layers),
            exclude_layers=_parse_layer_list(exclude_layers),
            flatten_z=flatten_z,
            prefer_engine=prefer_engine,
        )
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc
    except Exception as exc:
        raise HTTPException(500, f"Conversion failed: {exc}") from exc

    payload["job_id"] = job_id
    payload["download_url"] = f"/api/download/{job_id}"
    payload["output_name"] = output_name
    payload["output_path"] = str(output_path)
    return payload


@app.post("/api/convert")
async def convert(
    file: UploadFile = File(...),
    dxf_version: str = Form("R2010"),
    include_display_only: bool = Form(False),
    explode_blocks: bool = Form(True),
    convert_splines: bool = Form(True),
    explode_proxies: bool = Form(True),
    flatten_z: bool = Form(False),
    include_layers: str | None = Form(None),
    exclude_layers: str | None = Form(None),
    prefer_engine: str | None = Form(None),
) -> dict:
    filename = _safe_filename(file.filename or "drawing.dwg")
    suffix = Path(filename).suffix.lower()
    if suffix not in {".dwg", ".dxf"}:
        raise HTTPException(400, "Upload a .dwg or .dxf file.")

    job_id = uuid.uuid4().hex[:12]
    upload_path = UPLOAD_DIR / f"{job_id}_{filename}"
    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        raise HTTPException(413, "File exceeds 200 MB upload limit.")
    upload_path.write_bytes(data)

    try:
        # Preserve job id alignment with upload prefix by converting then renaming
        payload = _run_convert(
            upload_path,
            dxf_version=dxf_version,
            include_display_only=include_display_only,
            explode_blocks=explode_blocks,
            convert_splines=convert_splines,
            explode_proxies=explode_proxies,
            flatten_z=flatten_z,
            include_layers=include_layers,
            exclude_layers=exclude_layers,
            prefer_engine=prefer_engine,
        )
    finally:
        upload_path.unlink(missing_ok=True)

    return payload


@app.post("/api/convert-path")
async def convert_path(body: PathConvertRequest) -> dict:
    """Convert a DWG/DXF already on a mounted network path — no upload required."""
    try:
        source = resolve_source_path(body.path)
    except FileNotFoundError as exc:
        raise HTTPException(404, str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(400, str(exc)) from exc

    output_dir = Path(body.output_dir).expanduser() if body.output_dir else None
    if output_dir is not None:
        try:
            output_dir.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            raise HTTPException(400, f"Cannot write output_dir: {exc}") from exc

    return _run_convert(
        source,
        dxf_version=body.dxf_version,
        include_display_only=body.include_display_only,
        explode_blocks=body.explode_blocks,
        convert_splines=body.convert_splines,
        explode_proxies=body.explode_proxies,
        flatten_z=body.flatten_z,
        include_layers=body.include_layers,
        exclude_layers=body.exclude_layers,
        prefer_engine=body.prefer_engine,
        output_dir=output_dir,
    )


@app.get("/api/download/{job_id}")
async def download(job_id: str) -> FileResponse:
    if not re.fullmatch(r"[a-f0-9]{12}", job_id):
        raise HTTPException(400, "Invalid job id.")
    matches = list(OUTPUT_DIR.glob(f"{job_id}_*_trimble_access.dxf"))
    if not matches:
        matches = list(OUTPUT_DIR.glob(f"{job_id}_*.dxf"))
        matches = [path for path in matches if not path.name.endswith(".raw.dxf")]
    if not matches:
        raise HTTPException(404, "Converted file not found or expired.")
    path = matches[0]
    download_name = path.name.split("_", 1)[-1] if "_" in path.name else path.name
    return FileResponse(
        path,
        media_type="application/dxf",
        filename=download_name,
    )


@app.get("/api/guide")
async def guide() -> dict:
    return {
        "no_autocad_field_workflow": [
            "Mount the project network share on the field laptop / tablet (SMB/NFS).",
            "Point StakeDXF at the Civil 3D DWG path (UI network field, /api/convert-path, or CLI).",
            "StakeDXF decodes the DWG and explodes embedded AECC/AEC proxy graphics into stakeable LINE/LWPOLYLINE/ARC/POINT entities.",
            "Copy the resulting *_trimble_access.dxf into the Trimble Access project folder and stake.",
            "Office one-time requirement: Civil 3D drawings must be saved with PROXYGRAPHICS=1 (usually already on) so proxy metafiles exist. No AutoCAD is needed in the field.",
        ],
        "civil3d_prep": [
            "Preferred (no field AutoCAD): ensure PROXYGRAPHICS=1 when the DWG is saved in the office.",
            "Optional stronger prep: EXPORTTOAUTOCAD if you control office deliverables.",
            "Freeze annotation / hatch layers you will not stake.",
            "Confirm modelspace uses the project grid coordinate system expected by the Trimble job.",
            "Leave the DWG on the network share for field conversion.",
        ],
        "trimble_import": [
            "Copy the downloaded *_trimble_access.dxf into the project folder.",
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
        "engines": available_engines(),
        "notes": [
            "R2010 ASCII DXF is the default for broad Trimble Access compatibility.",
            "AECC_* intelligence is not reconstructed — only the saved display linework (proxy graphics) is exploded for stakeout.",
            "If proxies have empty graphics (PROXYGRAPHICS=0), ask the office to re-save; field AutoCAD is still not required.",
            "White CAD colors appear black in Trimble Access.",
            "Set Null elevation in Trimble if your CAD uses sentinel Z values such as -9999.",
        ],
    }
