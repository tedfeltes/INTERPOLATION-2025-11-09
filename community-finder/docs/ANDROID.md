# Running Community Finder on Android

Community Finder is a Python CLI. On Android it runs inside **[Termux](https://termux.dev/)**.

## 1. Install Termux

Prefer the F-Droid build (Play Store builds are outdated):

1. Install F-Droid
2. Install **Termux** and optionally **Termux:API**

## 2. System packages

```bash
pkg update && pkg upgrade
pkg install python git
```

## 3. Get storage access

So exports can land in shared folders (Download, Drive, etc.):

```bash
termux-setup-storage
```

This maps phone storage under `~/storage/` (e.g. `~/storage/downloads`).

## 4. Install Community Finder

From this repo (or copy the `community-finder` folder onto the device):

```bash
cd community-finder
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp samples/config.example.yaml config.yaml
```

Edit credentials and keywords:

```bash
nano config.yaml
```

Suggested Android export paths:

```yaml
export:
  output_dir: "/data/data/com.termux/files/home/exports"
  cloud_sync_dir: "/storage/emulated/0/Download/CommunityFinder"
  formats: [json, csv, txt]
  auto_export: true
```

Or using Termux’s storage symlink:

```yaml
export:
  output_dir: "~/exports"
  cloud_sync_dir: "~/storage/downloads/CommunityFinder"
```

If you use Dropbox / Google Drive / OneDrive Android apps, point `cloud_sync_dir` at a folder those apps sync (or copy exports into them after a run).

## 5. Run

```bash
source .venv/bin/activate
python -m community_finder -c config.yaml
```

Plain name list only:

```bash
python -m community_finder -c config.yaml --format names --no-export
```

## 6. Optional: schedule with Termux

Install a cron-like job with `termux-job-scheduler` or run manually when needed. Example wrapper:

```bash
#!/data/data/com.termux/files/usr/bin/bash
cd ~/community-finder || exit 1
source .venv/bin/activate
python -m community_finder -c config.yaml
```

## Troubleshooting

| Issue | Fix |
|---|---|
| `Permission denied` writing to `/sdcard` | Re-run `termux-setup-storage`; use `~/storage/downloads/...` |
| Reddit `401` / auth errors | Check `client_id`, `client_secret`, `user_agent` |
| Empty results | Broaden keywords; raise `limit_per_term`; set `include_nsfw: true` if relevant |
| SSL / network errors | Confirm mobile data / Wi‑Fi; retry later if Reddit rate-limits |

Community Finder does not require root and does not install as a Play Store APK — Termux is the supported Android runtime.
