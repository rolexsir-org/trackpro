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
| Release gate | `python3 tools/release_gate.py` | **clean, 46 checks**, exit 0 |
| Gate probes | `python3 track_flutter/tools/gate_probe.py` | **14/14 fired**, tree clean afterwards |
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
