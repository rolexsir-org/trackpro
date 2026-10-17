# Security review — Track

Scope: the Android client, the billing verification service in `billing_server/`,
the data at rest on the device, and the build/release chain. Written from the code
as it stands on 2026-10-15, not from intent.

Owner: `ENG` (app/billing), `OPS` (service deployment), `REL` (release chain).
Review cadence: before every production release, and after any change to the
billing path or the permission set.

---

## 1. Assets, in the order an attacker cares about

| Asset | Where it lives | Why it matters |
|---|---|---|
| Purchase tokens | Google, and transiently the client + service | A token is a bearer credential for someone's order; leakage enables verification-by-proxy and support fraud |
| Entitlement state | Client (cached JSON), service (records) | Directly monetisable: forged Pro = lost revenue |
| Tracker data (health, mood, cycle, expenses) | Device only | Highly personal; a breach is a privacy incident, not just a data one |
| Service-account private key | Service environment only | Can read financial data for the app |
| Release signing key | Your machine / CI secret store | Can publish as you |

---

## 2. Threat model

| # | Threat | Control | Status | Residual risk |
|---|---|---|---|---|
| T1 | Forge a purchase (patched APK, edited prefs, replayed token) | Entitlement requires `verified: true`, which only `BillingService` writes from a server response; server-side verdict comes from the Play Developer API | **Mitigated** | A rooted device that edits a *verified* record buys at most `maxStaleDays` (7 days) per edit |
| T2 | Replay someone else's purchase token | Token must resolve for *this* package via `subscriptionsv2.get`; install association is recorded | **Mitigated** | Server-side only — losing the server means losing this control |
| T3 | Keep Pro after a refund | RTDN `SUBSCRIPTION_REVOKED` / `VOIDED_PURCHASE` revokes immediately; the client re-checks on launch/resume | **Mitigated** | If RTDN delivery breaks, detection degrades to "next verification" |
| T4 | Enumerate/abuse `/billing/verify` as a token oracle | Bearer credential compared in constant time, burst-20 rate limit, 8 KB body cap, pluggable Play Integrity hook | **Mitigated** | The API key ships in the APK and is extractable; it is a speed bump, not a secret. Rotate it, and enable the integrity hook before scale |
| T5 | Extract the API key from the APK | Key is a build-time value, rotatable without a client update; the true authority (Play) is server-side | **Accepted** | Anyone can call the endpoint with a valid key; they still cannot mint entitlements |
| T6 | Leak tokens through logs/traces | `tokenRef` (truncated SHA-256) instead of the token; key-based redaction **plus** free-text scrubbing for token-shaped strings; Play errors keep only a sanitised summary | **Mitigated** | Third-party log sinks inherit the redaction, not replace it |
| T7 | Read tracker data off the device | `allowBackup="false"`; local files are never uploaded; Health Connect is read-only | **Partially mitigated — see §3** | A rooted device or a forensic image can read the SQLite file: it is **not encrypted at rest** |
| T8 | Sneak data out through a third-party SDK | Zero analytics/ads SDKs; the only outbound calls are `/billing/verify` and, if configured, a game-services integrity check | **Mitigated** | Adding any SDK in future invalidates this row |
| T9 | Shoulder-surf a notification | Generic bodies by default, `NotificationVisibility.private`, opt-in to detail | **Mitigated** | A user who opts in has chosen the trade-off, and the copy says so |
| T10 | Malicious/compromised dependency | `billing_server` has **zero runtime dependencies**; the app's dependency set is pinned in `pubspec.yaml` | **Mitigated** | Dart/Kotlin transitive trees are not vendored — a supply-chain attack on pub.dev/Gradle remains possible |
| T11 | Steal the release keystore | Keystore never in the repo (`release_gate` P-09/P-10); `key.properties` documented but not created | **Mitigated (process)** | Play App Signing should be enabled so a lost upload key can be reset |
| T12 | Bypass a paid limit through the UI | Gates are UI-level; the underlying data is never withheld | **Accepted** | A modified client can show a Pro window. The design decision stands: users' own data is never held hostage by a gate |
| T13 | Focus Lock used as a surveillance or coercion tool (an app that watches what you open, or a block you cannot escape) | The detector reads only package names + timestamps, keeps integer counters, writes nothing to disk about usage, and sends nothing. The panel has a visible exit at all times, is never `FLAG_SECURE`, never imitates another app, and names itself. Deep focus makes the exit deliberate (press-and-hold), never hidden. Usage access and the overlay are user-granted AppOps permissions, revocable while a session runs | **Mitigated (by design)** | A rooted device can read `focus_sessions`, which reveals which apps were in a block list — the user's own choice, on their own device |
| T14 | Focus Lock escalates itself (silently requesting Accessibility, Device Admin, VPN or device-owner) | None of those are declared, requested or referenced. The release gate fails the build if any of those permission strings appear in the manifest, if `FLAG_SECURE` appears in the overlay, or if the entitlement becomes reachable from the permission path (P-24/P-25/P-26) | **Mitigated — verified by gate probe** | A future contributor could add one deliberately; the gate makes it a deliberate, visible act |
| T15 | Focus Lock claims a block it is not performing (the "it says blocked but nothing happened" failure) | `FocusEnforcement.verified` requires the platform to have reported at least one foreground event *and* the service to be alive *and* both grants held. A session whose enforcement was lost or never confirmed is stored as `completedDegraded`/`interrupted` and never as a clean completion | **Mitigated** | Usage-event granularity means a brief app open can be missed — a documented platform limit, stated to the user before the session and again in the status block |
| T16 | The overlay panel is used to deceive (fake system dialog, un-dismissable screen, hidden exit) | The panel is a plain Track-voiced screen with two visible actions, `exported=false`, `noHistory`, and no `FLAG_SECURE`; it never renders another app's name or UI. Ending is always possible, and the emergency dialler, launcher and keyboards are refused at both the engine and the platform layer | **Mitigated (by design)** | None identified |

---

## 3. Data at rest: what is and is not claimed

**Not claimed: encryption at rest.** Tracker data lives in a SQLite database in the
app's private storage. On a device where the app sandbox is intact, other apps
cannot read it; on a rooted device, or from a full-device forensic image, it is
readable. There is no SQLCipher, no per-field encryption and no key management in
this codebase, so none is advertised in the Play listing or in the app.

If you need that property later, the honest options are (a) SQLCipher via a Drift
`QueryExecutor` wrapper — a schema-compatible change with a migration for the
key-material store, or (b) moving the sensitive columns behind an encrypted blob
with an Android Keystore-held key. Either is a project, not a config flag, and
either makes "export always works" harder — which is why it is not in this release.

What *is* claimed and implemented:

- Data never leaves the device except a purchase token to your own backend.
- Android cloud backup is disabled for the app (`allowBackup="false"`,
  `fullBackupContent="false"`), so health data is not silently copied to the user's
  Google Drive.
- Health Connect is read-only, foreground-only, and asks for three data types
  (steps, sleep, weight) and nothing else. Background read permission was
  deliberately **removed**.
- Deleting all data deletes: `daily_entries`, `events`, `app_settings` — including
  the cached entitlement — and does not recreate anything.

---

## 4. Billing: the fail-closed model and its limits

The single most important change in this pass: **nothing the client can observe by
itself grants Pro.**

- `Entitlement.active` is true only when `verified` is true **and** `pending` is
  false **and** the plan is either lifetime or within `expiresAt + 3 days` **and**
  the last successful verification is younger than 7 days.
- A recognised product id is explicitly not sufficient (there is a regression test
  for exactly that).
- The purchase path acknowledges with Play immediately (the 3-day auto-refund rule)
  and then queues the claim: `pending: true, verified: false`, which grants nothing.
- `reconcile()` treats a *rejection* as a revocation and an *outage* as a
  retryable state. Collapsing those two is the classic way to either lock out paying
  users or to never revoke a refund.

**Residual risk, stated plainly.** An attacker with root can edit the cached
entitlement JSON and set `verified: true` with a fresh `verifiedAt`. The app will
grant Pro for up to 7 days, then require a real verification, which will fail (or
succeed, if they genuinely own a subscription). Removing that window entirely
requires the paid features to be gated by the server, which contradicts "your data
stays on your device and export is always free". The chosen trade-off bounds the
loss to a ≤ 7-day window per attacker with root on their own device, and keeps the
privacy promise. Monetisation must be measured against that, not against a
zero-loss assumption.

---

## 5. Findings from this pass

| ID | Severity | Finding | Fix | Status |
|---|---|---|---|---|
| S-01 | **High** | `Entitlement.active` returned true for unverified purchases; a recognised product id was enough to unlock Pro | Fail-closed rewrite; regression tests | **Fixed** |
| S-02 | **High** | `SUBSCRIPTION_CANCELED` wrote `undefined` over the stored expiry, cutting a paying user's access short | Store only writes fields it actually receives; `needsReverify` flag instead | **Fixed** |
| S-03 | **High** | Play API errors retained the original throwable, whose message can contain the token in the URL path | `PlayUnavailableError` keeps a sanitised summary only; `scrub()` on all string log values | **Fixed** |
| S-04 | **High** | `LocalOnlyVerifier` was the documented development default for `main.dart`, i.e. one wrong line from shipping client-side-only trust | `main.dart` passes `null` when no backend is configured; the stub throws in release; release gate fails if it is reachable from `main.dart` | **Fixed** |
| S-05 | **Medium** | Oversized request bodies destroyed the socket, so a client saw a connection reset instead of a rejection | Drain and answer `413` | **Fixed** |
| S-06 | **Medium** | Haptics passed `FLAG_IGNORE_GLOBAL_SETTING`, overriding the user's system-wide haptics preference | Flag removed; only the view-level flag is used | **Fixed** |
| S-07 | **Medium** | Notification bodies named trackers on the lock screen by default | Generic bodies by default, `visibility: private`, explicit opt-in with honest copy | **Fixed** |
| S-08 | **Medium** | Android cloud backup was left on for a health app | `allowBackup=false` | **Fixed** |
| S-09 | **Low** | Install ids and e-mail could be logged if they ever reached the logger | Added to the redaction key list | **Fixed** |
| S-10 | **Low** | `READ_HEALTH_DATA_IN_BACKGROUND` was requested with nothing needing it | Removed from the manifest | **Fixed** |
| S-11 | **Low** | No integrity hook on `/billing/verify` | Pluggable `integrityCheck` (Play Integrity) documented and wired, inert until configured | **Accepted** |
| S-12 | Medium | Health permission revocation is not detected on resume | Open — `PRODUCTION_READINESS.md` §11 item 5 | **Open** |

---

## 6. Verification checklist for the next reviewer

```bash
# 1. the release gate (fast, no SDK needed)
python3 tools/release_gate.py                     # expect: exit 0

# 2. no secrets in the tree
grep -rInE '(api[_-]?key|secret|password|token)"?\s*[:=]\s*"[A-Za-z0-9_\-]{16,}"' \
  --include='*.dart' --include='*.kt' --include='*.gradle' --include='*.yaml' .
grep -rIn 'BEGIN .*PRIVATE' .                      # expect: nothing

# 3. the money path
cd billing_server && npm test                      # expect: 60 pass
grep -n "verified" src/verifier.js | head          # the only place validity is decided

# 4. the client cannot grant Pro alone
grep -n "active" ../../track_flutter/lib/config/pro_config.dart | head
grep -rn "Entitlement.provisional" ../../track_flutter/lib   # must be pending+unverified

# 5. on a device (BLOCKED here)
adb shell run-as com.track.app ls -l databases/    # confirm the DB is app-private
# then revoke notifications / Health Connect access and watch the app react
```

---

## 7. Things this review does not cover

- No penetration test, no fuzzing, no dynamic analysis of the APK.
- No review of Google's or the OEM's own components.
- No assessment of physical extraction resistance, which is not achievable in a
  software-only, root-trust-model Android app.
- The billing service has not been deployed or exercised against real Play
  responses; the tests use injected fakes by design.
