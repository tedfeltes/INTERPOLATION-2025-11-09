"""FastAPI application: Civil 3D DWG → Trimble Access DXF converter."""

from __future__ import annotations

import json
import re
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, Header, HTTPException, Query, Request, UploadFile
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from . import __version__
from .config import API_KEY, MAX_UPLOAD_BYTES, OUTPUT_DIR, STATIC_DIR, UPLOAD_DIR
from .converter import convert_for_trimble, inspect_file, resolve_source_path
from .engines import available_engines

app = FastAPI(
    title="StakeDXF — Civil 3D to Trimble Access",
    description=(
        "Cloud converter: Civil 3D DWG from OneDrive → stakeable DXF for "
        "Trimble Access on TSC5. Designed for iPhone + Android collector field use."
    ),
    version=__version__,
)

app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

SAFE_NAME = re.compile(r"[^A-Za-z0-9._-]+")
ALLOWED_VERSIONS = {"R12", "R2000", "R2004", "R2007", "R2010", "R2013", "R2018"}


class PathConvertRequest(BaseModel):
    path: str = Field(
        ...,
        description="Absolute path to a .dwg/.dxf (server-side / office automation only)",
    )
    dxf_version: str = "R2010"
    include_display_only: bool = False
    explode_blocks: bool = True
    convert_splines: bool = True
    explode_proxies: bool = True
    flatten_z: bool = False
    include_layers: str | None = None
    exclude_layers: str | None = None
    prefer_engine: str | None = None
    output_dir: str | None = None


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


def _require_api_key(
    x_api_key: str | None = None,
    api_key: str | None = None,
) -> None:
    """When STAKEDXF_API_KEY is configured, enforce it for automation endpoints."""
    if not API_KEY:
        return
    provided = (x_api_key or api_key or "").strip()
    if provided != API_KEY:
        raise HTTPException(401, "Invalid or missing API key.")


@app.get("/", response_class=HTMLResponse)
async def index() -> HTMLResponse:
    index_path = STATIC_DIR / "index.html"
    return HTMLResponse(index_path.read_text(encoding="utf-8"))


@app.get("/manifest.webmanifest")
async def manifest() -> FileResponse:
    return FileResponse(
        STATIC_DIR / "manifest.webmanifest",
        media_type="application/manifest+json",
    )


@app.get("/api/health")
async def health() -> dict:
    return {
        "status": "ok",
        "version": __version__,
        "engines": available_engines(),
        "api_key_required": bool(API_KEY),
        "mode": "cloud-field-kit",
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


async def _store_upload(file: UploadFile) -> tuple[Path, str]:
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
    return upload_path, filename


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
    upload_path, _filename = await _store_upload(file)
    try:
        return _run_convert(
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


@app.post("/api/convert-file")
async def convert_file(
    file: UploadFile = File(...),
    dxf_version: str = Form("R2010"),
    explode_proxies: bool = Form(True),
    explode_blocks: bool = Form(True),
    convert_splines: bool = Form(True),
    flatten_z: bool = Form(False),
    include_display_only: bool = Form(False),
    include_layers: str | None = Form(None),
    exclude_layers: str | None = Form(None),
    x_api_key: str | None = Header(default=None, alias="X-API-Key"),
    api_key: str | None = Query(default=None),
) -> FileResponse:
    """
    Convert and return the DXF bytes directly.

    Built for:
    - iPhone / TSC5 browsers (simple download)
    - Microsoft Power Automate OneDrive flows (HTTP action → Create file)
    """
    _require_api_key(x_api_key, api_key)
    upload_path, filename = await _store_upload(file)
    try:
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
            prefer_engine=None,
        )
    finally:
        upload_path.unlink(missing_ok=True)

    output_path = Path(payload["output_path"])
    if not output_path.exists():
        raise HTTPException(500, "Conversion produced no file.")

    headers = {
        "X-StakeDXF-Job-Id": payload["job_id"],
        "X-StakeDXF-Stakeable-Count": str(payload.get("stakeable_count", 0)),
        "X-StakeDXF-Proxy-Exploded": str(payload.get("proxy_carriers_exploded", 0)),
        "X-StakeDXF-Engine": str(payload.get("engine", "")),
        # Helpful for Power Automate / mobile save-as
        "Access-Control-Expose-Headers": (
            "X-StakeDXF-Job-Id, X-StakeDXF-Stakeable-Count, "
            "X-StakeDXF-Proxy-Exploded, X-StakeDXF-Engine, Content-Disposition"
        ),
    }
    return FileResponse(
        output_path,
        media_type="application/dxf",
        filename=payload["output_name"],
        headers=headers,
    )


@app.post("/api/convert-path")
async def convert_path(body: PathConvertRequest) -> dict:
    """Server-side path convert (office/server automation). Not used on phone."""
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
        media_type="application/octet-stream",
        filename=download_name,
        headers={
            "Content-Disposition": f'attachment; filename="{download_name}"',
        },
    )


@app.get("/api/guide")
async def guide(request: Request) -> dict:
    base = str(request.base_url).rstrip("/")
    return {
        "devices": ["iPhone", "Trimble TSC5 (Android)", "OneDrive"],
        "recommended_field_workflow": [
            "Office saves Civil 3D DWG to the project OneDrive folder (PROXYGRAPHICS=1).",
            "Best: Power Automate auto-converts DWG → *_trimble_access.dxf into the same folder (zero phone conversion).",
            "Or on iPhone/TSC5 browser: open StakeDXF → Browse OneDrive/Files → convert → Save DXF to OneDrive.",
            "On TSC5: OneDrive app → download/copy DXF into Trimble Data/Projects/<project>/.",
            "Trimble Access → Layer manager → Map files → tap DXF twice (selectable) → Stakeout.",
        ],
        "iphone_steps": [
            "Open StakeDXF in Safari (Add to Home Screen for a one-tap icon).",
            "Tap Choose DWG → Browse → OneDrive location (or Files).",
            "Tap Convert — cloud recovers AECC proxy linework.",
            "Tap Save DXF → Save to Files → OneDrive project folder.",
        ],
        "tsc5_steps": [
            "Install/sign in to Microsoft OneDrive on the TSC5.",
            "Open the project folder and download/copy the *_trimble_access.dxf file.",
            "In Trimble Access: Job data → File Explorer → move/copy DXF into Trimble Data/Projects/<your project>/.",
            "Open the job → map → Layer manager → Map files → enable DXF (visible + selectable).",
            "Optional Map data controls: Create nodes, Explode polylines.",
            "Tap linework → Stakeout.",
        ],
        "power_automate": {
            "trigger": "When a file is created or modified in the OneDrive project folder (filter .dwg)",
            "http_action": f"POST {base}/api/convert-file",
            "headers": {"X-API-Key": "(set STAKEDXF_API_KEY on the server)"},
            "body": "multipart/form-data file=<OneDrive file content>",
            "next_action": "Create file in OneDrive with response body as <name>_trimble_access.dxf",
            "template_path": "/static/power-automate-onedrive.md",
        },
        "civil3d_prep": [
            "Save DWG with PROXYGRAPHICS=1 (typical Civil 3D default).",
            "Upload/sync the DWG to the shared OneDrive project folder.",
            "Confirm grid coordinates match the Trimble job.",
            "Optional: freeze annotation/hatch layers you will not stake.",
        ],
        "trimble_import": [
            "Place *_trimble_access.dxf in Trimble Data/Projects/<project>/ on the TSC5.",
            "Map toolbar → Layer manager → Map files.",
            "Tap DXF once (visible), twice (selectable).",
            "Enable Create nodes / Explode polylines if needed.",
            "Tap a line/arc/point → Stakeout.",
        ],
        "stakeable_entities": sorted(
            ["ARC", "CIRCLE", "INSERT", "LINE", "POINT", "POLYLINE", "LWPOLYLINE"]
        ),
        "engines": available_engines(),
        "public_base_url": base,
        "notes": [
            "You do not need a laptop or AutoCAD in the field — only iPhone/TSC5 + OneDrive + this cloud converter.",
            "AECC_* objects are recovered from embedded proxy graphics in the DWG.",
            "If stakeable count is 0, the office DWG likely lacks proxy graphics (PROXYGRAPHICS=0) — re-save once in Civil 3D.",
            "Host StakeDXF on any always-on URL (Docker/VPS/Azure/Render) so the phone can reach it over cellular.",
        ],
    }
