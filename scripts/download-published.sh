#!/usr/bin/env bash
# Download the .debs of the newest published versions from this repo's releases.
# Old packages are reused rather than rebuilt, so their hashes never change.
#
# Usage: download-published.sh <repo> <output-dir>
set -euo pipefail

KEEP_VERSIONS=5

repo=$1
out=$2
mkdir -p "${out}"

tags=$(gh api --paginate "repos/${repo}/releases" \
  --jq '.[] | select((.draft or .prerelease) | not) | .tag_name' \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -V \
  | tail -n "${KEEP_VERSIONS}")

[[ -n ${tags} ]] || {
  echo "no published releases found in ${repo}" >&2
  exit 1
}

for tag in ${tags}; do
  echo "using ${tag}"
  gh release download "${tag}" --repo "${repo}" --pattern '*.deb' --dir "${out}" --clobber
done
