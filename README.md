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


## Running

```bash
cp .env.example .env   # fill in JWT_SECRET, POSTGRES_PASSWORD, PUBLIC_URL, SMTP_*
docker compose up -d
```

`docker-compose.yml` is a trimmed copy of upstream's compose file (no Caddy/TLS —
front it with your own reverse proxy) pointed at `webstas/supersync:latest` by default.

Running it behind IIS on Windows Server? See
[`docs/reverse-proxy-iis.md`](docs/reverse-proxy-iis.md) for a URL Rewrite + ARR
walkthrough and a ready-made [`web.config`](docs/iis/web.config).

See upstream's
[env.example](https://github.com/super-productivity/super-productivity/blob/master/packages/super-sync-server/env.example)
for the full list of supported environment variables.

## Unraid

This repo ships a Community Applications template at
[`templates/supersync.xml`](templates/supersync.xml), plus a
[`ca_profile.xml`](ca_profile.xml) describing the repo, as required by
[ca.unraid.net/submit](https://ca.unraid.net/submit).

To use it before/without an official CA listing, add this repo as a template
repository in the Community Applications plugin (Apps → Settings → Template
Repositories): `https://github.com/BigWebstas/SuperSync`.

SuperSync needs its own PostgreSQL 16 database — the template does not bundle
one. Install a Postgres container first (e.g. the official `postgres:16-alpine`
image via a separate CA template), create a database/user for SuperSync, then
fill in the **Database URL** field with the resulting connection string.

## Notes

- No Terms of Service / privacy policy is baked in. Upstream deliberately ships none —
  see the comments in `.env.example` and upstream's own `env.example` for the
  `PRIVACY_*` variables that generate one for *your* deployment.
- This image tracks upstream `master`, which has no stability guarantee. Pin to a
  specific `<sha>` tag rather than `latest` for anything you care about staying stable.
