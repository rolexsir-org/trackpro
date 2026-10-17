# Privacy and data flow — Track

Purpose: an exact description of what data exists, where it goes, how long it
lives, and what a user can do about it. This is the document that Play's Data
safety form must agree with — §6 maps the form questions to these answers.

Claims in this file are limited to what the code does. Anything not implemented is
listed in §7 as explicitly **not** claimed.

---

## 1. What is stored, and where

| Data | Where | Notes |
|---|---|---|
| Tracker entries (water, mood, expenses, sleep, habits, calories, steps, cycle, screen time, weight) | Device SQLite (`track.sqlite`), app-private | Day-keyed rollups in `daily_entries`, individual events in `events` |
| Habit names and colours | Device SQLite (`app_settings.habits`) | User-authored |
| Goals, tracker order, visibility, theme | Device SQLite | User-authored |
| Height (optional, for BMI) | Device SQLite (`app_settings.profile.heightCm`) | Only used to compute BMI locally |
| Entitlement (plan, expiry, token) | Device SQLite (`app_settings.pro.entitlement`) | Cached so a cold start shows the right tier |
| Purchase records | Your billing service (`billing_server`) | package, product, purchase token, install id, verification state, expiry |
| Notification schedules | OS (AndroidX WorkManager / alarm manager via the plugin) | Times and ids only |
| Widget snapshot | Device `shared_preferences` (~600 bytes) | Today's rings + streak, read by the widget process |
| Focus sessions | Device SQLite (`focus_sessions`), app-private | Mode, goal, both clocks, focus/paused ms, outcome, end reason, enforcement value, three counters, the covered package ids, the user's reflection |
| Focus profiles / schedules | Device SQLite (`focus_profiles`, `focus_schedules`) | The user's own configuration: name, mode, length, app list, times and days |

There is **no account, no sign-in, no user id, and no user profile**. "Install id"
in the billing service is a random identifier generated on the device for purchase
association; it is not derived from anything about the person.

## 2. Where data goes

```
┌──────────────────────────── the device ────────────────────────────┐
│  Track (SQLite)  ──►  widget snapshot (shared_preferences)          │
│        │                     │                                      │
│        │                     └──►  home-screen widget (same device) │
│        │                                                            │
│  Health Connect (READ steps/sleep/weight) ──► daily rows            │
└─────────────────────────────────────────────────────────────────────┘
                     │
                     │  only on a purchase attempt:
                     │  {productId, purchaseToken, packageName, installId}
                     ▼
        ┌──────────────────────────────┐        ┌────────────────────┐
        │  /billing/verify (your host) │───────►│  Google Play       │
        │  audit-logged, token redacted│        │  Developer API     │
        └──────────────────────────────┘        └────────────────────┘
                     ▲
                     │  RTDN (Pub/Sub): renewals, refunds, expiry
```

- **Health Connect is read-only.** The app never writes to it and never requests
  background read access.
- **The billing service receives no tracker data, ever.** It receives a purchase
  token and an opaque install id. There is no code path that could attach a
  tracker value to a request.
- **No analytics, ads, crash-reporting or attribution SDK is present.** Nothing in
  `pubspec.yaml` phones home; `ProAnalytics` is a *local* SQLite table of funnel
  events (paywall views, plan selections) used to answer questions in this repo,
  not a network SDK.

## 3. Retention

| Data | Retention |
|---|---|
| Tracker entries | Until the user deletes them. There is no automatic expiry and no server copy. |
| Funnel events (local) | Local SQLite, deleted with "Delete all data" |
| Purchase records (service) | Until you delete them. Recommended: keep while the entitlement can be disputed (refund window + 1 year), then purge. **Purge job not implemented — see §7.** |
| Verification logs | One JSON line per verification, no token, no tracker data. Retention is your log platform's policy — set it, and say what it is here before you file Data safety. |

### Focus Lock specifically

Focus Lock is the one feature that reads anything outside the app, so it gets its own
statement. What it reads: the **package name** of the app that came to the front and the
**moment it did** — for the length of a session, in memory, compared against the user's
own list. What it never reads: screen content, other apps' data, messages, notifications,
credentials, location, contacts. What it writes: three integers (opens detected, panels
shown, foreground events observed) plus the session's own numbers. What it sends:
nothing. There is no upload path for this data, and `docs/FOCUS_LOCK.md` §5 is the
long form.

## 4. User controls (all implemented)

| Control | Where | Behaviour |
|---|---|---|
| See what is stored | Settings → Diagnostics | Row counts by source ("Typed by you", "From Health Connect", "Sample data") |
| Export everything | Settings → Export data | JSON (full event log + daily rows) and CSV, always free, never gated by the paywall |
| Delete everything | Settings → Delete all data | Confirmation dialog, then deletes entries, events and settings. **Nothing is recreated.** Tracker definitions remain so the app is still usable |
| Remove only the samples | Settings → Remove sample data (only shown when sample rows exist) | Deletes rows with `source: 'demo'` and keeps everything the user logged |
| Turn off reminders | Settings → Notifications | Persisted; reschedules immediately |
| Keep reminder content off the lock screen | Settings → Notifications → "Show details on the lock screen" (off by default) | Generic bodies until explicitly enabled |
| Focus: revoke app covering at any time | Settings → Focus Lock → App covering, or Android's own settings | Revoking usage access or the overlay turns covering off immediately; the running session is recorded as degraded rather than as a clean completion |
| Focus: delete focus history | Settings → Delete all data (with the rest) | Sessions are deleted with the user's other data; profiles and schedules survive as configuration |
| Focus: export sessions | Settings → Export data | Included in the JSON (`track.focus.v1`) and as CSV, always free |
| Revoke health access | System Health Connect settings | App degrades to manual logging; already-synced rows remain the user's own data |

## 5. Deletion semantics, precisely

`EntryRepository.deleteAllUserData()` runs in a transaction and removes:

- all rows from `daily_entries` (every tracker, every source),
- all rows from `events`,
- all rows from `app_settings` — **including the cached entitlement** and the
  habit list.

It keeps: the tracker *definitions* table (unless
`keepTrackerDefinitions: false` is passed programmatically).

It does **not**: re-seed, re-create sample rows, or restore defaults that look like
history. The state after deletion is an empty app, and the empty states say so.

## 6. Mapping to the Play Data safety form

Answer from this table, not from memory:

| Play question | Answer |
|---|---|
| Does your app collect or share user data? | **Collect: no. Share: no.** Data is created and stored on the device. A purchase token is transmitted to your own service to validate a purchase — Play treats purchase data processed on the developer's behalf for app functionality as service-provider processing, not "sharing"; declare it under *App functionality* and be consistent in the privacy policy |
| Data types collected | None of the Play "personal data" categories. Health and fitness data is **collected on device, not transmitted** |
| Data encrypted in transit? | Yes for the one outbound call (HTTPS enforced by `AppEnvironment.validate()`); N/A otherwise |
| Data deletion request mechanism | In-app: Settings → Delete all data. Document the same path in the privacy policy |
| Health Connect declaration | Steps, sleep, weight; read-only; foreground; user-initiated connect from Settings. Complete the Health Connect permissions declaration form in Play Console with this wording |
| Ads / tracking | None |
| Children | Not directed at children; no age gate is claimed |

## 7. Explicitly **not** claimed (do not put these in the listing)

- **No encryption at rest.** The SQLite file is app-private, not encrypted.
- **No cloud sync, no cloud backup, no multi-device restore** (unless the user
  exports and imports manually).
- **No per-app screen-time reading.** Android does not expose it without a
  system-granted special permission; the app asks the user to log it.
- **No medical advice, no diagnosis, no fertility guarantee.** Cycle predictions are
  estimates from the user's own logged cycles and appear only after two real
  cycles.
- **No retention-job implementation for service-side purchase records** — it is a
  deployment task on your side, and until it exists you cannot claim a retention
  period in the policy.

## 8. Required external work before you can publish a privacy policy

1. Host the policy at a stable HTTPS URL you control. Set it as
   `--dart-define=TRACK_PRIVACY_URL=…` (and `TRACK_TERMS_URL=…`). A release build
   without both is flagged by `AppEnvironment.validate()` and by the release gate.
2. Write the policy using this document as the source of truth — in particular the
   "no encryption at rest" and "data is not transmitted" statements, which are the
   two most likely places to accidentally overclaim.
3. File the Data safety form and the Health Connect declaration consistently with §6.
4. Publish a support contact (`TRACK_SUPPORT_EMAIL`) that a human monitors —
   deletion requests by e-mail have to be answerable.
