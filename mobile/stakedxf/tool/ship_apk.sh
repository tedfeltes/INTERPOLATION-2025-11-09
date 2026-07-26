#!/usr/bin/env bash
# Build release APK and copy to dist/ as "Staking Plot vX.Y.Z.apk".
set -euo pipefail
APP="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$APP/../.." && pwd)"
DIST="$ROOT/dist"
VERSION="$(python3 - <<PY
import re
from pathlib import Path
text = Path("$APP/pubspec.yaml").read_text()
m = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', text, re.M)
print(m.group(1) if m else '0.0.0')
PY
)"
cd "$APP"
flutter build apk --release
NAME="Staking Plot v${VERSION}.apk"
mkdir -p "$DIST"
cp -f build/app/outputs/flutter-apk/app-release.apk "$DIST/$NAME"
# Keep legacy filename as a copy for older install docs during transition.
cp -f "$DIST/$NAME" "$DIST/StakeDXF-tsc5.apk"
ls -lh "$DIST/$NAME" "$DIST/StakeDXF-tsc5.apk"
echo "Shipped: dist/$NAME"
