#!/usr/bin/env bash
# Download the .debs of the newest published versions from this repo's releases.
# Old packages are reused rather than rebuilt, so their hashes never change.
#
# Usage: download-published.sh <repo> <output-dir> <tag>
#
# <tag> is the release this run publishes. It is always included: the release
# list endpoint can lag behind a release created seconds earlier, which would
# otherwise drop the new version from the repository.
set -euo pipefail

KEEP_VERSIONS=5

repo=$1
out=$2
tag=$3
mkdir -p "${out}"

[[ ${tag} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "refusing tag '${tag}': not a stable vX.Y.Z tag" >&2
  exit 1
}

tags=$({
  gh api --paginate "repos/${repo}/releases" \
    --jq '.[] | select((.draft or .prerelease) | not) | .tag_name'
  echo "${tag}"
} | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | sort -uV \
  | tail -n "${KEEP_VERSIONS}")

grep -qxF "${tag}" <<<"${tags}" || {
  echo "${tag} is older than the ${KEEP_VERSIONS} newest releases" >&2
  exit 1
}

for t in ${tags}; do
  echo "using ${t}"
  gh release download "${t}" --repo "${repo}" --pattern '*.deb' --dir "${out}" --clobber
done

version=${tag#v}
for deb in oh-my-posh_"${version}"-1_{amd64,arm64,armhf}.deb oh-my-posh-themes_"${version}"-1_all.deb; do
  [[ -s ${out}/${deb} ]] || {
    echo "${deb} is missing from the ${tag} release" >&2
    exit 1
  }
done
