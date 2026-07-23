"""Command-line interface for StakeDXF conversion."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .converter import convert_for_trimble


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Convert Civil 3D DWG/DXF linework to Trimble Access stakeout DXF."
    )
    parser.add_argument("input", type=Path, help="Source .dwg or .dxf file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output DXF path (default: <input>_trimble_access.dxf)",
    )
    parser.add_argument("--dxf-version", default="R2010")
    parser.add_argument("--include-layers", default=None, help="Comma-separated layer names")
    parser.add_argument("--exclude-layers", default=None, help="Comma-separated layer names")
    parser.add_argument("--keep-display", action="store_true", help="Keep text/hatch/etc.")
    parser.add_argument("--no-explode", action="store_true")
    parser.add_argument("--no-splines", action="store_true")
    parser.add_argument("--flatten-z", action="store_true")
    parser.add_argument("--json", action="store_true", help="Print machine-readable summary")
    args = parser.parse_args(argv)

    if not args.input.exists():
        parser.error(f"File not found: {args.input}")

    output = args.output or args.input.with_name(f"{args.input.stem}_trimble_access.dxf")
    include = (
        [part.strip() for part in args.include_layers.split(",") if part.strip()]
        if args.include_layers
        else None
    )
    exclude = (
        [part.strip() for part in args.exclude_layers.split(",") if part.strip()]
        if args.exclude_layers
        else None
    )

    payload = convert_for_trimble(
        args.input,
        output,
        dxf_version=args.dxf_version,
        include_display_only=args.keep_display,
        explode_blocks=not args.no_explode,
        convert_splines=not args.no_splines,
        include_layers=include,
        exclude_layers=exclude,
        flatten_z=args.flatten_z,
    )

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"Wrote {output}")
        print(f"Stakeable entities: {payload['stakeable_count']}")
        for message in payload.get("messages", []):
            print(f"- {message}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
