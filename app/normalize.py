"""Normalize CAD drawings into Trimble Access–friendly DXF linework."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass, field
from typing import Iterable

import ezdxf
from ezdxf.document import Drawing
from ezdxf.entities import DXFEntity
from ezdxf.addons import Importer

from .config import (
    DEFAULT_DXF_VERSION,
    TRIMBLE_DISPLAY_ONLY_TYPES,
    TRIMBLE_STAKEABLE_TYPES,
)


@dataclass
class LayerStats:
    name: str
    entity_count: int
    stakeable_count: int
    types: dict[str, int]


@dataclass
class NormalizeResult:
    output_path: str
    dxf_version: str
    source_entity_count: int
    output_entity_count: int
    stakeable_count: int
    skipped_types: dict[str, int]
    layers: list[LayerStats]
    warnings: list[str] = field(default_factory=list)
    bbox: dict[str, float] | None = None
    proxy_carriers_exploded: int = 0
    proxy_primitives_created: int = 0


def _entity_type(entity: DXFEntity) -> str:
    return entity.dxftype().upper()


def analyze_document(doc: Drawing) -> tuple[Counter[str], list[LayerStats], int]:
    type_counts: Counter[str] = Counter()
    by_layer: dict[str, Counter[str]] = {}
    for entity in doc.modelspace():
        etype = _entity_type(entity)
        type_counts[etype] += 1
        layer = getattr(entity.dxf, "layer", "0") or "0"
        by_layer.setdefault(layer, Counter())[etype] += 1

    layers: list[LayerStats] = []
    for name, counts in sorted(by_layer.items(), key=lambda item: item[0].lower()):
        stakeable = sum(counts[t] for t in TRIMBLE_STAKEABLE_TYPES if t in counts)
        layers.append(
            LayerStats(
                name=name,
                entity_count=sum(counts.values()),
                stakeable_count=stakeable,
                types=dict(counts),
            )
        )
    return type_counts, layers, sum(type_counts.values())


def _explode_inserts(doc: Drawing) -> int:
    """Explode INSERT blocks into primitive geometry where possible."""
    exploded = 0
    msp = doc.modelspace()
    inserts = [e for e in msp if e.dxftype() == "INSERT"]
    for insert in inserts:
        try:
            for virtual in insert.virtual_entities():
                msp.add_entity(virtual.copy())
                exploded += 1
            msp.delete_entity(insert)
        except Exception:
            continue
    return exploded


def _approximate_splines(doc: Drawing) -> int:
    """Convert SPLINE entities to LWPOLYLINE so they can be staked."""
    converted = 0
    msp = doc.modelspace()
    splines = [e for e in msp if e.dxftype() == "SPLINE"]
    for spline in splines:
        try:
            points = list(spline.flattening(distance=0.1))
            if len(points) < 2:
                ctrl = list(spline.control_points)
                if len(ctrl) >= 2:
                    points = ctrl
            if len(points) < 2:
                continue
            coords = [(p.x, p.y, p.z) for p in points]
            msp.add_lwpolyline(
                coords,
                dxfattribs={
                    "layer": spline.dxf.layer,
                    "color": spline.dxf.color,
                },
            )
            msp.delete_entity(spline)
            converted += 1
        except Exception:
            continue
    return converted


def _sample_points(entity: DXFEntity) -> list[tuple[float, float, float]]:
    etype = entity.dxftype()
    if etype == "LINE":
        start, end = entity.dxf.start, entity.dxf.end
        return [(start.x, start.y, start.z), (end.x, end.y, end.z)]
    if etype == "POINT":
        loc = entity.dxf.location
        return [(loc.x, loc.y, loc.z)]
    if etype in {"CIRCLE", "ARC"}:
        center = entity.dxf.center
        return [(center.x, center.y, center.z)]
    if etype == "LWPOLYLINE":
        elevation = float(getattr(entity.dxf, "elevation", 0.0) or 0.0)
        return [(float(x), float(y), elevation) for x, y, *_ in entity.get_points("xy")]
    if etype == "POLYLINE":
        return [(v.dxf.location.x, v.dxf.location.y, v.dxf.location.z) for v in entity.vertices]
    if etype == "INSERT":
        loc = entity.dxf.insert
        return [(loc.x, loc.y, loc.z)]
    return []


def _compute_bbox(doc: Drawing) -> dict[str, float] | None:
    xs: list[float] = []
    ys: list[float] = []
    zs: list[float] = []
    for entity in doc.modelspace():
        try:
            for point in _sample_points(entity):
                xs.append(point[0])
                ys.append(point[1])
                zs.append(point[2])
        except Exception:
            continue
    if not xs:
        return None
    return {
        "min_x": min(xs),
        "min_y": min(ys),
        "min_z": min(zs),
        "max_x": max(xs),
        "max_y": max(ys),
        "max_z": max(zs),
    }


def _flatten_entity_z(entity: DXFEntity) -> None:
    etype = entity.dxftype()
    try:
        if etype == "LINE":
            entity.dxf.start = (entity.dxf.start.x, entity.dxf.start.y, 0)
            entity.dxf.end = (entity.dxf.end.x, entity.dxf.end.y, 0)
        elif etype == "POINT":
            loc = entity.dxf.location
            entity.dxf.location = (loc.x, loc.y, 0)
        elif etype in {"CIRCLE", "ARC"}:
            center = entity.dxf.center
            entity.dxf.center = (center.x, center.y, 0)
        elif etype == "LWPOLYLINE":
            entity.dxf.elevation = 0
        elif etype == "INSERT":
            insert = entity.dxf.insert
            entity.dxf.insert = (insert.x, insert.y, 0)
    except Exception:
        return


def normalize_dxf(
    source_path: str,
    output_path: str,
    *,
    dxf_version: str = DEFAULT_DXF_VERSION,
    include_display_only: bool = False,
    explode_blocks: bool = True,
    convert_splines: bool = True,
    explode_proxies: bool = True,
    include_layers: Iterable[str] | None = None,
    exclude_layers: Iterable[str] | None = None,
    flatten_z: bool = False,
) -> NormalizeResult:
    """
    Build an ASCII DXF containing only geometry Trimble Access can stake.

    Civil 3D AECC_* objects are recovered via embedded proxy graphics (no
    AutoCAD required) when the DWG was saved with PROXYGRAPHICS enabled.
    """
    from .proxy_explode import explode_proxy_graphics

    warnings: list[str] = []
    source_doc = ezdxf.readfile(source_path)
    type_counts, _, source_count = analyze_document(source_doc)

    # Work on a fresh copy so we can mutate safely
    working = ezdxf.readfile(source_path)

    proxy_exploded = 0
    proxy_primitives = 0
    if explode_proxies:
        proxy_stats = explode_proxy_graphics(working)
        proxy_exploded = proxy_stats.carriers_exploded
        proxy_primitives = proxy_stats.primitives_created
        warnings.extend(proxy_stats.messages)

    if convert_splines:
        converted = _approximate_splines(working)
        if converted:
            warnings.append(f"Converted {converted} SPLINE(s) to LWPOLYLINE for stakeout.")

    if explode_blocks:
        exploded = _explode_inserts(working)
        if exploded:
            warnings.append(
                f"Exploded block INSERT geometry into {exploded} primitive entity(ies)."
            )

    include_set = {name.lower() for name in include_layers} if include_layers else None
    exclude_set = {name.lower() for name in exclude_layers} if exclude_layers else set()

    allowed_types = set(TRIMBLE_STAKEABLE_TYPES)
    if include_display_only:
        allowed_types |= TRIMBLE_DISPLAY_ONLY_TYPES

    out = ezdxf.new(dxf_version)
    try:
        if "INSUNITS" in source_doc.header:
            out.header["$INSUNITS"] = source_doc.header["$INSUNITS"]
        if "MEASUREMENT" in source_doc.header:
            out.header["$MEASUREMENT"] = source_doc.header["$MEASUREMENT"]
    except Exception:
        pass

    importer = Importer(working, out)
    skipped: Counter[str] = Counter()

    for entity in list(working.modelspace()):
        etype = _entity_type(entity)
        layer = getattr(entity.dxf, "layer", "0") or "0"
        layer_key = layer.lower()

        if include_set is not None and layer_key not in include_set:
            skipped[etype] += 1
            continue
        if layer_key in exclude_set:
            skipped[etype] += 1
            continue
        if etype not in allowed_types:
            skipped[etype] += 1
            continue

        if flatten_z:
            _flatten_entity_z(entity)

        try:
            importer.import_entity(entity)
        except Exception:
            skipped[etype] += 1

    importer.finalize()

    out_type_counts, layers, out_count = analyze_document(out)
    stakeable = sum(
        out_type_counts[t] for t in TRIMBLE_STAKEABLE_TYPES if t in out_type_counts
    )

    if stakeable == 0:
        if proxy_exploded == 0:
            warnings.append(
                "No Trimble Access stakeable entities were found. "
                "If this is a Civil 3D DWG, ensure it was saved with PROXYGRAPHICS=1 "
                "so AECC objects embed recoverable linework (no AutoCAD needed here)."
            )
        else:
            warnings.append(
                "Proxy objects were exploded but no stakeable entity types remained "
                "after filtering. Check layer filters."
            )

    customish = {
        name: count
        for name, count in type_counts.items()
        if name not in TRIMBLE_STAKEABLE_TYPES | TRIMBLE_DISPLAY_ONLY_TYPES
        and name
        not in {
            "VIEWPORT",
            "REGION",
            "BODY",
            "3DSOLID",
            "IMAGE",
            "WIPEOUT",
            "ACAD_PROXY_ENTITY",
        }
    }
    if customish and proxy_exploded == 0:
        top = ", ".join(f"{name}×{count}" for name, count in sorted(customish.items())[:8])
        warnings.append(f"Skipped non-stakeable entity types: {top}")

    out.saveas(output_path)
    return NormalizeResult(
        output_path=output_path,
        dxf_version=dxf_version,
        source_entity_count=source_count,
        output_entity_count=out_count,
        stakeable_count=stakeable,
        skipped_types=dict(skipped),
        layers=layers,
        warnings=warnings,
        bbox=_compute_bbox(out),
        proxy_carriers_exploded=proxy_exploded,
        proxy_primitives_created=proxy_primitives,
    )


def result_to_dict(result: NormalizeResult) -> dict:
    return {
        "dxf_version": result.dxf_version,
        "source_entity_count": result.source_entity_count,
        "output_entity_count": result.output_entity_count,
        "stakeable_count": result.stakeable_count,
        "skipped_types": result.skipped_types,
        "layers": [
            {
                "name": layer.name,
                "entity_count": layer.entity_count,
                "stakeable_count": layer.stakeable_count,
                "types": layer.types,
            }
            for layer in result.layers
        ],
        "warnings": result.warnings,
        "bbox": result.bbox,
        "proxy_carriers_exploded": result.proxy_carriers_exploded,
        "proxy_primitives_created": result.proxy_primitives_created,
    }
