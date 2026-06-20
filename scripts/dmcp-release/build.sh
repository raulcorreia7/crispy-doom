#!/usr/bin/env bash
#
# Purpose: Build DMCP and Crispy Doom for one Crispy Doom release platform.
# Dependencies: bash, cmake

set -Eeuo pipefail
IFS=$'\n\t'

readonly PROGRAM_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

platform=""
build_type="Release"
build_dir="$REPO_ROOT/build"
dmcp_dir="$REPO_ROOT/third_party/doom-mcp"
dmcp_build_dir="$REPO_ROOT/build/dmcp"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --platform linux|macos|windows [OPTIONS]

Build DMCP and Crispy Doom for one Crispy Doom release platform.

Options:
      --platform NAME       Target platform: linux, macos, or windows.
      --build-dir DIR       Crispy Doom CMake build directory (default: build).
      --dmcp-dir DIR        doom-mcp submodule directory (default: third_party/doom-mcp).
      --dmcp-build-dir DIR  DMCP CMake build directory (default: build/dmcp).
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
      --dmcp-dir)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        dmcp_dir="$2"
        shift 2
        ;;
      --dmcp-build-dir)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        dmcp_build_dir="$2"
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

  [[ -d "$dmcp_dir" ]] || die "doom-mcp checkout not found: $dmcp_dir"
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

build_dmcp() {
  local -a cmake_args=(
    -S "$dmcp_dir"
    -B "$dmcp_build_dir"
    -DDMCP_BUILD_SHARED=ON
    -DDMCP_BUILD_SINGLE_DLL=ON
    -DDMCP_BUILD_EXAMPLES=OFF
    -DDMCP_BUILD_ADAPTER_FAKE=OFF
    -DDMCP_BUILD_ADAPTER_ZDOOM=OFF
    -DDMCP_BUILD_ADAPTER_CRISPY=OFF
    -DCMAKE_BUILD_TYPE="$build_type"
  )

  if [[ "$platform" == "macos" ]]; then
    cmake_args+=(
      -DCMAKE_CXX_COMPILER=clang++
      -DCMAKE_C_COMPILER=clang
      -DCMAKE_SHARED_LINKER_FLAGS=-Wl,-undefined,dynamic_lookup
    )
  elif [[ "$platform" == "windows" ]]; then
    local vcpkg_root
    vcpkg_root="$(windows_vcpkg_root)"
    cmake_args+=(
      "-DCMAKE_TOOLCHAIN_FILE=$vcpkg_root/scripts/buildsystems/vcpkg.cmake"
      -DVCPKG_TARGET_TRIPLET=x64-windows
    )
  fi

  cmake "${cmake_args[@]}"
  cmake --build "$dmcp_build_dir" --config "$build_type" --parallel
}

build_crispy() {
  local -a cmake_args=(
    -S "$REPO_ROOT"
    -B "$build_dir"
    -DDMCP_ENABLE=ON
    -DDMCP_FRAME_CAPTURE=OFF
    -DDMCP_ROOT="$dmcp_dir"
    -DDMCP_ADAPTER_DIR="$dmcp_dir/adapters/crispy-doom"
    -DDMCP_BUILD_DIR="$dmcp_build_dir"
    -DDMCP_LIBRARY_DIR="$dmcp_build_dir"
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
  elif [[ "$platform" == "macos" ]]; then
    cmake_args+=(
      -DCMAKE_BUILD_RPATH=@loader_path
      -DCMAKE_INSTALL_RPATH=@loader_path
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    )
  else
    cmake_args+=(
      '-DCMAKE_BUILD_RPATH=$ORIGIN'
      '-DCMAKE_INSTALL_RPATH=$ORIGIN'
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    )
  fi

  cmake "${cmake_args[@]}"
  cmake --build "$build_dir" --config "$build_type" --parallel
}

main() {
  parse_args "$@"
  validate_args
  require_command cmake

  build_dmcp
  build_crispy
}

main "$@"
