#!/usr/bin/env bash
# go.sh - Run the DMCP release with a default IWAD

set -euo pipefail

usage() {
	cat <<'EOF'
Run crispy-doom from the extracted DMCP release folder.

Usage:
  ./go.sh [extra args...]

Notes:
  - If you pass -iwad yourself, go.sh forwards args untouched.
  - Otherwise it uses DOOM_WAD or ./doom1.wad.
  - If ./doom1.wad is missing, it downloads the shareware IWAD first.
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

if [[ ! -x "./crispy-doom" ]]; then
	echo "error: crispy-doom not found in $SCRIPT_DIR" >&2
	exit 1
fi

for argument in "$@"; do
	if [[ "$argument" == "-iwad" ]]; then
		exec ./crispy-doom "$@"
	fi
done

wad_path="${DOOM_WAD:-./doom1.wad}"

if [[ ! -f "$wad_path" && "$wad_path" == "./doom1.wad" && -x "./download_wad.sh" ]]; then
	./download_wad.sh -o "$wad_path"
fi

if [[ ! -f "$wad_path" ]]; then
	echo "error: WAD not found: $wad_path" >&2
	exit 1
fi

exec ./crispy-doom -iwad "$wad_path" "$@"
