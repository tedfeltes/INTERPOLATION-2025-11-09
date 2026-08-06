#!/usr/bin/env python3
"""Convert a Civil 3D plotted PDF exhibit to Trimble-stakeable DXF linework.

Coordinates are local engineering feet (north-up), scaled from the sheet
plot scale. They are NOT state-plane / GPS coordinates unless the source
PDF is georeferenced with GPTS (this exhibit is not).
"""

from __future__ import annotations

import argparse
import math
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path

import ezdxf
import fitz
from ezdxf.enums import TextEntityAlignment

# Sheet scale from PDF Measure dictionary / title block: 1" = 150'
FT_PER_INCH = 150.0
FT_PER_PT = FT_PER_INCH / 72.0

# Color (RGB 0-1 rounded) → (layer name, ACI color)
COLOR_LAYERS: dict[tuple[float, float, float], tuple[str, int]] = {
    (0.0, 1.0, 1.0): ("CLEARING_LIMITS", 4),  # cyan – tree clearing limits
    (1.0, 0.0, 1.0): ("SANITARY_CLEAR_ZONE", 6),  # magenta – clear along sanitary
    (0.0, 0.502, 1.0): ("WETLANDS", 5),  # blue
    (1.0, 0.0, 0.0): ("WETLAND_EXPANSION", 1),  # red – potential wetland pockets
    (0.2, 0.8, 0.0): ("BUFFER_BORING", 3),  # green – buffer / sanitary boring
    (0.498, 0.0, 1.0): ("LANDSCAPE_POND", 6),  # purple – existing landscape ponds
    (0.0, 0.0, 0.0): ("SITE_BASE", 7),  # black – roads, RR, lot lines
    (0.459, 0.459, 0.459): ("EXISTING_DETAIL", 8),  # gray detail
    (0.592, 0.592, 0.592): ("EXISTING_DETAIL", 8),
    (0.863, 0.863, 0.863): ("HATCH_FILL", 9),
    (0.945, 0.945, 0.945): ("HATCH_FILL", 9),
}

DEFAULT_LAYER = ("OTHER_LINEWORK", 7)


@dataclass
class Seg:
    x1: float
    y1: float
    x2: float
    y2: float


def _round_color(c: tuple[float, ...] | None) -> tuple[float, float, float] | None:
    if not c or len(c) < 3:
        return None
    return (round(c[0], 3), round(c[1], 3), round(c[2], 3))


def _layer_for(color: tuple[float, float, float] | None) -> tuple[str, int]:
    if color is None:
        return DEFAULT_LAYER
    return COLOR_LAYERS.get(color, DEFAULT_LAYER)


def media_to_display(page: fitz.Page, x: float, y: float) -> tuple[float, float]:
    p = fitz.Point(x, y) * page.rotation_matrix
    return float(p.x), float(p.y)


def display_to_feet(
    dx: float,
    dy: float,
    origin_x: float,
    origin_y: float,
    page_height: float,
) -> tuple[float, float]:
    """PDF display (y down) → local CAD feet (y north / up)."""
    east = (dx - origin_x) * FT_PER_PT
    north = (page_height - dy - origin_y) * FT_PER_PT
    return east, north


def _dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return math.hypot(a[0] - b[0], a[1] - b[1])


def _key(pt: tuple[float, float], tol: float) -> tuple[int, int]:
    return (int(round(pt[0] / tol)), int(round(pt[1] / tol)))


def merge_segments(segs: list[Seg], tol: float = 0.05) -> list[list[tuple[float, float]]]:
    """Chain segments into polylines via endpoint hashing (feet space)."""
    if not segs:
        return []

    # endpoint key → list of (seg_index, end: 0|1)
    index: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
    used = [False] * len(segs)
    ends: list[tuple[tuple[float, float], tuple[float, float]]] = []
    for i, s in enumerate(segs):
        a, b = (s.x1, s.y1), (s.x2, s.y2)
        ends.append((a, b))
        index[_key(a, tol)].append((i, 0))
        index[_key(b, tol)].append((i, 1))

    def take_next(pt: tuple[float, float]) -> tuple[int, tuple[float, float]] | None:
        for k in (
            _key(pt, tol),
            ( _key(pt, tol)[0] - 1, _key(pt, tol)[1] ),
            ( _key(pt, tol)[0] + 1, _key(pt, tol)[1] ),
            ( _key(pt, tol)[0], _key(pt, tol)[1] - 1 ),
            ( _key(pt, tol)[0], _key(pt, tol)[1] + 1 ),
        ):
            for seg_i, end_i in index.get(k, []):
                if used[seg_i]:
                    continue
                a, b = ends[seg_i]
                if end_i == 0 and _dist(pt, a) <= tol:
                    used[seg_i] = True
                    return seg_i, b
                if end_i == 1 and _dist(pt, b) <= tol:
                    used[seg_i] = True
                    return seg_i, a
        return None

    polys: list[list[tuple[float, float]]] = []
    for i, s in enumerate(segs):
        if used[i]:
            continue
        used[i] = True
        a, b = ends[i]
        chain = [a, b]
        # extend forward
        while True:
            nxt = take_next(chain[-1])
            if nxt is None:
                break
            chain.append(nxt[1])
        # extend backward
        while True:
            nxt = take_next(chain[0])
            if nxt is None:
                break
            chain.insert(0, nxt[1])
        cleaned = [chain[0]]
        for pt in chain[1:]:
            if _dist(cleaned[-1], pt) > 1e-6:
                cleaned.append(pt)
        if len(cleaned) >= 2:
            polys.append(cleaned)
    return polys


def extract_paths(
    page: fitz.Page,
    *,
    skip_hatch: bool,
    title_block_max_display_x: float | None,
) -> tuple[dict[str, list[Seg]], dict[str, int], tuple[float, float, float]]:
    page_height = float(page.rect.height)
    raw: dict[str, list[tuple[float, float, float, float]]] = defaultdict(list)
    layer_aci: dict[str, int] = {}

    for d in page.get_drawings():
        color = _round_color(d.get("color")) or _round_color(d.get("fill"))
        layer, aci = _layer_for(color)
        if skip_hatch and layer == "HATCH_FILL":
            continue
        layer_aci[layer] = aci

        for it in d.get("items", []):
            op = it[0]
            pts: list[tuple[float, float]] = []
            if op == "l":
                p1, p2 = it[1], it[2]
                pts = [(p1.x, p1.y), (p2.x, p2.y)]
            elif op == "c":
                p1, p2, p3, p4 = it[1], it[2], it[3], it[4]
                for t in [i / 8 for i in range(9)]:
                    mt = 1 - t
                    x = (
                        mt**3 * p1.x
                        + 3 * mt**2 * t * p2.x
                        + 3 * mt * t**2 * p3.x
                        + t**3 * p4.x
                    )
                    y = (
                        mt**3 * p1.y
                        + 3 * mt**2 * t * p2.y
                        + 3 * mt * t**2 * p3.y
                        + t**3 * p4.y
                    )
                    pts.append((x, y))
            elif op == "qu":
                q = it[1]
                pts = [
                    (q.ul.x, q.ul.y),
                    (q.ur.x, q.ur.y),
                    (q.lr.x, q.lr.y),
                    (q.ll.x, q.ll.y),
                    (q.ul.x, q.ul.y),
                ]
            elif op == "re":
                rect = it[1]
                pts = [
                    (rect.x0, rect.y0),
                    (rect.x1, rect.y0),
                    (rect.x1, rect.y1),
                    (rect.x0, rect.y1),
                    (rect.x0, rect.y0),
                ]
            else:
                continue

            dpts = [media_to_display(page, x, y) for x, y in pts]
            if title_block_max_display_x is not None:
                if all(x >= title_block_max_display_x for x, _ in dpts):
                    continue

            for a, b in zip(dpts, dpts[1:]):
                if _dist(a, b) < 1e-9:
                    continue
                raw[layer].append((a[0], a[1], b[0], b[1]))

    all_x = [s[0] for segs in raw.values() for s in segs] + [
        s[2] for segs in raw.values() for s in segs
    ]
    all_y = [s[1] for segs in raw.values() for s in segs] + [
        s[3] for segs in raw.values() for s in segs
    ]
    if not all_x:
        raise RuntimeError("No vector linework found in PDF")

    min_x, max_y = min(all_x), max(all_y)
    origin_x = min_x
    origin_y = page_height - max_y

    by_layer: dict[str, list[Seg]] = {}
    for layer, segs in raw.items():
        out: list[Seg] = []
        for x1, y1, x2, y2 in segs:
            e1, n1 = display_to_feet(x1, y1, origin_x, origin_y, page_height)
            e2, n2 = display_to_feet(x2, y2, origin_x, origin_y, page_height)
            out.append(Seg(e1, n1, e2, n2))
        by_layer[layer] = out

    return by_layer, layer_aci, (origin_x, origin_y, page_height)


def extract_labels(
    page: fitz.Page,
    origin_x: float,
    origin_y: float,
    page_height: float,
    title_block_max_display_x: float | None,
) -> list[tuple[float, float, str]]:
    """Rebuild short labels from character-split PDF text."""
    words = page.get_text("words")
    groups: dict[tuple[int, int], list] = defaultdict(list)
    for w in words:
        groups[(w[5], w[6])].append(w)

    labels: list[tuple[float, float, str]] = []
    for (_, _), items in groups.items():
        items.sort(key=lambda w: (w[0], w[1]))
        text = " ".join("".join(w[4] for w in items).split())
        if len(text) < 2:
            continue
        xs = [(w[0] + w[2]) / 2 for w in items]
        ys = [(w[1] + w[3]) / 2 for w in items]
        mx, my = sum(xs) / len(xs), sum(ys) / len(ys)
        dx, dy = media_to_display(page, mx, my)
        if title_block_max_display_x is not None and dx >= title_block_max_display_x:
            continue
        e, n = display_to_feet(dx, dy, origin_x, origin_y, page_height)
        if len(text) >= 3:
            labels.append((e, n, text))
    return labels


def write_dxf(
    by_layer: dict[str, list[Seg]],
    layer_aci: dict[str, int],
    labels: list[tuple[float, float, str]],
    out_path: Path,
    *,
    include_hatch: bool,
    include_text: bool,
) -> dict:
    doc = ezdxf.new("R2010")
    doc.header["$INSUNITS"] = 2  # feet
    doc.header["$MEASUREMENT"] = 0  # English
    msp = doc.modelspace()

    for name, aci in sorted(layer_aci.items()):
        if not include_hatch and name == "HATCH_FILL":
            continue
        if name not in doc.layers:
            doc.layers.add(name, color=aci)

    if include_text and "LABELS" not in doc.layers:
        doc.layers.add("LABELS", color=7)

    stats: dict[str, int] = defaultdict(int)

    for layer, segs in sorted(by_layer.items()):
        if not include_hatch and layer == "HATCH_FILL":
            continue
        polys = merge_segments(segs)
        for pts in polys:
            if len(pts) == 2:
                msp.add_line(pts[0], pts[1], dxfattribs={"layer": layer})
                stats["LINE"] += 1
            else:
                msp.add_lwpolyline(pts, dxfattribs={"layer": layer})
                stats["LWPOLYLINE"] += 1

    if include_text:
        for e, n, text in labels:
            if len(text) > 80:
                continue
            msp.add_text(
                text,
                dxfattribs={"layer": "LABELS", "height": 8.0},
            ).set_placement((e, n), align=TextEntityAlignment.LEFT)
        stats["TEXT"] = len(labels)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    doc.saveas(str(out_path))
    stats["stakeable"] = stats.get("LINE", 0) + stats.get("LWPOLYLINE", 0)
    return dict(stats)


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("pdf", type=Path)
    p.add_argument("-o", "--output", type=Path, required=True)
    p.add_argument(
        "--keep-hatch",
        action="store_true",
        help="Keep light gray hatch fill strokes (noisy)",
    )
    p.add_argument("--no-text", action="store_true")
    p.add_argument(
        "--title-block-x",
        type=float,
        default=1880.0,
        help="Display-space X cutoff; geometry fully right of this is dropped "
        "(title block). Set negative to disable.",
    )
    args = p.parse_args(argv)

    if not args.pdf.exists():
        print(f"PDF not found: {args.pdf}", file=sys.stderr)
        return 2

    doc = fitz.open(args.pdf)
    page = doc[0]
    tb = None if args.title_block_x < 0 else args.title_block_x

    by_layer, layer_aci, (ox, oy, ph) = extract_paths(
        page, skip_hatch=not args.keep_hatch, title_block_max_display_x=tb
    )
    labels: list[tuple[float, float, str]] = []
    if not args.no_text:
        labels = [
            (e, n, t)
            for e, n, t in extract_labels(page, ox, oy, ph, tb)
            if sum(ch.isalnum() for ch in t) >= 3
        ]

    stats = write_dxf(
        by_layer,
        layer_aci,
        labels,
        args.output,
        include_hatch=args.keep_hatch,
        include_text=not args.no_text,
    )
    print(f"Wrote {args.output}")
    print(f"Scale: 1 in = {FT_PER_INCH:g} ft  ({FT_PER_PT:.6f} ft / PDF point)")
    print("Local origin: SW of retained geometry (feet, north-up)")
    print(f"Layers: {sorted(by_layer)}")
    print(f"Stats: {stats}")
    print(
        "NOTE: Coordinates are local sheet feet, not WISCRS/state plane. "
        "Transform with field control before GPS stakeout."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
