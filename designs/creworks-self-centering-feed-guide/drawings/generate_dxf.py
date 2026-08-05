#!/usr/bin/env python3
"""Generate flat DXF patterns for the CREWORKS self-centering feed guide.

Defaults match scad/feed_guide.scad. Override via CLI flags after measuring
your machine (see ../MEASURE.md).
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import ezdxf
from ezdxf import units
from ezdxf.enums import TextEntityAlignment


def add_dims_note(msp, x: float, y: float, text: str) -> None:
    msp.add_text(
        text,
        height=3.5,
        dxfattribs={"layer": "NOTES"},
    ).set_placement((x, y), align=TextEntityAlignment.LEFT)


def rect(msp, cx: float, cy: float, w: float, h: float, layer: str = "CUT") -> None:
    hw, hh = w / 2, h / 2
    pts = [
        (cx - hw, cy - hh),
        (cx + hw, cy - hh),
        (cx + hw, cy + hh),
        (cx - hw, cy + hh),
        (cx - hw, cy - hh),
    ]
    msp.add_lwpolyline(pts, dxfattribs={"layer": layer, "closed": True})


def circle(msp, cx: float, cy: float, d: float, layer: str = "CUT") -> None:
    msp.add_circle((cx, cy), d / 2, dxfattribs={"layer": layer})


def v_jaw_polyline(
    msp,
    cx: float,
    cy: float,
    side: int,
    body_w: float,
    body_h: float,
    max_wire_d: float,
    layer: str = "CUT",
) -> None:
    """Outline of one V-jaw as seen from the feed direction (flat pattern)."""
    face = max_wire_d / 2 + 8
    # Outer rectangle with a 90° V notch toward centerline
    # side=-1 is left jaw (V opens to +X); side=+1 right jaw (V opens to -X)
    if side < 0:
        pts = [
            (cx - body_w, cy - body_h / 2),
            (cx, cy - body_h / 2),
            (cx, cy - face / math.sqrt(2)),
            (cx + face / math.sqrt(2), cy),  # V apex toward center
            (cx, cy + face / math.sqrt(2)),
            (cx, cy + body_h / 2),
            (cx - body_w, cy + body_h / 2),
            (cx - body_w, cy - body_h / 2),
        ]
    else:
        pts = [
            (cx + body_w, cy - body_h / 2),
            (cx, cy - body_h / 2),
            (cx, cy - face / math.sqrt(2)),
            (cx - face / math.sqrt(2), cy),
            (cx, cy + face / math.sqrt(2)),
            (cx, cy + body_h / 2),
            (cx + body_w, cy + body_h / 2),
            (cx + body_w, cy - body_h / 2),
        ]
    msp.add_lwpolyline(pts, dxfattribs={"layer": layer, "closed": True})


def build_doc(args: argparse.Namespace) -> ezdxf.Drawing:
    doc = ezdxf.new("R2010")
    doc.units = units.MM
    for name, color in (("CUT", 1), ("HOLES", 3), ("NOTES", 5), ("CENTER", 2)):
        doc.layers.add(name, color=color)
    msp = doc.modelspace()

    # --- Mount plate at origin ---
    plate_cx, plate_cy = 0.0, 0.0
    rect(msp, plate_cx, plate_cy, args.plate_w, args.plate_h, "CUT")

    # Thumbscrew holes — Y positioned so centerline matches roller
    cl_y = plate_cy - args.plate_h / 2 + args.centerline_z
    for x in (-args.screw_spacing / 2, args.screw_spacing / 2):
        circle(msp, plate_cx + x, cl_y, args.screw_clearance, "HOLES")

    # Center window
    window_w = args.max_wire_d + args.max_wire_d + 10 + 8
    window_h = max(args.max_wire_d + 16, 50)
    rect(msp, plate_cx, cl_y, window_w, window_h, "CUT")

    # Pinion bore + spring anchors
    circle(msp, plate_cx, cl_y, args.pinion_bore, "HOLES")
    for x in (-args.screw_spacing / 2 + 12, args.screw_spacing / 2 - 12):
        circle(msp, plate_cx + x, cl_y, 3.2, "HOLES")

    # Centerline mark
    msp.add_line(
        (plate_cx, cl_y - window_h / 2 - 8),
        (plate_cx, cl_y + window_h / 2 + 8),
        dxfattribs={"layer": "CENTER"},
    )
    msp.add_line(
        (plate_cx - window_w / 2 - 8, cl_y),
        (plate_cx + window_w / 2 + 8, cl_y),
        dxfattribs={"layer": "CENTER"},
    )

    add_dims_note(
        msp,
        -args.plate_w / 2,
        args.plate_h / 2 + 12,
        f"MOUNT PLATE  {args.plate_w:.0f} x {args.plate_h:.0f} x {args.plate_t:.0f} mm",
    )
    add_dims_note(
        msp,
        -args.plate_w / 2,
        args.plate_h / 2 + 6,
        f"Screw C-C A={args.screw_spacing:.1f}  CL height C={args.centerline_z:.1f}  "
        f"Max wire={args.max_wire_d:.1f}",
    )

    # --- Jaws below plate ---
    jaw_y = -args.plate_h / 2 - 55
    body_w, body_h = 28.0, args.max_wire_d + 20
    v_jaw_polyline(msp, -40, jaw_y, -1, body_w, body_h, args.max_wire_d)
    v_jaw_polyline(msp, 40, jaw_y, 1, body_w, body_h, args.max_wire_d)
    circle(msp, -40 - body_w + 8, jaw_y + body_h / 2 - 8, 3.2, "HOLES")
    circle(msp, 40 + body_w - 8, jaw_y + body_h / 2 - 8, 3.2, "HOLES")
    add_dims_note(msp, -70, jaw_y - body_h / 2 - 10, "LEFT JAW")
    add_dims_note(msp, 20, jaw_y - body_h / 2 - 10, "RIGHT JAW")

    # --- Pinion PCD reference ---
    pinion_x, pinion_y = -100.0, jaw_y
    pitch_d = args.pinion_teeth * args.rack_module
    circle(msp, pinion_x, pinion_y, pitch_d + 2 * args.rack_module, "CUT")
    circle(msp, pinion_x, pinion_y, args.pinion_bore, "HOLES")
    add_dims_note(msp, pinion_x - 20, pinion_y - 30, f"PINION  z{args.pinion_teeth} m{args.rack_module}")

    # Title block
    add_dims_note(msp, -args.plate_w / 2, -args.plate_h / 2 - 100, "CREWORKS Self-Centering Feed Guide — flat patterns")
    add_dims_note(msp, -args.plate_w / 2, -args.plate_h / 2 - 106, "Units: mm | CUT=profile HOLES=drill CENTER=alignment | Verify A/C on machine before cutting")

    return doc


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--screw-spacing", type=float, default=140.0)
    p.add_argument("--screw-clearance", type=float, default=8.5)
    p.add_argument("--centerline-z", type=float, default=55.0)
    p.add_argument("--plate-w", type=float, default=170.0)
    p.add_argument("--plate-h", type=float, default=100.0)
    p.add_argument("--plate-t", type=float, default=8.0)
    p.add_argument("--max-wire-d", type=float, default=38.0)
    p.add_argument("--pinion-bore", type=float, default=5.2)
    p.add_argument("--pinion-teeth", type=int, default=12)
    p.add_argument("--rack-module", type=float, default=1.5)
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path(__file__).with_name("feed_guide_patterns.dxf"),
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    doc = build_doc(args)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    doc.saveas(args.output)
    print(f"Wrote {args.output}")


if __name__ == "__main__":
    main()
