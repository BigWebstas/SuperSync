# SuperSyncDocker

Publicly-published Docker Hub image for [Super Productivity](https://super-productivity.com)'s
"SuperSync" server (`packages/super-sync-server` in the
[super-productivity monorepo](https://github.com/super-productivity/super-productivity)).

Upstream only publishes a **private** image at `ghcr.io/super-productivity/supersync`
(see [issue #6225](https://github.com/super-productivity/super-productivity/issues/6225)),
so this repo rebuilds it from the official source and pushes a public image to Docker Hub
at `webstas/supersync`.

There are no upstream release tags — `master` is the only source of truth. This repo
rebuilds from `master` and tags the result with the upstream commit SHA and a build date,
in addition to `latest`.

## Building

```bash
./build.sh              # build only, tags: latest, <upstream-sha>, <YYYYMMDD>
PUSH=true ./build.sh     # build and push to Docker Hub
IMAGE=myuser/supersync ./build.sh   # override the target image name
```

The script does a shallow clone of upstream `master` into a temp dir and builds using
upstream's own `packages/super-sync-server/Dockerfile` unmodified — nothing here forks
or patches their source.

## Automated builds

`.github/workflows/build-and-push.yml` rebuilds and pushes daily (06:00 UTC) and on
manual dispatch, tracking upstream `master`. It needs two repo secrets:

- `DOCKERHUB_USERNAME` — your Docker Hub username
- `DOCKERHUB_TOKEN` — a Docker Hub access token (Account Settings → Security →
  New Access Token; needs Read & Write)

The image is pushed to `<DOCKERHUB_USERNAME>/supersync`.

## Running

```bash
cp .env.example .env   # fill in JWT_SECRET, POSTGRES_PASSWORD, PUBLIC_URL, SMTP_*
docker compose up -d
```

`docker-compose.yml` is a trimmed copy of upstream's compose file (no Caddy/TLS —
front it with your own reverse proxy) pointed at `webstas/supersync:latest` by default.
See upstream's
[env.example](https://github.com/super-productivity/super-productivity/blob/master/packages/super-sync-server/env.example)
for the full list of supported environment variables.

## Notes

- No Terms of Service / privacy policy is baked in. Upstream deliberately ships none —
  see the comments in `.env.example` and upstream's own `env.example` for the
  `PRIVACY_*` variables that generate one for *your* deployment.
- This image tracks upstream `master`, which has no stability guarantee. Pin to a
  specific `<sha>` tag rather than `latest` for anything you care about staying stable.
