# Track Pro Billing Server — Operations Runbook

Self-contained Node 20 service (`billing_server/`) that implements the server half
of Track Pro's fail-closed Play Billing contract (`MONETIZATION.md` §4):

- `POST /billing/verify` — called by `HttpPurchaseVerifier` in
  `lib/services/billing_service.dart`
- `POST /rtdn` — called by Google Cloud Pub/Sub for Real-time Developer
  Notifications (renewals, cancellations, revocations, refunds, expirations)
- `GET /healthz` — liveness probe (returns `200 {"ok":true}` with no internal state)

## 1. Running tests locally & in CI

```bash
cd billing_server
npm test
```

Zero external runtime dependencies; all 60 unit and socket-integration tests run
offline under `node --test`.

## 2. Required environment variables in production

| Variable | Purpose |
|---|---|
| `PORT` | Listening port (default `8080`) |
| `TRACK_BILLING_API_KEYS` | Comma-separated bearer keys accepted on `POST /billing/verify` (supports two keys during rotation) |
| `TRACK_RTDN_SECRET` | Bearer token required on `POST /rtdn` push subscription |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to the Play Developer API service-account JSON key (never committed to git) |
| `TRACK_STORE_PATH` | Path to the persistent JSON store file (or swap `BillingStore` to Postgres using `BillingStore.POSTGRES_DDL`) |

## 3. Verifier contract (`POST /billing/verify`)

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
