"""Tests for Trimble Access DXF normalization and API."""

from __future__ import annotations

from pathlib import Path

import ezdxf
import pytest
from fastapi.testclient import TestClient

from app.converter import convert_for_trimble
from app.main import app
from app.normalize import normalize_dxf


@pytest.fixture()
def sample_dxf(tmp_path: Path) -> Path:
    path = tmp_path / "design.dxf"
    doc = ezdxf.new("R2010")
    msp = doc.modelspace()
    doc.layers.add("CL")
    doc.layers.add("EOP")
    doc.layers.add("NOTES")
    msp.add_lwpolyline([(0, 0), (100, 0), (100, 50)], dxfattribs={"layer": "CL"})
    msp.add_line((0, 10), (100, 10), dxfattribs={"layer": "EOP"})
    msp.add_arc(center=(50, 50), radius=20, start_angle=0, end_angle=90, dxfattribs={"layer": "EOP"})
    msp.add_point((0, 0), dxfattribs={"layer": "CL"})
    msp.add_circle((80, 20), radius=2, dxfattribs={"layer": "EOP"})
    msp.add_text("STA 1+00", dxfattribs={"layer": "NOTES", "height": 2}).set_placement((5, 5))
    hatch = msp.add_hatch(dxfattribs={"layer": "NOTES"})
    hatch.paths.add_polyline_path([(0, 0), (10, 0), (10, 10), (0, 10)])
    doc.saveas(path)
    return path


def test_normalize_keeps_stakeable_only(sample_dxf: Path, tmp_path: Path) -> None:
    out = tmp_path / "out.dxf"
    result = normalize_dxf(str(sample_dxf), str(out), include_display_only=False)
    assert result.stakeable_count == 5  # lwpoly, line, arc, point, circle
    assert out.exists()
    doc = ezdxf.readfile(out)
    types = {e.dxftype() for e in doc.modelspace()}
    assert "TEXT" not in types
    assert "HATCH" not in types
    assert "LWPOLYLINE" in types
    assert "LINE" in types


def test_normalize_layer_filter(sample_dxf: Path, tmp_path: Path) -> None:
    out = tmp_path / "cl_only.dxf"
    result = normalize_dxf(str(sample_dxf), str(out), include_layers=["CL"])
    assert result.stakeable_count == 2  # lwpoly + point
    layers = {layer.name for layer in result.layers}
    assert layers == {"CL"}


def test_convert_pipeline_dxf(sample_dxf: Path, tmp_path: Path) -> None:
    out = tmp_path / "trimble.dxf"
    payload = convert_for_trimble(sample_dxf, out)
    assert payload["stakeable_count"] >= 5
    assert Path(out).exists()
    assert payload["dxf_version"] == "R2010"


def test_api_convert_and_download(sample_dxf: Path) -> None:
    client = TestClient(app)
    with sample_dxf.open("rb") as handle:
        response = client.post(
            "/api/convert",
            files={"file": ("design.dxf", handle, "application/dxf")},
            data={"dxf_version": "R2010", "explode_blocks": "true"},
        )
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["stakeable_count"] >= 5
    assert payload["job_id"]
    download = client.get(payload["download_url"])
    assert download.status_code == 200
    assert b"SECTION" in download.content
    assert b"ENTITIES" in download.content


def test_api_health() -> None:
    client = TestClient(app)
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_api_guide() -> None:
    client = TestClient(app)
    response = client.get("/api/guide")
    assert response.status_code == 200
    body = response.json()
    assert "LINE" in body["stakeable_entities"]
    assert body["civil3d_prep"]
    assert body["trimble_import"]


def test_dwg_conversion_smoke() -> None:
    sample = Path(__file__).resolve().parents[1] / "samples" / "Arc.dwg"
    if not sample.exists():
        pytest.skip("sample DWG not present")
    out = sample.with_name("Arc_trimble_access.dxf")
    try:
        payload = convert_for_trimble(sample, out)
        assert payload["engine"] == "ezdwg"
        assert payload["stakeable_count"] >= 1
        assert out.exists()
    finally:
        out.unlink(missing_ok=True)


def test_spline_conversion(tmp_path: Path) -> None:
    src = tmp_path / "spline.dxf"
    doc = ezdxf.new("R2010")
    msp = doc.modelspace()
    msp.add_spline([(0, 0), (10, 5), (20, 0), (30, 8)])
    doc.saveas(src)
    out = tmp_path / "spline_out.dxf"
    result = normalize_dxf(str(src), str(out), convert_splines=True)
    assert result.stakeable_count >= 1
    types = {e.dxftype() for e in ezdxf.readfile(out).modelspace()}
    assert "SPLINE" not in types
    assert "LWPOLYLINE" in types
