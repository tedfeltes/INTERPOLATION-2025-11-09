"""Export community lists to local and optional cloud-synced folders."""

from __future__ import annotations

import csv
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .config import ExportSettings
from .discover import CommunityMatch


SUPPORTED_FORMATS = {"json", "csv", "txt"}


def _timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _ensure_dir(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)
    return path


def write_json(path: Path, matches: Iterable[CommunityMatch], meta: dict[str, Any]) -> None:
    payload = {
        "meta": meta,
        "communities": [m.to_dict() for m in matches],
    }
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def write_csv(path: Path, matches: Iterable[CommunityMatch]) -> None:
    rows = list(matches)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "name",
                "title",
                "subscribers",
                "over18",
                "score",
                "url",
                "matched_primary",
                "matched_secondary",
                "matched_tertiary",
                "description",
            ],
        )
        writer.writeheader()
        for match in rows:
            terms = match.matched_terms
            writer.writerow(
                {
                    "name": match.name,
                    "title": match.title,
                    "subscribers": match.subscribers,
                    "over18": match.over18,
                    "score": match.score,
                    "url": match.url,
                    "matched_primary": "; ".join(terms.get("primary", [])),
                    "matched_secondary": "; ".join(terms.get("secondary", [])),
                    "matched_tertiary": "; ".join(terms.get("tertiary", [])),
                    "description": match.description.replace("\n", " ").strip(),
                }
            )


def write_txt(path: Path, matches: Iterable[CommunityMatch]) -> None:
    lines = [f"r/{m.name}" for m in matches]
    path.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")


def export_matches(
    matches: list[CommunityMatch],
    settings: ExportSettings,
    *,
    keywords_summary: dict[str, list[str]] | None = None,
    output_dir_override: str | Path | None = None,
) -> dict[str, list[Path]]:
    """Write exports to output_dir and optionally mirror to cloud_sync_dir.

    Returns mapping of destination label -> list of written file paths.
    """
    formats = [fmt.lower() for fmt in settings.formats if fmt.lower() in SUPPORTED_FORMATS]
    if not formats:
        raise ValueError(
            f"No supported export formats. Choose from: {', '.join(sorted(SUPPORTED_FORMATS))}"
        )

    stamp = _timestamp()
    prefix = settings.filename_prefix.strip() or "communities"
    base_name = f"{prefix}_{stamp}"

    output_dir = Path(output_dir_override or settings.output_dir).expanduser().resolve()
    _ensure_dir(output_dir)

    meta = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "count": len(matches),
        "keywords": keywords_summary or {},
    }

    written_primary: list[Path] = []
    for fmt in formats:
        path = output_dir / f"{base_name}.{fmt}"
        if fmt == "json":
            write_json(path, matches, meta)
        elif fmt == "csv":
            write_csv(path, matches)
        elif fmt == "txt":
            write_txt(path, matches)
        written_primary.append(path)

    result: dict[str, list[Path]] = {"local": written_primary}

    if settings.cloud_sync_dir:
        cloud_dir = Path(settings.cloud_sync_dir).expanduser().resolve()
        _ensure_dir(cloud_dir)
        mirrored: list[Path] = []
        for src in written_primary:
            dest = cloud_dir / src.name
            shutil.copy2(src, dest)
            mirrored.append(dest)
        result["cloud"] = mirrored

    return result
