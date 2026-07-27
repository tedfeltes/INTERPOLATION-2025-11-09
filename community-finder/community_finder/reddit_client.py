"""Reddit API client wrapper (official API via PRAW)."""

from __future__ import annotations

from typing import Any, Protocol

import praw

from .config import RedditAuth


class SubredditLike(Protocol):
    display_name: str
    title: str
    public_description: str
    subscribers: int | None
    over18: bool
    url: str


def create_reddit(auth: RedditAuth) -> praw.Reddit:
    """Create an authenticated Reddit client.

    Read-only (client credentials) works for subreddit search.
    Username/password are optional for script apps that need a user session.
    """
    kwargs: dict[str, Any] = {
        "client_id": auth.client_id,
        "client_secret": auth.client_secret,
        "user_agent": auth.user_agent,
    }
    if auth.username and auth.password:
        kwargs["username"] = auth.username
        kwargs["password"] = auth.password

    reddit = praw.Reddit(**kwargs)
    reddit.read_only = not (auth.username and auth.password)
    return reddit


def search_subreddits(
    reddit: praw.Reddit,
    query: str,
    *,
    limit: int = 100,
    include_nsfw: bool = True,
) -> list[dict[str, Any]]:
    """Search communities matching a query string."""
    results: list[dict[str, Any]] = []
    for sub in reddit.subreddits.search(query, limit=limit, include_nsfw=include_nsfw):
        results.append(subreddit_to_dict(sub))
    return results


def subreddit_to_dict(sub: SubredditLike) -> dict[str, Any]:
    return {
        "name": str(getattr(sub, "display_name", "") or ""),
        "title": str(getattr(sub, "title", "") or ""),
        "description": str(getattr(sub, "public_description", "") or ""),
        "subscribers": int(getattr(sub, "subscribers", 0) or 0),
        "over18": bool(getattr(sub, "over18", False)),
        "url": str(getattr(sub, "url", "") or ""),
    }
