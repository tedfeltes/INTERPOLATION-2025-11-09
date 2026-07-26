"""Tests for phone/OneDrive/TSC5 cloud field endpoints."""

from __future__ import annotations

from pathlib import Path

import pytest
from fastapi.testclient import TestClient

import app.config as config
from app.main import app
from tests.proxy_fixture import write_proxy_fixture


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture()
def proxy_dxf(tmp_path: Path) -> Path:
    return write_proxy_fixture(tmp_path / "field.dxf")


def test_convert_file_returns_dxf_bytes(client: TestClient, proxy_dxf: Path) -> None:
    with proxy_dxf.open("rb") as handle:
        response = client.post(
            "/api/convert-file",
            files={"file": ("field.dxf", handle, "application/dxf")},
            data={"explode_proxies": "true", "dxf_version": "R2010"},
        )
    assert response.status_code == 200, response.text
    assert b"SECTION" in response.content
    assert b"ENTITIES" in response.content
    assert "attachment" in response.headers.get("content-disposition", "").lower()
    assert int(response.headers.get("X-StakeDXF-Stakeable-Count", "0")) >= 1


def test_convert_file_api_key_enforced(client: TestClient, proxy_dxf: Path, monkeypatch) -> None:
    monkeypatch.setattr(config, "API_KEY", "secret-field-key")
    # main imported API_KEY at module load — patch app.main.API_KEY too
    import app.main as main

    monkeypatch.setattr(main, "API_KEY", "secret-field-key")

    with proxy_dxf.open("rb") as handle:
        denied = client.post(
            "/api/convert-file",
            files={"file": ("field.dxf", handle, "application/dxf")},
        )
    assert denied.status_code == 401

    with proxy_dxf.open("rb") as handle:
        ok = client.post(
            "/api/convert-file",
            files={"file": ("field.dxf", handle, "application/dxf")},
            headers={"X-API-Key": "secret-field-key"},
        )
    assert ok.status_code == 200
    assert b"ENTITIES" in ok.content


def test_guide_is_phone_tsc5_onedrive(client: TestClient) -> None:
    body = client.get("/api/guide").json()
    assert "iPhone" in body["devices"]
    assert any("TSC5" in d for d in body["devices"])
    assert body["iphone_steps"]
    assert body["tsc5_steps"]
    assert body["power_automate"]["http_action"].endswith("/api/convert-file")


def test_health_cloud_mode(client: TestClient) -> None:
    body = client.get("/api/health").json()
    assert body["mode"] == "cloud-field-kit"


def test_manifest_available(client: TestClient) -> None:
    response = client.get("/manifest.webmanifest")
    assert response.status_code == 200
    assert "StakeDXF" in response.text
