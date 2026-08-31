"""Static checks and math specs for civil3d/ZHOVER.lsp."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

LSP_PATH = Path(__file__).resolve().parents[1] / "civil3d" / "ZHOVER.lsp"


def _strip_lisp(source: str) -> str:
    """Remove AutoLISP comments and strings so paren counts are meaningful."""
    out: list[str] = []
    i = 0
    n = len(source)
    while i < n:
        if source.startswith(";|", i):
            end = source.find("|;", i + 2)
            if end < 0:
                raise AssertionError("Unterminated block comment")
            i = end + 2
            continue
        if source[i] == ";":
            while i < n and source[i] != "\n":
                i += 1
            continue
        if source[i] == '"':
            i += 1
            while i < n:
                if source[i] == "\\":
                    i += 2
                    continue
                if source[i] == '"':
                    i += 1
                    break
                i += 1
            else:
                raise AssertionError("Unterminated string")
            out.append('"_"')
            continue
        out.append(source[i])
        i += 1
    return "".join(out)


def _defun_names(stripped: str) -> list[str]:
    return re.findall(r"\(\s*defun\s+([^\s(/]+)", stripped)


@pytest.fixture(scope="module")
def lsp_text() -> str:
    return LSP_PATH.read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def stripped(lsp_text: str) -> str:
    return _strip_lisp(lsp_text)


def test_lisp_is_ascii(lsp_text: str) -> None:
    """Older APPLOAD encodings choke on Unicode punctuation in .lsp files."""
    assert lsp_text.encode("ascii")


def test_balanced_parentheses(stripped: str) -> None:
    depth = 0
    min_depth = 0
    for ch in stripped:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            min_depth = min(min_depth, depth)
    assert min_depth >= 0, "A closing parenthesis appears before its match"
    assert depth == 0, f"Unbalanced parentheses (open-close={depth})"


def test_commands_and_alias(stripped: str) -> None:
    names = set(_defun_names(stripped))
    assert "c:zhover" in names
    assert "c:zh" in names
    assert "zhover--bary-z" in names
    assert "zhover--at-cursor" in names
    assert "zhover--show" in names
    assert "zhover--cleanup" in names
    assert "zhover--box-corners" in names
    assert "zhover--make-box" in names


def test_hover_loop_and_magenta(lsp_text: str) -> None:
    assert "(list T 15 0)" in lsp_text
    assert "grread" in lsp_text
    assert "grtext -2 6" not in lsp_text
    assert "(list -1 (strcat" in lsp_text
    assert "'(62 . 6)" in lsp_text
    assert "'(62 . 253)" in lsp_text
    assert '"SOLID"' in lsp_text
    assert "FILLMODE" in lsp_text
    assert "0.011" in lsp_text
    assert "nentselp" in lsp_text
    assert "FindElevationAtXY" in lsp_text
    assert "vlax-curve-getClosestPointTo" in lsp_text
    assert "vlax-curve-getClosestPointToProjection" in lsp_text
    assert "AECC_COGO_POINT" in lsp_text
    assert "3DFACE" in lsp_text


def test_no_versioned_aecc_application(stripped: str) -> None:
    assert "AeccApplication" not in stripped
    assert "AeccXUiLand" not in stripped


def test_error_handler_cleans_up(lsp_text: str) -> None:
    assert "*error*" in lsp_text
    assert "zhover--cleanup" in lsp_text
    assert "zhover--erase-label" in lsp_text
    assert "Esc" in lsp_text


def test_label_sits_next_to_cursor(lsp_text: str) -> None:
    assert "* h 1.25" in lsp_text
    assert "* h 0.45" in lsp_text
    assert "VIEWSIZE" in lsp_text
    assert 'strcat "Z = "' in lsp_text


def barycentric_z(
    a: tuple[float, float, float],
    b: tuple[float, float, float],
    c: tuple[float, float, float],
    p: tuple[float, float],
) -> float | None:
    """Same XY barycentric interpolation as zhover--bary-z."""
    v0x, v0y = b[0] - a[0], b[1] - a[1]
    v1x, v1y = c[0] - a[0], c[1] - a[1]
    v2x, v2y = p[0] - a[0], p[1] - a[1]
    d00 = v0x * v0x + v0y * v0y
    d01 = v0x * v1x + v0y * v1y
    d11 = v1x * v1x + v1y * v1y
    d02 = v0x * v2x + v0y * v2y
    d12 = v1x * v2x + v1y * v2y
    den = d00 * d11 - d01 * d01
    if abs(den) <= 1e-12:
        return None
    u = (d11 * d02 - d01 * d12) / den
    v = (d00 * d12 - d01 * d02) / den
    w = 1.0 - u - v
    if u >= -1e-6 and v >= -1e-6 and w >= -1e-6:
        return w * a[2] + u * b[2] + v * c[2]
    return None


def z_on_segment_xy(
    a: tuple[float, float, float],
    b: tuple[float, float, float],
    p: tuple[float, float],
) -> float:
    """Plan-view interpolation used by getClosestPointToProjection along a line."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    length2 = dx * dx + dy * dy
    if length2 == 0:
        return a[2]
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / length2
    t = max(0.0, min(1.0, t))
    return a[2] + t * (b[2] - a[2])


def test_face_centroid_is_average_z() -> None:
    a, b, c = (0.0, 0.0, 10.0), (10.0, 0.0, 20.0), (0.0, 10.0, 30.0)
    z = barycentric_z(a, b, c, (10.0 / 3.0, 10.0 / 3.0))
    assert z == pytest.approx((10.0 + 20.0 + 30.0) / 3.0)


def test_face_vertex_returns_that_z() -> None:
    a, b, c = (0.0, 0.0, 12.5), (8.0, 0.0, 4.0), (0.0, 6.0, 9.0)
    assert barycentric_z(a, b, c, (0.0, 0.0)) == pytest.approx(12.5)
    assert barycentric_z(a, b, c, (8.0, 0.0)) == pytest.approx(4.0)
    assert barycentric_z(a, b, c, (0.0, 6.0)) == pytest.approx(9.0)


def test_face_outside_returns_none() -> None:
    a, b, c = (0.0, 0.0, 1.0), (1.0, 0.0, 2.0), (0.0, 1.0, 3.0)
    assert barycentric_z(a, b, c, (2.0, 2.0)) is None


def test_vertical_face_returns_none() -> None:
    a, b, c = (0.0, 0.0, 0.0), (0.0, 0.0, 10.0), (0.0, 1.0, 5.0)
    assert barycentric_z(a, b, c, (0.0, 0.5)) is None


def test_3d_line_midpoint_z() -> None:
    assert z_on_segment_xy((0.0, 0.0, 10.0), (10.0, 0.0, 20.0), (5.0, 0.0)) == pytest.approx(
        15.0
    )


def test_3d_line_off_axis_projects_in_plan() -> None:
    z = z_on_segment_xy((0.0, 0.0, 100.0), (100.0, 0.0, 200.0), (25.0, 50.0))
    assert z == pytest.approx(125.0)


def test_magenta_aci_is_six(lsp_text: str) -> None:
    """ACI 6 is magenta; the TEXT entity uses it."""
    assert "'(62 . 6)" in lsp_text
    assert "magenta" in lsp_text.lower()


def test_background_box_is_color_253(lsp_text: str) -> None:
    assert "'(62 . 253)" in lsp_text
    assert "zhover--make-box" in lsp_text
    assert "* h 0.18" in lsp_text


def padded_box(text_ll: tuple[float, float], text_ur: tuple[float, float], h: float) -> tuple[float, float, float, float]:
    """Same padding as zhover--box-corners."""
    pad = 0.18 * h
    return (
        text_ll[0] - pad,
        text_ll[1] - pad,
        text_ur[0] + pad,
        text_ur[1] + pad,
    )


def test_box_padding_is_tight_around_text() -> None:
    xmin, ymin, xmax, ymax = padded_box((-0.04, -0.12), (8.64, 1.12), 1.0)
    assert xmin == pytest.approx(-0.22)
    assert ymin == pytest.approx(-0.30)
    assert xmax == pytest.approx(8.82)
    assert ymax == pytest.approx(1.30)
    assert xmax - xmin > 8.64 + 0.04
    assert ymax - ymin > 1.12 + 0.12
