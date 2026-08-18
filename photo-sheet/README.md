# Photo Sheet

Fill an 8.5×11 sheet with photos, print it, cut them apart.

Two ways to use it.

## 1. Browser (no install)

Open `index.html` in Chrome, Safari, Firefox, or Edge (double-click it, or drag it into a browser tab). Everything runs on-device — photos never leave the browser.

1. Drag your photos onto the drop zone (or click to pick).
2. The 8.5×11 preview fills in as you go.
3. Tweak columns, rows, margin, gap, orientation, and fit as needed.
4. Click **Print / Save PDF**.
5. In the print dialog, pick your printer — or "Save as PDF" — and set the destination to Letter (8.5×11), margins **None**, scale **100%**. The `@page { size: letter; margin: 0 }` rule already asks the browser for the right paper.

Defaults are chosen for 9 photos: 3×3 grid, 0.25 in page margin, 0.1 in gap between photos, portrait orientation, cover fit (photos fill each cell, may crop). Uncheck **Show cut guides on screen** if you don't want to see the dashed borders in the preview — they don't print either way.

Tip: **Auto grid** picks the best columns × rows for however many photos you loaded. **Repeat to fill** duplicates the photos in order so a leftover 10th cell in a 3×4 grid isn't blank.

## 2. Python CLI

For scripted workflows, batch runs, or when you want a real PDF file straight from a folder of photos.

```bash
pip install pillow

# 9 photos, auto 3x3, 300 DPI PDF
python photo_sheet.py /path/to/photos -o sheet.pdf

# Explicit grid, landscape, no cropping
python photo_sheet.py photo1.jpg photo2.jpg photo3.jpg photo4.jpg \
  -c 2 -r 2 --landscape --fit contain -o quad.pdf

# Faint cut guides drawn between tiles
python photo_sheet.py photos/ --cut-guides -o sheet.pdf
```

Options:

| flag | default | meaning |
| --- | --- | --- |
| `-o`, `--output` | `photo_sheet.pdf` | `.pdf`, `.png`, or `.jpg` |
| `-c`, `--cols` | auto | grid columns |
| `-r`, `--rows` | auto | grid rows |
| `--margin` | `0.25` | page margin in inches |
| `--gap` | `0.1` | gap between photos in inches |
| `--dpi` | `300` | print resolution |
| `--landscape` | off | use 11×8.5 instead of 8.5×11 |
| `--fit` | `cover` | `cover` (fill, may crop) or `contain` (no crop) |
| `--repeat` | off | duplicate photos to fill leftover cells |
| `--cut-guides` | off | draw thin cut guides between photos |

The Python tool sorts files inside a directory alphabetically — rename them (`01.jpg`, `02.jpg`, …) if you care about photo order.

## Notes on printing

* When Chrome prints an HTML page, "Save as PDF" gives a smaller file than a JPG/PNG export and preserves original photo detail.
* If your printer software adds its own margins, either accept them (photos will still line up, just smaller) or set Chrome's margins to **None** and turn off "Fit to page".
* For scissor-friendly cuts, set gap to `0` and enable cut guides — you'll get a single line to trim along instead of a paper border.
