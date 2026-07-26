# Field kit: iPhone + Trimble TSC5 + OneDrive

You said the real constraint clearly: **no laptop in the field** — only an iPhone, a Trimble TSC5 (Android), and OneDrive.

StakeDXF is built for that. Conversion runs in the **cloud**. The phone/collector only move files.

## Recommended setups

### Option 1 — Auto-convert (best)

Office OneDrive folder watches for `.dwg` → Power Automate calls StakeDXF → `*_trimble_access.dxf` appears automatically.

Field work:
1. Open OneDrive on the TSC5
2. Copy DXF into `Trimble Data/Projects/<project>/`
3. Stake

See [static/power-automate-onedrive.md](static/power-automate-onedrive.md).

### Option 2 — Convert on iPhone

1. Open the hosted StakeDXF URL in Safari (Add to Home Screen)
2. Choose DWG from OneDrive / Files
3. Convert → Save DXF back to OneDrive
4. On TSC5, copy DXF into the project folder and stake

### Option 3 — Convert on the TSC5 browser

Same as Option 2, but use the TSC5 Chrome/browser if cellular/Wi‑Fi can reach the StakeDXF URL. Then move the downloaded DXF with Trimble Access File Explorer.

## What you must host

StakeDXF needs an always-on HTTPS URL. Docker example:

```bash
docker build -t stakedxf .
docker run -d -p 8000:8000 \
  -e STAKEDXF_API_KEY='replace-me' \
  --name stakedxf stakedxf
```

Put HTTPS in front. Bookmark that URL on the iPhone.

## TSC5 placement path

Android Trimble Access expects project map files under:

```text
/Trimble Data/Projects/<project name>/
```

DXF must live there (or be added via Map files → Add) before Layer manager can enable it.

## Civil 3D office note

Save DWGs with `PROXYGRAPHICS=1` (typical default). That is the only office CAD requirement for AECC linework recovery. You do **not** need AutoCAD or a computer with you in the field.
