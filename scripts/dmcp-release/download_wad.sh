#!/usr/bin/env bash
# download_wad.sh - Download Doom shareware IWAD

set -euo pipefail

output_file="./doom1.wad"
force=0
positional_output=""
readonly DOOM1_WAD_SHA256="1d7d43be501e67d927e415e0b8f3e29c3bf33075e859721816f652a526cac771"
readonly DOOM1_WAD_SIZE=4196020

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

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
	echo "error: requires curl or wget" >&2
	exit 1
fi

urls=(
	"https://distro.ibiblio.org/slitaz/sources/packages/d/doom1.wad"
)
archive_urls=(
	"https://deb.debian.org/debian/pool/non-free/d/doom-wad-shareware/doom-wad-shareware_1.9.fixed.orig.tar.gz"
)
tmp_wad="$(dirname "$output_file")/.doom1.wad.tmp"
tmp_archive="$(dirname "$output_file")/.doom-shareware.tar.gz.tmp"
tmp_dir="$(dirname "$output_file")/.doom-shareware.tmp"

cleanup() {
	rm -f "$tmp_wad" "$tmp_archive"
	rm -rf "$tmp_dir"
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
	[[ "$size" -eq "$DOOM1_WAD_SIZE" ]] || return 1

	local digest=""
	if command -v sha256sum >/dev/null 2>&1; then
		digest="$(sha256sum "$1" | awk '{print $1}')"
	elif command -v shasum >/dev/null 2>&1; then
		digest="$(shasum -a 256 "$1" | awk '{print $1}')"
	else
		echo "error: requires sha256sum or shasum to verify doom1.wad" >&2
		return 1
	fi

	[[ "$digest" == "$DOOM1_WAD_SHA256" ]]
}

mkdir -p "$(dirname "$output_file")"

if [[ "$force" -eq 1 ]]; then
	rm -f "$output_file"
fi

if [[ -f "$output_file" ]]; then
	if valid_wad "$output_file"; then
		echo "doom1.wad already exists: $output_file"
		exit 0
	fi
	echo "error: existing file does not match the expected Doom shareware IWAD: $output_file" >&2
	echo "Use --force to replace it, or set DOOM_WAD/pass -iwad to use a different IWAD." >&2
	exit 1
fi

echo "Downloading doom1.wad..."
for url in "${urls[@]}"; do
	rm -f "$tmp_wad"
	if download_to_file "$url" "$tmp_wad" && valid_wad "$tmp_wad"; then
		mv "$tmp_wad" "$output_file"
		echo "Downloaded: $output_file"
		exit 0
	fi
done

if command -v tar >/dev/null 2>&1; then
	for url in "${archive_urls[@]}"; do
		rm -rf "$tmp_dir"
		mkdir -p "$tmp_dir"
		rm -f "$tmp_archive" "$tmp_wad"
		if download_to_file "$url" "$tmp_archive" && tar -xzf "$tmp_archive" -C "$tmp_dir"; then
			candidate="$(find "$tmp_dir" -iname 'doom1.wad' -type f -print -quit)"
			if [[ -n "$candidate" ]] && valid_wad "$candidate"; then
				mv "$candidate" "$output_file"
				echo "Downloaded: $output_file"
				exit 0
			fi
		fi
	done
else
	echo "warning: tar not found; skipping Debian shareware archive fallback" >&2
fi

if [[ -f "$tmp_wad" || -f "$tmp_archive" ]]; then
	echo "error: downloaded doom1.wad did not match expected SHA256" >&2
else
	echo "error: failed to download doom1.wad" >&2
fi
exit 1
