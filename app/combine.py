"""Combine multiple project DWG/DXF files into one base drawing.

Desktop/CLI counterpart to the on-device Android ``combine_base_drawings``
pipeline. Each input is converted for Trimble (Civil 3D proxy explode +
stakeable filter), then entities are merged into a single R2010 DXF. Empty
layer table entries are purged so the base only lists layers with data.
"""

from __future__ import annotations

import json
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any

import ezdxf
from ezdxf.addons import Importer

from .config import DEFAULT_DXF_VERSION, TRIMBLE_STAKEABLE_TYPES
from .converter import convert_for_trimble


STAKEABLE = frozenset(TRIMBLE_STAKEABLE_TYPES)


def _safe_dxftype(entity) -> str | None:
    fn = getattr(entity, "dxftype", None)
    if not callable(fn):
        return None
    try:
        return str(fn()).upper()
    except Exception:
        return None


def _safe_layer(entity) -> str | None:
    dxf_ns = getattr(entity, "dxf", None)
    if dxf_ns is None:
        return None
    layer = getattr(dxf_ns, "layer", None)
    if not layer:
        return None
    return str(layer)


def _layer_stats(doc) -> list[dict]:
    counts: Counter[str] = Counter()
    types: dict[str, Counter[str]] = {}
    for entity in doc.modelspace():
        etype = _safe_dxftype(entity)
        if etype is None or etype not in STAKEABLE:
            continue
        layer = _safe_layer(entity) or "0"
        counts[layer] += 1
        types.setdefault(layer, Counter())[etype] += 1
    rows = []
    for name, count in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0].lower())):
        rows.append(
            {
                "name": name,
                "entity_count": int(count),
                "types": dict(types[name]),
            }
        )
    return rows


def _purge_empty_layers(doc) -> int:
    used: set[str] = set()
    for e in doc.modelspace():
        layer = _safe_layer(e)
        if layer:
            used.add(layer)
    removed = 0
    for layer in list(doc.layers):
        dxf_ns = getattr(layer, "dxf", None)
        name = getattr(dxf_ns, "name", None) if dxf_ns is not None else None
        if not isinstance(name, str) or not name:
            continue
        if name in used or name.upper() == "0":
            continue
        try:
            doc.layers.remove(name)
            removed += 1
        except Exception:
            pass
    return removed


def _import_stakeable(working, out) -> int:
    importer = Importer(working, out)
    kept = 0
    for entity in list(working.modelspace()):
        etype = _safe_dxftype(entity)
        if etype is None or etype not in STAKEABLE:
            continue
        try:
            importer.import_entity(entity)
            kept += 1
        except Exception:
            pass
    importer.finalize()
    return kept


def combine_for_base(
    inputs: list[Path | str],
    output: Path | str,
    *,
    dxf_version: str = DEFAULT_DXF_VERSION,
    prefer_engine: str | None = None,
) -> dict[str, Any]:
    """Convert each input, merge stakeable entities, purge empty layers."""
    paths = [Path(p) for p in inputs]
    if len(paths) < 2:
        raise ValueError("Select at least two project drawings to build a base")
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(path)

    out_path = Path(output)
    out = ezdxf.new(dxf_version if dxf_version else DEFAULT_DXF_VERSION)
    total_kept = 0
    sources: list[dict] = []
    messages: list[str] = []
    units_copied = False

    with tempfile.TemporaryDirectory(prefix="stakedxf_base_") as tmp:
        tmp_dir = Path(tmp)
        for idx, path in enumerate(paths):
            part_out = tmp_dir / f"part_{idx:02d}_{path.stem}.dxf"
            payload = convert_for_trimble(
                path,
                part_out,
                dxf_version=dxf_version,
                prefer_engine=prefer_engine,
            )
            messages.extend(payload.get("messages") or [])
            part_doc = ezdxf.readfile(part_out)
            if not units_copied:
                try:
                    if "INSUNITS" in part_doc.header:
                        out.header["$INSUNITS"] = part_doc.header["$INSUNITS"]
                        units_copied = True
                except Exception:
                    pass
            imported = _import_stakeable(part_doc, out)
            total_kept += imported
            sources.append(
                {
                    "path": str(path),
                    "name": path.name,
                    "stakeable_count": imported,
                    "ok": imported > 0,
                }
            )

    purged = _purge_empty_layers(out)
    layers = _layer_stats(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out.saveas(out_path)

    merged = sum(1 for s in sources if s.get("ok"))
    ok = total_kept > 0 and len(layers) > 0
    message = (
        f"Base drawing: {total_kept} entities on {len(layers)} layer(s) "
        f"from {merged}/{len(paths)} files"
        if ok
        else "No stakeable linework found across the selected drawings"
    )
    messages.append(message)
    return {
        "ok": ok,
        "output": str(out_path),
        "stakeable_count": total_kept,
        "empty_layers_removed": purged,
        "source_count": len(paths),
        "sources_merged": merged,
        "sources": sources,
        "layers": layers,
        "layers_json": json.dumps(layers),
        "message": message,
        "messages": messages,
    }
