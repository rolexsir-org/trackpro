# Store listing — Track Pro

Everything the Play Console listing needs, in one place. **Nothing in this file
has been filed in Play Console yet.** The repository contains no store assets
(zero PNG/JPG/WebP files); the copy below is a draft to review, not a published
listing.

Play's requirements move. Verify each field against the current Play Console
before submitting.

---

## 1. Identity

| Field | Value |
|---|---|
| App name | **Track Pro** (30-char limit) |
| Package / application ID | `com.track.app` (permanent) |
| Version | `1.0.0` (versionCode `12` in `pubspec.yaml`) |
| Category | **Health & Fitness** |
| Tags | habit tracker, water intake, mood, sleep, focus, screen time, health |
| Support email | `support@YOUR-SITE` (must match `TRACK_SUPPORT_EMAIL`) |
| Privacy policy URL | `https://YOUR-SITE/track/privacy` (must match `TRACK_PRIVACY_URL`) |
| Terms of service URL | `https://YOUR-SITE/track/terms` (must match `TRACK_TERMS_URL`) |
| Website | optional; use the same site as the policy pages |

## 2. Short description (≤ 80 characters)

```
Track water, mood, sleep, habits and focus — privately, on your phone.
```

(70 characters.)

## 3. Full description (≤ 4000 characters)

```
Track Pro is one calm place for the things you track every day: water, mood, sleep, expenses, calories, steps, cycle, screen time, weight and the commitments you keep.

• One dashboard, ten trackers. Log a value in seconds, or let Health Connect fill in steps, sleep and weight.
• Commitments, not just habits. Define an outcome and a minimum, then record full / minimum / missed / rest. Momentum shows the run you are on, the patterns behind it, and a restart plan when you need one.
• Focus Lock. Start a timed session, choose the apps to cover, and keep a visible timer with an end action. Free sessions cover three apps; Pro covers the whole list.
• A home-screen widget with today's rings and your streak.
• Private by design. No account, no ads, no third-party analytics, no cloud sync. Your data stays in your phone's app-private storage. Export it as JSON or CSV at any time, and delete everything from Settings.
• Pro: every tracker, full history, Health Connect sync, unlimited focus apps, profiles, schedules and patterns. 7 days free on the annual plan.

No ads. No tracking. Your data is yours.
```

(About 1,100 characters. Check the live count in Play Console; the limit is
4,000.)

**Do not claim the Wear tile** unless the `:wear` module is built and included.
The only Wear code is `android_overlay/wear/TrackTileService.kt`, which is not
in `android/settings.gradle.kts` and is not part of the build. The current
`ProConfig` paywall copy says "widget with 3 rings + Wear tile" — either build
the module or remove the claim before submitting.

## 4. "What's new" release notes (1.0.0)

```
Track Pro 1.0.0 — the first release.

• Ten trackers in one place: water, mood, sleep, expenses, calories, steps, cycle, screen time, weight and commitments.
• Momentum: streaks, patterns and restart plans.
• Focus Lock with a visible timer and app covering.
• Home-screen widget.
• Private by design: no account, no ads, no third-party analytics. Export or delete your data at any time.
• Pro: full history, Health Connect sync, unlimited focus apps, profiles, schedules and patterns. 7 days free on the annual plan.
```

## 5. Graphic assets (all missing)

| Asset | Spec | Status |
|---|---|---|
| App icon | 512 × 512 px, 32-bit PNG, no transparency, no rounded corners (Play applies the mask) | **MISSING** |
| Feature graphic | 1024 × 500 px, PNG/JPEG, no transparency | **MISSING** |
| Phone screenshots | 2–8 images, 16:9 or 9:16, 320–3840 px per side, PNG/JPEG, no transparency. Recommended: 1080 × 1920 or 1080 × 2400. | **MISSING** |
| 7-inch tablet screenshots | 1200 × 1920 px (optional if not targeting tablets) | **MISSING** |
| 10-inch tablet screenshots | 1600 × 2560 px (optional) | **MISSING** |
| Wear screenshots | Only if the Wear tile is actually built | **MISSING / DO NOT CLAIM** |

Suggested phone screenshots (in order):

1. Today dashboard — rings, habit queue, one-tap logging.
2. Momentum — streak, 14-day strip, weekly review.
3. Focus Lock — session timer, app list, covering panel.
4. Insights — correlations and patterns (Pro).
5. Home-screen widget — three rings + streak.
6. Paywall — clear pricing, trial terms, manage/cancel link.

## 6. Content rating questionnaire (draft answers)

| Question | Answer |
|---|---|
| Does the app contain violence, blood or gore? | No |
| Does the app contain sexual content or nudity? | No |
| Does the app contain profanity or crude humor? | No |
| Does the app contain controlled substances, alcohol or tobacco? | No |
| Does the app contain gambling or simulated gambling? | No |
| Does the app contain user-generated content shared with others? | No (no accounts, no sharing, no social features) |
| Does the app have in-app purchases? | **Yes** — auto-renewing subscriptions and a one-time lifetime product |
| Is the app a health/fitness app? | Yes — it stores health-related data on-device |
| Does the app target children? | No (general audience; not designed for children) |

Complete the questionnaire truthfully in Play Console; the answers above are a
starting point, not a substitute for the live form.

## 7. Data safety form (draft answers)

The full data inventory is `docs/PRIVACY_DATA_FLOW.md`; §6 there maps each Play
question to an answer. Summary:

| Play question | Answer |
|---|---|
| Does your app collect or share user data? | **Collect: no. Share: no.** Tracker data is created and stored on the device. |
| Data types collected | None of the Play "personal data" categories. Health and fitness data is collected on-device, not transmitted. |
| Is data encrypted in transit? | Yes — the only network call is the purchase-token verification to the developer's HTTPS backend. |
| Can users request deletion? | Yes — Settings → Delete all data. |
| Health Connect data | Read-only steps, sleep, weight; no background read; never transmitted; user can revoke. |
| Usage access data | Package names + timestamps processed on-device for Focus Lock; never transmitted; user can revoke. |
| Purchase data | Purchase token + product id + package name sent to the developer's verification service for app functionality (service-provider processing). Declare under *App functionality* and be consistent with the privacy policy. |
| Ads | No ads SDK. |
| Analytics | No third-party analytics SDK is integrated. `ProAnalytics` is a local SQLite table, not a network SDK. Platform components (Play services / Health Connect / Play Billing) may send their own SDK diagnostics to Google — not tracker data, and not suppressible from app code. Read `docs/PRIVACY_DATA_FLOW.md` §2 before filing this row. |
| Crash reporting | None. |
| Backup | `allowBackup=false`; tracker data is not copied to Android cloud backup. |

## 8. Sensitive permissions and declarations

### 8.1 Health Connect

> Track Pro reads steps, sleep and weight from Health Connect, only after the
> user grants permission in the Health Connect permission sheet. The data is
> read-only: the app never writes to Health Connect and never requests
> background read access. The values are stored in the app's private SQLite
> database and are never transmitted. The user can revoke access at any time in
> Health Connect settings; the app then degrades to manual logging.

### 8.2 Foreground service `specialUse` (Focus Lock)

> Track Pro is a habit tracker. Its Focus Lock feature lets a user run a timed
> focus session and, if they grant usage access and the display-over-other-apps
> permission, have the apps they chose covered for that session. The foreground
> service polls `UsageStatsManager.queryEvents` for foreground-app transitions
> and shows a notice with a running timer and an "End" action, so the user can
> always see that a session is active and stop it. No other category fits: the
> work is not media playback, not location, not a call, not a data sync and not
> a health service. It is a user-started, user-visible, bounded session (5–180
> minutes) that ends when the timer reaches zero or the user taps End. The
> service is `exported=false`, holds no other app's data, and stores nothing but
> its own counters.

Subtype: `focus_session_detector` (already in `AndroidManifest.xml`).

### 8.3 `PACKAGE_USAGE_STATS` (Usage access)

> Track Pro's Focus Lock feature lets a user run a timed focus session and, if
> they grant usage access, cover the apps they chose for the length of the
> session. The service polls `UsageStatsManager` for foreground-app
> transitions, shows a visible notification with a running timer and an End
> action, and records only three counters (opens detected, panels shown,
> foreground events observed). It does not read screen content, messages,
> notifications, credentials, location, contacts or any other app's data. The
> data is processed on-device, never transmitted, and the user can revoke usage
> access at any time in Android settings; the session is then recorded as
> degraded rather than as a clean completion.

### 8.4 `SYSTEM_ALERT_WINDOW` (display over other apps)

> Track Pro's Focus Lock feature shows a user-started, user-visible covering
> panel over the apps the user selected for the length of a focus session. The
> panel has a running timer and an End action, is not shown outside a session,
> and is dismissed when the session ends or the user taps End. It does not
> display ads, does not collect data, and does not cover the system UI or other
> apps' controls.

### 8.5 `ACTIVITY_RECOGNITION` (step counting)

> Track Pro reads step counts from Health Connect / the system activity
> provider for the user's own step tracker. The data is processed on-device and
> is never transmitted. The user can revoke the permission at any time.

## 9. Review access

- The app has **no login**. Select "All functionality is available without
  special access."
- Pro features require a subscription. Add a note for reviewers: "Pro can be
  tested with a Play licence tester; the free tier includes any 5 trackers, 7 days
  of history, the daily check-in reminder, the home-screen widget (1 ring) and
  Focus Lock up to 3 apps."
- If a reviewer asks for a test account, explain that there are no accounts and
  provide a licence-tester purchase path.

## 10. Pre-launch checklist

- [ ] App icon, feature graphic and screenshots uploaded.
- [ ] Short and full descriptions saved.
- [ ] Category and tags saved.
- [ ] Support email, privacy URL and terms URL saved and live.
- [ ] Data safety form completed and saved.
- [ ] Health Connect declaration completed.
- [ ] FGS `specialUse` declaration completed.
- [ ] Usage access and `SYSTEM_ALERT_WINDOW` declarations completed.
- [ ] Content rating questionnaire completed.
- [ ] Ads declaration: no ads.
- [ ] News/COVID/financial/government: no.
- [ ] Account deletion: no accounts.
- [ ] Products and offers created; licence testers added.
- [ ] Closed testing track started (12+ testers, 14 continuous days for a
      personal account).
- [ ] Pre-launch report reviewed; all issues fixed.
- [ ] Staged rollout plan ready (10% → 50% → 100%).

## 11. Open decisions

1. **Wear tile** — build the `:wear` module or remove the claim from
   `ProConfig`, the paywall and this listing. Do not ship the claim as-is.
2. **Category** — Health & Fitness vs Productivity. Pick one and keep it; the
   listing copy above assumes Health & Fitness.
3. **Support email / domain** — the app has no hosted site. Stand up a minimal
   site for the privacy policy, terms and support contact, or use a reputable
   policy-page host. The URLs must be HTTPS and public.
4. **License** — the repository has no `LICENSE`. Add one before publishing the
   source; the Inter font license is already in `assets/fonts/`.
