#!/usr/bin/env bash
# dmcp-agent.sh - Run the bundled DMCP Python helper from the package root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/agents/python"

if ! command -v uv >/dev/null 2>&1; then
	echo "error: uv is required to run dmcp-agent: https://docs.astral.sh/uv/" >&2
	exit 1
fi

if [[ ! -d "$AGENT_DIR" ]]; then
	echo "error: bundled Python agent not found: $AGENT_DIR" >&2
	exit 1
fi

cd "$AGENT_DIR"
export UV_LINK_MODE="${UV_LINK_MODE:-copy}"
exec uv run --quiet dmcp-agent "$@"
