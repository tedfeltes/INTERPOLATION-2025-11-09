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

        doc = ezdxf.readfile(out)
        types = {e.dxftype() for e in doc.modelspace()}
        assert "ACAD_PROXY_ENTITY" not in types
        assert types & {"POLYLINE", "ARC", "LINE", "LWPOLYLINE"}
