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
