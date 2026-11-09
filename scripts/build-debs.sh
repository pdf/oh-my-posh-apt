#!/usr/bin/env bash
# Build the .deb packages from a verified upstream download.
#
# Usage: build-debs.sh <tag> <upstream-dir> <output-dir>
set -euo pipefail

tag=$1
upstream=$(realpath "$2")
mkdir -p "$3"
out=$(realpath "$3")
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

stage=$(mktemp -d)
trap 'cd / && rm -rf "${stage}"' EXIT

export VERSION=${tag#v}
export DEB_REVISION=1

# nfpm resolves the relative src paths in its configs from here.
cd "${stage}"
install -m 0644 "${upstream}/COPYING" COPYING

# Debian architecture : upstream asset
for pair in amd64:posh-linux-amd64 arm64:posh-linux-arm64 armhf:posh-linux-arm; do
  export DEB_ARCH=${pair%%:*}
  install -m 0755 "${upstream}/${pair#*:}" oh-my-posh
  nfpm package --packager deb --config "${root}/nfpm/oh-my-posh.yaml" --target "${out}/"
done

mkdir themes
unzip -q "${upstream}/themes.zip" -d themes
if [[ -n $(find themes ! -type f ! -type d) ]]; then
  echo "themes.zip contains something other than files and directories" >&2
  exit 1
fi
chmod -R u=rwX,go=rX themes
nfpm package --packager deb --config "${root}/nfpm/oh-my-posh-themes.yaml" --target "${out}/"
