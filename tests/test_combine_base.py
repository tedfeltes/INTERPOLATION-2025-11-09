"""Base drawing combiner — merge project DXFs, keep only layers with data."""

from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

import ezdxf

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "mobile/stakedxf/android/app/src/main/python"))
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT))

import linework  # noqa: E402
from app.combine import combine_for_base  # noqa: E402


def _write_layered(path: Path, layer: str, x0: float) -> Path:
    doc = ezdxf.new("R2010")
    doc.layers.add(layer)
    doc.layers.add("EMPTY_UNUSED")
    msp = doc.modelspace()
    msp.add_line((x0, 0), (x0 + 10, 0), dxfattribs={"layer": layer})
    msp.add_circle((x0 + 5, 5), 1.0, dxfattribs={"layer": layer})
    doc.saveas(path)
    return path


def test_combine_base_drawings_merges_and_purges_empty_layers():
    with tempfile.TemporaryDirectory() as tmp:
        a = _write_layered(Path(tmp) / "a.dxf", "CURB", 0)
        b = _write_layered(Path(tmp) / "b.dxf", "STM", 20)
        out = Path(tmp) / "base.dxf"

        result = linework.combine_base_drawings(
            json.dumps([str(a), str(b)]),
            str(out),
        )
        assert result["ok"] is True
        assert result["stakeable_count"] == 4
        assert result["source_count"] == 2
        assert result["sources_merged"] == 2
        names = {row["name"] for row in result["layers"]}
        assert names == {"CURB", "STM"}
        assert "EMPTY_UNUSED" not in names

        doc = ezdxf.readfile(out)
        table = {layer.dxf.name for layer in doc.layers}
        assert "EMPTY_UNUSED" not in table
        assert {e.dxf.layer for e in doc.modelspace()} == {"CURB", "STM"}


def test_combine_base_requires_two_files():
    with tempfile.TemporaryDirectory() as tmp:
        a = _write_layered(Path(tmp) / "a.dxf", "CURB", 0)
        out = Path(tmp) / "base.dxf"
        result = linework.combine_base_drawings(json.dumps([str(a)]), str(out))
        assert result["ok"] is False
        assert "at least two" in result["message"].lower()


def test_combine_base_never_raises_on_bad_json():
    result = linework.combine_base_drawings("not-json", "/tmp/nope_base.dxf")
    assert isinstance(result, dict)
    assert result["ok"] is False


def test_desktop_combine_for_base():
    with tempfile.TemporaryDirectory() as tmp:
        a = _write_layered(Path(tmp) / "a.dxf", "WATER", 0)
        b = _write_layered(Path(tmp) / "b.dxf", "SEWER", 30)
        out = Path(tmp) / "desktop_base.dxf"
        payload = combine_for_base([a, b], out)
        assert payload["ok"] is True
        assert payload["stakeable_count"] == 4
        names = {row["name"] for row in payload["layers"]}
        assert names == {"WATER", "SEWER"}
        assert out.is_file()
