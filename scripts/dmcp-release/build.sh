#!/usr/bin/env bash
#
# Purpose: Build the four Crispy games with embedded DMCP for one release platform.
# Dependencies: bash, cmake, git (DMCP fetches yyjson and cpp-httplib at configure time)

set -Eeuo pipefail
IFS=$'\n\t'

readonly PROGRAM_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

platform=""
build_type="Release"
build_dir="$REPO_ROOT/build"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --platform linux|macos|windows [OPTIONS]

Configure and build crispy-doom, crispy-heretic, crispy-hexen, and crispy-strife
with DMCP embedded (-DDMCP_ENABLE=ON).

Options:
      --platform NAME       Target platform: linux, macos, or windows.
      --build-dir DIR       CMake build directory (default: build).
      --build-type TYPE     CMake build type (default: Release).
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

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --platform)
        [[ "${2:-}" ]] || die_usage "$1 requires NAME"
        platform="$2"
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
}

windows_vcpkg_root() {
  local vcpkg_root="${VCPKG_INSTALLATION_ROOT:-${VCPKG_ROOT:-}}"
  local vcpkg_path=""

  if [[ -z "$vcpkg_root" ]] && command -v vcpkg >/dev/null 2>&1; then
    vcpkg_path="$(command -v vcpkg)"
    vcpkg_root="$(dirname "$vcpkg_path")"
  fi

  [[ -n "$vcpkg_root" ]] || die "vcpkg root not found; set VCPKG_INSTALLATION_ROOT or VCPKG_ROOT"

  if command -v cygpath >/dev/null 2>&1; then
    cygpath -m "$vcpkg_root"
  else
    printf '%s\n' "$vcpkg_root"
  fi
}

build_games() {
  local -a cmake_args=(
    -S "$REPO_ROOT"
    -B "$build_dir"
    -DDMCP_ENABLE=ON
    -DCMAKE_BUILD_TYPE="$build_type"
  )

  if [[ "$platform" == "windows" ]]; then
    local vcpkg_root
    vcpkg_root="$(windows_vcpkg_root)"
    cmake_args+=(
      "-DCMAKE_TOOLCHAIN_FILE=$vcpkg_root/scripts/buildsystems/vcpkg.cmake"
      -DVCPKG_TARGET_TRIPLET=x64-windows
      "-DCMAKE_PREFIX_PATH=$vcpkg_root/installed/x64-windows"
    )
  fi

  cmake "${cmake_args[@]}"
  cmake --build "$build_dir" --config "$build_type" --parallel \
    --target crispy-doom crispy-heretic crispy-hexen crispy-strife
}

main() {
  parse_args "$@"
  validate_args
  require_command cmake

  build_games
}

main "$@"
