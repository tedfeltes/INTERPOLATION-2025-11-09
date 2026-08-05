# CREWORKS Self-Centering Feed Guide

Drop-in replacement for the black 5-hole feed plate on a CREWORKS 180W (and similar) electric wire stripper.

**Problem:** Wire must be aimed into a specific hole / the roller V, and still walks sideways off the roller so it is not stripped.

**Solution:** A spring-loaded dual V-jaw guide that always squeezes the wire onto the blade/roller centerline. Push the wire roughly into the flared mouth — the jaws open to the wire diameter and stay centered for the full 1.5–38 mm range.

```
                    OEM thumbscrews
                   ○───────────────○
        ┌──────────────────────────────┐
        │   ╲                      ╱   │  ← left / right V-jaws
        │    ╲      ○ wire        ╱    │     spring-closed,
        │     ╲                  ╱     │     rack+pinion synced
        │      ╲________________╱      │
        │           ▼ into roller      │
        └──────────────────────────────┘
                 stripper head
```

## How it works

1. Two mirrored V-jaws slide horizontally in the mount plate.
2. Rack teeth on each jaw mesh with a shared pinion, so both jaws always move the same amount — the gap center never leaves the machine centerline.
3. Light springs pull the jaws closed. The wire itself opens them to size.
4. A flared lead-in lets you feed without lining up to a hole.

No channel selection. No hand-steering. Wire stays in the roller V.

## What’s in this package

| Path | Purpose |
|------|---------|
| [`MEASURE.md`](MEASURE.md) | Three measurements you take on *your* machine before printing |
| [`scad/feed_guide.scad`](scad/feed_guide.scad) | Parametric OpenSCAD — all printable parts |
| [`drawings/`](drawings/) | Flat DXF patterns for laser/CNC or paper templates |
| [`BOM.md`](BOM.md) | Printed parts + hardware list |
| [`ASSEMBLY.md`](ASSEMBLY.md) | Install on the stripper, tune springs, align centerline |
| [`diagrams/`](diagrams/) | Exploded / front / section concept diagrams |

## Build options

1. **3D print (recommended)** — PETG or ABS, 0.2 mm layers, 4+ walls, 40% infill. Enter your screw spacing in the SCAD file and export STLs.
2. **Laser / CNC from DXF** — cut the mount plate and jaws from 6 mm HDPE / UHMW / plywood; add printed or purchased pinion.
3. **No-print shop build** — see “Hardware-store alternative” in [`BOM.md`](BOM.md).

## Safety

- Unplug the stripper before removing the OEM plate or installing the guide.
- Keep fingers clear of the driven roller and blade.
- Start with light spring tension; too much drag can stall thin wire or burn the motor.
- Verify centerline alignment with a straight rod before powering on.
