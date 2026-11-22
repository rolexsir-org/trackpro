# Track Pro — Railway Production Deployment

This guide covers deploying the **Track Pro billing verification service** in
`billing_server/` to [Railway](https://railway.com). The service verifies Google
Play purchase tokens, stores the resulting entitlements, and processes Real-time
Developer Notifications (RTDN). It is a self-contained Node 20 service with
**zero runtime dependencies** (only `node:*` built-ins).

> The Android app is **never** trusted as the authority for Pro entitlements.
> Every purchase is re-verified server-side against the Google Play Developer
> API, and the server is **fail-closed**: a forged, expired, refunded, or
> unreachable purchase never grants Pro. See `MONETIZATION.md` and `README.md`.

---

## 1. Railway ↔ GitHub connection

1. In Railway, create a new **Project** (or use an existing one).
2. **New Service → GitHub Repo** and select `rolexsir-org/trackpro`.
3. After the repo is linked, **do not** let Railway auto-deploy yet. First:
   - Open the new service → **Settings → Source**.
   - Set **Root Directory** to **`billing_server`**. This tells Railway to build
     from `billing_server/Dockerfile` with `billing_server/` as the build
     context, so the relative `COPY` paths in the Dockerfile resolve correctly.
4. Add a **Volume** (see §8) **before** the first production deploy.
5. Add the environment variables (see §4).
6. Trigger a deploy from the latest commit.

Railway reads `railway.toml` (committed at the repo root) for the build builder
and deploy health-check/restart settings, so most of the configuration below is
already encoded — you still must set the **Root Directory** and the **env vars**
in the dashboard.

---

## 2. Repository & service root directory

| Item | Value |
|---|---|
| Repo | `rolexsir-org/trackpro` |
| **Service Root Directory** | **`billing_server`** (required) |
| Dockerfile | `billing_server/Dockerfile` |
| Start command | `node src/index.js` (the Dockerfile `ENTRYPOINT` runs it) |
| Listening | `0.0.0.0:$PORT` — Railway injects `PORT` at runtime |

Because the service lives in a subdirectory, setting the **Root Directory** is
the single most important dashboard step. Without it, Railway builds from the
repo root and cannot find `package.json`/`Dockerfile`.

---

## 3. Build & start commands

**Recommended — Docker (already configured & security-hardened):**

Railway auto-detects the Dockerfile once the Root Directory is `billing_server`.
The image:

- is based on `node:20-alpine`,
- contains **only** `package.json`, `package-lock.json` and `src/` (no tests, no
  dev dependencies — see `.dockerignore`),
- runs the process as the unprivileged `node` user,
- has a built-in `HEALTHCHECK` on `/healthz`.

No `npm install` runs at runtime (zero runtime deps). The committed
`package-lock.json` makes any install reproducible (`npm ci` in CI/`Nixpacks`).

**Alternative — Nixpacks (no Dockerfile):** if you prefer not to use the
Dockerfile, delete/ignore it and let Railway use Nixpacks: it will run
`npm install` then `npm start` (`start` → `node src/index.js`). The same env
vars and volume apply. The Dockerfile path is recommended for the explicit
non-root, secret-free image.

Local smoke test (optional):

```bash
cd billing_server
docker build -t trackpro-billing .
docker run --rm -p 8080:8080 \
  -e TRACK_BILLING_API_KEYS="$TRACK_BILLING_API_KEYS" \
  -e TRACK_RTDN_SECRET="$TRACK_RTDN_SECRET" \
  -v "$PWD/play-service-account.json:/run/secrets/play-service-account.json:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/play-service-account.json \
  -v trackpro-billing-data:/data \
  trackpro-billing
curl -s http://127.0.0.1:8080/healthz   # -> {"ok":true}
```

---

## 4. Required environment variables

Set these in **Railway → Service → Variables**. Never commit them; the
`.env.example` file in this folder contains placeholders only.

| Variable | Required | Source / how to set | Purpose |
|---|---|---|---|
| `PORT` | no | Railway injects it | Listening port. Server defaults to `8080` if unset. |
| `TRACK_BILLING_API_KEYS` | **yes** | Generate a long random value, e.g. `openssl rand -hex 32` | Comma-separated bearer keys accepted on `POST /billing/verify`. Two values are supported for zero-downtime rotation. |
| `TRACK_RTDN_SECRET` | **yes** | `openssl rand -hex 32` | Bearer token Google Pub/Sub must present on `POST /rtdn`. |
| `GOOGLE_APPLICATION_CREDENTIALS` | one of the two | Path to a mounted service-account JSON (see §5) | File path variant. |
| `GOOGLE_APPLICATION_CREDENTIALS_JSON` | one of the two | Paste the entire service-account JSON as a string | Inline variant — easiest for Railway variable injection. Takes precedence over the path variant. |
| `TRACK_STORE_PATH` | **yes** | Default in image: `/data/purchases.json` | Path to the persistent JSON purchase ledger. Keep it **inside the volume** (`/data`). |
| `TRACK_REQUEST_TIMEOUT_MS` | no | Default `30000` | Per-connection socket timeout (slowloris defense). Applied to `requestTimeout`/`headersTimeout`; `keepAliveTimeout` is fixed at 61s. |

**Startup contract (enforced by the service):** the process **refuses to start**
if `TRACK_BILLING_API_KEYS`, `TRACK_RTDN_SECRET`, `TRACK_STORE_PATH`, **or** a
valid Google credential (`GOOGLE_APPLICATION_CREDENTIALS` path or
`GOOGLE_APPLICATION_CREDENTIALS_JSON`) is missing/invalid. This is intentional —
a billing service that starts without authentication would accept forged tokens.

---

## 5. Google Cloud service-account setup

The server signs an RS256 JWT with the service account's private key and calls
the Google Play Android Developer API. It never sends the private key off the
machine and never logs it.

1. In **Google Cloud Console**, open the project that is **linked to your Play
   app** (Play Console → *Setup → API access* shows the linked GCP project).
2. **IAM & Admin → Service Accounts → Create service account**
   (e.g. `trackpro-billing-verifier`).
3. **Keys → Add key → Create new key → JSON**. Download the JSON. This file is
   the credential — store it in a secret manager / Railway secret, **never in
   git** (`.gitignore` already blocks `*service-account*.json`,
   `credentials.json`, etc.).
4. Enable the **Google Play Android Developer API** for that GCP project
   (*APIs & Services → Library*).
5. In **Play Console → Users & permissions**, grant the service-account email
   at least **View financial data** (read-only monetization access), scoped to
   the `com.track.app` app.

Provide the credentials to Railway via **one** of:

- **Inline (recommended for Railway):** paste the whole JSON into the
  `GOOGLE_APPLICATION_CREDENTIALS_JSON` variable.
- **Mounted secret file:** upload the JSON as a Railway **secret file** mounted
  at, e.g., `/run/secrets/play-service-account.json` and set
  `GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/play-service-account.json`.

The client calls exactly:

- `GET …/applications/{pkg}/purchases/subscriptionsv2/{productId}/tokens/{token}`
- `GET …/applications/{pkg}/purchases/products/{productId}/tokens/{token}`

---

## 6. Google Play API permissions

| Permission | Where | Why |
|---|---|---|
| **View financial data** | Play Console → Users & permissions | Minimum read access needed to verify purchases. Do **not** grant admin. |
| **Google Play Android Developer API** | GCP → APIs & Services | The API the verifier calls. |
| App scope = `com.track.app` | Play Console | The verifier rejects any other `packageName` (`EXPECTED_PACKAGE`). |

Catalogue allowlist (hard-coded in `src/verifier.js`, do not change without a
reason): `track_pro_monthly`, `track_pro_annual` (subscriptions) and
`track_pro_lifetime` (one-time product). Any other `productId` is rejected.

---

## 7. RTDN / Pub/Sub configuration

Real-time Developer Notifications keep the stored entitlement in sync (renewals,
cancellations, refunds, revocations, expirations).

1. **GCP → Pub/Sub → Topics → Create** (e.g. `trackpro-rtdn`).
2. **Create a push subscription** to `https://<your-domain>/rtdn`.
   - The server requires `Authorization: Bearer <TRACK_RTDN_SECRET>` on this
     endpoint. Configure the subscription's **push `headers`** to attach that
     `Authorization` header (Google Pub/Sub push config supports custom headers;
     verify the exact field name against current Google docs / `gcloud
     pubsub subscriptions create … --push-header`). The bearer secret must equal
     the `TRACK_RTDN_SECRET` variable.
   - Optional hardening: also enable **OIDC token** on the subscription and
     restrict the endpoint at your proxy. The current server authenticates via
     the shared secret only — see *Known limitations* below.
3. **Play Console → Monetization → Real-time developer notifications** → point
   the topic at the one you created. Send a **test notification** (Play Console
   provides a button) and confirm `POST /rtdn` returns `200
   {"ok":true,"action":"test_notification"}`.
4. The handler is **fail-closed**: RTDN can only *revoke/update*; it can never
   *grant* Pro. An unknown token or a malformed envelope is a safe no-op (or a
   400 that stops redelivery); a **storage failure returns 503** so Pub/Sub
   redelivers instead of dropping a revocation.

---

## 8. Persistent volume requirements

The purchase ledger is a **file-backed JSON store** at `TRACK_STORE_PATH`. The
container filesystem is **ephemeral** — without a volume, every redeploy/restarts
wipes all entitlements and forces every client to re-verify (and loses
revocation state).

| Setting | Value |
|---|---|
| Volume mount path | **`/data`** |
| Store file | `/data/purchases.json` (image default `TRACK_STORE_PATH`) |
| Enforcement | `railway.toml` sets `requiredMountPath = "/data"`; Railway will prompt you to attach a volume (it is **not** auto-created) |

Steps:

1. Railway → Service → **Volumes → Add Volume**, mount at **`/data`**.
2. Keep `TRACK_STORE_PATH=/data/purchases.json` (the image default already sets
   this, so you usually don't need to override it).
3. The `docker-entrypoint.sh` (as root) `chown`s `/data` to the `node` user
   before dropping privileges, so the non-root process can write to the mounted
   volume.

**Backups:** the volume holds the only copy of entitlement state. Schedule
periodic snapshots / copies of `/data/purchases.json`. There is no external
database.

> If you later move to Postgres, `src/store.js` exposes `BillingStore.POSTGRES_DDL`
> (two tables with a foreign-key cascade). That is an optional swap and is **not
> required** for launch — the file store is sufficient and is what ships.

---

## 9. Health-check configuration

- **Endpoint:** `GET /healthz` → `200 {"ok":true}`.
- **Railway:** `railway.toml` sets `healthcheckPath = "/healthz"` with a
  60-second `healthcheckTimeout`.
- The endpoint is **liveness-only**: it returns 200 with no internal state and
  does **not** require Google Play credentials. A transient Play API outage will
  therefore **not** cause Railway to kill a healthy service (correct — we do not
  want to flap on a Google hiccup). It also never exposes credentials, tokens,
  or infrastructure details.
- The Docker image also has a `HEALTHCHECK` on `/healthz`.

---

## 10. Deploy & rollback procedure

**Deploy**

1. Merge/commit changes to the `arena/...-trackpro` branch (or the branch
   Railway watches).
2. In Railway, the service auto-deploys on push (once connected). Watch the
   build/deploy logs.
3. Confirm the deploy becomes **Healthy** (health check passes) and the startup
   log line `service_started` appears with the assigned port.

**Rollback**

- Railway keeps deploy history: open the service → **Deployments → … → Rollback**
  to a previous healthy build. Because `railway.toml` is version-controlled, also
  revert the offending commit in git for a consistent state.
- Rollback affects only the service binary/config. The `/data` volume (purchase
  ledger) is **independent of the image** and is preserved across rollbacks —
  which is the whole point of the volume.

**Zero-downtime key rotation**

- `TRACK_BILLING_API_KEYS` accepts two comma-separated values. Add the new key,
  deploy, rotate the app's `TRACK_VERIFY_URL` bearer, then remove the old key.

---

## 11. Production verification checklist

After deploy, verify in order:

- [ ] Service is **Healthy** in Railway (health check green).
- [ ] `GET /healthz` returns `200 {"ok":true}`.
- [ ] `POST /billing/verify` with **no/auth-wrong** bearer returns `401`.
- [ ] `POST /billing/verify` with a **valid test purchase** (closed testing
      track) returns `200 {valid:true, expiresAt,...}` and the token is stored
      (keyed by an HMAC ref, never the raw token).
- [ ] A **forged/garbage** token returns `200 {valid:false, reason:"token_not_found"}`
      (never `valid:true`).
- [ ] `POST /rtdn` with **wrong** secret returns `401`.
- [ ] A **Play Console test RTDN** returns `200 {"ok":true,"action":"test_notification"}`.
- [ ] A real **renewal/cancel** RTDN updates/revokes the stored entitlement.
- [ ] The volume survives a **redeploy**: re-verify shows the same stored record
      (no re-verification storm, no lost revocations).
- [ ] Logs show structured JSON with **no** raw purchase tokens, credentials, or
      bearer secrets (the logger redacts them).
- [ ] `service_started` / `service_stopping` log lines appear on start/stop.

> The 83 automated tests (`npm test`) cover the contract, entitlement rules,
> RTDN handling, storage persistence, fail-closed verification, production
> startup, graceful SIGTERM shutdown, `0.0.0.0` binding, and storage-failure
> handling. They use an injected fake Play client — a **real** service-account
> test purchase on a closed-testing track is still required before launch.

---

## 12. Estimated operational cost & external dependencies

**Railway**

- This is a tiny, low-traffic service: it is hit only when a user verifies a
  purchase and when Google delivers RTDN. Expected CPU/RAM is minimal.
- Typical cost: within Railway's Hobby plan (~$5/mo) or low usage-based billing.
  A dedicated instance with 256–512 MB RAM and fractional vCPU is ample. The
  `/data` volume adds a few cents per GB-month (ledger is tiny — KB to low MB).
- Rough total: **usually < $10/month**, often on the free/including tier.

**External dependencies**

- **Google Play Android Developer API** — free; quota is generous for this use.
- **Google Cloud Pub/Sub** — free tier (10 GB/month egress, ample for RTDN);
  negligible cost afterwards.
- **No database, no cache, no third-party SaaS** required. The only stateful
  dependency is the Railway Volume at `/data`.

---

## Security model (summary)

- **Server-side verification only.** The Android app posts
  `{productId, purchaseToken, packageName}`; the server re-checks with Google.
- **Fail-closed.** Forged/expired/refunded/wrong-package/unknown-SKU → rejected;
  Play outage → `503 retryable` (client keeps the purchase pending, never
  revokes a valid one).
- **No secrets in logs or store.** Purchase tokens are stored only as an HMAC
  reference (`tokenRef`); the logger redacts tokens, emails, bearer headers and
  sensitive keys; storage failures log only a safe error code.
- **Auth.** `POST /billing/verify` requires `TRACK_BILLING_API_KEYS`;
  `POST /rtdn` requires `TRACK_RTDN_SECRET`; credentials come from env/secret,
  never the image.
- **Hardening added for this deploy:** bounded request/socket timeouts, explicit
  `0.0.0.0` + `PORT` binding, safe storage-failure responses (503 retryable
  instead of a hang or a false 200), and a non-root container that can still
  write to the mounted volume.

## Known limitations (not fixed here — out of scope)

- RTDN auth relies on the shared `TRACK_RTDN_SECRET` bearer (documented,
  fail-closed). Google Pub/Sub **OIDC** token verification is not implemented;
  add it at a proxy or inside `handleRtdn` if you want defense-in-depth against
  secret leakage.
- Rate limiting is per client IP (from `X-Forwarded-For`). Behind Railway's
  proxy this is reasonable, but a client spoofing that header can split its
  bucket; the API key remains the primary control.
- The file store is unencrypted. It holds purchase *metadata only* (no tracker
  data); protect it via the managed volume and regular backups.

See `README.md`, `OPERATIONS.md`, and `docs/PLAY_CHECKLIST.md` for related
context.
