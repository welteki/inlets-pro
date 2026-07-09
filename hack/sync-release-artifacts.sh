#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <source-oci-image> <target-repo> [tag]" >&2
  echo "Example: $0 ghcr.io/openfaasltd/inlets-pro-artifacts inlets/inlets-pro 0.11.13" >&2
}

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  usage
  exit 1
fi

source_image="$1"
target_repo="$2"
tag="${3:-}"

sync_release() {
  local source_tag="$1"
  local tmpdir

  tmpdir="$(mktemp -d -t inlets-pro-artifacts-XXXXXXXX)"
  trap 'rm -rf "${tmpdir}"' RETURN

  crane export "${source_image}:${source_tag}" - | tar -x -C "${tmpdir}"

  if ! gh release view "${source_tag}" --repo "${target_repo}" >/dev/null 2>&1; then
    # Public releases are upload buckets for private builds, not code-based releases.
    # If the tag is missing, gh creates it against the public default branch.
    gh release create "${source_tag}" --repo "${target_repo}" --title "${source_tag}" --notes "" >/dev/null
  fi

  gh release upload "${source_tag}" "${tmpdir}"/* --repo "${target_repo}" --clobber >&2
}

if [ -n "${tag}" ]; then
  source_tags="${tag}"
else
  source_tags="$(crane ls "${source_image}" | sort -V)"
fi

existing_releases="$(gh release list --repo "${target_repo}" --limit 1000 --json tagName --jq '.[].tagName')"

synced=0
skipped=0

echo "### Release artifact sync"
echo
echo "| Tag | Result |"
echo "| --- | --- |"

for source_tag in ${source_tags}; do
  if [ -z "${tag}" ] && echo "${existing_releases}" | grep -Fxq "${source_tag}"; then
    skipped=$((skipped + 1))
    continue
  fi

  sync_release "${source_tag}"

  echo "| \`${source_tag}\` | Synced |"
  synced=$((synced + 1))
done

echo
echo "Synced: ${synced}"
echo "Skipped: ${skipped}"
