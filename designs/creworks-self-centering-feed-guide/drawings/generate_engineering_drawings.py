#!/usr/bin/env python3
"""Generate multi-concept engineering drawing sheets (PNG).

Provisional envelope (edit after measuring machine):
  A = 140 mm thumbscrew C-C
  B = 8.5 mm screw clearance
  C = 55 mm centerline height from plate bottom
  plate = 170 x 100 mm
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Arc, Circle, FancyBboxPatch, Polygon, Rectangle, Wedge

from eng_drawing import (
    centerline,
    dim_h,
    dim_v,
    new_sheet,
    note_block,
    save,
    section_arrows,
    view_label,
)

OUT = Path(__file__).resolve().parent / "sheets"

# Provisional machine interface
A, B, C = 140.0, 8.5, 55.0
PLATE_W, PLATE_H, PLATE_T = 170.0, 100.0, 8.0


def _iface_front(ax, ox, oy, s=1.0):
    """Draw OEM mounting interface front view at origin ox,oy (plate bottom-left). Scale s."""
    w, h = PLATE_W * s, PLATE_H * s
    ax.add_patch(Rectangle((ox, oy), w, h, fill=False, lw=1.4, ec="black"))
    # thumbscrews
    for dx in ((PLATE_W - A) / 2, (PLATE_W + A) / 2):
        ax.add_patch(Circle((ox + dx * s, oy + C * s), (B / 2) * s, fill=False, lw=1.0))
        ax.add_patch(Circle((ox + dx * s, oy + C * s), 1.2 * s, facecolor="black"))
    # centerline
    clx = ox + (PLATE_W / 2) * s
    centerline(ax, clx, oy - 6 * s, clx, oy + h + 6 * s)
    centerline(ax, ox - 6 * s, oy + C * s, ox + w + 6 * s, oy + C * s)
    return clx, oy + C * s, w, h


# ---------------------------------------------------------------------------
# Sheet 00 — Concept comparison
# ---------------------------------------------------------------------------
def sheet_00_comparison():
    sh = new_sheet("WSFG-00", "CONCEPT COMPARISON — SELF-CENTERING FEED GUIDE", scale="NTS", material="—")
    ax = sh.ax

    concepts = [
        ("A", "FIXED FUNNEL", "0 moving parts\nkeyhole exit on CL", "Simplest"),
        ("B", "DEEP-V + HOLD-DOWN", "V centers wire\nspring pad retains", "Best effort/accuracy"),
        ("C", "SIDE IDLERS", "Equal-arm rollers\nrolling contact", "Lowest drag"),
        ("D", "SCISSOR JAWS", "X-linkage jaws\nspring closed", "No printed gears"),
        ("E", "3-JAW IRIS", "Scroll/cam pads\naperture on CL", "Highest precision"),
    ]

    x0, y0 = 25, 200
    card_w, card_h = 70, 95
    for i, (tag, name, desc, pick) in enumerate(concepts):
        x = x0 + i * (card_w + 6)
        ax.add_patch(Rectangle((x, y0 - card_h), card_w, card_h, fill=False, lw=1.2))
        ax.add_patch(Rectangle((x, y0 - 16), card_w, 16, facecolor="#eeeeee", ec="black", lw=1.0))
        ax.text(x + 4, y0 - 11, f"CONCEPT {tag}", fontsize=8, fontweight="bold", va="center")
        ax.text(x + 4, y0 - 28, name, fontsize=7.5, fontweight="bold")
        ax.text(x + 4, y0 - 48, desc, fontsize=6.5, va="top")
        ax.text(x + 4, y0 - card_h + 10, f"→ {pick}", fontsize=6.5, style="italic")

        # mini glyph
        cx, cy = x + card_w / 2, y0 - 70
        if tag == "A":
            ax.add_patch(Circle((cx, cy), 12, fill=False, lw=1))
            ax.add_patch(Rectangle((cx - 2, cy - 10), 4, 20, fill=False, lw=0.8))
        elif tag == "B":
            ax.plot([cx - 14, cx, cx + 14], [cy + 8, cy - 10, cy + 8], "k-", lw=1.2)
            ax.plot([cx - 10, cx + 10], [cy + 12, cy + 12], "k-", lw=1.0)
        elif tag == "C":
            ax.add_patch(Circle((cx - 10, cy), 6, fill=False, lw=1))
            ax.add_patch(Circle((cx + 10, cy), 6, fill=False, lw=1))
            ax.add_patch(Circle((cx, cy), 3, facecolor="#888", ec="black", lw=0.5))
        elif tag == "D":
            ax.plot([cx - 12, cx + 12], [cy - 10, cy + 10], "k-", lw=1.2)
            ax.plot([cx - 12, cx + 12], [cy + 10, cy - 10], "k-", lw=1.2)
        else:
            for ang in (90, 210, 330):
                import math
                px = cx + 9 * math.cos(math.radians(ang))
                py = cy + 9 * math.sin(math.radians(ang))
                ax.add_patch(Circle((px, py), 3.5, fill=False, lw=0.8))
            ax.add_patch(Circle((cx, cy), 4, fill=False, lw=0.8))

    note_block(
        ax,
        25,
        90,
        [
            "All concepts mount with OEM thumbscrews (spacing A). Centerline height C must match driven V-roller.",
            "Recommended build order: B (accuracy) → C if drag is an issue → A as zero-moving-part fallback.",
            "Do not fabricate from these sheets until A/B/C are measured on the specific machine (see MEASURE.md).",
            "Detail sheets: WSFG-A0/A1, WSFG-B0/B1/B2, WSFG-C0/C1, WSFG-D0/D1, WSFG-E0.",
        ],
    )

    # Interface reference table
    ax.add_patch(Rectangle((250, 55), 150, 50, fill=False, lw=1.0))
    ax.text(255, 95, "MACHINE INTERFACE (PROVISIONAL)", fontsize=7, fontweight="bold", va="top")
    ax.text(255, 85, f"A  Screw C–C ................ {A:.0f} mm", fontsize=6.5, family="monospace")
    ax.text(255, 78, f"B  Screw clearance Ø ........ {B:.1f} mm", fontsize=6.5, family="monospace")
    ax.text(255, 71, f"C  Centerline height ........ {C:.0f} mm", fontsize=6.5, family="monospace")
    ax.text(255, 64, f"   Plate envelope ...... {PLATE_W:.0f} × {PLATE_H:.0f} × {PLATE_T:.0f}", fontsize=6.5, family="monospace")

    save(sh, OUT / "WSFG-00_concept_comparison.png")


# ---------------------------------------------------------------------------
# Concept A — Funnel
# ---------------------------------------------------------------------------
def sheet_A0():
    sh = new_sheet("WSFG-A0", "CONCEPT A — FIXED FUNNEL ASSEMBLY", scale="1:2", material="PETG / HDPE / AL 6061")
    ax = sh.ax
    s = 0.55
    ox, oy = 40, 100
    clx, cly, w, h = _iface_front(ax, ox, oy, s)

    # Funnel mouth (front) — outer circle + keyhole exit
    ax.add_patch(Circle((clx, cly), 28 * s, fill=False, lw=1.3))
    ax.add_patch(Circle((clx, cly), 22 * s, fill=False, lw=0.8, ls="--"))
    # keyhole exit
    ax.add_patch(Rectangle((clx - 3.5 * s, cly - 20 * s), 7 * s, 40 * s, fill=False, lw=1.2))
    ax.add_patch(Circle((clx, cly), 5 * s, fill=False, lw=1.0))

    dim_h(ax, ox + ((PLATE_W - A) / 2) * s, ox + ((PLATE_W + A) / 2) * s, oy + h + 14, f"A={A:.0f}")
    dim_v(ax, oy, cly, ox - 12, f"C={C:.0f}")
    dim_h(ax, ox, ox + w, oy - 14, f"{PLATE_W:.0f}")
    dim_v(ax, oy, oy + h, ox + w + 14, f"{PLATE_H:.0f}")
    view_label(ax, ox + w / 2, oy + h + 28, "FRONT VIEW (FEED DIRECTION)")

    # Side section
    sx, sy = 280, 110
    # plate
    ax.add_patch(Rectangle((sx, sy), PLATE_T * s * 1.2, PLATE_H * s, fill=False, lw=1.2))
    # funnel taper
    funnel = [
        (sx + PLATE_T * s * 1.2, sy + (C - 28) * s),
        (sx + 45 * s, sy + (C - 28) * s),
        (sx + 45 * s, sy + (C + 28) * s),
        (sx + PLATE_T * s * 1.2, sy + (C + 28) * s),
    ]
    # outer flare
    ax.plot(
        [sx + PLATE_T * s * 1.2, sx + 50 * s, sx + 50 * s, sx + PLATE_T * s * 1.2],
        [sy + (C - 8) * s, sy + (C - 28) * s, sy + (C + 28) * s, sy + (C + 8) * s],
        "k-",
        lw=1.3,
    )
    ax.plot(
        [sx + PLATE_T * s * 1.2, sx + 50 * s, sx + 50 * s, sx + PLATE_T * s * 1.2],
        [sy + (C - 3) * s, sy + (C - 22) * s, sy + (C + 22) * s, sy + (C + 3) * s],
        "k--",
        lw=0.8,
    )
    # wire CL
    centerline(ax, sx - 8, sy + C * s, sx + 60 * s, sy + C * s)
    dim_h(ax, sx + PLATE_T * s * 1.2, sx + 50 * s, sy + (C + 36) * s, "35–50")
    dim_v(ax, sy + (C - 28) * s, sy + (C + 28) * s, sx + 58 * s, "Ø55 ENTRANCE")
    view_label(ax, sx + 30 * s, sy + h + 20, "SECTION A–A")
    section_arrows(ax, ox + 20, cly + 35 * s, ox + w - 20, "A")

    note_block(
        ax,
        25,
        85,
        [
            "Exit is a vertical KEYHOLE (slot + round) on centerline — centers small wire, passes jackets up to Ø38.",
            "Optional: press-fit UHMW liner in tunnel for wear.",
            "Chamfer entrance 2×45°. Break all edges 0.5.",
            "Bolt with OEM thumbscrews; confirm exit CL coincides with roller V before use.",
        ],
    )
    save(sh, OUT / "WSFG-A0_funnel_assembly.png")


def sheet_A1():
    sh = new_sheet("WSFG-A1", "CONCEPT A — FUNNEL BODY DETAIL", scale="1:1", material="HDPE  OR  PETG PRINT")
    ax = sh.ax
    s = 1.0
    # Front detail larger
    ox, oy = 50, 90
    clx, cly, w, h = _iface_front(ax, ox, oy, 0.7)
    s = 0.7
    ax.add_patch(Circle((clx, cly), 28 * s, fill=False, lw=1.4))
    # keyhole dimensions
    slot_w, slot_h, hole_d = 7.0, 40.0, 10.0
    ax.add_patch(Rectangle((clx - slot_w / 2 * s, cly - slot_h / 2 * s), slot_w * s, slot_h * s, fill=False, lw=1.2))
    ax.add_patch(Circle((clx, cly), (hole_d / 2) * s, fill=False, lw=1.1))
    dim_h(ax, clx - slot_w / 2 * s, clx + slot_w / 2 * s, cly - slot_h / 2 * s - 10, f"{slot_w:.0f}")
    dim_v(ax, cly - slot_h / 2 * s, cly + slot_h / 2 * s, clx + 40, f"{slot_h:.0f}")
    ax.text(clx + 18, cly + 2, f"Ø{hole_d:.0f}", fontsize=7)

    # Top view
    tx, ty = 260, 160
    ax.add_patch(Rectangle((tx, ty), PLATE_W * 0.5, PLATE_T * 0.5 + 40, fill=False, lw=1.2))
    ax.plot([tx, tx + 20], [ty + 25, ty + 45], "k-", lw=1.0)
    ax.plot([tx, tx + 20], [ty + 25, ty + 5], "k-", lw=1.0)
    view_label(ax, tx + 40, ty + 70, "TOP VIEW (SCHEME)")
    view_label(ax, ox + w / 2, oy + h + 30, "FRONT — EXIT DETAIL")

    note_block(
        ax,
        25,
        75,
        [
            f"Thumbscrew holes: Ø{B} thru, C–C {A} (match machine).",
            "Keyhole must be symmetric about vertical CL within 0.5 mm.",
            "If printing: 4 walls, 40% infill, outer walls on XY for smooth tunnel.",
        ],
    )
    save(sh, OUT / "WSFG-A1_funnel_body.png")


# ---------------------------------------------------------------------------
# Concept B — Deep V + hold-down
# ---------------------------------------------------------------------------
def sheet_B0():
    sh = new_sheet("WSFG-B0", "CONCEPT B — DEEP-V + HOLD-DOWN ASSEMBLY", scale="1:2", material="SEE PART SHEETS")
    ax = sh.ax
    s = 0.55
    ox, oy = 35, 105
    clx, cly, w, h = _iface_front(ax, ox, oy, s)

    # Deep V
    v = 22 * s
    ax.plot([clx - v, clx, clx + v], [cly + v * 0.3, cly - v, cly + v * 0.3], "k-", lw=1.6)
    ax.plot([clx - v - 8 * s, clx - v], [cly + v * 0.3, cly + v * 0.3], "k-", lw=1.2)
    ax.plot([clx + v, clx + v + 8 * s], [cly + v * 0.3, cly + v * 0.3], "k-", lw=1.2)
    # hold-down pad
    ax.add_patch(Rectangle((clx - 14 * s, cly + 8 * s), 28 * s, 6 * s, fill=False, lw=1.2))
    # spring
    ax.plot([clx, clx], [cly + 14 * s, cly + 30 * s], "k-", lw=0.8)
    ys = [cly + 18 * s + i * 2 * s for i in range(5)]
    xs = [clx + (3 * s if i % 2 else -3 * s) for i in range(5)]
    ax.plot(xs, ys, "k-", lw=0.9)
    # pivot
    ax.add_patch(Circle((clx + 30 * s, cly + 20 * s), 2.5 * s, fill=False, lw=1.0))
    ax.plot([clx + 14 * s, clx + 30 * s], [cly + 11 * s, cly + 20 * s], "k-", lw=1.0)

    # sample wire
    ax.add_patch(Circle((clx, cly - 2 * s), 6 * s, fill=False, lw=1.0))

    dim_h(ax, ox + ((PLATE_W - A) / 2) * s, ox + ((PLATE_W + A) / 2) * s, oy + h + 12, f"A={A:.0f}")
    dim_v(ax, oy, cly, ox - 14, f"C={C:.0f}")
    view_label(ax, ox + w / 2, oy + h + 26, "FRONT VIEW")

    # Side view
    sx, sy = 270, 115
    ax.add_patch(Rectangle((sx, sy), 10, 55, fill=False, lw=1.2))  # plate edge
    # V block protrusion
    ax.add_patch(Rectangle((sx + 10, sy + 8), 28, 30, fill=False, lw=1.2))
    ax.plot([sx + 10, sx + 38], [sy + 20, sy + 20], "k--", lw=0.7)
    # hold-down arm
    ax.plot([sx + 14, sx + 40], [sy + 42, sy + 48], "k-", lw=1.3)
    ax.add_patch(Circle((sx + 40, sy + 48), 2.5, fill=False, lw=1.0))
    ax.add_patch(Rectangle((sx + 16, sy + 36), 14, 5, fill=False, lw=1.0))
    centerline(ax, sx - 5, sy + 23, sx + 55, sy + 23)
    dim_h(ax, sx + 10, sx + 38, sy - 8, "28")
    view_label(ax, sx + 30, sy + 72, "RIGHT SIDE")

    note_block(
        ax,
        25,
        90,
        [
            "90° V apex ON centerline C. Apex radius ≤ 0.5 mm (or leave sharp for small wire).",
            "Hold-down force: light — wire must still be pulled by driven roller without stalling.",
            "V faces: UHMW tape or print in PETG; replace when grooved.",
            "Bill: plate+V (B1), hold-down arm (B2), M5 pivot, torsion or extension spring.",
        ],
    )
    save(sh, OUT / "WSFG-B0_vblock_assembly.png")


def sheet_B1():
    sh = new_sheet("WSFG-B1", "CONCEPT B — V-BLOCK / MOUNT PLATE", scale="1:1", material="PETG  OR  AL 6061-T6")
    ax = sh.ax
    s = 0.85
    ox, oy = 40, 80
    clx, cly, w, h = _iface_front(ax, ox, oy, s)

    # V cut detail in window
    v_half = 24 * s
    ax.plot([clx - v_half, clx, clx + v_half], [cly + 10 * s, cly - v_half, cly + 10 * s], "k-", lw=1.8)
    # hatch under V (material)
    for i in range(6):
        x0 = clx - v_half + i * (2 * v_half / 6)
        ax.plot([x0, x0 + 4], [cly - v_half + 2, cly - v_half + 8], "k-", lw=0.4)

    dim_h(ax, clx - v_half, clx + v_half, cly + 28 * s, "48  (V OPENING)")
    ax.text(clx + 8, cly - 8, "90°", fontsize=8, fontweight="bold")
    # angle arc
    ax.add_patch(Arc((clx, cly - v_half), 20, 20, angle=0, theta1=45, theta2=135, lw=0.8, fill=False))

    dim_h(ax, ox + ((PLATE_W - A) / 2) * s, ox + ((PLATE_W + A) / 2) * s, oy + h + 16, f"{A:.0f}±0.2")
    dim_v(ax, oy, cly, ox - 16, f"{C:.0f}±0.2")
    view_label(ax, ox + w / 2, oy + h + 32, "FRONT VIEW")

    # Section of V
    sx, sy = 280, 100
    ax.plot([sx, sx + 40, sx + 80], [sy + 40, sy, sy + 40], "k-", lw=1.6)
    ax.plot([sx, sx + 80], [sy + 40, sy + 40], "k-", lw=1.0)
    ax.add_patch(Rectangle((sx, sy - 10), 80, 18, fill=False, lw=1.0))
    dim_v(ax, sy, sy + 40, sx + 90, "24 DEPTH")
    view_label(ax, sx + 40, sy + 60, "SECTION B–B  (V PROFILE)")

    note_block(
        ax,
        25,
        68,
        [
            "Apex of V must lie on vertical & horizontal centerlines within 0.3 mm.",
            f"Mount holes Ø{B} thru. Spotface optional under thumbscrew heads.",
            "If aluminum: break V edges 0.2; if PETG: iron V faces or sand smooth.",
        ],
    )
    save(sh, OUT / "WSFG-B1_vblock_detail.png")


def sheet_B2():
    sh = new_sheet("WSFG-B2", "CONCEPT B — HOLD-DOWN ARM", scale="1:1", material="PETG / STEEL STRAP")
    ax = sh.ax
    # Flat pattern of arm
    ox, oy = 60, 140
    ax.add_patch(Rectangle((ox, oy), 90, 16, fill=False, lw=1.4))
    ax.add_patch(Rectangle((ox + 10, oy - 2), 28, 20, fill=False, lw=1.2))  # pad
    ax.add_patch(Circle((ox + 82, oy + 8), 3.1, fill=False, lw=1.2))  # pivot hole
    ax.add_patch(Circle((ox + 55, oy + 8), 2.0, fill=False, lw=1.0))  # spring hole
    dim_h(ax, ox, ox + 90, oy + 30, "90")
    dim_v(ax, oy, oy + 16, ox - 12, "16")
    dim_h(ax, ox + 10, ox + 38, oy - 16, "PAD 28")
    ax.text(ox + 82, oy - 12, "Ø6.2 (M5 CLEAR)", fontsize=7, ha="center")
    view_label(ax, ox + 45, oy + 50, "FLAT PATTERN / TOP")

    # Side
    ax.add_patch(Rectangle((250, 140), 90, 5, fill=False, lw=1.2))
    ax.add_patch(Rectangle((260, 135), 28, 10, fill=False, lw=1.1))
    dim_v(ax, 135, 145, 360, "PAD t=5–8")
    view_label(ax, 295, 175, "SIDE")

    note_block(
        ax,
        25,
        100,
        [
            "Pad face may be faced with leather/UHMW for grip without tearing jacket.",
            "Spring: light torsion at pivot OR extension to plate — open by hand to Ø38.",
            "Pivot shared with plate boss (see B0 side view).",
        ],
    )
    save(sh, OUT / "WSFG-B2_holddown.png")


# ---------------------------------------------------------------------------
# Concept C — Side rollers
# ---------------------------------------------------------------------------
def sheet_C0():
    sh = new_sheet("WSFG-C0", "CONCEPT C — OPPOSED IDLE SIDE ROLLERS", scale="1:2", material="SEE NOTES")
    ax = sh.ax
    s = 0.55
    ox, oy = 35, 110
    clx, cly, w, h = _iface_front(ax, ox, oy, s)

    # Arms + rollers
    for side, sign in (("L", -1), ("R", 1)):
        rx = clx + sign * 18 * s
        ax.add_patch(Circle((rx, cly), 8 * s, fill=False, lw=1.4))
        ax.add_patch(Circle((rx, cly), 2 * s, facecolor="black"))
        # arm
        ax.plot([rx, clx + sign * 45 * s], [cly, cly + 25 * s], "k-", lw=1.3)
        ax.add_patch(Circle((clx + sign * 45 * s, cly + 25 * s), 2.5 * s, fill=False, lw=1.0))
    # equalizer bar
    ax.plot([clx - 45 * s, clx + 45 * s], [cly + 25 * s, cly + 25 * s], "k-", lw=1.1)
    ax.add_patch(Circle((clx, cly + 25 * s), 2.2 * s, fill=False, lw=1.0))
    # wire
    ax.add_patch(Circle((clx, cly), 5 * s, fill=False, lw=1.0))
    # springs
    ax.plot([clx - 50 * s, clx - 30 * s], [cly - 15 * s, cly - 5 * s], "k-", lw=0.9)
    ax.plot([clx + 50 * s, clx + 30 * s], [cly - 15 * s, cly - 5 * s], "k-", lw=0.9)

    dim_h(ax, clx - 18 * s - 8 * s, clx + 18 * s + 8 * s, oy - 12, "ROLLER SPAN (VARIES)")
    dim_v(ax, oy, cly, ox - 14, f"C={C:.0f}")
    view_label(ax, ox + w / 2, oy + h + 24, "FRONT VIEW — ARMS OPEN FOR Ø12 WIRE")

    # Kinematic sketch
    kx, ky = 280, 150
    ax.add_patch(Circle((kx - 20, ky), 8, fill=False, lw=1.2))
    ax.add_patch(Circle((kx + 20, ky), 8, fill=False, lw=1.2))
    ax.plot([kx - 20, kx - 35], [ky, ky + 25], "k-", lw=1.1)
    ax.plot([kx + 20, kx + 35], [ky, ky + 25], "k-", lw=1.1)
    ax.plot([kx - 35, kx + 35], [ky + 25, ky + 25], "k-", lw=1.0)
    ax.text(kx, ky - 25, "EQUALIZER KEEPS ΔL = ΔR", ha="center", fontsize=7)
    view_label(ax, kx, ky + 50, "KINEMATIC SCHEME")

    note_block(
        ax,
        25,
        90,
        [
            "Rollers: Ø16–20 PU or POM, 608ZZ bearings (or printed axles for light duty).",
            "Equalizer: solid bar on slotted pivots, OR meshing gear sectors at arm pivots.",
            "Spring bias closed; stop screws set minimum gap ≈ 1 mm for tiny wire.",
            "Lowest drag option — preferred when thin wire slips on the driven roller.",
        ],
    )
    save(sh, OUT / "WSFG-C0_side_rollers_assembly.png")


def sheet_C1():
    sh = new_sheet("WSFG-C1", "CONCEPT C — SWING ARM DETAIL", scale="1:1", material="AL 6061 / PETG")
    ax = sh.ax
    ox, oy = 80, 120
    # arm body
    pts = [(ox, oy), (ox + 70, oy + 8), (ox + 70, oy + 22), (ox, oy + 30)]
    ax.add_patch(Polygon(pts, fill=False, lw=1.4))
    ax.add_patch(Circle((ox + 10, oy + 15), 4, fill=False, lw=1.2))  # roller axle
    ax.add_patch(Circle((ox + 60, oy + 15), 3.1, fill=False, lw=1.2))  # pivot
    dim_h(ax, ox + 10, ox + 60, oy + 45, "50  PIVOT→AXLE")
    dim_v(ax, oy, oy + 30, ox - 14, "30")
    ax.text(ox + 10, oy - 12, "Ø8 ROLLER AXLE", fontsize=7, ha="center")
    ax.text(ox + 60, oy - 12, "Ø6.2 PIVOT", fontsize=7, ha="center")
    view_label(ax, ox + 35, oy + 65, "ARM — 2 REQ'D (1 LH / 1 RH)")

    # roller
    ax.add_patch(Circle((260, 150), 20, fill=False, lw=1.4))
    ax.add_patch(Circle((260, 150), 6, fill=False, lw=1.1))
    dim_h(ax, 240, 280, 120, "Ø40 MAX / Ø16 MIN")
    ax.text(260, 95, "IDLE ROLLER (PU/POM)", ha="center", fontsize=7)
    view_label(ax, 260, 195, "ROLLER")

    note_block(
        ax,
        25,
        85,
        [
            "Make LH/RH arms mirrored. Keep axle parallel to blade axis within 1°.",
            "Equalizer holes: slotted ±3 mm for sync fine-tune after install.",
        ],
    )
    save(sh, OUT / "WSFG-C1_swing_arm.png")


# ---------------------------------------------------------------------------
# Concept D — Scissor
# ---------------------------------------------------------------------------
def sheet_D0():
    sh = new_sheet("WSFG-D0", "CONCEPT D — SCISSOR (X-LINK) JAWS", scale="1:2", material="PETG / STEEL PIVOTS")
    ax = sh.ax
    s = 0.55
    ox, oy = 40, 110
    clx, cly, w, h = _iface_front(ax, ox, oy, s)

    # X links
    ax.plot([clx - 40 * s, clx + 40 * s], [cly - 25 * s, cly + 25 * s], "k-", lw=1.5)
    ax.plot([clx - 40 * s, clx + 40 * s], [cly + 25 * s, cly - 25 * s], "k-", lw=1.5)
    ax.add_patch(Circle((clx, cly), 3 * s, fill=False, lw=1.2))  # center pivot
    # jaw pads
    for sign in (-1, 1):
        jx = clx + sign * 16 * s
        ax.add_patch(Rectangle((jx - 5 * s, cly - 12 * s), 10 * s, 24 * s, fill=False, lw=1.2))
    ax.add_patch(Circle((clx, cly), 5 * s, fill=False, lw=1.0))  # wire
    # spring between lower ends
    ax.plot([clx - 35 * s, clx + 35 * s], [cly - 28 * s, cly - 28 * s], "k-", lw=0.9)

    dim_v(ax, oy, cly, ox - 14, f"C={C:.0f}")
    view_label(ax, ox + w / 2, oy + h + 24, "FRONT — SCISSOR CLOSED ON WIRE")

    # Side
    sx, sy = 280, 120
    ax.add_patch(Rectangle((sx, sy), 8, 50, fill=False, lw=1.2))
    ax.add_patch(Circle((sx + 20, sy + 25), 3, fill=False, lw=1.1))
    ax.plot([sx + 8, sx + 35], [sy + 40, sy + 30], "k-", lw=1.2)
    ax.plot([sx + 8, sx + 35], [sy + 10, sy + 20], "k-", lw=1.2)
    view_label(ax, sx + 25, sy + 70, "SIDE (LINK STACK)")

    note_block(
        ax,
        25,
        90,
        [
            "Center pivot MUST lie on machine centerline C — this is the self-centering datum.",
            "Jaw pads: V-face or flat with soft pad; bolt to link ends with shoulder screws.",
            "No rack/pinion — sync is pure linkage geometry.",
            "Add nylon washers between links to reduce play.",
        ],
    )
    save(sh, OUT / "WSFG-D0_scissor_assembly.png")


def sheet_D1():
    sh = new_sheet("WSFG-D1", "CONCEPT D — LINK + JAW PAD", scale="1:1", material="PETG / DELRIN")
    ax = sh.ax
    ox, oy = 70, 140
    ax.add_patch(Rectangle((ox, oy), 100, 14, fill=False, lw=1.4))
    ax.add_patch(Circle((ox + 10, oy + 7), 3.1, fill=False, lw=1.2))
    ax.add_patch(Circle((ox + 50, oy + 7), 3.1, fill=False, lw=1.2))
    ax.add_patch(Circle((ox + 90, oy + 7), 3.1, fill=False, lw=1.2))
    dim_h(ax, ox + 10, ox + 50, oy + 30, "40")
    dim_h(ax, ox + 50, ox + 90, oy + 30, "40")
    dim_h(ax, ox, ox + 100, oy - 16, "100")
    view_label(ax, ox + 50, oy + 50, "LINK — 2 REQ'D")

    # jaw pad
    jx, jy = 260, 130
    ax.add_patch(Rectangle((jx, jy), 20, 40, fill=False, lw=1.4))
    ax.plot([jx, jx + 12, jx], [jy + 5, jy + 20, jy + 35], "k-", lw=1.3)  # V face
    ax.add_patch(Circle((jx + 14, jy + 20), 2.6, fill=False, lw=1.0))
    view_label(ax, jx + 10, jy + 60, "JAW PAD — 2 REQ'D")

    note_block(
        ax,
        25,
        100,
        [
            "Center hole = common pivot. Outer holes = jaw pad + spring anchors.",
            "Slot outer holes ±2 mm if jaw alignment needs trim after first fit.",
        ],
    )
    save(sh, OUT / "WSFG-D1_link_jaw.png")


# ---------------------------------------------------------------------------
# Concept E — Three jaw
# ---------------------------------------------------------------------------
def sheet_E0():
    sh = new_sheet("WSFG-E0", "CONCEPT E — THREE-JAW IRIS / SCROLL LAYOUT", scale="1:2", material="AL / BRASS SCROLL")
    ax = sh.ax
    s = 0.6
    ox, oy = 50, 100
    clx, cly, w, h = _iface_front(ax, ox, oy, s)

    import math

    R = 32 * s
    ax.add_patch(Circle((clx, cly), R, fill=False, lw=1.4))
    ax.add_patch(Circle((clx, cly), 8 * s, fill=False, lw=1.0))
    for i, ang in enumerate((90, 210, 330)):
        rad = math.radians(ang)
        jx = clx + 18 * s * math.cos(rad)
        jy = cly + 18 * s * math.sin(rad)
        ax.add_patch(Rectangle((jx - 6 * s, jy - 5 * s), 12 * s, 10 * s, fill=False, lw=1.1, angle=ang - 90))
        # scroll drive hint
        ax.plot([clx, jx], [cly, jy], "k--", lw=0.6)

    ax.text(clx, cly - R - 12, "SCROLL / CAM PLATE DRIVES 3 JAWS EQUALLY", ha="center", fontsize=7)
    view_label(ax, ox + w / 2, oy + h + 24, "FRONT — APERTURE ABOUT CL")

    # Note: buy vs build
    ax.add_patch(Rectangle((260, 120), 130, 80, fill=False, lw=1.0))
    ax.text(265, 190, "BUILD STRATEGY", fontsize=8, fontweight="bold", va="top")
    ax.text(265, 175, "• DIY: 3 cams on one knob shaft", fontsize=6.5, va="top")
    ax.text(265, 165, "• Or adapt mini lathe chuck nose", fontsize=6.5, va="top")
    ax.text(265, 155, "• Print spiral scroll only if", fontsize=6.5, va="top")
    ax.text(265, 145, "  willing to iterate fit", fontsize=6.5, va="top")
    ax.text(265, 130, "Recommended only if A–D", fontsize=6.5, va="top", style="italic")
    ax.text(265, 123, "fail your accuracy needs.", fontsize=6.5, va="top", style="italic")

    note_block(
        ax,
        25,
        85,
        [
            "Highest centering accuracy; highest fab cost. Keep as stretch goal.",
            "Jaw stroke must cover Ø1.5–38; scroll pitch sized accordingly.",
            "Mount scroll housing to same thumbscrew interface; aperture CL = C.",
        ],
    )
    save(sh, OUT / "WSFG-E0_three_jaw.png")


# ---------------------------------------------------------------------------
# Interface control drawing
# ---------------------------------------------------------------------------
def sheet_IF():
    sh = new_sheet("WSFG-IF", "MACHINE INTERFACE CONTROL DRAWING", scale="1:1", material="— (REFERENCE)")
    ax = sh.ax
    s = 1.0
    ox, oy = 90, 90
    clx, cly, w, h = _iface_front(ax, ox, oy, 0.9)
    s = 0.9

    dim_h(ax, ox + ((PLATE_W - A) / 2) * s, ox + ((PLATE_W + A) / 2) * s, oy + h + 18, f"A = {A:.0f}  (MEASURE)")
    dim_v(ax, oy, cly, ox - 20, f"C = {C:.0f}  (MEASURE)")
    dim_h(ax, ox, ox + w, oy - 18, f"{PLATE_W:.0f}  (FIT CHECK)")
    dim_v(ax, oy, oy + h, ox + w + 18, f"{PLATE_H:.0f}")
    ax.text(clx + 12, cly + 12, f"ØB = {B}", fontsize=8)
    view_label(ax, ox + w / 2, oy + h + 36, "MOUNTING FACE — LOOKING AT FEED")

    note_block(
        ax,
        25,
        70,
        [
            "CRITICAL: Measure A and C on your machine; revise all concept sheets before cutting metal/printing.",
            "Use OEM 5-hole plate as drill template for A if calipers are awkward.",
            "Centerline C = deepest point of driven V-roller projected to mounting face.",
            "All concept datums: vertical CL through midspan of A, horizontal CL at height C.",
        ],
    )
    save(sh, OUT / "WSFG-IF_machine_interface.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet_00_comparison()
    sheet_IF()
    sheet_A0()
    sheet_A1()
    sheet_B0()
    sheet_B1()
    sheet_B2()
    sheet_C0()
    sheet_C1()
    sheet_D0()
    sheet_D1()
    sheet_E0()
    print(f"Wrote {len(list(OUT.glob('*.png')))} sheets to {OUT}")


if __name__ == "__main__":
    main()
