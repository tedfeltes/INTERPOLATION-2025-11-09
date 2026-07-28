"""Keyword-tiered community discovery and scoring."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable

from .config import AppConfig, KeywordTiers, SearchSettings


SearchFn = Callable[..., list[dict[str, Any]]]


@dataclass
class CommunityMatch:
    name: str
    title: str
    description: str
    subscribers: int
    over18: bool
    url: str
    score: int = 0
    matched_terms: dict[str, list[str]] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "title": self.title,
            "description": self.description,
            "subscribers": self.subscribers,
            "over18": self.over18,
            "url": self.url,
            "score": self.score,
            "matched_terms": self.matched_terms,
        }


def _text_blob(item: dict[str, Any]) -> str:
    return " ".join(
        [
            str(item.get("name") or ""),
            str(item.get("title") or ""),
            str(item.get("description") or ""),
        ]
    ).lower()


def score_community(
    item: dict[str, Any],
    keywords: KeywordTiers,
    weights: dict[str, int],
) -> tuple[int, dict[str, list[str]]]:
    """Score a community against keyword tiers."""
    blob = _text_blob(item)
    name_title = f"{item.get('name', '')} {item.get('title', '')}".lower()
    matched: dict[str, list[str]] = {"primary": [], "secondary": [], "tertiary": []}
    score = 0

    for tier, terms in (
        ("primary", keywords.primary),
        ("secondary", keywords.secondary),
        ("tertiary", keywords.tertiary),
    ):
        weight = int(weights.get(tier, 1))
        for term in terms:
            needle = term.strip().lower()
            if not needle:
                continue
            if needle in blob:
                matched[tier].append(term.strip())
                # Extra bump when the term appears in name/title
                bump = weight * (2 if needle in name_title else 1)
                score += bump

    # Drop empty tiers for cleaner export
    matched = {k: v for k, v in matched.items() if v}
    return score, matched


def discover_communities(
    config: AppConfig,
    search_fn: SearchFn,
) -> list[CommunityMatch]:
    """Run keyword searches and return ranked, deduplicated communities."""
    keywords = config.keywords
    settings: SearchSettings = config.search
    by_name: dict[str, CommunityMatch] = {}

    for tier, term in keywords.all_terms():
        hits = search_fn(
            term,
            limit=settings.limit_per_term,
            include_nsfw=settings.include_nsfw,
        )
        for raw in hits:
            name = str(raw.get("name") or "").strip()
            if not name:
                continue
            subscribers = int(raw.get("subscribers") or 0)
            if subscribers < settings.min_subscribers:
                continue

            score, matched = score_community(raw, keywords, settings.weights)
            if settings.require_any_tier_in_name_or_title:
                name_title = f"{raw.get('name', '')} {raw.get('title', '')}".lower()
                all_terms = [
                    t.strip().lower()
                    for t in (keywords.primary + keywords.secondary + keywords.tertiary)
                    if t.strip()
                ]
                if not any(t in name_title for t in all_terms):
                    continue

            # Ensure the term that produced this search hit is credited
            matched.setdefault(tier, [])
            if term not in matched[tier]:
                matched[tier].append(term)
                score += int(settings.weights.get(tier, 1))

            existing = by_name.get(name.lower())
            if existing is None:
                by_name[name.lower()] = CommunityMatch(
                    name=name,
                    title=str(raw.get("title") or ""),
                    description=str(raw.get("description") or ""),
                    subscribers=subscribers,
                    over18=bool(raw.get("over18")),
                    url=str(raw.get("url") or f"/r/{name}/"),
                    score=score,
                    matched_terms=matched,
                )
            else:
                existing.score = max(existing.score, score)
                existing.subscribers = max(existing.subscribers, subscribers)
                for t_name, terms in matched.items():
                    bucket = existing.matched_terms.setdefault(t_name, [])
                    for item in terms:
                        if item not in bucket:
                            bucket.append(item)

    ranked = sorted(
        by_name.values(),
        key=lambda m: (-m.score, -m.subscribers, m.name.lower()),
    )
    return ranked
