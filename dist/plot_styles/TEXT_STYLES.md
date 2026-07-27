# Civil text styles (Pheasant Farm DWG)

Extracted from `CIVIL_BASE_PHEASANT_FARM_2026-05-22.dwg` STYLE table via LibreDWG DXF dump (`PHEASANT_FARM_trimble_access.raw.libredwg.tmp.dxf`).

SHX/proprietary TTF fonts cannot ship in the app. Each style maps to a Liberation stand-in: **PlotSerif** (Romans/Romand/Sylfaen/Italict), **PlotSans** (Simplex/Arial/LD SHX/Souvenir Bold).

## Primary styles (picker)

| Style | DWG font | Face | Width | Oblique | Bold/Italic | Entities |
|---|---|---|---|---|---|---|
| `ROMAND_SHX` | `romand.shx` | PlotSerif | 0.85 | 0° | — | 292 |
| `OR-LD_SHX` | `or-ld.shx` | PlotSans | 1 | 0° | — | 227 |
| `SHR` | `SIMPLEX` | PlotSans | 1 | 0° | — | 96 |
| `arial` | `arial.ttf` | PlotSans | 1 | 0° | — | 32 |
| `HL-LD` | `hl-ld.shx` | PlotSans | 1 | 0° | — | 17 |
| `ROMANS` | `ROMANS` | PlotSerif | 1 | 0° | — | 6 |
| `SYLFAEN` | `sylfaen.ttf` | PlotSerif | 1 | 0° | — | 1 |
| `ITALICT` | `italict.shx` | PlotSerif | 1 | 0° | italic | 0 |
| `L80` | `SIMPLEX.SHX` | PlotSans | 1 | 0° | — | 0 |
| `P-CONT` | `Souvenir Bold.ttf` | PlotSans | 1 | 0° | bold | 0 |
| `P-TEXT` | `Romans TT.ttf` | PlotSerif | 0.95 | 0° | — | 0 |
| `ROMANS_SHX` | `romans.shx` | PlotSerif | 0.8 | 0° | — | 0 |
| `Standard` | `romans.shx` | PlotSerif | 0.8 | 15° | italic | 0 |
| `TD-LD_SHX` | `td-ld.shx` | PlotSans | 1 | 0° | — | 0 |

## Unique DWG fonts

| Font file | Used by |
|---|---|
| `arial.ttf` | `arial` |
| `hl-ld.shx` | `HL-LD` |
| `italict.shx` | `ITALICT` |
| `or-ld.shx` | `OR-LD_SHX` |
| `romand.shx` | `ROMAND_SHX` |
| `ROMANS` | `ROMANS` |
| `Romans TT.ttf` | `P-TEXT` |
| `romans.shx` | `ROMANS_SHX`, `Standard` |
| `SIMPLEX` | `SHR` |
| `SIMPLEX.SHX` | `L80` |
| `Souvenir Bold.ttf` | `P-CONT` |
| `sylfaen.ttf` | `SYLFAEN` |
| `td-ld.shx` | `TD-LD_SHX` |

## Xref/nested styles (not in picker)

| Style | DWG font | Width | Oblique |
|---|---|---|---|
| `41SITO$0$ROMANS_SHX` | `romans.shx` | 0.8 | 0° |
| `RES_SURVEY$0$Standard` | `romans.shx` | 0.8 | 15° |
| `41SITO$0$Standard` | `romans.shx` | 0.8 | 15° |
| `41SITO$0$ITALICT` | `italict.shx` | 1 | 0° |
| `41SITO$0$Arial` | `arial.ttf` | 1 | 0° |
| `41SITO$0$SHR` | `SIMPLEX` | 1 | 0° |
