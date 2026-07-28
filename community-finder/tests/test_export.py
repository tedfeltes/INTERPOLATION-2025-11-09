"""Tests for export writers."""

import json
from pathlib import Path

from community_finder.config import ExportSettings
from community_finder.discover import CommunityMatch
from community_finder.export import export_matches


def _sample_matches() -> list[CommunityMatch]:
    return [
        CommunityMatch(
            name="photography",
            title="Photography",
            description="Cameras and photos",
            subscribers=1000,
            over18=False,
            url="/r/photography/",
            score=20,
            matched_terms={"primary": ["photography"]},
        ),
        CommunityMatch(
            name="nsfw_example",
            title="Example",
            description="",
            subscribers=10,
            over18=True,
            url="/r/nsfw_example/",
            score=2,
            matched_terms={"tertiary": ["example"]},
        ),
    ]


def test_export_local_and_cloud(tmp_path: Path) -> None:
    local = tmp_path / "out"
    cloud = tmp_path / "cloud"
    settings = ExportSettings(
        output_dir=str(local),
        cloud_sync_dir=str(cloud),
        formats=["json", "csv", "txt"],
        filename_prefix="communities",
        auto_export=True,
    )
    written = export_matches(
        _sample_matches(),
        settings,
        keywords_summary={"primary": ["photography"]},
    )
    assert len(written["local"]) == 3
    assert len(written["cloud"]) == 3
    assert all(p.exists() for p in written["local"])
    assert all(p.exists() for p in written["cloud"])

    json_path = next(p for p in written["local"] if p.suffix == ".json")
    payload = json.loads(json_path.read_text(encoding="utf-8"))
    assert payload["meta"]["count"] == 2
    assert payload["communities"][0]["name"] == "photography"

    txt_path = next(p for p in written["local"] if p.suffix == ".txt")
    lines = txt_path.read_text(encoding="utf-8").strip().splitlines()
    assert lines == ["r/photography", "r/nsfw_example"]
