#!/usr/bin/env bash
# Download an upstream release and verify it before anything is packaged.
#
# Usage: fetch-upstream.sh <tag> <output-dir>
#
# Binaries: checksums.txt must carry a valid signature from the upstream key
# pinned in upstream/public_key.pem, and the sha256 must match.
# themes.zip: upstream's checksums.txt does not list it, so it is checked
# against the sha256 digest GitHub's API reports for the asset.
set -euo pipefail

UPSTREAM_REPO=JanDeDobbeleer/oh-my-posh
BINARIES=(posh-linux-amd64 posh-linux-arm64 posh-linux-arm)

tag=$1
out=$2
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[[ ${tag} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "refusing tag '${tag}': not a stable vX.Y.Z tag" >&2
  exit 1
}

mkdir -p "${out}"
base="https://github.com/${UPSTREAM_REPO}/releases/download/${tag}"
for asset in "${BINARIES[@]}" themes.zip checksums.txt checksums.txt.sig; do
  curl -fsSL --retry 3 -o "${out}/${asset}" "${base}/${asset}"
done
curl -fsSL --retry 3 -o "${out}/COPYING" \
  "https://raw.githubusercontent.com/${UPSTREAM_REPO}/${tag}/COPYING"

openssl pkeyutl -verify -pubin -rawin \
  -inkey "${root}/upstream/public_key.pem" \
  -sigfile "${out}/checksums.txt.sig" \
  -in "${out}/checksums.txt"

for asset in "${BINARIES[@]}"; do
  sum=$(awk -v name="${asset}" '$2 == name { print $1 }' "${out}/checksums.txt")
  [[ -n ${sum} ]] || {
    echo "${asset} is not listed in checksums.txt" >&2
    exit 1
  }
  echo "${sum}  ${out}/${asset}" | sha256sum --check --strict
done

digest=$(gh api "repos/${UPSTREAM_REPO}/releases/tags/${tag}" \
  --jq '.assets[] | select(.name == "themes.zip") | .digest')
[[ ${digest} == sha256:* ]] || {
  echo "no sha256 digest reported for themes.zip" >&2
  exit 1
}
echo "${digest#sha256:}  ${out}/themes.zip" | sha256sum --check --strict
