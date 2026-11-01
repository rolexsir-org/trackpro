# Track Pro billing verification service

The server half of Track Pro's fail-closed Play Billing contract. It verifies
purchase tokens with the Google Play Developer API, stores the resulting
entitlement, and processes Real-time Developer Notifications (renewals,
cancellations, refunds, revocations, expirations).

- **Runtime:** Node 20+, zero runtime dependencies (only `node:*` built-ins).
- **Tests:** 60+ offline tests; Google is replaced by an injected fake in every
  test. `npm test`.
- **Entry point:** `src/index.js` (the process). `src/server.js` is the HTTP
  factory used by the tests.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| `GET` | `/healthz` | none | Liveness. Returns `{"ok":true}` and nothing else. |
| `POST` | `/billing/verify` | `Authorization: Bearer <TRACK_BILLING_API_KEYS>` | Verify a purchase token and return the entitlement. |
| `POST` | `/rtdn` | `Authorization: Bearer <TRACK_RTDN_SECRET>` | Google Cloud Pub/Sub push for RTDN. |

`POST /billing/verify` body:

```json
{
  "productId": "track_pro_annual",
  "purchaseToken": "<Play serverVerificationData>",
  "packageName": "com.track.app",
  "installId": "<optional opaque device id>"
}
```

Responses are documented in `OPERATIONS.md` §3.

## Required configuration

| Variable | Required | Purpose |
|---|---|---|
| `TRACK_BILLING_API_KEYS` | yes | Comma-separated bearer keys for `/billing/verify`. Two values are supported during rotation. |
| `TRACK_RTDN_SECRET` | yes | Bearer token that Pub/Sub must present on `/rtdn`. |
| `TRACK_STORE_PATH` | yes | Path to the persistent JSON purchase store. |
| `GOOGLE_APPLICATION_CREDENTIALS` | yes | Path to the Play service-account JSON key. |
| `PORT` | no | Listening port (default `8080`). |

The service **refuses to start** if any of the four required values is missing.
A billing service that starts without authentication would accept forged
purchase tokens.

### Play service account

1. In Google Cloud, create a service account in the same project as the Play
   Developer API.
2. Create a JSON key for it. Store it outside git (e.g. `/run/secrets/...`).
3. In Play Console → **Users & permissions**, grant the service account
   **View financial data** (and the app must be scoped to it).
4. Enable the **Google Play Android Developer API** in the Cloud project.

The client signs a JWT with the service account's private key (RS256), exchanges
it at `https://oauth2.googleapis.com/token`, and calls:

- `GET /androidpublisher/v3/applications/{packageName}/purchases/subscriptionsv2/{productId}/tokens/{token}`
- `GET /androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}`

## Run locally

```bash
cd billing_server
npm test

# Fill in .env from .env.example first.
node --env-file=.env src/index.js
curl -s http://127.0.0.1:8080/healthz
```

Node 20.6+ supports `--env-file`. On older Node 20, export the variables in the
shell or use your platform's secret injection.

## Run with Docker

```bash
docker build -t trackpro-billing ./billing_server

docker run --rm -p 8080:8080 \
  -e TRACK_BILLING_API_KEYS="$TRACK_BILLING_API_KEYS" \
  -e TRACK_RTDN_SECRET="$TRACK_RTDN_SECRET" \
  -v "$PWD/play-service-account.json:/run/secrets/play-service-account.json:ro" \
  -e GOOGLE_APPLICATION_CREDENTIALS=/run/secrets/play-service-account.json \
  -v trackpro-billing-data:/data \
  trackpro-billing
```

The image runs as the unprivileged `node` user and stores purchases in
`/data/purchases.json`. Mount a persistent volume there. The healthcheck hits
`/healthz`.

## RTDN (Pub/Sub)

1. Create a Pub/Sub topic in the same Google Cloud project.
2. Create a push subscription to `https://YOUR-DOMAIN/rtdn` with the
   `TRACK_RTDN_SECRET` as a bearer token (configure the subscription's
   authentication header, or put the secret in the path behind your proxy).
3. In Play Console → **Monetise → Setup → RTDN**, point the topic at the
   subscription.
4. Verify with a test purchase that a `SUBSCRIPTION_RENEWED` notification
   arrives and extends the stored expiry.

## Security notes

- Purchase tokens are never written to the store or logs. The store keys records
  by `tokenRef()` (an HMAC prefix), and the logger redacts token-shaped strings.
- The service is fail-closed: an invalid/forged/expired token never grants an
  entitlement; a Play outage returns `503 retryable` rather than a rejection.
- Rate limiting is per client IP (token bucket).
- The service receives no tracker data. It only sees product id, purchase token,
  package name and an optional opaque install id.
- SQLite/JSON store is not encrypted; it contains purchase metadata, not
  tracker data. Use a platform-managed secret/volume.

## What is not tested here

The 60+ tests use a fake Play client, so they prove the contract and the
entitlement rules, not Google's live responses. A real service-account test
purchase on a closed-testing track is still required before launch. See
`docs/PLAY_CHECKLIST.md` and `docs/PUBLISHING_GAPS.md`.
