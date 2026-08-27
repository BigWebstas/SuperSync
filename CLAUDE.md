# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo contains **no application source code**. It only builds and publishes a Docker image
that repackages a third party's server unmodified, plus deployment artifacts for running it.

- Upstream project: [super-productivity/super-productivity](https://github.com/super-productivity/super-productivity),
  specifically `packages/super-sync-server` — the self-hostable sync backend for the Super
  Productivity app.
- Upstream only publishes a **private** GHCR image for that server. This repo shallow-clones
  upstream `master`, builds their `packages/super-sync-server/Dockerfile` unmodified, and pushes
  the result publicly to Docker Hub as `webstas/supersync`.
- There are no upstream release tags — `master` is the only source of truth, so images are tagged
  with `latest`, the upstream commit SHA, and a build date (`YYYYMMDD`).

Because the actual server source lives upstream, don't look in this repo for application logic,
tests, or a package.json — there isn't one. Changes here are about the build/publish pipeline and
the deployment artifacts (compose file, Unraid template, `docs/`), not server behavior.

## Commands

```bash
./build.sh                          # build only; tags: latest, <upstream-sha>, <YYYYMMDD>
PUSH=true ./build.sh                # build and push to Docker Hub
IMAGE=myuser/supersync ./build.sh   # override the target image name (default webstas/supersync)
```

`build.sh` does a shallow clone of upstream `master` into a temp dir (cleaned up via `trap`) and
builds using upstream's own `packages/super-sync-server/Dockerfile` as-is — this repo never forks
or patches upstream source.

Running the built image locally:

```bash
cp .env.example .env   # fill in JWT_SECRET, POSTGRES_PASSWORD, PUBLIC_URL, SMTP_*
docker compose up -d
```

There is no lint/test suite in this repo.

## Architecture / how the pieces fit together

- **`build.sh`** — the only build logic. Clones upstream, builds, tags three ways, optionally
  pushes. Any change to what gets built starts here.
- **`.github/workflows/build-and-push.yml`** — runs `build.sh` with `PUSH=true` on a daily cron
  (06:00 UTC, since upstream has no release tags to react to), on manual dispatch, and on pushes
  to `main` that touch `build.sh` or the workflow file itself. Needs `DOCKERHUB_USERNAME` and
  `DOCKERHUB_TOKEN` repo secrets; the image is pushed to `<DOCKERHUB_USERNAME>/supersync`.
- **`docker-compose.yml`** — a trimmed copy of upstream's compose file (no Caddy/TLS — intended to
  sit behind the user's own reverse proxy) pointed at `webstas/supersync:latest`. Mirrors the env
  vars upstream's server supports; keep it in sync with upstream's
  `packages/super-sync-server/env.example` when upstream adds/removes variables.
- **`.env.example`** — documents the env vars `docker-compose.yml` consumes, with the required
  ones (`JWT_SECRET`, `POSTGRES_PASSWORD`, `PUBLIC_URL`) called out separately from optional ones.
- **`templates/supersync.xml`** + **`ca_profile.xml`** — Unraid Community Applications template
  and repo profile (per [ca.unraid.net/submit](https://ca.unraid.net/submit)). The template's
  `<Config>` entries are a parallel representation of the same env vars as `.env.example` /
  `docker-compose.yml` — when adding or changing a supported env var, update all three in lockstep
  (upstream env var list → `.env.example` → `docker-compose.yml` environment block →
  `templates/supersync.xml` `<Config>`).
- **`docs/`** — deployment guides for fronting the container with a specific reverse proxy.
  Currently `docs/reverse-proxy-iis.md` (IIS + URL Rewrite/ARR) plus the sample
  `docs/iis/web.config` it references. These restate env vars like `PUBLIC_URL`, `WEBAUTHN_*`
  and `CORS_ORIGINS`, so include them in the lockstep update when those change.

## Notes for making changes

- Never modify upstream server behavior from this repo — this repo's whole value proposition is
  that it's an unmodified rebuild. If upstream needs a code change, that's a PR to
  `super-productivity/super-productivity`, not here.
- `templates/supersync.xml` requires a separate, unbundled PostgreSQL 16 instance — don't add a
  bundled Postgres container to it or to `docker-compose.yml`'s Unraid story without checking that
  assumption still holds.
- Since upstream has no stable release tags, treat `latest` as a moving target tracking upstream
  `master`; the SHA/date tags exist so users can pin to something stable.
