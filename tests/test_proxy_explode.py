"""Tests for Civil 3D proxy-graphics explosion (no AutoCAD)."""

from __future__ import annotations

from pathlib import Path

import ezdxf
import pytest
from fastapi.testclient import TestClient

from app.converter import convert_for_trimble, resolve_source_path
from app.engines import available_engines, dwg_to_dxf_best_effort
from app.main import app
from app.normalize import normalize_dxf
from app.proxy_explode import explode_proxy_graphics
from tests.proxy_fixture import write_proxy_fixture


@pytest.fixture()
def proxy_dxf(tmp_path: Path) -> Path:
    return write_proxy_fixture(tmp_path / "aec_proxy.dxf")


def test_proxy_virtual_entities_exist(proxy_dxf: Path) -> None:
    doc = ezdxf.readfile(proxy_dxf)
    proxies = [e for e in doc.modelspace() if e.dxftype() == "ACAD_PROXY_ENTITY"]
    assert len(proxies) == 1
    types = [e.dxftype() for e in proxies[0].virtual_entities()]
    assert types  # recovered geometry
    assert set(types) <= {"POLYLINE", "ARC", "LINE", "LWPOLYLINE", "CIRCLE", "POINT"}


def test_explode_proxy_graphics(proxy_dxf: Path) -> None:
    doc = ezdxf.readfile(proxy_dxf)
    stats = explode_proxy_graphics(doc)
    assert stats.carriers_exploded == 1
    assert stats.primitives_created >= 1
    remaining = [e.dxftype() for e in doc.modelspace()]
    assert "ACAD_PROXY_ENTITY" not in remaining
    assert any(t in remaining for t in ("POLYLINE", "ARC", "LWPOLYLINE", "LINE"))


def test_normalize_recovers_proxy_as_stakeable(proxy_dxf: Path, tmp_path: Path) -> None:
    out = tmp_path / "proxy_out.dxf"
    result = normalize_dxf(str(proxy_dxf), str(out), explode_proxies=True)
    assert result.proxy_carriers_exploded == 1
    assert result.stakeable_count >= 1
    types = {e.dxftype() for e in ezdxf.readfile(out).modelspace()}
    assert "ACAD_PROXY_ENTITY" not in types


def test_convert_path_network_style(proxy_dxf: Path, tmp_path: Path) -> None:
    out = tmp_path / "from_share.dxf"
    resolved = resolve_source_path(str(proxy_dxf))
    payload = convert_for_trimble(resolved, out)
    assert payload["stakeable_count"] >= 1
    assert payload["proxy_carriers_exploded"] == 1


def test_api_convert_path(proxy_dxf: Path) -> None:
    client = TestClient(app)
    response = client.post(
        "/api/convert-path",
        json={"path": str(proxy_dxf), "dxf_version": "R2010", "explode_proxies": True},
    )
    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload["stakeable_count"] >= 1
    assert payload["proxy_carriers_exploded"] == 1
    download = client.get(payload["download_url"])
    assert download.status_code == 200


def test_api_convert_path_missing() -> None:
    client = TestClient(app)
    response = client.post(
        "/api/convert-path",
        json={"path": "/no/such/file.dwg"},
    )
    assert response.status_code == 404


def test_dwg_engine_libredwg_or_ezdwg() -> None:
    sample = Path(__file__).resolve().parents[1] / "samples" / "Line.dwg"
    if not sample.exists():
        pytest.skip("sample DWG missing")
    engines = available_engines()
    assert engines["ezdwg"] is True
    out = sample.with_name("Line_engine_test.dxf")
    try:
        name = dwg_to_dxf_best_effort(sample, out, prefer="libredwg")
        assert name in {"libredwg", "ezdwg", "oda"}
        assert out.exists() and out.stat().st_size > 0
    finally:
        out.unlink(missing_ok=True)


def test_health_lists_engines() -> None:
    client = TestClient(app)
    response = client.get("/api/health")
    assert response.status_code == 200
    body = response.json()
    assert "engines" in body
    assert body["engines"]["ezdwg"] is True


def test_guide_mentions_no_autocad() -> None:
    client = TestClient(app)
    body = client.get("/api/guide").json()
    assert body["no_autocad_field_workflow"]
    assert any("PROXYGRAPHICS" in note for note in body["notes"])
