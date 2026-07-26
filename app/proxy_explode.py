"""Explode Civil 3D / AEC proxy graphics into stakeable AutoCAD primitives.

Civil 3D AECC_* objects cannot be decoded without Autodesk ObjectARX.
When PROXYGRAPHICS=1 at save time (Civil 3D default for many deliverables),
the DWG embeds a binary "proxy graphic" metafile — the last displayed
geometry. ezdxf can turn that metafile into LINE / POLYLINE / ARC / etc.

This is the field workaround that avoids requiring AutoCAD on the collector:
DWG (with proxy graphics) → DXF (preserving ACAD_PROXY_ENTITY) → explode → stake.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ezdxf.document import Drawing
from ezdxf.entities import DXFEntity
from ezdxf.proxygraphic import ProxyGraphic, ProxyGraphicError


# Entity types we treat as "custom / proxy carriers"
PROXY_CARRIER_TYPES = frozenset(
    {
        "ACAD_PROXY_ENTITY",
        "ACAD_PROXY_OBJECT",
    }
)


@dataclass
class ProxyExplodeStats:
    carriers_seen: int = 0
    carriers_exploded: int = 0
    primitives_created: int = 0
    carriers_empty: int = 0
    errors: int = 0
    class_names: dict[str, int] = field(default_factory=dict)
    messages: list[str] = field(default_factory=list)


def _proxy_class_hint(entity: DXFEntity) -> str:
    """Best-effort class name from XDATA / reactives (e.g. AEC_DOOR, AECC_*)."""
    try:
        xdata = entity.get_xdata("ACAD")
        if xdata:
            values = [tag.value for tag in xdata if isinstance(tag.value, str)]
            for value in reversed(values):
                upper = value.upper()
                if upper.startswith(("AEC", "AECC", "ACAD_")) or "_" in value:
                    return value
    except Exception:
        pass
    return entity.dxftype()


def _has_proxy_graphic(entity: DXFEntity) -> bool:
    graphic = getattr(entity, "proxy_graphic", None)
    return bool(graphic)


def _iter_virtual_from_proxy(entity: DXFEntity, doc: Drawing) -> list[DXFEntity]:
    """Yield exploded primitives from a proxy carrier."""
    entities: list[DXFEntity] = []

    # Preferred: entity.virtual_entities() (ACAD_PROXY_ENTITY, DXFTagStorage, …)
    virtual = getattr(entity, "virtual_entities", None)
    if callable(virtual):
        try:
            entities = list(virtual())
            if entities:
                return entities
        except Exception:
            pass

    # Fallback: decode raw proxy_graphic bytes
    graphic = getattr(entity, "proxy_graphic", None)
    if graphic:
        try:
            entities = list(ProxyGraphic(graphic, doc).virtual_entities())
        except ProxyGraphicError:
            return []
        except Exception:
            return []
    return entities


def _copy_attribs(source: DXFEntity, target: DXFEntity) -> None:
    """Preserve layer / color when proxy primitives lack them."""
    try:
        if not getattr(target.dxf, "layer", None) or target.dxf.layer == "0":
            if hasattr(source.dxf, "layer"):
                target.dxf.layer = source.dxf.layer
        if getattr(target.dxf, "color", 256) == 256 and hasattr(source.dxf, "color"):
            # Keep ByLayer unless source has an explicit color
            if source.dxf.color not in (256, 0):
                target.dxf.color = source.dxf.color
    except Exception:
        return


def explode_proxy_graphics(doc: Drawing) -> ProxyExplodeStats:
    """
    Replace Civil 3D / AEC proxy carriers in modelspace with stakeable geometry.

    Also attempts virtual_entities() on any modelspace entity that carries
    proxy_graphic bytes but is not a standard stakeable type (covers some
    LibreDWG / ODA outputs that store custom objects as DXFTagStorage).
    """
    from .config import TRIMBLE_STAKEABLE_TYPES, TRIMBLE_DISPLAY_ONLY_TYPES

    stats = ProxyExplodeStats()
    msp = doc.modelspace()
    known = TRIMBLE_STAKEABLE_TYPES | TRIMBLE_DISPLAY_ONLY_TYPES | {
        "VIEWPORT",
        "IMAGE",
        "WIPEOUT",
        "UNDERLAY",
        "PDFUNDERLAY",
        "DGNUNDERLAY",
        "DWFUNDERLAY",
    }

    candidates = []
    for entity in list(msp):
        etype = entity.dxftype().upper()
        if etype in PROXY_CARRIER_TYPES or _has_proxy_graphic(entity):
            candidates.append(entity)
        elif etype not in known and hasattr(entity, "virtual_entities"):
            # Unsupported custom object that might still expose virtual geometry
            candidates.append(entity)

    for entity in candidates:
        stats.carriers_seen += 1
        hint = _proxy_class_hint(entity)
        stats.class_names[hint] = stats.class_names.get(hint, 0) + 1

        try:
            primitives = _iter_virtual_from_proxy(entity, doc)
        except Exception:
            stats.errors += 1
            continue

        if not primitives:
            stats.carriers_empty += 1
            continue

        for primitive in primitives:
            try:
                clone = primitive.copy()
            except Exception:
                # Some virtual entities are already detached copies
                clone = primitive
            _copy_attribs(entity, clone)
            try:
                msp.add_entity(clone)
                stats.primitives_created += 1
            except Exception:
                stats.errors += 1

        try:
            msp.delete_entity(entity)
            stats.carriers_exploded += 1
        except Exception:
            stats.errors += 1

    if stats.carriers_exploded:
        top = ", ".join(
            f"{name}×{count}"
            for name, count in sorted(stats.class_names.items(), key=lambda i: -i[1])[:8]
        )
        stats.messages.append(
            f"Exploded {stats.carriers_exploded} Civil 3D/AEC proxy object(s) "
            f"into {stats.primitives_created} stakeable primitive(s) ({top})."
        )
    elif stats.carriers_seen and stats.carriers_empty:
        stats.messages.append(
            f"Found {stats.carriers_seen} proxy object(s) but no embedded graphics. "
            "The DWG was likely saved with PROXYGRAPHICS=0. Ask the office to "
            "re-save with PROXYGRAPHICS=1 — AutoCAD is not required on the collector."
        )

    return stats
