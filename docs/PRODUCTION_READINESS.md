# Production readiness — Track (Momentum)

Status document for the habit-first rebuild. Every row carries an ID, an acceptance
criterion, the evidence that exists **right now**, a status, the residual risk, and
who has to close it.

Status vocabulary, used strictly:

| Status | Means |
|---|---|
| **PASS** | An executed command in this repository produced the result claimed. Reproducible here. |
| **NOT TESTED** | The code exists and is reviewed, but no command has ever executed it (no Flutter SDK on this host). |
| **BLOCKED** | Requires something this environment does not have: a Flutter/Gradle toolchain, a device, Play Console access. |
| **FAIL** | A gate was executed and failed. |

Owner codes: `ENG` (app), `OPS` (backend/deploy), `REL` (release chain), `PM` (product/pricing), `LEGAL` (policy pages).

Verdict: **NOT READY** — §12. Nothing here has been compiled, and no build has run
on a device.

---

## 0. Host probe (what this machine can and cannot prove)

Executed 2026-10-16 (`bash tools/collect_evidence.sh`):

```
flutter  ABSENT        dart     ABSENT        gradle   ABSENT
kotlinc  ABSENT        aapt2    ABSENT        adb      ABSENT
java     /usr/bin/java  node v20.20.2  npm  python3 3.13.16
cpus 2, free disk 21G
```

Consequence: **every Flutter gate is BLOCKED here** — `flutter --version`,
`pub get`, `build_runner` (so `lib/data/db/database.g.dart` does not exist), `dart
format`, `analyze`, `test`, `build apk|aab`. Device passes are BLOCKED (no `adb`,
no hardware). Play Console and licence testing are BLOCKED (no console access).

What *is* available and used as evidence: the Node billing backend with its 60-test
suite, and three text audits (`tools/static_audit.py`, `tools/import_audit.py`,
`../tools/release_gate.py`) plus `tools/test_api_audit.py` and the Dart test sources
they check.

---

## 1. Product structure (what the app now is)

| Section | Screen | What it does |
|---|---|---|
| Today | `today_screen.dart` | The commitment queue first (full / minimum / rest / skip, one tap each), then measurements, then observations with their samples |
| Routines | `routines_screen.dart` | Create, edit, schedule, pause, archive, delete commitments; starter templates; Measurements entry point |
| Momentum | `momentum_screen.dart` | The consistency record: rate + sample, 14-day strip, streaks, restart plans, weekday patterns, weekly review, and the full method |
| Insights | `insights_screen.dart` | Cross-tracker patterns from the measurement data, still gated by Pro for the advanced half |
| Profile | `settings_screen.dart` | Tiers, notifications, data (export/delete), diagnostics, Pro management, legal |

The engine behind Momentum lives in `lib/data/momentum.dart` (pure, 500 lines) and
`lib/data/commitment_repository.dart` (storage, 520 lines), with the model layer in
`lib/models/models.dart` and the schema in `lib/data/db/database.dart` (v3).

---

## 2. Demo data, seeded history, fabricated metrics (directive phase 2 & 4)

Full evidence: `docs/MOCK_DATA_AUDIT.md`. Machine checks: release gate P-01, P-01b,
P-07, P-15, P-16, P-17; `test/demo_policy_test.dart`.

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| DEM-01 | Production start-up cannot seed history | `EntryRepository.bootstrap()` has no seeder parameter; `BootstrapReport` has no `seededDemo` | `grep -n "bootstrap(" lib/data/entry_repository.dart lib/state/app_state.dart lib/main.dart`; audit | **PASS** (text-verified) | none structural; a future contributor could re-add a parameter — P-01b fails if they do | ENG |
| DEM-02 | The seeder is gone | `lib/data/demo_seed.dart` deleted; no reference in `lib/` | `grep -rn "DemoSeed" lib/` → only a comment in `main.dart` | **PASS** | — | ENG |
| DEM-03 | No build-time demo switch | `TRACK_DEMO_SEED` / `demoSeedEnabled` removed from `app_environment.dart` | `grep -rn "TRACK_DEMO_SEED" lib/` → nothing | **PASS** | — | ENG |
| DEM-04 | Fixtures live only under `test/` | `lib/` cannot import `test/fixtures/demo_fixtures.dart` | `python3 tools/import_audit.py`; demo-policy clause 2 scans every `lib/**/*.dart` | **NOT TESTED** (test written, never executed) | a compile error, not a silent leak | ENG |
| DEM-05 | Fresh install shows honest empty states | Zero entries, zero tracked days, no "tracking since" | `test/repository_test.dart`, `test/demo_policy_test.dart` clause 1 | **NOT TESTED** | — | ENG |
| DEM-06 | Fabricated metrics removed | `1,284`, `23-day streak`, `28 days of history`, `Jai Deshmukh`, the 12-day-promo headline, the unconditional PRO badge | `python3 ../tools/release_gate.py` (P-07, P-16, P-17, P-19; 20 checks, clean, exit 0); `docs/MOCK_DATA_AUDIT.md` §2 | **PASS** (gate clean, exit 0) | other copy could still make an unsupported claim; review copy changes like code | ENG |
| DEM-07 | Reset deletes rather than recreates | After `deleteAllUserData()`: 0 entries, 0 demo rows, 0 sources | `test/demo_policy_test.dart` clause 4; `test/repository_test.dart` | **NOT TESTED** | — | ENG |
| DEM-08 | Legacy habit history converts once, non-destructively | Habits + ticked days become commitments; second run is a no-op; original rows untouched | `test/commitment_repository_test.dart` (5 cases) | **NOT TESTED** | positional-index limitation, stated in-app | ENG |

## 3. Database integrity (directive phase 3)

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| DB-01 | Atomic writes | Rollup + event row in one transaction | `EntryRepository` write paths; read by hand | **NOT TESTED** | no crash-injection harness exists | ENG |
| DB-02 | Duplicate prevention | A repeated tap yields one row per (routine, day) / (tracker, day, source) | `test/commitment_repository_test.dart` "a repeated tap replaces"; `test/repository_test.dart` | **NOT TESTED** | — | ENG |
| DB-03 | Migration v2 → v3 preserves data | Open a v2-shaped DB with history; v3 tables appear; old rows readable | `test/commitment_repository_test.dart` group "migration from the v2 schema" (2 cases) | **NOT TESTED** | the test's v2 DDL is hand-written; if v2's real DDL differs the test could pass on a shape no user has | ENG |
| DB-04 | Destructive changes are not silent | No `drop`, no data rewrite in `onUpgrade`; conversion is an explicit idempotent import | `grep -n "drop\|delete" lib/data/db/database.dart` (none in migration); `commitment_repository.dart` importLegacyHabits | **PASS** (text-verified) | — | ENG |
| DB-05 | Timezone / midnight / DST correctness | Day keys are local calendar days; stepping a day always moves exactly one calendar day | `test/momentum_engine_test.dart` group "day keys are local calendar days" (3 cases, incl. 400 consecutive days) | **NOT TESTED** | host TZ affects nothing here because the assertions are component-based | ENG |
| DB-06 | Malformed / out-of-range input refused | Negative, NaN, ∞ and out-of-bounds values are rejected before writing | `test/repository_test.dart`; `lib/data/value_validation.dart` | **NOT TESTED** | — | ENG |
| DB-07 | Source precedence | manual > health > legacy sample; a health sync never overwrites a typed value and replaces a sample row rather than doubling it | `lib/data/entry_repository.dart` `mergeHealthSeries`; `test/repository_test.dart` | **NOT TESTED** | precedence is per (tracker, day); a same-day manual *event* and a health *rollup* can still both exist — documented, not resolved | ENG |
| DB-08 | Integrity + foreign keys | `PRAGMA integrity_check` and `foreign_key_check` exposed and surfaced in Diagnostics | `TrackDao.integrityCheck()`, `foreignKeyViolationCount()`; `Settings → Diagnostics` | **NOT TESTED** | — | ENG |
| DB-09 | Bounded memory / query cost | Reads come from a 90-day projection; aggregates are SQL; nothing scans the full table per frame | design in `EntryRepository` (documented); **no benchmark exists** | **NOT TESTED** | 90-day query cost unmeasured — see §11 | ENG |
| DB-10 | Export + deletion are user-reachable | Export CSV/JSON (always free); "Delete all data" with confirmation | `settings_screen.dart` rows; `EntryRepository.exportCsv/exportJson/deleteAllUserData` | **NOT TESTED** | export does not yet include commitments — see §11 item 4 | ENG |

## 4. Momentum (the signature system)

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| MOM-01 | Outcome + minimum per commitment | A commitment cannot be saved without both, and both are shown when logging | `commitment_sheets.dart` `_EditorBody._save()` validation; `_DefinitionRow` | **NOT TESTED** | — | ENG |
| MOM-02 | Record what actually happened | full / minimum / missed / rest / skipped, plus optional amount and note | `CommitmentDay`; `showOutcomeSheet` | **NOT TESTED** | — | ENG |
| MOM-03 | A minimum is never a full completion | Credit table: full 1.0, minimum 0.6, missed 0; full streak stops at a minimum | `test/momentum_engine_test.dart` groups "credit" and "streaks" | **NOT TESTED** | — | ENG |
| MOM-04 | Flexible schedules | Weekday selection; only selected weekdays are planned | engine + `test` "only selected weekdays are planned at all" | **NOT TESTED** | — | ENG |
| MOM-05 | Rest days and pauses | Rest/skip excluded from every figure; paused days are not planned at all | engine + tests "rest days and deliberate skips are excluded", "pausing excludes days" | **NOT TESTED** | — | ENG |
| MOM-06 | Recovery | ≥3 consecutive unlogged planned days generates a 3-step restart plan; answering today clears it | engine + tests group "recovery plans" (3 cases) | **NOT TESTED** | the trigger is arithmetic; PM should review whether 3 is the right number with real users | PM |
| MOM-07 | History survives goal/schedule changes | Schedules are versioned; a change starts a new revision today | engine `isPlanned` + test "a revision governs only the days from its own date onward" | **NOT TESTED** | — | ENG |
| MOM-08 | Every metric is explainable | The explainer sheet prints the formula, the credit table, the window and every threshold, read from the engine constants | `showMomentumExplainer`; constants in `MomentumEngine` | **NOT TESTED** | — | ENG |
| MOM-09 | Nothing is reported without a sample | Rate is `null` below 7 decided days — **including the weekly review**, which now withholds the rate and prints "n of 7 decided days so far"; weekday patterns need 3 decided days on that weekday plus 25 points above the user's own rate; improvement needs 7+7 decided days and 10 points; gate P-18 fails the build if a withheld figure is force-unwrapped | engine + `test/momentum_engine_test.dart` groups "the reporting threshold is real", "weekly review"; gate P-18 | **NOT TESTED** (engine tests) / **PASS** (gate) | thresholds are judgement calls; they are stated in the UI, not hidden | PM |
| MOM-10 | No fabricated score or recommendation | No figure is produced from an empty record; no causal language; the screen prints the sample beside every claim | `momentum_screen.dart` (`—` when there is no sample; `_NoRoutines`; `_PatternsSection` empty state) | **NOT TESTED** (UI) + **PASS** (gate P-07/P-16 clean) | copy review required on every future change | ENG |

## 5. Billing (directive phase 5)

Unchanged from the previous pass, which is why the detail lives in
`MONETIZATION.md` and `docs/SECURITY_REVIEW.md`.

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| BIL-01 | Server-side verification only | A recognised product id grants nothing; entitlement requires `verified` | `lib/config/pro_config.dart` `Entitlement.active`; `test/billing_test.dart` matrix | **PASS** for the backend / **NOT TESTED** for the client | root can still edit the cache for ≤7 days (§Security S-01/T1) | ENG |
| BIL-02 | Fail-closed default | With no backend configured, Pro cannot be granted | `main.dart` passes `null`; gate P-04 fails if `LocalOnlyVerifier` reaches `main.dart` | **PASS** (gate) | — | ENG |
| BIL-03 | Idempotency | One purchase record and one entitlement per token, verified by a repeat call | `billing_server/test/server.test.js` | **PASS** — 60/60 backend tests green here | — | OPS |
| BIL-04 | Pending / cancelled / expired / refunded / revoked | Each state handled, cancellation does not cut access short, revocation revokes immediately | `billing_server/test/{verifier,rtdn,store}.test.js` | **PASS** (backend) | RTDN delivery depends on Pub/Sub wiring in the real project | OPS |
| BIL-05 | Pending never unlocks; the paywall says so | `pending: true` grants nothing; the footer shows "Confirming your purchase" and "Check again" instead of re-selling | `paywall_screen.dart` `_Footer`; `Entitlement.active` | **NOT TESTED** | — | ENG |
| BIL-06 | Restore and manage | Both surfaces exist and call the store | `settings_screen.dart` rows; `BillingService.restore/launchManage` | **NOT TESTED** | — | ENG |
| BIL-07 | No secret in the client | Product ids, prices, copy — no key material | gate P-08/P-09/P-10 clean | **PASS** | the verification bearer token ships in the APK by design; rotate it | ENG |
| BIL-08 | Prices are real or absent | Store prices when available, ₹ fallbacks only as fallbacks | `ProConfig.plans` (`fallbackMonthly/Annual/Lifetime`) | **NOT TESTED** (needs Play) | a wrong fallback would misprice copy — the fallback is labelled in the code, not in the UI | PM |

## 6. Security and privacy (directive phase 6)

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| SEC-01 | Least privilege on Health Connect | Read-only, foreground, three data types; background read permission removed | `android_overlay/app/src/main/AndroidManifest.xml` | **PASS** (text-verified) + **BLOCKED** (device) | — | ENG |
| SEC-02 | No secrets in the tree | Credential scan clean | `collect_evidence.sh` credential scan; gate P-08/09/10 | **PASS** | — | ENG |
| SEC-03 | No encryption claim without encryption | "Encrypted at rest" is never claimed; the threat model states the opposite | `docs/PRIVACY_DATA_FLOW.md` §7; `docs/SECURITY_REVIEW.md` §3 | **PASS** (documented) | rooted-device reads remain possible | ENG |
| SEC-04 | Lock screen safe by default | Generic notification bodies; `hideDetails` true; `private` visibility | `notification_service.dart`; gate P-11 | **PASS** | — | ENG |
| SEC-05 | Cloud backup off for health data | `allowBackup="false"` | manifest | **PASS** (text-verified) | — | REL |
| SEC-06 | Real policy URLs only | Placeholder `track.app/privacy|terms` removed; release requires configured URLs | gate P-02; `AppEnvironment.validate()` | **PASS** for removal / **BLOCKED** for the URLs themselves | you must host and review the pages | LEGAL |

## 7. Android host and native (directive phase 7)

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| AND-01 | App id / namespace consistent | `com.track.app` everywhere | `grep -rn "com.track.app" android_overlay/`; overlay script checks the receiver's package | **PASS** (text-verified) | the overlay has never been applied to a generated host project | REL |
| AND-02 | SDK / toolchain coherent | compileSdk 36, minSdk 26, targetSdk 36, JVM 17, desugaring on | `android_overlay/app/build.gradle.additions` | **BLOCKED** (no Gradle) | minSdk 26 drops Android 7.x — a deliberate choice, revisit if analytics say otherwise | PM |
| AND-03 | Manifest correctness | Receivers, permissions, `<queries>`, no exact alarms, no background health read | `AndroidManifest.xml`; gate P-12 | **BLOCKED** (no aapt2 / no device) | — | ENG |
| AND-04 | R8 keeps what reflection touches | Glance, widget receiver, notifications, Billing, org.json kept | `android_overlay/app/proguard-rules.pro` | **BLOCKED** | a missing keep rule fails at runtime, on a release build only | ENG |
| AND-05 | Component lifecycle | Behaviour after process death, reboot, update, permission change | implemented in `MainActivity`/widget/notifications; **never tested on hardware** | **BLOCKED** | highest-risk unverified area | ENG |
| AND-06 | Wear OS | Separate gate — **deferred, disabled** | `android_overlay/wear/HOW_TO_ADD_WEAR.md` says "do not enable before a device pass" | **BLOCKED** | none if it stays off | PM |

## 7b. Focus Lock (this pass)

The feature was **implemented**, not documented: engine, models, platform seam,
Drift v4 tables + DAO, repository, state wiring, four screens, the native Kotlin seam,
Pro gates, tests, docs and eleven new release-gate checks. The long form — mechanism,
permanent platform limits, permission copy, Play Console declarations, rollback — is
`docs/FOCUS_LOCK.md`.

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| FOC-01 | Basic timer Focus stays free | Every mode, the timer, the picker, the summary, the reflection and the user's own history are free; Pro adds block-list scale, profiles, schedules and analysis | `lib/config/pro_config.dart` (`freeBlockedApps`, `freeFocusHistorySessions`, `isProOnly('focus.*')`); `test/focus_budget_test.dart` | **PASS** (static + test written) | the test has never executed | ENG |
| FOC-02 | Never report a block that is not happening | `verified` requires a live service, both grants and ≥1 observed foreground event; `armed` is displayed as unconfirmed; a degraded session is never a clean completion | `FocusEngine.enforcementFor/outcomeFor`; `focus_screen.dart` status block; gate P-22 | **PASS** (static + probe) | usage-event granularity can miss a brief open — documented | ENG |
| FOC-03 | Monotonic elapsed time | Countdown and totals come from `SystemClock.elapsedRealtime()`; the wall clock is display-only; no monotonic clock ⇒ `timingVerified = false` and the summary says so | `focus_platform.dart`, `FocusEngine.recover` | **BLOCKED** (no device; the Kotlin path cannot run here) | a device that refuses usage reporting falls back to `armed` | ENG |
| FOC-04 | Transactional, idempotent persistence | Row written before enforcement starts; at most one live session; two open rows are repaired on hydration; `recover()` is idempotent | `focus_repository.dart` (`start`, `_repairMultipleLiveSessions`, `recover`); `test/focus_repository_test.dart` | **BLOCKED** (drift codegen + tests cannot run) | first `flutter analyze` will be the real check | ENG |
| FOC-05 | Permission honesty | Each permission explained before use; the app only opens system settings; enabling a permission never grants Pro | `focus_setup_sheets.dart`; gate P-24 | **PASS** (static + probe) | OEM settings screens that do not exist on some builds | ENG |
| FOC-06 | No silent escalation | No Accessibility, VPN, Device Admin, device-owner, kiosk, `USE_FULL_SCREEN_INTENT` or `FLAG_SECURE` anywhere | manifest comment block; gate P-25/P-26 (probe-proven) | **PASS** (static + probe) | a future contributor must do it deliberately and visibly | ENG |
| FOC-07 | Emergency functions and essential apps never covered | Dialer/launcher/system UI/settings/keyboards/Track refused at both the engine and the platform layer | `FocusEngine.alwaysProtected` + `sanitizeBlockList`; `FocusChannel.start` + `protectedPackages()` | **PASS** (static) | a device with no resolvable default dialler falls back to the static list | REL |
| FOC-08 | Reliable exit, disclosed cancellation | The exit is present on the session screen at all times and in the panel; deep focus makes it a press-and-hold; the mode's cancellation rule is printed before the session starts | `focus_screen.dart`; `FocusEngine.cancellationCopy`; `focus_setup_sheets.dart` | **PASS** (static) | — | ENG |
| FOC-09 | Usage data never leaves the device | The detector reads package names + timestamps, keeps integer counters, writes nothing about usage to disk, and sends nothing | `FocusSessionService.kt`; `PRIVACY_DATA_FLOW.md` §Focus Lock | **PASS** (static; no upload path exists to audit) | a rooted device can read the user's own session rows | REL |
| FOC-10 | Sessions survive restarts; interrupts are recovered | Reboot, force-stop, revocation, app update and expiry each produce a specific, explained end reason; none of them is recorded as a completion | `FocusEngine.recover`/`outcomeFor`; `test/focus_recovery_test.dart` | **BLOCKED** (tests written, never executed) | the heartbeat-staleness window (12 s) is a judgement, not a measurement | ENG |
| FOC-11 | Play policy for the foreground service | `specialUse` + subtype property declared, with the Console justification drafted | `AndroidManifest.xml`; `docs/FOCUS_LOCK.md` §6 | **NOT TESTED** | Console declarations are unverifiable here; rejection is a release blocker | PM |

## 8. Notifications, lifecycle, widgets (directive phase 8)

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| NTF-01 | Permission re-grant after denial | Settings shows a route back to the OS screen; the app states it cannot prompt twice | `settings_screen.dart` "Turn notifications on" dialog | **NOT TESTED** | Android 13+ one-shot prompt behaviour needs a device | ENG |
| NTF-02 | Timezone / DST re-scheduling | `ensureTimezone()` re-schedules when the zone moved | `notification_service.dart` | **NOT TESTED** | — | ENG |
| NTF-03 | No duplicate reminders | Every `schedule*` cancels its id first; one call site (`state.syncReminders()`) | `notification_service.dart`; `main.dart` | **NOT TESTED** | boot-reschedule path is `RECEIVE_BOOT_COMPLETED` + plugin, needs hardware | ENG |
| NTF-04 | Honest scheduling | Inexact by design; copy never promises exact delivery | `exactScheduling: false`; gate P-12; settings subtitle | **PASS** (text) | on some OEMs an inexact reminder can drift; the copy says "not early, possibly late" | ENG |
| NTF-05 | Widget shows real numbers | Widget ships the real streak and commitment count; renders "no streak yet" | `widget_bridge.dart` | **NOT TESTED** | widget rendering needs a launcher | ENG |

## 9. Test suite (directive phase 9)

| ID | Requirement | Acceptance criterion | Evidence / command | Status | Residual risk | Owner |
|---|---|---|---|---|---|---|
| TST-01 | Billing backend suite green | 60/60 | `cd billing_server && npm test` | **PASS** | tests use injected Play fakes by design | OPS |
| TST-02 | Storage tests exist for repository + commitments + migration | 3 files, ≥60 cases | `test/repository_test.dart`, `test/commitment_repository_test.dart` | **NOT TESTED** | compile-time drift against the rewritten APIs is the main hazard; `tools/test_api_audit.py` checks 270 member references against `lib/` | ENG |
| TST-02b | Every member the un-compiled code references exists | All `Class.member` references in `lib/` resolve against a declaration | `python3 tools/member_audit.py --all` → 1,657 refs / 45 files / 146 types, all resolved | **PASS** (text-level; proves presence, not types) | a member can exist and still be called wrongly | ENG |
| TST-02c | Every member the un-compiled *tests* reference exists | Test references resolve against `lib/` | `python3 tools/test_api_audit.py` → 516 refs / 13 files, 7 loose | **PASS** (text-level) | — | ENG |
| TST-04c | Focus Lock's rules are tested | Engine verdicts, the recovery matrix, persistence/recovery, and the free/Pro split | `test/focus_engine_test.dart`, `test/focus_recovery_test.dart`, `test/focus_repository_test.dart`, `test/focus_budget_test.dart` (new, 4 files) | **NOT TESTED** | written but never executed — same caveat as every other Dart test here | ENG |
| TST-04d | The release gate covers the new feature's honesty invariants | 46 checks; the Focus Lock checks, the eleven integration checks and the three wipe checks are probe-proven to fire | `python3 tools/release_gate.py` (P-20…P-31 Focus Lock, P-32…P-42 integration repair, P-43…P-45 the wipe, run by tools/gate_probe.py) | **PASS** | a probe proves the check fires, not that the code is correct | ENG |
| TST-03 | Momentum rules tested as arithmetic | 30+ cases incl. credit, thresholds, streaks, pauses, recovery, patterns, day keys | `test/momentum_engine_test.dart` | **NOT TESTED** | — | ENG |
| TST-04 | Billing matrix tested | Valid/invalid/forged/expired/revoked/pending/restored/duplicated/unverifiable | `test/billing_test.dart` (739 lines) | **NOT TESTED** | — | ENG |
| TST-04b | The read layer is tested against its own hazards | Fresh install reads zero; an unknown/short series degrades instead of throwing; a write lands on today; the export merges both halves | `test/app_state_test.dart` (new, 8 cases); `test/format_test.dart` (16 cases) | **NOT TESTED** | written but never executed — the same caveat as every other Dart test here | ENG |
| TST-05 | Widget/UI tests | Not written | — | **BLOCKED** | no golden tests; visual regressions are uncaught | ENG |
| TST-06 | Device / integration pass | Not run | — | **BLOCKED** | see §7 AND-05 | REL |
| TST-07 | Release-build verification | Not run | — | **BLOCKED** | demo-data absence in a *release binary* is asserted statically, not by inspecting an artefact | REL |

## 10. Documentation (directive phase 10)

| ID | Document | Contents | Status |
|---|---|---|---|
| DOC-01 | `docs/PRODUCTION_READINESS.md` (this file) | Requirement tables, verdict, gaps | **PASS** (written) |
| DOC-02 | `docs/MOCK_DATA_AUDIT.md` | Every fabrication, evidence, disposition, residual risk | **PASS** (written, greps re-run) |
| DOC-03 | `docs/SECURITY_REVIEW.md` | Threat model, findings, limits of local storage | **PASS** (written) |
| DOC-04 | `docs/PRIVACY_DATA_FLOW.md` | Data inventory, flows, retention, Play Data-safety mapping | **PASS** (written) |
| DOC-05 | `MONETIZATION.md`, `billing_server/OPERATIONS.md` | Pricing, Play Console setup, deployment, RTDN, incidents | **PASS** (pre-existing; §9/§11 pricing still to re-check) |
| DOC-06 | `docs/TEST_RESULTS.md` | Executed vs not-executed, with the raw capture | **PASS** (this pass) |
| DOC-07 | root `README.md` §8 | What the owner must supply | **PASS** (consolidated into the single root README) |

---

## 11. Known gaps and open defects

1. **`lib/data/db/database.g.dart` does not exist.** Drift's generated code cannot
   be produced without the SDK. Nothing in this repository has been compiled, so the
   first `flutter analyze` will find real errors. Ranked by likelihood:
   the hand-written v2 DDL in the migration test; the `@DataClassName` annotations
   (added this pass precisely because the previous code assumed two different naming
   rules); any member I renamed; the v4 focus tables and every `FocusSessionsCompanion`
   call site added this pass (51 lib files / 25,492 lines now — none of it run).
2. **No client test has ever been executed** — 13 test files, 4,609 lines, zero runs.
   Two defects found this pass (`docs/MOCK_DATA_AUDIT.md` M-17, M-18) are exactly
   what the first `flutter test` run would have caught.
3. **No widget or golden tests.** Layout, contrast and text scaling are unverified.
4. ~~Commitment records are missing from the export.~~ **Closed this pass.**
   `CommitmentRepository.exportPayload()` (definitions, schedule revisions, every
   recorded day, every pause) is merged into the user's JSON export by
   `AppState.exportJson()`, and `exportCsv()` gives one row per recorded routine day;
   Settings offers "Copy routines CSV" when there are routines. Residual risk: the
   merged shape has no test yet (see `TEST_RESULTS.md` §5), and the export still
   excludes Pro/purchase metadata — deliberately: an export is user data, not billing.
5. **The design system is half applied.** The new screens use
   `lib/config/design_system.dart`; the measurement detail views, log sheets and
   paywall still read `TrackTheme`. Two palettes coexist until that migration lands.
6. **Health Connect revocation is not detected on resume** (carried over).
7. **Widgets, notifications, Wear and the Android overlay have never run on a
   device.** The highest-risk area.
8. **No crash/ANR monitoring** and no field diagnostics; a production incident would
   be discovered by reviews.
9. **The 90-day aggregate query is unmeasured.**
10. ~~`insights_screen.dart` still holds direct history indexing.~~ **Closed this
    pass.** The consistency score reached into every tracker's series at a fixed slot
    (`data[t.id]![i]`); a series shorter than the window, or absent, took the screen
    down. `activityScore` now skips a tracker it has no value for, `AppState.today`,
    `week`, `avg`, `best` and `streak` clamp instead of force-unwrapping, the write
    paths create their series rather than indexing one, and `detail_screen`'s four
    `state.history['x']!` reads go through `historyOf`. Residual risk: those paths
    have tests written but not executed (`test/app_state_test.dart`).
11. **The app could not have started at all before this pass.** `provider` was a
    declared dependency (`pubspec.yaml`), eleven screens called
    `context.watch<AppState>()`, and **nothing ever put an `AppState` into the widget
    tree** — `main.dart` built `MaterialApp(home: HomeShell())` with no provider above
    it, and no file imported `package:provider`. Found by grepping the focus work's own
    call sites. Fixed (one provider above `MaterialApp`, imports in all eleven files),
    and turned into two gate checks (P-20 presence, P-21 per-file import contract) that
    are probe-proven to fire. This is the strongest argument in the repository for
    running `flutter analyze` as the first act on a machine that can.
12. **Focus Lock's native half has never run.** Every Kotlin file in
    `android_overlay/` is a reviewed patch, not a build input: no Gradle, no
    Kotlin compiler, no device. The danger is not that it is obviously wrong — it is
    that a plausible-looking seam can fail in ways only a device shows (usage-event
    batching per OEM, background-activity-launch refusal, FGS start restrictions).
    `docs/FOCUS_LOCK.md` §3 lists the seven specific behaviours a device pass must
    confirm, and §8 the evidence table.
13. **Two fabricated values were found in the ring/delta maths and fixed**
    (`docs/MOCK_DATA_AUDIT.md` M-17, M-18): an unlogged weight day drew a completed
    ring and a 90-day streak, and the "vs week avg" line averaged in gap-filled
    zeros — and crashed outright for every non-money tracker through an
    `int.parse` over a decimal string. Both are the reason the checks in §2 exist:
    they were invisible to every text audit, and only reading the arithmetic found
    them.

## 12. Verdict and the path to a closed test

**NOT READY.** Not "conditionally ready": the definition of done for this work
requires the mandatory gates to have been executed, and five of them have not —
`analyze`, `test`, `build apk`, `build aab`, and any device pass. Everything in this
document marked PASS is a *static* result (text audits, gates, the Node suite); there
is no compiled artefact, no screenshot and no measured performance number anywhere in
this repository.

What would move it, in order, with the owner:

| # | Step | Closes | Owner |
|---|---|---|---|
| 1 | `flutter pub get && dart run build_runner build --delete-conflicting-outputs` | gap 1 | ENG |
| 2 | `dart format --output=none --set-exit-if-changed lib test` → `flutter analyze` → fix everything | gaps 1, 2 | ENG |
| 3 | `flutter test` — expect failures in the never-run files; fix the code, never the expectation | TST-02/03/04 | ENG |
| 4 | Add commitments to the export + a test for it | gap 4, DB-10 | ENG |
| 5 | `flutter build apk --release` then `--dart-define`-less install on a device: fresh-install emptiness, log/relaunch persistence, permission denial, reboot, widget | AND-05, NTF-*, TST-06/07 | REL |
| 6 | Deploy the billing service, configure Play products, run licence testing across pending → active → cancel → refund → revoke | BIL-* | OPS/PM |
| 7 | Only then: `READY FOR CONTROLLED RELEASE` (closed/internal testing), with 1–2 weeks of field data before production | all | PM |

Until step 5 completes, the honest classification is **NOT READY**. After a green
`flutter analyze` + `flutter test` on a developer machine, it becomes **READY FOR
DEVICE TESTING**; after step 6, **READY FOR CONTROLLED RELEASE**.

What the static layer now covers, so that step 1–3 are about *types* rather than
about invented names: every relative import resolves, every package import is
declared, every `AppState` member and static constant resolves, every
`Class.member` reference in `lib/` resolves (1,122 of them, `tools/member_audit.py`),
every `test/` reference resolves against `lib/` (270), and 20 release-gate checks pass
— two of which (P-18 force-unwrapped withheld figures, P-19 causal copy) were shown
to fail on a probe before being trusted.
