#!/usr/bin/env bash
# filename: ./scripts/pull_activity.sh
# date: 05.10.2026

set -euo pipefail

: "${GITLAB_TOKEN:?set GITLAB_TOKEN}"
: "${SOURCE_PROJECT_ID:?set SOURCE_PROJECT_ID}"

for cmd in jq unzip curl sed grep mv; do
    command -v "${cmd}" >/dev/null \
        || { exit 1; }
done

SOURCE_BRANCH="${SOURCE_BRANCH:-main}"
SOURCE_JOB="${SOURCE_JOB:-fetch-activity}"
DEST="${DEST:-./src/activity_graph.svg}"

API_BASE="https://gitlab.com/api/v4/projects/${SOURCE_PROJECT_ID}"

WORKDIR="$( mktemp -d )"
trap 'rm -rf "${WORKDIR}"' EXIT

PIPELINE_ID=$( curl -s --fail-with-body \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${API_BASE}/pipelines?ref=${SOURCE_BRANCH}&status=success&order_by=id&sort=desc&per_page=1" \
    | jq -r '.[0].id // empty' )

if [ -z "${PIPELINE_ID}" ]; then
    exit 1
fi

JOB_ID=$( curl -s --fail-with-body \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    "${API_BASE}/pipelines/${PIPELINE_ID}/jobs?per_page=100" \
    | jq -r --arg name "${SOURCE_JOB}" '.[] | select(.name==$name) | .id' \
    | head -n1 )

if [ -z "${JOB_ID}" ]; then
    exit 1
fi

curl --fail-with-body \
    --silent --show-error \
    --location \
    --retry 3 --retry-delay 2 --retry-connrefused \
    --connect-timeout 10 --max-time 30 \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --output "${WORKDIR}/artifacts.zip" \
    "${API_BASE}/jobs/${JOB_ID}/artifacts"

if ! unzip -q "${WORKDIR}/artifacts.zip" -d "${WORKDIR}/extracted"; then
    exit 1
fi

SVG=$( find "${WORKDIR}/extracted" -maxdepth 1 -type f -name 'activity_graph_*.svg' \
    -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2- )

if [ -z "${SVG}" ]; then
    exit 1
fi

if [[ ! -d "$( dirname "${DEST}" )" ]]; then
    if ! mkdir -p "$( dirname "${DEST}" )"; then
        exit 1
    fi
fi

if ! mv "${SVG}" "${DEST}"; then
    exit 1
fi

if grep -qF '<desc>' "${DEST}"; then
    if ! sed -i "s|<desc>[^<]*</desc>|<desc>${JOB_ID}</desc>|" "${DEST}"; then
        exit 1
    fi
else
    if ! sed -i "0,/<svg[^>]*>/s//&<desc>${JOB_ID}<\/desc>/" "${DEST}"; then
        exit 1
    fi
fi

if [[ ! -s "${DEST}" ]]; then
    exit 1
fi

if ! grep -q "<desc>${JOB_ID}</desc>" "${DEST}"; then
    exit 1
fi

sed -i 's|<text[^>]*class="graph-label"[^>]*>[^<]*</text>||g' "${DEST}" || true

exit 0
