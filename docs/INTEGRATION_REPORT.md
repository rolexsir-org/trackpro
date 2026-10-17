# Track Pro integration — final report

**Date:** 2026-10-16 · **Scope:** Track Pro integration repair, run against the standing
master prompt (production hardening, complete repair, release validation) and the twelve
criteria below.
**Status of every item:** PASS / FAIL / BLOCKED, with the command that shows it.

Nothing here is inferred from a document: each item carries the artefact that proves it,
and items that could not be proven on this host say so and name what would prove them.
The defect-by-defect list lives in `docs/INTEGRATION_AUDIT.md`; the raw tool output lives
in `/home/user/TEST_EVIDENCE.txt` (one authoritative copy; the `docs/` mirror was removed
in the cohesion pass).

---

## 1. Workflow and sequence — the request lifecycle is repaired · **PASS (code) / BLOCKED (run)**

**Acceptance.** A user action either reaches the database or is reported as not having
reached it. No screen may confirm a write that did not land, and no screen may show a
value the store does not hold.

**What was wrong.** Every mutation painted the model, notified, and then fired
`unawaited(_persist(...))` whose error handling was `catch (_) {}`. The UI confirmed
what SQLite did not receive; the value looked right until the next launch and then
reverted silently. Sheet actions popped the route *before* writing, so a second tap
during the dismiss animation wrote twice.

**What changed.**
* `_persist` returns whether the write landed, records `AppState.writeFailure`
  (`SaveFailure`: action, reason, time) and re-derives the projection from the store
  (`_rollbackProjection`) so the screens agree with the database again.
* `HomeShell` shows a dismissible banner naming the action; Diagnostics keeps a "Last
  save problem" row.
* `SubmitOnce` (`widgets/glass.dart`) sets its guard synchronously, latches on success,
  re-arms on failure; `_Btn` dims when inert. Every logging sheet follows one shape:
  **write → pop → toast** — and a refused value keeps the sheet open and says nothing was
  saved.

**Evidence.** `tools/release_gate.py` → P-37, P-38 (probe-proven by
`tools/gate_probe.py`); `test/day_edit_test.dart` → three failed-write cases, the failure
produced by SQLite (`PRAGMA query_only`), not by a mock.
**Residual risk.** None in the code path; the run is BLOCKED (no SDK) — see item 8.
**Owner:** ENG.

---

## 2. Demo data and fabricated content · **PASS**

**Acceptance.** No sample history in a shipped build, and no screen states something the
user's data does not support.

**Evidence.**
* `lib/` contains no seeder, no `DemoData`/`DemoFixtures`, no `TRACK_DEMO_SEED`; the
  production start-up path takes no seeder parameter. Gate P-01/P-01b/P-15, plus the
  hygiene greps in `TEST_EVIDENCE.txt` (`clean DemoData\.`, `clean seedDemoIfEmpty`, …).
* This pass removed the last three ways a screen could describe data that was not there:
  the history list no longer renders unlogged days as `0` (C-1), the period sheet no
  longer confirms a save it never made (E-5), and the health row no longer reports a
  connection it does not have (F-1).
* Deliberate zeros stay visible: a logged `0` is a reading for screen time, spending,
  habits and the cycle, and hiding it would be its own kind of lie.

**Residual risk.** `test/fixtures/demo_fixtures.dart` still exists as test-only fixtures —
importable from `test/` only, and asserted so. **Owner:** ENG.

---

## 3. One source of truth · **PASS**

**Acceptance.** One declaration per concept; the UI reads the store rather than a parallel
copy; no duplicate definitions.

**What was wrong — and it was a compile error.** `dayKey` was declared in **both**
`data/db/database.dart` and `util/day_key.dart`, and three files import both and use it.
Dart rejects that outright; the app could not have been built. No audit here could see it,
because a duplicate definition looks exactly like a definition.

**What changed.**
* One declaration, in `util/day_key.dart`; `database.dart` imports and re-exports
  `show dayKey`, so existing importers resolve to the same declaration.
* `todayKey`/`previousDayKey`/`shortDayKey` and friends all come from that one file.
* The day-level write path is one path: `EntryRepository.setDayValue`/`clearDay` are the
  only writers for a specific day, used by the new sheet, and the projection slot is
  patched by the repository rather than by each screen.
* History is read from rows (`recordedDays`), not from the gap-filled projection.

**Evidence.** `tools/symbol_clash_audit.py` → clean, 64 files; gate **P-42** runs it and
is probe-proven (a duplicate is re-introduced and reverted by `gate_probe.py`);
`tools/static_audit.py`, `import_audit.py`, `member_audit.py` → clean
(1,657 refs / 45 files / 146 types).
**Residual risk.** The audit covers `lib/` and `test/`; a clash introduced only in
`android_overlay/` would be caught by Kotlin, not here. **Owner:** ENG.

---

## 4. UI/UX polish without a redesign · **PASS (code) / BLOCKED (visual)**

**Acceptance.** Every control goes where its label says; one affordance per mode; no
copy that overstates; the established visual system untouched.

**What changed.**
* "Goal settings" now opens the goals sheet (it opened **Insights**); "Manage trackers"
  pushes the trackers page (it opened **Momentum**).
* The duplicate reorder control is gone (the header's `Edit` remains); the row now carries
  an inline hint instead.
* One word for one state — **hidden** — with messages that follow the resulting state, and
  a long-press item that reads "Show on dashboard" when the tracker is hidden.
* History rows show an entry's provenance ("You", "Health Connect", "Widget", "Imported")
  instead of the tracker's blurb, and a tap opens the day sheet.
* Measurements shows one header and one back control instead of two stacked bars.
* Calories' primary action is labelled "Save total", which is what it does.
* `Editorial`/`TrackTheme` tokens, spacing, type scale, motion and the five-section IA are
  unchanged; no screen was rebuilt.

**Evidence.** Gate P-34/P-35 (probe-proven) forbid the two wrong dispatches; gate P-33
guards the series reads; `docs/INTEGRATION_AUDIT.md` §D/§E/§G name file and symbol per
change.
**Residual risk / not tested.** Nothing visual was rendered (no SDK, no device): the
changes are text-verified only. `docs/focus_lock_preview.html` remains the *only* visual
artefact of this project and it states on its face that it is generated from source, not
a screenshot. **Owner:** ENG + design review on a device.

---

## 5. Security and privacy · **PASS for what is implemented; one gate BLOCKED**

**Acceptance.** No fabricated security claims, no new permissions, no data leaving the
device by default, and permissions/disclosures that match the mechanism.

**Evidence.**
* No new permission was added by this pass. The manifest keeps its previous decisions:
  usage access + user-granted overlay + `specialUse` foreground service for Focus Lock,
  no AccessibilityService, no VPN, no Device-Admin, no kiosk, no exact alarms, no
  Internet permission. Gate P-25 (forbidden permissions), P-26 (`FLAG_SECURE`), P-27
  (usage-data field names written into a row) all clean and probe-proven.
* The health permission state is now read from the OS (`HealthPermissionState`) instead of
  remembered, so the app cannot describe a revoked permission as connected (F-1).
* No credential findings: the secret scan in `TEST_EVIDENCE.txt` reports none; gate
  P-08/P-09/P-10 clean.
* Privacy posture is unchanged and still true: local-only storage, export as a query,
  analytics events carry no tracker content, focus/usage data never leaves the device.
* The audit corrected one over-claim of its own rather than the code (D-4's phantom `-3`).

**BLOCKED.** Play Console declarations (FGS `specialUse` subtype, usage-access
justification) and any device-level verification of blocking behaviour: no console, no
device. **Owner:** RELEASE + ENG on hardware.

---

## 6. Tests · **PASS (written) / BLOCKED (executed)**

**Acceptance.** Every fixed defect has a test that fails if the defect returns; no test may
be changed to make it pass.

**What changed.**
* New suite `test/day_edit_test.dart` (334 lines): rows-not-gaps history; never-logged day
  absent vs logged zero present; write/edit/delete one day; delete removes events too;
  reordering never changes what is hidden (cache **and** database row); a failed write is
  refused, named and rolled back; period flow/symptoms land in the row; absolute log is
  idempotent while a delta adds once; the added list survives a restart.
* Corrected one test that **could not fail**
  (`test/app_state_test.dart`: both branches of a conditional were the same literal). It
  now asserts the real invariant (`series(id, 10000).length ≤ EntryRepository.cacheDays`).
* Totals: 13 test files, 4,609 lines; `test_api_audit.py` resolves 516 member references
  across 13 files (7 under the documented loose rule).

**BLOCKED.** `flutter test` cannot run here — no Flutter/Dart SDK — so no suite in this
repository has ever executed. The new suite is written and unrun, and is reported that way
everywhere. **Owner:** ENG, first task on a machine with the SDK:
`flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter test`.

---

## 7. Checks and gates · **PASS**

**Acceptance.** The lessons behind each fix are enforced by a check that can be seen to
fail.

| Check | What it forbids | Proven |
|---|---|---|
| P-32 | a force-unwrapped projection read (`history[...]!`) | probe fires |
| P-33 | an unguarded series read in the tracker cards/rows | probe fires |
| P-34, P-35 | a control dispatching to an unrelated tab | probes fire |
| P-36 | a sheet closed before its write (window check) | probe fires |
| P-37 | the failed-write surface missing (app_state **and** home_shell) | probe fires |
| P-38 | the double-submit guard missing | probe fires |
| P-39, P-40 | the day edit / delete paths missing | probes fire |
| P-41 | history read from the projection instead of rows | probe fires |
| P-42 | an ambiguous top-level name (a Dart compile error) | probe fires |

**Also fixed in the check machinery itself:** the gate's `accept_if` treated a bare `//`
as "documented here" against a three-line window, which had silently disabled three of the
new checks (H-2). A bare `//` is now evaluated against the current line only.

**Evidence.** `python3 tools/release_gate.py` → *clean, 46 checks, exit 0*;
`python3 track_flutter/tools/gate_probe.py` → *every probed check fired, and the tree is
clean again* (both in `TEST_EVIDENCE.txt`). **Owner:** ENG.

---

## 8. Evidence pack and reproducibility · **PASS**

**Acceptance.** A reviewer can reproduce every claim with one command and see exactly what
this host can and cannot run.

* `/home/user/TEST_EVIDENCE.txt` — 113 lines, timestamped, one copy (the `docs/` mirror was
  removed in the cohesion pass so there is a single authoritative file), regenerated by
  `(cd track_flutter && bash ../tools/collect_evidence.sh)`.
* It opens with the host probes (`flutter`/`dart`/`gradle`/`kotlinc`/`aapt2`/`adb` ABSENT)
  and the BLOCKED list, then every available check in order: billing backend 60/60, static
  audit, imports, member audit, release gate + exit code, symbol-clash audit, test-API
  audit, gate probe, hygiene greps, secret scan, source size, tracker definitions.
* Counts in the docs were re-aligned to the measured ones this pass
  (`PRODUCTION_READINESS.md`, `TEST_RESULTS.md`, `FOCUS_LOCK.md`).

**Residual risk.** Evidence is text-level; it proves presence and absence, never runtime
behaviour. **Owner:** ENG.

---

## 9. Files changed this pass · **PASS**

`lib/state/app_state.dart` (1,861), `lib/models/models.dart` (555),
`lib/services/health_service.dart` (182), `lib/data/entry_repository.dart` (619),
`lib/data/db/database.dart` (1,131), `lib/screens/detail_screen.dart` (1,073),
`lib/screens/log_sheets.dart` (1,159), `lib/screens/settings_screen.dart` (1,233),
`lib/screens/trackers_screen.dart` (331), `lib/screens/today_screen.dart` (630),
`lib/screens/home_shell.dart` (514), `lib/screens/measurements_page.dart` (30, rewritten),
`lib/widgets/glass.dart` (649).

New: `test/day_edit_test.dart`, `tools/symbol_clash_audit.py`, `tools/gate_probe.py`.
Tools: `/home/user/tools/release_gate.py` (403), `/home/user/tools/collect_evidence.sh`
(+2 sections). Docs: `INTEGRATION_AUDIT.md` (426, rewritten), `TEST_RESULTS.md` (§1.5, §3,
§7), `PRODUCTION_READINESS.md` (counts, TST rows), `FOCUS_LOCK.md` (gate count).

Totals: `lib` 51 files / 25,492 lines · `test` 13 files / 4,609 lines (the cohesion pass
added the wipe tests and the `reset()` rewrite).

---

## 10. Defects found but **not** fixed · **PASS (disclosed)**

Disclosed rather than quietly dropped, with the reason each was left:

1. **No `AppLifecycleState` observer for the health permission.** A revocation while the
   app is backgrounded is noticed on the next launch or sync attempt, not instantly.
   *Why not fixed:* it is platform behaviour that cannot be verified here, and guessing at
   it would trade a known limitation for an unverified claim (F-1).
2. **Free-tier history list has no per-row lock marker.** It is bounded by the query
   (7 rows for free) with the Pro row beneath, unlike the charts which draw lock markers.
   *Why not fixed:* it is a design decision about a Pro surface, and the audit's job was to
   stop the list from lying, not to redesign gating.
3. **Deleting a day removes a health-sourced value too.** The next health sync can restore
   it. Disclosed in the confirmation copy, but it is a genuine asymmetry (J-4).
4. **`recordedDays` returns rows, not a dense series.** Correct for the history list; a
   caller wanting a dense series must gap-fill deliberately. Only one call site today.
5. **Kotlin/Android code remains uncompiled and unrun**, exactly as before this pass.
6. **Two audit claims from the first draft were wrong and are corrected, not implemented
   around:** D-3 (the add/remove toast was never stale — `toggleAdded` mutates
   synchronously) and E-4's claim that the commitment sheets shared the pop-then-write bug
   (they already set `_busy` synchronously, awaited, then popped — they were the model for
   the fix). Correcting the document instead of "fixing" correct code is the point.

---

## 11. BLOCKED gates and exactly what unblocks each · **BLOCKED**

| Gate | Blocked on | Unblocks with | Owner |
|---|---|---|---|
| `dart format`, `flutter analyze` | no Flutter/Dart SDK | `flutter --version && flutter pub get && flutter analyze` | ENG |
| `flutter test` (13 suites, incl. the new one) | no SDK | `dart run build_runner build --delete-conflicting-outputs && flutter test` | ENG |
| Drift codegen (`database.g.dart`, v4 tables) | no SDK | the same `build_runner` step | ENG |
| `flutter build apk` / `appbundle` | no Gradle/Kotlin/aapt2 | `flutter build appbundle --release` on the overlay-applied project | ENG |
| Focus Lock blocking on hardware | no device | the nine-limit matrix in `FOCUS_LOCK.md` §limits on a real device | ENG |
| Health Connect on hardware | no device | grant, revoke, reboot, re-grant cycle on Android 13 and 14+ | ENG |
| Billing lifecycle | no Play Console | products configured + licence-testing evidence | RELEASE |
| Play declarations (FGS `specialUse`, usage access) | no console | console submission with the draft subtype text | RELEASE |

---

## 12. Verdict · **NOT YET PRODUCTION READY**

By the standing definition of done — *any unverified mandatory gate means NOT YET
PRODUCTION READY* — the verdict cannot be anything else, and it is unchanged by this pass:
`flutter analyze`, `flutter test`, Drift codegen, the Android build and every device pass
are **BLOCKED** on this host (`TEST_EVIDENCE.txt` proves the absence of the tools).

What this pass *does* establish, on evidence that exists in the tree:

* **17 defects fixed in code**, each pinned by a check or a test (counted in §A–H of
  `INTEGRATION_AUDIT.md`): the swallowed write failure and the missing failure surface;
  four force-unwrapped projection reads plus three unguarded series reads that the same fix
  made reachable; history rendered from a gap-filled projection; the missing day
  edit/delete path; two controls dispatching to unrelated tabs; the collapsed health result
  codes at both call sites; silent un-hiding on reorder; three vocabularies for one state
  and a long-press item that offered to hide what was already hidden; the calories
  delta/absolute confusion; double-submit on every logging sheet; a period sheet that saved
  nothing; health connection state that reset every launch; two stacked headers.
* **One compile error removed** (counted in the 17): `dayKey` declared twice across two
  libraries, used by three files that import both.
* **One check bug removed**: a `//` acceptance rule that had been silently passing three
  checks for the wrong reason.
* **Three audit over-claims corrected** and one test that could not fail fixed.
* **Release gate clean at 46 checks, all fourteen probes firing (the eleven added in this
  pass plus the three the cohesion pass added)**, and the
  bills-of-materials audits clean.

The gap between that and "production ready" is not more documentation: it is one machine
with the Flutter SDK, one Android device, and one Play Console account, in that order. The
commands are in item 11.
