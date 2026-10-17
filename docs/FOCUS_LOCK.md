# Focus Lock

*Status: implemented in `track_flutter/`. Not verified on a device — see
[Evidence status](#evidence-status). Nothing in this document is a substitute for the
device pass listed at the end.*

---

## 1. What it is

A focus session with a goal, a length, an honest status line, and — where the user
grants the permissions — the ability to cover the apps they picked for the duration.

| Mode | What it enforces | Pause budget | Free? |
|---|---|---|---|
| **Standard** | The timer, the goal, Track's own reminders held, a reflection at the end. Nothing outside Track changes. | none (nothing to suspend) | yes |
| **App blocking** | The timer, plus the selected apps covered when they come to the front. | 5 min — pausing releases the apps | yes |
| **Deep focus** | App blocking plus a stricter exit (press-and-hold), a 3-minute pause budget, and degraded recording if the pause budget is exceeded. | 3 min | yes |

Entry points: a card on **Today**, **inside a routine's sheet** ("Start a focus session
for this"), **Settings → Focus Lock**, a scheduled reminder's notification, and the
**Focus history** screen.

Pro adds *scale*, never the feature: a block list longer than
`ProConfig.freeBlockedApps` (3), saved profiles, scheduled deep focus, and the pattern
analysis over the whole history. Every mode, the timer, the app picker, the session
summary, the reflection and the user's own history are free.
(`test/focus_budget_test.dart` asserts this so a later diff cannot quietly change it.)

---

## 2. The mechanism, and why it is the mechanism

```
Today / routine / Settings
        │
        ▼
FocusRepository (Dart)  ── writes the row FIRST, then asks the platform
        │
        ├── FocusEngine (pure): clocks, enforcement verdicts, outcomes, stats
        ├── Drift v4 tables: FocusSessions · FocusProfiles · FocusSchedules
        └── track/focus (MethodChannel)
                    │
                    ▼
        FocusChannel.kt  ── permissions, monotonic clock, app list, start/stop
                    │
                    ▼
        FocusSessionService.kt  (foreground service, type `specialUse`)
                    │  polls UsageStatsManager.queryEvents every 1.2 s
                    ▼
        FocusBlockOverlay.kt  (the panel, raised with the user-granted overlay)
```

**Clocks.** Elapsed time comes from `SystemClock.elapsedRealtime()` — a monotonic
clock that cannot be moved by the user, the network or a time-zone change. The wall
clock is stored beside it and used only for display and day keys. A session whose
monotonic clock is unavailable is recorded with `timingVerified = false` and its
summary says the length could not be checked.

**Evidence.** `FocusEnforcement` is derived on every tick from what the platform
reports:

| Value | Meaning | May the UI say "blocking"? |
|---|---|---|
| `timerOnly` | No blocking was requested. | No |
| `unavailable` | Blocking was requested; a required permission is missing. Nothing is enforced. | No |
| `armed` | Service alive, both grants held, **zero foreground events observed**. | **No** — the status reads "blocking set up, unconfirmed" |
| `verified` | Service alive, grants held, and the device has demonstrably reported foreground activity this session. | Yes |
| `lost` | The service died or a permission went away mid-session. | No |

`armed` is the value that makes this feature honest: it is what a device that refuses
to report usage looks like, and it is also what a genuinely quiet phone looks like.
The app cannot tell them apart, so it says so instead of guessing.

**Persistence.** The row is written **before** the service is asked to enforce, so a
crash between the two steps leaves a recoverable session rather than an enforcement
service nothing is recording. There is at most one live session; a store holding two
(from a crash between writes) is repaired on hydration by ending the older one as
`interrupted` with `serviceLost`. Recovery is idempotent by construction — the verdict
is written once and the second call finds no open row.

---

## 3. What Android still limits — permanent, documented, not bugs

These are limits of the platform, not of this implementation. They are stated to the
user **before** the session starts (`focus_setup_sheets.dart`) and again in the
session's status block.

1. **Detection is not interception.** Track cannot stop a launch. `queryEvents` is
   batched by the OS, so the panel can appear a second or two after the app opens —
   and a very brief open can be missed entirely. The honest claim is "covered when
   Track sees it", never "this app cannot be opened".
2. **`queryEvents` granularity varies by OEM and by device state.** Some builds report
   every transition; some coalesce them. This is why `detectionEvents` exists and why
   `armed` is a state rather than an error.
3. **Usage access is AppOps-protected.** Only the user can grant it, from
   Settings → Special app access → Usage access. No runtime dialog exists, so the app
   can only open that screen. Without it, no app can be covered in any mode.
4. **The overlay grant is required twice over.** Drawing the panel needs it; so does
   *starting* the panel activity from the background, under Android's
   background-activity-launch rules. Without it the detector must not claim to cover
   anything — which is why `unavailable`, not `armed`, is reported.
5. **Battery optimisation can suspend the service.** The heartbeat stops, the state is
   reported as lost, and the session is recorded as degraded. The app explains this and
   offers the settings screen; it does not pretend the session held.
6. **A force-stop is invisible.** Android gives a force-stopped app no callback at all.
   The state is therefore derived from the absence of a heartbeat
   (`FocusStore.SERVICE_STALE_MS`), never invented.
7. **A reboot resets the monotonic clock.** Recovery treats a negative delta as a
   restart and keeps only the banked focus time — the rest is unknowable and is not
   claimed.
8. **An app update stops the service.** Recorded as `interrupted` with
   `appUpdated` as the reason, so the history explains itself.
9. **Track's own reminders, not other apps'.** A session holds Track's 9pm check-in and
   streak saver. Silencing *other* apps needs Do Not Disturb access, which Track does
   not request — so it does not claim to.

### What is deliberately not used

No Accessibility Service, no VPN service, no Device Admin or device-owner profile, no
kiosk/lock-task mode, no `USE_FULL_SCREEN_INTENT`, no root, no hidden APIs, no
`FLAG_SECURE`, no fake screens and no imitation of another app's interface. Each of
those would cover apps more reliably and each would also hand the app the ability to
read or control far more of the device than this feature needs. The gate enforces the
manifest side of that promise (`P-25`), the screenshot-hiding side (`P-26`) and the
"no permission ever grants Pro" side (`P-24`).

Emergency functions are never in scope: dialer, system UI, launcher, settings, the
permission controller, keyboards and Track itself are refused at **both** layers — in
`FocusEngine.sanitizeBlockList` and again in `FocusChannel.start` — whatever a caller
passes.

---

## 4. Permission copy (what the user is actually told)

The full text lives in `focus_setup_sheets.dart → openFocusPermissionSheet`, and the
same wording is reachable before a session and from Settings:

| Permission | Why Track asks | What happens without it |
|---|---|---|
| **Usage access** | "Lets Track notice when a covered app comes to the front… It reads only the package name and the moment — never what is on the screen, never messages, never your accounts." | "Without it, no app can be covered. Sessions become timers." |
| **Display over other apps** | "Lets Track draw the 'this is covered' panel over the app you opened. The panel has one action… and it never imitates another app's interface." | "Track can detect an app but cannot say anything about it, so it does not claim to cover it." |
| **Notifications** | "Used for the running-session notice Android requires while the detector is active, and for scheduled sessions you set up." | "The running-session notice is missing and Android may stop the detector. A session still runs as a timer." |
| **Battery optimisation** | "If Android is optimising Track, it can suspend the detector mid-session." | "Sessions still run, but they may quietly stop being enforced." |

Two sentences accompany every sheet, and both are load-bearing:

> *"Track never turns a permission on for you, and a permission never unlocks anything
> paid."*

> *"Track keeps focus sessions on this device. Nothing about which apps you open is
> sent anywhere."*

---

## 5. Privacy

* **Stored (local only, deleted with the session):** session id, mode, planned minutes,
  goal label, optional linked routine id, both clocks, focus/paused milliseconds,
  state, outcome, end reason, enforcement value, and three counters — blocked attempts,
  overlay shows, detection events. Plus the covered package ids, the user's reflection,
  and a day key.
* **Not stored, ever:** what was on the screen, app content, messages, notifications
  from other apps, credentials, location, contacts, or a history of which apps were
  opened when. The detector compares a package name against the user's own list in
  memory and increments an integer.
* **Not transmitted:** nothing. There is no upload path for focus data; the only
  outbound call in the app is purchase-token verification.
* **Clocks vs content:** "3 apps covered, 2 opens detected" is arithmetic on the
  device. It is not a log of the user's phone usage, and the history screen never
  presents it as one.
* **Export:** sessions are included in the user's own JSON export
  (`track.focus.v1`) and a CSV export, both triggered by the user and saved by them.

---

## 6. Play Console declarations

**Foreground service type.** `specialUse`, subtype `focus_session_detector`
(`<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" …/>`).
Play Console → *App content → Foreground service types* requires a written
justification. A draft:

> Track is a habit tracker. Its Focus Lock feature lets a user run a timed focus session
> and, if they grant usage access and the display-over-other-apps permission, have the
> apps they chose covered for that session. The foreground service polls
> `UsageStatsManager.queryEvents` for foreground-app transitions and shows a notice
> with a running timer and an "End" action, so the user can always see that a session is
> active and stop it. No other category fits: the work is not media playback, not
> location, not a call, not a data sync and not a health service. It is a user-started,
> user-visible, bounded session (5–180 minutes) that ends when the timer reaches zero or
> the user taps End. The service is `exported=false`, holds no other app's data, and
> stores nothing but its own counters.

**Also required in the release path:** the *Usage access* declaration under
*App content → Sensitive permissions* (Play asks for a justification for
`PACKAGE_USAGE_STATS`), and the data-safety form must declare that app-usage
information is processed on-device and **not** shared.

**Rejection is a release blocker.** If any of these declarations are missing or
rejected, the release is not shippable, and no amount of working code changes that.

---

## 7. Rollback plan (RB-04)

If Focus Lock has to be withdrawn after release — a policy rejection, a device family
where the detector misbehaves, or a defect in the panel — this is the order of retreat.
Each step is a separate, independently shippable change, and each one **fails closed**:
sessions get quieter, they never get louder.

| Step | Change | Effect on users |
|---|---|---|
| RB-04.1 | Set `AppState.hasFocusSupport` to `false` (one line, `focusRepo` not passed from `main()`) | Focus Lock disappears from Today/Settings. Sessions already recorded stay in the database and in the export; nothing is deleted. |
| RB-04.2 | Remove the `startForegroundService` call path (`FocusChannel` `start` returns false) | New sessions are timers that say so; the history keeps every row. |
| RB-04.3 | Remove the FGS + `specialUse` declaration and the `FOREGROUND_SERVICE*` permissions from the manifest | The detector cannot run at all. Blocking is gone; nothing else in the app changes. |
| RB-04.4 | Delete `FocusSessionService.kt` / `FocusBlockOverlay.kt` / `FocusChannel.kt` and deregister the channel | The Dart side degrades to `NoFocusEnforcer`: every capability reads as absent, and `MethodChannelFocusEnforcer` answers null/false. |
| RB-04.5 | Leave the v4 tables and the migration in place | Dropping a table is a destructive migration. The rows are the user's own history; they can be read by a future version or exported by the user. Do not drop them. |

**Never do on rollback:** delete or rewrite session rows, change an outcome, remove
the export, or hide a session that the user ran. A withdrawn feature that edits the
user's record on the way out is worse than the defect that caused the rollback.

---

## 8. Tests

| File | What it pins |
|---|---|
| `test/focus_engine_test.dart` | enforcement verdicts (armed ≠ verified), outcomes (a lost-enforcement session is never clean), the reboot branch, protected apps, pause budgets, stats thresholds, labels |
| `test/focus_recovery_test.dart` | the recovery matrix: background/foreground, reboot, revocation, app update, expiry-while-away, process termination, and the sentences each produces |
| `test/focus_repository_test.dart` | one live session, repair of two, the write-then-start order, the checkpoint throttle, pause banking with a stored pause start, reflections, profiles/schedules, export, deletion |
| `test/focus_budget_test.dart` | the free/Pro split, permission-never-grants-Pro, the emergency-app guarantees, the "before you start" copy, and the banned over-claiming phrases |
| `tools/release_gate.py` P-20…P-31 | the structural and honesty invariants, proven to fire on a probe of each |

---

## Evidence status

**NOT TESTED / BLOCKED.** No Flutter, Dart, Gradle, Kotlin or Android SDK exists in the
environment where this was written, and no Android device is attached. Therefore:

| Gate | Status |
|---|---|
| `flutter analyze`, `flutter test` (the four focus test files included) | **BLOCKED** — no SDK |
| `dart run build_runner build` (`database.g.dart`, v4 tables) | **BLOCKED** — no SDK |
| `flutter build apk --release` with the merged manifest | **BLOCKED** — no SDK |
| Device pass: grant/revoke each permission mid-session; force-stop; reboot; app update; battery restriction; multi-window; OEM with batched usage events | **NOT TESTED** — no device |
| Play Console FGS + usage-access declarations | **NOT TESTED** — no console access |

What *is* verified here: the text-level audits (`tools/static_audit.py`,
`tools/member_audit.py --all`, `tools/import_audit.py`, `tools/test_api_audit.py`), the
release gate (46 checks, clean, with every Focus Lock check, every integration-repair check and every wipe check probe-proven to fire), and
the fact that no automated result has been fabricated — `../TEST_EVIDENCE.txt` records
exactly which tools were present and which were not.

**No claim of working app blocking on any device is made anywhere in this repository
until that device pass exists.**
