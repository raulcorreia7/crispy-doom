#!/usr/bin/env bash
#
# Purpose: Verify release archive contents without launching the game.
# Dependencies: bash, tar on Linux/macOS, 7z for .zip archives

set -Eeuo pipefail
IFS=$'\n\t'
shopt -s nullglob

readonly PROGRAM_NAME="${0##*/}"
readonly GAMES=(doom heretic hexen strife)

artifact_name="${ARTIFACT_NAME:-}"
asset_name="${ASSET_NAME:-}"
platform="${PLATFORM:-}"
smoke_dir="${SMOKE_DIR:-build/dmcp-release/smoke}"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --artifact-name NAME --asset-name FILE --platform linux|macos|windows [OPTIONS]

Verify release archive contents without launching the game.

Options:
      --artifact-name NAME  Directory name expected inside the archive.
      --asset-name FILE     Archive file to inspect.
      --platform NAME       Target platform: linux, macos, or windows.
      --smoke-dir DIR       Temporary extraction directory (default: build/dmcp-release/smoke).
  -h, --help                Show this help and exit.

Exit status:
  0  Success.
  1  Runtime failure.
  2  Usage or validation error.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

die_usage() {
  printf 'error: %s\n\n' "$*" >&2
  printf "Try '%s --help' for usage.\n" "$PROGRAM_NAME" >&2
  exit 2
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --artifact-name)
        [[ "${2:-}" ]] || die_usage "$1 requires NAME"
        artifact_name="$2"
        shift 2
        ;;
      --asset-name)
        [[ "${2:-}" ]] || die_usage "$1 requires FILE"
        asset_name="$2"
        shift 2
        ;;
      --platform)
        [[ "${2:-}" ]] || die_usage "$1 requires NAME"
        platform="$2"
        shift 2
        ;;
      --smoke-dir)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        smoke_dir="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      -*)
        die_usage "unknown option: $1"
        ;;
      *)
        die_usage "unexpected argument: $1"
        ;;
    esac
  done
}

validate_args() {
  [[ -n "$artifact_name" ]] || die_usage "--artifact-name is required"
  [[ -n "$asset_name" ]] || die_usage "--asset-name is required"
  [[ -f "$asset_name" ]] || die "asset does not exist: $asset_name"
  case "$platform" in
    linux|macos|windows) ;;
    "") die_usage "--platform is required" ;;
    *) die_usage "--platform must be linux, macos, or windows" ;;
  esac
}

verify_unix_script_syntax() {
  local root="$1"

  command -v bash >/dev/null 2>&1 ||
    die "bash is required to verify packaged Unix launchers"
  bash -n "$root/go.sh" "$root/download_wad.sh" "$root/dmcp-agent"
}

verify_agent_runs() {
  local root="$1"
  local python=""

  python="$(command -v python3 || command -v python || true)"
  [[ -n "$python" ]] || return 0
  PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$root/agents/python" "$python" -m dmcp_agent --help >/dev/null ||
    die "packaged dmcp_agent does not start with $python"
}

main() {
  parse_args "$@"
  validate_args

  rm -rf "$smoke_dir"
  mkdir -p "$smoke_dir"

  if [[ "$asset_name" == *.zip ]]; then
    7z x "$asset_name" "-o$smoke_dir" >/dev/null
  else
    tar -xzf "$asset_name" -C "$smoke_dir"
  fi

  local root="$smoke_dir/$artifact_name"

  local -a required_files=(
    "$root/README.md"
    "$root/BUILDING.md"
    "$root/AGENTS.md"
    "$root/COPYING.md"
    "$root/AUTHORS"
    "$root/DMCP-LICENSE"
    "$root/DMCP-TOOLS.md"
    "$root/third-party-licenses/yyjson-LICENSE"
    "$root/third-party-licenses/cpp-httplib-LICENSE"
    "$root/VERSION.txt"
    "$root/agent-presets/codex/config.toml"
    "$root/agent-presets/opencode/opencode.json"
    "$root/agent-presets/claude/mcp.json"
    "$root/agent-presets/generic/mcp.json"
    "$root/agent-presets/pi/mcp.json"
    "$root/agents/python/README.md"
    "$root/agents/python/pyproject.toml"
    "$root/agents/python/dmcp_agent/__main__.py"
    "$root/agents/python/dmcp_agent/cli.py"
    "$root/agents/python/dmcp_agent/client.py"
  )

  local game
  local windows=0
  if [[ "$platform" == "windows" || "${RUNNER_OS:-}" == "Windows" ]]; then
    windows=1
    required_files+=("$root/download_wad.bat" "$root/go.bat" "$root/dmcp-agent.bat")
    for game in "${GAMES[@]}"; do
      required_files+=("$root/crispy-$game.exe")
    done
  else
    required_files+=("$root/download_wad.sh" "$root/go.sh" "$root/dmcp-agent")
    for game in "${GAMES[@]}"; do
      required_files+=("$root/crispy-$game")
    done
  fi

  for file in "${required_files[@]}"; do
    [[ -f "$file" ]] || die "missing package file: $file"
  done

  [[ ! -e "$root/.codex" ]] || die "release package must use agent-presets/codex, not root .codex"
  [[ ! -e "$root/.mcp.json" ]] || die "release package must use agent-presets/claude, not root .mcp.json"
  [[ ! -e "$root/opencode.json" ]] || die "release package must use agent-presets/opencode, not root opencode.json"
  [[ ! -e "$root/mcp.json" ]] || die "release package must use agent-presets/generic, not root mcp.json"

  if find "$root" -type f \( -iname '*.wad' -o -iname '*dmcp*.dll' -o -iname 'libdmcp*' \) \
      -print -quit | grep -q .; then
    die "release package must not bundle WAD files or a DMCP shared library"
  fi

  if find "$root/agents" -type d \( -name '.venv' -o -name '__pycache__' \) \
      -print -quit | grep -q .; then
    die "release package must not bundle Python virtualenvs or bytecode caches"
  fi

  if [[ "$windows" -eq 0 ]]; then
    for game in "${GAMES[@]}"; do
      [[ -x "$root/crispy-$game" ]] || die "crispy-$game must be executable"
    done
    [[ -x "$root/dmcp-agent" ]] || die "dmcp-agent launcher must be executable"
    verify_unix_script_syntax "$root"
  fi

  verify_agent_runs "$root"
}

main "$@"
