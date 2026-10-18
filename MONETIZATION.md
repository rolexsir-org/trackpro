# Track Pro — monetisation runbook

Everything on the **server side** of the subscription: what to create in Play
Console, what the verification backend must do, and the exact rules the Flutter
client already assumes. The client is written and wired (`lib/config/pro_config.dart`,
`lib/services/billing_service.dart`, `lib/screens/paywall_screen.dart`); this file is
the list of things that only you can do, in the order that gets you to a testing
build fastest.

If you read only one section, read §1 and §4.

---

## 1. Play Console catalogue

Create these under **Monetise → Products**. The ids are load-bearing: they are
constants in `ProConfig`, and a typo here is a paywall that loads forever.

### Subscriptions (one product each, base plan ids are their own namespace)

| Product id | Base plan id | Type | Price (India) | Notes |
|---|---|---|---|---|
| `track_pro_monthly` | `monthly-auto` | Auto-renewing | ₹399 / month | no trial on its own |
| `track_pro_annual` | `annual-auto` | Auto-renewing | ₹2,499 / year | **hero plan** (`highlighted: true`) |
| `track_pro_lifetime` | — | One-time product | ₹4,999 | not a subscription |

### The trial lives on the annual base plan only

The 7-day free trial is **not** a separate product. It is an *offer* on
`annual-auto`:

- In `track_pro_annual` → **Base plans → Offers → Add offer**
  - Offer id: `free-trial-7d`  ← must match `ProConfig.trialOfferId`
  - Eligibility: *New customer acquisition* (not "upgrade")
  - Phase 1: **Free** · 7 days
  - Phase 2: Auto-renewing · ₹2,499 / year
  - Tags: none required

Why the annual-only trial: trials are the highest-converting lever, so they belong
on the highest-intent plan. It also keeps the paywall honest — one trial, stated
once, on the plan we actually want people on.

> **Play payout check.** You cannot enable paid products until the merchant
> profile, bank account and tax info are complete (**Setup → Payments profile**),
> and your app must be on a **closed testing track with at least 12 testers for
> 14 continuous days** before production access (personal-account rule). Start the
> tester recruitment the day you create the products, not the day you finish the
> app.

### Prices in other countries

Let Play's *auto-convert* set everything from the India price, then spot-check the
US, UK and BR tiers by hand. The client never hardcodes a currency: it renders
`ProductDetails.price`, which Play localises per country *and* per cohort. The
`fallbackPrice` strings in `ProConfig` (`₹399` / `₹2,499` / `₹4,999`) appear only
when Play is unreachable, and they are deliberately Indian-rupee formatted because
that is the reference market.

### Licence testing (do this first)

**Setup → License testing** → add the Google accounts you test with. Then:

- Test cards always approve; the *annual* plan shows the ₹0 trial phase.
- Licence testers never get charged, so use them for every purchase-path test —
  never a real card, never your own production account (you cannot buy your own
  product, Play blocks it with `ITEM_ALREADY_OWNED` / "purchase not allowed").

Add at least one licence tester for each Android version you support (13, 14, 15)
and for the **Google Play Billing test responses** (see §6).

---

## 2. In-app products vs subscriptions: what the client does with each

`BillingService._merge()` collapses Play's response down to **one `ProPlan` per
product**, because Play returns a separate `GooglePlayProductDetails` for *every
offer* on a subscription. Two consequences worth knowing when you debug:

1. **Prices come from the first *paid* phase.** If Play hand you the ₹0 trial
   phase as the headline, the paywall would render "₹0 / 7 days" — technically
   true and commercially terrible. `_merge()` picks the paid phase's price, so the
   card reads `₹2,499 / year` with a separate "7 days free" line.
2. **The offer token is required.** Subscriptions are launched with
   `GooglePlayPurchaseParam(offerToken: …)`. Without it the Play sheet opens and
   silently fails, or throws `DEVELOPER_ERROR`. The token is per-offer and
   short-lived — it is re-fetched by `loadPlans()` every time the paywall opens
   (that call in `PaywallScreen.initState` is not decoration).

Lifetime is a plain one-time product: `PurchaseParam` with no offer token, no
renewal, and `Entitlement.isLifetime == true` forever after.

---

## 3. Google Play Billing Library version

`in_app_purchase_android` 0.5.x ships Play Billing **7.x** transitively, which
meets the current Play requirement (Billing Library 7+ for new releases, with the
deadline for 6.x already past as of 2025-08-31). Don't pin a lower version "for
safety" — a downgrade fails the release review.

No Gradle dependency line is needed; see `android_overlay/app/build.gradle.additions`
§3 for the note and the optional explicit pin.

---

## 4. Server-side verification (the part that must exist before launch)

The client trusts Play for the *purchase* and your backend for the *entitlement*.
`HttpPurchaseVerifier` is already written and expects exactly this contract:

```
POST /billing/verify
Authorization: Bearer <API_TOKEN>
Content-Type: application/json

{ "productId": "track_pro_annual",
  "purchaseToken": "…",           // PurchaseVerificationData.serverVerificationData
  "packageName": "com.track.app" }
```

Response (every branch the client understands):

```json
{ "valid": true,
  "expiresAt": "2026-11-15T09:12:00Z",
  "trialEndsAt": "2026-10-22T09:12:00Z",
  "autoRenew": true,
  "inGracePeriod": false }
```

```json
{ "valid": false, "pending": true }          // payment not settled — grant nothing, wait
{ "valid": false, "reason": "token_not_found" }  // a verdict — drop the claim
```

and, for anything that is *our* fault rather than the purchase's, **HTTP 503**
(`{ "valid": false, "retryable": true }`). 5xx, 408 and 429 are all treated as
"could not ask".

**503 is not a rejection, and the client depends on that.** It is the difference
between "revoke this entitlement" and "try again later". Collapse the two and
you either lock out every paying user during a Google outage, or you never revoke
a refund.

What the backend must do:

1. Authenticate the app. `billing_server` ships a rotatable API key compared in
   constant time, plus a pluggable Play Integrity hook (`X-Integrity-Token`) for
   asserting that the request comes from a genuine, unmodified install. The key is
   a build-time value, not a secret in the APK's assets: treat it as an abuse
   speed-bump, and let the Play Developer API be the actual authority.
2. Call the Play Developer API with a **service account** that has
   "View financial data" + the app scoped in Play Console → *Users & permissions*:
   - subscriptions → `purchases.subscriptionsv2.get` (this is the only endpoint
     that exposes **expiry**, `autoRenewing`, and the graceful grace period)
   - lifetime → `purchases.products.get` and remember `purchaseState == 0`
3. Persist `(userId, purchaseToken, expiryTimeMillis, productId, autoRenew)`.
   This is what makes reactivation, refunds and family-sharing supportable later.
4. **Subscribe to Real-time Developer Notifications (RTDN)** on a Pub/Sub topic:
   `SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_EXPIRED`, `SUBSCRIPTION_CANCELED`,
   `SUBSCRIPTION_REVOKED`, `SUBSCRIPTION_IN_GRACE_PERIOD`, `SUBSCRIPTION_ON_HOLD`,
   `VOIDED_PURCHASE`. On revoke/expiry, drop the entitlement server-side — the
   client re-checks on every resume and will follow within one foreground.

**Why it matters even at small scale:** `purchaseToken` alone is forgeable on a
rooted device, and refunds are invisible to the client. A week after launch,
verification is the difference between revenue and a spreadsheet of ghost Pro
users.

### 4.1 The entitlement model is fail-closed

The client used to grant Pro the moment Play reported a purchase, then verify
afterwards. That is gone. What is true now:

| State | Pro? |
|---|---|
| `verified: true`, subscription, before `expiresAt + offlineGrace (3d)`, verified within `maxStaleDays (7d)` | yes |
| `verified: true`, lifetime | yes, forever |
| `pending: true` (payment not settled) | **no** |
| `verified: false` (a claim nobody has confirmed) | **no** |
| Recognised product id, nothing else | **no** |
| Subscription with no `expiresAt` from the server | **no** |
| Verified more than 7 days ago | **no** until the next successful check |

A purchase that Play accepts is acknowledged immediately (the 3-day rule below),
then queued as *pending verification* and shown in the UI as "Confirming with
Google Play". It unlocks nothing until `/billing/verify` says `valid: true`.
`LocalOnlyVerifier` still exists for tests and emulator work, but it **throws in
release builds**, so it cannot be shipped by accident; `HttpPurchaseVerifier`
returns "unreachable" when `TRACK_VERIFY_URL` is not set, which means an
unconfigured build simply cannot grant Pro.

The server implementation lives in `billing_server/` (Node 20, zero runtime
dependencies, 60 tests): `POST /billing/verify`, `POST /rtdn` for Pub/Sub
notifications, a file-backed store, and the deployment, monitoring and incident
runbooks. Read `billing_server/OPERATIONS.md` before touching the client contract.

---

## 5. Acknowledgement, pending payments, and the 3-day refund window

Non-negotiable Play rules, already implemented in `BillingService._onPurchaseUpdate`:

- **Acknowledge within 3 days or Play auto-refunds and revokes.** The client
  calls `completePurchase` *immediately* on the `purchased` event, before
  verification — never behind a network call. Verification happens after, and it
  decides whether access is granted at all (see 4.1): an unverified claim is
  queued and retried, not honoured.
- **Acknowledge `restored` too.** A reinstall can deliver a purchase Play never
  got an acknowledgement for; skipping it silently refunds a paying user.
- **`PurchaseStatus.pending` is normal, not an error.** UPI, net-banking and
  cash-on-delivery-style payment methods in India routinely sit pending for
  minutes to hours. The paywall shows the waiting state and stays put; the
  entitlement lands whenever the purchase stream delivers it — including while
  the user is on another screen. A pending purchase is *never* granted provisionally:
  the free tier keeps working, and Pro arrives when the payment clears.
- **Multi-quantity is not used.** If you add one, `completePurchase` needs the
  right quantity or Play rejects the acknowledgement.

---

## 6. Testing matrix before you ship

| What | How | Expected |
|---|---|---|
| Products load | Open the paywall on a **Play-installed** build | Three plans, real localized prices, `7 days free` on annual |
| Trial | Buy annual as a licence tester | Entitlement lands, Settings says "Track Pro trial · N days left" |
| Cancel in trial | Play → Subscriptions → Cancel | Access remains until trial end; `autoRenew: false`; Settings shows "Cancelled · access until …" |
| Cancel after charge | Same, on a paid month | Access until `expiresAt`; no instant lockout |
| Restore | Clear app data, reopen, Restore | Pro returns without re-paying |
| Refund | Play Console → Order → Refund | After the RTDN/verification path lands, Pro drops within one foreground |
| Pending | Play Console → **Test responses** → `PURCHASES_UPDATED`? No: use *Test payment declines*/slow methods, or a real UPI on the internal track | Paywall stays in "waiting for Google Play", then resolves |
| Decline | Test card that declines | `purchase_error` in the funnel, human copy on screen, no entitlement |
| No Play Services | Sideload the APK | Paywall explains it cannot sell here; the rest of the app works |
| Offline launch | Airplane mode, cold start | A previously **verified** entitlement holds Pro while it is valid; verification is retried on the next resume |
| Server down | Point `TRACK_VERIFY_URL` at a dead port, buy | Purchase is acknowledged, UI says "Confirming with Google Play", **no Pro unlocked**, retry on resume |
| Forged token | `curl` `/billing/verify` with a made-up token | `200 {valid:false, reason:token_not_found}`, no entitlement |
| Refund | Play Console → Order → Refund | RTDN `SUBSCRIPTION_REVOKED` drops the install entitlement; the client follows on the next check |
| Edited cache | Edit `pro.entitlement` in a rooted device's app data to `expiresAt: 2099` | With `verified:false` it grants nothing; a forged `verified:true` is bounded by `maxStaleDays` (7 days) — see `SECURITY_REVIEW.md` for the residual risk |
| Sideload = free | Sideload, log data | Free limits apply, **export still works** |

Test responses live in Play Console → **License testing → Test responses**. Note
that they are per-licence-tester and reset after a successful purchase.

---

## 7. Free vs Pro — the commercial model

Enforced in exactly two places in code: `ProConfig` (limits) and
`AppState` (`canAddTracker`, `historyWindow`, `isHistoryLocked`, …). Nothing in a
screen hardcodes a number, so this table is the single source of truth.

| | Free | Pro |
|---|---|---|
| Trackers | **3** active | all 10 + custom |
| History window | **7 days** | everything, back to day one |
| Insights | today's rings, streaks, badges, 3 patterns | correlations, heatmaps, 90-day range |
| Health Connect sync | — | steps / sleep / weight auto-filled |
| Reminders | daily 9pm check-in | + streak saver, + weekly report |
| Widget | 1 ring | 3 rings + Wear tile |
| Logging | unlimited | unlimited |
| **Export (JSON/CSV)** | **free, always** | free |
| Price | ₹0 | ₹399/month · ₹2,499/year · ₹4,999 lifetime |

Three deliberate decisions, so nobody "optimises" them away later:

1. **History is the paid axis, and nothing already logged is ever withheld.**
   Free users keep writing rows into the same `events` table forever; Pro reveals
   them. Selling access to data a user already entered is the fastest route to a
   one-star review, and Play policy leans the same way.
2. **Export is never gated.** It is the receipt that proves the lock-in is value,
   not hostage-taking. It costs a few conversions and buys the entire review
   section.
3. **The daily check-in stays free.** It is the habit loop. Gating it would raise
   short-term conversion and destroy the retention that makes the ₹2,499 make
   sense.

---

## 8. Funnel analytics

`ProAnalytics` writes to the local `track_events` table (schema v2) with a
whitelist of 15 events, every one tagged with a `trigger`:

```
paywall_viewed · plan_selected · purchase_started · purchase_pending
purchase_completed · purchase_canceled · purchase_error · restore_started
restore_completed · trial_started · paywall_dismissed · manage_opened
pro_gate_tapped · soft_prompt_shown · soft_prompt_dismissed
```

Two queries are already written for you in `pro_analytics.dart`:

- `viewToPurchaseRate()` — paywall views → completed purchases, the only number
  that matters in week one.
- `trialConversionQuery` — of everyone who started a trial, how many still had
  Pro 8 days later.
- `hardPaywallSkewQuery` — conversion by placement, i.e. *which* gate earns its
  interruption. Placements live at: `trackerLimit`, `historyLock`,
  `insightsLock`, `healthSync`, `streakSave`, `softPrompt`, `settings`,
  `widgetTap`.

Events are local only. If you later want them server-side, ship them to the same
backend as `/billing/verify` in the same batch — do not add an analytics SDK to a
privacy-first tracker.

---

## 9. Privacy and policy checklist

Play's subscription policy requires these, and they are all already in the build:

- **Manage/cancel reachable in-app** — Settings → *Manage subscription* and the
  paywall footer, both deep-linking to
  `play.google.com/store/account/subscriptions?sku=…&package=com.track.app`.
- **Restore** — Settings and paywall.
- **Clear price, billing period and auto-renewal** — the paywall card + the legal
  line directly under the CTA.
- **Trial terms stated before purchase** — "Free for 7 days, then ₹2,499/year.
  Auto-renews until cancelled."
- **Terms + Privacy links** on the paywall and in Settings (`TRACK_TERMS_URL` and
  `TRACK_PRIVACY_URL` via `--dart-define`; when omitted in a development or
  unconfigured build, tapping either link opens the bundled in-app disclosure
  sheet `showLegalSheet` rather than a dead placeholder URL).
- **Data safety form** — declare that tracker data stays on-device, Health
  Connect data is read-only and never transmitted, and the only network call is
  the purchase-token verification.

---

## 10. Launch order (what to do, in this order)

1. **Merchant profile + payments profile** complete. (Blocks everything else.)
2. Create the three products and the `free-trial-7d` offer exactly as in §1.
3. Add licence testers; install from a **closed testing track** build.
4. Run the §6 matrix end to end. Fix copy, not logic, unless a purchase fails.
5. Stand up `/billing/verify` + RTDN. Swap `LocalOnlyVerifier` →
   `HttpPurchaseVerifier` in `main.dart`. Re-run the matrix.
6. Recruit 12+ testers for the 14-day closed-testing requirement (if a personal
   developer account) *concurrently* with step 5.
7. Store listing: screenshot the paywall, the Pro widget and the correlations —
   the ₹2,499 is justified by what people can *see*.
8. Production, with the funnel queries from §8 running from day one.

---

## 11. Open items (not yet done, on purpose)

- **Verification backend** — contract in §4, client written, server is yours.
- **RTDN handler** — Pub/Sub push → revoke entitlements on
  `SUBSCRIPTION_REVOKED` / `SUBSCRIPTION_EXPIRED`.
- **Server-side price experiment** — Play supports per-cohort offers; the funnel
  `plan_selected` event already tags by plan, so you can read the result.
- **Promo codes** — `manageUrl` and the paywall do not yet surface redeem links
  (`play.google.com/redeem`). One-line addition when you run a campaign.
- **`FLAG_IGNORE_GLOBAL_SETTING` / `FlutterFragmentActivity`** — the two
  unresolved nits from the health and notification overlays. Neither blocks
  billing.
