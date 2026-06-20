#!/usr/bin/env bash
#
# Purpose: Install platform dependencies for the DMCP release workflow.
# Dependencies: bash, apt-get on Linux, Homebrew on macOS, vcpkg on Windows

set -Eeuo pipefail
IFS=$'\n\t'

readonly PROGRAM_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

platform=""

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --platform linux|macos|windows

Install platform dependencies for the DMCP release workflow.

Options:
      --platform NAME  Target platform: linux, macos, or windows.
  -h, --help           Show this help and exit.

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

install_linux() {
  require_command sudo
  sudo apt-get update
  sudo apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    libsdl2-dev \
    libsdl2-net-dev \
    libsdl2-mixer-dev \
    libfluidsynth-dev \
    libpng-dev \
    libsamplerate0-dev \
    zlib1g-dev
}

install_macos() {
  require_command brew
  brew install cmake pkg-config sdl2 sdl2_net sdl2_mixer fluid-synth libpng libsamplerate
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
    cygpath -u "$vcpkg_root"
  else
    printf '%s\n' "$vcpkg_root"
  fi
}

install_windows() {
  local vcpkg_root
  local vcpkg_exe=""

  vcpkg_root="$(windows_vcpkg_root)"
  vcpkg_exe="$vcpkg_root/vcpkg"
  if [[ -x "$vcpkg_exe.exe" ]]; then
    vcpkg_exe="$vcpkg_exe.exe"
  fi
  [[ -x "$vcpkg_exe" ]] || die "vcpkg executable not found under $vcpkg_root"

  (
    cd "$REPO_ROOT"
    "$vcpkg_exe" install \
      --triplet x64-windows \
      --vcpkg-root "$vcpkg_root"
  )
}

main() {
  parse_args "$@"
  validate_args

  case "$platform" in
    linux) install_linux ;;
    macos) install_macos ;;
    windows) install_windows ;;
  esac
}

main "$@"
