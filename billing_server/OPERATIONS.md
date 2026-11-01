# Track Pro Billing Server — Operations Runbook

Self-contained Node 20 service (`billing_server/`) that implements the server half
of Track Pro's fail-closed Play Billing contract (`MONETIZATION.md` §4):

- `POST /billing/verify` — called by `HttpPurchaseVerifier` in
  `lib/services/billing_service.dart`
- `POST /rtdn` — called by Google Cloud Pub/Sub for Real-time Developer
  Notifications (renewals, cancellations, revocations, refunds, expirations)
- `GET /healthz` — liveness probe (returns `200 {"ok":true}` with no internal state)

## 1. Running the service

The process entry point is `src/index.js`. `src/server.js` is the HTTP factory
used by the tests; it does not listen on its own.

```bash
cd billing_server
cp .env.example .env       # fill in real values; never commit .env
node --env-file=.env src/index.js
curl -s http://127.0.0.1:8080/healthz
```

The service refuses to start if `TRACK_BILLING_API_KEYS`, `TRACK_RTDN_SECRET`,
`TRACK_STORE_PATH` or `GOOGLE_APPLICATION_CREDENTIALS` is missing. A billing
service that starts without authentication would accept forged purchase tokens.

Docker:

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

The image runs as the unprivileged `node` user, stores purchases in
`/data/purchases.json`, and has a `/healthz` healthcheck.

## 2. Running tests locally & in CI

```bash
cd billing_server
npm test
```

Zero external runtime dependencies; all 78 unit and socket-integration tests run
offline under `node --test`. The Google Play API is replaced by an injected fake
in every test; the real service-account path is not exercised offline.

## 3. Required environment variables in production

| Variable | Purpose |
|---|---|
| `PORT` | Listening port (default `8080`) |
| `TRACK_BILLING_API_KEYS` | Comma-separated bearer keys accepted on `POST /billing/verify` (supports two keys during rotation) |
| `TRACK_RTDN_SECRET` | Bearer token required on `POST /rtdn` push subscription |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to the Play Developer API service-account JSON key (never committed to git) |
| `TRACK_STORE_PATH` | Path to the persistent JSON store file (or swap `BillingStore` to Postgres using `BillingStore.POSTGRES_DDL`) |

The Play service account needs the **View financial data** permission in Play
Console → Users & permissions, and the Google Play Android Developer API must be
enabled in the Cloud project. The client signs an RS256 JWT with the service
account's private key and calls `purchases.subscriptionsv2.get` /
`purchases.products.get`.

## 4. Verifier contract (`POST /billing/verify`)

Request:
```json
{
  "productId": "track_pro_annual",
  "purchaseToken": "<Google Play serverVerificationData>",
  "packageName": "com.track.app"
}
```

Responses:
- `200 {"valid":true,"expiresAt":"…","trialEndsAt":"…","autoRenew":true,"inGracePeriod":false}` — verified active purchase
- `200 {"valid":false,"pending":true,"expiresAt":null,"reason":"pending"}` — slow payment method (UPI / bank transfer) still pending
- `200 {"valid":false,"reason":"token_not_found"}` — definitive rejection (forged, refunded, expired, wrong package, unknown SKU)
- `503 {"valid":false,"retryable":true,"reason":"play_unreachable"}` — transient Play API or server outage; the Flutter client keeps the purchase queued and never revokes an existing valid entitlement on a 503
