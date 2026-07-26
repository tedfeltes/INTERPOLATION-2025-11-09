# AGENTS.md

## Cursor Cloud specific instructions

### Repository shape (non-obvious)
- The base branch `main` is an empty bootstrap commit. The real code lives on `cursor/*` feature branches; base new work on the latest feature branch that has content, not on `main`.
- Two products live here:
  - `app/` — a Python **FastAPI cloud converter** (Civil 3D DWG → Trimble Access DXF) plus a CLI. This is the service that is set up and runnable on the Linux cloud VM.
  - `mobile/stakedxf/` — a **Flutter** mobile app (Android TSC5 + iOS). Building/running it needs the Flutter + Android SDK/NDK and a device/emulator, plus a native LibreDWG cross-compile; it is out of scope on this headless Linux VM. See `mobile/README.md`.

### Python service (in scope)
- Dependencies install into a virtualenv at `.venv` (the update script creates it). Activate with `. .venv/bin/activate` before running anything.
- Run tests: `python -m pytest` from the repo root (25 tests, ~1s).
- Dev server (hot reload): `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`. Non-reload equivalent is `python -m app`. Web UI is served at `/`; JSON API under `/api/*` (see `/api/health`, `/api/convert`, `/api/download/{job_id}`).
- CLI conversion: `python -m app.cli samples/Line.dwg -o /tmp/out.dxf --json`.
- No Python linter is configured (the `flutter_lints` config only applies to the Flutter app).

### DWG conversion engines (gotcha)
- The converter tries ODA → LibreDWG → `ezdwg`. `ODAFileConverter` and LibreDWG's `dwg2dxf` are optional native binaries and are **not installed** here, so `/api/health` reports `oda:false, libredwg:false`. The pure-Python `ezdwg` engine is always available and handles the bundled `samples/*.dwg`, so conversion works without the native tools. Installing LibreDWG/ODA only improves Civil 3D proxy-graphics fidelity.

### Misc
- `STAKEDXF_API_KEY` (env var) optionally gates the automation endpoints; it is unset by default, so no key is required for local use.
- Sample DWGs for smoke tests are in `samples/`.
