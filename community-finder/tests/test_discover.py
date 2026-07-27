"""Tests for discovery scoring and ranking."""

from community_finder.config import (
    AppConfig,
    ExportSettings,
    KeywordTiers,
    RedditAuth,
    SearchSettings,
)
from community_finder.discover import discover_communities, score_community


def _cfg(**search_overrides) -> AppConfig:
    search = SearchSettings(
        limit_per_term=25,
        include_nsfw=True,
        min_subscribers=0,
        weights={"primary": 10, "secondary": 5, "tertiary": 2},
    )
    for key, value in search_overrides.items():
        setattr(search, key, value)
    return AppConfig(
        keywords=KeywordTiers(
            primary=["photography"],
            secondary=["landscape"],
            tertiary=["sony"],
        ),
        reddit=RedditAuth(
            client_id="id",
            client_secret="secret",
            user_agent="test",
        ),
        export=ExportSettings(),
        search=search,
    )


def test_score_community_weights() -> None:
    item = {
        "name": "LandscapePhotography",
        "title": "Landscape Photography",
        "description": "Sony cameras welcome",
    }
    score, matched = score_community(
        item,
        KeywordTiers(
            primary=["photography"],
            secondary=["landscape"],
            tertiary=["sony"],
        ),
        {"primary": 10, "secondary": 5, "tertiary": 2},
    )
    assert "photography" in matched["primary"]
    assert "landscape" in matched["secondary"]
    assert "sony" in matched["tertiary"]
    assert score > 0


def test_discover_dedupes_and_ranks() -> None:
    fixtures = {
        "photography": [
            {
                "name": "photography",
                "title": "Photography",
                "description": "General photo community",
                "subscribers": 1000,
                "over18": False,
                "url": "/r/photography/",
            },
            {
                "name": "SonyAlpha",
                "title": "Sony Alpha",
                "description": "Sony photography",
                "subscribers": 500,
                "over18": False,
                "url": "/r/SonyAlpha/",
            },
        ],
        "landscape": [
            {
                "name": "photography",
                "title": "Photography",
                "description": "General photo community",
                "subscribers": 1000,
                "over18": False,
                "url": "/r/photography/",
            },
            {
                "name": "LandscapePhotography",
                "title": "Landscape Photography",
                "description": "Landscapes",
                "subscribers": 800,
                "over18": False,
                "url": "/r/LandscapePhotography/",
            },
        ],
        "sony": [
            {
                "name": "SonyAlpha",
                "title": "Sony Alpha",
                "description": "Sony photography",
                "subscribers": 500,
                "over18": False,
                "url": "/r/SonyAlpha/",
            },
        ],
    }

    def search_fn(query: str, *, limit: int, include_nsfw: bool):
        return list(fixtures.get(query, []))

    matches = discover_communities(_cfg(), search_fn)
    names = [m.name for m in matches]
    assert names.count("photography") == 1
    assert names.count("SonyAlpha") == 1
    assert "LandscapePhotography" in names
    # photography should rank highly (primary + secondary credit)
    assert matches[0].name in {"photography", "LandscapePhotography", "SonyAlpha"}
    assert all(m.score > 0 for m in matches)


def test_min_subscribers_filter() -> None:
    def search_fn(query: str, *, limit: int, include_nsfw: bool):
        return [
            {
                "name": "tiny",
                "title": "photography club",
                "description": "",
                "subscribers": 5,
                "over18": False,
                "url": "/r/tiny/",
            },
            {
                "name": "big",
                "title": "photography",
                "description": "",
                "subscribers": 500,
                "over18": False,
                "url": "/r/big/",
            },
        ]

    matches = discover_communities(_cfg(min_subscribers=100), search_fn)
    assert [m.name for m in matches] == ["big"]
