"""Command-line interface for Community Finder."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import __version__
from .config import load_config
from .discover import discover_communities
from .export import export_matches
from .reddit_client import create_reddit, search_subreddits


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="community-finder",
        description=(
            "Discover Reddit communities matching primary, secondary, "
            "and tertiary keywords from a config file."
        ),
    )
    parser.add_argument(
        "-c",
        "--config",
        default="config.yaml",
        help="Path to YAML config (default: config.yaml)",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        default=None,
        help="Override export.output_dir from config",
    )
    parser.add_argument(
        "--no-export",
        action="store_true",
        help="Print results only; do not write files",
    )
    parser.add_argument(
        "--format",
        choices=("json", "table", "names"),
        default="table",
        help="Stdout format (default: table)",
    )
    parser.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max communities to print (export still includes all)",
    )
    parser.add_argument(
        "--version",
        action="version",
        version=f"community-finder {__version__}",
    )
    return parser


def _print_table(matches, limit: int | None) -> None:
    rows = matches if limit is None else matches[:limit]
    if not rows:
        print("No communities matched your keywords.")
        return
    name_w = max(4, max(len(m.name) for m in rows))
    print(f"{'NAME':<{name_w}}  {'SCORE':>5}  {'SUBS':>10}  NSFW  MATCHED")
    print(f"{'-' * name_w}  {'-----':>5}  {'----------':>10}  ----  -------")
    for match in rows:
        nsfw = "yes" if match.over18 else "no"
        flat = []
        for tier, terms in match.matched_terms.items():
            flat.append(f"{tier}={','.join(terms)}")
        print(
            f"{match.name:<{name_w}}  {match.score:>5}  {match.subscribers:>10}  "
            f"{nsfw:<4}  {'; '.join(flat)}"
        )
    if limit is not None and len(matches) > limit:
        print(f"… {len(matches) - limit} more (exported if auto_export is on)")


def _print_names(matches, limit: int | None) -> None:
    rows = matches if limit is None else matches[:limit]
    for match in rows:
        print(f"r/{match.name}")


def run(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    try:
        config = load_config(args.config)
    except (OSError, ValueError) as exc:
        print(f"Config error: {exc}", file=sys.stderr)
        return 2

    try:
        reddit = create_reddit(config.reddit)

        def search_fn(query: str, *, limit: int, include_nsfw: bool):
            return search_subreddits(
                reddit, query, limit=limit, include_nsfw=include_nsfw
            )

        matches = discover_communities(config, search_fn)
    except Exception as exc:  # noqa: BLE001 — surface API errors cleanly to CLI
        print(f"Search failed: {exc}", file=sys.stderr)
        return 1

    if args.format == "json":
        payload = [m.to_dict() for m in matches]
        if args.limit is not None:
            payload = payload[: args.limit]
        print(json.dumps(payload, indent=2, ensure_ascii=False))
    elif args.format == "names":
        _print_names(matches, args.limit)
    else:
        _print_table(matches, args.limit)

    should_export = config.export.auto_export and not args.no_export
    if should_export:
        try:
            written = export_matches(
                matches,
                config.export,
                keywords_summary={
                    "primary": list(config.keywords.primary),
                    "secondary": list(config.keywords.secondary),
                    "tertiary": list(config.keywords.tertiary),
                },
                output_dir_override=args.output_dir,
            )
        except (OSError, ValueError) as exc:
            print(f"Export failed: {exc}", file=sys.stderr)
            return 1

        print()
        for label, paths in written.items():
            for path in paths:
                print(f"Wrote ({label}): {path}")

    print(f"\nFound {len(matches)} communities.")
    return 0


def main() -> None:
    raise SystemExit(run())


if __name__ == "__main__":
    main()
