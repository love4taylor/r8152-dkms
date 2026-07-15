#!/bin/sh

set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
repo_root=$(dirname "$script_dir")
cd "$repo_root"

driver_version=$(sed -n 's/^#define DRIVER_VERSION "v\([0-9][0-9.]*\)".*/\1/p' r8152.c)
make_version=$(sed -n 's/^DKMS_VERSION ?= //p' Makefile)
dkms_version=$(sed -n 's/^PACKAGE_VERSION="\([^"]*\)"/\1/p' dkms.conf)
debian_version=$(sed -n '1s/^[^(]*(\([^)]*\)).*/\1/p' debian/changelog)
debian_version=${debian_version%%-*}
arch_version=$(sed -n 's/^pkgver=//p' packaging/arch/PKGBUILD)

for version in \
	"$driver_version" \
	"$make_version" \
	"$dkms_version" \
	"$debian_version" \
	"$arch_version"
do
	if [ -z "$version" ]; then
		echo "Unable to read every package version" >&2
		exit 1
	fi

	if [ "$version" != "$make_version" ]; then
		echo "Package version mismatch: expected $make_version, found $version" >&2
		exit 1
	fi
done

echo "Package versions match: $make_version"
