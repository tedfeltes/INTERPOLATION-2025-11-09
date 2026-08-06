#!/usr/bin/env python3
"""Convert a PNEZD silt-fence stake TXT into Trimble-stakeable DXF linework.

Input format per line:
  Point,Northing,Easting,Elevation,Description

Runs are split at descriptions containing END (including SILT END/DITCH CHECK).
"""

from __future__ import annotations

import argparse
import math
from pathlib import Path

import ezdxf
from ezdxf.enums import TextEntityAlignment


def parse_pnezd(path: Path) -> list[dict]:
    rows: list[dict] = []
    for line in path.read_text().splitlines():
        parts = line.strip().split(",")
        if len(parts) < 5:
            continue
        rows.append(
            {
                "pt": parts[0],
                "n": float(parts[1]),
                "e": float(parts[2]),
                "z": float(parts[3]),
                "d": parts[4].strip(),
            }
        )
    return rows


def split_runs(rows: list[dict]) -> list[list[dict]]:
    runs: list[list[dict]] = []
    cur: list[dict] = []
    for row in rows:
        cur.append(row)
        if "END" in row["d"].upper():
            runs.append(cur)
            cur = []
    if cur:
        runs.append(cur)
    return runs


def write_dxf(rows: list[dict], out: Path, *, labels: bool) -> dict:
    runs = [run for run in split_runs(rows) if len(run) >= 2]
    doc = ezdxf.new("R2010")
    doc.header["$INSUNITS"] = 2
    doc.header["$MEASUREMENT"] = 0
    msp = doc.modelspace()
    for name, color in (
        ("SILT_FENCE", 3),
        ("SILT_FENCE_POINTS", 2),
        ("SILT_FENCE_ENDS", 1),
        ("SILT_FENCE_LABELS", 7),
    ):
        if name == "SILT_FENCE_LABELS" and not labels:
            continue
        doc.layers.add(name, color=color)

    total_len = 0.0
    for run in runs:
        xy = [(r["e"], r["n"]) for r in run]
        msp.add_lwpolyline(xy, dxfattribs={"layer": "SILT_FENCE"})
        for a, b in zip(run, run[1:]):
            total_len += math.hypot(a["e"] - b["e"], a["n"] - b["n"])

    for row in rows:
        layer = "SILT_FENCE_ENDS" if "END" in row["d"].upper() else "SILT_FENCE_POINTS"
        msp.add_point((row["e"], row["n"], row["z"]), dxfattribs={"layer": layer})
        if labels:
            msp.add_text(
                row["pt"],
                dxfattribs={"layer": "SILT_FENCE_LABELS", "height": 3.0},
            ).set_placement(
                (row["e"] + 3.0, row["n"] + 3.0),
                align=TextEntityAlignment.LEFT,
            )

    out.parent.mkdir(parents=True, exist_ok=True)
    doc.saveas(str(out))
    return {
        "points": len(rows),
        "polylines": len(runs),
        "length_ft": total_len,
        "e_range": (min(r["e"] for r in rows), max(r["e"] for r in rows)),
        "n_range": (min(r["n"] for r in rows), max(r["n"] for r in rows)),
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("txt", type=Path)
    p.add_argument("-o", "--output", type=Path, required=True)
    p.add_argument("--labels", action="store_true", help="Include point-number text")
    args = p.parse_args(argv)

    rows = parse_pnezd(args.txt)
    if not rows:
        raise SystemExit(f"No PNEZD rows in {args.txt}")
    stats = write_dxf(rows, args.output, labels=args.labels)
    print(f"Wrote {args.output}")
    print(
        f"Points={stats['points']}  polylines={stats['polylines']}  "
        f"length={stats['length_ft']:.1f} ft"
    )
    print(
        f"E {stats['e_range'][0]:.3f}..{stats['e_range'][1]:.3f}  "
        f"N {stats['n_range'][0]:.3f}..{stats['n_range'][1]:.3f}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
