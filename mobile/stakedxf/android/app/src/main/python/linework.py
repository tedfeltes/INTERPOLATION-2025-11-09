"""On-device Civil 3D linework recovery for StakeDXF Android.

Called from Kotlin after LibreDWG (or for DXF inputs directly).
Explodes ACAD_PROXY_ENTITY proxy graphics into stakeable LINE/ARC/POLYLINE.
Only layers that contain stakeable entities are kept in the output DXF.
"""

from __future__ import annotations

import json
from collections import Counter

import ezdxf
from ezdxf.addons import Importer
from ezdxf.proxygraphic import ProxyGraphic, ProxyGraphicError


STAKEABLE = frozenset(
    {"ARC", "CIRCLE", "INSERT", "LINE", "POINT", "POLYLINE", "LWPOLYLINE"}
)


def _explode_proxies(doc) -> tuple[int, int]:
    msp = doc.modelspace()
    exploded = 0
    primitives = 0
    for entity in list(msp):
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

        for item in virt:
            try:
                clone = item.copy()
            except Exception:
                clone = item
            try:
                if hasattr(entity.dxf, "layer"):
                    clone.dxf.layer = entity.dxf.layer
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
    return exploded, primitives


def _layer_stats(doc) -> list[dict]:
    counts: Counter[str] = Counter()
    types: dict[str, Counter[str]] = {}
    for entity in doc.modelspace():
        layer = getattr(entity.dxf, "layer", "0") or "0"
        etype = entity.dxftype().upper()
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
        if name.upper() in {"0", "DEFPOINTS"}:
            # Keep 0 always; drop Defpoints if unused
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


def recover_linework(input_path: str, output_path: str) -> dict:
    """
    Recover Civil 3D / AEC linework into a Trimble-stakeable DXF.

    Empty layers are omitted. Returns layer stats for the UI checklist.
    """
    source = ezdxf.readfile(input_path)
    working = ezdxf.readfile(input_path)
    exploded, primitives = _explode_proxies(working)

    out = ezdxf.new("R2010")
    try:
        if "INSUNITS" in source.header:
            out.header["$INSUNITS"] = source.header["$INSUNITS"]
    except Exception:
        pass

    kept, skipped = _import_stakeable(working, out)
    purged = _purge_empty_layers(out)
    out.saveas(output_path)
    layers = _layer_stats(out)

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
    out = ezdxf.new("R2010")
    try:
        if "INSUNITS" in source.header:
            out.header["$INSUNITS"] = source.header["$INSUNITS"]
    except Exception:
        pass

    kept, skipped = _import_stakeable(source, out, include_layers=include)
    _purge_empty_layers(out)
    out.saveas(output_path)
    layers = _layer_stats(out)
    return {
        "ok": kept > 0,
        "stakeable_count": kept,
        "skipped": dict(skipped),
        "layers": layers,
        "layers_json": json.dumps(layers),
        "message": (
            f"Exported {kept} entities on {len(layers)} selected layer(s)"
            if kept > 0
            else "No entities on the selected layers"
        ),
    }
