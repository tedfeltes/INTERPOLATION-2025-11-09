"""On-device Civil 3D linework recovery for StakeDXF Android.

Called from Kotlin after LibreDWG (or for DXF inputs directly).
Explodes ACAD_PROXY_ENTITY proxy graphics into stakeable LINE/ARC/POLYLINE.
"""

from __future__ import annotations

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


def recover_linework(input_path: str, output_path: str) -> dict:
    """
    Recover Civil 3D / AEC linework into a Trimble-stakeable DXF.

    Returns counts for the UI.
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

    importer = Importer(working, out)
    kept = 0
    skipped: Counter[str] = Counter()
    for entity in list(working.modelspace()):
        etype = entity.dxftype().upper()
        if etype not in STAKEABLE:
            skipped[etype] += 1
            continue
        try:
            importer.import_entity(entity)
            kept += 1
        except Exception:
            skipped[etype] += 1
    importer.finalize()
    out.saveas(output_path)

    return {
        "stakeable_count": kept,
        "proxy_exploded": exploded,
        "proxy_primitives": primitives,
        "skipped": dict(skipped),
        "ok": kept > 0,
        "message": (
            f"Recovered {kept} stakeable entities"
            + (f" (exploded {exploded} Civil 3D proxies → {primitives} primitives)" if exploded else "")
            if kept > 0
            else "No stakeable linework found — drawing may lack proxy graphics"
        ),
    }
