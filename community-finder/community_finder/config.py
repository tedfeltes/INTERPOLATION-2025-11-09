"""Load and validate community-finder configuration."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml


@dataclass
class KeywordTiers:
    """Search terms grouped by priority."""

    primary: list[str] = field(default_factory=list)
    secondary: list[str] = field(default_factory=list)
    tertiary: list[str] = field(default_factory=list)

    def all_terms(self) -> list[tuple[str, str]]:
        """Return (tier_name, term) pairs in search order."""
        pairs: list[tuple[str, str]] = []
        for tier, terms in (
            ("primary", self.primary),
            ("secondary", self.secondary),
            ("tertiary", self.tertiary),
        ):
            for term in terms:
                cleaned = term.strip()
                if cleaned:
                    pairs.append((tier, cleaned))
        return pairs

    def is_empty(self) -> bool:
        return not any((self.primary, self.secondary, self.tertiary))


@dataclass
class RedditAuth:
    """Reddit API credentials (script or installed app)."""

    client_id: str
    client_secret: str
    user_agent: str
    username: str | None = None
    password: str | None = None


@dataclass
class ExportSettings:
    """Where and how to store result lists."""

    output_dir: str = "./exports"
    formats: list[str] = field(default_factory=lambda: ["json", "csv", "txt"])
    filename_prefix: str = "communities"
    # Optional cloud-synced folder (Dropbox, Drive File Stream, OneDrive, etc.)
    cloud_sync_dir: str | None = None
    auto_export: bool = True


@dataclass
class SearchSettings:
    """Reddit search behavior."""

    limit_per_term: int = 100
    include_nsfw: bool = True
    min_subscribers: int = 0
    require_any_tier_in_name_or_title: bool = False
    # Weights used when ranking matches
    weights: dict[str, int] = field(
        default_factory=lambda: {"primary": 10, "secondary": 5, "tertiary": 2}
    )


@dataclass
class AppConfig:
    keywords: KeywordTiers
    reddit: RedditAuth
    export: ExportSettings = field(default_factory=ExportSettings)
    search: SearchSettings = field(default_factory=SearchSettings)


def _as_str_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        return [str(item) for item in value]
    raise ValueError(f"Expected string or list of strings, got {type(value)!r}")


def load_config(path: str | Path) -> AppConfig:
    """Load YAML config from disk."""
    config_path = Path(path).expanduser().resolve()
    if not config_path.is_file():
        raise FileNotFoundError(f"Config not found: {config_path}")

    with config_path.open(encoding="utf-8") as handle:
        raw = yaml.safe_load(handle) or {}

    if not isinstance(raw, dict):
        raise ValueError("Config root must be a mapping")

    keywords_raw = raw.get("keywords") or {}
    keywords = KeywordTiers(
        primary=_as_str_list(keywords_raw.get("primary")),
        secondary=_as_str_list(keywords_raw.get("secondary")),
        tertiary=_as_str_list(keywords_raw.get("tertiary")),
    )
    if keywords.is_empty():
        raise ValueError(
            "No search terms configured. Set keywords.primary, "
            "keywords.secondary, and/or keywords.tertiary in the config file."
        )

    reddit_raw = raw.get("reddit") or {}
    missing = [
        key
        for key in ("client_id", "client_secret", "user_agent")
        if not str(reddit_raw.get(key, "")).strip()
    ]
    if missing:
        raise ValueError(
            "Missing Reddit API fields: "
            + ", ".join(missing)
            + ". Create an app at https://www.reddit.com/prefs/apps"
        )

    reddit = RedditAuth(
        client_id=str(reddit_raw["client_id"]).strip(),
        client_secret=str(reddit_raw["client_secret"]).strip(),
        user_agent=str(reddit_raw["user_agent"]).strip(),
        username=(str(reddit_raw["username"]).strip() or None)
        if reddit_raw.get("username")
        else None,
        password=(str(reddit_raw["password"]).strip() or None)
        if reddit_raw.get("password")
        else None,
    )

    export_raw = raw.get("export") or {}
    formats = _as_str_list(export_raw.get("formats") or ["json", "csv", "txt"])
    formats = [fmt.lower().strip() for fmt in formats if fmt.strip()]
    export = ExportSettings(
        output_dir=str(export_raw.get("output_dir") or "./exports"),
        formats=formats or ["json", "csv", "txt"],
        filename_prefix=str(export_raw.get("filename_prefix") or "communities"),
        cloud_sync_dir=(
            str(export_raw["cloud_sync_dir"]).strip() or None
            if export_raw.get("cloud_sync_dir")
            else None
        ),
        auto_export=bool(export_raw.get("auto_export", True)),
    )

    search_raw = raw.get("search") or {}
    weights_raw = search_raw.get("weights") or {}
    weights = {
        "primary": int(weights_raw.get("primary", 10)),
        "secondary": int(weights_raw.get("secondary", 5)),
        "tertiary": int(weights_raw.get("tertiary", 2)),
    }
    search = SearchSettings(
        limit_per_term=int(search_raw.get("limit_per_term", 100)),
        include_nsfw=bool(search_raw.get("include_nsfw", True)),
        min_subscribers=int(search_raw.get("min_subscribers", 0)),
        require_any_tier_in_name_or_title=bool(
            search_raw.get("require_any_tier_in_name_or_title", False)
        ),
        weights=weights,
    )

    return AppConfig(keywords=keywords, reddit=reddit, export=export, search=search)
