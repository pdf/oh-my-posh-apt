#!/usr/bin/env bash
# Build the signed apt repository from a directory of .debs. aptly's database
# is thrown away after each run: the .debs in the input are the only state.
#
# The signing key must already be in the GnuPG keyring.
#
# Usage: build-repo.sh <debs-dir> <site-dir>
set -euo pipefail

SIGNING_UID=oh-my-posh-apt@c0dedbad.com
REPO_NAME=oh-my-posh

debs=$(realpath "$1")
mkdir -p "$2"
site=$(realpath "$2")
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

fingerprint=$(gpg --batch --with-colons --list-secret-keys "<${SIGNING_UID}>" \
  | awk -F: '$1 == "fpr" { print $10; exit }')
[[ -n ${fingerprint} ]] || {
  echo "no secret key for ${SIGNING_UID} in the keyring" >&2
  exit 1
}

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT
cat >"${work}/aptly.conf" <<EOF
{
  "rootDir": "${work}/aptly",
  "gpgProvider": "gpg2",
  "architectures": []
}
EOF

aptly() { command aptly -config="${work}/aptly.conf" "$@"; }

aptly repo create -distribution=stable -component=main "${REPO_NAME}"
aptly repo add "${REPO_NAME}" "${debs}"
aptly publish repo -batch -gpg-key="${fingerprint}" \
  -architectures=amd64,arm64,armhf \
  -origin=oh-my-posh-apt -label="oh-my-posh (unofficial)" \
  -acquire-by-hash \
  "${REPO_NAME}"

# Copy with links resolved: aptly hardlinks and symlinks its output.
cp -rL "${work}/aptly/public/." "${site}/"
gpg --batch --export "${fingerprint}" >"${site}/key.gpg"
cp "${root}/site/index.html" "${site}/index.html"

gpg --batch --with-colons --show-keys "${site}/key.gpg" | grep -q "<${SIGNING_UID}>"
echo "signed with ${fingerprint}"
