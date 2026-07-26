#!/usr/bin/env python3
"""Generate StakeDXF UI slide deck + install/usage/help tutorial PDFs."""

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

# Brand
BG = (0.063, 0.086, 0.059)  # #10160F
SURFACE = (0.082, 0.125, 0.086)  # #152016
CARD = (0.086, 0.125, 0.078)
ORANGE = (0.894, 0.341, 0.180)  # #E4572E
TEXT = (0.93, 0.93, 0.90)
MUTED = (0.70, 0.72, 0.68)
WHITE = (1, 1, 1)
BLACK = (0, 0, 0)
SLIDE_W, SLIDE_H = 1120, 630  # 16:9-ish points
PHONE_W, PHONE_H = 280, 560


def _font(name="helv", bold=False):
    if bold:
        return "helv" if name == "helv" else name
    return name


def new_slide(doc: fitz.Document, title: str | None = None) -> fitz.Page:
    page = doc.new_page(width=SLIDE_W, height=SLIDE_H)
    # atmospheric background
    page.draw_rect(page.rect, color=None, fill=BG)
    # subtle top accent bar
    page.draw_rect(fitz.Rect(0, 0, SLIDE_W, 6), color=None, fill=ORANGE)
    if title:
        page.insert_text(
            (48, 48),
            title,
            fontsize=26,
            fontname="hebo",
            color=WHITE,
        )
    return page


def footer(page: fitz.Page, n: int, total: int, label="StakeDXF"):
    page.insert_text(
        (48, SLIDE_H - 22),
        f"{label}  ·  TRIO Engineering",
        fontsize=9,
        fontname="helv",
        color=MUTED,
    )
    page.insert_text(
        (SLIDE_W - 90, SLIDE_H - 22),
        f"{n} / {total}",
        fontsize=9,
        fontname="helv",
        color=MUTED,
    )


def bullet_block(page, x, y, lines, size=13, gap=22, color=TEXT, width=600):
    for i, line in enumerate(lines):
        page.insert_textbox(
            fitz.Rect(x, y + i * gap, x + width, y + i * gap + gap),
            f"•  {line}",
            fontsize=size,
            fontname="helv",
            color=color,
            align=fitz.TEXT_ALIGN_LEFT,
        )
    return y + len(lines) * gap


def draw_phone(page: fitz.Page, x: float, y: float, screen_drawer) -> None:
    """Draw a TSC5-ish phone chrome and call screen_drawer(inner_rect)."""
    outer = fitz.Rect(x, y, x + PHONE_W, y + PHONE_H)
    page.draw_rect(outer, color=(0.15, 0.15, 0.15), fill=(0.08, 0.08, 0.08), width=2)
    # bezel
    inner = fitz.Rect(x + 10, y + 28, x + PHONE_W - 10, y + PHONE_H - 18)
    page.draw_rect(inner, color=None, fill=BG)
    # status notch bar
    page.draw_rect(
        fitz.Rect(inner.x0, inner.y0, inner.x1, inner.y0 + 18),
        color=None,
        fill=(0.05, 0.07, 0.05),
    )
    page.insert_text((inner.x0 + 10, inner.y0 + 13), "9:41", fontsize=8, color=MUTED)
    page.insert_text((inner.x1 - 50, inner.y0 + 13), "TSC5", fontsize=8, color=MUTED)
    content = fitz.Rect(inner.x0, inner.y0 + 18, inner.x1, inner.y1)
    page.draw_rect(content, color=None, fill=BG)
    screen_drawer(page, content)


def card(page, rect, title, subtitle, icon_text="▸"):
    page.draw_rect(rect, color=ORANGE, fill=CARD, width=0.8)
    page.insert_text(
        (rect.x0 + 14, rect.y0 + 22),
        icon_text,
        fontsize=14,
        fontname="hebo",
        color=ORANGE,
    )
    page.insert_text(
        (rect.x0 + 34, rect.y0 + 22),
        title,
        fontsize=12,
        fontname="hebo",
        color=WHITE,
    )
    page.insert_textbox(
        fitz.Rect(rect.x0 + 34, rect.y0 + 28, rect.x1 - 8, rect.y1 - 6),
        subtitle,
        fontsize=8,
        fontname="helv",
        color=MUTED,
    )


def ui_home(page, r: fitz.Rect):
    page.insert_text((r.x0 + 14, r.y0 + 36), "StakeDXF", fontsize=22, fontname="hebo", color=WHITE)
    page.insert_textbox(
        fitz.Rect(r.x0 + 14, r.y0 + 48, r.x1 - 12, r.y0 + 100),
        "Recover Civil 3D linework, or build a staking plot from points on this controller.",
        fontsize=8,
        color=MUTED,
    )
    card(
        page,
        fitz.Rect(r.x0 + 12, r.y0 + 110, r.x1 - 12, r.y0 + 168),
        "Convert DWG → DXF",
        "Recover Civil 3D linework for Trimble Access",
        "≈",
    )
    card(
        page,
        fitz.Rect(r.x0 + 12, r.y0 + 180, r.x1 - 12, r.y0 + 238),
        "Export Points",
        "Select points → CSV or staking plot PDF",
        "◉",
    )
    page.insert_text(
        (r.x0 + 14, r.y1 - 24),
        "Runs entirely on this device. No cloud upload.",
        fontsize=7,
        color=MUTED,
    )


def ui_convert(page, r: fitz.Rect):
    page.insert_text((r.x0 + 12, r.y0 + 22), "←  Convert DWG", fontsize=11, fontname="hebo", color=WHITE)
    page.insert_textbox(
        fitz.Rect(r.x0 + 12, r.y0 + 36, r.x1 - 10, r.y0 + 80),
        "Recover stakeable linework, review layers with data, export a DXF for Trimble Access.",
        fontsize=8,
        color=MUTED,
    )
    card(
        page,
        fitz.Rect(r.x0 + 12, r.y0 + 88, r.x1 - 12, r.y0 + 132),
        "Choose DWG / DXF",
        "Civil 3D drawing with linework",
        "▤",
    )
    # primary button
    btn = fitz.Rect(r.x0 + 12, r.y0 + 142, r.x1 - 12, r.y0 + 178)
    page.draw_rect(btn, color=None, fill=ORANGE)
    page.insert_text((btn.x0 + 28, btn.y0 + 24), "Convert for Trimble Access", fontsize=10, fontname="hebo", color=BLACK)
    # result card with layer checklist
    res = fitz.Rect(r.x0 + 12, r.y0 + 190, r.x1 - 12, r.y0 + 400)
    page.draw_rect(res, color=(0.4, 0.7, 0.35), fill=(0.08, 0.14, 0.07), width=0.8)
    page.insert_text((res.x0 + 10, res.y0 + 18), "Recovered 390 entities on 12 layer(s)", fontsize=9, fontname="hebo", color=WHITE)
    page.insert_text((res.x0 + 10, res.y0 + 34), "Layers with data: 12 (empty layers omitted)", fontsize=7, color=MUTED)
    page.insert_text((res.x0 + 10, res.y0 + 52), "Converted layers (3/12)", fontsize=8, fontname="hebo", color=WHITE)
    y = res.y0 + 68
    for label in ("☑  P-CURB — 390 entities", "☑  P-U-STM — 649 entities", "☐  0 — 26804 entities"):
        page.insert_text((res.x0 + 14, y), label, fontsize=7, color=TEXT)
        y += 14
    sbtn = fitz.Rect(res.x0 + 10, res.y0 + 120, res.x1 - 10, res.y0 + 150)
    page.draw_rect(sbtn, color=None, fill=ORANGE)
    page.insert_text((sbtn.x0 + 40, sbtn.y0 + 20), "Save DXF (3 layers)", fontsize=9, fontname="hebo", color=BLACK)


def ui_export(page, r: fitz.Rect, mode="loaded"):
    page.insert_text((r.x0 + 12, r.y0 + 22), "←  Export Points", fontsize=11, fontname="hebo", color=WHITE)
    y = r.y0 + 40
    # job field
    page.draw_rect(fitz.Rect(r.x0 + 12, y, r.x1 - 12, y + 28), color=MUTED, fill=SURFACE, width=0.5)
    page.insert_text((r.x0 + 18, y + 12), "Job name", fontsize=7, color=MUTED)
    page.insert_text((r.x0 + 18, y + 24), "ALPINE HILLS", fontsize=9, fontname="hebo", color=WHITE)
    y += 36
    for label in ("Import points CSV / TXT", "Link DXF linework (optional)"):
        page.draw_rect(fitz.Rect(r.x0 + 12, y, r.x1 - 12, y + 26), color=ORANGE, fill=CARD, width=0.6)
        page.insert_text((r.x0 + 20, y + 17), label, fontsize=8, fontname="hebo", color=WHITE)
        y += 32
    if mode == "empty":
        page.insert_textbox(
            fitz.Rect(r.x0 + 12, y + 8, r.x1 - 12, y + 60),
            "Import a PNEZD CSV from Trimble Access to begin.",
            fontsize=8,
            color=MUTED,
        )
        return
    page.insert_text((r.x0 + 12, y + 8), "Plot options", fontsize=10, fontname="hebo", color=ORANGE)
    y += 22
    for label, value in (
        ("Point marker", "Large X"),
        ("Point label", "Number + elevation"),
    ):
        page.draw_rect(fitz.Rect(r.x0 + 12, y, r.x1 - 12, y + 30), color=MUTED, fill=SURFACE, width=0.5)
        page.insert_text((r.x0 + 18, y + 11), label, fontsize=7, color=MUTED)
        page.insert_text((r.x0 + 18, y + 24), value, fontsize=9, color=WHITE)
        y += 36
    # toggles
    page.insert_text((r.x0 + 12, y + 10), "○  Include point list table", fontsize=8, color=MUTED)
    page.insert_text((r.x0 + 12, y + 28), "●  Draw linked DXF linework", fontsize=8, color=WHITE)
    y += 46
    page.insert_text((r.x0 + 12, y), "Linework layers (3/3)", fontsize=8, fontname="hebo", color=WHITE)
    y += 14
    for layer in ("CL", "CURB", "STRUCTURE"):
        page.insert_text((r.x0 + 16, y + 12), f"☑  {layer}", fontsize=8, color=TEXT)
        y += 16
    y += 8
    page.insert_text((r.x0 + 12, y), "4 of 4 points selected", fontsize=8, fontname="hebo", color=WHITE)
    y += 14
    for pid, desc in (("700", "125 HUB"), ("701", "125 PK"), ("702", "125 PK")):
        page.insert_text((r.x0 + 16, y + 12), f"☑  {pid}  {desc}", fontsize=8, color=TEXT)
        y += 16
        if y > r.y1 - 90:
            break
    # bottom buttons
    btn = fitz.Rect(r.x0 + 12, r.y1 - 78, r.x1 - 12, r.y1 - 46)
    page.draw_rect(btn, color=None, fill=ORANGE)
    page.insert_text((btn.x0 + 22, btn.y0 + 21), "Create staking plot PDF", fontsize=9, fontname="hebo", color=BLACK)
    btn2 = fitz.Rect(r.x0 + 12, r.y1 - 38, r.x1 - 12, r.y1 - 10)
    page.draw_rect(btn2, color=ORANGE, fill=CARD, width=0.7)
    page.insert_text((btn2.x0 + 28, btn2.y0 + 18), "Export selected points CSV", fontsize=8, fontname="hebo", color=WHITE)


def insert_image_fit(page, rect: fitz.Rect, path: Path):
    if not path.exists():
        page.draw_rect(rect, color=MUTED, fill=SURFACE, width=0.5)
        page.insert_text((rect.x0 + 12, rect.y0 + 24), f"(missing {path.name})", fontsize=9, color=MUTED)
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
    page.insert_text((48, 220), "StakeDXF", fontsize=54, fontname="hebo", color=WHITE)
    page.insert_text((48, 270), "UI & Capabilities Slide Deck", fontsize=28, fontname="helv", color=ORANGE)
    page.insert_textbox(
        fitz.Rect(48, 320, 700, 420),
        "On-device Civil 3D DWG → Trimble DXF recovery\nand customizable staking plot PDFs for Trimble TSC5.",
        fontsize=16,
        color=MUTED,
    )
    page.insert_text((48, 480), "TRIO Engineering  ·  Field Controller App", fontsize=12, color=MUTED)

    # 2 Agenda
    page = add(new_slide(doc, "Agenda"))
    bullet_block(
        page,
        48,
        90,
        [
            "What StakeDXF does",
            "Home screen & navigation",
            "Convert DWG → DXF workflow",
            "Export Points & plot customization",
            "Staking plot PDF examples",
            "Install on Trimble TSC5",
            "Where to find help docs",
        ],
        size=16,
        gap=32,
    )

    # 3 What it does
    page = add(new_slide(doc, "What StakeDXF does"))
    bullet_block(
        page,
        48,
        100,
        [
            "Recover Civil 3D / AEC proxy linework into stakeable DXF",
            "Import Trimble point CSV / TXT (PNEZD)",
            "Build auto-scaled staking plot PDFs on the controller",
            "Optionally overlay DXF linework by layer",
            "Customize markers, labels, and point-list table",
            "Runs entirely on-device — no cloud upload",
        ],
        size=15,
        gap=30,
        width=900,
    )

    # 4 Home UI
    page = add(new_slide(doc, "Home screen"))
    draw_phone(page, 70, 70, ui_home)
    page.insert_textbox(
        fitz.Rect(400, 120, 1050, 500),
        "Two jobs from the home screen:\n\n"
        "1. Convert DWG → DXF\n"
        "   Recover Civil 3D linework for Trimble Access stakeout.\n\n"
        "2. Export Points\n"
        "   Select points, customize a staking plot PDF,\n"
        "   or export a trimmed CSV.\n\n"
        "Everything stays on the TSC5.",
        fontsize=14,
        color=TEXT,
    )

    # 5 Convert UI
    page = add(new_slide(doc, "Convert DWG → DXF"))
    draw_phone(page, 70, 55, ui_convert)
    bullet_block(
        page,
        400,
        110,
        [
            "Pick a Civil 3D .dwg or .dxf",
            "LibreDWG converts DWG → DXF on device",
            "Python (ezdxf) explodes ACAD_PROXY_ENTITY graphics",
            "Keeps Trimble-stakeable types only",
            "Save DXF into Trimble Data/Projects/<job>/",
            "Map files → selectable → Stakeout",
        ],
        size=13,
        gap=28,
        width=650,
    )

    # 6 Export empty
    page = add(new_slide(doc, "Export Points — start"))
    draw_phone(page, 70, 55, lambda p, r: ui_export(p, r, "empty"))
    bullet_block(
        page,
        400,
        120,
        [
            "Enter a job name for the sheet title",
            "Import points CSV / TXT from Trimble Access",
            "Optionally link a matching DXF for linework",
            "Then customize markers, labels, and layers",
        ],
        size=14,
        gap=30,
        width=650,
    )

    # 7 Export loaded
    page = add(new_slide(doc, "Export Points — customize & create"))
    draw_phone(page, 70, 55, lambda p, r: ui_export(p, r, "loaded"))
    bullet_block(
        page,
        400,
        100,
        [
            "Point marker: triangle, X, cross, circle, dot…",
            "Point label: number / desc / elev combinations",
            "Point list table: off by default (more plot space)",
            "DXF layers: check only what you want drawn",
            "Object library: place hydrants, signs, MH — move/scale/recolor",
            "Select which points appear on the sheet",
            "Create staking plot PDF or export CSV",
        ],
        size=13,
        gap=28,
        width=650,
    )

    # 8 Marker / label matrix
    page = add(new_slide(doc, "Plot customization options"))
    page.insert_text((48, 90), "Markers", fontsize=16, fontname="hebo", color=ORANGE)
    bullet_block(
        page,
        48,
        110,
        [
            "Filled triangle  ·  Triangle outline",
            "Cross (+)  ·  X  ·  Large X",
            "Circle  ·  Dot  ·  Large dot",
        ],
        size=13,
        gap=24,
        width=480,
    )
    page.insert_text((560, 90), "Labels", fontsize=16, fontname="hebo", color=ORANGE)
    bullet_block(
        page,
        560,
        110,
        [
            "Point number",
            "Number + description",
            "Number + elevation",
            "Number + description + elevation",
            "No labels",
        ],
        size=13,
        gap=24,
        width=480,
    )
    page.insert_text((48, 280), "Layout & linework", fontsize=16, fontname="hebo", color=ORANGE)
    bullet_block(
        page,
        48,
        300,
        [
            "Include point list table — optional (off by default for staking)",
            "Link DXF — draw LINE / LWPOLYLINE / ARC / CIRCLE by layer",
            "Engineering scale auto-picked so content fits the ANSI B sheet",
        ],
        size=13,
        gap=26,
        width=980,
    )

    # 9-12 Example plot gallery (2x2 grids)
    gallery = [
        ("01_field_staking_large_x.png", "Field staking — large X + elev"),
        ("02_control_note_style_table.png", "Control-note style + table"),
        ("03_markers_circle_dot.png", "Circles + curb layer"),
        ("04_markers_cross_plus.png", "Cross (+) number only"),
        ("06_markers_large_dot_no_labels.png", "Overview — dots, no labels"),
        ("07_labels_number_only.png", "Dense set — number only"),
        ("08_dot_with_elevations.png", "Grade check — elev labels"),
        ("09_full_sheet_with_table_and_linework.png", "Full sheet + linework"),
    ]
    for i in range(0, len(gallery), 4):
        chunk = gallery[i : i + 4]
        page = add(new_slide(doc, "Staking plot examples"))
        positions = [
            fitz.Rect(40, 80, 540, 330),
            fitz.Rect(560, 80, 1080, 330),
            fitz.Rect(40, 350, 540, 580),
            fitz.Rect(560, 350, 1080, 580),
        ]
        for (name, caption), rect in zip(chunk, positions):
            img_rect = fitz.Rect(rect.x0, rect.y0, rect.x1, rect.y1 - 22)
            insert_image_fit(page, img_rect, SHOTS / name)
            page.insert_text((rect.x0 + 4, rect.y1 - 6), caption, fontsize=10, color=MUTED)

    # Install
    page = add(new_slide(doc, "Install on Trimble TSC5"))
    bullet_block(
        page,
        48,
        100,
        [
            "Copy dist/Staking Plot vX.Y.Z.apk onto the TSC5 (USB or Files)",
            "Open the APK → allow Install from this source if prompted",
            "Open StakeDXF from the app drawer",
            "If Install is blocked, ask IT to allow unknown sources / MDM exception",
            "APK is Android-only — will not install on iPhone",
        ],
        size=15,
        gap=32,
        width=980,
    )

    # Field workflow
    page = add(new_slide(doc, "Field workflow (end-to-end)"))
    bullet_block(
        page,
        48,
        90,
        [
            "Office: save Civil 3D DWG with proxy graphics preserved",
            "TSC5: Convert DWG → DXF → Save into Trimble job folder",
            "Trimble Access: Map files → selectable → stake linework",
            "Export points CSV from Access for the shots you need",
            "StakeDXF Export Points → customize → Create staking plot PDF",
            "Keep the PDF open while staking for a scaled field sheet",
        ],
        size=14,
        gap=30,
        width=980,
    )

    # Help
    page = add(new_slide(doc, "Docs & help"))
    bullet_block(
        page,
        48,
        100,
        [
            "dist/INSTALL_TSC5.md — quick install card",
            "dist/StakeDXF_User_Guide.pdf — full install / usage / help",
            "docs/USER_GUIDE.md — same guide in Markdown",
            "dist/plot_examples/ — sample staking plot PDFs",
            "PR #6 — source, APK, and release notes",
        ],
        size=15,
        gap=32,
        width=980,
    )

    # Close
    page = add(new_slide(doc))
    page.insert_text((48, 250), "Ready for the field.", fontsize=40, fontname="hebo", color=WHITE)
    page.insert_text((48, 310), "StakeDXF on Trimble TSC5", fontsize=22, color=ORANGE)
    page.insert_text((48, 380), "Recover linework. Plot points. Stake with confidence.", fontsize=14, color=MUTED)

    total = len(pages)
    for i in range(total):
        footer(doc[i], i + 1, total)

    DIST.mkdir(parents=True, exist_ok=True)
    doc.save(OUT_SLIDES, garbage=4, deflate=True)
    doc.close()
    return OUT_SLIDES


def build_tutorial_pdf() -> Path:
    doc = fitz.open()
    # Letter portrait
    W, H = 612, 792

    def page_start(title: str) -> fitz.Page:
        page = doc.new_page(width=W, height=H)
        page.draw_rect(fitz.Rect(0, 0, W, 48), color=None, fill=BG)
        page.draw_rect(fitz.Rect(0, 48, W, 52), color=None, fill=ORANGE)
        page.insert_text((40, 32), title, fontsize=16, fontname="hebo", color=WHITE)
        return page

    def body(page, y, text, size=11, color=BLACK, indent=40):
        rect = fitz.Rect(indent, y, W - 40, y + 400)
        rc = page.insert_textbox(rect, text, fontsize=size, fontname="helv", color=color, align=0)
        # insert_textbox returns unused height (negative if overflow). Approximate used:
        lines = text.count("\n") + 1
        return y + max(18, int(lines * (size + 5)))

    # Cover
    page = doc.new_page(width=W, height=H)
    page.draw_rect(page.rect, color=None, fill=BG)
    page.draw_rect(fitz.Rect(0, 0, W, 8), color=None, fill=ORANGE)
    page.insert_text((48, 260), "StakeDXF", fontsize=42, fontname="hebo", color=WHITE)
    page.insert_text((48, 310), "User Guide", fontsize=28, color=ORANGE)
    page.insert_textbox(
        fitz.Rect(48, 360, 520, 460),
        "Install · Usage · Help\nTrimble TSC5 field controller app\nTRIO Engineering",
        fontsize=14,
        color=MUTED,
    )
    page.insert_text((48, 720), "Companion to StakeDXF_UI_Slide_Deck.pdf", fontsize=10, color=MUTED)

    # Install
    page = page_start("1. Installation (Trimble TSC5)")
    y = 80
    text = (
        "StakeDXF ships as an Android APK for the Trimble TSC5.\n\n"
        "File: dist/Staking Plot vX.Y.Z.apk  (~65 MB)\n"
        "Package: com.stakedxf.stakedxf\n\n"
        "Steps\n"
        "1. Copy Staking Plot vX.Y.Z.apk onto the TSC5 (USB File Transfer, or any file share you already use).\n"
        "2. On the TSC5 open Files / Downloads and tap the APK.\n"
        "3. If Android blocks it, enable Allow from this source for Files (or the app that opened the APK).\n"
        "4. Tap Install, then open StakeDXF from the app drawer.\n\n"
        "If Install is greyed out\n"
        "Company MDM may block unknown APKs. Ask IT to allow unknown-source installs or push the APK through managed distribution.\n\n"
        "Common mistakes\n"
        "• Trying to open the APK on iPhone — iOS cannot install Android APKs.\n"
        "• Opening a zip/repo instead of the .apk file.\n"
        "• USB mode left on Charging only — switch to File Transfer."
    )
    page.insert_textbox(fitz.Rect(40, y, W - 40, H - 50), text, fontsize=11, color=BLACK)

    # Usage convert
    page = page_start("2. Usage — Convert DWG → DXF")
    text = (
        "Purpose: turn a Civil 3D drawing into a Trimble-stakeable DXF on the controller.\n\n"
        "Steps\n"
        "1. Open StakeDXF → Convert DWG → DXF.\n"
        "2. Tap Choose DWG / DXF and pick the office drawing.\n"
        "3. Tap Convert for Trimble Access.\n"
        "4. Confirm stakeable entity count (and proxy explode count when Civil 3D proxies were present).\n"
        "5. Review Converted layers (empty layers are omitted).\n"
        "6. Check layers to include, then Save DXF (or share the full DXF).\n"
        "7. Place it in:\n"
        "      Trimble Data/Projects/<your project>/\n"
        "6. In Trimble Access: Map → Layer manager → Map files → make the DXF selectable → Stakeout.\n\n"
        "What happens on-device\n"
        "• LibreDWG reads the DWG into DXF.\n"
        "• ezdxf explodes ACAD_PROXY_ENTITY / AEC proxy graphics into LINE / ARC / POLYLINE.\n"
        "• Non-stakeable entity types are filtered out.\n\n"
        "Tip: Office DWGs should be saved with proxy graphics preserved so Civil 3D features can be recovered."
    )
    page.insert_textbox(fitz.Rect(40, 80, W - 40, H - 50), text, fontsize=11, color=BLACK)

    # Usage export
    page = page_start("3. Usage — Export Points & staking plots")
    text = (
        "Purpose: build a scaled field sheet from selected points (and optional DXF linework).\n\n"
        "Steps\n"
        "1. In Trimble Access, export the points you need as CSV / TXT (PNEZD).\n"
        "2. StakeDXF → Export Points.\n"
        "3. Import points CSV / TXT.\n"
        "4. (Optional) Link DXF linework and choose layers to draw.\n"
        "5. Set Point marker and Point label format.\n"
        "6. Leave Include point list table off unless you want the coordinate table.\n"
        "7. (Optional) Add from object library — place, nudge, scale, rotate, recolor.\n"
        "8. Select the points for the sheet.\n"
        "9. Tap Create staking plot PDF — scale is chosen automatically to fit.\n"
        "10. Or tap Export selected points CSV for a trimmed point list.\n\n"
        "Supported point formats\n"
        "• Headered or headerless PNEZD: Point, Northing, Easting, Elevation, Description\n"
        "• Also accepts common header aliases (Point #, Elev, Desc, etc.)\n\n"
        "Linked DXF linework\n"
        "• Reads LINE, LWPOLYLINE, POLYLINE, ARC, CIRCLE\n"
        "• Layer checklist lets you keep only relevant linework on the plot"
    )
    page.insert_textbox(fitz.Rect(40, 80, W - 40, H - 50), text, fontsize=11, color=BLACK)

    # Customization
    page = page_start("4. Plot customization reference")
    text = (
        "Markers\n"
        "Filled triangle · Triangle outline · Cross (+) · X · Large X · Circle · Dot · Large dot\n\n"
        "Labels\n"
        "Point number · Number + description · Number + elevation ·\n"
        "Number + description + elevation · No labels\n\n"
        "Layout\n"
        "• Point list table OFF by default — gives the plan view more sheet space.\n"
        "• Turn the table ON for a control-note style coordinate list.\n"
        "• Sheet size is ANSI B landscape (17\" × 11\"), north up, auto engineering scale.\n\n"
        "Examples\n"
        "See dist/plot_examples/ for ten sample PDFs covering these combinations.\n"
        "Regenerate with:  cd mobile/stakedxf && dart run tool/generate_plot_examples.dart"
    )
    page.insert_textbox(fitz.Rect(40, 80, W - 40, H - 50), text, fontsize=11, color=BLACK)

    # Help / troubleshooting
    page = page_start("5. Help & troubleshooting")
    text = (
        "No stakeable entities after convert\n"
        "• Confirm the DWG still contains proxy graphics (ACAD_PROXY_ENTITY).\n"
        "• Civil objects saved without proxies cannot be exploded to linework.\n"
        "• Try converting a DXF that already shows proxies in a CAD viewer.\n\n"
        "Staking plot has no linework\n"
        "• Link a DXF and enable Draw linked DXF linework.\n"
        "• Ensure at least one layer is checked.\n"
        "• Only LINE / LWPOLYLINE / POLYLINE / ARC / CIRCLE are drawn.\n\n"
        "Points missing after import\n"
        "• Use PNEZD order or a headered CSV with Northing/Easting columns.\n"
        "• Blank or malformed rows are skipped.\n\n"
        "App will not install\n"
        "• Must be the TSC5 (Android), not iPhone.\n"
        "• Enable Allow from this source.\n"
        "• MDM may require IT approval.\n\n"
        "Support files\n"
        "• dist/INSTALL_TSC5.md\n"
        "• dist/StakeDXF_UI_Slide_Deck.pdf\n"
        "• docs/USER_GUIDE.md\n"
        "• GitHub PR for StakeDXF TSC5 app"
    )
    page.insert_textbox(fitz.Rect(40, 80, W - 40, H - 50), text, fontsize=11, color=BLACK)

    # Quick reference
    page = page_start("6. Quick reference card")
    text = (
        "Home\n"
        "  Convert DWG → DXF     Recover Civil 3D linework\n"
        "  Export Points         CSV + staking plot PDF\n\n"
        "Convert\n"
        "  Choose drawing → Convert → Save DXF → Trimble Map files\n\n"
        "Export Points\n"
        "  Import CSV → (Link DXF) → Marker/Label options → Select points\n"
        "  → Create staking plot PDF   or   Export CSV\n\n"
        "Good defaults for staking\n"
        "  Marker: Large X\n"
        "  Label: Number + elevation\n"
        "  Point list table: Off\n"
        "  Linework: On (only layers you need)\n\n"
        "Runs on-device. No cloud upload."
    )
    page.insert_textbox(fitz.Rect(40, 80, W - 40, H - 50), text, fontsize=12, color=BLACK)

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

**File:** `dist/Staking Plot vX.Y.Z.apk` (~65 MB)  
**Package:** `com.stakedxf.stakedxf`

1. Copy `Staking Plot vX.Y.Z.apk` onto the TSC5 (USB File Transfer or your usual file share).
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

## 2. Usage — Convert DWG → DXF

Recover Civil 3D linework into a Trimble-stakeable DXF on the controller.

1. Open **StakeDXF → Convert DWG → DXF**
2. **Choose DWG / DXF**
3. **Convert for Trimble Access**
4. Confirm stakeable entity count (and proxy explode count when present)
5. Review **Converted layers** (empty layers omitted) and select which to export
6. **Save DXF** into `Trimble Data/Projects/<job>/`
7. Trimble Access: **Map → Layer manager → Map files → selectable → Stakeout**

### On-device pipeline
1. LibreDWG: DWG → DXF  
2. ezdxf: explode `ACAD_PROXY_ENTITY` / AEC proxies → LINE / ARC / POLYLINE  
3. Keep Trimble-stakeable types only; purge empty layer-table entries  
4. Optional: export a subset of layers from the on-screen checklist  

**Tip:** Office DWGs should keep proxy graphics so Civil features can be recovered.

## 3. Usage — Export Points & staking plots

1. Export points from Trimble Access as CSV/TXT (PNEZD)
2. **StakeDXF → Export Points**
3. **Import points CSV / TXT**
4. (Optional) **Link DXF linework** and select layers
5. Choose **point marker** and **point label** format
6. Leave **Include point list table** off unless you want the coordinate table
7. (Optional) **Add from object library** — place, nudge, scale, rotate, recolor
8. Select points for the sheet
9. **Create staking plot PDF** (auto scale)  
   or **Export selected points CSV**

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
| Point list table | Off by default (more plot space); optional on |
| Linework | Optional linked DXF layers |
| Scale | Auto engineering scale to fit ANSI B landscape sheet |

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
  Convert DWG → DXF     Recover Civil 3D linework
  Export Points         CSV + staking plot PDF

Convert
  Choose drawing → Convert → Save DXF → Trimble Map files

Export Points
  Import CSV → (Link DXF) → Marker/Label → Select points
  → Create staking plot PDF   or   Export CSV

Good staking defaults
  Marker: Large X
  Label: Number + elevation
  Point list table: Off
  Linework: On (only layers you need)
```

Runs on-device. No cloud upload.
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
1. Title — StakeDXF UI & Capabilities
2. Agenda
3. What StakeDXF does
4. Home screen (UI)
5. Convert DWG → DXF (UI + pipeline)
6. Export Points — start
7. Export Points — customize & create
8. Plot customization options
9–10. Staking plot example galleries
11. Install on Trimble TSC5
12. Field workflow end-to-end
13. Docs & help
14. Close
""",
        encoding="utf-8",
    )


def main():
    slides = build_slide_deck()
    tutorial = build_tutorial_pdf()
    write_markdown_guides()
    # also render first pages as preview pngs
    ART.mkdir(parents=True, exist_ok=True)
    for pdf, prefix in ((slides, "slides"), (tutorial, "guide")):
        d = fitz.open(pdf)
        for i in range(min(3, len(d))):
            pix = d[i].get_pixmap(matrix=fitz.Matrix(1.1, 1.1))
            pix.save(str(ART / f"{prefix}_{i+1:02d}.png"))
        d.close()
    print(f"Wrote {slides} ({slides.stat().st_size} bytes)")
    print(f"Wrote {tutorial} ({tutorial.stat().st_size} bytes)")
    print(f"Wrote {OUT_HELP_MD}")
    print(f"Wrote {OUT_SLIDES_MD}")


if __name__ == "__main__":
    main()
