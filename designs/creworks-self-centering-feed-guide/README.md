# CREWORKS self-centering feed guide — multi-concept design package

Engineering concepts and drawings for a feed guide that keeps wire in the driven V-roller **without** picking a hole in the OEM 5-channel plate or hand-steering mid-strip.

## Start here

1. Read **[`CONCEPTS.md`](CONCEPTS.md)** — five distinct mechanisms + tradeoffs  
2. Open the drawing sheets in **[`drawings/sheets/`](drawings/sheets/)**  
3. Measure your machine per **[`MEASURE.md`](MEASURE.md)** before fabricating  

**Recommended first build:** Concept **B** (deep-V + spring hold-down).  
**If thin wire stalls from drag:** Concept **C** (opposed idle rollers).  
**Same-day zero-moving-parts fix:** Concept **A** (funnel with keyhole exit).

---

## Drawing index

| DWG | File | Description |
|-----|------|-------------|
| WSFG-00 | `WSFG-00_concept_comparison.png` | All five concepts at a glance |
| WSFG-IF | `WSFG-IF_machine_interface.png` + `.dxf` | Mounting interface control (A, B, C) |
| WSFG-A0/A1 | `WSFG-A0_…` `WSFG-A1_…` | Concept A — fixed funnel |
| WSFG-B0/B1/B2 | `WSFG-B0_…` `WSFG-B1_…` `WSFG-B2_…` | Concept B — deep-V + hold-down |
| WSFG-C0/C1 | `WSFG-C0_…` `WSFG-C1_…` | Concept C — side idle rollers |
| WSFG-D0/D1 | `WSFG-D0_…` `WSFG-D1_…` | Concept D — scissor jaws |
| WSFG-E0 | `WSFG-E0_…` | Concept E — three-jaw iris (stretch) |

PNG sheets are A3 landscape shop-style layouts (border, title block, orthographic / section views, dimensions, notes).  
DXF files are fab patterns / interface geometry for CAD, laser, or CNC.

### Regenerate drawings

```bash
python3 -m venv .venv && .venv/bin/pip install matplotlib ezdxf
cd drawings
../.venv/bin/python generate_engineering_drawings.py
../.venv/bin/python generate_dxf_engineering.py
```

Edit provisional `A`, `B`, `C` at the top of both generators after measuring.

---

## Concepts (summary)

| ID | Name | Moving parts | Centering | Drag | Complexity |
|----|------|--------------|-----------|------|------------|
| **A** | Fixed funnel / keyhole tunnel | None | Good | Low | Lowest |
| **B** | Deep-V cradle + spring hold-down | Hold-down only | Excellent | Low–med | Low |
| **C** | Opposed idle side rollers | Arms + rollers | Excellent | Lowest | Medium |
| **D** | Scissor (X-link) jaws | Linkage | Excellent | Med | Medium |
| **E** | Three-jaw iris / scroll | Scroll + jaws | Best | Med | Highest |

---

## Legacy note

An earlier single-concept rack-and-pinion jaw SCAD experiment remains under `scad/` for reference only. Prefer the multi-concept sheets above.
