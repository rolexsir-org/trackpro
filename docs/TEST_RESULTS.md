# Test results — Track

Evidence produced by execution, not by intent. The raw capture is
`../TEST_EVIDENCE.txt`, produced by

```bash
cd /home/user && bash tools/collect_evidence.sh    # last run: 2026-10-16, 85 lines
```

Anything not in that capture or in §1 below was **not run**. Nothing in this
repository has been compiled; the host has no Flutter, Gradle or Android toolchain
(probe in the capture, first section).

---

## 1. Executed and passing (2026-10-16)

### 1.1 Billing backend — 60 tests, 0 failures

```
# tests 60   # pass 60   # fail 0   # cancelled 0   # skipped 0   # todo 0
# duration_ms 600.714818
```

Command: `cd billing_server && npm test` (Node v20.20.2, zero runtime dependencies,
no network access — Google is replaced by an injected fake in every test).

| File | Tests | What it proves |
|---|---|---|
| `test/verifier.test.js` | 15 | Product allowlist; package mismatch; `token_not_found`; pending vs active; **expired status rejected even when the state string says ACTIVE**; grace period valid; cancelled-until-expiry valid; revoked rejected; one-time purchase states 0/1/2; lifetime has no expiry; short/empty tokens never reach Google; **a Google outage surfaces as unavailability, never as a rejection**; a subscription with no expiry is refused rather than assumed |
| `test/server.test.js` | 12 | The HTTP contract end to end on a real socket: valid verdict shape, 401 without/with a wrong bearer, forged token → `200 {valid:false}` (a verdict, not an outage), outage → **503 retryable**, pending → `{pending:true}`, **idempotent by token** (one purchase record, one entitlement), **no raw token in any log line**, 400/413 bodies, burst → 429, `/healthz` leaks nothing |
| `test/rtdn.test.js` | 10 | Pub/Sub envelope decoding; renewal extends expiry; **cancellation must not cut access short**; refund/revoke drops purchase *and* install entitlement immediately; expiry revokes; account hold revokes; unknown types acknowledged; unknown tokens ignored; malformed envelope rejected; corrupt store file quarantined |
| `test/store.test.js` | 10 | Idempotent keys; survives a restart; no temp file left behind; corrupt file quarantined rather than wiped; revoking one install leaves others alone; unknown token revoke is a no-op; **a renewal without an expiry does not blank the stored one**; cross-package tokens cannot be revoked; Postgres swap DDL asserted |
| `test/security.test.js` | 13 | Constant-time bearer compare (6 negative cases); an empty configured key authenticates nothing; rate limiter burst+refill and per-client isolation; `tokenRef` stable/truncated/non-reversible; redaction at depth **including install ids and e-mail**; cyclic structures safe; one JSON line per event; **token-shaped text scrubbed from a message**; a Play error cannot retain a token through its `cause` |

Three of these tests **found real bugs**, each fixed in the same pass:

1. An oversized body killed the socket instead of returning `413`.
2. `SUBSCRIPTION_CANCELED` (which carries no new expiry) wrote `undefined` over the
   stored expiry — a cancellation cut access short, the opposite of its meaning.
3. Play API errors retained the original throwable, whose message can contain the
   request URL **including the purchase token in the path**.

### 1.2 Static audit of the Dart sources

```
static audit clean: no undeclared AppState members, no undeclared static constants, no undeclared top-level calls
```

`python3 tools/static_audit.py`. A **stand-in for `flutter analyze`, not a type
check**: it catches the failure mode of editing without a compiler — a caller
referencing a member the declaring class does not define. It caught
`AppEnvironment.verifyTimeout` and later `ProConfig.freePlanLabel`.

### 1.3 Import and dependency resolution

```
imports clean: every relative import resolves, every package import is declared (21 deps)
```

`python3 tools/import_audit.py`. This is the check that found `detail_screen.dart`
importing the deleted `demo_data.dart`.

### 1.4 Member audit (new this pass)

```
member audit: 1122 qualified references checked across 36 files, 112 types declared in lib/
  all resolved (text-level: proves presence, not correctness of types)
```

`python3 tools/member_audit.py --all`. The screens, engine and repository written
during the Momentum work were never compiled, so every `Class.member` reference in
`lib/` is now checked against the members their declaring classes actually define.
This closes the largest blind spot in the previous pass: `Editorial.inkSecondary`,
`MomentumEngine.minDecidedDaysForRate`, `CommitmentTemplates.all()`,
`DayOutcomeText.verb`, `PaywallTrigger.commitmentLimit`, `showTrackContextMenu` and
`TrackDatabase.forTesting` are present, not invented.

It proves **presence only** — not types, not argument lists, not overrides. Its
false-positive modes were worked out and removed rather than white-listed: private
constructors (`Editorial._`), named constructors (`TrackDatabase.forTesting`) and
enum values are now collected properly.

### 1.5 Release gate

*(The count below is the gate as it stands after this pass: 20 checks were the number
when this section was first written, then Focus Lock added P-22…P-31 and the integration
repair added P-32…P-42 — see §6 and §7.)*

```
release gate: clean (46 checks across the Dart, Kotlin, Gradle, manifest and documentation surfaces)
release gate exit code: 0
```

`python3 tools/release_gate.py`. It fails non-zero on: the removed demo-seeding APIs
reappearing, a seeder wired into the production start-up path, placeholder
`track.app/*` URLs in `lib/`, a recognised product id treated as an entitlement,
`LocalOnlyVerifier` reachable from `main.dart`, cleartext HTTP, debug bypasses around
a security decision, fabricated metrics, secret-shaped literals, private key
material, a service-account JSON in the tree, lock-screen detail on by default,
exact alarms requested, placeholder copy, unhandled TODO/FIXME, fabricated history
or streak claims, a hardcoded "since" date in shipped copy, **a withheld momentum
figure force-unwrapped** (P-18) and **causal or psychologising copy** (P-19).

Two things changed in the check machinery this pass, both to keep it trustworthy:

* **P-18 and P-19 can be seen to fail.** A temporary probe
  (`lib/_gate_probe.dart`, since deleted) produced exactly:

  ```
  [CRITICAL] P-18 .../_gate_probe.dart:5   double force() => rate!.roundToDouble();
  [CRITICAL] P-18 .../_gate_probe.dart:6   Map<String, double> payload() => {'rate': rate!};
  [HIGH]     P-19 .../_gate_probe.dart:4   String copy() => 'because you skipped yesterday';
  ```

* **Acceptance is windowed.** A guard is usually one line above the use it protects
  (`if (x == null) ... else Text('${x!}')`), so the acceptance test looks at the
  three-line window, not the bare line. Before that, P-18 fired on six *correct*
  guarded call sites — and a check that cries wolf gets switched off. Two of the six
  were instead genuinely improved: `momentum_screen.dart` now binds the value
  (`if (o.rate case final rate)`) instead of asserting it, because a guard 18 lines
  above a `!` is a guard waiting to drift.

### 1.6 Production hygiene greps

```
clean        DemoData\.        seedDemoIfEmpty    wipeAndReseed    DemoFixtures
clean        track\.app/(privacy|terms)   LocalOnlyVerifier\(   http://
clean        TODO: / FIXME:   AIza   BEGIN PRIVATE KEY   service_account
clean        \.widget\.TrackWidgetReceiver
comments     1,284  (3 explanatory mentions, no code)
comments     subscriptionsv2 (2 explanatory mentions, no code)
```

### 1.7 Android overlay apply script (against a simulated host)

Run against a fabricated `android/` tree to prove the copy step, the
widget-receiver name check and the failure path:

```
ok    MainActivity.kt        ok    TrackWidget.kt        ok    WearSync.kt
ok    TrackWidgetReceiver declared in package com.track.app
NOTE  manifest does not reference com.track.app.TrackWidgetReceiver yet (expected before the merge step)
```

With no `android/` directory it exits 1 with the exact `flutter create` command to
run first. This is *not* a build: nothing was compiled.

### 1.8 Source size

```
lib:  51 files, 25436 lines
test: 13 files,  4519 lines
```

(The Focus Lock pass added 8 lib files and 4 test files. The figures above are
`find`/`cat | wc -l` on the working tree at 2026-10-16, not estimates.)

---

## 2. Changes this pass a reviewer should look at directly

1. **The weekly rate now obeys the sample rule** (`lib/data/momentum.dart`).
   `WeeklyReview.rate` was `decided == 0 ? null : credit/decided*100`, so a week with
   two decided days printed a percentage — against the product rule that no rate is
   shown below seven decided days. It is now
   `decided < minDecidedDaysForRate ? null : …`, the same threshold the rolling rate
   and the per-commitment snapshot use; `_WeeklyReviewCard` prints
   "n of 7 decided days so far" instead of a score.

   The test file was changed too, and the distinction matters: one assertion encoded
   the *old* behaviour (`expect(review.rate, closeTo(100, .001))` for a five-decided
   day week), while a sibling assertion already demanded the invariant
   (`expect(review.rate, isNull, reason: 'two decided days cannot produce a rate')`).
   The engine was fixed to satisfy the invariant and the test was rewritten — now two
   tests, one at five decided days asserting the rate is withheld, one at exactly
   seven asserting 88.57 % from 5 full + 2 minimum days (the credit table made
   arithmetic). No expectation was relaxed; the old one contradicted the product rule.

2. **The comment/string stripper used by every audit was wrong**
   (`track_flutter/tools/dart_source.py`). A regex cannot tell that the quote inside
   `${...}` is not the end of the literal, so a line such as
   `throw StateError('misconfigured:\n - ${items.join('\n - ')}')` leaked its tail
   into the "code" stream and unbalanced the braces — which is how a text audit starts
   reporting invented problems. The stripper is now a small scanner that understands
   nesting and keeps interpolated expressions (they are code) while blanking their own
   literals. `static_audit.py` and `test_api_audit.py` import it; both still report
   clean, and the brace-imbalance warning that prompted the work is gone.

3. **Two fabricated values were removed from the ring and delta maths**
   (`lib/util/format.dart`, M-17/M-18 in `docs/MOCK_DATA_AUDIT.md`).

   * `ringPct` scored weight as distance-from-goal, so the gap-filled zero of an
     unlogged day evaluated to **1.0**: a brand-new install drew a *completed*
     weight ring and — because `streakOf` walks back while the ring is ≥ 70 % — a
     **90-day streak**, printed as "90 days" on the weight detail screen. A value of
     zero now means "nothing logged" on every tracker.
   * `deltaOf` averaged in every gap-filled zero, so the first weight entry ever
     logged read **"72.5 kg vs last week"** against a week of nothing. The average is
     now taken over logged days, with an explicit `zeroIsAValue` list for the
     trackers where a logged zero is a real answer (money, screen time, habits,
     period); a first entry reads "First entry — nothing to compare yet".

4. **`deltaOf` crashed on every tracker except money and minutes.** The label was
   built as `_group(int.parse(abs))` where `abs` was `diff.abs().toStringAsFixed(1)`
   — `int.parse("500.0")` throws `FormatException`. Since `deltaOf` is called by the
   tracker card, the water, steps, sleep, calories and weight paths threw before they
   could draw. It now groups a `double` (`_magnitude`: grouped whole numbers above
   100, one decimal below). This is the kind of defect no text audit can see and
   that only an executed test, an analyzer or a device would have caught — a
   concrete argument for step 2 and 3 of the release path.

---

## 3. Written but NOT EXECUTED (no Flutter SDK on this host)

Real test files with real assertions — **the eight suites below, then four Focus Lock
suites (§6), one integration-repair suite (§7) and the wipe tests of the cohesion pass: 13 files,
4,609 lines in total, none of
them ever executed.** Treat them as unverified until `flutter test` passes on a developer
machine. Two of the defects above were exactly what these tests would have caught on their
first run.

| File | Lines | Covers |
|---|---|---|
| `test/repository_test.dart` | 300 | Fresh install has definitions and **no fabricated rows**; bootstrap idempotent, never seeds over real data; writes stored once; validation refuses impossible values; **source precedence manual > health > demo**; re-run does not double-count; delete removes without resurrecting; integrity check; day keys are local calendar keys through a DST night |
| `test/demo_policy_test.dart` | 150 | The four clauses of the demo-data policy, including "production defaults contain no invented statistics" |
| `test/billing_test.dart` | 690 | Fail-closed entitlement (unverified / stale / no-expiry / recognised-id all inactive); provisional claims grant nothing; verdict matrix; **the HTTP verifier against a real loopback `HttpServer`** for valid, pending, rejected, 503, 429, 401, malformed JSON, timeout, unconfigured build, and that the token never appears in the request line or headers |
| `test/momentum_engine_test.dart` | ~470 | Credit table; rest/skip excluded from both sides; planned/decided arithmetic including silent past days; today never judged; the seven-decided-day reporting threshold; full vs keep-going streaks; pauses; the ≥3-day restart trigger and the "today already answered" guard; revision-boundary history; weekday patterns and improvement thresholds; weekly review incl. the sample rule above; day-key arithmetic over 400 consecutive days |
| `test/commitment_repository_test.dart` | ~430 | Create/record/replace/reload/clear; schedule revisions; archive and cascade delete; pauses; `importLegacyHabits` (imports, idempotent, non-destructive, corrupt blob safe, marker written); **v2 → v3 migration** on a hand-written v2 database: old rows survive, the three Momentum tables appear |
| `test/format_test.dart` | ~130 | Formatting helpers; **rings and deltas**: an unlogged day cannot complete a ring or supply a streak; unlogged days are left out of the average while a logged zero stays in it; a first entry is not compared against gap-filled zeros |
| `test/app_state_test.dart` | ~140 | **New.** The read layer through a real `AppState`: a fresh install reads zero everywhere (no since-date, no streak); an unknown or short series degrades to zero/empty instead of throwing; a write lands on today and an unknown id is refused by validation; the JSON export merges the commitments section and the routine CSV has a header even when empty |
| `test/fixtures/demo_fixtures.dart` | — | Fixtures, importable only from `test/` |

Risks a run can resolve, in order of likelihood:

1. **Signature drift** against the rewritten repositories (`test_api_audit.py` checks
   270 member references, which catches names but not types).
2. **`database.g.dart` does not exist** — Drift codegen needs
   `dart run build_runner build --delete-conflicting-outputs` on a machine with the
   SDK before any of these can compile.
3. `track_flutter` needs `libsqlite3` present on Linux for `drift/native.dart`
   (`apt-get install libsqlite3-0`).

---

## 4. BLOCKED gates (probe included)

| Gate | Probe | Status |
|---|---|---|
| `flutter --version` | `flutter: ABSENT` | BLOCKED |
| `flutter pub get` | no SDK | BLOCKED |
| `dart run build_runner build --delete-conflicting-outputs` | no SDK; **`lib/data/db/database.g.dart` missing** | BLOCKED |
| `dart format --output=none --set-exit-if-changed lib test` | no SDK | BLOCKED |
| `flutter analyze` | no SDK | BLOCKED |
| `flutter test` | no SDK | BLOCKED |
| `flutter build apk --release` | no SDK | BLOCKED |
| `flutter build appbundle --release` | no SDK | BLOCKED |
| Device smoke test | `adb: ABSENT` | BLOCKED |
| Play Billing end to end | no Play Console access | BLOCKED |
| Health Connect on hardware | no device | BLOCKED |
| Notification delivery on hardware | no device | BLOCKED |
| Widget on a real launcher | no device | BLOCKED |
| Wear OS | no device, no watch | BLOCKED |

---

## 5. What the evidence does *not* prove

- **Nothing about the Dart code's ability to compile.** The audits check names,
  members and imports — not types. A first `flutter analyze` with the SDK present
  should be expected to surface errors, and none should be dismissed without a fix.
- **Nothing about rendering.** No screenshot, no golden test, no device frame.
- **Nothing about performance.** No benchmark was run; the "bounded memory" claim in
  `PRODUCTION_READINESS.md` is a design claim, not a measurement.
- **Nothing about the Play integration.** Whether Play returns what the backend
  expects for a licence tester is unverified until `MONETIZATION.md` §6 is executed
  against a real console.
- **Nothing about Focus Lock on a device.** The feature now exists end to end in the
  source (engine, repository, Drift v4 tables, state wiring, four screens, the Kotlin
  seam) and it has four test files and eleven new gate checks — none of which executes
  the part that matters. `queryEvents` batching, background-activity-launch refusal,
  FGS start restrictions, OEM battery behaviour and the panel itself are all unproven
  until `docs/FOCUS_LOCK.md` §8's device pass runs. The static truth is narrower and
  worth stating plainly: no code path in the app can render "blocking" without a
  platform report behind it (`FocusEngine.enforcementFor` requires `detectionEvents > 0`,
  a live service and both grants).
- **Nothing about the export round trip.** `CommitmentRepository.exportPayload()`
  and `exportCsv()` are new and unchecked beyond the text audits; the export is
  composed in `AppState.exportJson()` (`{'commitments': …}`), and no test asserts the
  merged shape yet.


---

## 6. This pass: Focus Lock

*Written 2026-10-16, in the same host-probe conditions as §4 — no Flutter, Dart,
Gradle, Kotlin, aapt2 or adb. Nothing below was executed.*

| Artefact | Lines | Status |
|---|---|---|
| `lib/models/focus_models.dart` | 595 | written, text-audited |
| `lib/data/focus_engine.dart` | 694 | written, text-audited |
| `lib/services/focus_platform.dart` | 397 | written, text-audited |
| `lib/data/focus_repository.dart` | 841 | written, text-audited |
| `lib/data/db/database.dart` (v4: 3 tables + `FocusDao`) | +~430 | written, text-audited |
| `lib/screens/focus_screen.dart` | 721 | written, text-audited |
| `lib/screens/focus_setup_sheets.dart` | 1,053 | written, text-audited |
| `lib/screens/focus_history_screen.dart` | 327 | written, text-audited |
| `lib/screens/focus_profiles_screen.dart` | 730 | written, text-audited |
| `android_overlay/…/FocusChannel.kt` | 363 | written, text-audited (Kotlin is not audited by any tool here) |
| `android_overlay/…/FocusSessionService.kt` | 342 | written, text-audited |
| `android_overlay/…/FocusBlockOverlay.kt` | 229 | written, text-audited |
| `android_overlay/…/FocusStore.kt` | 176 | written, text-audited |
| `test/focus_engine_test.dart` | 504 | **written, NEVER EXECUTED** |
| `test/focus_recovery_test.dart` | 277 | **written, NEVER EXECUTED** |
| `test/focus_repository_test.dart` | 521 | **written, NEVER EXECUTED** |
| `test/focus_budget_test.dart` | 237 | **written, NEVER EXECUTED** |
| `docs/FOCUS_LOCK.md` | ~260 | written |

**Also fixed this pass, outside the feature:** the app had no `Provider` anywhere in
its widget tree while eleven screens consumed `AppState` through `context.watch`. That
is a compile-and-run blocker, it was invisible to every text audit the repository had,
and it is now covered by two gate checks (P-20, P-21) that are probe-proven to fire.

**Deliberately not done:** no claim that any Kotlin file compiles, that the manifest
merges, that the service starts, that usage events arrive, or that a panel appears.
Those sentences require a device, and the repository does not contain them.

---

## 7. This pass: Track Pro integration repair

*Same host-probe conditions as §4 and §6 — no Flutter, Dart, Gradle, Kotlin, aapt2 or
adb. Nothing in this section was executed.*

The pass started as a read of the whole repository against the brief (workflow and
sequence, demo data, one source of truth, UI/UX polish, security/privacy, tests) and
ended with fixes in the code — full defect list, evidence per item and the claims that
turned out to be wrong: **`docs/INTEGRATION_AUDIT.md`**.

### 7.1 Fixed in code

| # | Defect | Where it was | What changed |
|---|---|---|---|
| A-1 | `_persist` swallowed every write failure | `state/app_state.dart` | returns whether the write landed; failure recorded on `writeFailure`; projection re-derived from the store; labels name the action |
| A-2 | no surface for a failed write | `screens/home_shell.dart` | dismissible banner + a "Last save problem" row in Diagnostics |
| B-1 | four `history[id]!` force-unwraps | `detail`, `trackers`, `today` screens | all read through `historyOf`; three unguarded `values.last` guarded too |
| C-1 | history rendered gap-filled zeros as entries | `screens/detail_screen.dart` | `_HistorySection` reads stored rows (`recordedDays`) and shows provenance |
| C-2 | a recorded day could not be edited or deleted | `data/entry_repository.dart`, `state/app_state.dart`, `screens/log_sheets.dart` | transactional `setDayValue`/`clearDay`, an edit sheet with a confirmation, three honest result codes |
| D-1 | "Goal settings" opened Insights | `screens/trackers_screen.dart` | opens a real goals sheet |
| D-2 | "Manage trackers" opened Momentum | `screens/settings_screen.dart` | pushes the trackers page |
| D-4 | health result codes collapsed into "permission denied" | `settings_screen.dart`, `today_screen.dart` | per-code copy (−2 Pro, −1 refused, 0 split three ways, >0 merged days) |
| E-1 | reordering silently un-hid a tracker | `state/app_state.dart` | `move`/`pinToTop` reorder only |
| E-2 | three words for `hidden`, and a menu that lied | `trackers_screen.dart`, `today_screen.dart` | one word; every message reports the resulting state |
| E-3 | calories total passed to a delta API | `screens/log_sheets.dart` | writes the day's total (`log`), labelled "Save total" |
| E-4 | sheets could be submitted twice | `widgets/glass.dart`, `screens/log_sheets.dart` | `SubmitOnce` latches on success; write → pop → toast; `_Btn` dims when inert |
| E-5 | the period sheet wrote nothing | `screens/log_sheets.dart`, `state/app_state.dart` | `_PeriodDraft` + `logPeriod` stores flow and symptoms in the row's meta |
| F-1 | health connection state reset every launch | `services/health_service.dart`, `state/app_state.dart` | `HealthPermissionState` probed on load, persisted, re-asked; Settings reports it |
| G-1 | two headers on the Measurements page | `screens/measurements_page.dart`, `screens/trackers_screen.dart` | one header, back button leading |
| H-1 | **`dayKey` declared twice — a compile error in three files** | `data/db/database.dart`, `util/day_key.dart` | one declaration, re-exported |
| H-2 | the gate's `//` acceptance rule had disabled three checks | `tools/release_gate.py` | bare `//` is evaluated against the current line only |

### 7.2 Added test coverage

| File | Lines | Covers |
|---|---|---|
| `test/day_edit_test.dart` | ~330 | history read from rows (not the gap-filled projection); a never-logged day is absent while a logged zero is a row; write/edit/delete one day; delete removes events too (nothing left for the export to disagree with); reordering never changes what is hidden (cache **and** row); a failed write is refused, named and rolled back — with the failure produced by `PRAGMA query_only`, i.e. by SQLite rather than a mock; the period sheet's flow and symptoms reach the row; an absolute log is idempotent while a delta adds once; the added list survives a restart |

### 7.3 Added checks

`tools/release_gate.py`: **P-32** force-unwrapped projection reads, **P-33** unguarded
series reads, **P-34/P-35** control-dispatch to an unrelated tab, **P-36** a sheet closed
before it writes (window check), **P-37** the failed-write surface, **P-38** the
double-submit guard, **P-39/P-40** the day edit/delete paths, **P-41** history read from
stored rows, **P-42** ambiguous top-level names.

`tools/symbol_clash_audit.py`: new — a duplicate top-level declaration is a Dart compile
error and nothing else here could see one.

`tools/gate_probe.py`: new — makes each of those defects real, asserts the gate fires,
reverts, and re-runs the gate clean. The first run found three checks that had been
passing for the wrong reason (H-2).

### 7.4 Still not proven

`flutter analyze`, `flutter test`, `dart format`, Drift codegen, the Android build and
every device behaviour: **BLOCKED** on this host (§4). The new suite is unrun, so its
existence is not evidence that the fixed behaviour is correct — only that the intended
behaviour is written down and executable on a machine that has the SDK.
