# Blank screen after onboarding / a few options — repair note (2026-11-05)

Branch: `arena/eb3f667e-trackpro`. This pass targets the reported shape: the app
opens, the user goes through a few options, and then a screen goes blank. The
previous startup repair (`STARTUP_2026-11-04.md`) made launch visible and
retryable; it did not cover exceptions thrown **after** the shell was already
mounted.

## Confirmed defects fixed

1. **Insights could read `.last` of an empty list.**
   `state.loggedFlags(7).last` threw when the projection had no loaded days, even
   if another tracker had a streak. In release that paints an error/blank tab.
   `loggedFlags` now returns an empty list explicitly, `loadedDays` uses the
   longest loaded series, and the streak card renders an empty-state line instead
   of indexing blindly.

2. **Tab indices were not validated.**
   `AppState.setTab` accepted any integer and `HomeShell` handed it straight to
   `IndexedStack`. An out-of-range value from a notification payload, deep link,
   or future caller would throw and take the shell down. `setTab` now records and
   ignores invalid indices; the shell also clamps defensively.

3. **Onboarding dismissed before it was saved.**
   `completeOnboarding()` set `onboarded = true`, notified, and only then awaited
   the preference write. A failed write left the user in the app for one run and
   replayed onboarding on the next; the final CTA also promised to create a
   routine but only landed on an empty tab. Completion now persists first, applies
   the landing tab in the same notification, guards double taps, and opens the
   routine picker when the CTA says it will.

4. **A build exception still looked like a blank screen.**
   Release-mode `ErrorWidget` is a grey rectangle. The app now replaces it with a
   readable panel naming the failure and offering **Try again** / **Back to
   Today**, backed by an interface epoch that rebuilds the shell's children.

5. **The widget snapshot could throw outside its own handler.**
   `WidgetBridge.writeSnapshot` built the payload before the `try`, so a bad
   projection escaped through the unawaited call fired when onboarding completes.
   Payload construction is now inside the guarded region, and the debounce timer
   is cancelled on dispose.

6. **Notification taps leaked a listener.**
   `NotificationRouter` subscribed to the tap stream without cancelling it. The
   subscription is now owned and disposed.

7. **"Add more" trackers were fake.**
   The addable catalogue only toggled a settings flag; no tracker row was created,
   so the UI said "added" but nothing appeared on Today. Adding now materialises a
   real tracker definition; removing hides it and keeps history.

8. **Blank days scored as consistency.**
   `activityScore` gave budget trackers a full hit on gap-filled zero days, so a
   fresh install could show non-zero consistency. Only positive values contribute
   now. The insights engine also uses the longest loaded series for its window and
   survives an empty catalogue.

## Regression tests added

`test/navigation_stability_test.dart` pins:

- out-of-range tab indices are recorded and ignored;
- onboarding persists before dismissing and does not dismiss on a failed write;
- an empty projection yields empty flags / fallback window instead of throwing;
- the insights engine survives an empty catalogue;
- a fresh install scores zero consistency;
- Insights renders an empty projection without an exception;
- the add-more catalogue creates a visible tracker and hides it on removal.

## Gates executed here

| Gate | Result |
|---|---|
| `python3 tools/static_audit.py` | PASS |
| `python3 tools/member_audit.py` | PASS |
| `python3 tools/import_audit.py` | PASS |
| `python3 tools/test_api_audit.py` | PASS |
| `python3 tools/symbol_clash_audit.py` | PASS |
| `python3 tools/release_gate.py` | PASS — 53 checks |
| `python3 tools/gate_probe.py` | PASS — every probed check fired |
| `npm --prefix billing_server test` | PASS — 78 tests |
| changed-file line budget | all changed lines <= 120 columns |

## Not executed

This workspace has no Flutter/Dart SDK, Android SDK, JDK, or device. The
following remain **unverified by execution** and must run on a toolchain host:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug   # then install and walk onboarding + all five tabs
```

No claim is made that the blank screen was reproduced on hardware from this
checkout. The fixes address concrete, source-level failure paths that produce
that symptom; the regression tests are written but not executed here.
