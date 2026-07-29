# StakeDXF UI Markup Catalog

PDF: [`dist/StakeDXF_UI_Markup_Catalog.pdf`](../dist/StakeDXF_UI_Markup_Catalog.pdf)

Regenerate:

```bash
python3 docs/generate_ui_markup_catalog.py
```

## How to reply (copy/paste)

```
REMOVE  HOME.STATUS.*
REMOVE  HOME.RIBBON.ONLINE, HOME.RIBBON.LOCAL
REMOVE  PLOT.OPTS.POINTLIST
CHANGE  PLOT.LPM → open as full-screen on TSC5
MUST REMOVE  PLOT.OPTS.ANNOT.HINT, PLOT.LPM.FOOTER.HINT
```

Use the stable IDs from the PDF. Orange-tinted rows are suggested clutter/chrome.
