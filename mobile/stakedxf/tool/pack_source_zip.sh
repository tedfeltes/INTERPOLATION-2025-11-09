#!/usr/bin/env bash
# Pack a lean ground-up source zip for StakeDXF (+ iOS/Android build docs).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="$ROOT/mobile/stakedxf"
DIST="$ROOT/dist"
DOCS_SRC="$DIST/source_pack"

VERSION="$(python3 - <<PY
import re
from pathlib import Path
text = Path("$APP/pubspec.yaml").read_text()
m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)", text, re.M)
print(m.group(1) if m else "0.0.0")
PY
)"

NAME="StakeDXF-source-v${VERSION}"
STAGE="$(mktemp -d)/${NAME}"
OUT_ZIP="$DIST/${NAME}.zip"

mkdir -p "$STAGE" "$DIST"

# Top-level docs from dist/source_pack/
cp -f "$DOCS_SRC/README.md" "$STAGE/"
cp -f "$DOCS_SRC/BUILD_IOS.md" "$STAGE/"
cp -f "$DOCS_SRC/BUILD_ANDROID.md" "$STAGE/"
cp -f "$DOCS_SRC/VERSION.txt" "$STAGE/"

# Flutter app (tracked-like tree, no caches)
mkdir -p "$STAGE/mobile/stakedxf"
cp -f "$ROOT/mobile/README.md" "$STAGE/mobile/README.md"

tar -C "$APP" \
  --exclude='.dart_tool' \
  --exclude='build' \
  --exclude='.idea' \
  --exclude='*.iml' \
  --exclude='.flutter-plugins' \
  --exclude='.flutter-plugins-dependencies' \
  --exclude='android/.gradle' \
  --exclude='android/.kotlin' \
  --exclude='android/local.properties' \
  --exclude='android/app/.cxx' \
  --exclude='android/captures' \
  --exclude='ios/Flutter/Generated.xcconfig' \
  --exclude='ios/Flutter/flutter_export_environment.sh' \
  --exclude='ios/Flutter/ephemeral' \
  --exclude='ios/Pods' \
  --exclude='ios/.symlinks' \
  --exclude='ios/Runner/GeneratedPluginRegistrant.h' \
  --exclude='ios/Runner/GeneratedPluginRegistrant.m' \
  --exclude='test/fixtures/*.pdf' \
  -cf - . | tar -C "$STAGE/mobile/stakedxf" -xf -

# Gradle wrapper bits are gitignored but required for ground-up Android builds
for f in gradlew gradlew.bat gradle/wrapper/gradle-wrapper.jar; do
  src="$APP/android/$f"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$STAGE/mobile/stakedxf/android/$f")"
    cp -f "$src" "$STAGE/mobile/stakedxf/android/$f"
    chmod +x "$STAGE/mobile/stakedxf/android/gradlew" 2>/dev/null || true
  fi
done

# Native LibreDWG wrapper (Android CONVERT rebuild)
mkdir -p "$STAGE/native"
cp -f "$ROOT/native/stakedxf_convert.c" "$STAGE/native/"
cp -f "$ROOT/native/build_android.sh" "$STAGE/native/"
chmod +x "$STAGE/native/build_android.sh"

# Replace stock Flutter README inside the app with a short pointer
cat > "$STAGE/mobile/stakedxf/README.md" <<EOF
# StakeDXF (Flutter)

Version **${VERSION}** — see pack root \`README.md\`, \`BUILD_IOS.md\`, and
\`BUILD_ANDROID.md\` for ground-up builds.
EOF

rm -f "$OUT_ZIP"
(
  cd "$(dirname "$STAGE")"
  zip -r -q "$OUT_ZIP" "$NAME"
)

echo "Packed: $OUT_ZIP"
unzip -l "$OUT_ZIP" | tail -5
ls -lh "$OUT_ZIP"
# Show excluded noise is gone
unzip -l "$OUT_ZIP" | grep -E 'build/|\.dart_tool|local.properties|\.apk$' && exit 1 || true
echo "OK — no build caches / APKs in zip"
