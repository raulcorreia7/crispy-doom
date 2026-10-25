#!/usr/bin/env bash
# go.sh - Run a Crispy game with DMCP and a default IWAD

set -euo pipefail

usage() {
	cat <<'EOF2'
Run a Crispy game from the extracted Crispy Doom release folder.

Usage:
  ./go.sh [doom|heretic|hexen|strife] [extra args...]

Notes:
  - The game defaults to doom.
  - Passes -dmcp_allow_cheats so the mutating DMCP tools are available. Run
    ./crispy-<game> directly to start without them.
  - If you pass -iwad yourself, go.sh forwards args untouched.
  - Otherwise it uses DOOM_WAD or, for doom, ./doom1.wad (downloaded as the
    shareware IWAD when missing). For the other games, DOOM_WAD or the IWAD
    search of the engine applies.
EOF2
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

game="doom"
case "${1:-}" in
doom | heretic | hexen | strife)
	game="$1"
	shift
	;;
esac

exe="./crispy-$game"
if [[ ! -x "$exe" ]]; then
	echo "error: $exe not found in $SCRIPT_DIR" >&2
	exit 1
fi

for argument in "$@"; do
	if [[ "$argument" == "-iwad" ]]; then
		exec "$exe" -dmcp_allow_cheats "$@"
	fi
done

if [[ "$game" != "doom" && -z "${DOOM_WAD:-}" ]]; then
	exec "$exe" -dmcp_allow_cheats "$@"
fi

wad_path="${DOOM_WAD:-./doom1.wad}"

if [[ ! -f "$wad_path" && "$wad_path" == "./doom1.wad" && -x "./download_wad.sh" ]]; then
	./download_wad.sh -o "$wad_path"
fi

if [[ ! -f "$wad_path" ]]; then
	echo "error: WAD not found: $wad_path" >&2
	exit 1
fi

exec "$exe" -iwad "$wad_path" -dmcp_allow_cheats "$@"
