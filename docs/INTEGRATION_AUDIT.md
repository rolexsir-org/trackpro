# Integration audit — Track / Track Pro

**Method.** Full read of `lib/` (51 files), `test/`, `tools/`, `android_overlay/` and
`docs/`, followed by targeted probes for each defect class the brief names:
force-unwraps, swallowed errors, stale reads after a mutation, wrong `setTab` targets,
delta-vs-absolute API misuse, unpersisted status fields and duplicate UI. Every item
below was reproduced by reading the exact line, then **fixed in the code**, then pinned
by a check or a test. Three claims from the first draft of this document turned out to be
wrong when the fix pass went to implement them; §H records the corrections, because an
audit that cannot be wrong is worth less than one that says where it was.

**Status legend.**
`FIXED` — changed in this pass; the symbol and file are named.
`CORRECTED` — the first draft was wrong; the truth is stated and the code was left alone.
`STILL BLOCKED` — needs a device, SDK or console this environment does not have.

**How each fix is held in place** (no fix rests on documentation):

| Surface | What it proves |
|---|---|
| `tools/release_gate.py` | 46 checks; the checks added in this pass are P-32…P-42 (the later cohesion pass added P-43…P-45) |
| `tools/gate_probe.py` | makes each of those defects real one at a time, asserts the gate fires, reverts |
| `tools/symbol_clash_audit.py` | ambiguous top-level names — a Dart compile error nothing else here can see |
| `tools/static_audit.py`, `import_audit.py`, `member_audit.py`, `test_api_audit.py` | declarations, imports, member references, test-to-`lib` references |
| `test/day_edit_test.dart` | the day read/edit/delete path and the failed-write behaviour (13 test files now) |

---

## A. False success and lost writes

### A-1 · `_persist` swallowed every write failure and left the optimistic value in the cache — FIXED
`lib/state/app_state.dart`. Eleven mutation paths change the in-memory model, call
`notifyListeners()`, then `unawaited(_persist(...))`, whose entire error handling was
`catch (_) { /* nothing */ }`.

Three consequences: the UI confirmed an action SQLite never received; the confirmation
survived until the next launch and then silently reverted; and every screen reading the
cache agreed with it, because the cache was the thing that was wrong.

**Fix as implemented.** The optimistic update still happens first — that is what keeps
logging instant — but a failure is no longer swallowed:

* `AppState.writeFailure` (`SaveFailure?`, from `lib/models/models.dart`) records the
  action in the user's words ("Water"), a reason a person can act on, and the time.
  `_describeWriteError` translates the exception: read-only, out of space, locked/busy,
  otherwise "your previous value is unchanged".
* `_persist` now **returns whether the write landed** (`Future<bool>`), so callers that
  need to know can wait for it; the eleven fire-and-forget call sites keep working and
  now each pass a `label` naming the action for the message.
* On failure the projection is re-derived from the store (`_rollbackProjection()` →
  `_reloadFromDb()` + `_refreshAggregates()`), so the screens stop showing a value that
  does not exist. The rollback is best-effort on purpose and explains why in the code: a
  database that cannot be written often cannot be read either, and a rollback that throws
  on top of the original failure would replace a reported failure with a crash.
* `_recordFailedWrite` gives the day-level write/delete path the same treatment.

**Enforced by:** gate P-37 (the surface must exist in `app_state.dart` **and**
`home_shell.dart`); `test/day_edit_test.dart` → "a failed day edit is refused, named, and
leaves the old value alone", "an optimistic log that fails is reported and rolled back",
"the rollback survives a database that cannot be read either" — the failure is produced
by `PRAGMA query_only`, i.e. by SQLite, not by a mock told to throw.

### A-2 · No surface for a failed write anywhere in the app — FIXED
There was no error state to render even if something wanted one.

**Fix as implemented.** `HomeShell` renders `_WriteFailureBanner` whenever
`AppState.writeFailure` is set: it names the action, states what happened to the data,
and is dismissed with `acknowledgeWriteFailure()` — a banner rather than a dialog,
because the failure already interrupted the user once. Settings → Diagnostics also lists
a "Last save problem" row, for the person who goes looking afterwards.

---

## B. Crash class: force-unwrapped projections

### B-1 · Four `history[id]!` reads — FIXED
`lib/screens/detail_screen.dart:43`, `lib/screens/trackers_screen.dart:58`,
`lib/screens/today_screen.dart:86,104`. `AppState.history` is a projection that does not
carry every tracker id, and `historyOf(id)` exists for exactly that reason. A tracker in
the database but absent from the projection took the whole screen down.

**Fix as implemented.** All four read through `historyOf()`; `_HistoryRow` no longer
indexes at all (see C-1). The three widgets that did `values.last` — `TrackerCard` (twice)
and `TrackersScreen`'s `_TrackerRow` — now read `values.isEmpty ? 0.0 : values.last`,
because the empty series is a real state and `MiniChart`/`deltaOf`/`streakOf` already
handle it. `detail_screen` computes `v` the same way.

**Enforced by:** gate P-32 (`history[...]!` may not reappear) and P-33 (an unguarded
`.last` in those widgets), both probe-proven.

---

## C. The record shown to the user is not the record

### C-1 · Detail-screen history rendered gap-filled zeros as entries — FIXED
The rows were built from the loaded series, which is **zero-filled to the cache window**,
and every past row was captioned with the tracker's marketing blurb. So a day the user
never logged appeared as `0` — indistinguishable from a logged zero — and the subtitle
said "Hydration keeps your skin, joints and focus in good shape" under a date, as though
it were a note about that day. That is fabricated data in the plainest sense: the screen
said "on 12 Oct you logged 0 glasses" when the truth was "you logged nothing on 12 Oct".

**Fix as implemented.** `EntryRepository.recordedDays(trackerId, limit:)` returns the days
that actually have a row (`RecordedDay = ({int day, double value, String source})`, newest
first). `_HistorySection` in `detail_screen.dart` renders that list: one row per stored
day, subtitled with the entry's **provenance** ("You", "Health Connect", "Widget",
"Imported"), and an empty state that says days appear only once they are logged. A read
failure is a third state, distinct from empty — the list cannot silently look empty
because the read failed. A deliberately logged zero *is* a row and stays visible: zero is
a value for screen time, spending, habits and the cycle, and the point is to distinguish
it from an absence, not to hide it.

**Enforced by:** gate P-41 plus four cases in `test/day_edit_test.dart` ("only days with a
row are listed…", "a day that was never logged is absent — not a zero", "a logged zero is
a reading", "the list is bounded by the requested window").

### C-2 · A recorded day could not be corrected or removed — FIXED
`setDaily`/`addEvent` only ever wrote *today*, and `deleteDailyFor` was reachable only from
the old demo-cleanup path. A value typed on Sunday for Saturday could not be entered at
all, and a mis-tap was permanent.

**Fix as implemented.**

* `EntryRepository.setDayValue(trackerId, day, value)` — one day, one row, upserted inside
  a transaction, validated by `ValueValidation.sanitize`, then patched into the cache slot
  that day maps to (or ignored when the day is outside the window, where there is nothing
  to patch).
* `EntryRepository.clearDay(trackerId, day)` — deletes the daily row **and** that day's
  event rows in one transaction, then clears the cache slot. A deleted day is **empty**,
  not zero: deleting is not the same as logging 0, and the difference is what makes
  streaks, averages and rings honest afterwards.
* `AppState.setDayValue` / `AppState.clearDay` — `bool` and `int?` (null = the delete
  failed, 0 = there was nothing stored, `>0` = rows removed), so the sheet's copy differs
  in all three cases instead of claiming "Day cleared" over an unchanged day.
* Tapping a history row opens `openDaySheet` (`log_sheets.dart`), which edits that day's
  value or clears it behind `_confirmClearDay` (a Cupertino alert that spells out that the
  day will read as *no record*, not as 0), then reloads the list.

**Enforced by:** gate P-39, P-40 and eight cases in `test/day_edit_test.dart`, including
"deleting also clears that day's events, so the export cannot disagree" (2 events + 1
rollup = 3 rows removed).

---

## D. Wrong destinations and stale labels

### D-1 · "Goal settings" opened Insights — FIXED
`trackers_screen.dart`: `setTab(3)`. Tab order is Today 0, Routines 1, Momentum 2,
**Insights 3**, Settings 4. The control was labelled "Goal settings" and landed on a
screen about correlations, with no route to a goal.

**Fix as implemented.** It opens `openGoalsSheet` (`log_sheets.dart`): every visible
tracker with its current goal, each row opening the existing goal sheet. The label and the
destination now agree. (Added: an inline hint beside it — "Tap Edit to reorder or hide" —
because the duplicate control below it is gone, see D-3.)

### D-2 · Settings → "Manage trackers" opened Momentum — FIXED
`settings_screen.dart`: `setTab(2)`. Same class: a labelled control that lands somewhere
unrelated. Trackers are deliberately not a tab, so the row now pushes the same pushed
wrapper Routines and Measurements already use (`MeasurementsPage`), which renders
`TrackersScreen` with its own header.

### D-3 · Add/remove tracker toast — CORRECTED, the first draft was wrong
The first draft recorded this as "the toast read a stale snapshot and said the opposite".
Re-reading `AppState.toggleAdded` shows it mutates `added` **synchronously** before
`notifyListeners()`, and the toast reads `state.added` after the call — so it printed the
post-toggle state and said "removed" on a removal. There was no defect here, and **no fix
was applied to the toast**; the code is as it was.

What was real in the same place: `trackers_screen.dart` had **two** controls for one mode
— the header's `Edit`/`Done` toggle and a `Reorder / remove` chip, both calling
`toggleEditing`. That chip is gone; `Edit` stays in the header, where iOS puts it. The
`_RowBtn` ✕ and the inline switch both call `toggleHidden`, which *does* toggle, so each
message now follows the resulting state (see E-2).

**Enforced by:** gate P-34/P-35 for the tab-dispatch class; the duplicate-control decision
is a design change, not a check.

### D-4 · Health sync reported the wrong reason for a no-op — FIXED
`syncHealth` returns `>0` days merged, `0` nothing to do, `-1` permission refused, `-2` not
entitled. Both call sites collapsed every negative into "Health Connect permission denied",
so a free user and a device without Health Connect were both told to fix a permission.

**Fix as implemented.** The Settings row and the pull-to-refresh toast each switch on the
code: `-2` says health sync is part of Pro (and opens the paywall, rather than blaming a
permission the user may well have granted), `-1` says the permission was not granted, `0`
is split three ways by `AppState.healthConnected` — connected with nothing new, not
connected, or Health Connect unavailable — and `>0` reports the days merged. There is no
`-3`: the first draft of this document claimed one, the code never had one, and inventing
a constant to match a document is the wrong direction.

---

## E. Data integrity and honesty in the state layer

### E-1 · Reordering a hidden tracker silently unhid it — FIXED
`AppState.move()` ended with `byId(id).hidden = false;` and `pinToTop()` with
`byId(id)..hidden = false`. Hiding is a user decision; moving a row is not consent to
reverse it.

**Fix as implemented.** Both methods reorder and persist the order only, and say why in a
comment. `test/day_edit_test.dart` asserts it in the cache **and** in the database row.

### E-2 · Three words for one state, and a menu that offered to hide what was hidden — FIXED
The same `hidden` flag was called "hidden from Today" in one control, "retired — history
kept" in another, and the Today long-press menu said "Hide from dashboard" even for a
tracker that was already hidden — so the one control that could bring it back read as a
second way to hide it.

**Fix as implemented.** One word everywhere — **hidden** — and every message reports the
resulting state: "hidden from Today — history kept" or "shown on Today again". The
long-press item is "Show on dashboard" when the tracker is hidden. The `trackers_screen`
header comment no longer says "retire, resurrect".

### E-3 · Calories: the running total was passed to a delta API — FIXED
The manual stepper is seeded with **today's total** (`start: state.today('calories')`) and
its action called `state.logAdd('calories', v)`, which treats `v` as a delta: 1,200 kcal
already logged, open the sheet, press the button → 2,400. The quick-add food rows were
correct (they pass a real delta); only the manual field was wrong.

**Fix as implemented.** The manual field writes the day's total through
`state.log('calories', value)`, which is what the number on screen means, and its label is
now **"Save total"** rather than "Add" — the two affordances in that sheet can no longer
be confused for one another. `test/day_edit_test.dart` pins the semantics: an absolute log
is idempotent, a delta adds exactly once.

### E-4 · Sheet actions could be submitted twice — FIXED
`Navigator.of(context).pop(); state.logAdd('calories', v);` — the write ran after the pop,
and the route stays on screen during its dismiss animation, so a tap arriving in that
window landed on a live button. Two taps, two writes: a delta counted twice, an expense
booked twice.

The first draft of this document also claimed "the commitment outcome tiles and the retry
row" had the same shape. They did not: `commitment_sheets.dart` already sets a `_busy`
flag synchronously, awaits the write and *then* pops. That file was the model for the fix,
not a victim of it.

**Fix as implemented.** `SubmitOnce` in `lib/widgets/glass.dart`:

* the guard is set **synchronously**, before the first `await` — a guard set inside the
  async body is a guard that arrives too late;
* success **latches** the control off for the rest of the widget's life, which is what
  closes the dismiss-animation window; a failure re-arms it, because the user needs to try
  again;
* `_Btn` now dims when `onTap == null`, so an inert button no longer looks live.

It is applied to every logging sheet (mood, habits, expense, sleep, calories, cycle,
default stepper), the goal sheet and both day-sheet actions. `_sheetAction` in
`log_sheets.dart` is the single shape those actions share: **write first, then pop, then
toast** — and a refused value keeps the sheet open and says nothing was saved.

**Enforced by:** gate P-36 (a `pop()` with a state write on the next two lines) and P-38
(`SubmitOnce` must exist).

### E-5 · The period sheet wrote nothing at all — FIXED (found during this pass)
`case 'period'` built `const _PeriodBody()`, whose flow and symptom chips lived in the
body's private state, and whose "Save" action popped and toasted **"Cycle updated"**
without writing anything. A user could set flow and six symptoms, tap Save, get a
confirmation, and lose all of it — the hardest kind of defect to notice, because the app
says it worked.

**Fix as implemented.** `_PeriodDraft` is owned by the sheet, rendered and edited by the
body (which now reads the draft rather than a private copy), and read by the action:
`AppState.logPeriod(flow:, symptoms:)` writes the day's value plus
`{"flow": n, "symptoms": [...]}` into the row's `meta_json`, which is what Export reads.
The cycle-day value itself is unchanged — Track has no "cycle started" concept, and
inventing one would be inventing a claim about the user's body; the sheet's subtitle says
"Cycle day N", which is what the stored number means.

**Enforced by:** `test/day_edit_test.dart` → "logPeriod keeps the flow and the symptoms,
not just the day".

---

## F. Status that did not reflect reality

### F-1 · Health Connect's connection state reset on every launch — FIXED
`lastSync` and `healthSyncedDays` were memory-only, and nothing ever re-queried the OS
permission after the first prompt.

**Fix as implemented.**

* `HealthService.permissionState()` → `HealthPermissionState { unknown, unavailable,
  denied, granted }`, probing availability first, because on Android 13 and below Health
  Connect is a separate app and "not installed" is a different state from "not granted" —
  they need different instructions.
* `AppState.healthPermission` is persisted in the settings KV, loaded on start, and
  re-asked in the background on every launch (`refreshHealthPermission()`), so a
  revocation in system settings stops being described as "connected".
* `syncHealth` writes `health.lastSync`, `health.syncedDays` and `health.permission` as
  it goes, so the Settings row reports the real last merge date after a restart.
* The Settings row now shows four different sentences for the four states, and Diagnostics
  carries the same information.

**Residual risk, stated plainly:** the re-probe happens on load and whenever the Health row
or the pull-to-refresh runs — there is **no** `AppLifecycleState` observer, so a permission
revoked while the app sits in the background is picked up on the next launch or the next
sync attempt, not the instant it is revoked. Adding that observer is a small change, but it
is a platform-behaviour change that cannot be verified on this host, so it was not made
blind.

---

## G. Duplicate UI

### G-1 · Two headers on the Measurements page — FIXED
`measurements_page.dart` stacked its own "Back" bar above `TrackersScreen`, which already
draws a `LargeTitleHeader`: two titles, two back affordances, and a bar of chrome above a
screen that had its own.

**Fix as implemented.** `TrackersScreen`'s header carries `TrackBackButton` as its
`leading` (the screen is always pushed — it is deliberately not a tab), and
`MeasurementsPage` is now `SafeArea(child: TrackersScreen())` with the canvas colour and a
doc comment that states what it wraps and why the old bar was wrong.

---

## H. Defects found *during* the fix pass

These were not in the first draft. They surfaced because fixing the first list meant
touching the same code paths, and one of them was a **compile error**.

### H-1 · `dayKey` was declared twice — a Dart compile error, in three files — FIXED
`lib/data/db/database.dart` declared its own `dayKey(DateTime)`, and
`lib/util/day_key.dart` declared another. Three files import both
(`data/commitment_repository.dart`, `data/focus_repository.dart`, `state/app_state.dart`)
and reference `dayKey`. In Dart that is not a shadowing warning, it is an error: *the name
'dayKey' is defined in the libraries '…/util/day_key.dart' and '…/db/database.dart'*. The
app could not have been built.

Nothing on this host runs `dart analyze`, and every existing text-level audit was happy,
because a duplicate definition looks exactly like a definition. It was found by a new tool
written for the purpose — `tools/symbol_clash_audit.py` — which collects top-level
declarations, walks each file's imports **and exports** transitively, and reports a name
that is visible from two different declarations at a point where the file uses it.

**Fix as implemented.** One declaration, in `util/day_key.dart`;
`db/database.dart` imports it and re-exports `show dayKey`, so existing importers keep
working and both import paths resolve to the same declaration. The twelve internal uses in
`database.dart` now call the shared function.

**Enforced by:** gate P-42, which runs `symbol_clash_audit.py`; probe-proven by
re-introducing a duplicate into `lib/util/format.dart`.

### H-2 · The gate's own `//` acceptance rule disabled three checks — FIXED
`release_gate.py` treats `accept_if` as "this use is sanctioned"; a bare `//` in that
pattern was meant to mean "documented right here", but it was matched against a
three-line window, so **any** use with a comment two lines above it was accepted. The
first probe run found P-32, P-33 and P-34 all failing to fire; they were passing because
of a comment, not because the code was clean.

**Fix as implemented.** `accept_if` is split on `|`; a bare `//` alternative is evaluated
against the **current line** only, and other alternatives keep the three-line window they
need for real guards (`if (x == null)` above the use it protects). All eleven new checks
now fire under probe.

### H-3 · Three `values.last` reads one step away from the same crash — FIXED
`Widgets/tracker_card.dart:40,257` and `screens/trackers_screen.dart:184`. Fixing B-1 made
an empty series *reachable* (`historyOf` returns an empty list instead of throwing), which
would have moved the crash from the screen to the card. All three now guard. Recorded
here rather than under B-1 because it was caused by the B-1 fix and caught by re-reading
the call sites, not by the original audit.

### H-4 · A test that could not fail — FIXED
`test/app_state_test.dart` asserted
`expect(state.series('steps', 10000).length, lessThanOrEqualTo(state.series('steps', 1).length > 0 ? 10000 : 10000))`
— both branches of the conditional are `10000`, so the assertion compared a value with
itself. It now asserts the real invariant: asking for more days than the cache holds
cannot return more points than `EntryRepository.cacheDays`. A test that cannot fail is
worse than no test, because it is counted.

---

## I. Verified as correct — checked, no change needed

Recorded so this document is not mistaken for a list of everything that was looked at.

| Area | What was checked | Result |
|---|---|---|
| Billing entitlement | Every `_apply` call site | Pro only from a server verdict with `verified: true`; `provisional` grants nothing; restore grants nothing by itself; fail-closed with no endpoint |
| Health merge | `mergeHealthSeries` | Per-`(tracker, day)` precedence manual > health > demo; re-runs upsert the same row; a stale `demo` row is deleted, not rewritten |
| Validation | `ValueValidation.boundsFor`/`sanitize` | Non-finite and negative rejected, out-of-range clamped, every write path goes through it (including the new `setDayValue`) |
| Insights thresholds | `InsightsEngine` constants | 14 logged days before patterns, 10 pairs and `|r| ≥ 0.35` before a correlation, 8 points before a trend |
| Momentum invariants | `momentum.dart` | Today never counted as decided; a recovery plan never fires when today is answered; both rates withheld below 7 decided days |
| Demo data | `lib/`, `android_overlay/`, `pubspec.yaml` | No seeder, no `DemoData`/`DemoFixtures` in `lib/`, no `TRACK_DEMO_SEED`; `test/fixtures/` is fixtures only; gate P-01/P-01b/P-15 |
| Migrations | `database.dart` `onUpgrade` | v2→v3→v4 additive; no destructive step; the focus tables are created, never rewritten |
| Entitlement expiry | `Entitlement.active` | Cached Pro cannot outlive its expiry, a revocation or the stale window |
| Notifications | `NotificationService` | One scheduler; every `schedule*` cancels its own id first; lock-screen detail off by default; scheduling stays inexact |
| Native seams | `track/haptics`, `track/widget`, `track/focus` | Absence is treated as absence: null/false on every failure path, never a fabricated success |
| Commitments sheet | `commitment_sheets.dart` | `_busy` set synchronously, write awaited, then pop — already correct (see D-3/E-4) |

---

## J. Residual risk after this pass

Stated so nobody reads the fix list as "there is nothing left".

1. **No foreground lifecycle observer for the health permission** (F-1). Revocation is
   noticed on load or on the next sync attempt, not at the moment it happens.
2. **Free-tier history is bounded by the query, not by the tier in the list itself.**
   `_HistorySection` asks for `freeHistoryDays` rows for a free user and shows the Pro row
   beneath; there is no per-row lock marker like the charts have.
3. **`recordedDays` returns rows, not gaps**, which is correct for the history list — but
   it means a caller wanting a dense series must gap-fill deliberately. Only the history
   list uses it today.
4. **Deleting a day removes `manual` daily rows and all event rows for that day.** A day
   whose value arrived from Health Connect is deleted here too; the next health sync can
   put it back. That is disclosed in the confirmation's wording ("the day goes back to
   having no record") but it is a genuine asymmetry.
5. **Nothing in this pass was executed.** `test/day_edit_test.dart` and the other twelve
   suites are unrun here (see §K), and `database.g.dart` still does not exist.

---

## K. Still blocked (needs a machine or an account this environment does not have)

| Gate | Status |
|---|---|
| `dart format`, `flutter analyze`, `flutter test` (13 files) | **BLOCKED** — no Flutter/Dart SDK |
| `dart run build_runner build` (`database.g.dart`) | **BLOCKED** — no SDK; the v4 tables are ungenerated |
| `flutter build apk` / `appbundle` | **BLOCKED** — no Gradle/Kotlin/aapt2 |
| Device pass: permissions, background, reboot, process death, billing lifecycle | **BLOCKED** — no device, no console |
| Play Console: products, FGS declaration, usage-access declaration | **BLOCKED** — no console access |

Nothing above is reported as passing. `../TEST_EVIDENCE.txt` records which tools were
present on this host and what each available check actually reported.
