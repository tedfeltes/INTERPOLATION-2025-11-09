"""On-device Civil 3D linework recovery for StakeDXF Android.

Called from Kotlin after LibreDWG (or for DXF inputs directly).
Explodes ACAD_PROXY_ENTITY proxy graphics into stakeable LINE/ARC/POLYLINE.
Only layers that contain stakeable entities are kept in the output DXF.

Performance notes (v1.11+):
- Single DXF load (no double-read)
- In-place proxy explode + non-stakeable strip (Importer only when version coerce needed)
- Optional progress bridge for foreground-service notifications

Robustness notes (v1.25.1+):
- Never raise out of recover_linework — Kotlin maps uncaught Python
  exceptions to PlatformException(recover_failed, …) which aborts CONVERT.
- Monkeypatch ezdxf ProxyGraphic so corrupt LAYER/LTYPE/STYLE tables
  (LibreDWG + Civil 3D) cannot abort explode with
  AttributeError: 'str' object has no attribute 'dxf'.
"""

from __future__ import annotations

import json
import traceback
from collections import Counter
from typing import Any

import ezdxf
from ezdxf import recover as ezdxf_recover
from ezdxf.addons import Importer
from ezdxf.proxygraphic import ProxyGraphic, ProxyGraphicError
import ezdxf.proxygraphic as _ezdxf_proxygraphic


STAKEABLE = frozenset(
    {"ARC", "CIRCLE", "INSERT", "LINE", "POINT", "POLYLINE", "LWPOLYLINE"}
)

# Keep VERTEX/SEQEND with their parent POLYLINE during in-place strip.
_KEEP_IN_PLACE = STAKEABLE | {"VERTEX", "SEQEND"}

# R2010 / AC1024 — preferred for Trimble Access
_R2010 = frozenset({"R2010", "AC1024"})


def _patch_proxy_graphic() -> None:
    """Tolerate non-entity junk in doc.layers / linetypes / styles.

    Stock ezdxf ProxyGraphic.__init__ does::

        layer.dxf.name for layer in self._doc.layers

    After a Civil 3D → LibreDWG round-trip the layers table can yield a bare
    ``str``. That raises ``AttributeError: 'str' object has no attribute
    'dxf'`` and historically aborted the entire CONVERT at ~35%.

    Retry without a document binding — proxy binary still decodes to the
    same stakeable primitives (layer names fall back to \"0\" / BYLAYER).
    """
    orig = _ezdxf_proxygraphic.ProxyGraphic.__init__
    if getattr(orig, "_stakedxf_safe", False):
        return

    def _safe_init(self, data, doc=None, *, dxfversion=None, **kwargs):
        # ezdxf 1.4.x: dxfversion is keyword-only with default DXF2000.
        init_kwargs = dict(kwargs)
        if dxfversion is not None:
            init_kwargs["dxfversion"] = dxfversion
        try:
            return orig(self, data, doc, **init_kwargs)
        except AttributeError:
            # Partial construction is OK to overwrite — orig resets fields.
            fallback = {}
            if doc is not None and hasattr(doc, "dxfversion"):
                fallback["dxfversion"] = doc.dxfversion
            elif dxfversion is not None:
                fallback["dxfversion"] = dxfversion
            fallback.update(kwargs)
            return orig(self, data, None, **fallback)

    _safe_init._stakedxf_safe = True  # type: ignore[attr-defined]
    _ezdxf_proxygraphic.ProxyGraphic.__init__ = _safe_init  # type: ignore[method-assign]
    # Keep the name imported into this module in sync.
    global ProxyGraphic
    ProxyGraphic = _ezdxf_proxygraphic.ProxyGraphic


_patch_proxy_graphic()


def _safe_layer(entity) -> str | None:
    """Return the entity's layer name, tolerating malformed entities.

    Civil 3D DWGs occasionally round-trip through LibreDWG with stray table
    entries (or proxy-exploded children) that surface as bare strings inside
    ``doc.modelspace()`` / ``doc.layers``. A naïve ``getattr(entity.dxf,
    "layer", "0")`` still evaluates ``entity.dxf`` first — which raises
    ``AttributeError: 'str' object has no attribute 'dxf'`` and aborts the
    entire conversion. Guarded lookup lets us skip the offending entry
    instead of tearing down the whole recover flow.
    """
    dxf_ns = getattr(entity, "dxf", None)
    if dxf_ns is None:
        return None
    layer = getattr(dxf_ns, "layer", None)
    if not layer:
        return None
    return str(layer)


def _safe_dxftype(entity) -> str | None:
    fn = getattr(entity, "dxftype", None)
    if not callable(fn):
        return None
    try:
        return str(fn()).upper()
    except Exception:
        return None


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


def _load_dxf(path: str):
    """Load DXF; fall back to recover mode for LibreDWG oddities."""
    try:
        return ezdxf.readfile(path)
    except Exception:
        doc, _auditor = ezdxf_recover.readfile(path)
        return doc


def _fail(message: str, **extra: Any) -> dict:
    payload = {
        "ok": False,
        "stakeable_count": 0,
        "proxy_exploded": 0,
        "proxy_primitives": 0,
        "skipped": {},
        "empty_layers_removed": 0,
        "layers": [],
        "layers_json": "[]",
        "message": message,
        "error": message,
    }
    payload.update(extra)
    return payload


def _explode_proxies(doc, progress: Any = None) -> tuple[int, int]:
    msp = doc.modelspace()
    entities = list(msp)
    total = max(len(entities), 1)
    exploded = 0
    primitives = 0
    last_pct = -1

    for idx, entity in enumerate(entities):
        etype = _safe_dxftype(entity)
        if etype is None:
            # Malformed entry (e.g. a str leaked in by a broken proxy round-trip).
            try:
                msp.delete_entity(entity)
            except Exception:
                pass
            continue
        graphic = getattr(entity, "proxy_graphic", None)
        is_proxy = etype in {"ACAD_PROXY_ENTITY", "ACAD_PROXY_OBJECT"} or bool(
            graphic
        )
        # Civil 3D custom entities (ACDC_*) expose virtual_entities via proxy.
        is_acdc = etype.startswith("ACDC_") or etype.startswith("AECC_")
        if not is_proxy and not is_acdc and not hasattr(entity, "virtual_entities"):
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
            # Drop unrecoverable proxies so they cannot poison later save/import.
            if is_proxy or is_acdc:
                try:
                    msp.delete_entity(entity)
                except Exception:
                    pass
            continue

        layer = _safe_layer(entity)

        for item in virt:
            if _safe_dxftype(item) is None:
                continue
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
        etype = _safe_dxftype(entity)
        if etype is None:
            # Skip anything we can't classify — malformed entries silently drop.
            try:
                msp.delete_entity(entity)
            except Exception:
                pass
        elif etype in _KEEP_IN_PLACE:
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
    """Remove layer table entries that have no modelspace entities."""
    used: set[str] = set()
    for e in doc.modelspace():
        layer = _safe_layer(e)
        if layer:
            used.add(layer)
    removed = 0
    for layer in list(doc.layers):
        # Layer table entries can also be malformed after a LibreDWG roundtrip;
        # skip anything without a well-formed ``dxf.name`` instead of aborting.
        dxf_ns = getattr(layer, "dxf", None)
        name = getattr(dxf_ns, "name", None) if dxf_ns is not None else None
        if not isinstance(name, str) or not name:
            continue
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
        etype = _safe_dxftype(entity)
        if etype is None:
            skipped["_MALFORMED"] += 1
            continue
        if etype not in STAKEABLE:
            skipped[etype] += 1
            continue
        layer = (_safe_layer(entity) or "0").lower()
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

    Never raises — failures return ``ok: False`` so Kotlin does not surface
    PlatformException(recover_failed, …).
    """
    try:
        return _recover_linework_impl(input_path, output_path, progress)
    except Exception as exc:
        detail = f"{type(exc).__name__}: {exc}"
        _report(progress, "error", 100, f"Recovery failed: {detail}")
        return _fail(
            f"Recovery failed: {detail}",
            traceback=traceback.format_exc()[-1500:],
        )


def _recover_linework_impl(
    input_path: str,
    output_path: str,
    progress: Any = None,
) -> dict:
    _report(progress, "load", 5, "Loading DXF…")
    doc = _load_dxf(input_path)

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
        try:
            layers = _layer_stats(ezdxf.readfile(output_path))
        except Exception:
            layers = _layer_stats(doc)

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
    try:
        doc = _load_dxf(input_path)
        layers = _layer_stats(doc)
        return {
            "layers": layers,
            "layers_json": json.dumps(layers),
            "stakeable_count": sum(r["entity_count"] for r in layers),
            "ok": True,
        }
    except Exception as exc:
        return {
            "layers": [],
            "layers_json": "[]",
            "stakeable_count": 0,
            "ok": False,
            "error": f"{type(exc).__name__}: {exc}",
            "message": f"Layer list failed: {type(exc).__name__}: {exc}",
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

    try:
        source = _load_dxf(input_path)
    except Exception as exc:
        return _fail(f"DXF load failed: {type(exc).__name__}: {exc}")

    include_l = {n.lower() for n in include}
    msp = source.modelspace()
    # First pass: decide which POLYLINE parents stay, then keep their VERTEX/SEQEND.
    keep_poly = False
    for entity in list(msp):
        etype = _safe_dxftype(entity)
        if etype is None:
            try:
                msp.delete_entity(entity)
            except Exception:
                pass
            continue
        layer = (_safe_layer(entity) or "0").lower()
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
        if (_safe_dxftype(e) or "") in STAKEABLE
    )
    _purge_empty_layers(source)

    version = str(getattr(source, "dxfversion", "") or "")
    try:
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
    except Exception as exc:
        return _fail(f"DXF write failed: {type(exc).__name__}: {exc}")

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
