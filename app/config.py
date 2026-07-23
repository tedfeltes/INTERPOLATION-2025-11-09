from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "data" / "uploads"
OUTPUT_DIR = BASE_DIR / "data" / "outputs"
STATIC_DIR = BASE_DIR / "static"

# Trimble Access selectable (stakeable) DXF entities
TRIMBLE_STAKEABLE_TYPES = frozenset(
    {
        "ARC",
        "CIRCLE",
        "INSERT",
        "LINE",
        "POINT",
        "POLYLINE",
        "LWPOLYLINE",
    }
)

# Display-only in Trimble Access — kept only when user opts in
TRIMBLE_DISPLAY_ONLY_TYPES = frozenset(
    {
        "3DFACE",
        "SPLINE",
        "SOLID",
        "ATTRIB",
        "ATTDEF",
        "TEXT",
        "MTEXT",
        "HATCH",
    }
)

DEFAULT_DXF_VERSION = "R2010"
MAX_UPLOAD_BYTES = 200 * 1024 * 1024  # 200 MB

for path in (UPLOAD_DIR, OUTPUT_DIR, STATIC_DIR):
    path.mkdir(parents=True, exist_ok=True)
