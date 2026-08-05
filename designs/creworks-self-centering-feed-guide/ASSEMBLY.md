# Fabrication & install (all concepts)

## 0. Measure before you cut

Per [`MEASURE.md`](MEASURE.md) / drawing **WSFG-IF**:

1. Thumbscrew hole C–C → **A**
2. Screw clearance → **B**
3. Roller V centerline height on the mounting face → **C**

Update generators and regenerate sheets if values differ from 140 / 8.5 / 55.

## 1. Pick a concept

| If you want… | Build |
|--------------|-------|
| Best centering per effort | **B** |
| Lowest drag | **C** |
| Zero moving parts tonight | **A** |
| Moving jaws, no gears | **D** |
| Lathe-chuck precision | **E** |

## 2. Fab

- **Print:** PETG/ABS, 0.2 mm, ≥4 walls, 40% infill. Orient wear faces on XY.
- **Machine:** HDPE / UHMW / Al 6061 from DXF profiles in `drawings/sheets/*.dxf`.
- Deburr; V and roller contact faces must be smooth.

## 3. Install (common)

1. Unplug stripper. Remove OEM 5-hole plate (keep it).
2. Mount new guide with OEM thumbscrews — snug, don’t crush plastic.
3. Sight a straight rod through the guide into the driven V. Rod must sit in the V bottom.
4. If off-center: slot mount holes ±1 mm or shim; re-check **C**.

## 4. Concept-specific checks

**A:** Keyhole exit vertical; wire drops to round portion of keyhole.  
**B:** V apex on CL; hold-down opens by hand to your max wire; light spring only.  
**C:** Move one arm — other mirrors via equalizer; rollers spin freely; min gap ~1 mm.  
**D:** Center pivot on CL; links don’t bind; pads hit wire together.  
**E:** Scroll opens/closes about CL with no jaw lag.

## 5. First strip

Start mid-size wire. If it walks out of the roller → centerline error.  
If motor labors / thin wire slips → reduce spring/hold-down force (or switch to **C**).
