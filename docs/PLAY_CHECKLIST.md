# Google Play submission checklist — Track Pro

Verify each item against the **current** Play Console requirements at release
time; policies move. Items marked ⚠ are known open items for this app.
Technical readiness ≠ account eligibility, policy approval or publication.

## Identity & artifact
- [ ] Application ID `com.track.app` — permanent, matches `_packageName` in `lib/main.dart`.
- [ ] `versionCode` strictly greater than every previous upload (`pubspec.yaml` `+n`).
- [ ] AAB built with `--dart-define-from-file=release-defines.json` and signed with the **upload keystore** (verify: `keytool -printcert -jarfile app-release.aab` shows your cert, not "Android Debug").
- [ ] Play App Signing enrolled at first upload; R8 `mapping.txt` uploaded for the release.
- [ ] Target API: targetSdk 36 — confirm it meets the current Play target-API deadline at submission time.
- [ ] 64-bit: Flutter ships arm64-v8a — confirmed in CI artifact check.

## App content declarations (Play Console → App content)
- [ ] **Privacy policy URL** — must be live, public, HTTPS (⚠ must be hosted before submission; the same URL goes in `TRACK_PRIVACY_URL`).
- [ ] **Data safety form** — truthful baseline for this app: all tracker data stored locally (SQLite, no cloud sync, backups disabled); purchase verification sends purchase token + package name to your backend over HTTPS; Health Connect data (steps/sleep/weight) read-only, never leaves the device; no ads SDK, no analytics SDK, no third-party data sharing. Cross-check `docs/PRIVACY_DATA_FLOW.md`.
- [ ] **Health apps / Health Connect declaration** — required because the app requests `android.permission.health.READ_*`. Complete the Health Connect data-use declaration; expect extra review.
- [ ] **Foreground service (`specialUse`)** — written justification for the Focus Lock session detector (user-started, user-visible session; subtype `focus_session_detector`). See `docs/FOCUS_LOCK.md` §6. ⚠ Rejection here is a release blocker.
- [ ] **ACTIVITY_RECOGNITION / Physical activity** permission declaration (step counting).
- [ ] **PACKAGE_USAGE_STATS** — App needs the Usage Access sensitive-permission declaration (Focus Lock: detect foreground app chosen by the user). ⚠ High-scrutiny permission; justification text should mirror the manifest rationale.
- [ ] **SYSTEM_ALERT_WINDOW** — declared use: user-started focus covering panel.
- [ ] **Ads declaration**: no ads.
- [ ] **Content rating questionnaire** (likely "Everyone"; health & fitness category).
- [ ] **News/COVID/financial/government**: not applicable — answer "no".
- [ ] **Account deletion requirement**: app has **no accounts** — answer "no account creation". Local data deletion exists in Settings → Data.

## Monetisation
- [ ] Subscription products created in Play Console matching the IDs in `lib/config/pro_config.dart` / `MONETIZATION.md`, each with at least one base plan + offer.
- [ ] Billing Library ≥ 7 (ships via `in_app_purchase_android`) — check the Play Console deprecation page at submission.
- [ ] Purchase-verification backend deployed and reachable at `TRACK_VERIFY_URL` (without it Pro can never be granted — fail-closed by design).
- [ ] In-app path to cancel/manage subscription works (paywall → Play subscriptions deep link).
- [ ] License testers added; a test purchase + refund + restore exercised on a device.

## Store listing
- [ ] App icon 512×512, feature graphic 1024×500, ≥ 2 phone screenshots (8 recommended), short + full description.
- [ ] Category: Health & Fitness (or Productivity — pick once, keep).
- [ ] Support email (same as `TRACK_SUPPORT_EMAIL`).

## Review access & rollout
- [ ] App access: no login → "All functionality available without special access". Note for reviewers: Pro features require a subscription; provide a license-tester account note if asked.
- [ ] Track order: internal testing → closed testing → production. New personal accounts must meet Play's closed-testing requirement (14 days / 12+ testers at the time of writing — verify current rule).
- [ ] Staged rollout (e.g. 10% → 50% → 100%) with Android vitals watched between stages.
- [ ] Pre-launch report reviewed (Play runs it automatically on upload).

## Must never ship
- [ ] No keystore/passwords/`key.properties` in the repo (git-ignored; verify `git ls-files | grep -Ei 'jks|keystore|key.properties'` is empty).
- [ ] No demo/seeded data path (removed at source — `EntryRepository.bootstrap()` takes no seeder).
- [ ] No `SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM` unless `NotificationService(exactScheduling: true)` is ever enabled — then the Console exact-alarm declaration is mandatory.
