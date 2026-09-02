#!/usr/bin/env bash
# Builds the Super Productivity "SuperSync" server image from upstream source
# and tags it for Docker Hub. Upstream only ships a private GHCR image
# (ghcr.io/super-productivity/supersync), so this rebuilds it from the
# official source in packages/super-sync-server for a public Docker Hub push.
set -euo pipefail

UPSTREAM_REPO="https://github.com/super-productivity/super-productivity.git"
UPSTREAM_BRANCH="master"
IMAGE="${IMAGE:-webstas/supersync}"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Cloning ${UPSTREAM_REPO}#${UPSTREAM_BRANCH} (shallow)"
git clone --depth 1 --branch "$UPSTREAM_BRANCH" "$UPSTREAM_REPO" "$WORKDIR"

VCS_REF="$(git -C "$WORKDIR" rev-parse --short HEAD)"
DATE_TAG="$(date +%Y%m%d)"

# --- Make upstream's hardcoded sync rate limits runtime-configurable --------
# Upstream exposes no runtime env var for these. This rewrites the hardcoded
# constants into `Number(process.env.X) || <upstream default>` reads, so the
# SAME published image honours two vars set at container start — no rebuild
# needed to tune them:
#   SYNC_UPLOAD_RATE_LIMIT_MAX  per-user + per-IP POST /api/sync/ops cap
#                               (upstream default: 100 per minute)
#   SYNC_GLOBAL_RATE_LIMIT_MAX  global per-IP request cap
#                               (upstream default: 500 per 15 minutes)
# The injected expression is inert when the var is unset, empty, or non-numeric
# (it falls back to the upstream default), so a stock deployment behaves exactly
# like upstream. Each rewrite is verified: if upstream refactors the target line
# the build fails loudly rather than silently shipping an un-patched (and now
# un-configurable) limit. Set FAITHFUL_REBUILD=true to skip all rewrites and
# produce a byte-faithful image with the limits hardcoded as upstream ships them.
_patch_rate_limit() {
  local file="$1" from="$2" to="$3"
  # '#' delimiter: the replacement text contains '||', which collides with sed's
  # usual '|' delimiter. No target/replacement string here contains '#'.
  sed -i "s#${from}#${to}#" "$file"
  if grep -qF "$from" "$file"; then
    echo "!! rate-limit patch failed: '${from}' still present in ${file##*/}" >&2
    echo "   upstream changed this line — update build.sh" >&2
    exit 1
  fi
}

if [[ "${FAITHFUL_REBUILD:-false}" == "true" ]]; then
  echo "==> FAITHFUL_REBUILD=true — leaving sync rate limits hardcoded as upstream ships them"
else
  echo "==> Making sync rate limits runtime-configurable (SYNC_UPLOAD_RATE_LIMIT_MAX, SYNC_GLOBAL_RATE_LIMIT_MAX)"
  SS="$WORKDIR/packages/super-sync-server/src"
  _patch_rate_limit "$SS/sync/sync.types.ts" \
    "uploadRateLimit: { max: 100," \
    "uploadRateLimit: { max: Number(process.env.SYNC_UPLOAD_RATE_LIMIT_MAX) || 100,"
  _patch_rate_limit "$SS/sync/sync.routes.ts" \
    "max: 100," \
    "max: Number(process.env.SYNC_UPLOAD_RATE_LIMIT_MAX) || 100,"
  _patch_rate_limit "$SS/server.ts" \
    "max: 500," \
    "max: Number(process.env.SYNC_GLOBAL_RATE_LIMIT_MAX) || 500,"
fi

echo "==> Building ${IMAGE}:latest / :${VCS_REF} / :${DATE_TAG} (upstream ${VCS_REF})"
docker build \
  -f "$WORKDIR/packages/super-sync-server/Dockerfile" \
  --build-arg "VCS_REF=$VCS_REF" \
  -t "${IMAGE}:latest" \
  -t "${IMAGE}:${VCS_REF}" \
  -t "${IMAGE}:${DATE_TAG}" \
  "$WORKDIR"

echo "==> Built:"
docker images "${IMAGE}"

if [[ "${PUSH:-false}" == "true" ]]; then
  echo "==> Pushing ${IMAGE} (latest, ${VCS_REF}, ${DATE_TAG})"
  docker push "${IMAGE}:latest"
  docker push "${IMAGE}:${VCS_REF}"
  docker push "${IMAGE}:${DATE_TAG}"
else
  echo "==> Skipping push (set PUSH=true to push to Docker Hub)"
fi
