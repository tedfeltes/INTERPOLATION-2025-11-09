"""DWG → DXF engines that preserve Civil 3D proxy graphics when possible."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
from pathlib import Path

import ezdwg
import ezdxf

from .config import DEFAULT_DXF_VERSION, TRIMBLE_STAKEABLE_TYPES


STAKEABLE_TYPE_LIST = " ".join(
    sorted(TRIMBLE_STAKEABLE_TYPES | {"SPLINE", "ACAD_PROXY_ENTITY"})
)


def _which(name: str) -> str | None:
    return shutil.which(name)


def libre_dwg_available() -> bool:
    return bool(_which("dwg2dxf"))


def oda_available() -> bool:
    if _which("ODAFileConverter"):
        return True
    for candidate in (
        "/usr/bin/ODAFileConverter",
        "/usr/local/bin/ODAFileConverter",
        "/opt/oda/ODAFileConverter",
    ):
        if Path(candidate).exists():
            return True
    return False


def _dxf_entity_score(path: Path) -> int:
    """
    Score a decoded DXF for usefulness.

    Prefer files with stakeable entities and/or proxy carriers. Empty
    LibreDWG outputs (seen on some DWGs) score 0 and trigger fallback.
    """
    try:
        doc = ezdxf.readfile(str(path))
    except Exception:
        return -1
    score = 0
    for entity in doc.modelspace():
        etype = entity.dxftype().upper()
        if etype in TRIMBLE_STAKEABLE_TYPES:
            score += 10
        elif etype == "ACAD_PROXY_ENTITY":
            score += 50  # highly valuable for Civil 3D recovery
        elif getattr(entity, "proxy_graphic", None):
            score += 40
        else:
            score += 1
    return score


def convert_with_libredwg(source: Path, dest: Path, dxf_version: str) -> None:
    version_map = {
        "R12": "r12",
        "R2000": "r2000",
        "R2004": "r2004",
        "R2007": "r2007",
        "R2010": "r2010",
        "R2013": "r2013",
        "R2018": "r2018",
    }
    as_ver = version_map.get(dxf_version, "r2010")
    env = os.environ.copy()
    lib_path = "/usr/local/lib"
    env["LD_LIBRARY_PATH"] = f"{lib_path}:{env.get('LD_LIBRARY_PATH', '')}"

    cmd = [
        "dwg2dxf",
        "-y",
        "--as",
        as_ver,
        "-o",
        str(dest),
        str(source),
    ]
    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        env=env,
        timeout=300,
    )
    if result.returncode != 0 or not dest.exists() or dest.stat().st_size == 0:
        detail = (result.stderr or result.stdout or "unknown error").strip()
        raise RuntimeError(f"LibreDWG dwg2dxf failed: {detail}")


def convert_with_oda(source: Path, dest: Path, dxf_version: str) -> None:
    """Use ODA File Converter if installed (best proxy preservation)."""
    exe = _which("ODAFileConverter")
    for candidate in (
        "/usr/bin/ODAFileConverter",
        "/usr/local/bin/ODAFileConverter",
        "/opt/oda/ODAFileConverter",
    ):
        if not exe and Path(candidate).exists():
            exe = candidate
    if not exe:
        raise RuntimeError("ODA File Converter not found")

    version_map = {
        "R12": "ACAD12",
        "R2000": "ACAD2000",
        "R2004": "ACAD2004",
        "R2007": "ACAD2007",
        "R2010": "ACAD2010",
        "R2013": "ACAD2013",
        "R2018": "ACAD2018",
    }
    out_ver = version_map.get(dxf_version, "ACAD2010")

    with tempfile.TemporaryDirectory(prefix="oda_in_") as in_dir, tempfile.TemporaryDirectory(
        prefix="oda_out_"
    ) as out_dir:
        staged = Path(in_dir) / source.name
        shutil.copy2(source, staged)
        cmd = [exe, in_dir, out_dir, out_ver, "DXF", "0", "1"]
        if not os.environ.get("DISPLAY"):
            xvfb = _which("xvfb-run")
            if xvfb:
                cmd = [xvfb, "-a", *cmd]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        produced = list(Path(out_dir).glob("*.dxf")) + list(Path(out_dir).glob("*.DXF"))
        if result.returncode != 0 or not produced:
            detail = (result.stderr or result.stdout or "no output").strip()
            raise RuntimeError(f"ODA File Converter failed: {detail}")
        shutil.copy2(produced[0], dest)


def convert_with_ezdwg(
    source: Path,
    dest: Path,
    *,
    dxf_version: str,
    explode_blocks: bool,
) -> None:
    """
    ezdwg decode with unsupported/proxy carriers retained.

    First pass keeps stakeable + ACAD_PROXY_ENTITY; if empty, keep everything
    unsupported so the normalizer can explode proxy graphics.
    """
    result = ezdwg.to_dxf(
        str(source),
        str(dest),
        types=STAKEABLE_TYPE_LIST,
        dxf_version=dxf_version,
        modelspace_only=True,
        flatten_inserts=explode_blocks,
        include_unsupported=True,
        strict=False,
    )
    exported = getattr(result, "exported", None)
    if exported == 0 or not dest.exists() or dest.stat().st_size == 0:
        ezdwg.to_dxf(
            str(source),
            str(dest),
            dxf_version=dxf_version,
            modelspace_only=True,
            flatten_inserts=explode_blocks,
            include_unsupported=True,
            strict=False,
        )


def dwg_to_dxf_best_effort(
    source: Path,
    dest: Path,
    *,
    dxf_version: str = DEFAULT_DXF_VERSION,
    explode_blocks: bool = True,
    prefer: str | None = None,
) -> str:
    """
    Convert DWG → DXF trying engines and keeping the best-scoring result.

    Order defaults to ODA → LibreDWG → ezdwg, but empty/broken outputs are
    skipped so a weaker engine that actually yields geometry wins.
    """
    source = Path(source)
    dest = Path(dest)
    dest.parent.mkdir(parents=True, exist_ok=True)

    order = ["oda", "libredwg", "ezdwg"]
    if prefer and prefer in order:
        order.remove(prefer)
        order.insert(0, prefer)

    errors: list[str] = []
    best_engine: str | None = None
    best_score = -1
    best_path: Path | None = None

    for engine in order:
        candidate = dest.with_suffix(f".{engine}.tmp.dxf")
        try:
            if engine == "oda":
                if not oda_available():
                    continue
                convert_with_oda(source, candidate, dxf_version)
            elif engine == "libredwg":
                if not libre_dwg_available():
                    continue
                convert_with_libredwg(source, candidate, dxf_version)
            elif engine == "ezdwg":
                convert_with_ezdwg(
                    source,
                    candidate,
                    dxf_version=dxf_version,
                    explode_blocks=explode_blocks,
                )
            else:
                continue

            score = _dxf_entity_score(candidate)
            if score < 0:
                errors.append(f"{engine}: produced unreadable DXF")
                candidate.unlink(missing_ok=True)
                continue
            if score == 0:
                errors.append(f"{engine}: empty modelspace")
                candidate.unlink(missing_ok=True)
                continue
            if score > best_score:
                if best_path and best_path != candidate:
                    best_path.unlink(missing_ok=True)
                best_score = score
                best_engine = engine
                best_path = candidate
            else:
                candidate.unlink(missing_ok=True)
        except Exception as exc:
            errors.append(f"{engine}: {exc}")
            candidate.unlink(missing_ok=True)
            continue

    if best_engine and best_path:
        shutil.move(str(best_path), str(dest))
        return best_engine

    raise RuntimeError(
        "All DWG decoders failed or returned empty drawings. "
        + (" | ".join(errors) if errors else "No DWG decoder available.")
    )


def available_engines() -> dict[str, bool]:
    return {
        "oda": oda_available(),
        "libredwg": libre_dwg_available(),
        "ezdwg": True,
    }
