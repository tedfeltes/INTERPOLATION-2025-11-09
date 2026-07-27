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


def new_slide(doc: fitz.Document, title: str | None = None) -> fitz.Page:
    page = doc.new_page(width=SLIDE_W, height=SLIDE_H)
    page.draw_rect(page.rect, color=None, fill=BG)
    # Instrument top ribbon
    ribbon = fitz.Rect(0, 0, SLIDE_W, 30)
    page.draw_rect(ribbon, color=None, fill=CARD)
    page.draw_line((0, 30), (SLIDE_W, 30), color=BORDER, width=1)
    page.draw_rect(fitz.Rect(20, 11, 28, 19), color=None, fill=ORANGE)
    page.insert_text((36, 20), "SDX  ·  v1.22", fontsize=9, fontname="cour", color=DIM)
    # Right-side telemetry pills
    for i, (label, ok) in enumerate([("ONLINE", True), ("LOCAL", False)]):
        x = SLIDE_W - 40 - i * 90
        r = fitz.Rect(x - 60, 6, x, 24)
        page.draw_rect(r, color=OK if ok else BORDER, fill=None, width=1)
        page.draw_rect(fitz.Rect(r.x0 + 6, r.y0 + 6, r.x0 + 12, r.y0 + 12),
                       color=None, fill=OK if ok else MUTED)
        page.insert_text((r.x0 + 18, r.y0 + 12), label, fontsize=8,
                         fontname="cour", color=OK if ok else MUTED)

    if title:
        page.insert_text(
            (36, 74),
            title.upper(),
            fontsize=24,
            fontname="hebo",
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
        fontsize=8, fontname="cour", color=MUTED,
    )
    page.insert_text(
        (SLIDE_W - 100, y + 4),
        f"{n:02d} / {total:02d}",
        fontsize=8, fontname="cour", color=MUTED,
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
            fontname="helv",
            color=color,
            align=fitz.TEXT_ALIGN_LEFT,
        )
    return y + len(lines) * gap


def draw_phone(page: fitz.Page, x: float, y: float, screen_drawer) -> None:
    """Draw a TSC5-ish handheld chrome and call screen_drawer(page, inner)."""
    outer = fitz.Rect(x - 10, y - 12, x + PHONE_W + 10, y + PHONE_H + 12)
    # Rugged bezel
    page.draw_rect(outer, color=BORDER_STRONG, fill=(0.02, 0.02, 0.03), width=2)
    # Screw dots
    for cx, cy in [(outer.x0 + 6, outer.y0 + 6),
                   (outer.x1 - 6, outer.y0 + 6),
                   (outer.x0 + 6, outer.y1 - 6),
                   (outer.x1 - 6, outer.y1 - 6)]:
        page.draw_circle((cx, cy), 2, color=BORDER_STRONG, fill=RAIL, width=0.5)
    # Screen
    screen = fitz.Rect(x, y, x + PHONE_W, y + PHONE_H)
    page.draw_rect(screen, color=None, fill=BG)
    # Instrument ribbon
    rib = fitz.Rect(screen.x0, screen.y0, screen.x1, screen.y0 + 24)
    page.draw_rect(rib, color=None, fill=CARD)
    page.draw_line((rib.x0, rib.y1), (rib.x1, rib.y1), color=BORDER, width=1)
    page.draw_rect(fitz.Rect(rib.x0 + 8, rib.y0 + 8, rib.x0 + 14, rib.y0 + 14),
                   color=None, fill=ORANGE)
    page.insert_text((rib.x0 + 20, rib.y0 + 15), "SDX · 09:41",
                     fontsize=7, fontname="cour", color=DIM)
    _pill(page, rib.x1 - 82, rib.y0 + 4, rib.x1 - 32, rib.y0 + 20, "ONLINE", OK, True)
    # Bottom ID bar
    bot = fitz.Rect(screen.x0, screen.y1 - 18, screen.x1, screen.y1)
    page.draw_rect(bot, color=None, fill=CARD)
    page.draw_line((bot.x0, bot.y0), (bot.x1, bot.y0), color=BORDER, width=1)
    page.insert_text((bot.x0 + 8, bot.y0 + 12), "TRIO / FIELD OPS",
                     fontsize=6, fontname="cour", color=MUTED)
    page.insert_text((bot.x1 - 96, bot.y0 + 12), "NO CLOUD",
                     fontsize=6, fontname="cour", color=MUTED)
    content = fitz.Rect(screen.x0, rib.y1, screen.x1, bot.y0)
    screen_drawer(page, content)


def _pill(page, x0, y0, x1, y1, label, color, ok):
    r = fitz.Rect(x0, y0, x1, y1)
    page.draw_rect(r, color=color if ok else BORDER, fill=None, width=0.8)
    page.draw_rect(fitz.Rect(r.x0 + 4, r.y0 + 5, r.x0 + 9, r.y0 + 10),
                   color=None, fill=color if ok else MUTED)
    page.insert_text((r.x0 + 13, r.y0 + 12), label, fontsize=6,
                     fontname="cour", color=color if ok else MUTED)


def _section_rule(page, x0, y, x1, label):
    page.insert_text((x0, y), label, fontsize=7, fontname="cour", color=MUTED)
    page.draw_line((x0 + len(label) * 5 + 8, y - 3), (x1, y - 3),
                   color=BORDER, width=1)


def _action_rail(page, rect, tag, title, detail, primary=True):
    page.draw_rect(rect, color=None, fill=CARD)
    # left rail
    page.draw_rect(fitz.Rect(rect.x0, rect.y0, rect.x0 + 4, rect.y1),
                   color=None, fill=ORANGE if primary else BORDER_STRONG)
    # hairline frame
    page.draw_rect(rect, color=BORDER, fill=None, width=0.8)
    # tag column
    page.insert_text((rect.x0 + 14, rect.y0 + 20), tag,
                     fontsize=8, fontname="cour", color=MUTED)
    page.draw_line((rect.x0 + 38, rect.y0 + 8),
                   (rect.x0 + 38, rect.y1 - 8), color=BORDER, width=0.8)
    # title
    page.insert_text((rect.x0 + 50, rect.y0 + 24), title,
                     fontsize=14, fontname="hebo", color=FG)
    page.insert_textbox(
        fitz.Rect(rect.x0 + 50, rect.y0 + 28, rect.x1 - 24, rect.y1 - 6),
        detail, fontsize=7, fontname="cour", color=DIM,
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
                     label, fontsize=9, fontname="cour", color=BLACK)
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
    # STAKE + DXF hero
    page.insert_text((r.x0 + 14, y + 30), "STAKE",
                     fontsize=32, fontname="hebo", color=FG)
    page.insert_text((r.x0 + 14 + 82, y + 30), "DXF",
                     fontsize=32, fontname="hebo", color=ORANGE)
    page.insert_text((r.x0 + 14, y + 44),
                     "FIELD-KIT / TSC5 / TRIMBLE",
                     fontsize=6, fontname="cour", color=MUTED)
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
                         fontsize=6, fontname="cour", color=MUTED)
        page.insert_text((cx0 + 6, cy0 + 32), val,
                         fontsize=9, fontname="cour", color=FG)


def ui_convert(page, r: fitz.Rect):
    y = r.y0 + 12
    # Header (page title style)
    page.insert_text((r.x0 + 14, y + 12), "◂  CONVERT / DWG → DXF",
                     fontsize=8, fontname="cour", color=ORANGE)
    y += 24
    # Input slot
    slot = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 60)
    page.draw_rect(slot, color=ORANGE, fill=CARD, width=1.4)
    page.insert_text((slot.x0 + 12, slot.y0 + 16), "DRAWING",
                     fontsize=6, fontname="cour", color=MUTED)
    page.insert_text((slot.x0 + 12, slot.y0 + 32), "ALPINE_HILLS.DWG",
                     fontsize=9, fontname="cour", color=FG)
    page.insert_text((slot.x0 + 12, slot.y0 + 46),
                     "TRIO/PROJECTS/ALPINE/…",
                     fontsize=6, fontname="cour", color=MUTED)
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
                     fontsize=7, fontname="cour", color=OK)
    page.insert_text((res.x0 + 12, res.y0 + 40),
                     "RECOVERED 390 ENTITIES · 12 LAYERS",
                     fontsize=8, fontname="cour", color=FG)
    kvs = [("STAKEABLE", "390"), ("LAYERS", "12"),
           ("PROXIES", "148"), ("FILE", "ALPINE_HILLS_TRIMBLE.DXF")]
    for i, (k, v) in enumerate(kvs):
        yy = res.y0 + 56 + i * 12
        page.insert_text((res.x0 + 12, yy), k,
                         fontsize=6, fontname="cour", color=MUTED)
        page.insert_text((res.x0 + 68, yy), v,
                         fontsize=7, fontname="cour", color=FG)
    y = res.y1 + 8
    # Layer checklist header
    lch = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 24)
    page.draw_rect(lch, color=None, fill=ELEVATED)
    page.draw_rect(lch, color=BORDER, fill=None, width=0.8)
    page.insert_text((lch.x0 + 10, lch.y0 + 15), "LAYERS",
                     fontsize=7, fontname="cour", color=FG)
    page.insert_text((lch.x0 + 60, lch.y0 + 15), "3/12",
                     fontsize=7, fontname="cour", color=ORANGE)
    page.insert_text((lch.x1 - 30, lch.y0 + 15), "ALL",
                     fontsize=7, fontname="cour", color=ORANGE)
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
                         fontsize=7, fontname="cour", color=FG)
        page.insert_text((rr.x1 - 8 - len(str(cnt)) * 4, rr.y0 + 13),
                         str(cnt), fontsize=7, fontname="cour",
                         color=DIM if on else MUTED)
        rowy = rr.y1
    _primary_button(page,
                    fitz.Rect(r.x0 + 14, rowy + 8, r.x1 - 14, rowy + 44),
                    "SAVE DXF · 3 LAYERS")


def ui_export(page, r: fitz.Rect, mode="loaded"):
    y = r.y0 + 12
    page.insert_text((r.x0 + 14, y + 12), "◂  PLOT / EXPORT POINTS",
                     fontsize=8, fontname="cour", color=ORANGE)
    y += 26
    # Job field slot
    slot = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 42)
    page.draw_rect(slot, color=BORDER, fill=CARD, width=0.8)
    page.insert_text((slot.x0 + 12, slot.y0 + 14), "JOB",
                     fontsize=6, fontname="cour", color=MUTED)
    page.insert_text((slot.x0 + 12, slot.y0 + 30), "ALPINE_HILLS",
                     fontsize=10, fontname="cour", color=FG)
    y = slot.y1 + 8
    # Import buttons
    for label in ("IMPORT POINTS CSV", "LINK DXF LINEWORK"):
        rr = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 30)
        page.draw_rect(rr, color=BORDER_STRONG, fill=CARD, width=0.8)
        page.insert_text((rr.x0 + 14, rr.y0 + 19), label,
                         fontsize=8, fontname="cour", color=FG)
        page.insert_text((rr.x1 - 22, rr.y0 + 19), "▸",
                         fontsize=9, fontname="hebo", color=ORANGE)
        y = rr.y1 + 6
    if mode == "empty":
        page.insert_textbox(
            fitz.Rect(r.x0 + 14, y + 12, r.x1 - 14, y + 60),
            "IMPORT A PNEZD CSV\nFROM TRIMBLE ACCESS TO BEGIN.",
            fontsize=7, fontname="cour", color=MUTED,
        )
        return
    # Section: PLOT OPTS
    _section_rule(page, r.x0 + 14, y + 12, r.x1 - 14, "PLOT OPTIONS")
    y += 22
    for label, value in (("MARKER", "LARGE X"),
                        ("LABEL", "NUM + ELEV"),
                        ("SCALE", "1\"=40'"),
                        ("SHEET", "ANSI B  17×11 LAND.")):
        rr = fitz.Rect(r.x0 + 14, y, r.x1 - 14, y + 24)
        page.draw_rect(rr, color=BORDER, fill=CARD, width=0.8)
        page.insert_text((rr.x0 + 10, rr.y0 + 15), label,
                         fontsize=7, fontname="cour", color=MUTED)
        page.insert_text((rr.x0 + 90, rr.y0 + 15), value,
                         fontsize=7, fontname="cour", color=FG)
        y = rr.y1 + 4
    # Layer toggles (mini)
    y += 4
    _section_rule(page, r.x0 + 14, y, r.x1 - 14, "LAYERS 3/3")
    y += 12
    for layer in ("CL", "CURB", "STRUCT"):
        _tick(page, r.x0 + 16, y + 3, on=True)
        page.insert_text((r.x0 + 32, y + 11), layer,
                         fontsize=7, fontname="cour", color=FG)
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
                     fontsize=8, fontname="cour", color=FG)


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
    # split hero title with orange DXF
    page.insert_text((40, 260), "STAKE", fontsize=110, fontname="hebo", color=FG)
    page.insert_text((40 + 300, 260), "DXF", fontsize=110, fontname="hebo", color=ORANGE)
    page.insert_text((40, 300), "UI & CAPABILITIES  ·  v1.22", fontsize=14,
                     fontname="cour", color=MUTED)
    page.draw_line((40, 320), (SLIDE_W - 40, 320), color=BORDER, width=1)
    page.insert_textbox(
        fitz.Rect(40, 340, 720, 440),
        "Rugged on-device field kit — Civil 3D DWG → Trimble DXF recovery\n"
        "and scaled staking-plot PDFs on the TSC5 handheld.",
        fontsize=16, color=DIM,
    )
    # tech readout
    page.insert_text((40, 500), "ENGINE",
                     fontsize=8, fontname="cour", color=MUTED)
    page.insert_text((40, 516), "LIBREDWG · EZDXF · FLUTTER",
                     fontsize=10, fontname="cour", color=FG)
    page.insert_text((260, 500), "OUTPUT",
                     fontsize=8, fontname="cour", color=MUTED)
    page.insert_text((260, 516), "DXF R2010 · PDF",
                     fontsize=10, fontname="cour", color=FG)
    page.insert_text((440, 500), "TARGET",
                     fontsize=8, fontname="cour", color=MUTED)
    page.insert_text((440, 516), "TRIMBLE TSC5",
                     fontsize=10, fontname="cour", color=FG)

    # 2 Agenda
    page = add(new_slide(doc, "AGENDA"))
    bullet_block(page, 40, 120,
                 ["Design system",
                  "Home / operations",
                  "CONVERT · DWG → DXF pipeline",
                  "PLOT · Export points + staking sheet",
                  "Plot customization",
                  "Staking plot examples",
                  "Install on Trimble TSC5",
                  "Field workflow end-to-end"],
                 size=15, gap=30)

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
                         fontsize=10, fontname="cour", color=FG)
        r = int(col[0] * 255)
        g = int(col[1] * 255)
        b = int(col[2] * 255)
        page.insert_text((cx + 92, cy + 40),
                         f"#{r:02X}{g:02X}{b:02X}",
                         fontsize=8, fontname="cour", color=MUTED)
    # Principles
    page.insert_text((40, 380), "PRINCIPLES",
                     fontsize=10, fontname="cour", color=MUTED)
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
        fontsize=15, color=DIM,
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
    _section_rule(page, 40, 310, SLIDE_W - 40, "LAYOUT & LINEWORK")
    bullet_block(page, 40, 330,
                 ["Point list table optional (off by default for staking)",
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
                             fontsize=9, fontname="cour", color=DIM)

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
                     fontsize=54, fontname="hebo", color=FG)
    page.draw_line((40, 300), (SLIDE_W - 40, 300), color=ORANGE, width=2)
    page.insert_text((40, 340), "STAKEDXF · TSC5",
                     fontsize=20, fontname="cour", color=ORANGE)
    page.insert_text((40, 380),
                     "RECOVER LINEWORK. PLOT POINTS. STAKE WITH CONFIDENCE.",
                     fontsize=12, fontname="cour", color=MUTED)

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
        page.draw_rect(fitz.Rect(0, 0, W, 44), color=None, fill=BG)
        page.draw_line((0, 44), (W, 44), color=ORANGE, width=2)
        page.insert_text((40, 30), title.upper(),
                         fontsize=14, fontname="hebo", color=FG)
        return page

    # Cover
    page = doc.new_page(width=W, height=H)
    page.draw_rect(page.rect, color=None, fill=BG)
    page.draw_rect(fitz.Rect(0, 0, W, 8), color=None, fill=ORANGE)
    page.insert_text((48, 250), "STAKE",
                     fontsize=42, fontname="hebo", color=FG)
    page.insert_text((48 + 132, 250), "DXF",
                     fontsize=42, fontname="hebo", color=ORANGE)
    page.draw_line((48, 270), (W - 48, 270), color=BORDER, width=1)
    page.insert_text((48, 300), "USER GUIDE  ·  v1.22",
                     fontsize=16, fontname="cour", color=DIM)
    page.insert_textbox(
        fitz.Rect(48, 340, 520, 460),
        "Install · Usage · Help\nTrimble TSC5 field controller app\nTRIO Engineering",
        fontsize=13, color=MUTED,
    )
    page.insert_text((48, 720),
                     "Companion to StakeDXF_UI_Slide_Deck.pdf",
                     fontsize=9, fontname="cour", color=MUTED)

    def body_text(page, text):
        page.insert_textbox(fitz.Rect(40, 68, W - 40, H - 50),
                            text, fontsize=11, color=(0, 0, 0))

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
        "Layout\n"
        "• Point list table off by default — more plan area for staking.\n"
        "• Turn the table on for a control-note style coordinate list.\n"
        "• Sheet: ANSI A–D, portrait/landscape, auto or fixed engineering scale.\n\n"
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

| Option | Choices |
| --- | --- |
| Markers | Filled triangle, triangle outline, cross (+), X, large X, circle, dot, large dot |
| Labels | Number · number+description · number+elevation · number+description+elevation · none |
| Point list table | Off by default; optional on |
| Linework | Optional linked DXF layers |
| Scale | Auto engineering scale, or fixed `1"=N'` |
| Sheet | ANSI A–D, portrait or landscape |
| Colors | Full ACI, CTB, HSV true-color |
| Layer lock | Lk column — locked layers can't be dragged |

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
1. Title — STAKE·DXF · UI & Capabilities · v1.22
2. Agenda
3. Design system (tokens + principles)
4. Home / Operations (rugged action rails)
5. CONVERT · DWG → DXF pipeline
6. PLOT · Export Points — start
7. PLOT · Customize + Create
8. Plot customization matrix
9–10. Staking plot example galleries
11. Install on Trimble TSC5
12. Field workflow
13. Docs & help
14. Ready for the field.
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
