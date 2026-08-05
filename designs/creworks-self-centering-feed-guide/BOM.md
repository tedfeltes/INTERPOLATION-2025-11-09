# Bill of materials

## 3D-printed parts (PETG or ABS)

| Qty | Part | SCAD `part=` | Notes |
|-----|------|--------------|-------|
| 1 | Mount plate | `plate` | Replaces OEM 5-hole plate; reuse OEM thumbscrews |
| 1 | Left V-jaw | `jaw_left` | Mirror of right; rack faces pinion |
| 1 | Right V-jaw | `jaw_right` | |
| 1 | Sync pinion | `pinion` | Print solid, 100% infill |
| 1 | Lead-in flare cover | `cover` | Optional but recommended |

**Print settings:** 0.2 mm layer, 4+ walls / 1.6 mm shell, 40% gyroid (100% for pinion), ironing off, seams away from V faces. Orient jaws with V face vertical (no supports on the contact face).

Optional upgrade: glue 1 mm UHMW or PTFE tape on the V faces for lower drag and longer life.

## Hardware (hardware store / McMaster)

| Qty | Item | Spec | Role |
|-----|------|------|------|
| 2 | OEM thumbscrews | reuse | Clamp plate to stripper head |
| 1 | Shoulder bolt or dowel | M5 × 25–30 mm (or 5 mm pin + e-clips) | Pinion axle |
| 2 | Extension springs | light, ~0.3–0.6 N/mm, free length ~25–35 mm | Close jaws |
| 4 | M3 × 8 screws + washers | optional | Spring hooks if not using hook-end springs |
| 1 | Drop of machine oil / dry PTFE | — | Rails + pinion |

Spring rule of thumb: you should open the jaws to 20 mm with two fingers. If it fights you, go lighter — drag causes thin wire to slip on the roller.

## Hardware-store alternative (no printer)

If you do not want to print:

1. **Mount:** Cut a steel or aluminum plate to match the OEM plate outline; drill the two thumbscrew holes from the OEM plate as a template; cut a center window.
2. **Jaws:** Two small adjustable V-blocks or 90° angle aluminum, mounted on miniature drawer slides or brass rod linear rails, facing each other.
3. **Sync:** Link the slides with a bicycle-brake-style crossover cable or a short scissor link so they move equally.
4. **Springs:** Same light extension springs between each jaw and the plate outer edge.
5. **Lead-in:** Funnel cut from a plastic bottle neck or sheet metal cone, bolted in front of the window.

Functionally identical; heavier and uglier, same centering behavior.
