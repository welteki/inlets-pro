#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <source-image> <target-image> [tag]" >&2
  echo "Example: $0 ghcr.io/openfaasltd/inlets-pro ghcr.io/inlets/inlets-pro 0.11.13" >&2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
  exit 1
fi

source_image="$1"
target_image="$2"
tag="${3:-}"

if [ -n "${tag}" ]; then
  source_tags="${tag}"
else
  source_tags="$(crane ls "${source_image}" | sort -V)"
fi

target_tags_err="$(mktemp)"
trap 'rm -f "${target_tags_err}"' EXIT

if target_tags="$(crane ls "${target_image}" 2>"${target_tags_err}" | sort -V)"; then
  :
elif grep -q "NAME_UNKNOWN" "${target_tags_err}"; then
  target_tags=""
else
  cat "${target_tags_err}" >&2
  exit 1
fi

copied=0
skipped=0

echo "### Image sync"
echo
echo "| Tag | Result |"
echo "| --- | --- |"

for source_tag in ${source_tags}; do
  if echo "${target_tags}" | grep -Fxq "${source_tag}"; then
    skipped=$((skipped + 1))
    continue
  fi

  crane cp "${source_image}:${source_tag}" "${target_image}:${source_tag}" >&2
  echo "| \`${source_tag}\` | Copied |"
  copied=$((copied + 1))
done

echo
echo "Copied: ${copied}"
echo "Skipped: ${skipped}"
