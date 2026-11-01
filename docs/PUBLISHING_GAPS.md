# Publishing gap register — Track Pro

Audit date: **2026-11-01** · Branch: `arena/b98feb0e-trackpro` · Base: `main@51a6adc`

**Verdict: NOT READY TO PUBLISH.** The app is a well-structured, statically
audited Flutter project, but **no Flutter artifact has ever been built**, CI has
never run, no signing key exists, the billing backend is not deployed, no Play
Console product exists, and the store listing has no assets. This file is the
complete list of what stands between the repository and a Play Store release.

It is deliberately separate from `PLAY_CHECKLIST.md` (the console-side
checklist) and `RELEASE.md` (the build procedure). This file records the
*state* of the repository and the *evidence* for each gap.

---

## 1. What was verified in this audit

All commands below were executed in this checkout on 2026-11-01.

| Check | Command | Result |
|---|---|---|
| Release gate | `python3 tools/release_gate.py` | **PASS** — 53 checks, 0 problems |
| Static audit | `python3 tools/static_audit.py` | **PASS** |
| Import audit | `python3 tools/import_audit.py` | **PASS** — 21 declared deps |
| Member audit | `python3 tools/member_audit.py` | **PASS** — 969 references |
| Symbol clash | `python3 tools/symbol_clash_audit.py` | **PASS** — 70 files |
| Test API audit | `python3 tools/test_api_audit.py` | **PASS** — 617 references |
| Billing server | `npm --prefix billing_server test` | **PASS** — 78/78 tests |
| Flutter toolchain | `flutter --version` | **ABSENT** — no Flutter/Dart SDK |
| Java / Gradle / Android SDK | `java -version`, `adb`, `aapt2` | **ABSENT** |
| `flutter analyze` / `flutter test` | — | **NEVER RUN** (no SDK) |
| `flutter build apk` / `appbundle` | — | **NEVER RUN** (no SDK) |
| Device smoke test | — | **NEVER RUN** (no device) |
| Play Console | — | **NO ACCESS** (no account/console in this environment) |

The Python and Node gates are real and passing, but they are text/structure
audits. They cannot prove that the Dart compiles, that the Android host links,
or that the app runs. Those are the gaps below.

---

## 2. The publish path, stage by stage

### Stage 0 — A build that compiles

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 0.1 | **The Dart code has never been compiled.** No `flutter analyze`, no `flutter test`, no `flutter build` has ever run in this repository. The only executed checks are Python text audits and the Node billing suite. | `docs/TEST_RESULTS.md` §1; `docs/UPGRADE_2026-10-20.md` §5; no build artifact in the tree | **P0** |
| 0.2 | **CI is not active.** The workflows are staged in `ci/workflows/`; moving them to `.github/workflows/` was rejected: `refusing to allow a GitHub App to create or update workflow .github/workflows/ci.yml without workflows permission`. The remote has no `.github/workflows/` at all. | `gh api repos/rolexsir-org/trackpro/contents/.github` → 404; `git push` output | **P0** |
| 0.3 | **`lib/data/db/database.g.dart` freshness is unverified.** The file is committed, but `build_runner` has never run against the current schema. The CI codegen gate is designed to catch this; it has never run. | `docs/AUDIT_2026-10-17.md` §1; `docs/INTEGRATION_AUDIT.md` §K | **P0** |
| 0.4 | **No `flutter analyze` result.** The project has strict lints (`strict-casts`, `strict-raw-types`, `require_trailing_commas`, `unawaited_futures`) and 51+ lib files that have never been through the analyzer. | `analysis_options.yaml`; no analyzer output in the repo | **P0** |
| 0.5 | **No `flutter test` result.** 17 test files exist (4,600+ lines) and none has ever executed. Two real defects were already found by reading, which is what a first test run would have caught. | `ls test/*.dart \| wc -l` → 17; `docs/PRODUCTION_READINESS.md` §11 | **P0** |
| 0.6 | **No release build, no R8 run.** `isMinifyEnabled = true` and `isShrinkResources = true`; the keep rules in `proguard-rules.pro` are load-bearing but unproven. R8 failures only appear in a release build. | `android/app/build.gradle.kts`; `docs/RELEASE.md` §5 | **P0** |
| 0.7 | **No device smoke test.** Widgets, notifications, Focus Lock, Health Connect, billing and the overlay have never run on hardware. | `docs/PRODUCTION_READINESS.md` §7; `docs/FOCUS_LOCK.md` §3 | **P0** |

### Stage 1 — A signed, shippable artifact

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 1.1 | **No upload keystore.** `android/key.properties` does not exist, so a release build falls back to the debug key. A debug-signed AAB cannot be uploaded. | `android/app/build.gradle.kts` signing block; `docs/RELEASE.md` §2 | **P0** |
| 1.2 | **No `release-defines.json`.** The production build requires `TRACK_VERIFY_URL`, `TRACK_TERMS_URL`, `TRACK_PRIVACY_URL`, `TRACK_SUPPORT_EMAIL`. Without `TRACK_VERIFY_URL` the app **cannot grant Pro** (fail-closed). | `lib/config/app_environment.dart`; `docs/RELEASE.md` §3 | **P0** |
| 1.3 | **No AAB has ever been produced.** `build/app/outputs/bundle/release/app-release.aab` does not exist. | `find build -name '*.aab'` → none | **P0** |
| 1.4 | **No R8 `mapping.txt`.** Play requires the mapping for each release; it is produced only by a release build. | `docs/RELEASE.md` §4 | **P1** |
| 1.5 | **No version/tag/release.** `pubspec.yaml` is `1.0.0+12`; there are no git tags and no GitHub releases. Play requires a strictly increasing `versionCode` for every upload. | `git tag` → empty; `gh release list` → empty | **P1** |
| 1.6 | **No Play App Signing enrollment.** This happens at first upload in Play Console; it cannot be done from the repo. | `docs/PLAY_CHECKLIST.md` | **P1** |

### Stage 2 — A deployed verification backend

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 2.1 | **The billing server is not deployed.** The code is now runnable (`src/index.js`, Dockerfile, `.env.example`, 78 tests), but there is no host, no TLS certificate, no domain and no deploy pipeline. | `billing_server/Dockerfile`, `billing_server/.env.example`; no deployment config in the repo | **P0** |
| 2.2 | **No Play service account.** `GOOGLE_APPLICATION_CREDENTIALS` requires a service-account JSON with "View financial data" and the app scoped in Play Console. It does not exist. The client code that consumes it now exists (`src/play_client.js`). | `billing_server/OPERATIONS.md` §3; `billing_server/src/play_client.js` | **P0** |
| 2.3 | **No `TRACK_BILLING_API_KEYS`.** The client's bearer token has no configured value. The service now refuses to start without it. | `billing_server/src/index.js`; `OPERATIONS.md` §3 | **P0** |
| 2.4 | **No `TRACK_RTDN_SECRET`.** The RTDN endpoint is unauthenticated if this is unset. The service now refuses to start without it. | `billing_server/src/index.js`; `OPERATIONS.md` §3 | **P0** |
| 2.5 | **No persistent store path.** `TRACK_STORE_PATH` is unset; the file-backed store has no durable volume. The Docker image declares `/data/purchases.json`. | `billing_server/src/store.js`; `billing_server/Dockerfile` | **P1** |
| 2.6 | **No RTDN Pub/Sub topic/subscription.** Renewals, cancellations, refunds and revocations will not reach the server. | `MONETIZATION.md` §4; `billing_server/src/rtdn.js` (handler exists, not wired) | **P0** |
| 2.7 | **No monitoring/alerting.** The server logs one JSON line per event, but there is no log retention, alert, uptime check or incident runbook. | `billing_server/src/security.js`; `OPERATIONS.md` | **P1** |
| 2.8 | **No purge job.** Purchase records are kept forever; `docs/PRIVACY_DATA_FLOW.md` §7 says the purge job is not implemented. | `docs/PRIVACY_DATA_FLOW.md` §3/§7 | **P2** |

### Stage 3 — Play Console catalogue and declarations

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 3.1 | **No products created.** `track_pro_monthly`, `track_pro_annual`, `track_pro_lifetime` must exist with the exact IDs in `lib/config/pro_config.dart`. | `MONETIZATION.md` §1 | **P0** |
| 3.2 | **No `free-trial-7d` offer** on the annual base plan. The client expects `ProConfig.trialOfferId`. | `MONETIZATION.md` §1 | **P0** |
| 3.3 | **No merchant/payments profile.** Paid products cannot be enabled until the merchant account, bank account and tax info are complete. | `MONETIZATION.md` §1 | **P0** |
| 3.4 | **No licence testers.** The purchase/refund/restore matrix has never been exercised. | `MONETIZATION.md` §1/§6 | **P0** |
| 3.5 | **No Data safety form.** The answers are drafted in `docs/PRIVACY_DATA_FLOW.md` §6 but not filed. | `PLAY_CHECKLIST.md` | **P0** |
| 3.6 | **No Health Connect declaration.** Required because the app requests `READ_STEPS`, `READ_SLEEP`, `READ_WEIGHT`. | `AndroidManifest.xml`; `PLAY_CHECKLIST.md` | **P0** |
| 3.7 | **No FGS `specialUse` justification filed.** The draft is in `docs/FOCUS_LOCK.md` §6; rejection is a release blocker. | `AndroidManifest.xml`; `PLAY_CHECKLIST.md` | **P0** |
| 3.8 | **No `PACKAGE_USAGE_STATS` declaration.** High-scrutiny permission; the justification must mirror the manifest rationale. | `AndroidManifest.xml`; `PLAY_CHECKLIST.md` | **P0** |
| 3.9 | **No `SYSTEM_ALERT_WINDOW` declaration.** Declared use: user-started focus covering panel. | `AndroidManifest.xml`; `PLAY_CHECKLIST.md` | **P1** |
| 3.10 | **No ACTIVITY_RECOGNITION declaration.** Step counting. | `AndroidManifest.xml`; `PLAY_CHECKLIST.md` | **P1** |
| 3.11 | **No content rating / ads / news / financial / account-deletion answers filed.** The app has no accounts, no ads, no analytics SDK. | `PLAY_CHECKLIST.md` | **P1** |
| 3.12 | **No app access instructions for reviewers.** Pro features require a subscription; reviewers need a note or a licence-tester path. | `PLAY_CHECKLIST.md` | **P1** |
| 3.13 | **No closed-testing track.** A personal developer account needs 12+ testers for 14 continuous days before production access. | `MONETIZATION.md` §1; `PLAY_CHECKLIST.md` | **P0** |
| 3.14 | **No staged rollout plan / Android vitals watch.** Production should start at 10% → 50% → 100%. | `PLAY_CHECKLIST.md` | **P1** |

### Stage 4 — Store listing assets (none exist in the repo)

| # | Asset | Requirement | Status |
|---|---|---|---|
| 4.1 | App icon | 512 × 512 PNG, 32-bit, no transparency | **MISSING** |
| 4.2 | Feature graphic | 1024 × 500 PNG/JPEG | **MISSING** |
| 4.3 | Phone screenshots | ≥ 2 required, 8 recommended; 16:9 or 9:16, 320–3840 px | **MISSING** |
| 4.4 | 7-inch/10-inch tablet screenshots | Optional if not targeting tablets | **MISSING** |
| 4.5 | Short description | ≤ 80 chars | **MISSING** |
| 4.6 | Full description | ≤ 4000 chars | **MISSING** |
| 4.7 | App name | ≤ 30 chars; "Track Pro" is fine | **MISSING** (not filed) |
| 4.8 | Category | Health & Fitness or Productivity (pick one) | **MISSING** |
| 4.9 | Support email | Must match `TRACK_SUPPORT_EMAIL` | **MISSING** |
| 4.10 | Privacy policy URL | Public, HTTPS, live | **MISSING** |
| 4.11 | Terms of service URL | Public, HTTPS, live | **MISSING** |
| 4.12 | "What's new" release notes | Required per release | **MISSING** |
| 4.13 | Wear OS screenshots | Only if the Wear tile is actually shipped | **MISSING** (and see 5.1) |

The repository contains **zero** PNG/JPG/WebP files. There is no `store/`
directory, no `fastlane/` metadata, and no screenshot source.

### Stage 5 — Legal pages and policy

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 5.1 | **No hosted privacy policy.** The app falls back to a bundled disclosure sheet when `TRACK_PRIVACY_URL` is empty, but Play requires a public HTTPS URL. | `lib/config/app_environment.dart`; `lib/screens/settings_screen.dart` `openPolicy` | **P0** |
| 5.2 | **No hosted terms of service.** Same. | `lib/config/app_environment.dart`; `MONETIZATION.md` §9 | **P0** |
| 5.3 | **No support email/address.** `TRACK_SUPPORT_EMAIL` is a build-time define with no value. | `lib/config/app_environment.dart` | **P1** |
| 5.4 | **No data-retention statement for verification logs.** `PRIVACY_DATA_FLOW.md` says retention is "your log platform's policy — set it". | `docs/PRIVACY_DATA_FLOW.md` §3 | **P1** |
| 5.5 | **No purchase-record purge job.** See 2.8. | `docs/PRIVACY_DATA_FLOW.md` §7 | **P2** |

### Stage 6 — Product claims that are not backed by the build

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 6.1 | **The Wear OS tile is advertised but not built.** `ProConfig` and the paywall say "widget with 3 rings + Wear tile". The only Wear code is `android_overlay/wear/TrackTileService.kt`, which is **not** in `android/` and is not included by `android/settings.gradle.kts`. `WearSync.kt` is present, but there is no `:wear` module. | `android_overlay/wear/HOW_TO_ADD_WEAR.md` ("deliberately-disabled"); `android/settings.gradle.kts` `include(":app")` only; `ProConfig` free/Pro table | **P1** (misleading claim) |
| 6.2 | **The home-screen widget is built but never run.** `TrackWidget.kt` + `TrackWidgetReceiver` + Glance are in `android/`, and the keep rules are present. It has never been rendered. | `android/app/src/main/kotlin/.../TrackWidget.kt`; `proguard-rules.pro` | **P0** (device verification) |
| 6.3 | **`@layout/glance_default_loading_layout` is unverified.** `track_widget_info.xml` references it; it is expected to come from the Glance library, but no build has resolved it. | `android/app/src/main/res/xml/track_widget_info.xml` | **P1** (first build will tell) |
| 6.4 | **No crash/ANR monitoring.** A production incident would be discovered by reviews. | `docs/PRODUCTION_READINESS.md` §11 item 8 | **P1** |
| 6.5 | **No widget/golden tests.** Layout, contrast and text scaling are unverified. | `docs/PRODUCTION_READINESS.md` §9 TST-05 | **P2** |

### Stage 7 — Repository hygiene and release engineering

| # | Gap | Evidence | Severity |
|---|---|---|---|
| 7.1 | **No `LICENSE`.** The public repo has no license, so all rights are reserved by default. The Inter font license is present (`assets/fonts/Inter-LICENSE.txt`), but the app code has none. | `ls LICENSE*` → none; `gh repo view` `licenseInfo: null` | **P1** |
| 7.2 | **No `CHANGELOG.md`.** Play's "What's new" has no source. | `ls CHANGELOG*` → none | **P2** |
| 7.3 | **No `.github/ISSUE_TEMPLATE`, `SECURITY.md`, `CONTRIBUTING.md`, or `CODE_OF_CONDUCT.md`.** | `ls .github` → 404 | **P2** |
| 7.4 | **No release automation.** No tag-triggered workflow, no Fastlane, no Play upload. The release is a manual local build per `RELEASE.md`. | `ci/workflows/` (staged, not active) | **P2** |
| 7.5 | **`android_overlay/` is still in the repo.** It is marked SUPERSEDED, but it duplicates Kotlin/manifest files and is a drift risk. It also contains the only Wear code. | `android_overlay/README.md` | **P2** |
| 7.6 | **`tools/collect_evidence.sh` is missing** but referenced by `docs/TEST_RESULTS.md`, `docs/PRODUCTION_READINESS.md`, `docs/INTEGRATION_REPORT.md`, `docs/PRODUCT_COHERENCE_REPORT.md`. | `ls tools/collect_evidence.sh` → none | **P2** |
| 7.7 | **`TEST_EVIDENCE.txt` is missing** but referenced by five docs. | `ls TEST_EVIDENCE.txt` → none | **P2** |
| 7.8 | **No actual `release-defines.json` or `android/key.properties`.** Templates now exist (`release-defines.example.json`, `android/key.properties.example`), but the real files are still absent. The real files contain deployment-specific values and secrets and must not be committed. | `ls release-defines.json android/key.properties` → none | **P0** |
| 7.9 | **No deployment pipeline.** `Dockerfile` and `.env.example` now exist, but there is no Cloud Run/ECS/systemd config, no CI deploy step and no domain/TLS setup. | `billing_server/Dockerfile`, `.env.example`; no deploy config | **P1** |
| 7.10 | **No store assets filed.** `docs/STORE_LISTING.md` now has the draft copy, asset specs, content-rating/data-safety/FGS/usage-access answers and a pre-launch checklist, but no icon, feature graphic or screenshots exist and nothing has been filed in Play Console. | `docs/STORE_LISTING.md`; zero PNG/JPG/WebP files | **P0** |

---

## 3. Stale or contradictory documentation

These are not blockers by themselves, but they will mislead the person doing
the release. Each is a factual contradiction with the current tree.

| Doc | Stale claim | Current truth | Status |
|---|---|---|---|
| `README.md` | "Platforms: Android (primary), Linux desktop (dev convenience, in `linux/`)" | There is **no `linux/` directory**. The app uses Android-only plugins (`health`, `in_app_purchase_android`, `flutter_local_notifications`); a Linux desktop target would not build without work. | **FIXED** — README now says Android only |
| `README.md` | "Flutter stable ≥ 3.44 / Dart ≥ 3.12" | `pubspec.yaml` requires **Flutter ≥ 3.47.0 / Dart ≥ 3.13.0**; `pubspec.lock` matches. | **FIXED** |
| `README.md` | "CI (`.github/workflows/ci.yml`) runs the same gates" | The workflows are staged in `ci/workflows/`; moving them to `.github/workflows/` was **rejected** by the token's missing `workflows` permission. | **FIXED** — README now says staged / not active |
| `docs/RELEASE.md` | "51 structural checks" | `release_gate.py` now reports **53 checks**. | **FIXED** |
| `docs/RELEASE.md` | "The workflows live in `ci/workflows/` until somebody ... moves them" | They have been moved in the local commit, but the remote push is blocked. The activation step is still real. | **FIXED** — RELEASE now says staged / not active |
| `docs/PLAY_CHECKLIST.md` | "Billing Library ≥ 7" | `in_app_purchase_android` 0.5.5 ships **Billing Library 8**; Play requires 8 for new releases. | **FIXED** |
| `MONETIZATION.md` §3 | "in_app_purchase_android 0.5.x ships Play Billing 7.x" | 0.5.5 ships **Billing 8** (see `docs/UPGRADE_2026-10-20.md` §2). | **FIXED** |
| `MONETIZATION.md` §11 | "Verification backend — server is yours" / "RTDN handler — not yet done" | Both are **implemented** in `billing_server/` (78/78 tests pass, runnable via `src/index.js`). What is missing is **deployment**, not code. | **FIXED** |
| `docs/PRODUCTION_READINESS.md` | "database.g.dart does not exist"; schema v3; 13 test files | `database.g.dart` exists; schema is **v4**; there are **17** test files. The document is a 2026-10-16 snapshot. | **HISTORICAL** — snapshot header added |
| `docs/TEST_RESULTS.md` | "Nothing in this repository has been compiled" | Still true for Flutter, but the doc's "13 suites" is stale (17 files). | **HISTORICAL** — snapshot header added |
| `docs/INTEGRATION_AUDIT.md` §K | "database.g.dart still does not exist" | It exists; freshness is unverified, not absent. | **HISTORICAL** — snapshot header added |
| `docs/INTEGRATION_REPORT.md` | References `/home/user/TEST_EVIDENCE.txt` | That path is outside the repo and not present. | **HISTORICAL** — snapshot header added |
| `docs/PRODUCT_COHERENCE_REPORT.md` | References `TEST_EVIDENCE.txt` | Missing. | **HISTORICAL** — snapshot header added |
| `docs/FOCUS_LOCK.md` | References `../TEST_EVIDENCE.txt` | Missing. | **HISTORICAL** — snapshot header added |

---

## 4. Prioritized action plan

### P0 — must happen before any upload

1. **Activate CI with a `workflows`-permission token.** The files are staged in
   `ci/workflows/`. Either:
   - move them to `.github/workflows/` and push with a token/credential that has
     the `workflows` scope, or
   - add the two files through the GitHub web UI (the procedure is in
     `ci/README.md`), or
   - run `bash tools/run_gates.sh --build` on a machine with Flutter 3.47.7,
     JDK 17 and Android SDK 36.
   The first green run will produce the `flutter analyze` / `flutter test` /
   build evidence that this repository has never had.
2. **Fix every compile/analyze/test failure the first run exposes.** Expect
   errors; the code has never been through a compiler. Fix the code, not the
   expectation.
3. **Create the upload keystore** per `docs/RELEASE.md` §2 and add
   `android/key.properties` (git-ignored). Verify the AAB certificate is not
   "Android Debug".
4. **Deploy the billing server** (now runnable via `src/index.js` / Docker) with
   TLS, a service account, API keys, an RTDN secret, a persistent store and a
   Pub/Sub subscription. Set `TRACK_VERIFY_URL` to the deployed `/billing/verify`.
5. **Host the privacy policy and terms** at public HTTPS URLs. Set
   `TRACK_PRIVACY_URL`, `TRACK_TERMS_URL`, `TRACK_SUPPORT_EMAIL`.
6. **Create the Play Console products** (`track_pro_monthly`,
   `track_pro_annual`, `track_pro_lifetime`, `free-trial-7d`) and complete the
   merchant/payments profile.
7. **Build the signed AAB** with `--dart-define-from-file=release-defines.json`
   and exercise the release build on a real device (the smoke list in
   `docs/RELEASE.md` §5).
8. **File the Play declarations**: Data safety, Health Connect, FGS
   `specialUse`, `PACKAGE_USAGE_STATS`, `SYSTEM_ALERT_WINDOW`,
   `ACTIVITY_RECOGNITION`, content rating, ads, account deletion.
9. **Run licence testing** through pending → active → cancel → refund → revoke
   → restore, on Android 13/14/15.
10. **Recruit 12+ testers for 14 continuous days** (personal account) before
    applying for production access.

### P1 — must happen before production rollout

- Store listing assets: 512 icon, 1024×500 feature graphic, ≥ 2 (ideally 8)
  phone screenshots, short/full description, category, support email, "What's
  new".
- Decide the Wear claim: either build and include the `:wear` module, or remove
  "Wear tile" from `ProConfig`/paywall/store copy. Do not ship a claim the
  build does not contain.
- Add `LICENSE`, `CHANGELOG.md`, and a release workflow (tag → build → upload
  to Play via a service account, or at least attach the AAB + mapping to a
  GitHub release).
- Add crash/ANR reporting (Play Console vitals is the minimum; a crash SDK is a
  privacy decision — document it).
- Add a `docs/STORE_LISTING.md` with the exact copy and asset specs.
- Add `billing_server/.env.example`, a Dockerfile, and a deploy runbook.
- Add the purchase-record purge job and a log-retention statement.
- Run a pre-launch report and fix every issue it flags.
- Staged rollout: 10% → 50% → 100%, watching Android vitals.

### P2 — hygiene

- Add `tools/collect_evidence.sh` and regenerate `TEST_EVIDENCE.txt`, or remove
  the references from the docs.
- Mark the historical status docs (`PRODUCTION_READINESS`, `TEST_RESULTS`,
  `INTEGRATION_AUDIT`, `INTEGRATION_REPORT`, `PRODUCT_COHERENCE_REPORT`,
  `FOCUS_LOCK`) as snapshots with a "current status" pointer to this file.
- Remove or archive `android_overlay/` after the Wear decision.
- Add issue/PR templates, `SECURITY.md`, `CONTRIBUTING.md`,
  `CODE_OF_CONDUCT.md`.
- Add widget/golden tests and a 90-day query benchmark.
- Remove the `linux/` platform from `.metadata` / `analysis_options.yaml` if
  Linux is not a target (or add a real `linux/` runner and test it).

---

## 5. Definition of done

A release is publishable only when **all** of these are true:

- [ ] `flutter analyze` passes on Flutter 3.47.7 / Dart 3.13.5.
- [ ] `flutter test` passes (17 files, 0 failures).
- [ ] `dart run build_runner build` produces no diff in `database.g.dart`.
- [ ] `dart format --set-exit-if-changed` passes.
- [ ] `flutter build apk --release` and `flutter build appbundle --release`
      succeed with the production defines.
- [ ] The AAB is signed with the upload keystore (not "Android Debug").
- [ ] The release build is installed and exercised on a real device; the
      widget, notifications, Focus Lock, Health Connect, billing and dark mode
      all work.
- [ ] The billing server is deployed, reachable over HTTPS, and a real
      licence-tester purchase verifies end to end.
- [ ] The privacy policy and terms are live at the URLs compiled into the app.
- [ ] All Play Console products, offers, declarations and Data safety answers
      are filed and approved.
- [ ] The store listing has an icon, feature graphic, screenshots, descriptions
      and support email.
- [ ] A closed-testing run has passed, and production access is granted.
- [ ] `mapping.txt` is uploaded with the release.
- [ ] A staged rollout plan and rollback plan are in place.

Until then, the honest status is **NOT READY** — not "conditionally ready".
