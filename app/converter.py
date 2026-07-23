"""DWG/DXF conversion pipeline for Trimble Access stakeout linework."""

from __future__ import annotations

import shutil
from dataclasses import dataclass, field
from pathlib import Path

import ezdwg
import ezdxf

from .config import DEFAULT_DXF_VERSION, TRIMBLE_STAKEABLE_TYPES
from .normalize import NormalizeResult, normalize_dxf, result_to_dict


STAKEABLE_TYPE_LIST = " ".join(sorted(TRIMBLE_STAKEABLE_TYPES | {"SPLINE"}))


@dataclass
class ConversionJob:
    job_id: str
    source_name: str
    source_path: Path
    output_path: Path
    intermediate_dxf: Path | None = None
    result: NormalizeResult | None = None
    engine: str = ""
    messages: list[str] = field(default_factory=list)


def _is_dwg(path: Path) -> bool:
    return path.suffix.lower() == ".dwg"


def _is_dxf(path: Path) -> bool:
    return path.suffix.lower() == ".dxf"


def inspect_file(path: Path) -> dict:
    """Return a lightweight summary of layers / entity types for UI preview."""
    suffix = path.suffix.lower()
    if suffix == ".dxf":
        doc = ezdxf.readfile(str(path))
        from .normalize import analyze_document

        type_counts, layers, total = analyze_document(doc)
        return {
            "format": "dxf",
            "entity_count": total,
            "types": dict(type_counts),
            "layers": [
                {
                    "name": layer.name,
                    "entity_count": layer.entity_count,
                    "stakeable_count": layer.stakeable_count,
                    "types": layer.types,
                }
                for layer in layers
            ],
        }

    if suffix == ".dwg":
        doc = ezdwg.read(str(path))
        # ezdwg Document — collect layout entity types when available
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
            "layers": [
                {"name": name, "entity_count": count, "stakeable_count": None, "types": {}}
                for name, count in sorted(layers_map.items())
            ],
            "note": (
                "DWG preview lists entities readable by the open-source parser. "
                "Civil 3D AECC objects may be missing until EXPORTTOAUTOCAD is used."
            ),
        }

    raise ValueError(f"Unsupported file type: {suffix}")


def dwg_to_dxf(
    source_path: Path,
    intermediate_path: Path,
    *,
    dxf_version: str = DEFAULT_DXF_VERSION,
    explode_blocks: bool = True,
) -> str:
    """Convert DWG → DXF using ezdwg. Returns engine label."""
    result = ezdwg.to_dxf(
        str(source_path),
        str(intermediate_path),
        types=STAKEABLE_TYPE_LIST,
        dxf_version=dxf_version,
        modelspace_only=True,
        flatten_inserts=explode_blocks,
        include_unsupported=False,
        strict=False,
    )
    exported = getattr(result, "exported", None)
    if exported == 0 or (isinstance(exported, int) and exported == 0):
        # Retry without type filter — keep everything then let normalizer filter
        result = ezdwg.to_dxf(
            str(source_path),
            str(intermediate_path),
            dxf_version=dxf_version,
            modelspace_only=True,
            flatten_inserts=explode_blocks,
            include_unsupported=True,
            strict=False,
        )
    return "ezdwg"


def convert_for_trimble(
    source_path: Path,
    output_path: Path,
    *,
    dxf_version: str = DEFAULT_DXF_VERSION,
    include_display_only: bool = False,
    explode_blocks: bool = True,
    convert_splines: bool = True,
    include_layers: list[str] | None = None,
    exclude_layers: list[str] | None = None,
    flatten_z: bool = False,
) -> dict:
    """
    Full pipeline: DWG/DXF → Trimble Access stakeout DXF.

    Returns a JSON-serializable summary including download basename.
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
        engine = dwg_to_dxf(
            source_path,
            intermediate,
            dxf_version=dxf_version,
            explode_blocks=explode_blocks,
        )
        dxf_source = intermediate
        messages.append(f"DWG decoded with {engine}.")
    else:
        raise ValueError("Only .dwg and .dxf files are supported.")

    # Sanity: ensure intermediate is readable
    try:
        ezdxf.readfile(str(dxf_source))
    except Exception as exc:
        raise RuntimeError(
            "Could not read drawing after conversion. "
            "If this is a Civil 3D DWG, run EXPORTTOAUTOCAD in Civil 3D first "
            f"so custom objects become standard AutoCAD entities. Detail: {exc}"
        ) from exc

    result = normalize_dxf(
        str(dxf_source),
        str(output_path),
        dxf_version=dxf_version,
        include_display_only=include_display_only,
        explode_blocks=explode_blocks,
        convert_splines=convert_splines,
        include_layers=include_layers,
        exclude_layers=exclude_layers,
        flatten_z=flatten_z,
    )

    # Clean intermediate raw dxf if different from output
    if dxf_source != source_path and dxf_source != output_path:
        try:
            Path(dxf_source).unlink(missing_ok=True)
        except OSError:
            pass

    payload = result_to_dict(result)
    payload["engine"] = engine
    payload["messages"] = messages + result.warnings
    payload["output_name"] = output_path.name
    payload["trimble_stakeable_types"] = sorted(TRIMBLE_STAKEABLE_TYPES)
    return payload


def copy_upload(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)
