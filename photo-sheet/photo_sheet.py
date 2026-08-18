#!/usr/bin/env python3
"""Compose a print-ready 8.5x11 photo sheet from a set of images.

Usage:
    python photo_sheet.py photo1.jpg photo2.jpg ... [options]
    python photo_sheet.py /path/to/folder [options]

Examples:
    # 9 photos, auto 3x3 grid, saved as PDF at 300 DPI
    python photo_sheet.py *.jpg -o sheet.pdf

    # Explicit grid + landscape
    python photo_sheet.py photos/ -c 3 -r 3 --landscape

    # No cropping (letterbox photos to fit their cell)
    python photo_sheet.py photos/ --fit contain
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps
except ImportError:
    sys.stderr.write(
        "Pillow is required. Install it with: pip install pillow\n"
    )
    sys.exit(1)


IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".tif", ".tiff", ".heic"}


def collect_images(paths: list[str]) -> list[Path]:
    out: list[Path] = []
    for p in paths:
        path = Path(p)
        if path.is_dir():
            files = sorted(
                (f for f in path.iterdir() if f.suffix.lower() in IMAGE_EXTS),
                key=lambda f: f.name.lower(),
            )
            out.extend(files)
        elif path.is_file():
            out.append(path)
        else:
            sys.stderr.write(f"warning: skipping missing path: {p}\n")
    return out


def auto_grid(n: int, page_w_in: float, page_h_in: float) -> tuple[int, int]:
    """Pick columns × rows that best fit n photos with roughly square cells."""
    if n <= 0:
        return (1, 1)
    best = (3, 3)
    best_score = math.inf
    for c in range(1, 7):
        for r in range(1, 7):
            if c * r < n:
                continue
            cell_w = page_w_in / c
            cell_h = page_h_in / r
            aspect_penalty = abs(math.log(cell_w / cell_h))
            waste = c * r - n
            score = aspect_penalty * 2 + waste * 0.2
            if score < best_score:
                best_score = score
                best = (c, r)
    return best


def fit_image(img: Image.Image, box_w_px: int, box_h_px: int, mode: str) -> Image.Image:
    """Return an RGB image sized exactly (box_w_px, box_h_px) using the requested fit mode."""
    img = ImageOps.exif_transpose(img)
    if img.mode != "RGB":
        img = img.convert("RGB")

    if mode == "cover":
        # ImageOps.fit crops centrally to fill the box exactly.
        return ImageOps.fit(img, (box_w_px, box_h_px), method=Image.LANCZOS)

    # contain: preserve entire image with white letterbox.
    src_w, src_h = img.size
    scale = min(box_w_px / src_w, box_h_px / src_h)
    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    resized = img.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGB", (box_w_px, box_h_px), (255, 255, 255))
    canvas.paste(resized, ((box_w_px - new_w) // 2, (box_h_px - new_h) // 2))
    return canvas


def compose(
    images: list[Path],
    output: Path,
    cols: int | None,
    rows: int | None,
    margin_in: float,
    gap_in: float,
    dpi: int,
    landscape: bool,
    fit: str,
    repeat_to_fill: bool,
    cut_guides: bool,
) -> None:
    if not images:
        raise SystemExit("No input images.")

    page_w_in = 11.0 if landscape else 8.5
    page_h_in = 8.5 if landscape else 11.0

    if cols is None or rows is None:
        c_auto, r_auto = auto_grid(len(images), page_w_in, page_h_in)
        cols = cols or c_auto
        rows = rows or r_auto

    total_cells = cols * rows
    picks = list(images)
    if repeat_to_fill and picks:
        while len(picks) < total_cells:
            picks.append(picks[len(picks) % len(images)])
    picks = picks[:total_cells]

    page_w_px = int(round(page_w_in * dpi))
    page_h_px = int(round(page_h_in * dpi))
    margin_px = int(round(margin_in * dpi))
    gap_px = int(round(gap_in * dpi))

    inner_w = page_w_px - 2 * margin_px - gap_px * (cols - 1)
    inner_h = page_h_px - 2 * margin_px - gap_px * (rows - 1)
    if inner_w <= 0 or inner_h <= 0:
        raise SystemExit(
            "Margins and gaps leave no room for photos. Reduce margin/gap or use a bigger page."
        )
    cell_w = inner_w // cols
    cell_h = inner_h // rows

    canvas = Image.new("RGB", (page_w_px, page_h_px), (255, 255, 255))

    for i, pth in enumerate(picks):
        col = i % cols
        row = i // cols
        x = margin_px + col * (cell_w + gap_px)
        y = margin_px + row * (cell_h + gap_px)
        try:
            with Image.open(pth) as im:
                tile = fit_image(im, cell_w, cell_h, fit)
        except Exception as e:  # noqa: BLE001
            sys.stderr.write(f"warning: failed to load {pth}: {e}\n")
            continue
        canvas.paste(tile, (x, y))

    if cut_guides:
        # Draw thin cut guides between tiles (extends to the paper edge for scissor-friendly lines).
        from PIL import ImageDraw

        draw = ImageDraw.Draw(canvas)
        color = (200, 200, 200)
        # Vertical guides
        for c in range(1, cols):
            x = margin_px + c * cell_w + (c - 1) * gap_px + gap_px // 2
            draw.line([(x, 0), (x, page_h_px)], fill=color, width=1)
        # Horizontal guides
        for r in range(1, rows):
            y = margin_px + r * cell_h + (r - 1) * gap_px + gap_px // 2
            draw.line([(0, y), (page_w_px, y)], fill=color, width=1)

    output.parent.mkdir(parents=True, exist_ok=True)
    ext = output.suffix.lower()
    if ext == ".pdf":
        canvas.save(output, "PDF", resolution=float(dpi))
    elif ext in {".jpg", ".jpeg"}:
        canvas.save(output, "JPEG", quality=95, dpi=(dpi, dpi))
    else:
        canvas.save(output, dpi=(dpi, dpi))

    print(
        f"Wrote {output} — {page_w_in}x{page_h_in} in, {cols}x{rows} grid, "
        f"{len(picks)} photo{'s' if len(picks) != 1 else ''}, {dpi} DPI, fit={fit}."
    )


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("inputs", nargs="+", help="Image files, globs, and/or directories")
    p.add_argument("-o", "--output", default="photo_sheet.pdf", help="Output file (.pdf, .png, .jpg)")
    p.add_argument("-c", "--cols", type=int, default=None, help="Columns (default: auto)")
    p.add_argument("-r", "--rows", type=int, default=None, help="Rows (default: auto)")
    p.add_argument("--margin", type=float, default=0.25, help="Page margin, inches (default 0.25)")
    p.add_argument("--gap", type=float, default=0.1, help="Gap between photos, inches (default 0.1)")
    p.add_argument("--dpi", type=int, default=300, help="Print resolution (default 300)")
    p.add_argument("--landscape", action="store_true", help="Use 11x8.5 (landscape) instead of 8.5x11")
    p.add_argument(
        "--fit",
        choices=("cover", "contain"),
        default="cover",
        help="cover fills each cell (may crop). contain letterboxes (no crop). Default: cover.",
    )
    p.add_argument(
        "--repeat",
        action="store_true",
        help="Repeat photos in order until every cell is filled.",
    )
    p.add_argument(
        "--cut-guides",
        action="store_true",
        help="Draw faint cut guides between photos.",
    )
    return p


def main(argv: list[str] | None = None) -> None:
    args = build_parser().parse_args(argv)
    images = collect_images(args.inputs)
    if not images:
        raise SystemExit("No images found in the supplied paths.")
    compose(
        images=images,
        output=Path(args.output),
        cols=args.cols,
        rows=args.rows,
        margin_in=args.margin,
        gap_in=args.gap,
        dpi=args.dpi,
        landscape=args.landscape,
        fit=args.fit,
        repeat_to_fill=args.repeat,
        cut_guides=args.cut_guides,
    )


if __name__ == "__main__":
    main()
