#!/usr/bin/env bash
# Build libstakedxf.so for Android arm64-v8a (TSC5) and optionally host.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_ANDROID="${ROOT}/mobile/stakedxf/android/app/src/main/jniLibs/arm64-v8a"
NDK="${ANDROID_HOME:-$HOME/android-sdk}/ndk/26.1.10909125"
TOOLCHAIN="${NDK}/toolchains/llvm/prebuilt/linux-x86_64"
API=24
PREFIX_ANDROID="${LIBREDWG_ANDROID_PREFIX:-/tmp/libredwg-android-prefix}"

if [[ ! -f "${PREFIX_ANDROID}/lib/libredwg.a" ]]; then
  echo "Missing ${PREFIX_ANDROID}/lib/libredwg.a — build LibreDWG for Android first." >&2
  exit 1
fi

mkdir -p "${OUT_ANDROID}"
CC="${TOOLCHAIN}/bin/aarch64-linux-android${API}-clang"

"${CC}" -shared -fPIC -O2 \
  -I"${PREFIX_ANDROID}/include" \
  "${ROOT}/native/stakedxf_convert.c" \
  "${PREFIX_ANDROID}/lib/libredwg.a" \
  -o "${OUT_ANDROID}/libstakedxf.so" \
  -lm -llog

echo "Built ${OUT_ANDROID}/libstakedxf.so"
ls -lh "${OUT_ANDROID}/libstakedxf.so"

# Host library for local smoke tests (uses system LibreDWG if present)
if [[ -f /usr/local/lib/libredwg.a || -f /usr/local/lib/libredwg.so ]]; then
  mkdir -p "${ROOT}/native/build/host"
  HOST_LIB="/usr/local/lib/libredwg.a"
  [[ -f /usr/local/lib/libredwg.so ]] && HOST_LIB="/usr/local/lib/libredwg.so"
  cc -shared -fPIC -O2 \
    -I/usr/local/include \
    "${ROOT}/native/stakedxf_convert.c" \
    ${HOST_LIB} \
    -o "${ROOT}/native/build/host/libstakedxf.so" \
    -lm \
    -Wl,-rpath,/usr/local/lib
  echo "Built host ${ROOT}/native/build/host/libstakedxf.so"
fi
