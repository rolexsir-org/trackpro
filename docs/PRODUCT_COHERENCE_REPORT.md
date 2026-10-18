# Track Pro — product coherence & repository pass

**Date:** 2026-10-16 · **Scope:** one product, one journey, one README, genuine data,
preserved UI, safely cleaned repository — implemented and then verified as far as this host
allows.

**Verdict: NOT YET PRODUCTION READY.** Every gate that needs a Flutter or Android toolchain
is **BLOCKED** here (`TEST_EVIDENCE.txt` names the absent tools), and the items in §7 are
unrun, not passed.

---

## 1. One product, one name

The Flutter app is the source of truth; `track.html` is the frozen visual spec and hosts the
demo data — the only place it is allowed to live.

| Decision | Detail |
|---|---|
| Product name | **Track Pro** in product-facing copy — the app bar/title, the widget header, the Wear tile, the notification channel names as the user sees them, permission explanations, the Android `app_name`, and the export's `app` field |
| Plan name | The paid tier is **Pro** everywhere a *plan* is meant (`Pro`, `Pro Lifetime`, `Pro trial`, `Pro Annual`, the Settings section, the paywall header, the "Rate Track Pro" row) |
| Identifiers untouched | Dart package `track`, application id `com.track.app`, channels `track.checkin` / `track.streak` / `track.weekly` / `track.focus.scheduled`, method channel `track/focus`, `track.export.v1`, every table/column/stored value, Kotlin constants, `widget.track.snapshot`, `custom:track:*`, the Gradle `additions` filenames |
| How it was applied | 95 prose/string occurrences across 27 files, `\bTrack\b(?! Pro)` — a rule that cannot match `TrackTheme`, `Trackers`, `Tracker` or an identifier, verified before running |
| Also corrected | `pubspec.yaml` description, the About line in Settings, `entry_repository.dart`'s export tag, `main.dart`'s `MaterialApp.title`, `strings.xml`'s `app_name`, the widget's "Open Track Pro to start logging" |
| Follow-through | The Focus preview generator holds **verbatim copies** of the app's copy and refuses to write on a mismatch — it failed on the first run and was updated to the new strings, then regenerated `docs/focus_lock_preview.html` (592 lines) from the app's own source |

The vocabulary is now fixed in the README: **tracker / entry / goal / routine (commitment) /
momentum / focus session / Pro**, with the words that are *not* used for each.

## 2. The journey, end to end

Each row was read against the code, not the docs: start, next step, completion, recovery.

| Surface | Verified behaviour |
|---|---|
| First run | Three onboarding beats, no fabricated stats; finishing lands on **Routines** when nothing is committed (the first meaningful action), Today otherwise; "Just show me the app" skips it; it never replays |
| Today | Ring tap, hero swipe, quick-add FAB and ＋ per row all write through the one `AppState` path; a refused value keeps the sheet open and says why |
| Correct / delete a day | The history list is read from **stored rows** (`recordedDays`), not the in-memory projection; deleting a day removes exactly that row; the chart, streak and Insights recompute from SQL |
| Routines | Create, edit, reorder, archive, pause/resume; a schedule edit creates a **new revision from today** so past days keep the rule that governed them |
| Momentum | Rate withheld below 7 decided days; rest and skip days excluded, never counted as failure; a gap produces a restart plan |
| Focus | Entry points on Today and inside a routine; three modes; emergency exit always live; an interrupted session is recorded as interrupted; a revoked permission degrades the session and says so (never "blocked" when nothing is blocking) |
| Insights | Thresholds stated with the day count they were computed from; below threshold the screen says so instead of drawing a curve |
| Notifications | 9pm check-in (free), streak saver, weekly review, focus reminders; taps route into the right sheet **including from a cold start** (payload parked, then drained) |
| Health | Read-only, manual always wins, revocation reads as revoked (`healthConnected`), not as "connected because the last sync worked" |
| Money | Pending grants nothing; billing unavailability is non-fatal; Restore and Manage always reachable; the entitlement copy is fail-closed |
| Leave | Export (JSON/CSV/routines/focus) to the clipboard; **delete all data** now removes what the dialog promises — see §4 |

Dead buttons, placeholder actions and stale screens were swept: no empty callbacks, no
TODO/FIXME in `lib/`, no placeholder copy, no duplicate operations (the three repeated row
titles in Settings are an `if/else` pair and a dialog title, verified by reading each site).

## 3. One README

| Before | After |
|---|---|
| Root `README.md`, `track_flutter/README.md`, `billing_server/README.md` | **One** authoritative root `README.md` |
| — | `billing_server/OPERATIONS.md` (endpoints, configuration, deploy, store, monitoring, incident response, client contract) — the unique operational content from the deleted README, kept as a distinct technical doc |
| — | `docs/PRODUCT_COHERENCE_REPORT.md` — this report |
| Two copies of `TEST_EVIDENCE.txt` (root + `docs/`) | **One** copy at the repository root, collected by `tools/collect_evidence.sh` |
| `track_flutter/README.md`'s build steps, overlay procedure, architecture notes, device checklist, Flutter-vs-Compose rationale | merged into the root README (§4, §5, §7.1) before deletion |

References were repaired where they pointed at a deleted file (`lib/main.dart`,
`MONETIZATION.md`, `docs/PRODUCTION_READINESS.md`). No new README was created.

## 4. The defect this pass fixed

**"Delete all data" did not delete all the data.** The Settings action promised "Erases every
entry on this device. Nothing is recreated." and the code removed the tracker entries, the
focus sessions and the schedules — but left every routine, every recorded routine day and
every pause behind, and left the Momentum projection drawing them. The most private thing in
the app is a routine's *name* ("Alcohol-free day"), and that survived a wipe the user had
confirmed.

| File | Change |
|---|---|
| `lib/data/db/database.dart` | `CommitmentDao.deleteAllUserData({keepDefinitions})` — one transaction, counts returned |
| `lib/data/commitment_repository.dart` | `deleteAllUserData` — clears the in-memory projection with the rows |
| `lib/state/app_state.dart` | `reset()` now returns `Map<String,int>` of what was removed, deletes routines and focus rules (`keepDefinitions: false`), and refreshes Momentum |
| `lib/screens/settings_screen.dart` | The confirmation names what goes and what stays; the success toast reports the **counts SQLite returned** |
| `test/commitment_repository_test.dart`, `test/app_state_test.dart` | Three new tests: rows+projection go together, `keepDefinitions` keeps only the routine row, a reopen after a wipe reads back empty, and `reset()` returns real counts |
| `tools/release_gate.py`, `tools/gate_probe.py` | **P-43/P-44/P-45** added, plus the P-42 description — all four verified firing |

This is the same class of bug the integration pass found: an action that reports success for
work it did not do.

## 5. Repository cleanup, safely

* **Dependencies:** `sqlite3_flutter_libs`, `path_provider` and `intl` were declared and
  imported by nothing. The first two arrive transitively through `drift_flutter` 0.3.1 (so
  the APK still bundles SQLite and the cache path); `intl` was simply unused — every date and
  number is formatted by `lib/util/format.dart`. Removed with a pubspec comment explaining
  where each now comes from. Import audit: 21 dependencies, all resolving.
* **Files:** no stray backups, `*.orig`, `*.tmp` or duplicate sources; every `lib/` file is
  referenced; every screen is reachable (149 widget classes checked for orphans — the four
  flagged are reached through their own file's helpers or `runApp`).
* **Not touched:** architecture, the DB schema and its migrations, `android_overlay/`, the
  release configuration, and every identifier Play Console or an installed APK depends on.
* **No Git history to damage:** the workspace is not a git repository, so cleanup was
  file-level and each deletion was preceded by a content check (§3).

## 6. Fake activity, kept out of production

* The app opens **empty**. 17 tracker definitions ship (configuration), with zero history.
* Empty states name the next action ("Nothing logged yet — 17 trackers ready", "Log anything
  — a glass of water counts").
* Charts, streaks, badges, tiles and the widget are all fed by SQL aggregates over the user's
  own rows; a withheld figure says so rather than guessing.
* Demo data lives only in `track.html`; "Remove sample data" still exists for an install that
  carries legacy `source: 'demo'` rows, and it removes only those.
* Greps for the removed seeder machinery run clean in every evidence collection.

## 7. Verification — exact results

| Check | Command | Result |
|---|---|---|
| Release gate | `python3 tools/release_gate.py` | **clean, 46 checks**, exit 0 (see §10: the file was missing from this checkout and was re-authored on 2026-10-17; it now runs 51 checks) |
| Gate probes | `python3 track_flutter/tools/gate_probe.py` | **14/14 fired** at the time of that table; now 52/52 (see §10) |
| Static audit | `python3 tools/static_audit.py` | clean |
| Member audit | `python3 tools/member_audit.py --all` | 1,657 references / 45 files / 146 types, all resolved |
| Import audit | `python3 tools/import_audit.py` | clean, 21 dependencies |
| Symbol clash | `python3 tools/symbol_clash_audit.py` | clean, 64 files |
| Test-side API | `python3 tools/test_api_audit.py` | clean, 516 references, 13 suites |
| Billing service | `cd billing_server && npm test` | **60/60 green**, no network |
| Evidence | `bash tools/collect_evidence.sh` | `TEST_EVIDENCE.txt` (113 lines, one copy) |
| `flutter analyze` / `flutter test` / Gradle / APK / device | — | **BLOCKED** — no Flutter, Dart, Gradle, `kotlinc`, `aapt2` or `adb` on this host |

New tests written this pass have **never executed**: `test/commitment_repository_test.dart`
and `test/app_state_test.dart` need `drift/native.dart` and the host's sqlite3. They are
counted as unrun, not as passing.

## 8. What remains blocked, and who can unblock it

| Item | Why blocked | Owner |
|---|---|---|
| `flutter analyze`, `flutter test`, build, APK | No Flutter/Android toolchain here | Anyone with an SDK: run §4 of the README |
| `database.g.dart` | Drift codegen needs the Dart SDK | Same |
| Focus blocking on a real device (interception, reboot, force-stop, battery optimisation, permission revocation) | Needs Android hardware and a version to test against | Device owner; procedure in `docs/FOCUS_LOCK.md` |
| Health Connect data, notifications at 21:00, widget render, Wear tile | Needs a device | Device owner |
| Selling anything | Play Console products, licence testers, a deployed verification service | Play Console owner; runbook in `MONETIZATION.md` |
| Policy URLs (`track.app/privacy`, `track.app/terms`) | Not provisioned — the app says so rather than linking to a 404 | Product owner |
| Encryption at rest | Not implemented, therefore not claimed; the threat model is stated | Eng, if required |

## 9. Files changed in this pass

`README.md` (rewritten as the single authoritative README) · `billing_server/OPERATIONS.md`
(new) · `billing_server/README.md`, `track_flutter/README.md` (removed, contents merged) ·
`track_flutter/pubspec.yaml` · `lib/config/{app_environment,pro_config}.dart` ·
`lib/data/db/database.dart` · `lib/data/{commitment_repository,entry_repository,focus_engine,focus_repository}.dart` ·
`lib/models/focus_models.dart` · `lib/services/{focus_platform,health_service,notification_service}.dart` ·
`lib/state/app_state.dart` · `lib/screens/{detail,focus_history,focus_profiles,focus_setup_sheets,home_shell,paywall,settings,today}_screen*.dart` ·
`lib/main.dart` · `test/{app_state,commitment_repository}_test.dart` ·
`tools/release_gate.py` · `tools/collect_evidence.sh` · `track_flutter/tools/{gate_probe,focus_preview}.py` ·
`android_overlay/` (display strings only) · docs counts and paths.


---

## 10. Second in-place pass — 2026-10-17 (this checkout, `rolexsir-org/trackpro`)

Everything above was authored in a sibling checkout (`track_flutter/`, whose files
`tools/release_gate.py` and `tools/collect_evidence.sh` did **not** reach this
repository). This pass re-authored the gate here, extended it, and fixed defects the
first pass could not have seen because they were introduced or exposed by the code that
has landed since.

### 10.1 The gate, and what probing it found

| | |
|---|---|
| `python3 tools/release_gate.py` | **clean — 51 checks, 0 problems**, exit 0 |
| `python3 tools/gate_probe.py` | **52/52 probes fired, tree restored clean**, exit 0 (14 inherited + 38 authored in this pass) |

Four bugs in the *gate itself* were found by running its probes, which is the argument
for the probes existing. All four were "the check could never fire":

1. **P-02 / P-19 matched with the strings blanked out.** `code()` removes comments *and*
   string bodies — which is right for symbol rules and fatal for rules about import paths
   and channel names, because those *are* string literals. Both now read `prose()`.
2. **`prose()` itself deleted `//` inside a literal**, so it ate the rest of any line
   containing a URL: P-04's placeholder-URL check was blind to every link in the app.
   Fixed in `tools/dart_source.py` (`strip_comments`, literal-aware), and documented there.
3. **P-20's dynamic-version pattern could not cross a Maven coordinate** (`name:1.1.+`),
   so it could only ever have matched something that is not a version string.
4. **P-22 asserted a Glance artifact layout that does not exist** (there is no separate
   `glance-state` package; `androidx.glance.state` ships in the core artifact). A check
   that cries wolf gets deleted along with the real rule, so the clause was removed rather
   than narrowed, and the package→artifact mapping it should have used is now written down
   in the check.

One check was **generalised rather than weakened**: P-51 first required the phrase
`too far apart` in the cycle summary, which would have blocked the copy fix that made the
line accurate for gaps that are too *short* as well as too long. It now asserts the
distinction (two separate `!hasPrediction` explanations) instead of a string.

### 10.2 Product defects fixed in this pass

| Area | Defect, as it behaved | Root cause |
|---|---|---|
| Day arithmetic | Streaks froze, history labels and the "N of 28 days" tile were a day off for a few hours around a DST change | Days were stepped by `Duration(days: 1)` (elapsed time) instead of by the day component; `difference().inDays` truncated a 23-hour day to 0 |
| Notifications | A weekly reminder permanently shifted by an hour after a DST transition, for every later week | `_nextInstanceOf` advanced with `add(Duration(days: 1))` on a `TZDateTime` instead of `day + 1` |
| Focus stats | A session at 00:30 six days ago was excluded from "last 7 days" | `weekFloor` derived from a fixed 144-hour subtraction |
| Hero card | Swipe-left ("one serving back") did nothing but warn | `logAdd` ran the *delta* through `ValueValidation.sanitize`, which refuses every negative; the refusal was also invisible (`onStep` returns void) |
| Hero card | After a clamped write, the event feed described a change the day's rollup did not contain | the requested delta was persisted while the clamped total was rolled up |
| Expenses | `NaN`, a negative or a 10-digit typo went straight into the rollup that every average and ring reads | `addExpense` was the one mutator with no validation, and its sheet confirmed success from its own `amount > 0` check |
| Day delete | Clearing a synced day (steps/sleep/weight) reported "nothing was stored", left the row in SQLite, and repainted the number on the next hydrate | the delete filtered on `source = 'manual'`; the cache slot was also written twice |
| Rhythm panel | Permanently showed its empty state on a screen that looked intentional | `_rhythms` was declared, documented and read but **never written**; the repository query had no caller at all |
| Reminders | Every future focus nudge lost after a reboot, update or reinstall, with no error | `main.dart` awaited `state.load()` before `notifications.init()`, and `syncReminders()` did not re-arm focus schedules |
| Billing | Two `PurchaseVerifier` declarations in one file with different signatures | a rename left a stale copy; both looked used, so nothing but reading caught it |
| Billing | An unknown product id could inherit a plan | `planForProduct` matched ids by substring; now exact id + the two documented base-plan aliases |
| Billing | `bindBilling` could subscribe twice; nothing unsubscribed | no idempotence guard, and `AppState` had no `dispose()` at all |
| Cycle widget | Predicted "period due today" from two starts 30 years apart | `hasPrediction` meant "non-empty", not "usable" |
| Charts | 59.5 minutes rendered as `0m`; a 90.6-minute goal said "1h limit"; a day with nothing logged scored as partly productive | hours and minutes rounded independently; the goal truncated; `activityScore` credited a period's weight without checking it recorded anything |
| Compile errors | Two `.firstOrNull` call sites with no `package:collection` import (and that package is only transitive here) | `analysis_options.yaml` excludes `**/*.g.dart` and no analyzer had ever run on this checkout |

### 10.3 Evidence and files this pass added

`tools/release_gate.py` (51 checks) · `tools/gate_probe.py` (probes extended to 52, and
its `GATE`/`ROOT` path assumption corrected — it looked for the gate one directory above
the repository) · `tools/dart_source.py` (`strip_comments`) ·
`test/day_key_test.dart`, `test/cycle_stats_test.dart`, `test/day_writes_test.dart`,
`test/app_environment_test.dart` (new) · `test/billing_test.dart` (three assertions
corrected against the fail-closed rule they exist to pin, plus the `ProPlan.productId`
reference that would not compile) · `ci/workflows/{ci,normalize}.yml` (the staged
workflows now run the Python gates, guard the `--dart-define` values, and check that the
manifest-instantiated classes survive R8) · `tools/run_gates.sh` (same gates, in release
order, toolchain-free ones first).

`AppEnvironment.assertNotMisconfigured()` was documented as "the CI entry point" with no
caller anywhere. It now has one (`test/app_environment_test.dart`) and a gate check (P-12)
that fails if that caller disappears, because a guard people believe is running is the
exact pattern that let this file go missing in the first place.

### 10.4 Still not executed here

No Flutter, Dart, Java or Android toolchain exists in this sandbox and the network
allowlist excludes pub.dev, dl.google.com and services.gradle.org, so `flutter pub get`,
`dart format`, `flutter analyze`, `flutter test`, `flutter build apk/appbundle` are
**NOT RUN / BLOCKED** — recorded as such in `docs/TEST_RESULTS.md` §3 and in the release
checklist. Nothing in this section should be read as a type check: the audits are
text-level, they prove presence and absence, not correctness.
