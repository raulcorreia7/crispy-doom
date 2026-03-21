#!/usr/bin/env bash
# download_wad.sh - Download Doom shareware IWAD

set -euo pipefail

output_file="./doom1.wad"
force=0
positional_output=""

usage() {
	cat <<'EOF'
Download doom1.wad into the current folder or a custom path.

Usage:
  ./download_wad.sh [OUTPUT_DIR]
  ./download_wad.sh -o FILE

Options:
  -o, --output FILE  Output WAD path
  -f, --force        Re-download even if the file already exists
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-o | --output)
		[[ $# -ge 2 ]] || {
			echo "error: missing value for $1" >&2
			exit 2
		}
		output_file="$2"
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
			echo "error: only one positional output path is supported" >&2
			usage >&2
			exit 2
		fi
		positional_output="$1"
		shift
		;;
	esac
done

if [[ -n "$positional_output" ]]; then
	if [[ "$output_file" != "./doom1.wad" ]]; then
		echo "error: use either OUTPUT_DIR or -o/--output, not both" >&2
		exit 2
	fi

	case "$positional_output" in
	*.wad | *.WAD)
		output_file="$positional_output"
		;;
	*)
		output_file="$positional_output/doom1.wad"
		;;
	esac
fi

mkdir -p "$(dirname "$output_file")"

if [[ "$force" -eq 1 ]]; then
	rm -f "$output_file"
fi

if [[ -f "$output_file" ]]; then
	size=$(stat -c%s "$output_file" 2>/dev/null || stat -f%z "$output_file" 2>/dev/null || echo "0")
	if [[ "$size" -ge 4000000 ]]; then
		echo "doom1.wad already exists: $output_file"
		exit 0
	fi
	rm -f "$output_file"
fi

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
	echo "error: requires curl or wget" >&2
	exit 1
fi

urls=(
	"https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
	"https://raw.githubusercontent.com/Doom-Utils/shareware-collection/master/Doom%201.0/doom1.wad"
	"https://archive.org/download/DoomsharewareEpisode/doom1.wad"
)
zip_url="https://www.quaddicted.com/files/idgames/idstuff/doom/doom19s.zip"
tmp_wad="$(dirname "$output_file")/.doom1.wad.tmp"
tmp_zip="$(dirname "$output_file")/.doom19s.zip.tmp"

cleanup() {
	rm -f "$tmp_wad" "$tmp_zip"
}
trap cleanup EXIT

download_to_file() {
	local url="$1"
	local file="$2"

	if command -v curl >/dev/null 2>&1; then
		curl -L --fail --retry 3 --progress-bar -o "$file" "$url" >/dev/null
	else
		wget -q --tries 3 -O "$file" "$url"
	fi
}

valid_wad() {
	local size
	size=$(stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo "0")
	[[ "$size" -ge 4000000 ]]
}

echo "Downloading doom1.wad..."
for url in "${urls[@]}"; do
	rm -f "$tmp_wad"
	if download_to_file "$url" "$tmp_wad" && valid_wad "$tmp_wad"; then
		mv "$tmp_wad" "$output_file"
		echo "Downloaded: $output_file"
		exit 0
	fi
done

if command -v unzip >/dev/null 2>&1; then
	if download_to_file "$zip_url" "$tmp_zip" && unzip -p "$tmp_zip" doom1.wad >"$tmp_wad" 2>/dev/null && valid_wad "$tmp_wad"; then
		mv "$tmp_wad" "$output_file"
		echo "Downloaded: $output_file"
		exit 0
	fi
fi

echo "error: failed to download doom1.wad" >&2
exit 1
