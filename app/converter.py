"""DWG/DXF conversion pipeline for Trimble Access stakeout linework."""

from __future__ import annotations

import shutil
from dataclasses import dataclass, field
from pathlib import Path

import ezdwg
import ezdxf

from .config import DEFAULT_DXF_VERSION, TRIMBLE_STAKEABLE_TYPES
from .engines import available_engines, dwg_to_dxf_best_effort
from .normalize import analyze_document, normalize_dxf, result_to_dict


@dataclass
class ConversionJob:
    job_id: str
    source_name: str
    source_path: Path
    output_path: Path
    intermediate_dxf: Path | None = None
    engine: str = ""
    messages: list[str] = field(default_factory=list)


def _is_dwg(path: Path) -> bool:
    return path.suffix.lower() == ".dwg"


def _is_dxf(path: Path) -> bool:
    return path.suffix.lower() == ".dxf"


def resolve_source_path(raw: str) -> Path:
    """Resolve a local or network filesystem path to an existing DWG/DXF."""
    path = Path(raw).expanduser()
    if not path.is_absolute():
        # Allow relative paths from CWD (useful for mounted shares)
        path = path.resolve()
    else:
        path = path.resolve()
    if not path.exists():
        raise FileNotFoundError(f"Drawing not found: {path}")
    if not path.is_file():
        raise ValueError(f"Not a file: {path}")
    if path.suffix.lower() not in {".dwg", ".dxf"}:
        raise ValueError("Only .dwg and .dxf files are supported.")
    return path


def inspect_file(path: Path) -> dict:
    """Return a lightweight summary of layers / entity types for UI preview."""
    suffix = path.suffix.lower()
    if suffix == ".dxf":
        doc = ezdxf.readfile(str(path))
        type_counts, layers, total = analyze_document(doc)
        proxy_count = type_counts.get("ACAD_PROXY_ENTITY", 0)
        return {
            "format": "dxf",
            "entity_count": total,
            "types": dict(type_counts),
            "proxy_entity_count": proxy_count,
            "layers": [
                {
                    "name": layer.name,
                    "entity_count": layer.entity_count,
                    "stakeable_count": layer.stakeable_count,
                    "types": layer.types,
                }
                for layer in layers
            ],
            "note": (
                f"Found {proxy_count} ACAD_PROXY_ENTITY carrier(s) — "
                "Civil 3D linework will be recovered from proxy graphics."
                if proxy_count
                else None
            ),
        }

    if suffix == ".dwg":
        engines = available_engines()
        doc = ezdwg.read(str(path))
        types: dict[str, int] = {}
        layers_map: dict[str, int] = {}
        try:
            layout = doc.modelspace() if hasattr(doc, "modelspace") else None
            entities = list(layout) if layout is not None else list(getattr(doc, "entities", []))
            for entity in entities:
                etype = getattr(entity, "dxftype", lambda: "UNKNOWN")()
                if callable(etype):
                    etype = etype()
                etype = str(etype).upper()
                types[etype] = types.get(etype, 0) + 1
                layer = str(getattr(getattr(entity, "dxf", entity), "layer", "0"))
                layers_map[layer] = layers_map.get(layer, 0) + 1
        except Exception:
            pass
        return {
            "format": "dwg",
            "entity_count": sum(types.values()),
            "types": types,
            "engines": engines,
            "layers": [
                {"name": name, "entity_count": count, "stakeable_count": None, "types": {}}
                for name, count in sorted(layers_map.items())
            ],
            "note": (
                "Civil 3D AECC objects are recovered from embedded proxy graphics "
                "(no AutoCAD required). Prefer LibreDWG or ODA for best fidelity. "
                f"Engines: {', '.join(k for k, v in engines.items() if v)}."
            ),
        }

    raise ValueError(f"Unsupported file type: {suffix}")


def convert_for_trimble(
    source_path: Path,
    output_path: Path,
    *,
    dxf_version: str = DEFAULT_DXF_VERSION,
    include_display_only: bool = False,
    explode_blocks: bool = True,
    convert_splines: bool = True,
    explode_proxies: bool = True,
    include_layers: list[str] | None = None,
    exclude_layers: list[str] | None = None,
    flatten_z: bool = False,
    prefer_engine: str | None = None,
) -> dict:
    """
    Full pipeline: DWG/DXF → Trimble Access stakeout DXF.

    AECC_* Civil 3D objects are recovered by exploding proxy graphics — AutoCAD
    is not required on the machine running this converter.
    """
    source_path = Path(source_path)
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    messages: list[str] = []
    engine = "ezdxf"

    if _is_dxf(source_path):
        dxf_source = source_path
        messages.append("Input is DXF — skipping DWG decode.")
    elif _is_dwg(source_path):
        intermediate = output_path.with_suffix(".raw.dxf")
        engine = dwg_to_dxf_best_effort(
            source_path,
            intermediate,
            dxf_version=dxf_version,
            explode_blocks=explode_blocks,
            prefer=prefer_engine,
        )
        dxf_source = intermediate
        messages.append(
            f"DWG decoded with {engine} (proxy carriers preserved when present)."
        )
    else:
        raise ValueError("Only .dwg and .dxf files are supported.")

    try:
        ezdxf.readfile(str(dxf_source))
    except Exception as exc:
        raise RuntimeError(
            "Could not read drawing after DWG decode. "
            f"Decoder={engine}. Detail: {exc}"
        ) from exc

    result = normalize_dxf(
        str(dxf_source),
        str(output_path),
        dxf_version=dxf_version,
        include_display_only=include_display_only,
        explode_blocks=explode_blocks,
        convert_splines=convert_splines,
        explode_proxies=explode_proxies,
        include_layers=include_layers,
        exclude_layers=exclude_layers,
        flatten_z=flatten_z,
    )

    if dxf_source != source_path and dxf_source != output_path:
        try:
            Path(dxf_source).unlink(missing_ok=True)
        except OSError:
            pass

    payload = result_to_dict(result)
    payload["engine"] = engine
    payload["engines_available"] = available_engines()
    payload["messages"] = messages + result.warnings
    payload["output_name"] = output_path.name
    payload["trimble_stakeable_types"] = sorted(TRIMBLE_STAKEABLE_TYPES)
    payload["source_path"] = str(source_path)
    return payload


def copy_upload(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
