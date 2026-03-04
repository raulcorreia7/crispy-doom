#!/usr/bin/env bash
# download_wad.sh - Download Doom shareware WAD
#
# Usage: ./download_wad.sh [OUTPUT_DIR]
#
# Downloads doom1.wad (shareware) to OUTPUT_DIR (default: current dir).
# Requires curl or wget.

set -euo pipefail

OUT_DIR="${1:-.}"
OUT_FILE="${OUT_DIR}/doom1.wad"
MIN_BYTES=4000000

mkdir -p "${OUT_DIR}"

if [[ -f "${OUT_FILE}" ]]; then
  size=$(stat -f%z "${OUT_FILE}" 2>/dev/null || stat -c%s "${OUT_FILE}" 2>/dev/null || echo "0")
  if [[ "${size}" -ge "${MIN_BYTES}" ]]; then
    echo "doom1.wad already exists (${size} bytes): ${OUT_FILE}"
    exit 0
  fi
  rm -f "${OUT_FILE}"
fi

if command -v curl >/dev/null 2>&1; then
  download() {
    local url="$1"
    curl -fsSL --retry 3 --connect-timeout 10 -o "${OUT_FILE}" "${url}" >/dev/null 2>&1
  }
elif command -v wget >/dev/null 2>&1; then
  download() {
    local url="$1"
    wget -q --tries 3 --timeout=10 -O "${OUT_FILE}" "${url}" >/dev/null 2>&1
  }
else
  echo "error: neither curl nor wget is available." >&2
  echo "Install one of them or download doom1.wad manually." >&2
  exit 1
fi

urls=(
  "https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
  "https://raw.githubusercontent.com/Doom-Utils/shareware-collection/master/Doom%201.0/doom1.wad"
  "https://archive.org/download/DoomsharewareEpisode/doom1.wad"
)

echo "Downloading Doom shareware WAD to: ${OUT_FILE}"
for url in "${urls[@]}"; do
  echo "Trying: ${url}"
  rm -f "${OUT_FILE}" 2>/dev/null || true
  if download "${url}"; then
    size=$(stat -f%z "${OUT_FILE}" 2>/dev/null || stat -c%s "${OUT_FILE}" 2>/dev/null || echo "0")
    if [[ "${size}" -ge "${MIN_BYTES}" ]]; then
      echo "Downloaded: ${OUT_FILE} (${size} bytes)"
      exit 0
    fi
  fi
done

echo "error: failed to download doom1.wad from all mirrors." >&2
echo "You can download it manually from:" >&2
echo "  https://archive.org/details/DoomsharewareEpisode" >&2
exit 1
