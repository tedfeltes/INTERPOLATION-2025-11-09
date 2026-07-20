#!/usr/bin/env python3
"""Build / customise a TRIO "Control Note" sheet.

The source sheet is a CAD-exported PDF. Its title reads "CONTROL NOTE" with an
optional job name beneath it, the left panel holds an aerial photo of the site,
and the upper-right holds a "CONTROL POINTS" table. Most on-sheet text (title,
job name, table values, scale, date) is stored as vector outlines rather than
selectable text, so it is cleared with precise redactions and redrawn as real
text using Arial-metric fonts that match the original sheet.

Examples:
    python3 make_control_note_template.py TEMPLATE.pdf OUTPUT.pdf \
        --job-name "ALPINE HILLS" \
        --aerial aerial.pdf --aerial-crop 355.26,0,850.44,552 \
        --points points.csv --styled-labels --date 07/15/26 --scale-500
"""

import argparse
import csv

import fitz  # PyMuPDF

# ---------------------------------------------------------------------------
# Geometry measured from the source sheet (all values in PDF points).
# ---------------------------------------------------------------------------

# Job name below the "CONTROL NOTE" title.
JOB_NAME_RECT = fitz.Rect(1030, 115, 1133, 136)
TITLE_CENTER_X = 1083.6
JOB_NAME_BASELINE_Y = 131.8
JOB_NAME_CAP_HEIGHT = 11.5

# Aerial photo: fills the whole left panel.
AERIAL_RECT = fitz.Rect(62.88, 65.28, 681.60, 755.0)
AERIAL_CLEAR_RECT = fitz.Rect(36.5, 63.0, 682.0, 755.5)
# Crop taken from the aerial source (its own coordinate space).
DEFAULT_AERIAL_CROP = (355.26, 0, 850.44, 552)
# Bounding boxes (aerial-source pixels) of the baked-in labels to inpaint away.
AERIAL_LABEL_BOXES = [
    (434, 52, 569, 151),
    (371, 164, 490, 260),
    (720, 134, 833, 225),
    (712, 428, 830, 523),
]

# "CONTROL POINTS" table grid.
TABLE_COLS = [708.7, 751.7, 819.6, 862.1, 917.0, 976.6]
TABLE_TOP = 65.3
TABLE_TITLE_SEP = 86.2
TABLE_HEADER_SEP = 105.4
TABLE_ROW_H = 17.25
TABLE_LINE_W = 1.2
# Lowest the table may reach before it would collide with the NOTE block (~y424).
# Long point lists shrink the row height / font to fit within this bound.
TABLE_MAX_BOTTOM = 416.0
TABLE_CLEAR_RECT = fitz.Rect(707.0, 64.0, 978.0, 228.0)
TABLE_HEADERS = ["Point #", "Description", "Elevation", "Northing", "Easting"]

# Point markers/labels on the aerial (aerial-source coords of each triangle),
# restyled to match the original sheet's red filled triangle + red bold-italic
# text (number / elevation / description).
STYLED_POINTS = [
    # number, elevation, description, aerial triangle centre (x, y)
    ("700", "961.66", "125 HUB", 449.2, 72.85),
    ("701", "958.51", "125 PK", 731.7, 154.35),
    ("702", "964.80", "125 PK", 726.2, 450.9),
    ("703", "970.58", "125 PK", 385.1, 185.65),
]
LABEL_RED = (1, 0, 0)
LABEL_FS = 8.0
LABEL_PITCH = 7.6
TRI_W = 12.0
TRI_H = 11.0

# Date (bottom-right). Only the value between "DATE:" and "PAGE" is replaced.
# The original uses a bold monospace-style face at ~16pt; sized/aligned to match
# the neighbouring "DATE:" / "PAGE" text.
DATE_CLEAR_RECT = fitz.Rect(1019, 738.5, 1101, 754.5)
DATE_X = 1020.0
DATE_BASELINE = 752.9
DATE_FS = 13.5

# Graphic scale + tick labels.
GSCALE_CLEAR_RECT = fitz.Rect(1004, 352.5, 1159, 365.0)
GSCALE_LEFT_X = 1005.67
GSCALE_BASELINE = 363.67
GSCALE_WIDTH = 152.08
GSCALE_TEXT = 'GRAPHIC SCALE: 1"=500\''
TICK_BASELINE = 393.67
TICK_FS = 11.0
TICK_400 = (fitz.Rect(1066, 384, 1099, 395), 1082.0, "500")
TICK_800 = (fitz.Rect(1136, 384, 1167, 395), 1151.0, "1000")

# ---------------------------------------------------------------------------
# Fonts (Liberation = Arial/Times metric-compatible; matches the sheet).
# ---------------------------------------------------------------------------
_LIB = "/usr/share/fonts/truetype/liberation/"
FONT_REG = (_LIB + "LiberationSans-Regular.ttf", "LiberationSans")
FONT_BOLD = (_LIB + "LiberationSans-Bold.ttf", "LiberationSans-Bold")
FONT_BOLDIT = (_LIB + "LiberationSans-BoldItalic.ttf", "LiberationSans-BoldItalic")
FONT_SERIF_BOLD = (_LIB + "LiberationSerif-Bold.ttf", "LiberationSerif-Bold")
FONT_MONO_BOLD = ("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", "DejaVuSansMono-Bold")
_CAP_RATIO = 0.716

TITLE_FONTSIZE = 9.65
TABLE_FONTSIZE = 9.0


def _fit_fontsize(fontfile, text, target_width, ref=100.0):
    font = fitz.Font(fontfile=fontfile)
    w = font.text_length(text, fontsize=ref)
    return target_width * ref / w


def _text_left(page, x, baseline, text, size, font, color=(0, 0, 0)):
    page.insert_text((x, baseline), text, fontfile=font[0], fontname=font[1],
                     fontsize=size, color=color)


def _text_center(page, cx, baseline, text, size, font, color=(0, 0, 0)):
    f = fitz.Font(fontfile=font[0])
    w = f.text_length(text, fontsize=size)
    _text_left(page, cx - w / 2.0, baseline, text, size, font, color)


# ---------------------------------------------------------------------------
# Individual edits.
# ---------------------------------------------------------------------------

def set_job_name(page, job_name):
    text = job_name.upper()
    size = JOB_NAME_CAP_HEIGHT / _CAP_RATIO
    f = fitz.Font(fontfile=FONT_BOLD[0])
    w = f.text_length(text, fontsize=size)
    page.insert_text((TITLE_CENTER_X - w / 2.0, JOB_NAME_BASELINE_Y), text,
                     fontfile=FONT_BOLD[0], fontname=FONT_BOLD[1], fontsize=size,
                     color=(0, 0, 0), fill=(0, 0, 0))


def _aerial_png(aerial_pdf, crop, out_png, inpaint=True):
    """Extract the aerial's satellite raster, optionally inpaint out its
    baked-in point labels, crop to *crop*, and write a PNG for placement.

    When ``inpaint`` is False the raster (including its own baked-in labels) is
    kept as-is -- used for aerials whose labels are already styled and whose
    vector metadata is too unreliable to redraw."""
    import cv2
    import numpy as np

    doc = fitz.open(aerial_pdf)
    base = doc.extract_image(doc[0].get_images()[0][0])
    doc.close()
    img = cv2.imdecode(np.frombuffer(base["image"], np.uint8), cv2.IMREAD_COLOR)
    if inpaint:
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        mask = np.zeros(img.shape[:2], np.uint8)
        for x0, y0, x1, y1 in AERIAL_LABEL_BOXES:
            sub = gray[y0:y1, x0:x1]
            mask[y0:y1, x0:x1] = (sub < 120).astype(np.uint8) * 255
        mask = cv2.dilate(mask, np.ones((3, 3), np.uint8), iterations=2)
        img = cv2.inpaint(img, mask, 6, cv2.INPAINT_TELEA)
    x0, y0, x1, y1 = (int(round(v)) for v in crop)
    cv2.imwrite(out_png, img[y0:y1, x0:x1])


def _aerial_pixmap(aerial_path, crop):
    panel_ratio = AERIAL_RECT.width / AERIAL_RECT.height
    doc = fitz.open(aerial_path)
    if doc.is_pdf:
        page = doc[0]
        if crop is None:
            src = page.rect
            cw = src.height * panel_ratio
            cx = (src.x0 + src.x1) / 2.0
            crop = fitz.Rect(cx - cw / 2.0, src.y0, cx + cw / 2.0, src.y1)
        pix = page.get_pixmap(matrix=fitz.Matrix(5, 5), clip=fitz.Rect(*crop))
        doc.close()
        return pix
    doc.close()
    return fitz.Pixmap(aerial_path)


def _aerial_mapper(crop):
    x0, y0, x1, y1 = crop
    sx = AERIAL_RECT.width / (x1 - x0)
    sy = AERIAL_RECT.height / (y1 - y0)

    def m(ax, ay):
        return (AERIAL_RECT.x0 + (ax - x0) * sx, AERIAL_RECT.y0 + (ay - y0) * sy)
    return m


def draw_styled_labels(page, crop):
    """Draw red filled triangles + red bold-italic labels at each point,
    matching the original sheet's marker/label design."""
    m = _aerial_mapper(crop)
    cap = _CAP_RATIO * LABEL_FS
    for number, elev, desc, ax, ay in STYLED_POINTS:
        px, py = m(ax, ay)
        # Red filled upward triangle centred on the point.
        apex = (px, py - TRI_H * 2 / 3)
        bl = (px - TRI_W / 2, py + TRI_H / 3)
        br = (px + TRI_W / 2, py + TRI_H / 3)
        shape = page.new_shape()
        shape.draw_polyline([apex, bl, br])
        shape.finish(color=LABEL_RED, fill=LABEL_RED, closePath=True, width=0.4)
        shape.commit()
        # Three text lines to the right, vertically centred on the triangle.
        tx = px + TRI_W / 2 + 2.5
        mid = py + cap / 2
        for i, line in enumerate((number, elev, desc)):
            _text_left(page, tx, mid + (i - 1) * LABEL_PITCH, line, LABEL_FS,
                       FONT_BOLDIT, color=LABEL_RED)


def _table_layout(n):
    """Row height, font size and bottom edge for *n* data rows, shrinking to
    stay within TABLE_MAX_BOTTOM for long point lists."""
    if n <= 0:
        return TABLE_ROW_H, TABLE_FONTSIZE, TABLE_HEADER_SEP
    avail = TABLE_MAX_BOTTOM - TABLE_HEADER_SEP
    row_h = min(TABLE_ROW_H, avail / n)
    fs = min(TABLE_FONTSIZE, row_h * 0.8)
    return row_h, fs, TABLE_HEADER_SEP + row_h * n


def draw_point_table(page, rows):
    n = len(rows)
    row_h, fs, bottom = _table_layout(n)
    x0, x1 = TABLE_COLS[0], TABLE_COLS[-1]
    row_lines = [TABLE_HEADER_SEP + row_h * i for i in range(n + 1)]
    for y in [TABLE_TOP, TABLE_TITLE_SEP] + row_lines:
        page.draw_line((x0, y), (x1, y), width=TABLE_LINE_W, color=(0, 0, 0))
    page.draw_line((x0, TABLE_TOP), (x0, bottom), width=TABLE_LINE_W, color=(0, 0, 0))
    page.draw_line((x1, TABLE_TOP), (x1, bottom), width=TABLE_LINE_W, color=(0, 0, 0))
    for x in TABLE_COLS[1:-1]:
        page.draw_line((x, TABLE_TITLE_SEP), (x, bottom), width=TABLE_LINE_W, color=(0, 0, 0))

    cap = _CAP_RATIO * fs
    centers = [(TABLE_COLS[i] + TABLE_COLS[i + 1]) / 2.0 for i in range(5)]
    _text_center(page, (x0 + x1) / 2.0, 79.25, "CONTROL POINTS", TITLE_FONTSIZE, FONT_REG)
    h_baseline = TABLE_TITLE_SEP + (TABLE_HEADER_SEP - TABLE_TITLE_SEP + cap) / 2.0
    for cx, text in zip(centers, TABLE_HEADERS):
        _text_center(page, cx, h_baseline, text, TABLE_FONTSIZE, FONT_REG)
    for i, row in enumerate(rows):
        baseline = row_lines[i] + (row_h + cap) / 2.0
        for cx, value in zip(centers, row):
            _text_center(page, cx, baseline, value, fs, FONT_REG)


def draw_date(page, date_str):
    _text_left(page, DATE_X, DATE_BASELINE, date_str, DATE_FS, FONT_MONO_BOLD)


def draw_scale(page):
    size = _fit_fontsize(FONT_SERIF_BOLD[0], GSCALE_TEXT, GSCALE_WIDTH)
    _text_left(page, GSCALE_LEFT_X, GSCALE_BASELINE, GSCALE_TEXT, size, FONT_SERIF_BOLD)
    for _rect, cx, label in (TICK_400, TICK_800):
        _text_center(page, cx, TICK_BASELINE, label, TICK_FS, FONT_BOLD)


def parse_points_csv(path):
    rows = []
    with open(path, newline="") as fh:
        for rec in csv.reader(fh):
            rec = [c.strip() for c in rec if c.strip() != ""]
            if len(rec) < 5:
                continue
            pt, northing, easting, elev, desc = rec[0], rec[1], rec[2], rec[3], " ".join(rec[4:])
            rows.append([pt, desc.upper(), f"{float(elev):.2f}",
                         f"{float(northing):.3f}", f"{float(easting):.3f}"])
    # Sort by point number (numeric first, ascending), non-numeric ids last.
    rows.sort(key=lambda r: (0, int(r[0]), "") if r[0].isdigit() else (1, 0, r[0]))
    return rows


def build(source, output, job_name=None, aerial=None, aerial_crop=None,
          points=None, styled_labels=False, date=None, scale_500=False,
          inpaint_aerial=True, aerial_fit=False):
    doc = fitz.open(source)
    page = doc[0]
    crop = aerial_crop or DEFAULT_AERIAL_CROP

    # Collect redactions.
    page.add_redact_annot(JOB_NAME_RECT, fill=(1, 1, 1))
    if aerial:
        page.add_redact_annot(AERIAL_CLEAR_RECT, fill=(1, 1, 1))
    if points is not None:
        _, _, tbottom = _table_layout(len(points))
        page.add_redact_annot(fitz.Rect(TABLE_CLEAR_RECT.x0, TABLE_CLEAR_RECT.y0,
                                        TABLE_CLEAR_RECT.x1, max(TABLE_CLEAR_RECT.y1, tbottom + 4)),
                              fill=(1, 1, 1))
    if date:
        page.add_redact_annot(DATE_CLEAR_RECT, fill=(1, 1, 1))
    if scale_500:
        page.add_redact_annot(GSCALE_CLEAR_RECT, fill=(1, 1, 1))
        page.add_redact_annot(TICK_400[0], fill=(1, 1, 1))
        page.add_redact_annot(TICK_800[0], fill=(1, 1, 1))
    page.apply_redactions(images=fitz.PDF_REDACT_IMAGE_REMOVE,
                          graphics=fitz.PDF_REDACT_LINE_ART_REMOVE_IF_COVERED)

    # Draw new content on top.
    if aerial:
        png = "/tmp/_aerial.png"
        _aerial_png(aerial, crop, png, inpaint=inpaint_aerial)
        page.insert_image(AERIAL_RECT, filename=png, keep_proportion=aerial_fit)
    if styled_labels:
        draw_styled_labels(page, crop)
    if points is not None:
        draw_point_table(page, points)
    if job_name:
        set_job_name(page, job_name)
    if date:
        draw_date(page, date)
    if scale_500:
        draw_scale(page)

    doc.save(output, garbage=4, deflate=True)
    doc.close()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("source")
    p.add_argument("output")
    p.add_argument("--job-name", default=None)
    p.add_argument("--aerial", default=None)
    p.add_argument("--aerial-crop", default=None)
    p.add_argument("--points", default=None)
    p.add_argument("--styled-labels", action="store_true")
    p.add_argument("--no-inpaint", action="store_true",
                   help="Keep the aerial's own baked-in labels (do not inpaint).")
    p.add_argument("--aerial-fit", action="store_true",
                   help="Fit the aerial inside the panel preserving aspect (letterbox).")
    p.add_argument("--date", default=None)
    p.add_argument("--scale-500", action="store_true")
    a = p.parse_args()

    crop = tuple(float(v) for v in a.aerial_crop.split(",")) if a.aerial_crop else None
    rows = parse_points_csv(a.points) if a.points else None
    build(a.source, a.output, job_name=a.job_name, aerial=a.aerial, aerial_crop=crop,
          points=rows, styled_labels=a.styled_labels, date=a.date, scale_500=a.scale_500,
          inpaint_aerial=not a.no_inpaint, aerial_fit=a.aerial_fit)
    print(f"Wrote: {a.output}")


if __name__ == "__main__":
    main()
