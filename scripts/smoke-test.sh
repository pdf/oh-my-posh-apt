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

    # GitHub Pages serves the site with Cache-Control: max-age=600, so a CDN
    # edge can keep serving the previous index for up to 10 minutes after a
    # deploy. Wait past that with a margin.
    # apt-cache show exits 0 for a version that does not exist, so use madison.
    # Capture its output first: piping into grep -q kills apt-cache with
    # SIGPIPE on an early match, which pipefail reports as a failure.
    in_index() {
      local versions
      versions=$(apt-cache madison "$1")
      grep -qF " ${EXPECTED_VERSION}-1 |" <<<"${versions}"
    }
    deadline=$(($(date +%s) + 900))
    until apt-get update -qq && in_index oh-my-posh && in_index oh-my-posh-themes; do
      [ "$(date +%s)" -lt "${deadline}" ] || {
        echo "version ${EXPECTED_VERSION} not in the index after 15 minutes"
        exit 1
      }
      sleep 30
    done

    apt-get install -y -qq \
      "oh-my-posh=${EXPECTED_VERSION}-1" "oh-my-posh-themes=${EXPECTED_VERSION}-1" >/dev/null
    actual=$(oh-my-posh --version)
    echo "$(dpkg --print-architecture): oh-my-posh ${actual}"
    [ "${actual}" = "${EXPECTED_VERSION}" ]
    test -s /usr/share/oh-my-posh/themes/agnoster.omp.json
    test -s /usr/share/doc/oh-my-posh/copyright
    oh-my-posh print primary --config /usr/share/oh-my-posh/themes/agnoster.omp.json >/dev/null
  '
