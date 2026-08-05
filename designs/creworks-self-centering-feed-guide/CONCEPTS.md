# Concept catalog — CREWORKS self-centering feed guide

Machine: CREWORKS 180W-class stripper, OEM 5-hole plate retained or replaced via two thumbscrews.  
Wire range target: Ø1.5–38 mm. Goal: feed without aiming at a hole; keep wire in the driven V-roller.

All concepts mount on the **existing thumbscrew pair**. Dimensions below use provisional envelope:

| Symbol | Description | Prov. value | Verify on machine |
|--------|-------------|-------------|-------------------|
| A | Thumbscrew hole C–C | 140 mm | required |
| B | Screw clearance Ø | 8.5 mm | required |
| C | Roller V centerline height from plate bottom | 55 mm | required |
| D | Plate envelope W × H | 170 × 100 mm | fit check |

---

## Concept A — Fixed funnel / tapered tunnel (zero moving parts)

**Idea:** Replace the 5-hole plate with a single flared tunnel whose exit slot is centered on the roller V. Wire is funneled to center by geometry alone.

| | |
|--|--|
| **Pros** | Simplest; cheapest; nothing to jam; shove-and-go |
| **Cons** | Large wire sits higher in a round funnel; small wire has more float unless exit is a vertical slot / keyhole |
| **Best if** | You mostly strip mid-size cable and want zero maintenance |
| **Parts** | 1 printed/machined body (+ optional UHMW insert) |
| **Drawings** | `A0` assembly, `A1` body detail |

**Key geometry:** Entrance Ø ≥ 55 mm; exit = vertical slot 40 mm tall × 6–8 mm wide (or keyhole) on centerline C; tunnel length 35–50 mm.

---

## Concept B — Fixed deep-V cradle + spring hold-down

**Idea:** Wire drops into a deep 90° V that is permanently aligned with the roller. A light top leaf-spring or hinged pad keeps it from bouncing out; V does the centering.

| | |
|--|--|
| **Pros** | True geometric centering; very robust; easy to print/machine |
| **Cons** | Must lift hold-down for huge wire; V face wear over time |
| **Best if** | You want shop-tool simplicity with real centering accuracy |
| **Parts** | Mount + V-block, hold-down leaf, 1 pivot/shoulder screw, light spring |
| **Drawings** | `B0` assembly, `B1` V-block, `B2` hold-down |

---

## Concept C — Opposed idle side rollers (equal-arm)

**Idea:** Two vertical idle rollers on mirrored swing arms, spring-biased closed, mechanically linked so they open equally. Wire is pinched on centerline with rolling contact (low drag).

| | |
|--|--|
| **Pros** | Lowest feed resistance; excellent for long continuous pulls; self-sizes |
| **Cons** | More parts (bearings, arms, link); needs clearance in front of head |
| **Best if** | You strip long runs and hate friction/stalling on thin wire |
| **Parts** | Mount, 2 arms, 2 rollers + bearings, equalizer link or gear sector, springs |
| **Drawings** | `C0` assembly, `C1` arm, `C2` equalizer |

---

## Concept D — Scissor (X-linkage) centering jaws

**Idea:** Two jaw pads on an X / scissor linkage with a common pivot on the machine centerline. Opening is always symmetric; light spring closes.

| | |
|--|--|
| **Pros** | Classic self-centering kinematics; intuitive; no gear teeth to print |
| **Cons** | Pivot stack height; linkage can rack if sloppy |
| **Best if** | You want moving jaws but hate printed gears |
| **Parts** | Mount, 2 links, 2 jaw pads, center pivot, spring |
| **Drawings** | `D0` assembly, `D1` link + jaw |

---

## Concept E — Three-point iris / scroll chuck style

**Idea:** Three (or four) pads driven by a scroll plate or linked cams so the aperture always grows/shrinks about center — like a lathe chuck or camera iris.

| | |
|--|--|
| **Pros** | Best centering of the set; holds odd jackets well |
| **Cons** | Highest part count / hardest to DIY; overkill for scrap wire |
| **Best if** | You want “set and forget” precision and will machine or buy a scroll |
| **Parts** | Body, scroll or cam plate, 3 jaws, retainer, knob |
| **Drawings** | `E0` assembly schematic, `E1` jaw layout |

---

## Recommendation matrix

| Priority | Pick |
|----------|------|
| Fewest parts / print tonight | **A** (add keyhole exit) |
| Best centering per effort | **B** |
| Lowest drag on long wire | **C** |
| Moving jaws, no gears | **D** |
| Maximum precision (complex) | **E** |

**Default recommendation for this machine:** build **B** first (deep-V + hold-down). If thin wire still slips on the driven roller from drag, switch the contact to **C** (side rollers). Use **A** as a same-day stopgap.
