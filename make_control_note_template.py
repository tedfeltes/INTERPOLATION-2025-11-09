#!/usr/bin/env python3
"""Build / customise a TRIO "Control Note" sheet.

The source sheet is a CAD-exported PDF. Its title reads "CONTROL NOTE" with an
optional job name beneath it (e.g. "WILDFLOWER"), and the left panel holds an
aerial photo of the site. The title/job name are stored as vector outlines
(not selectable text), so the job name is cleared with a precise redaction over
its bounding box and a new one is drawn as real text styled to match.

Examples:
    # Blank template (remove the job name entirely)
    python3 make_control_note_template.py SOURCE.pdf OUTPUT.pdf

    # Set a job name and swap the aerial
    python3 make_control_note_template.py TEMPLATE.pdf OUTPUT.pdf \
        --job-name "ALPINE HILLS" --aerial new_aerial.jpg
"""

import argparse

import fitz  # PyMuPDF

# --- Geometry measured from the source sheet (all values in PDF points) -------

# Bounding box of the job name that sits directly below the "CONTROL NOTE"
# title. Padded slightly so the whole word is cleared without touching "NOTE".
JOB_NAME_RECT = fitz.Rect(1030, 115, 1133, 136)

# Horizontal centre of the "CONTROL NOTE" title and the baseline / cap height of
# the original job name, so a replacement lines up exactly like the original.
TITLE_CENTER_X = 1083.6
JOB_NAME_BASELINE_Y = 131.8
JOB_NAME_CAP_HEIGHT = 11.5

# Placement rectangle of the aerial photo in the left panel.
AERIAL_RECT = fitz.Rect(62.88, 65.28, 681.60, 641.04)

# Arial-metric bold face used to imitate the sheet's Arial Black title font.
JOB_NAME_FONTFILE = "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"
JOB_NAME_FONTNAME = "LiberationSans-Bold"
# LiberationSans cap height is ~0.716 em; solve for the matching font size.
_CAP_RATIO = 0.716


def clear_job_name(page: fitz.Page) -> None:
    """Redact (truly remove) any existing job-name outlines below the title."""
    page.add_redact_annot(JOB_NAME_RECT, fill=(1, 1, 1))
    page.apply_redactions(
        images=fitz.PDF_REDACT_IMAGE_NONE,
        graphics=fitz.PDF_REDACT_LINE_ART_REMOVE_IF_COVERED,
    )


def set_job_name(page: fitz.Page, job_name: str) -> None:
    """Draw the job name centred under the title, styled like the original."""
    text = job_name.upper()
    font = fitz.Font(fontfile=JOB_NAME_FONTFILE)
    fontsize = JOB_NAME_CAP_HEIGHT / _CAP_RATIO
    width = font.text_length(text, fontsize=fontsize)
    x = TITLE_CENTER_X - width / 2.0
    page.insert_text(
        (x, JOB_NAME_BASELINE_Y),
        text,
        fontfile=JOB_NAME_FONTFILE,
        fontname=JOB_NAME_FONTNAME,
        fontsize=fontsize,
        color=(0, 0, 0),
        fill=(0, 0, 0),
    )


def replace_aerial(page: fitz.Page, aerial_path: str) -> None:
    """Cover the left panel with a new aerial photo.

    The image is drawn on top of the existing content stream, so it hides the
    old satellite raster together with any control-point markers/labels that
    were overlaid on it (the replacement aerial carries its own markers).
    """
    page.insert_image(AERIAL_RECT, filename=aerial_path, keep_proportion=False)


def build(source, output, job_name=None, aerial=None):
    doc = fitz.open(source)
    page = doc[0]

    clear_job_name(page)
    if job_name:
        set_job_name(page, job_name)
    if aerial:
        replace_aerial(page, aerial)

    doc.save(output, garbage=4, deflate=True)
    doc.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", help="source Control Note PDF")
    parser.add_argument("output", help="output PDF path")
    parser.add_argument("--job-name", default=None, help="job name to place under the title (blank if omitted)")
    parser.add_argument("--aerial", default=None, help="path to a replacement aerial image")
    args = parser.parse_args()

    build(args.source, args.output, job_name=args.job_name, aerial=args.aerial)
    print(f"Wrote: {args.output}")


if __name__ == "__main__":
    main()
