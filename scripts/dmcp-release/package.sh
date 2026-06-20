#!/usr/bin/env bash
#
# Purpose: Assemble and verify one DMCP-enabled Crispy Doom release artifact.
# Dependencies: bash, tar on Linux/macOS, 7z on Windows

set -Eeuo pipefail
IFS=$'\n\t'
shopt -s nullglob

readonly PROGRAM_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PAYLOAD_DIR="$SCRIPT_DIR/payload"
readonly CRISPY_EXECUTABLE_WINDOWS="crispy-doom.exe"
readonly CRISPY_EXECUTABLE_UNIX="crispy-doom"
readonly DMCP_RUNTIME_WINDOWS="dmcp.dll"
readonly DMCP_RUNTIME_LINUX="libdmcp.so"
readonly DMCP_RUNTIME_MACOS="libdmcp.dylib"

platform=""
artifact_name="${ARTIFACT_NAME:-}"
asset_name="${ASSET_NAME:-}"
release_tag="${RELEASE_TAG:-}"
dmcp_dir="${DMCP_DIR:-third_party/doom-mcp}"
build_dir="${CRISPY_BUILD_DIR:-build}"
build_type="${BUILD_TYPE:-Release}"
package_root="${PACKAGE_ROOT:-build/dmcp-release/pkg}"
artifact_dir="$package_root/$artifact_name"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --platform linux|macos|windows --artifact-name NAME --asset-name FILE [OPTIONS]

Assemble and verify the DMCP-enabled Crispy Doom release artifact.

Options:
      --platform NAME       Target platform: linux, macos, or windows.
      --artifact-name NAME  Directory name inside the archive.
      --asset-name FILE     Archive file to write.
      --release-tag TAG     Release tag to write into VERSION.txt.
      --dmcp-dir DIR        doom-mcp submodule directory (default: third_party/doom-mcp).
      --build-dir DIR       Crispy Doom CMake build directory (default: build).
      --build-type TYPE     CMake build type (default: Release).
      --package-root DIR    Temporary package root (default: build/dmcp-release/pkg).
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

abs_path() {
  case "$1" in
    /*|[A-Za-z]:*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$REPO_ROOT" "$1" ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)
        [[ "${2:-}" ]] || die_usage "$1 requires NAME"
        platform="$2"
        shift 2
        ;;
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
      --release-tag)
        [[ "${2:-}" ]] || die_usage "$1 requires TAG"
        release_tag="$2"
        shift 2
        ;;
      --dmcp-dir)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        dmcp_dir="$2"
        shift 2
        ;;
      --build-dir)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        build_dir="$2"
        shift 2
        ;;
      --build-type)
        [[ "${2:-}" ]] || die_usage "$1 requires TYPE"
        build_type="$2"
        shift 2
        ;;
      --package-root)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        package_root="$2"
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
  case "$platform" in
    linux|macos|windows) ;;
    "") die_usage "--platform is required" ;;
    *) die_usage "--platform must be linux, macos, or windows" ;;
  esac
  [[ -n "$artifact_name" ]] || die_usage "--artifact-name is required"
  [[ -n "$asset_name" ]] || die_usage "--asset-name is required"
  dmcp_dir="$(abs_path "$dmcp_dir")"
  build_dir="$(abs_path "$build_dir")"
  package_root="$(abs_path "$package_root")"
  asset_name="$(abs_path "$asset_name")"
  artifact_dir="$package_root/$artifact_name"
}

is_windows() {
  [[ "$platform" == "windows" || "${RUNNER_OS:-}" == "Windows" ]]
}

copy_file() {
  local src="$1"
  local dst="$2"
  if [[ ! -f "$src" ]]; then
      die "required file not found: $src"
  fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
}

copy_required_dir() {
  local src="$1"
  local dst="$2"
  [[ -d "$src" ]] || die "required directory not found: $src"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
}

copy_tree_contents() {
  local src="$1"
  local dst="$2"
  [[ -d "$src" ]] || die "required directory not found: $src"
  mkdir -p "$dst"
  cp -R "$src"/. "$dst"/
}

git_commit() {
  local repo="$1"
  if git -C "$repo" rev-parse HEAD >/dev/null 2>&1; then
    git -C "$repo" rev-parse HEAD
  else
    printf 'unknown\n'
  fi
}

copy_game_binary() {
  if is_windows; then
    copy_file "$build_dir/src/$build_type/$CRISPY_EXECUTABLE_WINDOWS" \
      "$artifact_dir/$CRISPY_EXECUTABLE_WINDOWS"
    local engine_dlls=("$build_dir"/src/"$build_type"/*.dll)
    if [[ ${#engine_dlls[@]} -gt 0 ]]; then
      cp "${engine_dlls[@]}" "$artifact_dir/"
    fi
    return
  fi

  copy_file "$build_dir/src/$CRISPY_EXECUTABLE_UNIX" "$artifact_dir/$CRISPY_EXECUTABLE_UNIX"
}

copy_dmcp_runtime() {
  if is_windows; then
    copy_file "$build_dir/src/$build_type/$DMCP_RUNTIME_WINDOWS" \
      "$artifact_dir/$DMCP_RUNTIME_WINDOWS"
    return
  fi

  if [[ "$platform" == "macos" ]]; then
    copy_file "$build_dir/src/$DMCP_RUNTIME_MACOS" "$artifact_dir/$DMCP_RUNTIME_MACOS"
  else
    copy_file "$build_dir/src/$DMCP_RUNTIME_LINUX" "$artifact_dir/$DMCP_RUNTIME_LINUX"
  fi
}

copy_release_files() {
  if is_windows; then
    copy_file "$REPO_ROOT/scripts/dmcp-release/go.bat" "$artifact_dir/go.bat"
    copy_file "$REPO_ROOT/scripts/dmcp-release/download_wad.bat" "$artifact_dir/download_wad.bat"
  else
    copy_file "$REPO_ROOT/scripts/dmcp-release/go.sh" "$artifact_dir/go.sh"
    copy_file "$REPO_ROOT/scripts/dmcp-release/download_wad.sh" "$artifact_dir/download_wad.sh"
    chmod +x "$artifact_dir/go.sh" "$artifact_dir/download_wad.sh"
  fi

  copy_file "$REPO_ROOT/README.DMCP.md" "$artifact_dir/README.md"
  copy_file "$REPO_ROOT/docs/build-dmcp.md" "$artifact_dir/BUILDING.md"
  copy_tree_contents "$PAYLOAD_DIR" "$artifact_dir"
  copy_required_dir "$dmcp_dir/examples/agents/python" "$artifact_dir/agents/python"
  rm -rf "$artifact_dir/agents/python/.venv" \
         "$artifact_dir/agents/python/__pycache__" \
         "$artifact_dir/agents/python/dmcp_agent/__pycache__"

  {
    printf 'release_tag=%s\n' "${release_tag:-unknown}"
    printf 'platform=%s\n' "${platform:-${RUNNER_OS:-unknown}}"
    printf 'crispy_commit=%s\n' "$(git_commit "$REPO_ROOT")"
    printf 'dmcp_commit=%s\n' "$(git_commit "$dmcp_dir")"
  } >"$artifact_dir/VERSION.txt"
}

create_archive() {
  mkdir -p "$package_root"
  if is_windows; then
    (cd "$package_root" && 7z a "$asset_name" "$artifact_name")
    return
  fi
  tar -czf "$asset_name" -C "$package_root" "$artifact_name"
}

main() {
  parse_args "$@"
  validate_args
  rm -rf "$artifact_dir" "$asset_name"
  mkdir -p "$artifact_dir"

  copy_game_binary
  copy_dmcp_runtime
  copy_release_files
  create_archive

  "$SCRIPT_DIR/verify_package.sh" \
    --artifact-name "$artifact_name" \
    --asset-name "$asset_name" \
    --platform "$platform"
}

main "$@"
