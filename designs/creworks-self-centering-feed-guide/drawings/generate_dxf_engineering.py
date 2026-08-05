#!/usr/bin/env python3
"""DXF engineering drawings — interface + Concepts A–D (flat / fab patterns)."""

from __future__ import annotations

from pathlib import Path

import ezdxf
from ezdxf import units, zoom
from ezdxf.enums import TextEntityAlignment

OUT = Path(__file__).resolve().parent / "sheets"

A, B, C = 140.0, 8.5, 55.0
PLATE_W, PLATE_H = 170.0, 100.0


def _new(name: str):
    doc = ezdxf.new("R2010")
    doc.units = units.MM
    doc.header["$INSUNITS"] = 4
    for layer, color in (
        ("OBJECT", 7),
        ("HIDDEN", 4),
        ("CENTER", 2),
        ("DIM", 3),
        ("TEXT", 5),
        ("HATCH", 8),
        ("TITLE", 7),
    ):
        doc.layers.add(layer, color=color)
    msp = doc.modelspace()
    return doc, msp


def _title(msp, x, y, dwg, title, scale="1:1"):
    msp.add_lwpolyline(
        [(x, y), (x + 180, y), (x + 180, y + 28), (x, y + 28), (x, y)],
        dxfattribs={"layer": "TITLE"},
    )
    msp.add_text(f"{dwg}  {title}", height=3.5, dxfattribs={"layer": "TEXT"}).set_placement(
        (x + 2, y + 18), align=TextEntityAlignment.LEFT
    )
    msp.add_text(
        f"SCALE {scale}  UNITS mm  TOL ±0.5  PROVISIONAL — VERIFY A,C",
        height=2.2,
        dxfattribs={"layer": "TEXT"},
    ).set_placement((x + 2, y + 8), align=TextEntityAlignment.LEFT)


def _centerline(msp, x1, y1, x2, y2):
    msp.add_line((x1, y1), (x2, y2), dxfattribs={"layer": "CENTER", "linetype": "CENTERX2"})


def _dim_h(msp, x1, x2, y, text):
    msp.add_line((x1, y - 2), (x1, y + 2), dxfattribs={"layer": "DIM"})
    msp.add_line((x2, y - 2), (x2, y + 2), dxfattribs={"layer": "DIM"})
    msp.add_line((x1, y), (x2, y), dxfattribs={"layer": "DIM"})
    msp.add_text(text, height=2.5, dxfattribs={"layer": "TEXT"}).set_placement(
        ((x1 + x2) / 2, y + 1.5), align=TextEntityAlignment.CENTER
    )


def _dim_v(msp, y1, y2, x, text):
    msp.add_line((x - 2, y1), (x + 2, y1), dxfattribs={"layer": "DIM"})
    msp.add_line((x - 2, y2), (x + 2, y2), dxfattribs={"layer": "DIM"})
    msp.add_line((x, y1), (x, y2), dxfattribs={"layer": "DIM"})
    msp.add_text(text, height=2.5, dxfattribs={"layer": "TEXT"}).set_placement(
        (x + 3, (y1 + y2) / 2), align=TextEntityAlignment.LEFT
    )


def _plate(msp, ox, oy):
    msp.add_lwpolyline(
        [
            (ox, oy),
            (ox + PLATE_W, oy),
            (ox + PLATE_W, oy + PLATE_H),
            (ox, oy + PLATE_H),
            (ox, oy),
        ],
        dxfattribs={"layer": "OBJECT"},
    )
    clx = ox + PLATE_W / 2
    cly = oy + C
    for dx in (-A / 2, A / 2):
        msp.add_circle((clx + dx, cly), B / 2, dxfattribs={"layer": "OBJECT"})
    msp.add_line((clx, oy - 8), (clx, oy + PLATE_H + 8), dxfattribs={"layer": "CENTER"})
    msp.add_line((ox - 8, cly), (ox + PLATE_W + 8, cly), dxfattribs={"layer": "CENTER"})
    return clx, cly


def dxf_interface():
    doc, msp = _new("IF")
    ox, oy = 0, 0
    clx, cly = _plate(msp, ox, oy)
    _dim_h(msp, clx - A / 2, clx + A / 2, oy + PLATE_H + 12, f"A={A:.0f}")
    _dim_v(msp, oy, cly, ox - 12, f"C={C:.0f}")
    _dim_h(msp, ox, ox + PLATE_W, oy - 12, f"{PLATE_W:.0f}")
    _dim_v(msp, oy, oy + PLATE_H, ox + PLATE_W + 12, f"{PLATE_H:.0f}")
    _title(msp, ox, oy - 50, "WSFG-IF", "MACHINE INTERFACE CONTROL")
    zoom.extents(msp)
    path = OUT / "WSFG-IF_machine_interface.dxf"
    doc.saveas(path)
    return path


def dxf_A_funnel():
    doc, msp = _new("A")
    ox, oy = 0, 0
    clx, cly = _plate(msp, ox, oy)
    msp.add_circle((clx, cly), 28, dxfattribs={"layer": "OBJECT"})
    # keyhole
    msp.add_lwpolyline(
        [
            (clx - 3.5, cly - 20),
            (clx + 3.5, cly - 20),
            (clx + 3.5, cly + 20),
            (clx - 3.5, cly + 20),
            (clx - 3.5, cly - 20),
        ],
        dxfattribs={"layer": "OBJECT"},
    )
    msp.add_circle((clx, cly), 5, dxfattribs={"layer": "OBJECT"})
    _dim_h(msp, clx - 3.5, clx + 3.5, cly - 28, "7")
    _dim_v(msp, cly - 20, cly + 20, clx + 40, "40")
    _dim_h(msp, clx - 28, clx + 28, oy + PLATE_H + 18, "Ø55 ENTRANCE")
    _title(msp, ox, oy - 50, "WSFG-A1", "CONCEPT A FUNNEL BODY — FRONT", "1:1")
    zoom.extents(msp)
    path = OUT / "WSFG-A1_funnel_body.dxf"
    doc.saveas(path)
    return path


def dxf_B_vblock():
    doc, msp = _new("B")
    ox, oy = 0, 0
    clx, cly = _plate(msp, ox, oy)
    # 90° V
    half = 24
    msp.add_lwpolyline(
        [(clx - half, cly + 10), (clx, cly - half), (clx + half, cly + 10)],
        dxfattribs={"layer": "OBJECT"},
    )
    # window outline around V
    msp.add_lwpolyline(
        [
            (clx - 40, cly - 30),
            (clx + 40, cly - 30),
            (clx + 40, cly + 30),
            (clx - 40, cly + 30),
            (clx - 40, cly - 30),
        ],
        dxfattribs={"layer": "HIDDEN"},
    )
    _dim_h(msp, clx - half, clx + half, cly + 36, "48 V OPENING")
    _dim_v(msp, cly - half, cly + 10, clx + 55, "34 V DEPTH")
    _dim_h(msp, clx - A / 2, clx + A / 2, oy + PLATE_H + 12, f"A={A:.0f}±0.2")
    _dim_v(msp, oy, cly, ox - 14, f"C={C:.0f}±0.2")
    msp.add_text("90° V APEX ON CL", height=2.5, dxfattribs={"layer": "TEXT"}).set_placement(
        (clx + 8, cly - 8), align=TextEntityAlignment.LEFT
    )
    _title(msp, ox, oy - 50, "WSFG-B1", "CONCEPT B V-BLOCK / MOUNT", "1:1")
    zoom.extents(msp)
    path = OUT / "WSFG-B1_vblock_detail.dxf"
    doc.saveas(path)
    return path


def dxf_C_arm():
    doc, msp = _new("C")
    # flat arm
    msp.add_lwpolyline(
        [(0, 0), (70, 4), (70, 26), (0, 30), (0, 0)],
        dxfattribs={"layer": "OBJECT"},
    )
    msp.add_circle((10, 15), 4, dxfattribs={"layer": "OBJECT"})
    msp.add_circle((60, 15), 3.1, dxfattribs={"layer": "OBJECT"})
    _dim_h(msp, 10, 60, 40, "50")
    _dim_v(msp, 0, 30, -10, "30")
    _title(msp, -10, -40, "WSFG-C1", "CONCEPT C SWING ARM — 2 REQ (LH/RH)", "1:1")
    zoom.extents(msp)
    path = OUT / "WSFG-C1_swing_arm.dxf"
    doc.saveas(path)
    return path


def dxf_D_link():
    doc, msp = _new("D")
    msp.add_lwpolyline(
        [(0, 0), (100, 0), (100, 14), (0, 14), (0, 0)],
        dxfattribs={"layer": "OBJECT"},
    )
    for x in (10, 50, 90):
        msp.add_circle((x, 7), 3.1, dxfattribs={"layer": "OBJECT"})
    _dim_h(msp, 10, 50, 24, "40")
    _dim_h(msp, 50, 90, 24, "40")
    _dim_h(msp, 0, 100, -12, "100")
    # jaw pad
    msp.add_lwpolyline(
        [(130, 0), (150, 0), (150, 40), (130, 40), (130, 0)],
        dxfattribs={"layer": "OBJECT"},
    )
    msp.add_lwpolyline([(130, 5), (142, 20), (130, 35)], dxfattribs={"layer": "OBJECT"})
    msp.add_circle((144, 20), 2.6, dxfattribs={"layer": "OBJECT"})
    _title(msp, 0, -40, "WSFG-D1", "CONCEPT D LINK + JAW PAD", "1:1")
    zoom.extents(msp)
    path = OUT / "WSFG-D1_link_jaw.dxf"
    doc.saveas(path)
    return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # Ensure CENTER linetype exists
    paths = [
        dxf_interface(),
        dxf_A_funnel(),
        dxf_B_vblock(),
        dxf_C_arm(),
        dxf_D_link(),
    ]
    for p in paths:
        print(f"Wrote {p}")


if __name__ == "__main__":
    main()
