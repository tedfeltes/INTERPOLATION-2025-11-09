# Measure your machine (do this first)

The SCAD defaults are typical for CREWORKS 180W-class heads, but thumbscrew spacing varies. Print only after you measure.

Unplug the machine. Remove the two black thumbscrews and the OEM 5-hole plate (keep the plate — it is your backup).

## Required measurements

| ID | What to measure | How | Default in SCAD |
|----|-----------------|-----|-----------------|
| **A** | Thumbscrew hole center-to-center (horizontal) | Calipers across the two threaded holes in the blue head | `140` mm |
| **B** | Hole diameter / screw clearance | Measure screw shank; add 0.5 mm for clearance | `8.5` mm (≈ M8) |
| **C** | Centerline height | From the **bottom** of the mounting face up to the deepest point of the lower V-roller (or to the center of the largest OEM hole) | `55` mm |
| **D** | Mount face width × height | Overall blue face the plate sat against (must cover both holes with margin) | `170 × 100` mm |
| **E** | Max wire you actually strip | Caps jaw travel; machine claims ~38 mm | `38` mm |

### Quick centerline trick

If the V-roller is hard to reach with calipers:

1. Lay a straight steel rod / drill bit into the roller V so it sits centered.
2. Hold a square against the mounting face and mark the rod height on a scrap of paper taped to the face.
3. That mark is **C**.

### Optional but useful

| ID | What | Why |
|----|------|-----|
| **F** | Depth from mount face to roller nip | Sets guide stick-out so jaws sit just ahead of the roller (~15–25 mm typical) |
| **G** | Thread type of thumbscrews | Reuse OEM screws; note if M6 vs M8 |

Write your values into the top of [`scad/feed_guide.scad`](scad/feed_guide.scad):

```openscad
screw_spacing   = 140;  // A
screw_clearance = 8.5;  // B
centerline_z    = 55;   // C
plate_w         = 170;  // D width
plate_h         = 100;  // D height
max_wire_d      = 38;   // E
```

Then regenerate STLs / DXFs.
