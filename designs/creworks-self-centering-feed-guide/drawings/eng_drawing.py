"""Minimal shop-drawing helpers (ASME-ish) for matplotlib sheets."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Arc, Circle, FancyArrowPatch, FancyBboxPatch, Polygon, Rectangle
from matplotlib.lines import Line2D


# Sheet sizes in mm (matplotlib inches conversion)
IN = 25.4


@dataclass
class Sheet:
    fig: plt.Figure
    ax: plt.Axes
    W: float = 420.0  # A3 landscape mm
    H: float = 297.0
    margin: float = 10.0

    @property
    def draw_w(self) -> float:
        return self.W - 2 * self.margin

    @property
    def draw_h(self) -> float:
        return self.H - 2 * self.margin - 42  # title block height


def new_sheet(dwg_no: str, title: str, scale: str = "1:2", material: str = "SEE NOTES") -> Sheet:
    W, H = 420.0, 297.0
    fig = plt.subplots(figsize=(W / IN, H / IN), dpi=180)[0]
    fig.patch.set_facecolor("white")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_xlim(0, W)
    ax.set_ylim(0, H)
    ax.set_aspect("equal")
    ax.axis("off")

    # Outer / inner border
    ax.add_patch(Rectangle((5, 5), W - 10, H - 10, fill=False, lw=1.8, ec="black"))
    ax.add_patch(Rectangle((10, 10), W - 20, H - 20, fill=False, lw=0.7, ec="black"))

    # Title block (lower right)
    tb_x, tb_y, tb_w, tb_h = W - 200, 10, 190, 42
    ax.add_patch(Rectangle((tb_x, tb_y), tb_w, tb_h, fill=False, lw=1.2, ec="black"))
    # internal grid
    ax.plot([tb_x, tb_x + tb_w], [tb_y + 14, tb_y + 14], "k-", lw=0.6)
    ax.plot([tb_x, tb_x + tb_w], [tb_y + 28, tb_y + 28], "k-", lw=0.6)
    ax.plot([tb_x + 70, tb_x + 70], [tb_y, tb_y + 28], "k-", lw=0.6)
    ax.plot([tb_x + 130, tb_x + 130], [tb_y, tb_y + 28], "k-", lw=0.6)

    ax.text(tb_x + 3, tb_y + 32, title, fontsize=9, fontweight="bold", va="center")
    ax.text(tb_x + 3, tb_y + 20, f"DWG NO: {dwg_no}", fontsize=7, va="center")
    ax.text(tb_x + 73, tb_y + 20, f"SCALE: {scale}", fontsize=7, va="center")
    ax.text(tb_x + 133, tb_y + 20, "SHEET 1 OF 1", fontsize=7, va="center")
    ax.text(tb_x + 3, tb_y + 6, f"MATERIAL: {material}", fontsize=7, va="center")
    ax.text(tb_x + 73, tb_y + 6, "UNITS: mm", fontsize=7, va="center")
    ax.text(tb_x + 133, tb_y + 6, "TOL: ±0.5 UNLESS NOTED", fontsize=6.5, va="center")

    # Left revision / notes strip
    ax.text(12, H - 16, "CREWORKS FEED GUIDE — CONCEPT DESIGN PACKAGE", fontsize=8, fontweight="bold")
    ax.text(12, H - 24, "PROVISIONAL DIMENSIONS — VERIFY A, B, C ON MACHINE BEFORE FAB", fontsize=7, color="#333")

    # Third-angle projection symbol (simplified)
    px, py = W - 45, H - 35
    ax.add_patch(Circle((px, py), 5, fill=False, lw=0.8, ec="black"))
    ax.add_patch(Circle((px, py), 1.6, facecolor="black"))
    ax.add_patch(Rectangle((px + 9, py - 5), 3, 10, fill=False, lw=0.8, ec="black"))
    ax.text(px + 6, py - 12, "3rd ANGLE", fontsize=5.5, ha="center")

    # Rev block
    ax.add_patch(Rectangle((10, 10), 55, 42, fill=False, lw=0.8, ec="black"))
    ax.text(12, 44, "REV", fontsize=6, fontweight="bold")
    ax.text(28, 44, "DESCRIPTION", fontsize=6, fontweight="bold")
    ax.plot([10, 65], [40, 40], "k-", lw=0.5)
    ax.text(12, 32, "A", fontsize=6)
    ax.text(28, 32, "MULTI-CONCEPT PKG", fontsize=6)
    ax.text(12, 22, "—", fontsize=6)
    ax.text(28, 22, "DATE: 2026-08-05", fontsize=6)

    return Sheet(fig=fig, ax=ax, W=W, H=H)


def save(sheet: Sheet, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.fig.savefig(path, dpi=180, facecolor="white")
    plt.close(sheet.fig)


def _arrowheads_h(ax, x1, x2, y, size=2.2):
    """Filled arrowheads for horizontal dim line."""
    ax.annotate("", xy=(x1, y), xytext=(x1 + size, y),
                arrowprops=dict(arrowstyle="-|>", color="black", lw=0.7, mutation_scale=10))
    ax.annotate("", xy=(x2, y), xytext=(x2 - size, y),
                arrowprops=dict(arrowstyle="-|>", color="black", lw=0.7, mutation_scale=10))
    ax.plot([x1 + size * 0.6, x2 - size * 0.6], [y, y], "k-", lw=0.6)


def _arrowheads_v(ax, y1, y2, x, size=2.2):
    ax.annotate("", xy=(x, y1), xytext=(x, y1 + size),
                arrowprops=dict(arrowstyle="-|>", color="black", lw=0.7, mutation_scale=10))
    ax.annotate("", xy=(x, y2), xytext=(x, y2 - size),
                arrowprops=dict(arrowstyle="-|>", color="black", lw=0.7, mutation_scale=10))
    ax.plot([x, x], [y1 + size * 0.6, y2 - size * 0.6], "k-", lw=0.6)


def dim_h(ax, x1, x2, y, text=None, offset=0, fontsize=7):
    """Horizontal dimension between x1–x2 at height y."""
    if text is None:
        text = f"{abs(x2 - x1):.0f}"
    y = y + offset
    # extension lines from object up to dim line
    ax.plot([x1, x1], [y - 8, y + 1.5], "k-", lw=0.45)
    ax.plot([x2, x2], [y - 8, y + 1.5], "k-", lw=0.45)
    _arrowheads_h(ax, x1, x2, y)
    ax.text((x1 + x2) / 2, y + 2.2, text, ha="center", va="bottom", fontsize=fontsize)


def dim_v(ax, y1, y2, x, text=None, offset=0, fontsize=7):
    """Vertical dimension between y1–y2 at x."""
    if text is None:
        text = f"{abs(y2 - y1):.0f}"
    x = x + offset
    ax.plot([x - 1.5, x + 8], [y1, y1], "k-", lw=0.45)
    ax.plot([x - 1.5, x + 8], [y2, y2], "k-", lw=0.45)
    _arrowheads_v(ax, y1, y2, x)
    ax.text(x + 3.5, (y1 + y2) / 2, text, ha="left", va="center", fontsize=fontsize, rotation=90)


def centerline(ax, x1, y1, x2, y2):
    ax.plot([x1, x2], [y1, y2], color="black", lw=0.6, ls=(0, (6, 2, 1, 2)))


def view_label(ax, x, y, text):
    ax.text(x, y, text, ha="center", va="top", fontsize=8, fontweight="bold")
    ax.plot([x - 18, x + 18], [y - 2, y - 2], "k-", lw=0.8)


def note_block(ax, x, y, lines, title="NOTES:"):
    ax.text(x, y, title, fontsize=8, fontweight="bold", va="top")
    for i, line in enumerate(lines):
        ax.text(x, y - 6 - i * 5, f"{i + 1}. {line}", fontsize=6.5, va="top")


def section_arrows(ax, x1, y, x2, label="A"):
    ax.annotate("", xy=(x1, y), xytext=(x1 - 8, y), arrowprops=dict(arrowstyle="->", color="black", lw=1))
    ax.annotate("", xy=(x2, y), xytext=(x2 + 8, y), arrowprops=dict(arrowstyle="->", color="black", lw=1))
    ax.plot([x1, x2], [y, y], "k-", lw=0.8)
    ax.text(x1 - 10, y + 3, label, fontsize=8, fontweight="bold")
    ax.text(x2 + 6, y + 3, label, fontsize=8, fontweight="bold")
