# Olympia-Grady — site-only JobXML

Source archive: Google Drive `Olympia-Grady.jxl` (Trimble Access JobXML).

## Output

`Olympia-Grady-site-only.jxl` — same local site / coordinate system as the original job, with **all points removed**.

Kept:

- Wisconsin South 4803 / NAD83(2011) projection and datum
- Local site (grid) project height
- Final plane horizontal adjustment and geoid + inclined-plane vertical adjustment
- Units, geoid (GEOID18 Conus), reference-frame / HTDP models
- Empty `Reductions` (no keyed-in or survey points)

Removed:

- 37,960 `PointRecord` entries and all reduced `Point` coordinates
- Observations, stations, antennas, GNSS equipment, linework, notes, map/export lists
- Calibration point-pair name references (adjustment parameters remain)

## Use in Trimble Access

1. Copy `Olympia-Grady-site-only.jxl` onto the controller (e.g. under Trimble Data).
2. **Jobs → New** → create from **JobXML or DC file** → select this `.jxl`.
3. Confirm coordinate system shows Wisconsin South + the site calibration / local site.
4. Rename the new job as needed and survey into the same local site with no legacy points.

## Regenerate

```bash
python3 scripts/strip_jxl_site_only.py /path/to/Olympia-Grady.jxl \
  -o dist/olympia_grady/Olympia-Grady-site-only.jxl
```
