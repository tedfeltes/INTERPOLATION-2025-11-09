# Staking plot templates (ANSI A–D)

Templates available in **Export Points → Plot options → Plot template**, derived from
commonalities in the field staking plot PDF set:

[Google Drive folder `1jmfZLTcZxhoksZeUCR0Jxq_cR9CgNp-S`](https://drive.google.com/drive/folders/1jmfZLTcZxhoksZeUCR0Jxq_cR9CgNp-S)
(31 sample plots analyzed).

## What the field plots share

| Observation | Count (of 31) | Implication |
| --- | ---: | --- |
| ANSI **B** (11×17) | 21 | Primary field size |
| ANSI **A** (8.5×11) | 5 | Small lot / letter sheets |
| ANSI **D** (22×34) | 4 | Long curb / site-wide |
| Arch D (24×36) | 1 | Mapped to ANSI D templates |
| Portrait | 21 | Especially common on B |
| Landscape | 10 | D sheets + some B/A |
| Full-bleed plan (no formal title block) | ~all | “Field map” layouts |
| Corner north arrow + `SCALE: 1" = …' (W"×H")` | ~all | Legend strip |
| Red X / multi-line labels on grey linework | ~all | Existing plot styling |
| Optional title + date clustered with north/scale | several | “Titled field” layout |

No ANSI **C** sheets appeared in the sample set; C templates are included so users
can step between B and D.

## Layout families

1. **Field map** — Plan fills the sheet; north arrow, graphic scale, scale text with
   sheet-size callout, job name, and date sit in a corner strip (bottom-right or
   bottom-left). Matches curb / utility / wetland / lot-line plots.
2. **Titled field map** — Same full-bleed plan with title, subtitle, date, north, and
   scale grouped (e.g. Cardinal Ridge test-pit style).
3. **Control note** — Bordered StakeDXF / TRIO sheet: plan left, side panel with
   title, optional CONTROL POINTS table, note, firm block, date.

## Selectable templates

| ID | Name | Size | Orient | Layout |
| --- | --- | --- | --- | --- |
| `field_a_portrait` | Field map — A portrait | A 8.5×11 | Portrait | Field map |
| `field_a_landscape` | Field map — A landscape | A 11×8.5 | Landscape | Field map |
| `field_b_portrait` | Field map — B portrait | B 11×17 | Portrait | Field map |
| `field_b_landscape` | Field map — B landscape | B 17×11 | Landscape | Field map |
| `field_c_landscape` | Field map — C landscape | C 22×17 | Landscape | Field map |
| `field_c_portrait` | Field map — C portrait | C 17×22 | Portrait | Field map |
| `field_d_landscape` | Field map — D landscape | D 34×22 | Landscape | Field map |
| `field_d_portrait` | Field map — D portrait | D 22×34 | Portrait | Field map |
| `header_b_landscape` | Titled field — B landscape | B 17×11 | Landscape | Titled field |
| `header_b_portrait` | Titled field — B portrait | B 11×17 | Portrait | Titled field |
| `header_d_landscape` | Titled field — D landscape | D 34×22 | Landscape | Titled field |
| `control_a_portrait` | Control note — A portrait | A 8.5×11 | Portrait | Control note |
| `control_b_landscape` | Control note — B landscape | B 17×11 | Landscape | Control note |
| `control_c_landscape` | Control note — C landscape | C 22×17 | Landscape | Control note |
| `control_d_landscape` | Control note — D landscape | D 34×22 | Landscape | Control note |

Default: **Control note — B landscape** (historical StakeDXF sheet).

## Regenerating example PDFs

```bash
cd mobile/stakedxf
dart run tool/generate_template_examples.dart
```

Outputs land in `dist/plot_templates/examples/`.
