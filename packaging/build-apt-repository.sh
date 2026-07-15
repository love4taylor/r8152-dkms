#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
	echo "Usage: $0 PACKAGE_DIR OUTPUT_DIR SIGNING_KEY_ID" >&2
	exit 2
fi

package_dir=$(CDPATH= cd "$1" && pwd)
output_dir=$2
signing_key_id=$3
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)

for command in gpg reprepro; do
	command -v "$command" >/dev/null || {
		echo "Required command not found: $command" >&2
		exit 1
	}
done

if [ -e "$output_dir" ]; then
	echo "Output directory already exists: $output_dir" >&2
	exit 1
fi

shopt -s nullglob
packages=("$package_dir"/*.deb)
if [ "${#packages[@]}" -eq 0 ]; then
	echo "No Debian packages found in $package_dir" >&2
	exit 1
fi

state_dir=$(mktemp -d)
trap 'rm -rf "$state_dir"' EXIT
mkdir -p "$state_dir/conf"

cat > "$state_dir/conf/distributions" <<EOF
Origin: love4taylor
Label: r8152-dkms
Codename: any
Suite: any
Architectures: ${APT_REPOSITORY_ARCHITECTURES:-amd64 arm64 armhf}
Components: main
Description: Realtek r8152 DKMS packages
SignWith: $signing_key_id

EOF

while IFS= read -r package; do
	reprepro -b "$state_dir" includedeb any "$package"
done < <(printf '%s\n' "${packages[@]}" | LC_ALL=C sort)

test -s "$state_dir/dists/any/InRelease"
test -s "$state_dir/dists/any/Release"

mkdir -p "$output_dir/keyrings"
mv "$state_dir/dists" "$output_dir/dists"
mv "$state_dir/pool" "$output_dir/pool"
gpg --batch --yes --export "$signing_key_id" \
	> "$output_dir/keyrings/r8152-archive-keyring.gpg"
test -s "$output_dir/keyrings/r8152-archive-keyring.gpg"

install -D -m 0644 "$script_dir/apt/_headers" "$output_dir/_headers"
install -D -m 0644 "$script_dir/apt/index.html" "$output_dir/index.html"
