# Assembly & install

## 1. Print / cut parts

Export STLs from `scad/feed_guide.scad` after entering your measurements. Deburr V faces with a knife or sandpaper so wire slides smoothly.

## 2. Dry-fit jaws

1. Drop the pinion axle through the plate bore (do not final-tighten yet).
2. Slide left and right jaws onto the plate rails so their rack teeth both mesh the pinion.
3. Move one jaw by hand — the other must move the opposite direction by the same amount. If not, flip a jaw or check tooth mesh.
4. Confirm the closed gap is on the plate vertical centerline (mark center with a Sharpie first).

## 3. Springs

Hook one light extension spring from each jaw’s outer hole to the matching plate anchor hole. Jaws should close firmly but still open by hand to your max wire size.

## 4. Flare cover

Seat the lead-in flare over the thumbscrew holes (or screw it to the plate face with short M3s if you added bosses). Mouth faces outward, small end toward the roller.

## 5. Mount on the stripper

1. Unplug the machine.
2. Remove OEM 5-hole plate.
3. Place the new assembly on the blue head, align thumbscrew holes, tighten OEM thumbscrews snug — not crushing plastic.
4. Sight a straight rod through the jaws into the roller V. The rod must sit in the deepest part of the V with both jaws touching it. If it sits left/right, loosen thumbscrews and shim/slot-adjust (the plate holes can be slotted ±1 mm if needed).

## 6. First-run tuning

| Symptom | Fix |
|---------|-----|
| Wire still walks off roller | Centerline misaligned — re-measure **C**, or add a thin washer under one side of the plate |
| Thin wire slips / motor labors | Lighter springs; polish V faces; add PTFE tape |
| Thick wire won’t enter | Increase `max_wire_d` / check jaw travel; flare mouth too small |
| Jaws rack unevenly | Debris in teeth; reprint pinion at 100% infill; reduce `slot_clearance` if sloppy |
| Guide rubs blade/roller | Reduce stick-out; shorten `jaw_t` or add spacers behind plate |

## 7. Daily use

1. Open jaws with fingers (or just push wire into the flare).
2. Feed the free end until the driven roller grabs it.
3. Let go — jaws keep it centered while it strips.
4. For bundled / kinked scrap, straighten the first 100 mm so the lead-in can catch it.

You no longer pick a hole size or steer the wire mid-strip.
