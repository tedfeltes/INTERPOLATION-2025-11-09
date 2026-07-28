#!/usr/bin/env python3
"""Generate StakeDXF UI slide deck + install/usage/help tutorial PDFs.

The mockups in this file are drawn to match the *actual* Flutter UI in
mobile/stakedxf/lib/main.dart — rugged, futuristic, minimalist, hard
90° edges, mono telemetry text, safety-orange used only as a functional
accent.
"""

from __future__ import annotations

from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
DOCS = ROOT / "docs"
EXAMPLES = DIST / "plot_examples"
SHOTS = Path("/opt/cursor/artifacts/screenshots/plot_examples")
ART = Path("/opt/cursor/artifacts/screenshots/docs")
OUT_SLIDES = DIST / "StakeDXF_UI_Slide_Deck.pdf"
OUT_TUTORIAL = DIST / "StakeDXF_User_Guide.pdf"
OUT_HELP_MD = DOCS / "USER_GUIDE.md"
OUT_SLIDES_MD = DOCS / "UI_SLIDE_DECK.md"

# Instrument palette (mirrors lib/points/plot_ui_theme.dart)
BG = (0.031, 0.039, 0.047)      # #080A0C
CARD = (0.063, 0.075, 0.102)    # #10131A
ELEVATED = (0.086, 0.102, 0.133)  # #161A22
RAIL = (0.114, 0.133, 0.169)    # #1D222B
BORDER = (0.149, 0.169, 0.212)  # #262B36
BORDER_STRONG = (0.231, 0.255, 0.314)  # #3B4150
FG = (0.949, 0.957, 0.969)      # #F2F4F7
DIM = (0.780, 0.796, 0.820)     # #C7CBD1
MUTED = (0.478, 0.522, 0.584)   # #7A8595
ORANGE = (1.000, 0.353, 0.122)  # #FF5A1F
ORANGE_DIM = (0.310, 0.114, 0.043)
OK = (0.498, 0.878, 0.627)      # #7FE0A0
WARN = (0.949, 0.757, 0.353)    # #F2C15A
DANGER = (0.898, 0.282, 0.302)  # #E5484D
WHITE = (1, 1, 1)
BLACK = (0, 0, 0)

SLIDE_W, SLIDE_H = 1120, 630
PHONE_W, PHONE_H = 300, 600  # slightly taller for TSC5 feel

# LiberationSans / LiberationMono TTFs shipped with the app.
# fitz's Base 14 aliases (helv/hebo/heit/cour/tibo/…) silently drop unicode
# glyphs like `→` and `—`. Register the TTFs under NON-Base 14 names so our
# arrows and em-dashes render properly.
FONT_DIR = ROOT / "mobile" / "stakedxf" / "assets" / "fonts"
FONT_SANS = FONT_DIR / "LiberationSans-Regular.ttf"
FONT_SANS_BOLD = FONT_DIR / "LiberationSans-Bold.ttf"
FONT_MONO = FONT_DIR / "LiberationMono-Regular.ttf"
FONT_MONO_BOLD = FONT_DIR / "LiberationMono-Bold.ttf"

# NOTE: aliases MUST NOT collide with Base 14 shortcuts. Using distinct names.
F_BODY = "lsr"
F_BOLD = "lsb"
F_MONO = "lmr"
F_MONO_BOLD = "lmb"


def register_fonts(page: fitz.Page) -> None:
    page.insert_font(fontname=F_BODY, fontfile=str(FONT_SANS))
    page.insert_font(fontname=F_BOLD, fontfile=str(FONT_SANS_BOLD))
    page.insert_font(fontname=F_MONO, fontfile=str(FONT_MONO))
    page.insert_font(fontname=F_MONO_BOLD, fontfile=str(FONT_MONO_BOLD))


def new_slide(doc: fitz.Document, title: str | None = None) -> fitz.Page:
    page = doc.new_page(width=SLIDE_W, height=SLIDE_H)
    register_fonts(page)
    page.draw_rect(page.rect, color=None, fill=BG)
    # Instrument top ribbon
    ribbon = fitz.Rect(0, 0, SLIDE_W, 30)
    page.draw_rect(ribbon, color=None, fill=CARD)
    page.draw_line((0, 30), (SLIDE_W, 30), color=BORDER, width=1)
    page.draw_rect(fitz.Rect(20, 11, 28, 19), color=None, fill=ORANGE)
    page.insert_text((36, 20), "SDX  ·  v1.24", fontsize=9, fontname=F_MONO, color=DIM)
    # Right-side telemetry pills
    for i, (label, ok) in enumerate([("ONLINE", True), ("LOCAL", False)]):
        x = SLIDE_W - 40 - i * 90
        r = fitz.Rect(x - 60, 6, x, 24)
        page.draw_rect(r, color=OK if ok else BORDER, fill=None, width=1)
        page.draw_rect(fitz.Rect(r.x0 + 6, r.y0 + 6, r.x0 + 12, r.y0 + 12),
                       color=None, fill=OK if ok else MUTED)
        page.insert_text((r.x0 + 18, r.y0 + 12), label, fontsize=8,
                         fontname=F_MONO, color=OK if ok else MUTED)

    if title:
        page.insert_text(
            (36, 74),
            title.upper(),
            fontsize=24,
            fontname=F_BOLD,
            color=FG,
        )
        # Section rule under title
        page.draw_line((36, 88), (SLIDE_W - 36, 88), color=BORDER, width=1)
    return page


def footer(page: fitz.Page, n: int, total: int, label="STAKEDXF"):
    y = SLIDE_H - 22
    page.draw_line((36, y - 8), (SLIDE_W - 36, y - 8), color=BORDER, width=1)
    page.insert_text(
        (36, y + 4),
        f"{label} / TRIO FIELD OPS",
        fontsize=8, fontname=F_MONO, color=MUTED,
    )
    page.insert_text(
        (SLIDE_W - 100, y + 4),
        f"{n:02d} / {total:02d}",
        fontsize=8, fontname=F_MONO, color=MUTED,
    )


def bullet_block(page, x, y, lines, size=13, gap=24, color=FG, width=600):
    for i, line in enumerate(lines):
        # tick mark instead of bullet
        page.draw_rect(
            fitz.Rect(x, y + i * gap + 6, x + 8, y + i * gap + 8),
            color=None, fill=ORANGE,
        )
        page.insert_textbox(
            fitz.Rect(x + 16, y + i * gap, x + width, y + i * gap + gap),
            line,
            fontsize=size,
            fontname=F_BODY,
            color=color,
            align=fitz.TEXT_ALIGN_LEFT,
        )
    return y + len(lines) * gap


def draw_phone(page: fitz.Page, x: float, y: float, screen_drawer,
                content_height: int | None = None) -> None:
    """Draw a TSC5-ish handheld chrome and call screen_drawer(page, inner)."""
    phone_h = content_height if content_height is not None else PHONE_H
    outer = fitz.Rect(x - 10, y - 12, x + PHONE_W + 10, y + phone_h + 12)
    # Rugged bezel
    page.draw_rect(outer, color=BORDER_STRONG, fill=(0.02, 0.02, 0.03), width=2)
    # Screw dots
    for cx, cy in [(outer.x0 + 6, outer.y0 + 6),
                   (outer.x1 - 6, outer.y0 + 6),
                   (outer.x0 + 6, outer.y1 - 6),
                   (outer.x1 - 6, outer.y1 - 6)]:
        page.draw_circle((cx, cy), 2, color=BORDER_STRONG, fill=RAIL, width=0.5)
    # Screen
    screen = fitz.Rect(x, y, x + PHONE_W, y + phone_h)
    page.draw_rect(screen, color=None, fill=BG)
    # Instrument ribbon
    rib = fitz.Rect(screen.x0, screen.y0, screen.x1, screen.y0 + 24)
    page.draw_rect(rib, color=None, fill=CARD)
    page.draw_line((rib.x0, rib.y1), (rib.x1, rib.y1), color=BORDER, width=1)
    page.draw_rect(fitz.Rect(rib.x0 + 8, rib.y0 + 8, rib.x0 + 14, rib.y0 + 14),
                   color=None, fill=ORANGE)
    page.insert_text((rib.x0 + 20, rib.y0 + 15), "SDX · 09:41",
                     fontsize=7, fontname=F_MONO, color=DIM)
    _pill(page, rib.x1 - 82, rib.y0 + 4, rib.x1 - 32, rib.y0 + 20, "ONLINE", OK, True)
    # Bottom ID bar
    bot = fitz.Rect(screen.x0, screen.y1 - 18, screen.x1, screen.y1)
    page.draw_rect(bot, color=None, fill=CARD)
    page.draw_line((bot.x0, bot.y0), (bot.x1, bot.y0), color=BORDER, width=1)
    page.insert_text((bot.x0 + 8, bot.y0 + 12), "TRIO / FIELD OPS",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    page.insert_text((bot.x1 - 96, bot.y0 + 12), "NO CLOUD",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    content = fitz.Rect(screen.x0, rib.y1, screen.x1, bot.y0)
    screen_drawer(page, content)


def _pill(page, x0, y0, x1, y1, label, color, ok):
    r = fitz.Rect(x0, y0, x1, y1)
    page.draw_rect(r, color=color if ok else BORDER, fill=None, width=0.8)
    page.draw_rect(fitz.Rect(r.x0 + 4, r.y0 + 5, r.x0 + 9, r.y0 + 10),
                   color=None, fill=color if ok else MUTED)
    page.insert_text((r.x0 + 13, r.y0 + 12), label, fontsize=6,
                     fontname=F_MONO, color=color if ok else MUTED)


def _section_rule(page, x0, y, x1, label):
    page.insert_text((x0, y), label, fontsize=7, fontname=F_MONO, color=MUTED)
    page.draw_line((x0 + len(label) * 5 + 8, y - 3), (x1, y - 3),
                   color=BORDER, width=1)


def _corner_brackets(page, rect, color=ORANGE, length=14, stroke=1.6):
    """Camera-viewfinder brackets on the four corners of `rect`."""
    L = length
    for (x, y, dx, dy) in [
        (rect.x0, rect.y0, L, 0), (rect.x0, rect.y0, 0, L),
        (rect.x1 - L, rect.y0, L, 0), (rect.x1, rect.y0, 0, L),
        (rect.x0, rect.y1 - L, 0, L), (rect.x0, rect.y1, L, 0),
        (rect.x1 - L, rect.y1, L, 0), (rect.x1, rect.y1 - L, 0, L),
    ]:
        page.draw_line((x, y), (x + dx, y + dy), color=color, width=stroke)


def _before_after_slide(page):
    """Side-by-side proof-of-change: the retired v1.19 mock vs the v1.22 UI."""
    # --- BEFORE ---
    left = fitz.Rect(40, 120, 540, 560)
    # legacy forest-green palette from earlier generator revisions
    OLD_BG = (0.063, 0.086, 0.059)
    OLD_CARD = (0.086, 0.125, 0.078)
    OLD_TXT = (0.93, 0.93, 0.90)
    OLD_MUTED = (0.70, 0.72, 0.68)
    OLD_ACCENT = (0.894, 0.341, 0.180)
    page.draw_rect(left, color=None, fill=OLD_BG)
    page.draw_rect(left, color=DANGER, fill=None, width=2)
    # struck-through indicator
    page.draw_line((left.x0, left.y0), (left.x1, left.y1),
                   color=DANGER, width=1.4)
    page.draw_line((left.x1, left.y0), (left.x0, left.y1),
                   color=DANGER, width=1.4)
    page.insert_text((left.x0 + 20, left.y0 + 28), "v1.19  —  retired",
                     fontsize=12, fontname=F_MONO, color=DANGER)
    page.insert_text((left.x0 + 20, left.y0 + 90), "StakeDXF",
                     fontsize=32, fontname=F_BOLD, color=OLD_TXT)
    old_card = fitz.Rect(left.x0 + 20, left.y0 + 130,
                          left.x1 - 20, left.y0 + 200)
    page.draw_rect(old_card, color=OLD_ACCENT, fill=OLD_CARD, width=0.8)
    page.insert_text((old_card.x0 + 20, old_card.y0 + 28),
                     "≈  Convert DWG → DXF",
                     fontsize=13, fontname=F_BOLD, color=OLD_TXT)
    old_btn = fitz.Rect(left.x0 + 20, left.y0 + 220,
                         left.x1 - 20, left.y0 + 274)
    page.draw_rect(old_btn, color=None, fill=OLD_ACCENT)
    page.insert_text((old_btn.x0 + 60, old_btn.y0 + 34),
                     "Convert for Trimble Access",
                     fontsize=13, fontname=F_BOLD, color=BLACK)
    page.insert_textbox(
        fitz.Rect(left.x0 + 20, left.y0 + 320, left.x1 - 20, left.y1 - 20),
        "Soft cards. Rounded chrome. Forest wash. Marketing copy.\n"
        "Every version prior to v1.22 looked essentially the same.",
        fontsize=11, fontname=F_BODY, color=OLD_MUTED,
    )

    # --- AFTER ---
    right = fitz.Rect(580, 120, 1080, 560)
    page.draw_rect(right, color=None, fill=BG)
    _corner_brackets(page, right, color=OK, length=18, stroke=1.8)
    page.insert_text((right.x0 + 20, right.y0 + 28),
                     "v1.24  —  shipped",
                     fontsize=12, fontname=F_MONO, color=OK)
    # HERO
    page.insert_text((right.x0 + 20, right.y0 + 100), "STAKE",
                     fontsize=44, fontname=F_BOLD, color=FG)
    _sw = fitz.get_text_length("STAKE", fontname="hebo", fontsize=44)
    page.insert_text((right.x0 + 20 + _sw + 4, right.y0 + 100), "DXF",
                     fontsize=44, fontname=F_BOLD, color=ORANGE)
    page.draw_line((right.x0 + 20, right.y0 + 112),
                   (right.x1 - 20, right.y0 + 112),
                   color=BORDER, width=1)
    page.insert_text((right.x0 + 20, right.y0 + 130),
                     "FIELD-KIT  /  TSC5  /  TRIMBLE",
                     fontsize=9, fontname=F_MONO, color=MUTED)
    # action rail (mirrors the app)
    rail = fitz.Rect(right.x0 + 20, right.y0 + 158,
                      right.x1 - 20, right.y0 + 218)
    _action_rail(page, rail, "01", "CONVERT",
                  "DWG → DXF  ·  Civil 3D linework recovery",
                  primary=True)
    # primary button (matches the shipped chrome)
    btn = fitz.Rect(right.x0 + 20, right.y0 + 234,
                     right.x1 - 20, right.y0 + 284)
    _primary_button(page, btn, "RUN CONVERT")
    page.insert_textbox(
        fitz.Rect(right.x0 + 20, right.y0 + 300, right.x1 - 20, right.y1 - 20),
        "Hard 90° corners. Hairline rules. Mono telemetry. Safety-orange "
        "reserved for commands. Corner brackets frame the active field of "
        "view. Reads as a piece of ruggedized field kit — not an app.",
        fontsize=11, fontname=F_BODY, color=DIM,
    )


def _action_rail(page, rect, tag, title, detail, primary=True):
    page.draw_rect(rect, color=None, fill=CARD)
    # left rail
    page.draw_rect(fitz.Rect(rect.x0, rect.y0, rect.x0 + 4, rect.y1),
                   color=None, fill=ORANGE if primary else BORDER_STRONG)
    # hairline frame
    page.draw_rect(rect, color=BORDER, fill=None, width=0.8)
    # tag column
    page.insert_text((rect.x0 + 14, rect.y0 + 20), tag,
                     fontsize=8, fontname=F_MONO, color=MUTED)
    page.draw_line((rect.x0 + 38, rect.y0 + 8),
                   (rect.x0 + 38, rect.y1 - 8), color=BORDER, width=0.8)
    # title
    page.insert_text((rect.x0 + 50, rect.y0 + 24), title,
                     fontsize=14, fontname=F_BOLD, color=FG)
    page.insert_textbox(
        fitz.Rect(rect.x0 + 50, rect.y0 + 28, rect.x1 - 24, rect.y1 - 6),
        detail, fontsize=7, fontname=F_MONO, color=DIM,
    )
    # arrow
    ar_x = rect.x1 - 16
    ar_y = rect.y0 + (rect.height / 2)
    page.draw_line((ar_x - 8, ar_y), (ar_x, ar_y), color=ORANGE, width=1.4)
    page.draw_line((ar_x, ar_y), (ar_x - 4, ar_y - 4), color=ORANGE, width=1.4)
    page.draw_line((ar_x, ar_y), (ar_x - 4, ar_y + 4), color=ORANGE, width=1.4)


def _primary_button(page, rect, label):
    page.draw_rect(rect, color=None, fill=ORANGE)
    page.insert_text((rect.x0 + 14, rect.y0 + rect.height / 2 + 4),
                     label, fontsize=9, fontname=F_MONO, color=BLACK)
    ax = rect.x1 - 22
    page.draw_line((ax - 6, rect.y0 + rect.height / 2),
                   (ax, rect.y0 + rect.height / 2), color=BLACK, width=1.2)
    page.draw_line((ax, rect.y0 + rect.height / 2),
                   (ax - 3, rect.y0 + rect.height / 2 - 3), color=BLACK, width=1.2)
    page.draw_line((ax, rect.y0 + rect.height / 2),
                   (ax - 3, rect.y0 + rect.height / 2 + 3), color=BLACK, width=1.2)
    # left icon slot
    page.draw_rect(fitz.Rect(rect.x1 - 34, rect.y0, rect.x1 - 34, rect.y1),
                   color=BLACK, width=1)


def _tick(page, x, y, on=True):
    r = fitz.Rect(x, y, x + 9, y + 9)
    page.draw_rect(r, color=ORANGE if on else BORDER_STRONG,
                   fill=ORANGE if on else None, width=1)
    if on:
        page.draw_line((r.x0 + 2, r.y0 + 4.5),
                       (r.x0 + 4, r.y0 + 6.5), color=BLACK, width=1.2)
        page.draw_line((r.x0 + 4, r.y0 + 6.5),
                       (r.x0 + 7, r.y0 + 2.5), color=BLACK, width=1.2)


def ui_home(page, r: fitz.Rect):
    y = r.y0 + 16
    # STAKE + DXF hero — width measured against Base 14 as a metric proxy
    page.insert_text((r.x0 + 14, y + 30), "STAKE",
                     fontsize=32, fontname=F_BOLD, color=FG)
    _stake_w = fitz.get_text_length("STAKE", fontname="hebo", fontsize=32)
    page.insert_text((r.x0 + 14 + _stake_w + 3, y + 30), "DXF",
                     fontsize=32, fontname=F_BOLD, color=ORANGE)
    page.insert_text((r.x0 + 14, y + 44),
                     "FIELD-KIT / TSC5 / TRIMBLE",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    _section_rule(page, r.x0 + 14, y + 74, r.x1 - 14, "OPERATIONS")

    _action_rail(page,
                 fitz.Rect(r.x0 + 14, y + 84, r.x1 - 14, y + 148),
                 "01", "CONVERT",
                 "DWG → DXF · Civil 3D recovery")
    _action_rail(page,
                 fitz.Rect(r.x0 + 14, y + 156, r.x1 - 14, y + 220),
                 "02", "PLOT",
                 "Points + linework → scaled PDF")

    _section_rule(page, r.x0 + 14, y + 248, r.x1 - 14, "STATUS")
    cells = [("ENGINE", "LIBREDWG"), ("OUTPUT", "DXF R2010"), ("MODE", "ON-DEVICE")]
    cw = (r.width - 28) / len(cells)
    for i, (lbl, val) in enumerate(cells):
        cx0 = r.x0 + 14 + i * cw
        cx1 = cx0 + cw - 2
        cy0, cy1 = y + 258, y + 306
        page.draw_rect(fitz.Rect(cx0, cy0, cx1, cy1),
                       color=BORDER, fill=CARD, width=0.8)
        page.insert_text((cx0 + 6, cy0 + 14), lbl,
                         fontsize=6, fontname=F_MONO, color=MUTED)
        page.insert_text((cx0 + 6, cy0 + 32), val,
                         fontsize=9, fontname=F_MONO, color=FG)


def ui_convert(page, r: fitz.Rect):
    y = r.y0 + 12
    # Header (page title style)
    page.insert_text((r.x0 + 14, y + 12), "◂  CONVERT / DWG → DXF",
                     fontsize=8, fontname=F_MONO, color=ORANGE)
    y += 24
    # Input slot
    slot = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 60)
    page.draw_rect(slot, color=ORANGE, fill=CARD, width=1.4)
    page.insert_text((slot.x0 + 12, slot.y0 + 16), "DRAWING",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    page.insert_text((slot.x0 + 12, slot.y0 + 32), "ALPINE_HILLS.DWG",
                     fontsize=9, fontname=F_MONO, color=FG)
    page.insert_text((slot.x0 + 12, slot.y0 + 46),
                     "TRIO/PROJECTS/ALPINE/…",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    y = slot.y1 + 8
    _primary_button(page, fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 40),
                    "RUN CONVERT")
    y += 52
    # Result readout
    res = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 122)
    page.draw_rect(res, color=None, fill=CARD)
    page.draw_rect(res, color=BORDER, fill=None, width=0.8)
    page.draw_rect(fitz.Rect(res.x0, res.y0, res.x0 + 4, res.y1),
                   color=None, fill=OK)
    page.draw_rect(fitz.Rect(res.x0 + 12, res.y0 + 12,
                              res.x0 + 20, res.y0 + 20),
                   color=None, fill=OK)
    page.insert_text((res.x0 + 26, res.y0 + 20), "CONVERT / OK",
                     fontsize=7, fontname=F_MONO, color=OK)
    page.insert_text((res.x0 + 12, res.y0 + 40),
                     "RECOVERED 390 ENTITIES · 12 LAYERS",
                     fontsize=8, fontname=F_MONO, color=FG)
    kvs = [("STAKEABLE", "390"), ("LAYERS", "12"),
           ("PROXIES", "148"), ("FILE", "ALPINE_HILLS_TRIMBLE.DXF")]
    for i, (k, v) in enumerate(kvs):
        yy = res.y0 + 56 + i * 12
        page.insert_text((res.x0 + 12, yy), k,
                         fontsize=6, fontname=F_MONO, color=MUTED)
        page.insert_text((res.x0 + 68, yy), v,
                         fontsize=7, fontname=F_MONO, color=FG)
    y = res.y1 + 8
    # Layer checklist header
    lch = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 24)
    page.draw_rect(lch, color=None, fill=ELEVATED)
    page.draw_rect(lch, color=BORDER, fill=None, width=0.8)
    page.insert_text((lch.x0 + 10, lch.y0 + 15), "LAYERS",
                     fontsize=7, fontname=F_MONO, color=FG)
    page.insert_text((lch.x0 + 60, lch.y0 + 15), "3/12",
                     fontsize=7, fontname=F_MONO, color=ORANGE)
    page.insert_text((lch.x1 - 30, lch.y0 + 15), "ALL",
                     fontsize=7, fontname=F_MONO, color=ORANGE)
    # Layer rows
    layer_rows = [
        ("P-CURB", 390, True),
        ("P-U-STM", 649, True),
        ("P-CL", 124, True),
        ("DEFPOINTS", 26804, False),
        ("HATCH", 33, False),
    ]
    rowy = lch.y1
    for i, (name, cnt, on) in enumerate(layer_rows):
        rr = fitz.Rect(r.x0 + 14, rowy, r.x1 - 14, rowy + 20)
        page.draw_rect(rr, color=BORDER, fill=CARD, width=0.8)
        _tick(page, rr.x0 + 10, rr.y0 + 5, on=on)
        page.insert_text((rr.x0 + 28, rr.y0 + 13), name,
                         fontsize=7, fontname=F_MONO, color=FG)
        page.insert_text((rr.x1 - 8 - len(str(cnt)) * 4, rr.y0 + 13),
                         str(cnt), fontsize=7, fontname=F_MONO,
                         color=DIM if on else MUTED)
        rowy = rr.y1
    _primary_button(page,
                    fitz.Rect(r.x0 + 14, rowy + 8, r.x1 - 14, rowy + 44),
                    "SAVE DXF · 3 LAYERS")


def ui_export(page, r: fitz.Rect, mode="loaded"):
    y = r.y0 + 12
    page.insert_text((r.x0 + 14, y + 12), "◂  PLOT / EXPORT POINTS",
                     fontsize=8, fontname=F_MONO, color=ORANGE)
    y += 26
    # Job field slot
    slot = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 42)
    page.draw_rect(slot, color=BORDER, fill=CARD, width=0.8)
    page.insert_text((slot.x0 + 12, slot.y0 + 14), "JOB",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    page.insert_text((slot.x0 + 12, slot.y0 + 30), "ALPINE_HILLS",
                     fontsize=10, fontname=F_MONO, color=FG)
    y = slot.y1 + 8
    # Import buttons
    for label in ("IMPORT POINTS CSV", "LINK DXF LINEWORK"):
        rr = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 30)
        page.draw_rect(rr, color=BORDER_STRONG, fill=CARD, width=0.8)
        page.insert_text((rr.x0 + 14, rr.y0 + 19), label,
                         fontsize=8, fontname=F_MONO, color=FG)
        page.insert_text((rr.x1 - 22, rr.y0 + 19), "▸",
                         fontsize=9, fontname=F_BOLD, color=ORANGE)
        y = rr.y1 + 6
    if mode == "empty":
        page.insert_textbox(
            fitz.Rect(r.x0 + 14, y + 12, r.x1 - 14, y + 60),
            "IMPORT A PNEZD CSV\nFROM TRIMBLE ACCESS TO BEGIN.",
            fontsize=7, fontname=F_MONO, color=MUTED,
        )
        return
    # Section: PLOT OPTS
    _section_rule(page, r.x0 + 14, y + 12, r.x1 - 14, "PLOT OPTIONS")
    y += 22
    for label, value in (("MARKER", "LARGE X"),
                        ("LABEL", "NUM + ELEV"),
                        ("SCALE", "1\"=40'"),
                        ("SHEET", "ANSI B  11×17 LAND.")):
        rr = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 24)
        page.draw_rect(rr, color=BORDER, fill=CARD, width=0.8)
        page.insert_text((rr.x0 + 10, rr.y0 + 15), label,
                         fontsize=7, fontname=F_MONO, color=MUTED)
        page.insert_text((rr.x0 + 90, rr.y0 + 15), value,
                         fontsize=7, fontname=F_MONO, color=FG)
        y = rr.y1 + 4
    # Layer toggles (mini)
    y += 4
    _section_rule(page, r.x0 + 14, y, r.x1 - 14, "LAYERS 3/3")
    y += 12
    for layer in ("CL", "CURB", "STRUCT"):
        _tick(page, r.x0 + 16, y + 3, on=True)
        page.insert_text((r.x0 + 32, y + 11), layer,
                         fontsize=7, fontname=F_MONO, color=FG)
        y += 14
    # Bottom actions pinned near footer
    btn_y = r.y1 - 78
    _primary_button(page,
                    fitz.Rect(r.x0 + 14, btn_y, r.x1 - 14, btn_y + 36),
                    "CREATE STAKING PLOT PDF")
    y2 = btn_y + 42
    rr = fitz.Rect(r.x0 + 14, y2, r.x1 - 14, y2 + 28)
    page.draw_rect(rr, color=BORDER_STRONG, fill=CARD, width=0.8)
    page.insert_text((rr.x0 + 14, rr.y0 + 18), "EXPORT CSV",
                     fontsize=8, fontname=F_MONO, color=FG)


# ────────────────────────────────────────────────────────────────────────
# Sub-menu mockups (Civil 3D-style Layer Properties Manager + bottom sheets)
# ────────────────────────────────────────────────────────────────────────

def _tri(page, x, y, up=True, right=False, color=FG, size=5):
    """Draw a small vector triangle glyph (avoids missing Unicode arrows)."""
    if right:
        pts = [(x, y), (x + size, y + size / 2), (x, y + size)]
    elif up:
        pts = [(x, y + size), (x + size / 2, y), (x + size, y + size)]
    else:
        pts = [(x, y), (x + size / 2, y + size), (x + size, y)]
    page.draw_polyline(pts + [pts[0]], color=color, fill=color, width=0.4)

def _lpm_toolbar_icon(page, x, y, w, h, kind, enabled=True):
    r = fitz.Rect(x, y, x + w, y + h)
    page.draw_rect(r, color=BORDER, fill=RAIL, width=0.8)
    cx = (r.x0 + r.x1) / 2
    cy = (r.y0 + r.y1) / 2
    col = DIM if enabled else MUTED
    if kind == "bulb_on":
        page.draw_circle((cx, cy - 1), 3, color=WARN, fill=WARN, width=0.6)
        page.draw_line((cx - 2, cy + 3), (cx + 2, cy + 3), color=WARN, width=0.8)
    elif kind == "bulb_off":
        page.draw_circle((cx, cy - 1), 3, color=col, width=0.8)
        page.draw_line((cx - 2, cy + 3), (cx + 2, cy + 3), color=col, width=0.8)
    elif kind == "invert":
        page.draw_line((cx - 4, cy - 2), (cx + 4, cy - 2), color=col, width=0.9)
        page.draw_line((cx + 2, cy - 4), (cx + 4, cy - 2), color=col, width=0.9)
        page.draw_line((cx + 4, cy - 2), (cx + 2, cy), color=col, width=0.9)
        page.draw_line((cx - 4, cy + 2), (cx + 4, cy + 2), color=col, width=0.9)
        page.draw_line((cx - 2, cy), (cx - 4, cy + 2), color=col, width=0.9)
        page.draw_line((cx - 4, cy + 2), (cx - 2, cy + 4), color=col, width=0.9)
    elif kind == "lock":
        page.draw_rect(fitz.Rect(cx - 3, cy, cx + 3, cy + 4),
                       color=ORANGE, fill=ORANGE, width=0.6)
        page.draw_line((cx - 2, cy), (cx - 2, cy - 3), color=ORANGE, width=0.8)
        page.draw_line((cx + 2, cy), (cx + 2, cy - 3), color=ORANGE, width=0.8)
        page.draw_line((cx - 2, cy - 3), (cx + 2, cy - 3), color=ORANGE, width=0.8)
    elif kind == "unlock":
        page.draw_rect(fitz.Rect(cx - 3, cy, cx + 3, cy + 4),
                       color=col, width=0.6)
        page.draw_line((cx + 2, cy), (cx + 2, cy - 3), color=col, width=0.8)
        page.draw_line((cx - 2, cy - 3), (cx + 2, cy - 3), color=col, width=0.8)
    elif kind == "reset":
        page.draw_line((cx - 3, cy), (cx + 3, cy), color=col, width=0.9)
        page.draw_line((cx + 1, cy - 2), (cx + 3, cy), color=col, width=0.9)
        page.draw_line((cx + 3, cy), (cx + 1, cy + 2), color=col, width=0.9)
    elif kind == "reset_all":
        page.draw_circle((cx, cy), 3, color=col, width=0.9)
        page.draw_line((cx + 2, cy - 2), (cx + 4, cy - 4), color=col, width=0.9)
    elif kind == "refresh":
        page.draw_circle((cx, cy), 3, color=col, width=0.9)
        page.draw_line((cx + 3, cy - 1), (cx + 5, cy - 3), color=col, width=0.9)
        page.draw_line((cx + 3, cy - 1), (cx + 1, cy - 3), color=col, width=0.9)


def _lpm_column_swatch(page, x, y, w, h, argb_rgb):
    r = fitz.Rect(x, y, x + w, y + h)
    page.draw_rect(r, color=BORDER_STRONG, fill=argb_rgb, width=0.6)


def _lpm_linetype_preview(page, x, y, w, kind, color=FG):
    y0 = y
    if kind == "cont":
        page.draw_line((x, y0), (x + w, y0), color=color, width=1)
    elif kind == "dash":
        i = 0
        while i < w:
            page.draw_line((x + i, y0), (x + min(i + 4, w), y0),
                           color=color, width=1)
            i += 6
    elif kind == "dashdot":
        i = 0
        step = 0
        while i < w:
            seg = [4, 2, 1, 2][step % 4]
            if step % 2 == 0:
                page.draw_line((x + i, y0), (x + min(i + seg, w), y0),
                               color=color, width=1)
            i += seg
            step += 1
    elif kind == "dot":
        i = 0
        while i < w:
            page.draw_line((x + i, y0), (x + min(i + 1, w), y0),
                           color=color, width=1)
            i += 3
    elif kind == "hidden":
        i = 0
        while i < w:
            page.draw_line((x + i, y0), (x + min(i + 3, w), y0),
                           color=color, width=1)
            i += 5


def ui_layer_properties_manager(page, r: fitz.Rect):
    """Civil-3D-style Layer Properties Manager screen inside the phone."""
    x = r.x0
    # title bar (rail with orange marker)
    yy = r.y0
    tb = fitz.Rect(x, yy, r.x1, yy + 22)
    page.draw_rect(tb, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 4, x + 11, yy + 18),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "LAYER PROPERTIES MANAGER",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    page.insert_text((r.x1 - 60, yy + 15), "5 / 12 ON",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    page.draw_line((x, tb.y1), (r.x1, tb.y1), color=BORDER, width=1)
    yy = tb.y1

    # toolbar strip
    tool = fitz.Rect(x, yy, r.x1, yy + 26)
    page.draw_rect(tool, color=None, fill=ELEVATED)
    tx = x + 6
    for kind in ("bulb_on", "bulb_off", "invert"):
        _lpm_toolbar_icon(page, tx, yy + 4, 22, 18, kind); tx += 24
    page.draw_line((tx, yy + 6), (tx, yy + 20), color=BORDER, width=0.6)
    tx += 6
    for kind in ("lock", "unlock"):
        _lpm_toolbar_icon(page, tx, yy + 4, 22, 18, kind); tx += 24
    page.draw_line((tx, yy + 6), (tx, yy + 20), color=BORDER, width=0.6)
    tx += 6
    for kind in ("reset", "reset_all"):
        _lpm_toolbar_icon(page, tx, yy + 4, 22, 18, kind); tx += 24
    page.draw_line((tx, yy + 6), (tx, yy + 20), color=BORDER, width=0.6)
    tx += 6
    _lpm_toolbar_icon(page, tx, yy + 4, 22, 18, "refresh")
    page.draw_line((x, tool.y1), (r.x1, tool.y1), color=BORDER, width=1)
    yy = tool.y1

    # filter chip bar
    fb = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(fb, color=None, fill=CARD)
    page.insert_text((x + 8, yy + 15), "FILTER",
                     fontsize=6, fontname=F_MONO_BOLD, color=MUTED)
    fx = x + 46
    chips = [("ALL", True), ("ON", False), ("OFF", False), ("LOCKED", False), ("OVERRIDDEN", False)]
    for label, active in chips:
        w = len(label) * 4 + 12
        cr = fitz.Rect(fx, yy + 5, fx + w, yy + 19)
        page.draw_rect(cr, color=ORANGE if active else BORDER,
                       fill=ORANGE_DIM if active else MUTED,
                       width=1 if active else 0.6)
        page.insert_text((fx + 4, yy + 15), label, fontsize=6,
                         fontname=F_MONO_BOLD if active else F_MONO,
                         color=ORANGE if active else DIM)
        fx += w + 4
    page.draw_line((x, fb.y1), (r.x1, fb.y1), color=BORDER, width=1)
    yy = fb.y1

    # search bar
    sb = fitz.Rect(x, yy, r.x1, yy + 20)
    page.draw_rect(sb, color=None, fill=CARD)
    page.draw_circle((x + 12, yy + 10), 3, color=MUTED, width=0.8)
    page.draw_line((x + 14, yy + 12), (x + 17, yy + 15), color=MUTED, width=0.9)
    page.insert_text((x + 22, yy + 13), "Filter layers…",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    page.draw_line((x, sb.y1), (r.x1, sb.y1), color=BORDER, width=1)
    yy = sb.y1

    # ── grid area ──
    grid_top = yy
    name_col_w = 110
    # Column widths in the scrolling strip (mirrors the widget)
    on_w, frz_w, lk_w = 22, 22, 22
    color_w, lt_w, lw_w, tr_w, lts_w = 26, 46, 26, 26, 26
    header_h = 18
    row_h = 18

    # ── name column ──
    nb = fitz.Rect(x, yy, x + name_col_w, yy + header_h)
    page.draw_rect(nb, color=None, fill=ELEVATED)
    # up-arrow (drawn as a triangle so glyph coverage is irrelevant)
    _tri(page, x + 8, yy + 6, up=True, color=ORANGE)
    page.insert_text((x + 16, yy + 13), "NAME",
                     fontsize=6, fontname=F_MONO_BOLD, color=FG)
    page.insert_text((x + name_col_w - 24, yy + 13), "ENT",
                     fontsize=6, fontname=F_MONO_BOLD, color=MUTED)
    page.draw_line((x + name_col_w, yy), (x + name_col_w, r.y1),
                   color=BORDER_STRONG, width=1)
    page.draw_line((x, yy + header_h), (x + name_col_w, yy + header_h),
                   color=BORDER, width=1)

    # data-strip headers
    hx = x + name_col_w
    def _h(w, label, active=False):
        nonlocal hx
        hh = fitz.Rect(hx, yy, hx + w, yy + header_h)
        page.draw_rect(hh, color=None, fill=ELEVATED)
        page.insert_text((hx + 3, yy + 13), label,
                         fontsize=5.5,
                         fontname=F_MONO_BOLD,
                         color=ORANGE if active else DIM)
        page.draw_line((hh.x1, yy), (hh.x1, yy + header_h),
                       color=BORDER, width=0.6)
        hx += w

    _h(on_w, "On")
    _h(frz_w, "Frz")
    _h(lk_w, "Lk")
    _h(color_w, "COLOR", active=True)
    _h(lt_w, "LTYPE")
    _h(lw_w, "LW")
    _h(tr_w, "TR")
    _h(lts_w, "LTS")

    yy += header_h
    page.draw_line((x, yy), (r.x1, yy), color=BORDER, width=1)

    # rows
    rows = [
        ("P-CURB",       390, True, False, False, (1.0, 0.20, 0.20), "dash", "0.35", "30", "1.0", True),
        ("P-U-STM",      649, True, False, False, (0.30, 0.65, 1.0), "cont", "0.50", "20", "1.0", False),
        ("P-CL",         124, True, False, False, (1.00, 0.98, 0.20), "dashdot", "0.25", "0", "1.5", False),
        ("P-BLDG",        82, True, False, True,  (0.60, 0.60, 0.60), "cont", "0.70", "0", "1.0", False),
        ("HATCH",         33, False, True, False, (0.35, 0.30, 0.30), "hidden", "0.18", "40", "1.0", False),
        ("DEFPOINTS", 26804, False, False, False, (0.55, 0.55, 0.55), "dot", "0.18", "0", "1.0", False),
        ("P-VP",           4, True, False, True,  (0.20, 0.85, 0.40), "cont", "0.35", "0", "1.0", False),
        ("P-ROAD",       260, True, False, False, (0.95, 0.60, 0.20), "cont", "0.50", "0", "1.0", True),
    ]
    for i, (name, cnt, on, frz, locked, col, lt, lw, tr, lts, override) in enumerate(rows):
        zebra = fitz.utils.getColorList()  # not used; visual only
        row_bg = ELEVATED if i % 2 else CARD
        selected = (name == "P-CL")
        bg = ORANGE_DIM if selected else row_bg
        rr_name = fitz.Rect(x, yy, x + name_col_w, yy + row_h)
        page.draw_rect(rr_name, color=None, fill=bg)
        # left marker
        marker = fitz.Rect(x, yy, x + 3, yy + row_h)
        if selected:
            page.draw_rect(marker, color=None, fill=ORANGE)
        elif override:
            page.draw_rect(marker, color=None, fill=WARN)
        if selected:
            _tri(page, x + 8, yy + 6, up=False, right=True, color=ORANGE)
        elif locked:
            _draw_lock(page, fitz.Rect(x + 6, yy + 2, x + 16, yy + row_h - 2), True)
        page.insert_text((x + 18, yy + 12), name,
                         fontsize=6.5, fontname=F_MONO_BOLD if selected else F_MONO,
                         color=FG if on else MUTED)
        page.insert_text((x + name_col_w - 26, yy + 12), str(cnt),
                         fontsize=6, fontname=F_MONO, color=MUTED)
        page.draw_line((x, yy + row_h), (x + name_col_w, yy + row_h),
                       color=BORDER, width=0.6)

        # data strip
        rx = x + name_col_w
        strip = fitz.Rect(rx, yy, r.x1, yy + row_h)
        page.draw_rect(strip, color=None, fill=bg)

        def _cell(w, drawer):
            nonlocal rx
            cell = fitz.Rect(rx, yy, rx + w, yy + row_h)
            drawer(cell)
            page.draw_line((cell.x1, yy), (cell.x1, yy + row_h),
                           color=BORDER, width=0.5)
            rx += w

        _cell(on_w, lambda c: (
            page.draw_circle(((c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2 - 1),
                             2.4,
                             color=WARN if on else MUTED,
                             fill=WARN if on else None,
                             width=0.7),
        ))
        _cell(frz_w, lambda c: (
            _ice_or_sun(page, c, frz),
        ))
        _cell(lk_w, lambda c: (
            _draw_lock(page, c, locked),
        ))
        _cell(color_w, lambda c: (
            _lpm_column_swatch(page, c.x0 + 2, c.y0 + 4,
                                c.width - 4, c.height - 8, col),
        ))
        _cell(lt_w, lambda c: (
            _lpm_linetype_preview(page, c.x0 + 3, c.y0 + 10, 22, lt, color=col),
            page.insert_text((c.x0 + 28, c.y0 + 12),
                             {"cont": "CONT", "dash": "DASH", "dashdot": "DASHD",
                              "dot": "DOT", "hidden": "HIDD"}.get(lt, "CONT"),
                             fontsize=5.5, fontname=F_MONO,
                             color=FG if on else MUTED),
        ))
        _cell(lw_w, lambda c: page.insert_text(
            (c.x0 + 4, c.y0 + 12), lw,
            fontsize=6, fontname=F_MONO,
            color=FG if on else MUTED))
        _cell(tr_w, lambda c: page.insert_text(
            (c.x0 + 4, c.y0 + 12), tr,
            fontsize=6, fontname=F_MONO,
            color=FG if on else MUTED))
        _cell(lts_w, lambda c: page.insert_text(
            (c.x0 + 4, c.y0 + 12), lts,
            fontsize=6, fontname=F_MONO,
            color=FG if on else MUTED))

        page.draw_line((x, yy + row_h), (r.x1, yy + row_h),
                       color=BORDER, width=0.6)
        yy += row_h
        if yy + row_h > r.y1 - 28:
            break

    # footer: global LTS
    ft = fitz.Rect(x, r.y1 - 28, r.x1, r.y1)
    page.draw_rect(ft, color=None, fill=RAIL)
    page.draw_line((x, ft.y0), (r.x1, ft.y0), color=BORDER, width=1)
    page.insert_text((x + 8, ft.y0 + 12), "GLOBAL  LTS",
                     fontsize=6, fontname=F_MONO_BOLD, color=MUTED)
    tr_ = fitz.Rect(x + 62, ft.y0 + 12, r.x1 - 40, ft.y0 + 14)
    page.draw_line((tr_.x0, tr_.y0 + 1), (tr_.x1, tr_.y0 + 1),
                   color=BORDER, width=1)
    page.draw_line((tr_.x0, tr_.y0 + 1), (tr_.x0 + tr_.width * 0.4, tr_.y0 + 1),
                   color=ORANGE, width=1.4)
    page.draw_circle((tr_.x0 + tr_.width * 0.4, tr_.y0 + 1),
                     2.4, color=ORANGE, fill=ORANGE, width=0.4)
    page.insert_text((r.x1 - 36, ft.y0 + 15), "1.0",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)


def _ice_or_sun(page, c, frozen):
    cx = (c.x0 + c.x1) / 2
    cy = (c.y0 + c.y1) / 2
    if frozen:
        for angle in range(0, 180, 30):
            dx = 3
            page.draw_line((cx - dx, cy), (cx + dx, cy),
                           color=(0.44, 0.77, 1.00), width=0.7)
            # rotate a little via approximated angles
            page.draw_line((cx - 2, cy - 2), (cx + 2, cy + 2),
                           color=(0.44, 0.77, 1.00), width=0.7)
            page.draw_line((cx - 2, cy + 2), (cx + 2, cy - 2),
                           color=(0.44, 0.77, 1.00), width=0.7)
            break
    else:
        page.draw_circle((cx, cy), 1.8, color=MUTED, width=0.6)
        for a in ((cx - 3, cy), (cx + 3, cy), (cx, cy - 3), (cx, cy + 3)):
            page.draw_line((cx, cy), a, color=MUTED, width=0.5)


def _draw_lock(page, c, locked):
    cx = (c.x0 + c.x1) / 2
    cy = (c.y0 + c.y1) / 2
    col = ORANGE if locked else MUTED
    body = fitz.Rect(cx - 3, cy, cx + 3, cy + 4)
    if locked:
        page.draw_rect(body, color=col, fill=col, width=0.5)
        page.draw_line((cx - 2, cy), (cx - 2, cy - 3), color=col, width=0.8)
        page.draw_line((cx + 2, cy), (cx + 2, cy - 3), color=col, width=0.8)
        page.draw_line((cx - 2, cy - 3), (cx + 2, cy - 3), color=col, width=0.8)
    else:
        page.draw_rect(body, color=col, width=0.6)
        page.draw_line((cx + 2, cy), (cx + 2, cy - 3), color=col, width=0.8)
        page.draw_line((cx - 2, cy - 3), (cx + 2, cy - 3), color=col, width=0.8)


def ui_color_picker(page, r: fitz.Rect):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "LAYER COLOR — P-CL",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    # current swatch
    page.draw_rect(fitz.Rect(r.x1 - 30, yy + 5, r.x1 - 10, yy + 19),
                   color=BORDER_STRONG, fill=(1.0, 0.98, 0.20), width=0.6)
    yy = hd.y1
    page.draw_line((x, yy), (r.x1, yy), color=BORDER, width=1)

    # Tab bar
    tab = fitz.Rect(x, yy, r.x1, yy + 22)
    page.draw_rect(tab, color=None, fill=CARD)
    page.insert_text((x + 14, yy + 15), "ACI / CTB",
                     fontsize=7, fontname=F_MONO_BOLD, color=ORANGE)
    page.insert_text((x + 90, yy + 15), "True color",
                     fontsize=7, fontname=F_MONO, color=MUTED)
    page.draw_line((x + 8, yy + 21), (x + 74, yy + 21), color=ORANGE, width=2)
    page.draw_line((x, yy + 22), (r.x1, yy + 22), color=BORDER, width=1)
    yy = tab.y1 + 2

    # 10 × N ACI grid
    grid_left = x + 8
    grid_top = yy + 4
    cols = 10
    rows = 12
    sw = (r.x1 - x - 16) / cols
    sh = sw
    aci_colors = [
        (1.0, 0.0, 0.0), (1.0, 1.0, 0.0), (0.0, 1.0, 0.0),
        (0.0, 1.0, 1.0), (0.0, 0.0, 1.0), (1.0, 0.0, 1.0),
        (1.0, 1.0, 1.0), (0.55, 0.55, 0.55), (0.75, 0.75, 0.75),
        (0.99, 0.32, 0.10),
    ]
    for j in range(rows):
        for i in range(cols):
            idx = j * cols + i
            base = aci_colors[i % len(aci_colors)]
            shade = 1.0 - (j / (rows + 2))
            r_ = base[0] * shade
            g_ = base[1] * shade
            b_ = base[2] * shade
            rx = grid_left + i * sw
            ry = grid_top + j * sh
            page.draw_rect(fitz.Rect(rx + 1, ry + 1, rx + sw - 1, ry + sh - 1),
                           color=None, fill=(r_, g_, b_))
            if idx == 34:
                page.draw_rect(fitz.Rect(rx + 1, ry + 1, rx + sw - 1, ry + sh - 1),
                               color=ORANGE, width=1.4)

    # Numeric ACI input + Set/Apply CTAs — matches v1.25 color picker.
    bt = fitz.Rect(x + 8, r.y1 - 42, r.x1 - 8, r.y1 - 10)
    page.draw_rect(bt, color=BORDER_STRONG, fill=CARD, width=0.8)
    label_x = bt.x0 + 8
    page.insert_text((label_x, bt.y0 + 10), "ACI NUMBER",
                     fontsize=5.5, fontname=F_MONO, color=MUTED)
    page.insert_text((label_x, bt.y0 + 24), "34",
                     fontsize=10, fontname=F_MONO_BOLD, color=FG)
    # SET pill
    set_pill = fitz.Rect(bt.x1 - 96, bt.y0 + 6, bt.x1 - 56, bt.y0 + 26)
    page.draw_rect(set_pill, color=None, fill=ORANGE)
    page.insert_text((set_pill.x0 + 12, set_pill.y0 + 14), "SET",
                     fontsize=7, fontname=F_MONO_BOLD, color=BLACK)
    # APPLY pill
    apply_pill = fitz.Rect(bt.x1 - 48, bt.y0 + 6, bt.x1 - 8, bt.y0 + 26)
    page.draw_rect(apply_pill, color=ORANGE, fill=None, width=1.2)
    page.insert_text((apply_pill.x0 + 6, apply_pill.y0 + 14), "APPLY",
                     fontsize=7, fontname=F_MONO_BOLD, color=ORANGE)


def ui_truecolor(page, r: fitz.Rect):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "LAYER COLOR — P-CL",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    page.draw_rect(fitz.Rect(r.x1 - 30, yy + 5, r.x1 - 10, yy + 19),
                   color=BORDER_STRONG, fill=(1.00, 0.55, 0.10), width=0.6)
    yy = hd.y1
    page.draw_line((x, yy), (r.x1, yy), color=BORDER, width=1)
    tab = fitz.Rect(x, yy, r.x1, yy + 22)
    page.draw_rect(tab, color=None, fill=CARD)
    page.insert_text((x + 14, yy + 15), "ACI / CTB",
                     fontsize=7, fontname=F_MONO, color=MUTED)
    page.insert_text((x + 90, yy + 15), "True color",
                     fontsize=7, fontname=F_MONO_BOLD, color=ORANGE)
    page.draw_line((x + 84, yy + 21), (x + 164, yy + 21), color=ORANGE, width=2)
    page.draw_line((x, yy + 22), (r.x1, yy + 22), color=BORDER, width=1)
    yy = tab.y1 + 4

    # Big saturation×value gradient block
    sv = fitz.Rect(x + 8, yy, r.x1 - 8, yy + 100)
    # left = white, right = pure orange
    steps_x = 24
    steps_y = 10
    dx = sv.width / steps_x
    dy = sv.height / steps_y
    for i in range(steps_x):
        for j in range(steps_y):
            s = i / (steps_x - 1)
            v = 1.0 - j / (steps_y - 1)
            col = (1.0 * v + (1 - s) * (1 - v),
                   (0.55 * s) * v + (1 - s) * (1 - v),
                   (0.10 * s) * v + (1 - s) * (1 - v))
            rx = sv.x0 + i * dx
            ry = sv.y0 + j * dy
            page.draw_rect(fitz.Rect(rx, ry, rx + dx + 0.5, ry + dy + 0.5),
                           color=None, fill=col)
    page.draw_rect(sv, color=BORDER_STRONG, width=0.8)
    # crosshair
    page.draw_circle((sv.x0 + sv.width * 0.85, sv.y0 + sv.height * 0.35),
                     4, color=WHITE, width=1.4)

    # hue slider
    yy = sv.y1 + 8
    hue = fitz.Rect(x + 8, yy, r.x1 - 8, yy + 12)
    steps = 40
    dxh = hue.width / steps
    hues = [(1, 0, 0), (1, 0.6, 0), (1, 1, 0), (0.2, 1, 0),
            (0, 1, 0.6), (0, 1, 1), (0, 0.6, 1), (0, 0, 1),
            (0.6, 0, 1), (1, 0, 0.6), (1, 0, 0)]
    for i in range(steps):
        t = i / (steps - 1)
        seg = min(int(t * (len(hues) - 1)), len(hues) - 2)
        frac = t * (len(hues) - 1) - seg
        h0 = hues[seg]
        h1 = hues[seg + 1]
        col = (h0[0] * (1 - frac) + h1[0] * frac,
               h0[1] * (1 - frac) + h1[1] * frac,
               h0[2] * (1 - frac) + h1[2] * frac)
        page.draw_rect(fitz.Rect(hue.x0 + i * dxh, hue.y0,
                                 hue.x0 + (i + 1) * dxh + 0.5, hue.y1),
                       color=None, fill=col)
    page.draw_rect(hue, color=BORDER_STRONG, width=0.6)
    page.draw_rect(fitz.Rect(hue.x0 + hue.width * 0.10 - 2, hue.y0 - 1,
                             hue.x0 + hue.width * 0.10 + 2, hue.y1 + 1),
                   color=WHITE, width=1)

    yy = hue.y1 + 8
    # RGB readout
    for i, (lbl, val) in enumerate([("R", "FF"), ("G", "8C"), ("B", "1A")]):
        rx = x + 8 + i * 60
        page.insert_text((rx, yy + 12), f"{lbl}  {val}",
                         fontsize=8, fontname=F_MONO, color=FG)
    yy += 22
    # apply button
    bt = fitz.Rect(x + 8, r.y1 - 34, r.x1 - 8, r.y1 - 10)
    page.draw_rect(bt, color=None, fill=ORANGE)
    page.insert_text((bt.x0 + 10, bt.y0 + 15), "APPLY  #FF8C1A",
                     fontsize=8, fontname=F_MONO_BOLD, color=BLACK)


def ui_linetype_sheet(page, r: fitz.Rect):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "LINETYPE — P-CL",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    yy = hd.y1
    page.draw_line((x, yy), (r.x1, yy), color=BORDER, width=1)
    yy += 4
    entries = [
        ("CONTINUOUS", "cont"),
        ("DASHED",     "dash"),
        ("DASHED2",    "dash"),
        ("DASHDOT",    "dashdot"),
        ("DASHDOT2",   "dashdot"),
        ("HIDDEN",     "hidden"),
        ("HIDDEN2",    "hidden"),
        ("DOT",        "dot"),
        ("DOT2",       "dot"),
        ("BORDER",     "dashdot"),
        ("CENTER",     "dashdot"),
        ("PHANTOM",    "dashdot"),
    ]
    for name, kind in entries:
        rr = fitz.Rect(x + 8, yy, r.x1 - 8, yy + 22)
        page.draw_line((rr.x0, rr.y1), (rr.x1, rr.y1),
                       color=BORDER, width=0.6)
        _lpm_linetype_preview(page, rr.x0, rr.y0 + 12, 60, kind, color=DIM)
        page.insert_text((rr.x0 + 72, rr.y0 + 15), name,
                         fontsize=7, fontname=F_MONO, color=FG)
        yy += 22
        if yy > r.y1 - 44:
            break
    bt = fitz.Rect(x + 8, r.y1 - 34, r.x1 - 8, r.y1 - 10)
    page.draw_rect(bt, color=BORDER_STRONG, fill=CARD, width=0.8)
    page.insert_text((bt.x0 + 10, bt.y0 + 15), "BYLAYER DEFAULT",
                     fontsize=7, fontname=F_MONO, color=DIM)


def ui_lineweight_sheet(page, r: fitz.Rect):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "LINEWEIGHT (pt) — P-CL",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    yy = hd.y1
    page.draw_line((x, yy), (r.x1, yy), color=BORDER, width=1)
    yy += 4
    for w in (0.18, 0.25, 0.35, 0.50, 0.70, 1.00, 1.40, 2.00):
        rr = fitz.Rect(x + 8, yy, r.x1 - 8, yy + 26)
        page.draw_line((rr.x0, rr.y1), (rr.x1, rr.y1),
                       color=BORDER, width=0.6)
        page.draw_line((rr.x0 + 8, rr.y0 + 13), (rr.x0 + 58, rr.y0 + 13),
                       color=FG, width=w * 1.4)
        page.insert_text((rr.x0 + 72, rr.y0 + 16), f"{w:.2f}",
                         fontsize=8, fontname=F_MONO, color=FG)
        yy += 26
        if yy > r.y1 - 44:
            break
    bt = fitz.Rect(x + 8, r.y1 - 34, r.x1 - 8, r.y1 - 10)
    page.draw_rect(bt, color=BORDER_STRONG, fill=CARD, width=0.8)
    page.insert_text((bt.x0 + 10, bt.y0 + 15), "BYLAYER / CTB DEFAULT",
                     fontsize=7, fontname=F_MONO, color=DIM)


def _slider_sheet(page, r: fitz.Rect, title, value_label, orange_frac,
                  apply_label="APPLY"):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), title,
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    yy = hd.y1
    page.draw_line((x, yy), (r.x1, yy), color=BORDER, width=1)
    # Slider
    sy = yy + 44
    sr = fitz.Rect(x + 16, sy, r.x1 - 16, sy + 2)
    page.draw_line((sr.x0, sr.y0 + 1), (sr.x1, sr.y0 + 1),
                   color=BORDER, width=1)
    page.draw_line((sr.x0, sr.y0 + 1),
                   (sr.x0 + sr.width * orange_frac, sr.y0 + 1),
                   color=ORANGE, width=1.6)
    page.draw_circle((sr.x0 + sr.width * orange_frac, sr.y0 + 1),
                     3.4, color=ORANGE, fill=ORANGE, width=0.5)
    page.insert_text((sr.x0, sr.y1 + 22),
                     value_label,
                     fontsize=10, fontname=F_MONO_BOLD, color=FG)
    # Reset + apply
    reset = fitz.Rect(x + 8, r.y1 - 34, x + 90, r.y1 - 10)
    apply = fitz.Rect(r.x1 - 100, r.y1 - 34, r.x1 - 8, r.y1 - 10)
    page.draw_rect(reset, color=BORDER_STRONG, fill=CARD, width=0.8)
    page.insert_text((reset.x0 + 24, reset.y0 + 15), "RESET",
                     fontsize=7, fontname=F_MONO, color=DIM)
    page.draw_rect(apply, color=None, fill=ORANGE)
    page.insert_text((apply.x0 + 22, apply.y0 + 15), apply_label,
                     fontsize=7, fontname=F_MONO_BOLD, color=BLACK)


def ui_transparency_sheet(page, r):
    _slider_sheet(page, r, "TRANSPARENCY — P-CL",
                  "OPACITY  75%   ·   TRANS  25%",
                  orange_frac=0.75)


def ui_ltscale_sheet(page, r):
    _slider_sheet(page, r, "LINETYPE SCALE — P-CL", "1.50", 0.15 / 20)


def ui_linework_panel(page, r):
    x = r.x0
    yy = r.y0 + 8
    page.insert_text((x + 14, yy + 12), "◂  LINEWORK  ·  P-CURB · LWPOLYLINE",
                     fontsize=8, fontname=F_MONO, color=ORANGE)
    yy += 22
    # Preview strip
    prev = fitz.Rect(x + 12, yy, r.x1 - 12, yy + 44)
    page.draw_rect(prev, color=BORDER, fill=CARD, width=0.8)
    page.draw_line((prev.x0 + 12, prev.y0 + 22),
                   (prev.x1 - 12, prev.y0 + 22), color=(1.0, 0.2, 0.2), width=1.4)
    page.insert_text((prev.x0 + 8, prev.y0 + 40), "SEG 3 / 12  ·  53.42 LF",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    yy = prev.y1 + 8
    # Rows
    rows = [
        ("LAYER",   "P-CURB"),
        ("COLOR",   "ACI 1  RED"),
        ("LINETYPE", "DASHED"),
        ("WEIGHT",  "0.35 pt"),
        ("SCALE",   "1.0"),
        ("TRANS",   "30 %"),
        ("SEG LEN", "53.42 ft"),
    ]
    for k, v in rows:
        rr = fitz.Rect(x + 12, yy, r.x1 - 12, yy + 22)
        page.draw_rect(rr, color=BORDER, fill=CARD, width=0.6)
        page.insert_text((rr.x0 + 8, rr.y0 + 15), k,
                         fontsize=7, fontname=F_MONO, color=MUTED)
        page.insert_text((rr.x0 + 90, rr.y0 + 15), v,
                         fontsize=7, fontname=F_MONO_BOLD, color=FG)
        yy = rr.y1 + 3
    # Actions
    yy += 4
    for label, kind in (("TRIM SEGMENT", False), ("DELETE SEGMENT", False), ("CLEAR SELECTION", True)):
        rr = fitz.Rect(x + 12, yy, r.x1 - 12, yy + 24)
        page.draw_rect(rr, color=None,
                       fill=(ORANGE if kind else CARD))
        page.draw_rect(rr, color=BORDER_STRONG if not kind else None, width=0.8)
        page.insert_text((rr.x0 + 12, rr.y0 + 16), label,
                         fontsize=7, fontname=F_MONO_BOLD,
                         color=BLACK if kind else FG)
        yy = rr.y1 + 6


def ui_point_properties(page, r):
    x = r.x0
    yy = r.y0 + 8
    page.insert_text((x + 14, yy + 12), "◂  POINT  ·  #142",
                     fontsize=8, fontname=F_MONO, color=ORANGE)
    yy += 22
    prev = fitz.Rect(x + 12, yy, r.x1 - 12, yy + 44)
    page.draw_rect(prev, color=BORDER, fill=CARD, width=0.8)
    # X-shaped marker
    cx = (prev.x0 + prev.x1) / 2
    cy = (prev.y0 + prev.y1) / 2
    page.draw_line((cx - 8, cy - 8), (cx + 8, cy + 8), color=ORANGE, width=1.6)
    page.draw_line((cx - 8, cy + 8), (cx + 8, cy - 8), color=ORANGE, width=1.6)
    page.insert_text((cx + 10, cy + 2), "#142  EL 1218.42",
                     fontsize=6, fontname=F_MONO, color=DIM)
    yy = prev.y1 + 8
    for k, v in (("PT #", "142"),
                 ("NORTH", "6,241,822.145"),
                 ("EAST", "1,842,633.911"),
                 ("ELEV", "1218.42 ft"),
                 ("DESC", "CURB RETURN"),
                 ("LABEL", "#  +  ELEV"),
                 ("MARKER", "LARGE X"),
                 ("OFFSET", "dN 0.20  dE 0.15")):
        rr = fitz.Rect(x + 12, yy, r.x1 - 12, yy + 20)
        page.draw_rect(rr, color=BORDER, fill=CARD, width=0.6)
        page.insert_text((rr.x0 + 8, rr.y0 + 14), k,
                         fontsize=6.5, fontname=F_MONO, color=MUTED)
        page.insert_text((rr.x0 + 74, rr.y0 + 14), v,
                         fontsize=6.5, fontname=F_MONO_BOLD, color=FG)
        yy = rr.y1 + 3
    yy += 2
    # actions
    for label, primary in (("MOVE LABEL", False), ("HIDE POINT", False), ("RESET OFFSET", True)):
        rr = fitz.Rect(x + 12, yy, r.x1 - 12, yy + 22)
        page.draw_rect(rr, color=None,
                       fill=(ORANGE if primary else CARD))
        page.draw_rect(rr, color=BORDER_STRONG if not primary else None, width=0.8)
        page.insert_text((rr.x0 + 12, rr.y0 + 15), label,
                         fontsize=7, fontname=F_MONO_BOLD,
                         color=BLACK if primary else FG)
        yy = rr.y1 + 6


def ui_text_style(page, r):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "TEXT STYLE",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    yy = hd.y1 + 4
    entries = [
        ("STANDARD", "arial", 3.0),
        ("ROMANS",   "romans", 2.4),
        ("ROMAND",   "romand", 2.5),
        ("ITALIC",   "italic", 2.4),
        ("MONO",     "mono", 2.2),
        ("SANS-B",   "sans-b", 3.2),
    ]
    for name, sample, height in entries:
        rr = fitz.Rect(x + 8, yy, r.x1 - 8, yy + 30)
        page.draw_rect(rr, color=BORDER, fill=CARD, width=0.6)
        page.insert_text((rr.x0 + 10, rr.y0 + 12), name,
                         fontsize=7, fontname=F_MONO_BOLD, color=FG)
        page.insert_text((rr.x0 + 10, rr.y0 + 24),
                         f"h {height:.1f} mm  ·  0.90 W",
                         fontsize=6, fontname=F_MONO, color=MUTED)
        # preview
        page.insert_text((rr.x1 - 90, rr.y0 + 22), "142 ELEV 1218.42",
                         fontsize=8,
                         fontname=F_MONO if "mono" in sample else F_BOLD,
                         color=DIM)
        yy = rr.y1 + 6


def ui_symbol_library(page, r):
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "SYMBOL LIBRARY",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    yy = hd.y1 + 4
    # category chips
    chips = ["ALL", "UTILITY", "STRUCT", "SURVEY", "DWG BLOCKS"]
    fx = x + 8
    for i, name in enumerate(chips):
        w = len(name) * 4 + 12
        active = i == 1
        page.draw_rect(fitz.Rect(fx, yy, fx + w, yy + 16),
                       color=ORANGE if active else BORDER,
                       fill=ORANGE_DIM if active else CARD, width=0.8)
        page.insert_text((fx + 4, yy + 12), name,
                         fontsize=6, fontname=F_MONO_BOLD,
                         color=ORANGE if active else DIM)
        fx += w + 4
    yy += 22

    def _mh(cx, cy):
        page.draw_circle((cx, cy), 5, color=DIM, width=1)
        page.draw_line((cx - 3, cy), (cx + 3, cy), color=DIM, width=0.8)
    def _hyd(cx, cy):
        page.draw_rect(fitz.Rect(cx - 3, cy - 4, cx + 3, cy + 4), color=ORANGE, width=1)
        page.draw_line((cx, cy - 5), (cx, cy + 5), color=ORANGE, width=0.8)
    def _wv(cx, cy):
        page.draw_circle((cx, cy), 4, color=DIM, width=1)
        page.draw_line((cx - 3, cy - 3), (cx + 3, cy + 3), color=DIM, width=0.8)
        page.draw_line((cx + 3, cy - 3), (cx - 3, cy + 3), color=DIM, width=0.8)
    def _sign(cx, cy):
        page.draw_line((cx, cy - 5), (cx, cy + 4), color=DIM, width=1)
        page.draw_rect(fitz.Rect(cx - 4, cy - 6, cx + 4, cy - 2), color=DIM, width=1)
    def _cb(cx, cy):
        page.draw_rect(fitz.Rect(cx - 5, cy - 3, cx + 5, cy + 3), color=DIM, width=1)
        page.draw_line((cx - 3, cy), (cx + 3, cy), color=DIM, width=0.6)
    def _tree(cx, cy):
        page.draw_circle((cx, cy - 2), 4, color=OK, width=1)
        page.draw_line((cx, cy + 2), (cx, cy + 5), color=OK, width=1)
    icons = [("MANHOLE", _mh), ("HYDRANT", _hyd),
             ("W-VALVE", _wv), ("SIGN", _sign),
             ("CATCH B", _cb), ("TREE", _tree)]
    grid_w = (r.x1 - r.x0 - 16)
    cell_w = grid_w / 3
    for i, (label, drawer) in enumerate(icons):
        col = i % 3
        row = i // 3
        cx = x + 8 + col * cell_w + cell_w / 2
        cy_row = yy + row * 74
        card_r = fitz.Rect(x + 8 + col * cell_w + 4, cy_row,
                            x + 8 + (col + 1) * cell_w - 4, cy_row + 66)
        page.draw_rect(card_r, color=BORDER, fill=CARD, width=0.6)
        drawer(cx, cy_row + 22)
        page.insert_text((card_r.x0 + 6, card_r.y1 - 8), label,
                         fontsize=6.5, fontname=F_MONO, color=DIM)


def ui_plot_preview(page, r):
    """
    ANSI full-bleed staking plot preview:
      * No border, no cream panel, no grid, no title block band.
      * No bounding box, no scale text, no north arrow, no sheet callout.
      * The only overlay is an OPTIONAL draggable plot title (paper-space).
    """
    x = r.x0
    yy = r.y0 + 8
    page.insert_text((x + 14, yy + 12), "◂  PLOT PREVIEW",
                     fontsize=8, fontname=F_MONO, color=ORANGE)
    yy += 20
    # Full-bleed sheet: white paper, hairline outline only.
    sheet = fitz.Rect(x + 10, yy, r.x1 - 10, r.y1 - 46)
    page.draw_rect(sheet, color=BORDER, fill=(0.97, 0.97, 0.98), width=0.6)

    # Layer-colored linework (parcel lines, curbs) — thin, edge-to-edge.
    parcels = [
        (sheet.x0 + 6,  sheet.y0 + 12, sheet.x1 - 6,  sheet.y0 + 20),
        (sheet.x0 + 6,  sheet.y0 + 40, sheet.x1 - 6,  sheet.y0 + 42),
        (sheet.x0 + 6,  sheet.y0 + 66, sheet.x1 - 6,  sheet.y0 + 60),
        (sheet.x0 + 60, sheet.y0 + 12, sheet.x0 + 62, sheet.y1 - 8),
        (sheet.x0 + 130, sheet.y0 + 12, sheet.x0 + 134, sheet.y1 - 8),
        (sheet.x0 + 200, sheet.y0 + 12, sheet.x0 + 204, sheet.y1 - 8),
    ]
    for x0, y0, x1, y1 in parcels:
        page.draw_line((x0, y0), (x1, y1), color=(0.35, 0.35, 0.40), width=0.4)

    curb = [
        (sheet.x0 + 20, sheet.y0 + 90, sheet.x0 + 120, sheet.y0 + 95),
        (sheet.x0 + 120, sheet.y0 + 95, sheet.x0 + 190, sheet.y0 + 78),
        (sheet.x0 + 190, sheet.y0 + 78, sheet.x1 - 30, sheet.y0 + 62),
    ]
    for x0, y0, x1, y1 in curb:
        page.draw_line((x0, y0), (x1, y1), color=(0.10, 0.10, 0.10), width=0.9)

    # Red stake crosses with numbered leaders — matches PDF output.
    pts = [
        (sheet.x0 + 55, sheet.y0 + 92, "101"),
        (sheet.x0 + 100, sheet.y0 + 94, "102"),
        (sheet.x0 + 155, sheet.y0 + 86, "103"),
        (sheet.x0 + 205, sheet.y0 + 76, "104"),
        (sheet.x1 - 40, sheet.y0 + 66, "105"),
    ]
    red = (0.82, 0.13, 0.15)
    for px, py, lbl in pts:
        page.draw_line((px - 3.5, py - 3.5), (px + 3.5, py + 3.5),
                       color=red, width=0.9)
        page.draw_line((px - 3.5, py + 3.5), (px + 3.5, py - 3.5),
                       color=red, width=0.9)
        page.insert_text((px + 5, py - 3), lbl,
                         fontsize=5, fontname=F_MONO, color=red)

    # Optional draggable plot title, centred near the top of the sheet.
    # This is now the ONLY overlay — no bounding box, no scale text, no
    # north arrow, no sheet-size callout on the plotted sheet itself.
    title_text = "ALPINE HILLS"
    title_size = 12
    title_w = len(title_text) * title_size * 0.55
    title_cx = (sheet.x0 + sheet.x1) / 2
    title_y = sheet.y0 + 18
    page.insert_text((title_cx - title_w / 2, title_y),
                     title_text,
                     fontsize=title_size, fontname=F_BOLD,
                     color=(0.06, 0.07, 0.09))
    # Dashed outline to hint "draggable" — the outline is preview UI only,
    # it never prints.
    dash = fitz.Rect(title_cx - title_w / 2 - 3, title_y - title_size,
                     title_cx + title_w / 2 + 3, title_y + 3)
    for step in range(int(dash.width // 4)):
        sx = dash.x0 + step * 4
        page.draw_line((sx, dash.y0), (min(sx + 2, dash.x1), dash.y0),
                       color=ORANGE, width=0.5)
        page.draw_line((sx, dash.y1), (min(sx + 2, dash.x1), dash.y1),
                       color=ORANGE, width=0.5)

    # Bottom action bar (save)
    ba = fitz.Rect(x + 10, r.y1 - 38, r.x1 - 10, r.y1 - 14)
    page.draw_rect(ba, color=None, fill=ORANGE)
    page.insert_text((ba.x0 + 10, ba.y0 + 16), "SAVE PLOT PDF",
                     fontsize=8, fontname=F_MONO_BOLD, color=BLACK)


def ui_templates(page, r):
    """
    Sheet template picker — every entry is ANSI full-bleed. The picker only
    selects size (A/B/C/D) × orientation (portrait/landscape).
    """
    x = r.x0
    yy = r.y0
    hd = fitz.Rect(x, yy, r.x1, yy + 24)
    page.draw_rect(hd, color=None, fill=RAIL)
    page.draw_rect(fitz.Rect(x + 8, yy + 5, x + 11, yy + 19),
                   color=None, fill=ORANGE)
    page.insert_text((x + 16, yy + 15), "SHEET TEMPLATE",
                     fontsize=7, fontname=F_MONO_BOLD, color=FG)
    yy = hd.y1 + 4
    # Layout header banner — reminds the user there's only one layout.
    lb = fitz.Rect(x + 8, yy, r.x1 - 8, yy + 18)
    page.draw_rect(lb, color=BORDER, fill=ELEVATED, width=0.6)
    page.insert_text((lb.x0 + 8, lb.y0 + 12),
                     "LAYOUT · ANSI FULL BLEED",
                     fontsize=6.5, fontname=F_MONO_BOLD, color=DIM)
    page.insert_text((lb.x1 - 82, lb.y0 + 12),
                     "NO BORDER · NO PANEL",
                     fontsize=6, fontname=F_MONO, color=MUTED)
    yy = lb.y1 + 6

    templates = [
        # (name, size, orient-letter, portrait-icon?, active?)
        ("ANSI A", "8.5 × 11",  "P", True,  False),
        ("ANSI A", "11 × 8.5",  "L", False, False),
        ("ANSI B", "11 × 17",   "P", True,  False),
        ("ANSI B", "17 × 11",   "L", False, True),
        ("ANSI C", "22 × 17",   "L", False, False),
        ("ANSI C", "17 × 22",   "P", True,  False),
        ("ANSI D", "34 × 22",   "L", False, False),
        ("ANSI D", "22 × 34",   "P", True,  False),
    ]
    grid_w = (r.x1 - r.x0 - 16) / 2
    for i, (name, size, orient, portrait, active) in enumerate(templates):
        col = i % 2
        row = i // 2
        cx0 = x + 8 + col * grid_w
        cy0 = yy + row * 48
        card = fitz.Rect(cx0 + 2, cy0, cx0 + grid_w - 2, cy0 + 44)
        page.draw_rect(card, color=ORANGE if active else BORDER,
                       fill=ORANGE_DIM if active else CARD,
                       width=1 if active else 0.6)
        # mini sheet icon (portrait/landscape ratio)
        if portrait:
            sh = fitz.Rect(card.x0 + 10, card.y0 + 6, card.x0 + 30, card.y0 + 36)
        else:
            sh = fitz.Rect(card.x0 + 6, card.y0 + 10, card.x0 + 36, card.y0 + 30)
        page.draw_rect(sh, color=DIM, width=0.7)
        # Optional draggable title hint — a thin orange tick where the
        # centred title sits by default.
        tick_left = sh.x0 + sh.width * 0.35
        tick_right = sh.x0 + sh.width * 0.65
        tick_y = sh.y0 + sh.height * 0.18
        page.draw_line((tick_left, tick_y), (tick_right, tick_y),
                       color=(1.0, 0.35, 0.12), width=0.9)
        page.insert_text((card.x0 + 48, card.y0 + 20), name,
                         fontsize=8, fontname=F_MONO_BOLD,
                         color=ORANGE if active else FG)
        page.insert_text((card.x0 + 48, card.y0 + 34), f"{size} in  ·  {orient}",
                         fontsize=6, fontname=F_MONO, color=MUTED)


def insert_image_fit(page, rect: fitz.Rect, path: Path):
    if not path.exists():
        page.draw_rect(rect, color=BORDER, fill=CARD, width=0.8)
        page.insert_text((rect.x0 + 12, rect.y0 + 24),
                         f"(missing {path.name})", fontsize=9, color=MUTED)
        return
    page.insert_image(rect, filename=str(path), keep_proportion=True)


def build_slide_deck() -> Path:
    ART.mkdir(parents=True, exist_ok=True)
    doc = fitz.open()
    pages: list[fitz.Page] = []

    def add(page: fitz.Page) -> fitz.Page:
        pages.append(page)
        return page

    # 1 Title
    page = add(new_slide(doc))
    # split hero title with orange DXF — width measured against LiberationSans
    stake_w = fitz.get_text_length("STAKE", fontname="hebo", fontsize=110)
    page.insert_text((40, 260), "STAKE", fontsize=110, fontname=F_BOLD, color=FG)
    page.insert_text((40 + stake_w + 6, 260), "DXF",
                     fontsize=110, fontname=F_BOLD, color=ORANGE)
    page.insert_text((40, 300), "UI & CAPABILITIES  ·  v1.24", fontsize=14,
                     fontname=F_MONO, color=MUTED)
    page.draw_line((40, 320), (SLIDE_W - 40, 320), color=BORDER, width=1)
    page.insert_textbox(
        fitz.Rect(40, 340, 720, 440),
        "Rugged on-device field kit — Civil 3D DWG → Trimble DXF recovery\n"
        "and scaled staking-plot PDFs on the TSC5 handheld.",
        fontsize=16, fontname=F_BODY, color=DIM,
    )
    # tech readout
    page.insert_text((40, 500), "ENGINE",
                     fontsize=8, fontname=F_MONO, color=MUTED)
    page.insert_text((40, 516), "LIBREDWG · EZDXF · FLUTTER",
                     fontsize=10, fontname=F_MONO, color=FG)
    page.insert_text((260, 500), "OUTPUT",
                     fontsize=8, fontname=F_MONO, color=MUTED)
    page.insert_text((260, 516), "DXF R2010 · PDF",
                     fontsize=10, fontname=F_MONO, color=FG)
    page.insert_text((440, 500), "TARGET",
                     fontsize=8, fontname=F_MONO, color=MUTED)
    page.insert_text((440, 516), "TRIMBLE TSC5",
                     fontsize=10, fontname=F_MONO, color=FG)

    # 2 Agenda
    page = add(new_slide(doc, "AGENDA"))
    bullet_block(page, 40, 120,
                 ["Before / after — visible break from v1.19",
                  "Design system",
                  "Home / operations",
                  "CONVERT · DWG → DXF pipeline",
                  "PLOT · Export points + staking sheet",
                  "Plot customization",
                  "Staking plot examples",
                  "Install on Trimble TSC5",
                  "Field workflow end-to-end"],
                 size=15, gap=30)

    # 2b Before / after — proves the UI actually changed
    page = add(new_slide(doc, "BEFORE  ·  AFTER"))
    _before_after_slide(page)

    # 3 Design system slide
    page = add(new_slide(doc, "DESIGN SYSTEM"))
    swatches = [("BG",       BG),
                ("CARD",     CARD),
                ("RAIL",     RAIL),
                ("BORDER",   BORDER),
                ("FG",       FG),
                ("DIM",      DIM),
                ("MUTED",    MUTED),
                ("ACCENT",   ORANGE),
                ("OK",       OK),
                ("WARN",     WARN),
                ("DANGER",   DANGER)]
    y = 130
    for i, (name, col) in enumerate(swatches):
        cx = 40 + (i % 6) * 170
        cy = y + (i // 6) * 90
        page.draw_rect(fitz.Rect(cx, cy, cx + 80, cy + 60),
                       color=BORDER_STRONG, fill=col, width=1)
        page.insert_text((cx + 92, cy + 22), name,
                         fontsize=10, fontname=F_MONO, color=FG)
        r = int(col[0] * 255)
        g = int(col[1] * 255)
        b = int(col[2] * 255)
        page.insert_text((cx + 92, cy + 40),
                         f"#{r:02X}{g:02X}{b:02X}",
                         fontsize=8, fontname=F_MONO, color=MUTED)
    # Principles
    page.insert_text((40, 380), "PRINCIPLES",
                     fontsize=10, fontname=F_MONO, color=MUTED)
    page.draw_line((40, 384), (SLIDE_W - 40, 384), color=BORDER, width=1)
    bullet_block(page, 40, 400,
                 ["Hard 90° corners — no rounded chrome",
                  "Mono telemetry for coordinates, versions, entity counts",
                  "Safety-orange only for active / primary actions",
                  "Hairline rules over cards; content over decoration",
                  "Minimum 44 px tap targets for TSC5 field use"],
                 size=13, gap=22)

    # 4 Home UI
    page = add(new_slide(doc, "HOME / OPERATIONS"))
    draw_phone(page, 60, 130, ui_home)
    page.insert_textbox(
        fitz.Rect(430, 140, 1080, 260),
        "Two ops, one screen: CONVERT and PLOT.\n\n"
        "Rugged action rails with a numeric tag, thick left rail, and "
        "arrow — reads like a hardware toggle, not a marketing card.",
        fontsize=15, fontname=F_BODY, color=DIM,
    )
    _section_rule(page, 430, 300, 1080, "TELEMETRY")
    bullet_block(page, 430, 320,
                 ["Ribbon: SDX build + ONLINE / LOCAL pills",
                  "Status grid: ENGINE / OUTPUT / MODE readouts",
                  "Footer: TRIO FIELD OPS · NO CLOUD · NO TRACKING"],
                 size=13, gap=24, width=640)

    # 5 Convert UI
    page = add(new_slide(doc, "CONVERT · DWG → DXF"))
    draw_phone(page, 60, 110, ui_convert)
    bullet_block(page, 430, 150,
                 ["Input slot glows orange when a drawing is loaded",
                  "RUN CONVERT primary button with arrow slot",
                  "Result readout tagged CONVERT / OK with mono KVs",
                  "Layer checklist with hard tick boxes + entity counts",
                  "SAVE DXF button carries the selected-layer count"],
                 size=13, gap=26, width=640)

    # 6 Export empty
    page = add(new_slide(doc, "PLOT · EXPORT POINTS — START"))
    draw_phone(page, 60, 110, lambda p, r: ui_export(p, r, "empty"))
    bullet_block(page, 430, 150,
                 ["Enter a JOB name — becomes the sheet title",
                  "IMPORT POINTS CSV / TXT from Trimble Access",
                  "Optional LINK DXF LINEWORK for on-plot detail",
                  "PNEZD headered or headerless supported"],
                 size=14, gap=28, width=640)

    # 7 Export loaded
    page = add(new_slide(doc, "PLOT · CUSTOMIZE + CREATE"))
    draw_phone(page, 60, 110, lambda p, r: ui_export(p, r, "loaded"))
    bullet_block(page, 430, 130,
                 ["MARKER · triangle / X / cross / circle / dot",
                  "LABEL · number / desc / elev combinations",
                  "SCALE · engineering presets or custom 1\"=N'",
                  "SHEET · ANSI A–D, portrait or landscape",
                  "LAYERS · tick only the linework you want",
                  "Object library places hydrants / MH / signs",
                  "CREATE STAKING PLOT PDF or EXPORT CSV"],
                 size=13, gap=24, width=640)

    # 7b Layer Properties Manager — Civil 3D style
    page = add(new_slide(doc, "LAYER PROPERTIES MANAGER"))
    draw_phone(page, 60, 100, ui_layer_properties_manager, content_height=500)
    page.insert_textbox(
        fitz.Rect(430, 120, 1080, 220),
        "The DXF linework grid is a true Layer Properties Manager — Civil 3D "
        "column order, sortable headers, sticky Name pane, horizontally "
        "scrolling data strip.",
        fontsize=14, fontname=F_BODY, color=DIM,
    )
    _section_rule(page, 430, 250, 1080, "COLUMNS")
    bullet_block(page, 430, 268,
                 ["On — light-bulb toggle (draws layer on the plot)",
                  "Frz — freeze marker (snowflake / sun icon)",
                  "Lk — padlock; locked layers can't be drag-selected",
                  "Color — ACI / CTB / true-color HSV picker",
                  "Linetype — CONT / DASHED / DASHDOT / HIDDEN …",
                  "LW — printed weight in points",
                  "Tr — transparency %; opacity = 100 - Tr",
                  "LTS — per-layer linetype scale"],
                 size=12, gap=22, width=640)
    _section_rule(page, 430, 480, 1080, "TOOLBAR + FILTER")
    bullet_block(page, 430, 498,
                 ["All-on / all-off / invert bulbs",
                  "Lock-all / unlock-all",
                  "Reset overrides for selected layer or every layer",
                  "Chips: ALL · ON · OFF · LOCKED · OVERRIDDEN",
                  "Live search box — filters by layer name"],
                 size=12, gap=22, width=640)

    # 7c Colour picker — ACI/CTB
    page = add(new_slide(doc, "COLOR PICKER  ·  ACI + CTB"))
    draw_phone(page, 60, 100, ui_color_picker, content_height=500)
    bullet_block(page, 430, 150,
                 ["Full ACI 1 – 255 grid, CTB-resolved swatches",
                  "Header shows the current color swatch",
                  "Selected chip framed in safety-orange",
                  "Tap ByLayer / CTB default to clear override",
                  "Two-tab sheet — ACI on the left, True on the right"],
                 size=13, gap=26, width=640)

    # 7d Colour picker — true color
    page = add(new_slide(doc, "COLOR PICKER  ·  TRUE COLOR"))
    draw_phone(page, 60, 100, ui_truecolor, content_height=500)
    bullet_block(page, 430, 150,
                 ["Sat/Value gradient — pick with a single tap",
                  "Full-hue slider under the pad",
                  "Live R / G / B readout in mono",
                  "APPLY writes the exact #RRGGBB override"],
                 size=13, gap=26, width=640)

    # 7e Linetype sheet
    page = add(new_slide(doc, "LINETYPE PICKER"))
    draw_phone(page, 60, 100, ui_linetype_sheet, content_height=500)
    bullet_block(page, 430, 150,
                 ["Full LIN catalog + user-loaded linetypes",
                  "Each row shows the actual dash pattern preview",
                  "Tap ByLayer default to inherit the layer style",
                  "Choice applies to the whole layer — same as Civil 3D"],
                 size=13, gap=26, width=640)

    # 7f Lineweight sheet
    page = add(new_slide(doc, "LINEWEIGHT PICKER"))
    draw_phone(page, 60, 100, ui_lineweight_sheet, content_height=500)
    bullet_block(page, 430, 150,
                 ["Standard AutoCAD weights 0.18 – 2.00 pt",
                  "Each row shows a scaled preview stroke",
                  "Choice affects the printed PDF stroke only",
                  "Tap ByLayer / CTB to defer to the CTB table"],
                 size=13, gap=26, width=640)

    # 7g Transparency sheet
    page = add(new_slide(doc, "TRANSPARENCY / OPACITY"))
    draw_phone(page, 60, 100, ui_transparency_sheet, content_height=500)
    bullet_block(page, 430, 150,
                 ["Live-updates the plot preview while dragging",
                  "OPACITY and TRANS both shown in mono",
                  "RESET returns to the resolved ByLayer / CTB value",
                  "APPLY commits the override; no more no-op slider"],
                 size=13, gap=26, width=640)

    # 7h Linetype scale sheet
    page = add(new_slide(doc, "LINETYPE SCALE (LTS)"))
    draw_phone(page, 60, 100, ui_ltscale_sheet, content_height=500)
    bullet_block(page, 430, 150,
                 ["Per-layer LTS override — 0.1 to 20.0",
                  "Global LTS lives on the LPM footer",
                  "Resolved value = layer LTS × global LTS",
                  "Reset returns to the resolved 1.0"],
                 size=13, gap=26, width=640)

    # 7i Linework properties panel
    page = add(new_slide(doc, "LINEWORK PROPERTIES"))
    draw_phone(page, 60, 100, ui_linework_panel, content_height=500)
    bullet_block(page, 430, 150,
                 ["Selecting a segment on the preview opens this panel",
                  "Read-outs: layer / color / linetype / weight / scale",
                  "TRIM SEGMENT — surgical edit without a full delete",
                  "DELETE SEGMENT — drop just this run",
                  "CLEAR SELECTION restores the sticky behaviour fix"],
                 size=13, gap=26, width=640)

    # 7j Point properties panel
    page = add(new_slide(doc, "POINT PROPERTIES"))
    draw_phone(page, 60, 100, ui_point_properties, content_height=500)
    bullet_block(page, 430, 150,
                 ["Full PNEZD read-out + label offset",
                  "Marker + label style overridable per-point",
                  "MOVE LABEL — drag on the preview to reposition",
                  "HIDE POINT — omit from the final PDF",
                  "RESET OFFSET returns to the auto-layout position"],
                 size=13, gap=26, width=640)

    # 7k Text style picker
    page = add(new_slide(doc, "TEXT STYLE PICKER"))
    draw_phone(page, 60, 100, ui_text_style, content_height=500)
    bullet_block(page, 430, 150,
                 ["Every SHX-equivalent style shown with a live preview",
                  "Height / width factor labelled in monospace",
                  "STANDARD, ROMANS, ROMAND, ITALIC, MONO, SANS-B",
                  "Applies to the selected label / callout style"],
                 size=13, gap=26, width=640)

    # 7l Symbol library
    page = add(new_slide(doc, "SYMBOL LIBRARY"))
    draw_phone(page, 60, 100, ui_symbol_library, content_height=500)
    bullet_block(page, 430, 150,
                 ["Category chips: ALL / UTILITY / STRUCT / SURVEY / DWG BLOCKS",
                  "Built-ins + AutoCAD blocks pulled from the DWG catalog",
                  "Tap a card, then place on the sheet at real-world scale",
                  "Symbols honour marker size + layer color overrides"],
                 size=13, gap=26, width=640)

    # 7m Plot preview
    page = add(new_slide(doc, "PLOT PREVIEW · ANSI FULL BLEED"))
    draw_phone(page, 60, 100, ui_plot_preview, content_height=500)
    bullet_block(page, 430, 150,
                 ["Full-bleed sheet — linework runs edge-to-edge",
                  "No border, no cream panel, no title block band",
                  "Plot title is OPTIONAL — off by default, draggable when on",
                  "Red X stake markers with numbered leader labels",
                  "Sub-menus cap at ~60% height so the preview stays visible",
                  "SAVE PLOT PDF writes the final Trimble-ready sheet"],
                 size=13, gap=24, width=640)

    # 7n Sheet template picker
    page = add(new_slide(doc, "SHEET TEMPLATE PICKER"))
    draw_phone(page, 60, 100, ui_templates, content_height=500)
    bullet_block(page, 430, 150,
                 ["Single layout — ANSI FULL BLEED",
                  "Pick ANSI A / B / C / D",
                  "Portrait or landscape",
                  "Active template highlighted in safety-orange",
                  "Plot is pure full-bleed — nothing but the plan by default"],
                 size=13, gap=24, width=640)

    # 8 Plot options matrix
    page = add(new_slide(doc, "PLOT CUSTOMIZATION"))
    _section_rule(page, 40, 130, SLIDE_W - 40, "MARKERS")
    bullet_block(page, 40, 150,
                 ["Filled triangle · Triangle outline",
                  "Cross (+) · X · Large X",
                  "Circle · Dot · Large dot"],
                 size=13, gap=24, width=520)
    _section_rule(page, 560, 130, SLIDE_W - 40, "LABELS")
    bullet_block(page, 560, 150,
                 ["Point number",
                  "Number + description",
                  "Number + elevation",
                  "Number + description + elevation",
                  "No labels"],
                 size=13, gap=24, width=520)
    _section_rule(page, 40, 310, SLIDE_W - 40, "SHEET & LINEWORK")
    bullet_block(page, 40, 330,
                 ["Plot title: optional, draggable & resizable on preview",
                  "No bounding box, no scale text, no north arrow, no callout",
                  "No hatch fills on solid objects — clean outlines",
                  "Linked DXF: LINE / LWPOLYLINE / ARC / CIRCLE by layer",
                  "Auto engineering scale or hard-set 1\"=N'",
                  "Layer LOCK column prevents accidental drag-selection",
                  "Full ACI + CTB + true-color HSV picker"],
                 size=13, gap=26, width=980)

    # 9-10 Example gallery
    gallery = [
        ("01_field_staking_large_x.png", "FIELD STAKING · LARGE X + ELEV"),
        ("02_control_note_style_table.png", "CONTROL-NOTE STYLE + TABLE"),
        ("03_markers_circle_dot.png", "CIRCLES + CURB LAYER"),
        ("04_markers_cross_plus.png", "CROSS (+) NUMBER ONLY"),
        ("06_markers_large_dot_no_labels.png", "OVERVIEW · DOTS · NO LABELS"),
        ("07_labels_number_only.png", "DENSE SET · NUMBER ONLY"),
        ("08_dot_with_elevations.png", "GRADE CHECK · ELEV LABELS"),
        ("09_full_sheet_with_table_and_linework.png", "FULL SHEET + LINEWORK"),
    ]
    for i in range(0, len(gallery), 4):
        chunk = gallery[i : i + 4]
        page = add(new_slide(doc, "STAKING PLOT EXAMPLES"))
        positions = [
            fitz.Rect(40, 110, 540, 340),
            fitz.Rect(560, 110, 1080, 340),
            fitz.Rect(40, 360, 540, 580),
            fitz.Rect(560, 360, 1080, 580),
        ]
        for (name, caption), rect in zip(chunk, positions):
            img_rect = fitz.Rect(rect.x0, rect.y0, rect.x1, rect.y1 - 22)
            page.draw_rect(img_rect, color=BORDER, fill=CARD, width=0.8)
            insert_image_fit(page, img_rect, SHOTS / name)
            page.insert_text((rect.x0 + 4, rect.y1 - 6), caption,
                             fontsize=9, fontname=F_MONO, color=DIM)

    # Install
    page = add(new_slide(doc, "INSTALL / TRIMBLE TSC5"))
    bullet_block(page, 40, 130,
                 ["Copy dist/StakeDXF vX.Y.Z.apk onto the TSC5",
                  "Open the APK — allow Install from this source",
                  "Open StakeDXF from the app drawer",
                  "MDM blocked? Ask IT for unknown-source exception",
                  "APK is Android-only — will not install on iPhone"],
                 size=15, gap=32, width=980)

    # Field workflow
    page = add(new_slide(doc, "FIELD WORKFLOW"))
    bullet_block(page, 40, 130,
                 ["Office: save Civil 3D DWG with proxies preserved",
                  "TSC5: CONVERT → save DXF into Trimble job folder",
                  "Trimble Access: Map files → selectable → Stakeout",
                  "Export points CSV from Access for shots you need",
                  "StakeDXF PLOT → customize → CREATE staking plot PDF",
                  "Keep PDF open while staking for a scaled field sheet"],
                 size=14, gap=30, width=980)

    # Help
    page = add(new_slide(doc, "DOCS & HELP"))
    bullet_block(page, 40, 130,
                 ["dist/INSTALL_TSC5.md — quick install card",
                  "dist/StakeDXF_User_Guide.pdf — full usage / help",
                  "docs/USER_GUIDE.md — same guide in Markdown",
                  "dist/plot_examples/ — sample staking PDFs",
                  "PR #18 — source, APK, release notes"],
                 size=15, gap=32, width=980)

    # Close
    page = add(new_slide(doc))
    page.insert_text((40, 260), "READY FOR THE FIELD.",
                     fontsize=54, fontname=F_BOLD, color=FG)
    page.draw_line((40, 300), (SLIDE_W - 40, 300), color=ORANGE, width=2)
    page.insert_text((40, 340), "STAKEDXF · TSC5",
                     fontsize=20, fontname=F_MONO, color=ORANGE)
    page.insert_text((40, 380),
                     "RECOVER LINEWORK. PLOT POINTS. STAKE WITH CONFIDENCE.",
                     fontsize=12, fontname=F_MONO, color=MUTED)

    total = len(pages)
    for i in range(total):
        footer(doc[i], i + 1, total)

    DIST.mkdir(parents=True, exist_ok=True)
    doc.save(OUT_SLIDES, garbage=4, deflate=True)
    doc.close()
    return OUT_SLIDES


def build_tutorial_pdf() -> Path:
    doc = fitz.open()
    W, H = 612, 792

    def page_start(title: str) -> fitz.Page:
        page = doc.new_page(width=W, height=H)
        register_fonts(page)
        page.draw_rect(fitz.Rect(0, 0, W, 44), color=None, fill=BG)
        page.draw_line((0, 44), (W, 44), color=ORANGE, width=2)
        page.insert_text((40, 30), title.upper(),
                         fontsize=14, fontname=F_BOLD, color=FG)
        return page

    # Cover
    page = doc.new_page(width=W, height=H)
    register_fonts(page)
    page.draw_rect(page.rect, color=None, fill=BG)
    page.draw_rect(fitz.Rect(0, 0, W, 8), color=None, fill=ORANGE)
    page.insert_text((48, 250), "STAKE",
                     fontsize=42, fontname=F_BOLD, color=FG)
    _stake_w42 = fitz.get_text_length("STAKE", fontname="hebo", fontsize=42)
    page.insert_text((48 + _stake_w42 + 4, 250), "DXF",
                     fontsize=42, fontname=F_BOLD, color=ORANGE)
    page.draw_line((48, 270), (W - 48, 270), color=BORDER, width=1)
    page.insert_text((48, 300), "USER GUIDE  ·  v1.24",
                     fontsize=16, fontname=F_MONO, color=DIM)
    page.insert_textbox(
        fitz.Rect(48, 340, 520, 460),
        "Install · Usage · Help\nTrimble TSC5 field controller app\nTRIO Engineering",
        fontsize=13, fontname=F_BODY, color=MUTED,
    )
    page.insert_text((48, 720),
                     "Companion to StakeDXF_UI_Slide_Deck.pdf",
                     fontsize=9, fontname=F_MONO, color=MUTED)

    def body_text(page, text):
        page.insert_textbox(fitz.Rect(40, 68, W - 40, H - 50),
                            text, fontsize=11, fontname=F_BODY, color=(0, 0, 0))

    # Install
    page = page_start("1. Installation (Trimble TSC5)")
    body_text(page, (
        "StakeDXF ships as an Android APK for the Trimble TSC5.\n\n"
        "File:  dist/StakeDXF vX.Y.Z.apk  (~65 MB)\n"
        "Package:  com.stakedxf.stakedxf\n\n"
        "Steps\n"
        "1. Copy the APK onto the TSC5 (USB File Transfer or your usual share).\n"
        "2. Open Files / Downloads on the TSC5 and tap the APK.\n"
        "3. If blocked, enable Allow from this source for that app.\n"
        "4. Tap Install, then open StakeDXF from the app drawer.\n\n"
        "If Install is greyed out\n"
        "Company MDM may block unknown APKs. Ask IT for an unknown-source exception "
        "or push the APK through managed distribution.\n\n"
        "Common mistakes\n"
        "• Trying to open the APK on iPhone (Android only).\n"
        "• Opening a zip/repo instead of the .apk.\n"
        "• USB stuck on Charging only — switch to File Transfer."
    ))

    # Convert
    page = page_start("2. Usage — CONVERT (DWG → DXF)")
    body_text(page, (
        "Purpose: turn a Civil 3D drawing into a Trimble-stakeable DXF on the controller.\n\n"
        "1. Open StakeDXF → CONVERT.\n"
        "2. Tap the drawing slot and pick the office DWG / DXF.\n"
        "3. Tap RUN CONVERT.\n"
        "4. Confirm the stakeable entity count and proxy explode count.\n"
        "5. Review the LAYERS list and tick which to include.\n"
        "6. Tap SAVE DXF — writes into the TSC5 documents folder.\n"
        "7. Move it into Trimble Data/Projects/<job>/.\n"
        "8. Trimble Access: Map → Layer manager → Map files → selectable → Stakeout.\n\n"
        "Pipeline (on-device)\n"
        "• LibreDWG reads the DWG into DXF.\n"
        "• ezdxf explodes ACAD_PROXY_ENTITY / AEC graphics into LINE / ARC / POLY.\n"
        "• Non-stakeable entity types are filtered out.\n\n"
        "Tip: office DWGs should be saved with proxy graphics preserved."
    ))

    # Plot
    page = page_start("3. Usage — PLOT (Export Points)")
    body_text(page, (
        "Purpose: build a scaled staking sheet from selected points (and optional linework).\n\n"
        "1. Export points from Trimble Access as CSV/TXT (PNEZD).\n"
        "2. StakeDXF → PLOT.\n"
        "3. Enter a JOB name.\n"
        "4. IMPORT POINTS CSV / TXT.\n"
        "5. Optionally LINK DXF LINEWORK and check the layers you want.\n"
        "6. Set MARKER, LABEL, SCALE, and SHEET.\n"
        "7. Optional: place library objects (hydrant / MH / sign).\n"
        "8. Select which points appear on the sheet.\n"
        "9. Tap CREATE STAKING PLOT PDF, or EXPORT CSV for a trimmed list.\n\n"
        "Supported point formats\n"
        "• PNEZD (headered or not)\n"
        "• Common header aliases (Point #, Elev, Desc, …)\n\n"
        "Linked DXF linework\n"
        "• Reads LINE / LWPOLYLINE / POLYLINE / ARC / CIRCLE\n"
        "• Layer checklist keeps only the linework you want on the plot"
    ))

    # Customization
    page = page_start("4. Plot customization reference")
    body_text(page, (
        "Markers\n"
        "Filled triangle · Triangle outline · Cross (+) · X · Large X · Circle · Dot · Large dot\n\n"
        "Labels\n"
        "Point number · Number + description · Number + elevation ·\n"
        "Number + description + elevation · No labels\n\n"
        "Sheet\n"
        "• Layout is always ANSI FULL BLEED — no border, no title-block band.\n"
        "• Plot title is OPTIONAL. When enabled, drag it around the preview\n"
        "  and scale it with the size slider. Nothing else prints on the sheet.\n"
        "• Sheet size: ANSI A–D, portrait or landscape; auto or fixed 1\"=N'.\n"
        "• Solid civil symbols draw as clean outlines — no hatch fills.\n"
        "• Sub-menus (color, layer props, symbol library, scale) cap at ~60%\n"
        "  of the screen so the plot preview always stays visible above.\n\n"
        "Colors\n"
        "• Full ACI 1–255, CTB-resolved swatches, and true-color HSV picker.\n\n"
        "Examples\n"
        "See dist/plot_examples/ for sample PDFs covering these combinations."
    ))

    # Help
    page = page_start("5. Help & troubleshooting")
    body_text(page, (
        "No stakeable entities after convert\n"
        "• Confirm the DWG still contains proxy graphics (ACAD_PROXY_ENTITY).\n"
        "• Civil objects saved without proxies cannot be exploded to linework.\n\n"
        "Staking plot has no linework\n"
        "• Link a DXF and enable Draw linked DXF linework.\n"
        "• Ensure at least one layer is checked.\n"
        "• Only LINE / LWPOLYLINE / POLYLINE / ARC / CIRCLE are drawn.\n\n"
        "Points missing after import\n"
        "• Use PNEZD or a headered CSV with Northing/Easting columns.\n"
        "• Blank or malformed rows are skipped.\n\n"
        "App will not install\n"
        "• Must be the TSC5 (Android), not iPhone.\n"
        "• Enable Allow from this source or ask IT for MDM approval."
    ))

    # Quick reference
    page = page_start("6. Quick reference")
    body_text(page, (
        "Home\n"
        "  01  CONVERT       Recover Civil 3D linework\n"
        "  02  PLOT          CSV + staking plot PDF\n\n"
        "Convert\n"
        "  Pick drawing → RUN CONVERT → tick layers → SAVE DXF → Trimble Map files\n\n"
        "Plot\n"
        "  Import CSV → (link DXF) → Marker / Label / Scale / Sheet →\n"
        "  Select points → CREATE STAKING PLOT PDF   or   EXPORT CSV\n\n"
        "Good defaults for staking\n"
        "  Marker: Large X\n"
        "  Label:  Number + elevation\n"
        "  Table:  Off\n"
        "  Layers: On (only what you need)\n\n"
        "Runs on-device. No cloud. No tracking."
    ))

    DIST.mkdir(parents=True, exist_ok=True)
    doc.save(OUT_TUTORIAL, garbage=4, deflate=True)
    doc.close()
    return OUT_TUTORIAL


def write_markdown_guides():
    DOCS.mkdir(parents=True, exist_ok=True)
    OUT_HELP_MD.write_text(
        """# StakeDXF User Guide

Install · Usage · Help for the Trimble TSC5 app.

Companion PDFs:
- `dist/StakeDXF_User_Guide.pdf`
- `dist/StakeDXF_UI_Slide_Deck.pdf`

## 1. Installation (Trimble TSC5)

**File:** `dist/StakeDXF vX.Y.Z.apk` (~65 MB)  
**Package:** `com.stakedxf.stakedxf`

1. Copy `StakeDXF vX.Y.Z.apk` onto the TSC5 (USB File Transfer or your usual file share).
2. Open **Files / Downloads** and tap the APK.
3. If blocked, enable **Allow from this source** for the app that opened the APK.
4. Tap **Install**, then open **StakeDXF**.

### If Install is greyed out
Company MDM may block unknown APKs. Ask IT to allow unknown-source installs or push the APK through managed distribution.

### Common mistakes
- Opening the APK on **iPhone** (Android only)
- Opening a zip/repo instead of the `.apk`
- USB left on **Charging only** (use File Transfer)

Also see `dist/INSTALL_TSC5.md`.

## 2. Usage — CONVERT (DWG → DXF)

1. Open **StakeDXF → CONVERT**
2. Tap the drawing slot → pick the DWG / DXF
3. Tap **RUN CONVERT**
4. Confirm stakeable entity count (and proxy explode count when present)
5. Review the **LAYERS** checklist (empty layers omitted)
6. Tap **SAVE DXF** to the TSC5 documents folder
7. Move it into `Trimble Data/Projects/<job>/`
8. Trimble Access: **Map → Layer manager → Map files → selectable → Stakeout**

### On-device pipeline
1. LibreDWG: DWG → DXF  
2. ezdxf: explode `ACAD_PROXY_ENTITY` / AEC proxies → LINE / ARC / POLYLINE  
3. Keep Trimble-stakeable types only; purge empty layer-table entries  
4. Optional: export a subset of layers from the LAYERS checklist  

**Tip:** Office DWGs should keep proxy graphics so Civil features can be recovered.

## 3. Usage — PLOT (Export Points)

1. Export points from Trimble Access as CSV/TXT (PNEZD)
2. **StakeDXF → PLOT**
3. Enter a **JOB** name
4. **IMPORT POINTS CSV / TXT**
5. (Optional) **LINK DXF LINEWORK** and pick layers
6. Set **MARKER**, **LABEL**, **SCALE**, **SHEET**
7. (Optional) place library objects — hydrant / MH / sign
8. Select points for the sheet
9. **CREATE STAKING PLOT PDF** or **EXPORT CSV**

### Supported point formats
- PNEZD: Point, Northing, Easting, Elevation, Description (headered or not)
- Common header aliases (`Point #`, `Elev`, `Desc`, …)

### Linked DXF linework
Draws `LINE`, `LWPOLYLINE`, `POLYLINE`, `ARC`, `CIRCLE` for checked layers.

## 4. Plot customization

### Layer Properties Manager (Civil 3D style)

Opens under **LAYERS** on the PLOT screen when a DXF is linked. Column order and
behaviour mirror the AutoCAD/Civil 3D LPM:

| Column | Purpose |
| --- | --- |
| **On** | Light-bulb toggle — draws the layer on the plot |
| **Frz** | Freeze marker (snowflake ⇄ sun) |
| **Lk** | Padlock — prevents accidental drag-selection |
| **Color** | ACI / CTB / HSV true-color picker |
| **Linetype** | CONT / DASHED / DASHDOT / HIDDEN / DOT / BORDER / CENTER / PHANTOM |
| **LW** | Printed weight in points (0.18 – 2.00) |
| **Tr** | Transparency % (Op = 100 − Tr) |
| **LTS** | Per-layer linetype scale |

Toolbar strip (top of the manager):

- Bulb-on / bulb-off / invert — bulk On toggling
- Lock-all / unlock-all — bulk Lk toggling
- Reset selected-layer overrides / reset ALL overrides
- Refresh sort

Filter chips: **ALL · ON · OFF · LOCKED · OVERRIDDEN**.  
Search box filters by layer name. Column headers with `▲/▼` are sortable.  
Selected layer shows an orange left bar; overridden layers show a yellow bar.

### Other plot options

| Option | Choices |
| --- | --- |
| Markers | Filled triangle, triangle outline, cross (+), X, large X, circle, dot, large dot |
| Labels | Number · number+description · number+elevation · number+description+elevation · none |
| Plot title | Optional; draggable / resizable on the preview (paper-space) |
| Linework | Optional linked DXF layers |
| Scale | Auto engineering scale, or fixed `1"=N'` |
| Sheet | ANSI A–D, portrait or landscape · always ANSI full bleed |
| Colors | Full ACI, CTB, HSV true-color |

Examples: `dist/plot_examples/`  
Regenerate: `cd mobile/stakedxf && dart run tool/generate_plot_examples.dart`

## 5. Help & troubleshooting

**No stakeable entities after convert**  
Drawing may lack proxy graphics. Re-save from Civil 3D with proxies preserved.

**Plot has no linework**  
Link a DXF, enable **Draw linked DXF linework**, and check at least one layer.

**Points missing after import**  
Use PNEZD or a headered CSV with Northing/Easting columns.

**App will not install**  
Must be TSC5 (Android). Enable unknown sources or get IT MDM approval.

## 6. Quick reference

```
Home
  01  CONVERT       Recover Civil 3D linework
  02  PLOT          CSV + staking plot PDF

Convert
  Pick drawing → RUN CONVERT → tick layers → SAVE DXF → Trimble Map files

Plot
  Import CSV → (Link DXF) → Marker / Label / Scale / Sheet →
  Select points → CREATE STAKING PLOT PDF   or   EXPORT CSV

Good staking defaults
  Marker: Large X
  Label:  Number + elevation
  Table:  Off
  Layers: On (only what you need)
```

Runs on-device. No cloud. No tracking.
""",
        encoding="utf-8",
    )

    OUT_SLIDES_MD.write_text(
        """# StakeDXF UI Slide Deck (outline)

PDF: `dist/StakeDXF_UI_Slide_Deck.pdf`

Regenerate with:

```bash
python3 docs/generate_docs.py
```

## Slides
1. Title — STAKE·DXF · UI & Capabilities · v1.24
2. Agenda
3. Before / after
4. Design system (tokens + principles)
5. Home / Operations (rugged action rails)
6. CONVERT · DWG → DXF pipeline
7. PLOT · Export Points — start
8. PLOT · Customize + Create
9. **Layer Properties Manager (Civil 3D style)**
10. Color picker · ACI + CTB
11. Color picker · True color
12. Linetype picker
13. Lineweight picker
14. Transparency / opacity
15. Linetype scale (LTS)
16. Linework properties panel
17. Point properties panel
18. Text style picker
19. Symbol library
20. Plot preview
21. Sheet template picker
22. Plot customization matrix
23–24. Staking plot example galleries
25. Install on Trimble TSC5
26. Field workflow
27. Docs & help
28. Ready for the field.
""",
        encoding="utf-8",
    )


def main():
    slides = build_slide_deck()
    tutorial = build_tutorial_pdf()
    write_markdown_guides()
    ART.mkdir(parents=True, exist_ok=True)
    for pdf, prefix in ((slides, "slides"), (tutorial, "guide")):
        d = fitz.open(pdf)
        for i in range(min(4, len(d))):
            pix = d[i].get_pixmap(matrix=fitz.Matrix(1.2, 1.2))
            pix.save(str(ART / f"{prefix}_{i+1:02d}.png"))
        d.close()
    print(f"Wrote {slides} ({slides.stat().st_size} bytes)")
    print(f"Wrote {tutorial} ({tutorial.stat().st_size} bytes)")
    print(f"Wrote {OUT_HELP_MD}")
    print(f"Wrote {OUT_SLIDES_MD}")


if __name__ == "__main__":
    main()
