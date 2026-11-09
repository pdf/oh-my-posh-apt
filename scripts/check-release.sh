#!/usr/bin/env bash
# Decide whether a publish is needed.
#
# Usage: check-release.sh [force]
# Prints key=value lines (tag, publish, keepalive), and appends them to
# $GITHUB_OUTPUT when running in Actions.
set -euo pipefail

UPSTREAM_REPO=JanDeDobbeleer/oh-my-posh
STATE_FILE="published-version"
KEEPALIVE_DAYS=45
force=${1:-false}

# /releases/latest already leaves out drafts and prereleases. Check both the
# flag and the tag shape anyway, so a prerelease can never be published.
release=$(gh api "repos/${UPSTREAM_REPO}/releases/latest" \
  --jq '[.tag_name, (.prerelease or .draft | tostring)] | @tsv')
latest=${release%%$'\t'*}
unstable=${release##*$'\t'}

published=""
if [[ -s ${STATE_FILE} ]]; then
  published=$(<"${STATE_FILE}")
fi

tag=""
if [[ ${unstable} == false && ${latest} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  tag=${latest}
else
  echo "ignoring upstream release '${latest}' (not a stable vX.Y.Z release)" >&2
fi

publish=false
if [[ -n ${tag} ]]; then
  newest=$(printf '%s\n%s\n' "${published}" "${tag}" | sort -V | tail -n 1)
  if [[ ${tag} != "${published}" && ${newest} == "${tag}" ]]; then
    publish=true
  elif [[ ${force} == true ]]; then
    publish=true
  fi
fi

# With no upstream release for a long time there is nothing to commit, so ask
# for an empty commit before GitHub's 60-day inactivity limit is reached.
last_commit=$(git log -1 --format=%ct)
age_days=$((($(date +%s) - last_commit) / 86400))
keepalive=false
if [[ ${publish} == false && ${age_days} -ge ${KEEPALIVE_DAYS} ]]; then
  keepalive=true
fi

{
  echo "tag=${tag}"
  echo "publish=${publish}"
  echo "keepalive=${keepalive}"
} | tee -a "${GITHUB_OUTPUT:-/dev/null}"
