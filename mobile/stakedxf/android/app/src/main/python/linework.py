"""On-device Civil 3D linework recovery for StakeDXF Android.

Called from Kotlin after LibreDWG (or for DXF inputs directly).
Explodes ACAD_PROXY_ENTITY proxy graphics into stakeable LINE/ARC/POLYLINE.
Only layers that contain stakeable entities are kept in the output DXF.

Performance notes (v1.11+):
- Single DXF load (no double-read)
- In-place proxy explode + non-stakeable strip (Importer only when version coerce needed)
- Optional progress bridge for foreground-service notifications
"""

from __future__ import annotations

import json
from collections import Counter
from typing import Any

import ezdxf
from ezdxf.addons import Importer
from ezdxf.proxygraphic import ProxyGraphic, ProxyGraphicError


STAKEABLE = frozenset(
    {"ARC", "CIRCLE", "INSERT", "LINE", "POINT", "POLYLINE", "LWPOLYLINE"}
)

# Keep VERTEX/SEQEND with their parent POLYLINE during in-place strip.
_KEEP_IN_PLACE = STAKEABLE | {"VERTEX", "SEQEND"}

# R2010 / AC1024 — preferred for Trimble Access
_R2010 = frozenset({"R2010", "AC1024"})


def _report(progress: Any, stage: str, percent: int, message: str) -> None:
    if progress is None:
        return
    try:
        # Kotlin ProgressBridge.on_progress(stage, percent, message)
        progress.on_progress(stage, int(percent), message)
    except Exception:
        try:
            progress(stage, int(percent), message)
        except Exception:
            pass


def _explode_proxies(doc, progress: Any = None) -> tuple[int, int]:
    msp = doc.modelspace()
    entities = list(msp)
    total = max(len(entities), 1)
    exploded = 0
    primitives = 0
    last_pct = -1

    for idx, entity in enumerate(entities):
        etype = entity.dxftype().upper()
        graphic = getattr(entity, "proxy_graphic", None)
        is_proxy = etype in {"ACAD_PROXY_ENTITY", "ACAD_PROXY_OBJECT"} or bool(graphic)
        if not is_proxy and not hasattr(entity, "virtual_entities"):
            continue
        if etype in STAKEABLE:
            continue

        virt = []
        try:
            if hasattr(entity, "virtual_entities"):
                virt = list(entity.virtual_entities())
        except Exception:
            virt = []
        if not virt and graphic:
            try:
                virt = list(ProxyGraphic(graphic, doc).virtual_entities())
            except (ProxyGraphicError, Exception):
                virt = []
        if not virt:
            continue

        layer = None
        try:
            if hasattr(entity.dxf, "layer"):
                layer = entity.dxf.layer
        except Exception:
            layer = None

        for item in virt:
            try:
                clone = item.copy()
            except Exception:
                clone = item
            if layer is not None:
                try:
                    clone.dxf.layer = layer
                except Exception:
                    pass
            try:
                msp.add_entity(clone)
                primitives += 1
            except Exception:
                pass
        try:
            msp.delete_entity(entity)
            exploded += 1
        except Exception:
            pass

        pct = 15 + int(40 * (idx + 1) / total)
        if pct != last_pct and (pct - last_pct >= 2 or idx + 1 == total):
            last_pct = pct
            _report(
                progress,
                "explode",
                pct,
                f"Exploding Civil 3D proxies… ({exploded} done)",
            )

    return exploded, primitives


def _strip_non_stakeable(doc, progress: Any = None) -> tuple[int, Counter]:
    """Delete non-stakeable modelspace entities in place (fast path)."""
    msp = doc.modelspace()
    entities = list(msp)
    total = max(len(entities), 1)
    kept = 0
    skipped: Counter[str] = Counter()
    last_pct = -1

    for idx, entity in enumerate(entities):
        etype = entity.dxftype().upper()
        if etype in _KEEP_IN_PLACE:
            if etype in STAKEABLE:
                kept += 1
        else:
            skipped[etype] += 1
            try:
                msp.delete_entity(entity)
            except Exception:
                pass
        pct = 55 + int(25 * (idx + 1) / total)
        if pct != last_pct and (pct - last_pct >= 3 or idx + 1 == total):
            last_pct = pct
            _report(progress, "filter", pct, "Keeping stakeable entities…")

    return kept, skipped


def _layer_stats(doc) -> list[dict]:
    counts: Counter[str] = Counter()
    types: dict[str, Counter[str]] = {}
    for entity in doc.modelspace():
        etype = entity.dxftype().upper()
        if etype not in STAKEABLE:
            continue
        layer = getattr(entity.dxf, "layer", "0") or "0"
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
    """Remove layer table entries that have no modelspace entities."""
    used = {getattr(e.dxf, "layer", "0") or "0" for e in doc.modelspace()}
    removed = 0
    for layer in list(doc.layers):
        name = layer.dxf.name
        if name in used:
            continue
        if name.upper() == "0":
            continue
        try:
            doc.layers.remove(name)
            removed += 1
        except Exception:
            pass
    return removed


def _import_stakeable(working, out, include_layers: set[str] | None = None) -> tuple[int, Counter]:
    importer = Importer(working, out)
    kept = 0
    skipped: Counter[str] = Counter()
    include_l = {n.lower() for n in include_layers} if include_layers is not None else None
    for entity in list(working.modelspace()):
        etype = entity.dxftype().upper()
        if etype not in STAKEABLE:
            skipped[etype] += 1
            continue
        layer = (getattr(entity.dxf, "layer", "0") or "0").lower()
        if include_l is not None and layer not in include_l:
            skipped[etype] += 1
            continue
        try:
            importer.import_entity(entity)
            kept += 1
        except Exception:
            skipped[etype] += 1
    importer.finalize()
    return kept, skipped


def _copy_units(source, out) -> None:
    try:
        if "INSUNITS" in source.header:
            out.header["$INSUNITS"] = source.header["$INSUNITS"]
    except Exception:
        pass


def _save_trimble(doc, output_path: str, progress: Any = None) -> int | None:
    """
    Save as R2010 Trimble-friendly DXF.

    Fast path: in-place save when already R2010 after strip (returns None —
    caller keeps its entity count). Slow path: Importer rebuild into a new
    R2010 doc (returns imported count).
    """
    version = str(getattr(doc, "dxfversion", "") or "")
    if version.upper() in _R2010 or version in _R2010:
        _report(progress, "write", 90, "Writing Trimble DXF…")
        doc.saveas(output_path)
        return None

    _report(progress, "write", 88, "Normalizing to R2010 DXF…")
    out = ezdxf.new("R2010")
    _copy_units(doc, out)
    kept, _ = _import_stakeable(doc, out)
    _purge_empty_layers(out)
    out.saveas(output_path)
    return kept


def recover_linework(
    input_path: str,
    output_path: str,
    progress: Any = None,
) -> dict:
    """
    Recover Civil 3D / AEC linework into a Trimble-stakeable DXF.

    Empty layers are omitted. Returns layer stats for the UI checklist.
    [progress] may be a Kotlin bridge with on_progress(stage, percent, message).
    """
    _report(progress, "load", 5, "Loading DXF…")
    doc = ezdxf.readfile(input_path)  # single load

    _report(progress, "explode", 15, "Exploding Civil 3D proxies…")
    exploded, primitives = _explode_proxies(doc, progress)

    _report(progress, "filter", 55, "Keeping stakeable entities…")
    kept, skipped = _strip_non_stakeable(doc, progress)

    _report(progress, "purge", 82, "Purging empty layers…")
    purged = _purge_empty_layers(doc)
    layers = _layer_stats(doc)

    imported = _save_trimble(doc, output_path, progress)
    if imported is not None:
        kept = imported

    _report(progress, "done", 100, "Conversion complete")

    return {
        "stakeable_count": kept,
        "proxy_exploded": exploded,
        "proxy_primitives": primitives,
        "skipped": dict(skipped),
        "empty_layers_removed": purged,
        "layers": layers,
        "layers_json": json.dumps(layers),
        "ok": kept > 0,
        "message": (
            f"Recovered {kept} stakeable entities on {len(layers)} layer(s)"
            + (
                f" (exploded {exploded} Civil 3D proxies → {primitives} primitives)"
                if exploded
                else ""
            )
            if kept > 0
            else "No stakeable linework found — drawing may lack proxy graphics"
        ),
    }


def list_layers(input_path: str) -> dict:
    """Return non-empty stakeable layer stats for an existing DXF."""
    doc = ezdxf.readfile(input_path)
    layers = _layer_stats(doc)
    return {
        "layers": layers,
        "layers_json": json.dumps(layers),
        "stakeable_count": sum(r["entity_count"] for r in layers),
    }


def filter_layers(input_path: str, output_path: str, layers_json: str) -> dict:
    """Rewrite DXF keeping only the named layers (must be non-empty after filter)."""
    try:
        selected = json.loads(layers_json)
    except Exception:
        selected = []
    if isinstance(selected, dict):
        selected = list(selected.keys())
    include = {str(name) for name in selected if str(name).strip()}
    if not include:
        return {
            "ok": False,
            "stakeable_count": 0,
            "layers": [],
            "layers_json": "[]",
            "message": "Select at least one layer",
        }

    source = ezdxf.readfile(input_path)
    include_l = {n.lower() for n in include}
    msp = source.modelspace()
    # First pass: decide which POLYLINE parents stay, then keep their VERTEX/SEQEND.
    keep_poly = False
    for entity in list(msp):
        etype = entity.dxftype().upper()
        layer = (getattr(entity.dxf, "layer", "0") or "0").lower()
        if etype == "POLYLINE":
            keep_poly = etype in STAKEABLE and layer in include_l
            if not keep_poly:
                try:
                    msp.delete_entity(entity)
                except Exception:
                    pass
            continue
        if etype in {"VERTEX", "SEQEND"}:
            if not keep_poly:
                try:
                    msp.delete_entity(entity)
                except Exception:
                    pass
            if etype == "SEQEND":
                keep_poly = False
            continue
        if etype not in STAKEABLE or layer not in include_l:
            try:
                msp.delete_entity(entity)
            except Exception:
                pass

    kept = sum(
        1
        for e in source.modelspace()
        if e.dxftype().upper() in STAKEABLE
    )
    _purge_empty_layers(source)

    version = str(getattr(source, "dxfversion", "") or "")
    if version.upper() in _R2010 or version in _R2010:
        source.saveas(output_path)
        layers = _layer_stats(source)
    else:
        out = ezdxf.new("R2010")
        _copy_units(source, out)
        kept, _ = _import_stakeable(source, out, include_layers=include)
        _purge_empty_layers(out)
        out.saveas(output_path)
        layers = _layer_stats(out)

    return {
        "ok": kept > 0,
        "stakeable_count": kept,
        "layers": layers,
        "layers_json": json.dumps(layers),
        "message": (
            f"Exported {kept} entities on {len(layers)} selected layer(s)"
            if kept > 0
            else "No entities on the selected layers"
        ),
    }
