#!/usr/bin/env python3
"""Smoke tests for DXF / engineering drawing generation."""

from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DRAW = ROOT / "drawings"


def test_legacy_flat_dxf() -> None:
    import ezdxf

    gen = DRAW / "generate_dxf.py"
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "out.dxf"
        subprocess.check_call([sys.executable, str(gen), "--screw-spacing", "142", "-o", str(out)])
        assert out.is_file() and out.stat().st_size > 500
        doc = ezdxf.readfile(out)
        types = {e.dxftype() for e in doc.modelspace()}
        assert "LWPOLYLINE" in types and "CIRCLE" in types


def test_engineering_dxf_package() -> None:
    import ezdxf

    gen = DRAW / "generate_dxf_engineering.py"
    subprocess.check_call([sys.executable, str(gen)], cwd=str(DRAW))
    sheets = DRAW / "sheets"
    required = [
        "WSFG-IF_machine_interface.dxf",
        "WSFG-A1_funnel_body.dxf",
        "WSFG-B1_vblock_detail.dxf",
        "WSFG-C1_swing_arm.dxf",
        "WSFG-D1_link_jaw.dxf",
    ]
    for name in required:
        path = sheets / name
        assert path.is_file(), name
        doc = ezdxf.readfile(path)
        assert len(list(doc.modelspace())) >= 3


def test_engineering_png_sheets_exist() -> None:
    gen = DRAW / "generate_engineering_drawings.py"
    subprocess.check_call([sys.executable, str(gen)], cwd=str(DRAW))
    sheets = list((DRAW / "sheets").glob("WSFG-*.png"))
    assert len(sheets) >= 12


if __name__ == "__main__":
    test_legacy_flat_dxf()
    test_engineering_dxf_package()
    test_engineering_png_sheets_exist()
    print("ok")
