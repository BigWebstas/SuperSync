# SuperSyncDocker

A public Docker Hub image for [Super Productivity](https://super-productivity.com)'s
**SuperSync** server (`packages/super-sync-server` in the
[super-productivity monorepo](https://github.com/super-productivity/super-productivity)).

Upstream only publishes a **private** image
([issue #6225](https://github.com/super-productivity/super-productivity/issues/6225)),
so this repo rebuilds it from source, unmodified, and pushes a public image to
`webstas/supersync`. There are no upstream release tags — `master` is the only
source of truth, so each build is tagged with `latest`, the upstream commit SHA,
and a build date. **Pin to a `<sha>` tag, not `latest`, for anything you care
about.**

## Running

```bash
cp .env.example .env   # fill in JWT_SECRET, POSTGRES_PASSWORD, PUBLIC_URL, SMTP_*
docker compose up -d
```

`docker-compose.yml` is a trimmed copy of upstream's — no Caddy/TLS, so front it
with your own reverse proxy. SuperSync needs its own PostgreSQL 16 database; the
compose file does not bundle one. See upstream's
[env.example](https://github.com/super-productivity/super-productivity/blob/master/packages/super-sync-server/env.example)
for every supported variable.

Behind IIS on Windows Server? See
[`docs/reverse-proxy-iis.md`](docs/reverse-proxy-iis.md) and the ready-made
[`web.config`](docs/iis/web.config).

## Unraid

Ships a Community Applications template at
[`templates/supersync.xml`](templates/supersync.xml). Add this repo as a template
repository (Apps → Settings → Template Repositories):
`https://github.com/BigWebstas/SuperSync`. Install a separate PostgreSQL 16
container first, then set the **Database URL** field.

## Notes

- No Terms of Service / privacy policy is baked in — upstream ships none. Set the
  `PRIVACY_*` variables to generate one for your deployment.
- `latest` tracks upstream `master`, which has no stability guarantee.
- Upstream's sync upload rate limits are compiled in, with no runtime env var:
  100 uploads/min on `POST /api/sync/ops` (enforced per user *and* per IP), plus
  a 500-request / 15-minute global per-IP cap. Behind a reverse proxy every
  client shares one IP, so the per-IP caps bite sooner. `build.sh` can raise them
  at build time — `SYNC_UPLOAD_RATE_LIMIT_MAX=1000 ./build.sh` and/or
  `SYNC_GLOBAL_RATE_LIMIT_MAX=5000 ./build.sh`. Both are unset by default, so the
  published image stays an unmodified rebuild; each patch is verified and fails
  the build if upstream moves the target line.
