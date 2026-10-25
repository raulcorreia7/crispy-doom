#!/usr/bin/env bash
#
# Purpose: Assemble and verify one Crispy Doom release artifact with DMCP support.
# Dependencies: bash, tar on Linux/macOS, 7z on Windows

set -Eeuo pipefail
IFS=$'\n\t'
shopt -s nullglob

readonly PROGRAM_NAME="${0##*/}"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly PAYLOAD_DIR="$SCRIPT_DIR/payload"
readonly GAMES=(doom heretic hexen strife)

platform=""
package_arch="${PACKAGE_ARCH:-}"
artifact_name="${ARTIFACT_NAME:-}"
asset_name="${ASSET_NAME:-}"
release_tag="${RELEASE_TAG:-}"
readonly DMCP_DIR="$REPO_ROOT/third_party/doom-mcp"
build_dir="${CRISPY_BUILD_DIR:-build}"
build_type="${BUILD_TYPE:-Release}"
package_root="${PACKAGE_ROOT:-build/dmcp-release/pkg}"
artifact_dir="$package_root/$artifact_name"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --platform linux|macos|windows --artifact-name NAME --asset-name FILE [OPTIONS]

Assemble and verify the Crispy Doom release artifact with DMCP support. Run
build.sh first.

Options:
      --platform NAME       Target platform: linux, macos, or windows.
      --package-arch ARCH   Native package architecture: x86_64 or arm64.
      --artifact-name NAME  Directory name inside the archive.
      --asset-name FILE     Archive file to write.
      --release-tag TAG     Release tag to write into VERSION.txt.
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

normalize_arch() {
  local arch="$1"
  arch="$(printf '%s' "$arch" | tr '[:upper:]' '[:lower:]' | tr '-' '_')"
  case "$arch" in
    amd64|x64|x86_64) printf 'x86_64\n' ;;
    aarch64|arm64) printf 'arm64\n' ;;
    *) printf '%s\n' "$arch" ;;
  esac
}

detect_package_arch() {
  local arch="${PROCESSOR_ARCHITECTURE:-}"

  if [[ -z "$arch" || "$arch" == "x86" ]]; then
    arch="$(uname -m 2>/dev/null || true)"
  fi

  normalize_arch "$arch"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --platform)
        [[ "${2:-}" ]] || die_usage "$1 requires NAME"
        platform="$2"
        shift 2
        ;;
      --package-arch)
        [[ "${2:-}" ]] || die_usage "$1 requires ARCH"
        package_arch="$2"
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
  local detected_arch
  local asset_file

  case "$platform" in
    linux|macos|windows) ;;
    "") die_usage "--platform is required" ;;
    *) die_usage "--platform must be linux, macos, or windows" ;;
  esac
  detected_arch="$(detect_package_arch)"
  case "$detected_arch" in
    x86_64|arm64) ;;
    *) die "unsupported or unknown build architecture: ${detected_arch:-unknown}" ;;
  esac
  if [[ -n "$package_arch" ]]; then
    package_arch="$(normalize_arch "$package_arch")"
    [[ "$package_arch" == "$detected_arch" ]] ||
      die "package architecture '$package_arch' does not match build host architecture '$detected_arch'"
  else
    package_arch="$detected_arch"
  fi
  [[ -n "$artifact_name" ]] || die_usage "--artifact-name is required"
  [[ -n "$asset_name" ]] || die_usage "--asset-name is required"
  build_dir="$(abs_path "$build_dir")"
  package_root="$(abs_path "$package_root")"
  asset_name="$(abs_path "$asset_name")"
  asset_file="${asset_name##*/}"
  [[ "$artifact_name" == *"$platform"* ]] ||
    die "artifact name must include target platform '$platform': $artifact_name"
  [[ "$artifact_name" == *"$package_arch"* ]] ||
    die "artifact name must include target architecture '$package_arch': $artifact_name"
  [[ "$asset_file" == *"$platform"* ]] ||
    die "asset name must include target platform '$platform': $asset_file"
  [[ "$asset_file" == *"$package_arch"* ]] ||
    die "asset name must include target architecture '$package_arch': $asset_file"
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

copy_game_binaries() {
  local game

  if is_windows; then
    for game in "${GAMES[@]}"; do
      copy_file "$build_dir/src/$build_type/crispy-$game.exe" "$artifact_dir/crispy-$game.exe"
    done
    # SDL and other runtime DLLs that vcpkg places next to the executables.
    local runtime_dlls=("$build_dir"/src/"$build_type"/*.dll)
    if [[ ${#runtime_dlls[@]} -gt 0 ]]; then
      cp "${runtime_dlls[@]}" "$artifact_dir/"
    fi
    return
  fi

  for game in "${GAMES[@]}"; do
    copy_file "$build_dir/src/crispy-$game" "$artifact_dir/crispy-$game"
    chmod +x "$artifact_dir/crispy-$game"
  done
}

# DMCP links yyjson and cpp-httplib statically; ship their license texts.
copy_third_party_licenses() {
  local cache="${CPM_SOURCE_CACHE:-$DMCP_DIR/.cache}"
  local dep
  local license

  mkdir -p "$artifact_dir/third-party-licenses"
  for dep in yyjson cpp-httplib; do
    license="$(find "$cache/$dep" -maxdepth 2 -name LICENSE -print -quit 2>/dev/null || true)"
    [[ -n "$license" ]] || die "license for $dep not found under $cache/$dep"
    cp "$license" "$artifact_dir/third-party-licenses/$dep-LICENSE"
  done
}

copy_release_files() {
  if is_windows; then
    copy_file "$REPO_ROOT/scripts/dmcp-release/go.bat" "$artifact_dir/go.bat"
    copy_file "$REPO_ROOT/scripts/dmcp-release/download_wad.bat" "$artifact_dir/download_wad.bat"
    copy_file "$REPO_ROOT/scripts/dmcp-release/dmcp-agent.bat" "$artifact_dir/dmcp-agent.bat"
  else
    copy_file "$REPO_ROOT/scripts/dmcp-release/go.sh" "$artifact_dir/go.sh"
    copy_file "$REPO_ROOT/scripts/dmcp-release/download_wad.sh" "$artifact_dir/download_wad.sh"
    copy_file "$REPO_ROOT/scripts/dmcp-release/dmcp-agent.sh" "$artifact_dir/dmcp-agent"
    chmod +x "$artifact_dir/go.sh" "$artifact_dir/download_wad.sh" "$artifact_dir/dmcp-agent"
  fi

  copy_file "$REPO_ROOT/README.DMCP.md" "$artifact_dir/README.md"
  copy_file "$REPO_ROOT/docs/build-dmcp.md" "$artifact_dir/BUILDING.md"
  copy_file "$REPO_ROOT/COPYING.md" "$artifact_dir/COPYING.md"
  copy_file "$REPO_ROOT/AUTHORS" "$artifact_dir/AUTHORS"
  copy_file "$DMCP_DIR/LICENSE" "$artifact_dir/DMCP-LICENSE"
  copy_file "$DMCP_DIR/docs/design/v1-tools.md" "$artifact_dir/DMCP-TOOLS.md"
  copy_third_party_licenses
  copy_tree_contents "$PAYLOAD_DIR" "$artifact_dir"

  local agent_src="$DMCP_DIR/examples/agents/python"
  copy_required_dir "$agent_src/dmcp_agent" "$artifact_dir/agents/python/dmcp_agent"
  copy_file "$agent_src/README.md" "$artifact_dir/agents/python/README.md"
  copy_file "$agent_src/pyproject.toml" "$artifact_dir/agents/python/pyproject.toml"
  find "$artifact_dir/agents" -name __pycache__ -type d -prune -exec rm -rf {} +

  {
    printf 'release_tag=%s\n' "${release_tag:-unknown}"
    printf 'platform=%s\n' "${platform:-${RUNNER_OS:-unknown}}"
    printf 'architecture=%s\n' "$package_arch"
    printf 'crispy_commit=%s\n' "$(git_commit "$REPO_ROOT")"
    printf 'dmcp_commit=%s\n' "$(git_commit "$DMCP_DIR")"
  } >"$artifact_dir/VERSION.txt"
}

create_archive() {
  mkdir -p "$package_root" "$(dirname "$asset_name")"
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

  copy_game_binaries
  copy_release_files
  create_archive

  "$SCRIPT_DIR/verify_package.sh" \
    --artifact-name "$artifact_name" \
    --asset-name "$asset_name" \
    --platform "$platform"
}

main "$@"
