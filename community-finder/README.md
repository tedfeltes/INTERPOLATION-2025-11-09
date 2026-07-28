# Community Finder

Discover Reddit communities that match **keywords you choose**.  
Configure primary, secondary, and tertiary search terms in a YAML file, run the crawler, and export a ranked list of community names to a folder on your device or a cloud-synced directory.

Works on **desktop (Linux / macOS / Windows)** and **Android via Termux**.

## What it does

1. Reads your keyword tiers from `config.yaml`
2. Queries Reddit’s official API for each term
3. Deduplicates and scores communities (primary hits weigh more than secondary/tertiary)
4. Exports JSON / CSV / plain-text name lists to a folder you pick
5. Optionally mirrors those files into a Dropbox, Google Drive, OneDrive, or other sync folder

It stores **community metadata and names only** — not posts or media.

## Quick start (desktop)

```bash
cd community-finder
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp samples/config.example.yaml config.yaml
# Edit config.yaml — add Reddit API credentials + your keywords
python -m community_finder -c config.yaml
```

Exports land in `./exports` by default (override with `export.output_dir` or `-o`).

## Reddit API credentials

1. Log in to Reddit → [https://www.reddit.com/prefs/apps](https://www.reddit.com/prefs/apps)
2. Create an app → type **script**
3. Copy the client ID and secret into `config.yaml`
4. Set a descriptive `user_agent` (Reddit requires this)

Read-only search works with client ID + secret alone.

## Config: keyword tiers

```yaml
keywords:
  primary:          # highest weight
    - photography
    - camera
  secondary:
    - landscape
    - portrait
  tertiary:         # broad / optional refiners
    - sony
    - fuji
```

Edit these anytime and re-run. See `samples/config.example.yaml` for the full schema.

## Export options

| Setting | Purpose |
|---|---|
| `export.output_dir` | Local destination folder |
| `export.cloud_sync_dir` | Optional second copy into a sync folder |
| `export.formats` | `json`, `csv`, `txt` |
| `export.auto_export` | Write files automatically after each run |

CLI overrides:

```bash
python -m community_finder -c config.yaml -o ~/Documents/CommunityFinder
python -m community_finder -c config.yaml --format names --no-export
python -m community_finder -c config.yaml --format json --limit 20
```

### Cloud libraries

Point `cloud_sync_dir` at any folder your sync client watches:

- Dropbox: `~/Dropbox/CommunityFinder`
- Google Drive for Desktop: `~/Library/CloudStorage/GoogleDrive-…/My Drive/CommunityFinder`
- OneDrive: `~/OneDrive/CommunityFinder`
- Android: `/sdcard/Download/CommunityFinder` (or a Drive/Dropbox app folder)

## Android (Termux)

See [docs/ANDROID.md](docs/ANDROID.md) for install, storage access, and scheduled runs.

## Layout

```
community-finder/
  community_finder/   Python package (config, search, export, CLI)
  samples/            Example config
  docs/               Android / Termux guide
  tests/              Unit tests (mocked Reddit responses)
```

## Tests

```bash
cd community-finder
pip install -r requirements.txt pytest
pytest -q
```

## Notes

- Uses Reddit’s official API (PRAW). Respect their rate limits and [API terms](https://www.reddit.com/wiki/api).
- “All matching communities” means whatever the search API returns for your terms — not a full site dump.
- Keep credentials out of git; `config.yaml` is gitignored when placed in this folder.
