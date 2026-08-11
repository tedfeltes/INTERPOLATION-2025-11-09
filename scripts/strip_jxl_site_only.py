#!/usr/bin/env python3
"""Strip a Trimble Access JobXML (.jxl) down to CRS / local-site data only.

Removes all PointRecord / Reductions Point data while keeping the FieldBook
coordinate-system history and Environment/CoordinateSystem (including site
calibration adjustments) so Trimble Access can create a new job on the same
local site.
"""
from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ALWAYS_KEEP = {
    "HorizontalAdjustmentRecord",
    "VerticalAdjustmentRecord",
    "EllipsoidRecord",
    "ProjectionRecord",
    "DatumRecord",
    "CoordinateSystemRecord",
    "DisplacementModelsRecord",
    "KinematicTransformationsRecord",
    "ReferenceFrameTransformationsRecord",
}

FIRST_ONLY = {
    "JobPropertiesRecord",
    "LinkedFilesRecord",
    "UnitsRecord",
    "FeatureCodingRecord",
    "CorrectionsRecord",
    "ActiveMapFilesRecord",
}

RECORD_OPEN = re.compile(r"^        <([A-Za-z][A-Za-z0-9]*)\b")


def is_effectively_empty(block: str, tag: str) -> bool:
    s = block.strip()
    if s.endswith("/>"):
        return True
    inner = re.sub(rf"^<{tag}\b[^>]*>", "", s, count=1, flags=re.S)
    inner = re.sub(rf"</{tag}>\s*$", "", inner, flags=re.S)
    return not re.search(r"<[^/!][^>]*>[^<\s]", inner)


def strip_jxl(src: Path, dst: Path) -> dict:
    header_lines: list[str] = []
    out_fb: list[str] = []
    timezone_blocks: list[str] = []
    env_lines: list[str] = []

    kept_counts: dict[str, int] = {}
    seen_first: set[str] = set()
    skipped_points = 0
    skipped_other = 0

    section = "header"
    capture_tag: str | None = None
    capture_buf: list[str] = []
    in_exported_files = False
    skip_pairs = False

    with src.open("r", encoding="utf-8", errors="replace", newline="") as f:
        for line in f:
            if section == "header":
                header_lines.append(line)
                if "<FieldBook>" in line:
                    section = "fieldbook"
                continue

            if section == "fieldbook":
                if "</FieldBook>" in line:
                    if capture_tag:
                        raise RuntimeError(f"Unclosed {capture_tag} at FieldBook end")
                    section = "after_fb"
                    continue

                if capture_tag is None:
                    m = RECORD_OPEN.match(line)
                    if not m:
                        continue
                    tag = m.group(1)
                    if line.strip().endswith("/>"):
                        tag_done, block_done = tag, line
                    else:
                        capture_tag = tag
                        capture_buf = [line]
                        continue
                else:
                    capture_buf.append(line)
                    if f"</{capture_tag}>" not in line:
                        continue
                    tag_done = capture_tag
                    block_done = "".join(capture_buf)
                    capture_tag = None
                    capture_buf = []

                tag, block = tag_done, block_done

                if tag == "PointRecord":
                    skipped_points += 1
                    continue

                if tag == "TimeZoneRecord":
                    timezone_blocks.append(block)
                    continue

                if tag in ALWAYS_KEEP:
                    out_fb.append(block if block.endswith(("\n", "\r\n")) else block + "\r\n")
                    kept_counts[tag] = kept_counts.get(tag, 0) + 1
                    continue

                if tag in FIRST_ONLY:
                    if tag in seen_first:
                        skipped_other += 1
                        continue
                    if tag in {"ActiveMapFilesRecord", "LinkedFilesRecord"} and not is_effectively_empty(
                        block, tag
                    ):
                        skipped_other += 1
                        continue
                    seen_first.add(tag)
                    out_fb.append(block if block.endswith(("\n", "\r\n")) else block + "\r\n")
                    kept_counts[tag] = kept_counts.get(tag, 0) + 1
                    continue

                skipped_other += 1
                continue

            if section == "after_fb":
                if "<Environment>" in line:
                    env_lines.append(line)
                    section = "environment"
                continue

            if section == "environment":
                if "<ExportedFiles>" in line:
                    in_exported_files = True
                    env_lines.append(line)
                    continue
                if in_exported_files:
                    if "</ExportedFiles>" in line:
                        in_exported_files = False
                        env_lines.append(line)
                    continue
                if "<CalibrationPointPairs>" in line:
                    skip_pairs = True
                    continue
                if skip_pairs:
                    if "</CalibrationPointPairs>" in line:
                        skip_pairs = False
                    continue
                env_lines.append(line)
                if "</Environment>" in line:
                    section = "done"
                continue

    chosen_tz = None
    for block in timezone_blocks:
        if "<ZoneName>CDT</ZoneName>" in block or "<HoursToUTC>5</HoursToUTC>" in block:
            chosen_tz = block
            break
    if chosen_tz is None and timezone_blocks:
        chosen_tz = timezone_blocks[-1]
    if chosen_tz is not None:
        out_fb.append(chosen_tz if chosen_tz.endswith(("\n", "\r\n")) else chosen_tz + "\r\n")
        kept_counts["TimeZoneRecord"] = 1

    parts: list[str] = []
    parts.extend(header_lines)
    for block in out_fb:
        parts.append("\r\n")
        parts.append(block if block.endswith(("\n", "\r\n")) else block + "\r\n")
    parts.append("    </FieldBook>\r\n")
    parts.append("\r\n")
    parts.append("    <Reductions>\r\n")
    parts.append("    </Reductions>\r\n")
    parts.append("\r\n")
    parts.extend(env_lines)
    parts.append("</JOBFile>\r\n")

    text = "".join(parts)
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(text.encode("utf-8"))
    ET.parse(dst)

    return {
        "bytes": dst.stat().st_size,
        "point_records_removed": skipped_points,
        "other_records_removed": skipped_other,
        "kept": kept_counts,
        "has_coordinate_system": "<CoordinateSystem>" in text,
        "has_local_site": "<LocalSite>" in text,
        "point_elements": len(re.findall(r"<Point\b", text)),
    }


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("input_jxl", type=Path, help="Source .jxl / JobXML file")
    p.add_argument(
        "-o",
        "--output",
        type=Path,
        required=True,
        help="Destination site-only .jxl path",
    )
    args = p.parse_args(argv)

    if not args.input_jxl.is_file():
        print(f"Input not found: {args.input_jxl}", file=sys.stderr)
        return 1

    stats = strip_jxl(args.input_jxl, args.output)
    print(f"Wrote {args.output} ({stats['bytes']} bytes)")
    print(f"Removed PointRecords: {stats['point_records_removed']}")
    print(f"Removed other FieldBook records: {stats['other_records_removed']}")
    print(f"Remaining <Point> elements: {stats['point_elements']}")
    print("Kept FieldBook records:")
    for name, count in sorted(stats["kept"].items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  {count:5d} {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
