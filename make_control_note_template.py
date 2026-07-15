#!/usr/bin/env python3
"""Generate a reusable Control Note template from an existing job sheet.

The source sheet is a CAD-exported PDF whose title reads "CONTROL NOTE" with a
job name beneath it (e.g. "WILDFLOWER"). The job name is stored as vector
outlines, not selectable text, so it is removed here with a precise redaction
over its bounding box. Everything else on the sheet is preserved exactly.

Usage:
    python3 make_control_note_template.py SOURCE.pdf OUTPUT.pdf
"""

import sys

import fitz  # PyMuPDF

# Bounding box (in PDF points) of the job name that sits directly below the
# "CONTROL NOTE" title on the source sheet. Measured from the rendered sheet;
# padded slightly so the whole word is covered without touching "NOTE" above it.
JOB_NAME_RECT = fitz.Rect(1030, 115, 1133, 136)


def build_template(source_path: str, output_path: str) -> None:
    doc = fitz.open(source_path)
    page = doc[0]

    # Redact (truly remove) the job-name vector outlines and fill with white so
    # nothing job-specific remains in the title block of the template.
    page.add_redact_annot(JOB_NAME_RECT, fill=(1, 1, 1))
    page.apply_redactions(
        images=fitz.PDF_REDACT_IMAGE_NONE,
        graphics=fitz.PDF_REDACT_LINE_ART_REMOVE_IF_COVERED,
    )

    doc.save(output_path, garbage=4, deflate=True)
    doc.close()


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    build_template(sys.argv[1], sys.argv[2])
    print(f"Wrote template: {sys.argv[2]}")


if __name__ == "__main__":
    main()
