#!/usr/bin/env python3
"""Smoke test for DXF pattern generation."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GEN = ROOT / "drawings" / "generate_dxf.py"


def test_dxf_writes_and_has_entities() -> None:
    import ezdxf

    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "out.dxf"
        subprocess.check_call(
            [sys.executable, str(GEN), "--screw-spacing", "142", "-o", str(out)],
        )
        assert out.is_file() and out.stat().st_size > 500
        doc = ezdxf.readfile(out)
        msp = doc.modelspace()
        types = {e.dxftype() for e in msp}
        assert "LWPOLYLINE" in types
        assert "CIRCLE" in types
        assert "TEXT" in types


if __name__ == "__main__":
    test_dxf_writes_and_has_entities()
    print("ok")
