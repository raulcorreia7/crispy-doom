#!/usr/bin/env bash
#
# Purpose: Verify release archive contents without launching the game.
# Dependencies: bash, tar on Linux/macOS, 7z for .zip archives

set -Eeuo pipefail
IFS=$'\n\t'
shopt -s nullglob

readonly PROGRAM_NAME="${0##*/}"
readonly DMCP_RUNTIME_WINDOWS="dmcp.dll"
readonly DMCP_RUNTIME_LINUX="libdmcp.so"
readonly DMCP_RUNTIME_MACOS="libdmcp.dylib"
readonly DMCP_RUNTIME_WINDOWS_GLOB="dmcp*.dll"
readonly DMCP_RUNTIME_LINUX_GLOB="libdmcp*.so"
readonly DMCP_RUNTIME_MACOS_GLOB="libdmcp*.dylib"
readonly LINUX_ORIGIN_RUNPATH='$ORIGIN'
readonly MACOS_LOADER_PATH='@loader_path'

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

verify_runtime_count() {
  local root="$1"
  local expected="$2"
  shift 2

  local -a runtimes=("$@")
  [[ ${#runtimes[@]} -eq 1 ]] ||
    die "expected exactly one DMCP runtime library, found ${#runtimes[@]}"
  [[ "${runtimes[0]##*/}" == "$expected" ]] ||
    die "unexpected DMCP runtime library: ${runtimes[0]##*/}"
  [[ -f "$root/$expected" ]] || die "missing DMCP runtime library: $root/$expected"
}

verify_linux_runtime_link() {
  local executable="$1"
  local root="$2"
  local dynamic_section

  command -v readelf >/dev/null 2>&1 ||
    die "readelf is required to verify Linux DMCP linkage"

  dynamic_section="$(readelf -d "$executable")"
  grep -F "Shared library: [$DMCP_RUNTIME_LINUX]" <<<"$dynamic_section" >/dev/null ||
    die "crispy-doom does not import $DMCP_RUNTIME_LINUX"
  grep -F "Library runpath: [$LINUX_ORIGIN_RUNPATH]" <<<"$dynamic_section" >/dev/null ||
    die "crispy-doom does not use $LINUX_ORIGIN_RUNPATH runpath for bundled libraries"

  if command -v ldd >/dev/null 2>&1; then
    ldd "$executable" | grep -F "$root/$DMCP_RUNTIME_LINUX" >/dev/null ||
      die "ldd did not resolve $DMCP_RUNTIME_LINUX from the package directory"
  fi
}

verify_macos_runtime_link() {
  local executable="$1"
  local load_commands
  local linked_libraries

  command -v otool >/dev/null 2>&1 ||
    die "otool is required to verify macOS DMCP linkage"

  linked_libraries="$(otool -L "$executable")"
  grep -F "$DMCP_RUNTIME_MACOS" <<<"$linked_libraries" >/dev/null ||
    die "crispy-doom does not import $DMCP_RUNTIME_MACOS"

  load_commands="$(otool -l "$executable")"
  grep -F "$MACOS_LOADER_PATH" <<<"$load_commands" >/dev/null ||
    die "crispy-doom does not use $MACOS_LOADER_PATH for bundled libraries"
}

verify_windows_runtime_link() {
  local executable="$1"

  if command -v dumpbin >/dev/null 2>&1; then
    dumpbin //dependents "$executable" | grep -Fi "$DMCP_RUNTIME_WINDOWS" >/dev/null ||
      die "crispy-doom.exe does not import $DMCP_RUNTIME_WINDOWS"
  elif command -v objdump >/dev/null 2>&1; then
    objdump -p "$executable" | grep -Fi "DLL Name: $DMCP_RUNTIME_WINDOWS" >/dev/null ||
      die "crispy-doom.exe does not import $DMCP_RUNTIME_WINDOWS"
  fi
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
    "$root/VERSION.txt"
    "$root/agent-presets/codex/config.toml"
    "$root/agent-presets/opencode/opencode.json"
    "$root/agent-presets/claude/mcp.json"
    "$root/agent-presets/generic/mcp.json"
    "$root/agent-presets/pi/mcp.json"
    "$root/agents/python/README.md"
    "$root/agents/python/pyproject.toml"
    "$root/agents/python/dmcp_agent/cli.py"
    "$root/agents/python/dmcp_agent/client.py"
    "$root/agents/python/dmcp_agent/workflows.py"
  )

  if [[ "$platform" == "windows" || "${RUNNER_OS:-}" == "Windows" ]]; then
    required_files+=("$root/crispy-doom.exe" "$root/download_wad.bat" "$root/go.bat")
    local -a dmcp_runtimes=("$root"/$DMCP_RUNTIME_WINDOWS_GLOB)
    verify_runtime_count "$root" "$DMCP_RUNTIME_WINDOWS" "${dmcp_runtimes[@]}"
    verify_windows_runtime_link "$root/crispy-doom.exe"
  else
    required_files+=("$root/crispy-doom" "$root/download_wad.sh" "$root/go.sh")
    if [[ "$platform" == "macos" ]]; then
      local -a dmcp_runtimes=("$root"/$DMCP_RUNTIME_MACOS_GLOB)
      verify_runtime_count "$root" "$DMCP_RUNTIME_MACOS" "${dmcp_runtimes[@]}"
      verify_macos_runtime_link "$root/crispy-doom"
    else
      local -a dmcp_runtimes=("$root"/$DMCP_RUNTIME_LINUX_GLOB)
      verify_runtime_count "$root" "$DMCP_RUNTIME_LINUX" "${dmcp_runtimes[@]}"
      verify_linux_runtime_link "$root/crispy-doom" "$root"
    fi
  fi

  for file in "${required_files[@]}"; do
    [[ -f "$file" ]] || die "missing package file: $file"
  done

  [[ -d "$root/agent-presets" ]] || die "missing package directory: agent-presets"
  [[ -d "$root/agents/python" ]] || die "missing package directory: agents/python"

  [[ ! -e "$root/.codex" ]] || die "release package must use agent-presets/codex, not root .codex"
  [[ ! -e "$root/.mcp.json" ]] || die "release package must use agent-presets/claude, not root .mcp.json"
  [[ ! -e "$root/opencode.json" ]] || die "release package must use agent-presets/opencode, not root opencode.json"
  [[ ! -e "$root/mcp.json" ]] || die "release package must use agent-presets/generic, not root mcp.json"

  grep -F 'dmcp-agent = "dmcp_agent.cli:main"' "$root/agents/python/pyproject.toml" >/dev/null ||
    die "Python agent package is missing the dmcp-agent entry point"

  if find "$root" -type f -iname '*.wad' -print -quit | grep -q .; then
    die "release package must not bundle WAD files"
  fi

  if find "$root/agents/python" -type d \( -name '.venv' -o -name '__pycache__' \) \
      -print -quit | grep -q .; then
    die "release package must not bundle Python virtualenvs or bytecode caches"
  fi
}

main "$@"
