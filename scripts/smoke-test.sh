#!/usr/bin/env bash
# Follow the README's install steps in a clean container and check the result.
#
# Usage: smoke-test.sh <repo-url> <docker-platform> <image> <version>
set -euo pipefail

url=$1
platform=$2
image=$3
version=$4

docker run --rm --network host --platform "${platform}" \
  -e REPO_URL="${url}" -e EXPECTED_VERSION="${version}" \
  "${image}" bash -euo pipefail -c '
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends ca-certificates curl >/dev/null

    install -d -m 0755 /etc/apt/keyrings
    curl -fsSL "${REPO_URL}/key.gpg" -o /etc/apt/keyrings/oh-my-posh-apt.gpg
    cat >/etc/apt/sources.list.d/oh-my-posh-apt.sources <<EOF
Types: deb
URIs: ${REPO_URL}
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/oh-my-posh-apt.gpg
EOF

    # A freshly deployed site can be served stale by the CDN for a few minutes.
    for attempt in 1 2 3 4 5 6; do
      apt-get update -qq
      if apt-cache show "oh-my-posh=${EXPECTED_VERSION}-1" >/dev/null 2>&1; then
        break
      fi
      [ "${attempt}" -lt 6 ] || { echo "version ${EXPECTED_VERSION} not in the index"; exit 1; }
      sleep 60
    done

    apt-get install -y -qq oh-my-posh oh-my-posh-themes >/dev/null
    actual=$(oh-my-posh --version)
    echo "$(dpkg --print-architecture): oh-my-posh ${actual}"
    [ "${actual}" = "${EXPECTED_VERSION}" ]
    test -s /usr/share/oh-my-posh/themes/agnoster.omp.json
    test -s /usr/share/doc/oh-my-posh/copyright
    oh-my-posh print primary --config /usr/share/oh-my-posh/themes/agnoster.omp.json >/dev/null
  '
