# Power Automate + OneDrive auto-convert

Use this when you have **only an iPhone + Trimble TSC5** in the field and want the DXF to appear in OneDrive automatically — no phone conversion step.

## What you get

```
Office saves design.dwg → OneDrive project folder
        ↓ (Power Automate)
StakeDXF cloud /api/convert-file
        ↓
OneDrive gets design_trimble_access.dxf
        ↓
Field: copy DXF onto TSC5 → stake
```

## One-time setup

### 1. Host StakeDXF on a public HTTPS URL

Examples: Azure Container Apps, Render, Fly.io, a small VPS with Docker.

```bash
docker build -t stakedxf .
docker run -p 8000:8000 -e STAKEDXF_API_KEY='long-random-secret' stakedxf
```

Put HTTPS in front (Caddy / nginx / cloud load balancer).

### 2. Create the Power Automate flow

1. **Trigger:** *When a file is created or modified (properties only)*  
   Location: your project OneDrive folder  
   Optional filter: file name ends with `.dwg`

2. **Action:** *Get file content* (OneDrive) for the trigger file

3. **Action:** *HTTP*  
   - Method: `POST`  
   - URI: `https://YOUR-HOST/api/convert-file`  
   - Headers:
     - `X-API-Key`: same value as `STAKEDXF_API_KEY`
   - Body: multipart form  
     - key `file` = file content from step 2  
     - key `explode_proxies` = `true`  
     - key `dxf_version` = `R2010`

   In Power Automate, the easiest pattern is often:
   - **HTTP with Azure AD** is not required
   - Use **HTTP** action with multipart body, or an Azure Function middleman if multipart is awkward in your tenant

   Minimal multipart example body (conceptually):

   ```
   Content-Type: multipart/form-data; boundary=---boundary

   -----boundary
   Content-Disposition: form-data; name="file"; filename="design.dwg"
   Content-Type: application/octet-stream

   <binary file content>
   -----boundary
   Content-Disposition: form-data; name="explode_proxies"

   true
   -----boundary--
   ```

4. **Action:** *Create file* (OneDrive)  
   - Folder: same project folder (or a `stakeout/` subfolder)  
   - File name: `@{replace(triggerOutputs()?['body/{FilenameWithExtension}'], '.dwg', '_trimble_access.dxf')}`  
   - File content: **body of the HTTP response** (raw DXF bytes)

5. Skip / ignore files that already end with `_trimble_access.dxf` so the flow does not loop.

### 3. Field use after automation

1. Office drops/saves the Civil 3D DWG to OneDrive (with `PROXYGRAPHICS=1`).
2. Within a minute, `*_trimble_access.dxf` appears beside it.
3. On the **TSC5**: OneDrive app → download DXF → Trimble Access File Explorer → copy into `Trimble Data/Projects/<project>/`.
4. Map files → selectable → Stakeout.

## If Power Automate multipart is painful

Use the phone path instead (still no laptop):

1. iPhone Safari → StakeDXF → Choose DWG from OneDrive → Convert  
2. Save DXF back to OneDrive  
3. TSC5 pulls the DXF

Or call from a tiny Azure Function:

```python
import requests

def main(dwg_bytes: bytes, name: str, base_url: str, api_key: str) -> bytes:
    r = requests.post(
        f"{base_url.rstrip('/')}/api/convert-file",
        headers={"X-API-Key": api_key},
        files={"file": (name, dwg_bytes, "application/octet-stream")},
        data={"explode_proxies": "true", "dxf_version": "R2010"},
        timeout=300,
    )
    r.raise_for_status()
    return r.content
```

## Office DWG requirement

Civil 3D must save the DWG with **proxy graphics** (`PROXYGRAPHICS=1`, usual default). StakeDXF recovers AECC linework from that embedded display metafile — no AutoCAD in the field, and no laptop.
