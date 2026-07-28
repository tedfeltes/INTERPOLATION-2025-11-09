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


def test_proxy_graphic_tolerates_corrupt_layer_table():
    """ProxyGraphic must not abort when doc.layers yields a bare str.

    This is the deeper Olde Highlander failure mode: even with ``_safe_*``
    helpers, ezdxf's ProxyGraphic.__init__ does ``layer.dxf.name for layer
    in doc.layers`` and historically raised AttributeError out of
    ``entity.virtual_entities()``. Our import-time patch retries without a
    document binding so geometry still explodes.
    """
    from ezdxf.proxygraphic import ProxyGraphic

    with tempfile.TemporaryDirectory() as tmp:
        src = write_proxy_fixture(Path(tmp) / "proxy.dxf")
        doc = ezdxf.readfile(src)
        ent = next(iter(doc.modelspace()))
        graphic = ent.proxy_graphic
        assert graphic

        real_layers = doc.tables.layers

        class _CorruptLayers:
            def __iter__(self):
                yield "CORRUPT_LAYER_STRING"
                yield from real_layers

            def __contains__(self, name):
                return name in real_layers

            def __getattr__(self, name):
                return getattr(real_layers, name)

        doc.tables.layers = _CorruptLayers()  # type: ignore[assignment]

        # Must not raise AttributeError: 'str' object has no attribute 'dxf'
        virt = list(ProxyGraphic(graphic, doc).virtual_entities())
        assert len(virt) == 6
        assert {v.dxftype() for v in virt} & {"POLYLINE", "ARC"}


def test_recover_survives_corrupt_layers_and_never_raises():
    """Full recover_linework must return a dict even when tables are hostile."""
    with tempfile.TemporaryDirectory() as tmp:
        src = write_proxy_fixture(Path(tmp) / "proxy.dxf")
        out = Path(tmp) / "out.dxf"

        real_read = ezdxf.readfile

        def _read_with_corrupt_layers(path):
            d = real_read(path)
            real = d.tables.layers

            class _CorruptLayers:
                def __iter__(self):
                    yield "bad-layer"
                    yield from real

                def __contains__(self, name):
                    return name in real

                def __getattr__(self, name):
                    return getattr(real, name)

                def remove(self, name):
                    return real.remove(name)

            d.tables.layers = _CorruptLayers()  # type: ignore[assignment]
            return d

        # Patch both ezdxf.readfile and linework's loader path.
        import linework as lw

        orig_load = lw._load_dxf
        lw._load_dxf = lambda p: _read_with_corrupt_layers(p)
        try:
            result = lw.recover_linework(str(src), str(out))
        finally:
            lw._load_dxf = orig_load

        assert isinstance(result, dict)
        assert "ok" in result
        assert result["ok"] is True
        assert result["stakeable_count"] == 6
        assert result["proxy_exploded"] == 1


def test_recover_linework_never_raises_on_missing_file():
    """Kotlin relies on a returned map — exceptions become recover_failed."""
    result = linework.recover_linework(
        "/tmp/definitely-missing-stakedxf.dxf",
        "/tmp/definitely-missing-stakedxf-out.dxf",
    )
    assert isinstance(result, dict)
    assert result["ok"] is False
    assert "Recovery failed" in result["message"]
    assert result["stakeable_count"] == 0


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
