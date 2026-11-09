#!/usr/bin/env bash
# Install a pinned, checksum-verified nfpm into /usr/local/bin (x86_64 only).
set -euo pipefail

VERSION=2.48.0
SHA256=6d7f9a28b2f397934403950fcbba83f598b08d02edbe79a0815b3b4897341750

work=$(mktemp -d)
trap 'rm -rf "${work}"' EXIT
curl -fsSL --retry 3 -o "${work}/nfpm.tar.gz" \
  "https://github.com/goreleaser/nfpm/releases/download/v${VERSION}/nfpm_${VERSION}_Linux_x86_64.tar.gz"
echo "${SHA256}  ${work}/nfpm.tar.gz" | sha256sum --check --strict
tar -xzf "${work}/nfpm.tar.gz" -C "${work}" nfpm
install -m 0755 "${work}/nfpm" /usr/local/bin/nfpm
