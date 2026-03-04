#!/usr/bin/env bash
# go.sh - Run Crispy Doom with MCP
#
# Usage: ./go.sh [extra args...]
#   Copies your own WAD to this folder, or uses bundled doom1.wad.
#
# Environment:
#   DOOM_WAD   Path to WAD file (default: ./doom1.wad)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

WAD="${DOOM_WAD:-./doom1.wad}"

if [[ ! -f "$WAD" ]]; then
  echo "error: WAD not found: $WAD" >&2
  echo "For shareware testing, run: ./download_wad.sh" >&2
  echo "Or copy your own doom.wad here, or set DOOM_WAD=/path/to/your.wad" >&2
  exit 1
fi

if [[ ! -f "./crispy-doom" ]]; then
  echo "error: crispy-doom binary not found in $SCRIPT_DIR" >&2
  exit 1
fi

export LD_LIBRARY_PATH="$SCRIPT_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export DYLD_LIBRARY_PATH="$SCRIPT_DIR${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"

exec ./crispy-doom -iwad "$WAD" "$@"
