#!/usr/bin/env python3
"""Generate StakeDXF UI Markup Catalog PDF.

Purpose: give reviewers a complete, ID-tagged inventory of every live UI
control so they can mark KEEP / REMOVE / CHANGE and return precise feedback.

Output: dist/StakeDXF_UI_Markup_Catalog.pdf
"""

from __future__ import annotations

from pathlib import Path

import fitz

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
OUT = DIST / "StakeDXF_UI_Markup_Catalog.pdf"
APP_VERSION = "1.26.3"

# Instrument palette (mirrors plot_ui_theme.dart)
BG = (0.98, 0.98, 0.99)
CARD = (1, 1, 1)
HEADER = (0.031, 0.039, 0.047)
FG = (0.12, 0.14, 0.18)
MUTED = (0.40, 0.44, 0.50)
ORANGE = (1.000, 0.353, 0.122)
BORDER = (0.78, 0.80, 0.84)
ROW_ALT = (0.96, 0.97, 0.98)
CLUTTER = (1.0, 0.95, 0.90)
KEEP = (0.90, 0.96, 0.92)
REMOVE = (0.98, 0.90, 0.90)
CHANGE = (0.95, 0.94, 0.88)

FONT_DIR = ROOT / "mobile" / "stakedxf" / "assets" / "fonts"
FONT_SANS = FONT_DIR / "LiberationSans-Regular.ttf"
FONT_SANS_B = FONT_DIR / "LiberationSans-Bold.ttf"
FONT_MONO = FONT_DIR / "LiberationMono-Regular.ttf"
FONT_MONO_B = FONT_DIR / "LiberationMono-Bold.ttf"

F_BODY = "lsr"
F_BOLD = "lsb"
F_MONO = "lmr"
F_MONO_BOLD = "lmb"

# For width measurement only (get_text_length is Base-14 limited).
_MEAS_BODY = fitz.Font(fontfile=str(FONT_SANS))
_MEAS_MONO = fitz.Font(fontfile=str(FONT_MONO))


def text_w(text: str, *, mono: bool = False, size: float = 9.5) -> float:
    font = _MEAS_MONO if mono else _MEAS_BODY
    return font.text_length(text, fontsize=size)

# US Letter portrait — easy to print & mark up
PAGE_W, PAGE_H = 612, 792  # 8.5 x 11
MARGIN = 36
CONTENT_W = PAGE_W - 2 * MARGIN


def register_fonts(page: fitz.Page) -> None:
    page.insert_font(fontname=F_BODY, fontfile=str(FONT_SANS))
    page.insert_font(fontname=F_BOLD, fontfile=str(FONT_SANS_B))
    page.insert_font(fontname=F_MONO, fontfile=str(FONT_MONO))
    page.insert_font(fontname=F_MONO_BOLD, fontfile=str(FONT_MONO_B))


def new_page(doc: fitz.Document, footer: str) -> fitz.Page:
    page = doc.new_page(width=PAGE_W, height=PAGE_H)
    register_fonts(page)
    page.draw_rect(page.rect, color=None, fill=BG)
    # Top bar
    page.draw_rect(fitz.Rect(0, 0, PAGE_W, 28), color=None, fill=HEADER)
    page.insert_text(
        (MARGIN, 18),
        f"STAKE·DXF  ·  UI MARKUP CATALOG  ·  v{APP_VERSION}",
        fontname=F_MONO_BOLD,
        fontsize=8,
        color=(0.95, 0.96, 0.97),
    )
    # Footer
    page.draw_line(
        (MARGIN, PAGE_H - 28),
        (PAGE_W - MARGIN, PAGE_H - 28),
        color=BORDER,
        width=0.6,
    )
    page.insert_text(
        (MARGIN, PAGE_H - 14),
        footer,
        fontname=F_MONO,
        fontsize=7,
        color=MUTED,
    )
    page.insert_text(
        (PAGE_W - MARGIN - 80, PAGE_H - 14),
        f"page {page.number + 1}",
        fontname=F_MONO,
        fontsize=7,
        color=MUTED,
    )
    return page


def h1(page: fitz.Page, y: float, text: str) -> float:
    page.insert_text((MARGIN, y), text, fontname=F_BOLD, fontsize=16, color=FG)
    return y + 22


def h2(page: fitz.Page, y: float, text: str) -> float:
    page.insert_text((MARGIN, y), text, fontname=F_BOLD, fontsize=12, color=FG)
    page.draw_line((MARGIN, y + 4), (PAGE_W - MARGIN, y + 4), color=ORANGE, width=1.2)
    return y + 18


def body(page: fitz.Page, y: float, text: str, size: float = 9.5) -> float:
    # Simple wrap
    words = text.split()
    line = ""
    x = MARGIN
    max_w = CONTENT_W
    for w in words:
        trial = (line + " " + w).strip()
        tw = text_w(trial, size=size)
        if tw > max_w and line:
            page.insert_text((x, y), line, fontname=F_BODY, fontsize=size, color=FG)
            y += size + 3
            line = w
        else:
            line = trial
    if line:
        page.insert_text((x, y), line, fontname=F_BODY, fontsize=size, color=FG)
        y += size + 3
    return y + 4


def bullet(page: fitz.Page, y: float, text: str) -> float:
    page.insert_text((MARGIN, y), "•", fontname=F_BOLD, fontsize=10, color=ORANGE)
    # wrap indented
    words = text.split()
    line = ""
    x = MARGIN + 12
    max_w = CONTENT_W - 12
    first = True
    for w in words:
        trial = (line + " " + w).strip()
        tw = text_w(trial, size=9.5)
        if tw > max_w and line:
            page.insert_text(
                (x if not first else x, y),
                line,
                fontname=F_BODY,
                fontsize=9.5,
                color=FG,
            )
            y += 13
            line = w
            first = False
        else:
            line = trial
    if line:
        page.insert_text((x, y), line, fontname=F_BODY, fontsize=9.5, color=FG)
        y += 14
    return y


# ---------------------------------------------------------------------------
# Inventory data
# ---------------------------------------------------------------------------

# Each item: (id, description, flag)
# flag: "" | "chrome" | "clutter" | "android" | "conditional"

HOME = [
    ("HOME.RIBBON", "Top instrument bar (SDX · version)", "chrome"),
    ("HOME.RIBBON.ONLINE", "ONLINE status chip", "chrome"),
    ("HOME.RIBBON.LOCAL", "LOCAL status chip", "chrome"),
    ("HOME.HERO.BRAND", "STAKE·DXF wordmark", ""),
    ("HOME.HERO.SUB", "FIELD-KIT / TSC5 / TRIMBLE subtitle", "chrome"),
    ("HOME.OPS.HDR", "OPERATIONS section label", "chrome"),
    ("HOME.RAIL.CONVERT", "01 CONVERT — open DWG→DXF", ""),
    ("HOME.RAIL.PLOT", "02 PLOT — open Export Points", ""),
    ("HOME.RAIL.BASE", "03 BASE — open combine DWGs", ""),
    ("HOME.STATUS.HDR", "STATUS section label", "chrome"),
    ("HOME.STATUS.ENGINE", "Engine readout (LIBREDWG)", "chrome"),
    ("HOME.STATUS.OUTPUT", "Output readout (DXF R2010)", "chrome"),
    ("HOME.STATUS.MODE", "Mode readout (ON-DEVICE)", "chrome"),
    ("HOME.FOOTER", "TRIO / FIELD OPS · NO CLOUD footer", "chrome"),
]

CONVERT = [
    ("CONVERT.APPBAR.BACK", "Back to Home", ""),
    ("CONVERT.APPBAR.TITLE", "CONVERT / DWG → DXF title", ""),
    ("CONVERT.INPUT", "Pick single DWG/DXF file", ""),
    ("CONVERT.RUN", "Run conversion", "android"),
    ("CONVERT.PROGRESS.BAR", "Progress bar while converting", "conditional"),
    ("CONVERT.PROGRESS.MSG", "Stage / percent text", "conditional"),
    ("CONVERT.PROGRESS.HINT", "BACKGROUND: SAFE TO SWITCH APPS", "chrome"),
    ("CONVERT.ERROR", "Error message block", "conditional"),
    ("CONVERT.RESULT", "Success stats (stakeable, layers, proxies)", "conditional"),
    ("CONVERT.LAYERS.HDR", "Layer list header + count", "conditional"),
    ("CONVERT.LAYERS.ALLNONE", "Select all / none layers", "conditional"),
    ("CONVERT.LAYERS.ROW", "Per-layer toggle + entity count", "conditional"),
    ("CONVERT.SAVE", "Share DXF for selected layers only", "conditional"),
    ("CONVERT.SHARE", "Share full unfiltered DXF", "conditional"),
]

BASE = [
    ("BASE.APPBAR.BACK", "Back to Home", ""),
    ("BASE.APPBAR.TITLE", "BASE / COMBINE DWG title", ""),
    ("BASE.INPUT", "Multi-pick project DWG/DXF files", ""),
    ("BASE.INPUT.ROW.RM", "Remove one drawing from list", ""),
    ("BASE.BUILD", "Combine into one base DXF", "android"),
    ("BASE.PROGRESS.BAR", "Progress bar while combining", "conditional"),
    ("BASE.PROGRESS.MSG", "Stage / percent text", "conditional"),
    ("BASE.PROGRESS.HINT", "Background-safe hint", "chrome"),
    ("BASE.ERROR", "Error message block", "conditional"),
    ("BASE.RESULT", "Success readout (sources, layers)", "conditional"),
    ("BASE.LAYERS.HDR", "Layer checklist header", "conditional"),
    ("BASE.LAYERS.ALLNONE", "Select all / none", "conditional"),
    ("BASE.LAYERS.ROW", "Per-layer toggle + count", "conditional"),
    ("BASE.SAVE", "Share selected-layers DXF", "conditional"),
    ("BASE.SHARE", "Share full base DXF", "conditional"),
]

PLOT_CORE = [
    ("PLOT.APPBAR.BACK", "Back to Home", ""),
    ("PLOT.APPBAR.TITLE", "Export Points title", ""),
    ("PLOT.JOB", "Job name text field", ""),
    ("PLOT.IMPORT.CSV", "Import points CSV/TXT (PNEZD)", ""),
    ("PLOT.IMPORT.DXF", "Link DXF linework", ""),
    ("PLOT.IMPORT.DXF.CLEAR", "Unlink DXF", "conditional"),
    ("PLOT.MSG.ERROR", "Inline error text", "conditional"),
    ("PLOT.MSG.STATUS", "Inline status text", "conditional"),
    ("PLOT.PREVIEW.TOGGLE", "Show / Hide plot preview", ""),
    ("PLOT.PREVIEW.CANVAS", "Interactive plan canvas (drag / tap / trim)", ""),
    ("PLOT.CHIP.SPREAD", "Spread labels now", ""),
    ("PLOT.CHIP.TRIM", "Trim / line-edit mode toggle", ""),
    ("PLOT.CHIP.RESET_LABELS", "Reset all label drag offsets", "conditional"),
    ("PLOT.FOOTER.PDF", "Create / share staking PDF", ""),
    ("PLOT.FOOTER.CSV", "Export selected points CSV", ""),
]

PLOT_PT = [
    ("PLOT.PT.HDR", "Selected point header + DRAGGED badge", "conditional"),
    ("PLOT.PT.CLOSE", "Deselect point", "conditional"),
    ("PLOT.PT.META", "N / E / Z · description readout", "conditional"),
    ("PLOT.PT.LABEL.CHIP", "Per-point label format chips", "conditional"),
    ("PLOT.PT.COLOR.SWATCH", "Quick color circles", "conditional"),
    ("PLOT.PT.COLOR.DEFAULT", "Clear color override", "conditional"),
    ("PLOT.PT.LABEL.TEXT", "Custom label text field", "conditional"),
    ("PLOT.PT.RESET.DRAG", "Reset this point’s drag", "conditional"),
    ("PLOT.PT.RESET.ALL", "Reset style + drag for point", "conditional"),
]

PLOT_SYM = [
    ("PLOT.SYM.NAME", "Selected object name", "conditional"),
    ("PLOT.SYM.EDIT", "Re-open symbol library", "conditional"),
    ("PLOT.SYM.DELETE", "Remove selected object", "conditional"),
    ("PLOT.SYM.COLOR", "Open color picker", "conditional"),
    ("PLOT.SYM.COLOR.PRESET", "Quick preset swatches", "conditional"),
    ("PLOT.SYM.SCALE", "Object scale slider", "conditional"),
    ("PLOT.SYM.OPACITY", "Object opacity slider", "conditional"),
]

PLOT_OPTS = [
    ("PLOT.OPTS.HDR", "Expand/collapse PLOT OPTIONS", ""),
    ("PLOT.OPTS.TEMPLATE", "Sheet template cards (ANSI A–D × P/L)", ""),
    ("PLOT.OPTS.TEXTSTYLE", "Open text-style picker", ""),
    ("PLOT.OPTS.MARKER", "Point marker style dropdown", ""),
    ("PLOT.OPTS.LABEL.CHIP", "Default label format chips", ""),
    ("PLOT.OPTS.SCALE", "Open engineering-scale picker", ""),
    ("PLOT.OPTS.ANNOT", "Annotation scale slider", ""),
    ("PLOT.OPTS.ANNOT.HINT", "Explains scale vs annotation", "chrome"),
    ("PLOT.OPTS.SPREAD", "Auto-spread labels switch", ""),
    ("PLOT.OPTS.POINTLIST", "Point list table switch (currently no-op)", "clutter"),
    ("PLOT.OPTS.OBJLABELS", "Show labels on library objects", ""),
]

PLOT_LW = [
    ("PLOT.LW.HDR", "Expand/collapse LAYERS section", "conditional"),
    ("PLOT.LW.DRAW", "Include DXF linework on plot", "conditional"),
    ("PLOT.TRIM.BANNER", "Selected entity info when Trim ON", "conditional"),
    ("PLOT.TRIM.EXPLODE", "Explode selected entity", "conditional"),
    ("PLOT.TRIM.DEL_SEG", "Delete selected segment", "conditional"),
    ("PLOT.TRIM.DEL_NODE", "Delete selected vertex", "conditional"),
    ("PLOT.TRIM.DELETE", "Delete whole entity", "conditional"),
]

PLOT_LPM = [
    ("PLOT.LPM.TITLE", "LAYER PROPERTIES MANAGER title", ""),
    ("PLOT.LPM.TOOL.ALL_ON", "Turn all layers on", ""),
    ("PLOT.LPM.TOOL.ALL_OFF", "Turn all layers off", ""),
    ("PLOT.LPM.TOOL.INVERT", "Invert on/off", ""),
    ("PLOT.LPM.TOOL.LOCK_ALL", "Lock all layers", ""),
    ("PLOT.LPM.TOOL.UNLOCK_ALL", "Unlock all layers", ""),
    ("PLOT.LPM.TOOL.RESET_SEL", "Reset overrides on current layer", ""),
    ("PLOT.LPM.TOOL.RESET_ALL", "Reset all layer overrides", ""),
    ("PLOT.LPM.TOOL.REFRESH", "Force refresh / rebuild sort", "clutter"),
    ("PLOT.LPM.FILTER.ALL", "Filter: all layers", ""),
    ("PLOT.LPM.FILTER.ON", "Filter: on only", ""),
    ("PLOT.LPM.FILTER.OFF", "Filter: off only", ""),
    ("PLOT.LPM.FILTER.LOCKED", "Filter: locked only", ""),
    ("PLOT.LPM.FILTER.OVERRIDDEN", "Filter: overridden only", ""),
    ("PLOT.LPM.FILTER.ALLNONE", "Parent all/none toggle", ""),
    ("PLOT.LPM.SEARCH", "Search layers by name", ""),
    ("PLOT.LPM.SEARCH.CLEAR", "Clear search", ""),
    ("PLOT.LPM.COL.NAME", "Name column (sortable)", ""),
    ("PLOT.LPM.ROW.NAME", "Select layer row", ""),
    ("PLOT.LPM.COL.ON", "Lightbulb on/off", ""),
    ("PLOT.LPM.COL.FRZ", "Freeze toggle (= On alias)", "clutter"),
    ("PLOT.LPM.COL.LK", "Lock / unlock", ""),
    ("PLOT.LPM.COL.COLOR", "Layer color picker", ""),
    ("PLOT.LPM.COL.LINETYPE", "Linetype picker", ""),
    ("PLOT.LPM.COL.LW", "Lineweight picker", ""),
    ("PLOT.LPM.COL.TRANS", "Transparency picker", ""),
    ("PLOT.LPM.COL.LTS", "Per-layer linetype scale", ""),
    ("PLOT.LPM.FOOTER.LTS", "Global linetype scale slider", ""),
    ("PLOT.LPM.FOOTER.HINT", "Usage tip text", "chrome"),
]

PLOT_OBJ = [
    ("PLOT.OBJ.HDR", "Expand/collapse OBJECTS", ""),
    ("PLOT.OBJ.CLEAR", "Clear all placed objects", ""),
    ("PLOT.OBJ.HINT", "Scale-independence note", "chrome"),
    ("PLOT.OBJ.PAPER", "Base paper size (in) for symbols", ""),
    ("PLOT.OBJ.ADD", "Open symbol library to place", ""),
    ("PLOT.OBJ.ROW", "Select object in list", ""),
    ("PLOT.OBJ.ROW.EDIT", "Edit via library sheet", ""),
    ("PLOT.OBJ.ROW.DEL", "Remove from list", ""),
]

PLOT_ANN = [
    ("PLOT.ANN.HDR", "Expand/collapse TITLE / TEXT", ""),
    ("PLOT.ANN.TITLE.ON", "Show plot title on sheet", ""),
    ("PLOT.ANN.TITLE.TEXT", "Title string", ""),
    ("PLOT.ANN.TITLE.SIZE", "Title font size (pt)", ""),
    ("PLOT.ANN.TITLE.HINT", "Drag-to-reposition hint", "chrome"),
    ("PLOT.ANN.TITLE.RESET", "Reset title paper position", ""),
    ("PLOT.ANN.TEXT.ADD", "Add free text at point centroid", ""),
    ("PLOT.ANN.TEXT.ROW", "Select text object", ""),
    ("PLOT.ANN.TEXT.ROW.DEL", "Delete text object", ""),
    ("PLOT.ANN.TEXT.EDIT", "Selected text content field", ""),
    ("PLOT.ANN.TEXT.SCALE", "Text object scale", ""),
    ("PLOT.ANN.TEXT.OPACITY", "Text object opacity", ""),
    ("PLOT.ANN.TEXT.HINT", "Drag-on-preview hint", "chrome"),
]

PLOT_PTS = [
    ("PLOT.PTS.HDR", "Expand/collapse POINTS list", ""),
    ("PLOT.PTS.ALLNONE", "Select all / clear selection", ""),
    ("PLOT.PTS.ROW", "Include/exclude stake point", ""),
]

SHEETS = [
    ("SHEET.COLOR.TITLE", "Color picker title + ACI/hex + swatch", ""),
    ("SHEET.COLOR.TAB.ACI", "ACI / CTB tab", ""),
    ("SHEET.COLOR.TAB.TRUE", "True color tab", ""),
    ("SHEET.COLOR.ACI.GRID", "255 ACI swatch grid", ""),
    ("SHEET.COLOR.ACI.NUM", "Type ACI 1–255", ""),
    ("SHEET.COLOR.ACI.SET", "Apply typed ACI to preview", ""),
    ("SHEET.COLOR.ACI.APPLY", "Commit ACI color & close", ""),
    ("SHEET.COLOR.TRUE.GRID", "HSV quick grid", ""),
    ("SHEET.COLOR.TRUE.HUE", "Hue slider", ""),
    ("SHEET.COLOR.TRUE.SAT", "Saturation slider", ""),
    ("SHEET.COLOR.TRUE.VAL", "Value slider", ""),
    ("SHEET.COLOR.TRUE.HEX", "Hex #RRGGBB field", ""),
    ("SHEET.COLOR.TRUE.SET", "Apply typed hex", ""),
    ("SHEET.COLOR.TRUE.APPLY", "Commit true color & close", ""),
    ("SHEET.COLOR.BYLAYER", "Clear to ByLayer (layers)", "conditional"),
    ("SHEET.LTYPE", "Linetype list sheet", ""),
    ("SHEET.LTYPE.BYLAYER", "ByLayer linetype choice", ""),
    ("SHEET.LW", "Lineweight presets sheet", ""),
    ("SHEET.LW.BYLAYER", "ByLayer lineweight choice", ""),
    ("SHEET.TRANS", "Transparency slider sheet + RESET/APPLY", ""),
    ("SHEET.LTS", "Per-layer LTS slider sheet + RESET/APPLY", ""),
    ("SHEET.SYM.TITLE", "Symbol library title", ""),
    ("SHEET.SYM.CLOSE", "Dismiss without placing", ""),
    ("SHEET.SYM.HINT", "Place-then-drag instructions", "chrome"),
    ("SHEET.SYM.CAT", "Category chips (Utilities, Drainage, …)", ""),
    ("SHEET.SYM.FILTER", "Filter DWG blocks by name", "conditional"),
    ("SHEET.SYM.GRID", "Symbol / block tile grid", ""),
    ("SHEET.SYM.PREVIEW", "Sticky selected glyph + name", ""),
    ("SHEET.SYM.COLOR", "Color preset circles", ""),
    ("SHEET.SYM.SCALE", "Scale slider", ""),
    ("SHEET.SYM.ROTATE", "Rotation slider", ""),
    ("SHEET.SYM.ADV", "Expand Location / label (optional)", ""),
    ("SHEET.SYM.SNAP", "Snap to stake point", ""),
    ("SHEET.SYM.N", "Northing field", ""),
    ("SHEET.SYM.E", "Easting field", ""),
    ("SHEET.SYM.LABEL", "Optional label", ""),
    ("SHEET.SYM.PLACE", "Place / Update object", ""),
    ("SHEET.TEXTSTYLE.TITLE", "Text style picker title", ""),
    ("SHEET.TEXTSTYLE.FILTER", "Filter styles", ""),
    ("SHEET.TEXTSTYLE.ROW", "Pick a text style", ""),
    ("SHEET.SCALE.TITLE", "Engineering scale title", ""),
    ("SHEET.SCALE.AUTO", "Auto scale for extents", ""),
    ("SHEET.SCALE.PRESET", "Preset 1\"=N' list", ""),
    ("SHEET.SCALE.CUSTOM", "Custom ft-per-inch field", ""),
    ("SHEET.SCALE.APPLY", "Apply custom scale", ""),
]

SECTIONS: list[tuple[str, str, list[tuple[str, str, str]]]] = [
    ("01  HOME", "App launch · HomePage", HOME),
    ("02  CONVERT", "HOME.RAIL.CONVERT → ConvertDwgPage", CONVERT),
    ("03  BASE", "HOME.RAIL.BASE → BaseDwgPage", BASE),
    ("04  PLOT — core & preview", "HOME.RAIL.PLOT → ExportPointsScreen", PLOT_CORE),
    ("05  PLOT — point inspector", "When a label/point is selected on preview", PLOT_PT),
    ("06  PLOT — object inspector", "When a library object is selected", PLOT_SYM),
    ("07  PLOT — options", "Sticky section: PLOT OPTIONS", PLOT_OPTS),
    ("08  PLOT — layers & trim", "Sticky section: LAYERS (DXF linked)", PLOT_LW),
    ("09  PLOT — Layer Properties Manager", "Embedded Civil-style LPM under LAYERS", PLOT_LPM),
    ("10  PLOT — objects", "Sticky section: OBJECTS", PLOT_OBJ),
    ("11  PLOT — title / text", "Sticky section: TITLE / TEXT", PLOT_ANN),
    ("12  PLOT — points list", "Sticky section: POINTS", PLOT_PTS),
    ("13  Sheets & pickers", "Modals opened from Plot / LPM", SHEETS),
]


FLAG_LABEL = {
    "": "",
    "chrome": "secondary chrome",
    "clutter": "clutter candidate",
    "android": "Android-leaning",
    "conditional": "conditional",
}


def draw_legend(page: fitz.Page, y: float) -> float:
    page.insert_text((MARGIN, y), "LEGEND", fontname=F_BOLD, fontsize=9, color=FG)
    y += 14
    items = [
        (KEEP, "KEEP — leave as-is"),
        (REMOVE, "REMOVE — delete from UI"),
        (CHANGE, "CHANGE — keep but redesign / relocate"),
        (CLUTTER, "Flagged clutter / secondary chrome (review first)"),
    ]
    x = MARGIN
    for color, label in items:
        page.draw_rect(fitz.Rect(x, y - 8, x + 12, y + 2), color=BORDER, fill=color, width=0.4)
        page.insert_text((x + 16, y), label, fontname=F_BODY, fontsize=8, color=FG)
        x += 140
        if x > PAGE_W - 160:
            x = MARGIN
            y += 14
    return y + 18


def draw_howto(doc: fitz.Document) -> None:
    page = new_page(doc, "How to mark up this catalog")
    y = 48
    y = h1(page, y, "How to request UI changes")
    y = body(
        page,
        y,
        "This catalog lists every live control in StakeDXF with a stable ID. "
        "Use those IDs when you tell us what to remove or change — no screenshots required "
        "(though circling on a printed copy also works).",
    )
    y += 4
    y = h2(page, y, "Preferred reply formats")
    y = bullet(
        page,
        y,
        "One-liners:  REMOVE  PLOT.OPTS.POINTLIST   |   CHANGE  HOME.STATUS.* → hide on TSC5",
    )
    y = bullet(
        page,
        y,
        "Groups:  REMOVE all HOME.RIBBON.* and HOME.STATUS.*  (keep rails only)",
    )
    y = bullet(
        page,
        y,
        "Relocate:  CHANGE  PLOT.LPM → open as full-screen page instead of embedded",
    )
    y = bullet(
        page,
        y,
        "Severity: prefix MUST / NICE — e.g. MUST REMOVE PLOT.OPTS.ANNOT.HINT",
    )
    y += 6
    y = h2(page, y, "On each inventory page")
    y = bullet(page, y, "Circle or check  KEEP / REMOVE / CHANGE  in the right columns.")
    y = bullet(page, y, "Write a short note in NOTES (e.g. “move under More”, “too big on TSC5”).")
    y = bullet(page, y, "Orange-tinted rows are already flagged as chrome/clutter candidates.")
    y += 6
    y = h2(page, y, "Blank forms")
    y = bullet(
        page,
        y,
        "Last pages are blank change-request forms — list IDs + action + notes if you prefer a clean sheet.",
    )
    y += 8
    y = draw_legend(page, y)
    y += 4
    y = h2(page, y, "App map (entry points)")
    for line in [
        "HOME  →  01 CONVERT  (DWG → Trimble DXF)",
        "HOME  →  02 PLOT   (points CSV + DXF linework → staking PDF)",
        "HOME  →  03 BASE   (combine project DWGs → one base DXF)",
        "PLOT opens sheets: color · linetype · lineweight · transparency · LTS · symbols · text style · scale",
    ]:
        y = bullet(page, y, line)
    y += 10
    page.insert_text(
        (MARGIN, y),
        f"Catalog generated for StakeDXF v{APP_VERSION}  ·  Flutter UI as shipped on TSC5/Android",
        fontname=F_MONO,
        fontsize=8,
        color=MUTED,
    )


def draw_index(doc: fitz.Document) -> None:
    page = new_page(doc, "ID index")
    y = 48
    y = h1(page, y, "Quick ID index")
    y = body(page, y, "All stable IDs in this catalog. Page references are section numbers.")
    y += 4
    col_w = (CONTENT_W - 12) / 2
    items: list[tuple[str, str]] = []
    for title, _entry, rows in SECTIONS:
        sec = title.split()[0]
        for uid, _desc, _flag in rows:
            items.append((uid, sec))

    # two columns
    left = items[: (len(items) + 1) // 2]
    right = items[(len(items) + 1) // 2 :]
    y0 = y
    for col_x, col_items in ((MARGIN, left), (MARGIN + col_w + 12, right)):
        yy = y0
        for uid, sec in col_items:
            if yy > PAGE_H - 50:
                page = new_page(doc, "ID index (cont.)")
                yy = 48
                y0 = 48
            page.insert_text(
                (col_x, yy),
                uid,
                fontname=F_MONO,
                fontsize=6.5,
                color=FG,
            )
            page.insert_text(
                (col_x + col_w - 28, yy),
                f"§{sec}",
                fontname=F_MONO,
                fontsize=6.5,
                color=MUTED,
            )
            yy += 9


def draw_table_pages(
    doc: fitz.Document,
    title: str,
    entry: str,
    rows: list[tuple[str, str, str]],
) -> None:
    page = new_page(doc, title)
    y = 46
    y = h1(page, y, title)
    page.insert_text((MARGIN, y), f"Entry: {entry}", fontname=F_MONO, fontsize=8, color=MUTED)
    y += 14
    y = draw_legend(page, y)

    # Column headers
    # ID | Description | KEEP | REM | CHG | Notes
    cols = [
        (MARGIN, 118, "ID"),
        (MARGIN + 122, 168, "DESCRIPTION"),
        (MARGIN + 294, 28, "KEEP"),
        (MARGIN + 326, 36, "REMOVE"),
        (MARGIN + 366, 36, "CHANGE"),
        (MARGIN + 406, CONTENT_W - 406, "NOTES"),
    ]

    def header_row(pg: fitz.Page, yy: float) -> float:
        pg.draw_rect(
            fitz.Rect(MARGIN, yy - 10, PAGE_W - MARGIN, yy + 6),
            color=None,
            fill=HEADER,
        )
        for x, _w, label in cols:
            pg.insert_text(
                (x + 2, yy),
                label,
                fontname=F_MONO_BOLD,
                fontsize=6.5,
                color=(0.95, 0.96, 0.97),
            )
        return yy + 12

    y = header_row(page, y)
    row_h = 22

    for i, (uid, desc, flag) in enumerate(rows):
        if y + row_h > PAGE_H - 40:
            page = new_page(doc, f"{title} (cont.)")
            y = 48
            page.insert_text(
                (MARGIN, y),
                f"{title} — continued",
                fontname=F_BOLD,
                fontsize=11,
                color=FG,
            )
            y += 16
            y = header_row(page, y)

        # background
        if flag in ("clutter", "chrome"):
            fill = CLUTTER
        elif i % 2:
            fill = ROW_ALT
        else:
            fill = CARD
        r = fitz.Rect(MARGIN, y - 8, PAGE_W - MARGIN, y - 8 + row_h)
        page.draw_rect(r, color=BORDER, fill=fill, width=0.4)

        # ID
        page.insert_text(
            (cols[0][0] + 2, y + 4),
            uid,
            fontname=F_MONO_BOLD,
            fontsize=6.2,
            color=FG,
        )
        # Description (+ flag)
        flag_txt = FLAG_LABEL.get(flag, "")
        d = desc if not flag_txt else f"{desc}  [{flag_txt}]"
        # clip description
        while text_w(d, size=6.5) > cols[1][1] - 4 and len(d) > 8:
            d = d[:-2]
        if d != desc and not d.endswith("…]"):
            if not d.endswith("…"):
                d = d[:-1] + "…"
        page.insert_text(
            (cols[1][0] + 2, y + 4),
            d,
            fontname=F_BODY,
            fontsize=6.5,
            color=FG,
        )

        # Checkbox squares
        for cx, label_w in (
            (cols[2][0] + 8, cols[2][1]),
            (cols[3][0] + 10, cols[3][1]),
            (cols[4][0] + 10, cols[4][1]),
        ):
            box = fitz.Rect(cx, y - 2, cx + 9, y + 7)
            page.draw_rect(box, color=FG, fill=CARD, width=0.7)

        # Notes line
        page.draw_line(
            (cols[5][0] + 2, y + 8),
            (PAGE_W - MARGIN - 4, y + 8),
            color=BORDER,
            width=0.5,
        )

        y += row_h


def draw_blank_forms(doc: fitz.Document, count: int = 3) -> None:
    for n in range(1, count + 1):
        page = new_page(doc, f"Change request form {n}")
        y = 48
        y = h1(page, y, f"Change request form  ·  sheet {n}")
        y = body(
            page,
            y,
            "Fill ID + ACTION (KEEP / REMOVE / CHANGE) + NOTES. Attach more sheets if needed.",
        )
        y += 6
        # header
        headers = [
            (MARGIN, 130, "ID"),
            (MARGIN + 134, 54, "ACTION"),
            (MARGIN + 192, CONTENT_W - 192, "NOTES / WHAT TO DO"),
        ]
        page.draw_rect(
            fitz.Rect(MARGIN, y - 10, PAGE_W - MARGIN, y + 6),
            color=None,
            fill=HEADER,
        )
        for x, _w, lab in headers:
            page.insert_text(
                (x + 2, y),
                lab,
                fontname=F_MONO_BOLD,
                fontsize=7,
                color=(0.95, 0.96, 0.97),
            )
        y += 14
        for _ in range(22):
            r = fitz.Rect(MARGIN, y - 6, PAGE_W - MARGIN, y - 6 + 24)
            page.draw_rect(r, color=BORDER, fill=CARD, width=0.4)
            page.draw_line(
                (MARGIN + 134, y - 6),
                (MARGIN + 134, y - 6 + 24),
                color=BORDER,
                width=0.4,
            )
            page.draw_line(
                (MARGIN + 192, y - 6),
                (MARGIN + 192, y - 6 + 24),
                color=BORDER,
                width=0.4,
            )
            y += 24


def draw_cover(doc: fitz.Document) -> None:
    page = new_page(doc, "Cover")
    # Big brand block
    page.draw_rect(fitz.Rect(MARGIN, 80, PAGE_W - MARGIN, 220), color=None, fill=HEADER)
    page.draw_rect(fitz.Rect(MARGIN, 80, MARGIN + 6, 220), color=None, fill=ORANGE)
    page.insert_text(
        (MARGIN + 24, 130),
        "STAKE·DXF",
        fontname=F_BOLD,
        fontsize=36,
        color=(0.95, 0.96, 0.97),
    )
    page.insert_text(
        (MARGIN + 24, 160),
        "UI MARKUP CATALOG",
        fontname=F_MONO_BOLD,
        fontsize=14,
        color=ORANGE,
    )
    page.insert_text(
        (MARGIN + 24, 185),
        f"v{APP_VERSION}  ·  Complete control inventory for declutter review",
        fontname=F_MONO,
        fontsize=9,
        color=(0.78, 0.80, 0.84),
    )

    y = 250
    y = h2(page, y, "What this is")
    y = body(
        page,
        y,
        "A printable / markable inventory of every live StakeDXF UI control "
        "(Home, Convert, Base, Plot, Layer Properties Manager, and all pickers). "
        "Each control has a stable ID so you can reply with precise REMOVE / CHANGE requests.",
    )
    y += 6
    y = h2(page, y, "How to use (30 seconds)")
    y = bullet(page, y, "Print or open in any PDF app that allows markup.")
    y = bullet(page, y, "On each table: check KEEP, REMOVE, or CHANGE — write notes.")
    y = bullet(
        page,
        y,
        "Or reply in chat/email like:  REMOVE HOME.STATUS.*  ·  CHANGE PLOT.LPM → full screen",
    )
    y = bullet(page, y, "Orange-tinted rows are suggested clutter / secondary chrome.")
    y += 10
    y = h2(page, y, "Contents")
    for i, (title, _e, rows) in enumerate(SECTIONS, start=1):
        page.insert_text(
            (MARGIN, y),
            f"{title}   ({len(rows)} controls)",
            fontname=F_BODY,
            fontsize=9,
            color=FG,
        )
        y += 13
    y += 8
    page.insert_text(
        (MARGIN, y),
        "+ How to mark up  ·  ID index  ·  Blank change-request forms",
        fontname=F_MONO,
        fontsize=8,
        color=MUTED,
    )


def main() -> None:
    DIST.mkdir(parents=True, exist_ok=True)
    doc = fitz.open()
    draw_cover(doc)
    draw_howto(doc)
    draw_index(doc)
    for title, entry, rows in SECTIONS:
        draw_table_pages(doc, title, entry, rows)
    draw_blank_forms(doc, count=3)
    doc.save(OUT)
    doc.close()
    print(f"Wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
