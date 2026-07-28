"""Command-line interface for StakeDXF conversion."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .combine import combine_for_base
from .converter import convert_for_trimble


def _run_convert(args: argparse.Namespace) -> int:
    if not args.input.exists():
        raise SystemExit(f"File not found: {args.input}")

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
        explode_proxies=not args.no_proxies,
        include_layers=include,
        exclude_layers=exclude,
        flatten_z=args.flatten_z,
        prefer_engine=args.engine,
    )

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"Wrote {output}")
        print(f"Stakeable entities: {payload['stakeable_count']}")
        for message in payload.get("messages", []):
            print(f"- {message}")
    return 0


def _add_convert_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("input", type=Path, help="Source .dwg or .dxf file")
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output DXF path (default: <input>_trimble_access.dxf)",
    )
    p.add_argument("--dxf-version", default="R2010")
    p.add_argument("--include-layers", default=None, help="Comma-separated layer names")
    p.add_argument("--exclude-layers", default=None, help="Comma-separated layer names")
    p.add_argument("--keep-display", action="store_true", help="Keep text/hatch/etc.")
    p.add_argument("--no-explode", action="store_true")
    p.add_argument("--no-splines", action="store_true")
    p.add_argument(
        "--no-proxies",
        action="store_true",
        help="Do not explode Civil 3D/AEC proxy graphics",
    )
    p.add_argument("--flatten-z", action="store_true")
    p.add_argument(
        "--engine",
        choices=["oda", "libredwg", "ezdwg"],
        default=None,
        help="Preferred DWG decoder (falls back automatically)",
    )
    p.add_argument("--json", action="store_true", help="Print machine-readable summary")


def main(argv: list[str] | None = None) -> int:
    # Preserve legacy flat args: `python -m app input.dwg -o out.dxf`
    # while adding `base` / `convert` subcommands.
    if argv is None:
        import sys

        argv = sys.argv[1:]

    if argv and argv[0] in {"base", "convert", "-h", "--help"}:
        parser = argparse.ArgumentParser(
            description="Convert Civil 3D DWG/DXF linework to Trimble Access stakeout DXF."
        )
        sub = parser.add_subparsers(dest="command", required=True)

        convert_p = sub.add_parser("convert", help="Convert one DWG/DXF")
        _add_convert_args(convert_p)

        base_p = sub.add_parser(
            "base",
            help="Combine multiple project DWG/DXF files into one base drawing "
            "(data layers only)",
        )
        base_p.add_argument(
            "inputs",
            nargs="+",
            type=Path,
            help="Two or more source .dwg / .dxf files from the same project",
        )
        base_p.add_argument(
            "-o",
            "--output",
            type=Path,
            required=True,
            help="Output base DXF path",
        )
        base_p.add_argument("--dxf-version", default="R2010")
        base_p.add_argument(
            "--engine",
            choices=["oda", "libredwg", "ezdwg"],
            default=None,
        )
        base_p.add_argument("--json", action="store_true")

        args = parser.parse_args(argv)
        if args.command == "base":
            payload = combine_for_base(
                args.inputs,
                args.output,
                dxf_version=args.dxf_version,
                prefer_engine=args.engine,
            )
            if args.json:
                print(json.dumps(payload, indent=2))
            else:
                print(f"Wrote {args.output}")
                print(payload["message"])
                for layer in payload.get("layers") or []:
                    print(f"  {layer['name']}: {layer['entity_count']}")
            return 0 if payload.get("ok") else 1
        return _run_convert(args)

    parser = argparse.ArgumentParser(
        description="Convert Civil 3D DWG/DXF linework to Trimble Access stakeout DXF."
    )
    _add_convert_args(parser)
    return _run_convert(parser.parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
