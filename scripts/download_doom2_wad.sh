#!/usr/bin/env bash
# download_doom2_wad.sh - Download the Doom II IWAD from archive.org.
#
# Usage:
#   scripts/download_doom2_wad.sh [OUTPUT_DIR]
#   scripts/download_doom2_wad.sh -o FILE
#
# Options:
#   -o, --output FILE  Output WAD path (default: ./doom2.wad)
#   -f, --force        Replace an existing output file
#   -h, --help         Show this help
#
# Requirements: curl or wget, plus unzip or bsdtar.

set -euo pipefail

readonly DOOM2_URL="https://archive.org/download/Doom-2/Doom2.zip"

output_file="./doom2.wad"
force=0
positional_output=""
explicit_output=0
tmp_dir=""

usage() {
	sed -n 's/^# //p' "$0" | sed -n '1,14p'
}

cleanup() {
	if [[ -n "$tmp_dir" ]]; then
		rm -rf "$tmp_dir"
	fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
	case "$1" in
	-o | --output)
		[[ $# -ge 2 ]] || {
			echo "error: missing value for $1" >&2
			exit 2
		}
		output_file="$2"
		explicit_output=1
		shift 2
		;;
	-f | --force)
		force=1
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	--)
		shift
		break
		;;
	-*)
		echo "error: unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	*)
		if [[ -n "$positional_output" ]]; then
			echo "error: only one positional output directory is supported" >&2
			usage >&2
			exit 2
		fi
		positional_output="$1"
		shift
		;;
	esac
done

if [[ -n "$positional_output" ]]; then
	if [[ "$explicit_output" -eq 1 ]]; then
		echo "error: use either OUTPUT_DIR or -o/--output, not both" >&2
		exit 2
	fi

	output_file="$positional_output/doom2.wad"
fi

download_to_file() {
	local url="$1"
	local file="$2"

	if command -v curl >/dev/null 2>&1; then
		curl -L --fail --retry 3 --progress-bar -o "$file" "$url" >/dev/null
	elif command -v wget >/dev/null 2>&1; then
		wget -q --tries=3 -O "$file" "$url"
	else
		echo "error: requires curl or wget to download Doom2.zip" >&2
		exit 1
	fi
}

select_extractor() {
	if command -v unzip >/dev/null 2>&1; then
		printf '%s\n' "unzip"
	elif command -v bsdtar >/dev/null 2>&1; then
		printf '%s\n' "bsdtar"
	else
		echo "error: requires unzip or bsdtar to extract Doom2.zip" >&2
		echo "Install unzip, or install libarchive/bsdtar, then retry." >&2
		exit 1
	fi
}

find_doom2_entry() {
	local archive="$1"
	local extractor="$2"
	local entries

	case "$extractor" in
	unzip)
		entries="$(unzip -Z -1 "$archive")"
		;;
	bsdtar)
		entries="$(bsdtar -tf "$archive")"
		;;
	esac

	printf '%s\n' "$entries" | awk '
		{
			name = $0
			sub(/^.*\//, "", name)
			if (tolower(name) == "doom2.wad") {
				print $0
				exit
			}
		}
	'
}

extract_doom2_entry() {
	local archive="$1"
	local extractor="$2"
	local entry="$3"
	local output="$4"

	case "$extractor" in
	unzip)
		unzip -p "$archive" "$entry" >"$output"
		;;
	bsdtar)
		bsdtar -xOf "$archive" "$entry" >"$output"
		;;
	esac
}

output_dir="$(dirname "$output_file")"
mkdir -p "$output_dir"

if [[ -e "$output_file" ]]; then
	if [[ "$force" -eq 1 ]]; then
		rm -f "$output_file"
	elif [[ -s "$output_file" ]]; then
		echo "doom2.wad already exists: $output_file"
		exit 0
	else
		echo "error: existing output file is empty: $output_file" >&2
		echo "Use --force to replace it." >&2
		exit 1
	fi
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/doom2-wad.XXXXXX")"
tmp_zip="$tmp_dir/Doom2.zip"
tmp_wad="$tmp_dir/doom2.wad"
extractor="$(select_extractor)"

echo "Downloading Doom2.zip..."
download_to_file "$DOOM2_URL" "$tmp_zip"

entry="$(find_doom2_entry "$tmp_zip" "$extractor")"
if [[ -z "$entry" ]]; then
	echo "error: Doom2.zip did not contain DOOM2.WAD/doom2.wad" >&2
	exit 1
fi

extract_doom2_entry "$tmp_zip" "$extractor" "$entry" "$tmp_wad"

if [[ ! -s "$tmp_wad" ]]; then
	echo "error: extracted doom2.wad is empty" >&2
	exit 1
fi

mv "$tmp_wad" "$output_file"
echo "Downloaded: $output_file"
