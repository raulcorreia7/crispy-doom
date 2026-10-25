#!/usr/bin/env bash
# dmcp-agent.sh - Run the bundled DMCP Python agent (standard library only).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/agents/python"

if [[ ! -d "$AGENT_DIR/dmcp_agent" ]]; then
	echo "error: bundled Python agent not found: $AGENT_DIR" >&2
	exit 1
fi

PYTHON="$(command -v python3 || command -v python || true)"
if [[ -z "$PYTHON" ]]; then
	echo "error: Python 3.10 or newer is required to run dmcp-agent" >&2
	exit 1
fi

export PYTHONDONTWRITEBYTECODE=1
export PYTHONPATH="$AGENT_DIR${PYTHONPATH:+:$PYTHONPATH}"
exec "$PYTHON" -m dmcp_agent "$@"
