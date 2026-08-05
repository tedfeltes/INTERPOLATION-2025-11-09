#!/usr/bin/env python3
"""Concept diagrams for the CREWORKS self-centering feed guide."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Circle, FancyArrowPatch, FancyBboxPatch, Polygon, Rectangle
from matplotlib.collections import LineCollection


OUT = Path(__file__).resolve().parent


def style_ax(ax, title: str) -> None:
    ax.set_aspect("equal")
    ax.axis("off")
    ax.set_title(title, fontsize=13, pad=12, fontweight="bold", color="#1a1a1a")


def draw_front(path: Path) -> None:
    fig, ax = plt.subplots(figsize=(10, 6.5), dpi=160)
    fig.patch.set_facecolor("#e8eef2")
    ax.set_facecolor("#e8eef2")

    # Machine head hint
    head = FancyBboxPatch(
        (-95, -55), 190, 120, boxstyle="round,pad=2,rounding_size=6",
        linewidth=1.5, edgecolor="#1f6f7a", facecolor="#2a9aa8", alpha=0.35, zorder=0,
    )
    ax.add_patch(head)

    # Mount plate
    plate = FancyBboxPatch(
        (-85, -50), 170, 100, boxstyle="round,pad=1,rounding_size=4",
        linewidth=2, edgecolor="#243447", facecolor="#6b7c8f", zorder=1,
    )
    ax.add_patch(plate)

    # Thumbscrews
    for x in (-70, 70):
        ax.add_patch(Circle((x, 5), 5, facecolor="#222", edgecolor="#111", zorder=5))
        ax.add_patch(Circle((x, 5), 2.2, facecolor="#888", zorder=6))

    # Jaws
    left = Polygon(
        [(-55, -30), (-12, -30), (-4, 5), (-12, 40), (-55, 40)],
        closed=True, facecolor="#cfd6de", edgecolor="#222", linewidth=1.5, zorder=3,
    )
    right = Polygon(
        [(55, -30), (12, -30), (4, 5), (12, 40), (55, 40)],
        closed=True, facecolor="#dfe4ea", edgecolor="#222", linewidth=1.5, zorder=3,
    )
    ax.add_patch(left)
    ax.add_patch(right)

    # Pinion
    ax.add_patch(Circle((0, 5), 9, facecolor="#c9973f", edgecolor="#5a3d10", linewidth=1.5, zorder=4))
    ax.add_patch(Circle((0, 5), 2.5, facecolor="#333", zorder=5))

    # Wire
    ax.add_patch(Circle((0, 5), 6, facecolor="#b87333", edgecolor="#6b3f12", linewidth=1.2, zorder=4))

    # Springs
    for x0, x1 in [(-78, -52), (78, 52)]:
        xs = [x0 + (x1 - x0) * i / 10 for i in range(11)]
        ys = [5 + (4 if i % 2 else -4) for i in range(11)]
        ys[0] = ys[-1] = 5
        ax.plot(xs, ys, color="#222", linewidth=1.4, zorder=4)

    # Arrows — self centering
    ax.add_patch(FancyArrowPatch((-48, -42), (-18, -42), arrowstyle="->", mutation_scale=14, color="#0b3d4a", lw=1.5))
    ax.add_patch(FancyArrowPatch((48, -42), (18, -42), arrowstyle="->", mutation_scale=14, color="#0b3d4a", lw=1.5))
    ax.text(0, -48, "jaws close equally → wire stays on centerline", ha="center", va="top", fontsize=9, color="#0b3d4a")

    ax.text(0, 58, "Replace OEM 5-hole plate · reuse thumbscrews", ha="center", fontsize=9, color="#243447")
    ax.text(-70, 18, "M", ha="center", fontsize=7, color="white", zorder=7)
    ax.text(70, 18, "M", ha="center", fontsize=7, color="white", zorder=7)

    style_ax(ax, "Front view — spring-loaded dual V-jaws + sync pinion")
    ax.set_xlim(-110, 110)
    ax.set_ylim(-70, 75)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def draw_section(path: Path) -> None:
    fig, ax = plt.subplots(figsize=(10, 5.5), dpi=160)
    fig.patch.set_facecolor("#f3efe6")
    ax.set_facecolor("#f3efe6")

    # Roller V
    roller = Polygon(
        [(-40, -10), (0, -35), (40, -10), (40, -5), (0, -28), (-40, -5)],
        closed=True, facecolor="#4a5560", edgecolor="#222", linewidth=1.5, zorder=2,
    )
    ax.add_patch(roller)
    ax.text(0, -42, "OEM V-roller (driven)", ha="center", fontsize=9, color="#222")

    # Blade
    ax.add_patch(Rectangle((-1.2, 8), 2.4, 36, facecolor="#bbb", edgecolor="#333", zorder=3))
    ax.text(8, 40, "Cutting blade", fontsize=9, color="#333")

    # Guide jaws ahead of nip
    jaw_l = Polygon([(-50, 0), (-8, 0), (-3, 10), (-8, 20), (-50, 20)], closed=True,
                    facecolor="#cfd6de", edgecolor="#222", zorder=4)
    jaw_r = Polygon([(50, 0), (8, 0), (3, 10), (8, 20), (50, 20)], closed=True,
                    facecolor="#dfe4ea", edgecolor="#222", zorder=4)
    ax.add_patch(jaw_l)
    ax.add_patch(jaw_r)

    # Flare
    flare = Polygon(
        [(-45, 55), (-12, 22), (12, 22), (45, 55)],
        closed=False, fill=False, edgecolor="#1f6f7a", linewidth=2.2, zorder=5,
    )
    # draw as lines
    ax.plot([-45, -12], [55, 22], color="#1f6f7a", lw=2.2)
    ax.plot([45, 12], [55, 22], color="#1f6f7a", lw=2.2)
    ax.plot([-12, 12], [22, 22], color="#1f6f7a", lw=2.2)
    ax.text(0, 60, "Lead-in flare — shove wire in roughly", ha="center", fontsize=9, color="#1f6f7a")

    # Wire path
    ax.plot([0, 0], [58, -30], color="#b87333", lw=5, solid_capstyle="round", zorder=3, alpha=0.85)
    ax.add_patch(FancyArrowPatch((0, 50), (0, 25), arrowstyle="->", mutation_scale=16, color="#6b3f12", lw=1.5))

    ax.text(55, 10, "Guide sits just\nahead of nip", fontsize=9, color="#222")
    style_ax(ax, "Side section — flare → jaws → roller/blade")
    ax.set_xlim(-70, 80)
    ax.set_ylim(-50, 70)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def draw_exploded(path: Path) -> None:
    fig, ax = plt.subplots(figsize=(11, 6), dpi=160)
    fig.patch.set_facecolor("#f7f7f7")
    ax.set_facecolor("#f7f7f7")

    def label(x, y, text):
        ax.text(x, y, text, ha="center", fontsize=8, color="#222")

    # Plate
    ax.add_patch(FancyBboxPatch((-40, -15), 80, 50, boxstyle="round,pad=1,rounding_size=3",
                                facecolor="#6b7c8f", edgecolor="#222", lw=1.5))
    label(0, -22, "1 Mount plate")

    # Jaws
    ax.add_patch(Polygon([(-95, 5), (-70, 5), (-65, 20), (-70, 35), (-95, 35)], closed=True,
                         facecolor="#cfd6de", edgecolor="#222"))
    ax.add_patch(Polygon([(95, 5), (70, 5), (65, 20), (70, 35), (95, 35)], closed=True,
                         facecolor="#dfe4ea", edgecolor="#222"))
    label(-80, -2, "2 Left jaw")
    label(80, -2, "3 Right jaw")

    # Pinion
    ax.add_patch(Circle((0, 70), 10, facecolor="#c9973f", edgecolor="#222"))
    label(0, 55, "4 Sync pinion")

    # Springs
    ax.plot([-110, -90], [20, 20], color="#222", lw=2)
    for i in range(6):
        ax.plot([-110 + i * 3, -108 + i * 3], [18, 22], color="#222", lw=1.2)
    label(-100, 8, "5 Springs (×2)")

    # Flare
    ax.plot([-25, -10], [100, 80], color="#1f6f7a", lw=2)
    ax.plot([25, 10], [100, 80], color="#1f6f7a", lw=2)
    ax.plot([-10, 10], [80, 80], color="#1f6f7a", lw=2)
    label(0, 108, "6 Lead-in flare")

    # Axle
    ax.add_patch(Rectangle((-1, 85), 2, 25, facecolor="#444", edgecolor="#111"))
    label(18, 95, "7 M5 axle")

    # Flow arrows
    ax.annotate("", xy=(0, 45), xytext=(0, 58),
                arrowprops=dict(arrowstyle="->", color="#666"))
    ax.annotate("", xy=(-45, 20), xytext=(-65, 20),
                arrowprops=dict(arrowstyle="->", color="#666"))
    ax.annotate("", xy=(45, 20), xytext=(65, 20),
                arrowprops=dict(arrowstyle="->", color="#666"))

    style_ax(ax, "Exploded kit — print 1–4 & 6, buy 5 & 7, reuse OEM thumbscrews")
    ax.set_xlim(-130, 130)
    ax.set_ylim(-35, 120)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def draw_size_range(path: Path) -> None:
    fig, ax = plt.subplots(figsize=(10, 4.8), dpi=160)
    fig.patch.set_facecolor("#eef2f5")
    ax.set_facecolor("#eef2f5")

    sizes = [(1.5, "1.5 mm"), (8, "8 mm"), (20, "20 mm"), (38, "38 mm")]
    y = 0.0
    for d, name in sizes:
        r = max(d / 2, 1.2)
        # Dual V-jaws (left / right), apexes on centerline
        left = Polygon(
            [(-40, y - 16), (-r, y - 16), (-0.5, y), (-r, y + 16), (-40, y + 16)],
            closed=True, facecolor="#cfd6de", edgecolor="#333", lw=1.2,
        )
        right = Polygon(
            [(40, y - 16), (r, y - 16), (0.5, y), (r, y + 16), (40, y + 16)],
            closed=True, facecolor="#dfe4ea", edgecolor="#333", lw=1.2,
        )
        ax.add_patch(left)
        ax.add_patch(right)
        ax.add_patch(Circle((0, y), r, facecolor="#b87333", edgecolor="#5a3210", lw=1, zorder=3))
        ax.axvline(0, color="#1f6f7a", lw=0.8, ls="--", alpha=0.5, ymin=0, ymax=1)
        ax.text(48, y, name, va="center", fontsize=10, color="#222")
        y += 42

    ax.plot([0, 0], [-28, y - 26], color="#1f6f7a", lw=1, ls="--", alpha=0.7)
    ax.text(0, -32, "Same jaws · same centerline · any diameter in range", ha="center", fontsize=10, color="#0b3d4a")
    style_ax(ax, "One guide covers the machine’s wire range")
    ax.set_xlim(-50, 70)
    ax.set_ylim(-40, y - 20)
    fig.tight_layout()
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    draw_front(OUT / "front_view.png")
    draw_section(OUT / "side_section.png")
    draw_exploded(OUT / "exploded.png")
    draw_size_range(OUT / "size_range.png")
    print(f"Wrote diagrams to {OUT}")


if __name__ == "__main__":
    main()
