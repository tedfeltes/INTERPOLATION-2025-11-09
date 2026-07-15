#!/usr/bin/env python3
"""Build / customise a TRIO "Control Note" sheet.

The source sheet is a CAD-exported PDF. Its title reads "CONTROL NOTE" with an
optional job name beneath it, the left panel holds an aerial photo of the site,
and the upper-right holds a "CONTROL POINTS" table. The title/job name, the
table grid and all of its values are stored as vector outlines (not selectable
text), so they are cleared with precise redactions and redrawn as real text.

Examples:
    # Blank template (remove the job name entirely)
    python3 make_control_note_template.py SOURCE.pdf OUTPUT.pdf

    # Set a job name, swap the aerial (PDF or image), rebuild the point table
    python3 make_control_note_template.py TEMPLATE.pdf OUTPUT.pdf \
        --job-name "ALPINE HILLS" \
        --aerial aerial.pdf --aerial-crop 306.3,0,899.49,552 \
        --points points.csv
"""

import argparse
import csv

import fitz  # PyMuPDF

# --- Geometry measured from the source sheet (all values in PDF points) -------

# Job name that sits directly below the "CONTROL NOTE" title.
JOB_NAME_RECT = fitz.Rect(1030, 115, 1133, 136)
TITLE_CENTER_X = 1083.6
JOB_NAME_BASELINE_Y = 131.8
JOB_NAME_CAP_HEIGHT = 11.5

# Aerial photo placement rectangle: fills the whole left panel, matching the
# original sheet where a satellite raster (top) plus a vector plat (bottom)
# together filled this area.
AERIAL_RECT = fitz.Rect(62.88, 65.28, 681.60, 755.0)
# Larger area to clear first: removes the old raster, the overlaid control-point
# markers/labels, and the site-specific plat drawing below the old photo.
AERIAL_CLEAR_RECT = fitz.Rect(36.5, 63.0, 682.0, 755.5)

# "CONTROL POINTS" table grid.
TABLE_COLS = [708.7, 751.7, 819.6, 862.1, 917.0, 976.6]  # 5 columns
TABLE_TOP = 65.3            # top border
TABLE_TITLE_SEP = 86.2     # below "CONTROL POINTS" title
TABLE_HEADER_SEP = 105.4   # below the column headers
TABLE_ROW_H = 17.25
TABLE_LINE_W = 1.2
TABLE_CLEAR_RECT = fitz.Rect(707.0, 64.0, 978.0, 228.0)
TABLE_HEADERS = ["Point #", "Description", "Elevation", "Northing", "Easting"]

# Fonts: Liberation Sans is metric-compatible with Arial; a bold cut mimics the
# sheet's Arial Black title font.
FONT_REG_FILE = "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
FONT_REG_NAME = "LiberationSans"
FONT_BOLD_FILE = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
FONT_BOLD_NAME = "LiberationSans-Bold"
_CAP_RATIO = 0.716

TITLE_FONTSIZE = 9.65
TABLE_FONTSIZE = 9.0


def _text_center(page, cx, baseline, text, size, fontfile, fontname):
    """Draw horizontally-centred text with its baseline at *baseline*."""
    font = fitz.Font(fontfile=fontfile)
    width = font.text_length(text, fontsize=size)
    page.insert_text(
        (cx - width / 2.0, baseline),
        text,
        fontfile=fontfile,
        fontname=fontname,
        fontsize=size,
        color=(0, 0, 0),
    )


def clear_job_name(page):
    page.add_redact_annot(JOB_NAME_RECT, fill=(1, 1, 1))


def set_job_name(page, job_name):
    text = job_name.upper()
    font = fitz.Font(fontfile=FONT_BOLD_FILE)
    fontsize = JOB_NAME_CAP_HEIGHT / _CAP_RATIO
    width = font.text_length(text, fontsize=fontsize)
    page.insert_text(
        (TITLE_CENTER_X - width / 2.0, JOB_NAME_BASELINE_Y),
        text,
        fontfile=FONT_BOLD_FILE,
        fontname=FONT_BOLD_NAME,
        fontsize=fontsize,
        color=(0, 0, 0),
        fill=(0, 0, 0),
    )


def _aerial_pixmap(aerial_path, crop):
    """Return a pixmap of the aerial cropped to the panel's aspect ratio."""
    panel_ratio = AERIAL_RECT.width / AERIAL_RECT.height
    doc = fitz.open(aerial_path)
    if doc.is_pdf:
        page = doc[0]
        if crop is None:
            src = page.rect
            cw = src.height * panel_ratio
            cx = (src.x0 + src.x1) / 2.0
            crop = fitz.Rect(cx - cw / 2.0, src.y0, cx + cw / 2.0, src.y1)
        pix = page.get_pixmap(matrix=fitz.Matrix(5, 5), clip=crop)
        doc.close()
        return pix
    doc.close()
    # Raster source: centre-crop to the panel ratio.
    pix = fitz.Pixmap(aerial_path)
    if crop is not None:
        pix = fitz.Pixmap(pix, pix.width, pix.height, fitz.Rect(*crop).irect)
    return pix


def replace_aerial(page, aerial_path, crop=None):
    page.add_redact_annot(AERIAL_CLEAR_RECT, fill=(1, 1, 1))
    # Redactions are applied by the caller; the image is drawn afterwards.
    page._pending_aerial = (aerial_path, crop)


def replace_point_table(page, rows):
    page.add_redact_annot(TABLE_CLEAR_RECT, fill=(1, 1, 1))
    page._pending_table = rows


def _draw_table(page, rows):
    n = len(rows)
    x0, x1 = TABLE_COLS[0], TABLE_COLS[-1]
    row_lines = [TABLE_HEADER_SEP + TABLE_ROW_H * i for i in range(n + 1)]
    bottom = row_lines[-1]

    # Horizontal lines.
    for y in [TABLE_TOP, TABLE_TITLE_SEP] + row_lines:
        page.draw_line((x0, y), (x1, y), width=TABLE_LINE_W, color=(0, 0, 0))
    # Vertical lines: outer span the whole table, inner start below the title.
    page.draw_line((x0, TABLE_TOP), (x0, bottom), width=TABLE_LINE_W, color=(0, 0, 0))
    page.draw_line((x1, TABLE_TOP), (x1, bottom), width=TABLE_LINE_W, color=(0, 0, 0))
    for x in TABLE_COLS[1:-1]:
        page.draw_line((x, TABLE_TITLE_SEP), (x, bottom), width=TABLE_LINE_W, color=(0, 0, 0))

    cap = _CAP_RATIO * TABLE_FONTSIZE
    centers = [(TABLE_COLS[i] + TABLE_COLS[i + 1]) / 2.0 for i in range(5)]

    # Title.
    _text_center(
        page, (x0 + x1) / 2.0, 79.25, "CONTROL POINTS",
        TITLE_FONTSIZE, FONT_REG_FILE, FONT_REG_NAME,
    )
    # Column headers.
    h_baseline = TABLE_TITLE_SEP + (TABLE_HEADER_SEP - TABLE_TITLE_SEP + cap) / 2.0
    for cx, text in zip(centers, TABLE_HEADERS):
        _text_center(page, cx, h_baseline, text, TABLE_FONTSIZE, FONT_REG_FILE, FONT_REG_NAME)
    # Data rows.
    for i, row in enumerate(rows):
        baseline = row_lines[i] + (TABLE_ROW_H + cap) / 2.0
        for cx, value in zip(centers, row):
            _text_center(page, cx, baseline, value, TABLE_FONTSIZE, FONT_REG_FILE, FONT_REG_NAME)


def parse_points_csv(path):
    """Parse a control CSV (Point, Northing, Easting, Elevation, Description).

    Returns rows ordered as the table columns:
    [Point #, Description, Elevation, Northing, Easting].
    """
    rows = []
    with open(path, newline="") as fh:
        for rec in csv.reader(fh):
            rec = [c.strip() for c in rec if c.strip() != ""]
            if len(rec) < 5:
                continue
            pt, northing, easting, elev, desc = rec[0], rec[1], rec[2], rec[3], " ".join(rec[4:])
            rows.append([
                pt,
                desc.upper(),
                f"{float(elev):.2f}",
                f"{float(northing):.3f}",
                f"{float(easting):.3f}",
            ])
    return rows


def build(source, output, job_name=None, aerial=None, aerial_crop=None, points=None):
    doc = fitz.open(source)
    page = doc[0]

    clear_job_name(page)
    if aerial:
        replace_aerial(page, aerial, crop=aerial_crop)
    if points:
        replace_point_table(page, points)

    page.apply_redactions(
        images=fitz.PDF_REDACT_IMAGE_REMOVE,
        graphics=fitz.PDF_REDACT_LINE_ART_REMOVE_IF_COVERED,
    )

    if getattr(page, "_pending_aerial", None):
        path, crop = page._pending_aerial
        pix = _aerial_pixmap(path, crop)
        page.insert_image(AERIAL_RECT, pixmap=pix, keep_proportion=False)
    if getattr(page, "_pending_table", None):
        _draw_table(page, page._pending_table)
    if job_name:
        set_job_name(page, job_name)

    doc.save(output, garbage=4, deflate=True)
    doc.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source")
    parser.add_argument("output")
    parser.add_argument("--job-name", default=None)
    parser.add_argument("--aerial", default=None, help="replacement aerial (PDF or image)")
    parser.add_argument("--aerial-crop", default=None, help="x0,y0,x1,y1 crop of the aerial source")
    parser.add_argument("--points", default=None, help="control-points CSV to rebuild the table")
    args = parser.parse_args()

    crop = tuple(float(v) for v in args.aerial_crop.split(",")) if args.aerial_crop else None
    rows = parse_points_csv(args.points) if args.points else None
    build(args.source, args.output, job_name=args.job_name, aerial=args.aerial, aerial_crop=crop, points=rows)
    print(f"Wrote: {args.output}")


if __name__ == "__main__":
    main()
