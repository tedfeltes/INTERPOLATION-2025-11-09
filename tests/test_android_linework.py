"""Android-packaged recover_linework must explode Civil 3D proxies."""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

import ezdxf

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "mobile/stakedxf/android/app/src/main/python"))
sys.path.insert(0, str(ROOT / "tests"))

from proxy_fixture import write_proxy_fixture  # noqa: E402
import linework  # noqa: E402


def test_recover_linework_explodes_aec_proxy():
    with tempfile.TemporaryDirectory() as tmp:
        src = write_proxy_fixture(Path(tmp) / "proxy.dxf")
        out = Path(tmp) / "stake.dxf"
        result = linework.recover_linework(str(src), str(out))

        assert result["ok"] is True
        assert result["proxy_exploded"] == 1
        assert result["stakeable_count"] == 6
        assert result["proxy_primitives"] == 6
        assert "layers_json" in result
        assert result["layers"]
        assert all(row["entity_count"] > 0 for row in result["layers"])

        doc = ezdxf.readfile(out)
        types = {e.dxftype() for e in doc.modelspace()}
        assert "ACAD_PROXY_ENTITY" not in types
        assert types & {"POLYLINE", "ARC", "LINE", "LWPOLYLINE"}


def test_recover_linework_omits_empty_layers():
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "mixed.dxf"
        doc = ezdxf.new("R2010")
        doc.layers.add("USED")
        doc.layers.add("EMPTY_A")
        doc.layers.add("EMPTY_B")
        msp = doc.modelspace()
        msp.add_line((0, 0), (10, 0), dxfattribs={"layer": "USED"})
        msp.add_circle((5, 5), 1.0, dxfattribs={"layer": "USED"})
        doc.saveas(path)

        out = Path(tmp) / "out.dxf"
        result = linework.recover_linework(str(path), str(out))
        assert result["ok"] is True
        names = {row["name"] for row in result["layers"]}
        assert "USED" in names
        assert "EMPTY_A" not in names
        assert "EMPTY_B" not in names

        out_doc = ezdxf.readfile(out)
        table_names = {layer.dxf.name for layer in out_doc.layers}
        assert "EMPTY_A" not in table_names
        assert "EMPTY_B" not in table_names


def test_safe_helpers_tolerate_string_entries():
    """The ``_safe_*`` helpers must return None instead of crashing on ``str``.

    Civil 3D DWGs occasionally round-trip through LibreDWG with malformed
    entries whose Python type is ``str``. Historically that surfaced as
    ``AttributeError: 'str' object has no attribute 'dxf'`` and aborted the
    whole conversion (frame 23 of the field bug-report screen recording).
    The helpers must degrade gracefully so those entries can be skipped.
    """
    from linework import _safe_dxftype, _safe_layer

    class _RealEntity:
        class _NS:
            layer = "REAL"

        dxf = _NS()

        def dxftype(self) -> str:  # pragma: no cover - simple test double
            return "LINE"

    real = _RealEntity()
    assert _safe_dxftype(real) == "LINE"
    assert _safe_layer(real) == "REAL"

    # A bare string used to blow up with AttributeError:
    #   'str' object has no attribute 'dxf'
    assert _safe_dxftype("phantom-entity") is None
    assert _safe_layer("phantom-entity") is None
    assert _safe_dxftype(None) is None
    assert _safe_layer(None) is None


def test_filter_layers_keeps_only_selected():
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "layers.dxf"
        doc = ezdxf.new("R2010")
        doc.layers.add("CURB")
        doc.layers.add("STM")
        doc.layers.add("NOISE")
        msp = doc.modelspace()
        msp.add_line((0, 0), (5, 0), dxfattribs={"layer": "CURB"})
        msp.add_lwpolyline([(0, 1), (5, 1)], dxfattribs={"layer": "STM"})
        msp.add_circle((0, 0), 2, dxfattribs={"layer": "NOISE"})
        doc.saveas(path)

        out = Path(tmp) / "filtered.dxf"
        result = linework.filter_layers(
            str(path), str(out), '["CURB", "STM"]'
        )
        assert result["ok"] is True
        assert result["stakeable_count"] == 2
        names = {row["name"] for row in result["layers"]}
        assert names == {"CURB", "STM"}

        out_doc = ezdxf.readfile(out)
        layers = {e.dxf.layer for e in out_doc.modelspace()}
        assert layers == {"CURB", "STM"}
        table = {layer.dxf.name for layer in out_doc.layers}
        assert "NOISE" not in table
