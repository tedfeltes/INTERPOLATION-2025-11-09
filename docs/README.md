# StakeDXF documentation

| Document | Description |
| --- | --- |
| [`USER_GUIDE.md`](USER_GUIDE.md) | Install, usage, help (Markdown) |
| [`UI_SLIDE_DECK.md`](UI_SLIDE_DECK.md) | Slide outline |
| [`../dist/StakeDXF_User_Guide.pdf`](../dist/StakeDXF_User_Guide.pdf) | Full user guide PDF |
| [`../dist/StakeDXF_UI_Slide_Deck.pdf`](../dist/StakeDXF_UI_Slide_Deck.pdf) | UI & capabilities slide deck PDF |
| [`../dist/INSTALL_TSC5.md`](../dist/INSTALL_TSC5.md) | Quick TSC5 install card |
| [`../dist/plot_examples/`](../dist/plot_examples/) | Sample staking plot PDFs |

## Regenerate PDFs

```bash
python3 docs/generate_docs.py
```

Requires PyMuPDF (`fitz`) and the plot example PNGs under `/opt/cursor/artifacts/screenshots/plot_examples` (or re-render those from `dist/plot_examples/*.pdf` first).
