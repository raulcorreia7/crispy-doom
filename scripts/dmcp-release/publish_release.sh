#!/usr/bin/env bash
#
# Purpose: Publish downloaded workflow artifacts as GitHub release assets.
# Dependencies: bash, gh

set -Eeuo pipefail
IFS=$'\n\t'

readonly PROGRAM_NAME="${0##*/}"

tag=""
title=""
artifacts_dir="dist"

usage() {
  cat <<EOF
Usage:
  $PROGRAM_NAME --tag TAG --artifacts-dir DIR [--title TITLE]

Publish downloaded workflow artifacts as GitHub release assets.

Options:
      --tag TAG          Existing Git tag to release.
      --artifacts-dir DIR Directory containing downloaded archives.
      --title TITLE      Release title (default: TAG).
  -h, --help             Show this help and exit.

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
      --tag)
        [[ "${2:-}" ]] || die_usage "$1 requires TAG"
        tag="$2"
        shift 2
        ;;
      --artifacts-dir)
        [[ "${2:-}" ]] || die_usage "$1 requires DIR"
        artifacts_dir="$2"
        shift 2
        ;;
      --title)
        [[ "${2:-}" ]] || die_usage "$1 requires TITLE"
        title="$2"
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

collect_assets() {
  mapfile -t assets < <(find "$artifacts_dir" -type f \( -name '*.tar.gz' -o -name '*.zip' \) -print | sort)
  [[ "${#assets[@]}" -gt 0 ]] || die "no release archives found in $artifacts_dir"
}

create_release() {
  local -a flags=(--verify-tag --title "${title:-$tag}" --generate-notes)

  if gh release view "$tag" >/dev/null 2>&1; then
    die "release already exists for $tag; refusing to overwrite release assets"
  fi

  local version_suffix="$tag"
  version_suffix="${version_suffix#dmcp-v}"
  version_suffix="${version_suffix#v}"
  if [[ "$version_suffix" == *-* ]]; then
    flags+=(--prerelease --latest=false)
  else
    flags+=(--latest)
  fi

  gh release create "$tag" "${assets[@]}" "${flags[@]}"
}

main() {
  parse_args "$@"
  [[ -n "$tag" ]] || die_usage "--tag is required"
  [[ -d "$artifacts_dir" ]] || die "artifacts directory does not exist: $artifacts_dir"
  require_command gh

  local -a assets=()
  collect_assets
  create_release
}

main "$@"
