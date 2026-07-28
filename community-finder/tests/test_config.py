"""Tests for config loading."""

from pathlib import Path

import pytest
import yaml

from community_finder.config import load_config


def _write_config(tmp_path: Path, data: dict) -> Path:
    path = tmp_path / "config.yaml"
    path.write_text(yaml.safe_dump(data), encoding="utf-8")
    return path


def _base_config(**overrides) -> dict:
    data = {
        "keywords": {
            "primary": ["photography"],
            "secondary": ["landscape"],
            "tertiary": ["sony"],
        },
        "reddit": {
            "client_id": "id",
            "client_secret": "secret",
            "user_agent": "community-finder/test",
        },
        "export": {
            "output_dir": "./exports",
            "formats": ["json", "csv", "txt"],
            "auto_export": True,
        },
        "search": {
            "limit_per_term": 50,
            "include_nsfw": True,
            "min_subscribers": 10,
        },
    }
    data.update(overrides)
    return data


def test_load_config_success(tmp_path: Path) -> None:
    path = _write_config(tmp_path, _base_config())
    cfg = load_config(path)
    assert cfg.keywords.primary == ["photography"]
    assert cfg.keywords.secondary == ["landscape"]
    assert cfg.reddit.client_id == "id"
    assert cfg.search.limit_per_term == 50
    assert cfg.export.formats == ["json", "csv", "txt"]


def test_missing_keywords_raises(tmp_path: Path) -> None:
    data = _base_config()
    data["keywords"] = {"primary": [], "secondary": [], "tertiary": []}
    path = _write_config(tmp_path, data)
    with pytest.raises(ValueError, match="No search terms"):
        load_config(path)


def test_missing_reddit_fields_raises(tmp_path: Path) -> None:
    data = _base_config()
    data["reddit"] = {"client_id": "id"}
    path = _write_config(tmp_path, data)
    with pytest.raises(ValueError, match="Missing Reddit API fields"):
        load_config(path)


def test_keyword_tiers_all_terms(tmp_path: Path) -> None:
    path = _write_config(tmp_path, _base_config())
    cfg = load_config(path)
    assert cfg.keywords.all_terms() == [
        ("primary", "photography"),
        ("secondary", "landscape"),
        ("tertiary", "sony"),
    ]
