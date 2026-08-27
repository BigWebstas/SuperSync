# Running SuperSync behind IIS (URL Rewrite + ARR)

`docker-compose.yml` intentionally ships **no TLS termination** — the container
serves plain HTTP on port `1900` and expects to sit behind your own reverse
proxy. On Windows Server that proxy is IIS, using the **URL Rewrite** and
**Application Request Routing (ARR)** modules.

A ready-to-use file is in [`docs/iis/web.config`](iis/web.config). This page
explains what it does and how to wire everything up.

SuperSync's sync API is plain request/response HTTP — there are **no
WebSockets**, so no `webSocket` handling is needed in IIS.

---

## 1. Install the IIS modules

On the Windows box running IIS:

1. **URL Rewrite 2.1** — <https://www.iis.net/downloads/microsoft/url-rewrite>
2. **Application Request Routing 3.0** — <https://www.iis.net/downloads/microsoft/application-request-routing>

(Both install cleanly via the [Web Platform Installer](https://www.microsoft.com/web/downloads/platform.aspx)
or the standalone MSIs.)

Then **enable the proxy** — this is the step everyone forgets:

- IIS Manager → select the **server** node (top of the tree)
- open **Application Request Routing Cache**
- right pane → **Server Proxy Settings…**
- tick **Enable proxy** → **Apply**

Without this, the rewrite rule returns HTTP 500.19 / 404.

---

## 2. Create the IIS site

1. Run the SuperSync stack somewhere reachable from the IIS host:
   ```powershell
   copy .env.example .env   # fill in the required values (see step 3)
   docker compose up -d
   ```
   By default the container publishes `1900:1900`, so from the IIS host the
   backend is `http://<docker-host>:1900` (or `http://127.0.0.1:1900` if IIS and
   Docker are on the same machine).

2. In IIS Manager, **Add Website**:
   - **Site name:** `supersync`
   - **Physical path:** an empty folder, e.g. `C:\inetpub\supersync`
     (no content is served from disk — every request is proxied)
   - **Binding:** `https`, host name `sync.example.com`, with a valid
     certificate. Use [win-acme](https://www.win-acme.com/) for a free
     Let's Encrypt cert, or import your own.
   - Optionally add a second `http` binding on port 80 so the HTTP→HTTPS
     redirect rule has something to catch.

3. Drop [`docs/iis/web.config`](iis/web.config) into that physical path. Edit the
   backend address in the **"Proxy to SuperSync"** rule if the container is not
   on `127.0.0.1:1900`.

---

## 3. Container environment (must match the public URL)

The app builds email links, passkey challenges and CORS checks from its
environment, **not** from the incoming request. Set these in `.env` to your
public HTTPS URL, otherwise login emails and passkeys break:

| Variable | Value | Why |
|---|---|---|
| `PUBLIC_URL` | `https://sync.example.com` | Base URL in verification / recovery emails. Must be the URL **users** hit, i.e. the IIS host. |
| `WEBAUTHN_RP_ID` | `sync.example.com` | Passkey relying-party ID — host only, no scheme/port. Changing it later invalidates existing passkeys. |
| `WEBAUTHN_ORIGIN` | `https://sync.example.com` | Passkey origin — must equal `PUBLIC_URL`. |
| `CORS_ORIGINS` | `https://app.super-productivity.com` (add your own web build origin if self-hosting the app, comma-separated) | Browser clients are rejected otherwise. Never use `*` — CORS runs with credentials. |
| `SMTP_*` | your mail relay | Required for email verification / account recovery. |

After changing `.env`: `docker compose up -d` (recreates the container).

In the Super Productivity app, set the sync provider's server URL to
`https://sync.example.com`.

---

## 4. What `web.config` does

| Piece | Purpose |
|---|---|
| `requestLimits maxAllowedContentLength="104857600"` | Raises IIS's 30 MB request-body cap to 100 MB. SuperSync uploads the whole sync payload in one PUT; large vaults exceed 30 MB. Bump higher if clients get **HTTP 413** on sync. |
| `HTTP to HTTPS` rule | 301-redirects any plain-HTTP request. Delete it if you have no HTTP binding or an upstream LB already does this. |
| `Proxy to SuperSync` rule | Rewrites every path to `http://127.0.0.1:1900/…`. `stopProcessing` + being last means it's the catch-all. |
| `serverVariables` → `X-Forwarded-Proto: https`, `X-Forwarded-Host` | Tells the backend the original request was HTTPS on the public host. ARR already adds `X-Forwarded-For`. |
| `allowedServerVariables` | URL Rewrite refuses to set server variables unless they're whitelisted here. |
| `httpErrors existingResponse="PassThrough"` | Stops IIS replacing the backend's JSON error bodies with IIS error pages. |

### Optional: preserve the Host header

By default ARR rewrites the `Host` header to the backend address
(`127.0.0.1:1900`). Because `PUBLIC_URL` is set explicitly, SuperSync doesn't
need the original Host, so the default is fine. If you *do* want it forwarded:
IIS Manager → server node → **Application Request Routing Cache** → **Server
Proxy Settings…** → tick **Preserve client IP in the following header** as
needed, and set `preserveHostHeader` via `%windir%\system32\inetsrv\appcmd`:

```powershell
appcmd.exe set config -section:system.webServer/proxy /preserveHostHeader:"True" /commit:apphost
```

### Optional: response buffering for large downloads

ARR buffers responses by default. For very large sync **downloads** you may want
to disable it (server-wide, ARR proxy settings → **Response buffer threshold** →
`0`). Not needed for typical use.

---

## 5. Verify

From the IIS host and from an external client:

```powershell
# health endpoint, straight through the proxy
curl.exe -i https://sync.example.com/health        # -> 200

# plain HTTP should redirect
curl.exe -i http://sync.example.com/health         # -> 301 to https
```

Then add the account in Super Productivity and run a sync.

### Troubleshooting

| Symptom | Cause |
|---|---|
| `HTTP 500.19` / `404` on every request | ARR proxy not enabled (step 1) |
| `502.3` / `504` | Backend address wrong, container down, or firewall between IIS and Docker host |
| Login email links point to `localhost:1900` | `PUBLIC_URL` not set in `.env` |
| Passkey registration fails | `WEBAUTHN_RP_ID` / `WEBAUTHN_ORIGIN` don't match the public host |
| Browser console CORS errors | client origin missing from `CORS_ORIGINS` |
| `HTTP 413` on sync | raise `maxAllowedContentLength` in `web.config` |
