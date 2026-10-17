# Mock-data and fabricated-metric audit

Scope: every source of sample data, seeded history, hardcoded statistic, fake
insight, placeholder result and simulated operation in the repository — the HTML
prototype, the Flutter app, the database bootstrap, the widget, the analytics, and
every release entry point.

Method: grep for the patterns, then read every hit. Commands are recorded so the
audit can be repeated; results are the actual output on 2026-10-16, not a summary of
intentions.

Owner: `ENG`. Re-run before every release; the machine-checked half lives in
`tools/release_gate.py` (checks P-01, P-01b, P-07, P-15, P-16, P-17) and in
`test/demo_policy_test.dart`.

---

## 1. Commands used

```bash
cd /home/user/track_flutter

# A. any writer of synthetic rows, or any seeder machinery, in shipped code
grep -rn "source: 'demo'\|DemoSeed\|demoSeedEnabled\|DemoFixtures\|seedDemo" lib/

# B. the specific fabrications found in earlier drafts
grep -rInE "1,284|21\.6|−2\.8|▼ 0\.7|23-day|12 days in a row|4 weeks of streaks|28 days of history" lib/

# C. hardcoded identities and dates
grep -rInE "Jai Deshmukh|Tracking since [0-9]" lib/

# D. implied causation and unfounded claims in copy
grep -rInE "is the lever|causes|proves|means you will|Best week in" lib/

# E. literal sample rows outside test/
grep -rn "DemoFixtures" lib/ test/

# F. the frozen prototype (not shipped in the app binary)
grep -c "1,284\|demo" ../track.html
```

## 2. Findings and dispositions

| # | Where | What it was | Severity | Disposition |
|---|---|---|---|---|
| M-01 | `lib/data/demo_seed.dart` (156 lines) | A complete synthetic-history generator: 28 days × 10 trackers, a fabricated cycle history, a habit checklist — reachable from `main()` behind `--dart-define=TRACK_DEMO_SEED=true` | **Critical** (any mis-set flag ships invented history) | **Deleted.** `EntryRepository.bootstrap()` no longer takes a seeder at all, so the production start-up path has nothing to inject |
| M-02 | `lib/config/app_environment.dart` | `demoSeedEnabled` / `demoSeedMisconfigured` — a build-time switch whose whole purpose was to arm M-01 | High | **Removed.** Gate P-01 fails if the identifier returns |
| M-03 | `lib/screens/home_shell.dart` | Onboarding claimed `28 days of history · 4 weeks of streaks` over a bar chart of invented water values | High | **Replaced** with a labelled `EXAMPLE` card that shows the minimum-vs-full mechanic. Gate P-16 fails if the copy returns |
| M-04 | `lib/screens/home_shell.dart` | Onboarding promise: *"on days you hit your water goal, you log about 40 minutes more sleep"* — a fabricated correlation, presented as a sample of what the app finds | High | **Replaced** with the evidence rule: thresholds, sample sizes, and "it stays empty otherwise" |
| M-05 | `lib/screens/home_shell.dart` | Progress ring drawn at an arbitrary `.72` | Medium | **Now encodes a real ratio**: the share of the tracker catalogue that ships enabled, labelled as such |
| M-06 | `lib/screens/today_screen.dart` | `streak < 20 ? 23 : streak` — a hardcoded 23-day streak in a user-facing card, plus "you are 7 days from the 30-day badge", "best week in three", and "sleep is the lever" | **Critical** (four invented claims on the home screen) | **Rewritten**: the section now renders only from real rows and disappears when its evidence is missing |
| M-07 | `lib/screens/settings_screen.dart` | Profile card showed the invented user **"Jai Deshmukh"** and a hardcoded date **"Tracking since 17 Sep"** | High | **Replaced** with the real `trackingSince` (or an honest "nothing logged yet"), no name. Gate P-17 fails on hardcoded dates |
| M-08 | `lib/screens/settings_screen.dart` | A `✨ TRACK PRO` badge rendered unconditionally — every free user was shown a tier they had not bought | High | **Now gated on `state.isPro`**, with a "Free plan" chip otherwise |
| M-09 | `lib/screens/settings_screen.dart`, `lib/screens/trackers_screen.dart` | Hardcoded `1,284 entries` in a diagnostics row and an export subtitle | High | **Replaced** with `state.entryCount` (SQL count) — this is why a fresh install now reads 0 |
| M-10 | `lib/services/widget_bridge.dart` | Home-screen widget substituted `23` whenever the real streak was zero | High | **Fixed**: the widget ships the real streak and renders "no streak yet" |
| M-11 | `lib/services/notification_service.dart`, `lib/state/app_state.dart` | Reminder copy and settings rows that named trackers and claimed "Cloud backup · last sync today" | Medium | Notification bodies are generic by default (`hideDetails`, `NotificationVisibility.private`); the fake sync row is gone |
| M-12 | `lib/data/insights_engine.dart` | Earlier drafts shipped fixed insight strings | — | Verified: every `Insight` is built from rows with a `sampleDays` count; `InsightCard`s on Today/Insights are rendered only when a real sample exists |
| M-13 | `lib/services/pro_analytics.dart` | Funnel events | — | **Local SQLite only**, no network SDK, no fabricated figures; the table answers "what converts" with a `GROUP BY` |
| M-14 | `lib/data/food_reference.dart` | A calorie lookup table (e.g. "roti 120 kcal") | — | **Not user data.** It is reference data used to pre-fill a log entry the user confirms; a test asserts the value comes from the table, not from the user's record |
| M-15 | `track.html` (frozen prototype, ~128 KB) | Contains the illustrative data the early design used — 13 matches for sample-history markers | — | **Deliberately kept, and not shipped.** It is the frozen visual specification; it has no build step and is not bundled in the APK/AAB. Stated here so nobody mistakes it for product behaviour |
| M-16 | `test/fixtures/demo_fixtures.dart` | Synthetic history for tests | — | **Correct location.** `lib/` may not import it; a test scans every shipped file and fails if `DemoFixtures`, `DemoSeed` or `source: 'demo'` (as a write) appears there |
| M-17 | `lib/util/format.dart` (`ringPct`) | Weight's ring is scored as *distance from goal*, so the gap-filled zero of an unlogged day evaluated to **1.0** — a completed ring, and (because `streakOf` walks back while the ring is ≥ 70 %) a **90-day streak** on a brand-new install, shown as "90 days" on the weight detail screen | High | **Fixed**: a value of zero means "nothing logged" on every tracker, so `ringPct` returns 0 and no streak can be built from unlogged days. Test: `format_test.dart` "an unlogged day cannot supply a streak, on any tracker" |
| M-18 | `lib/util/format.dart` (`deltaOf`) | Two fabricated comparisons in one function. (a) The average included every gap-filled zero, so a first weight entry read **"72.5 kg vs last week"** against a week of nothing; (b) the label was built with `int.parse` over a one-decimal string, which **throws** — every water/steps/sleep/calories/weight card with a comparison crashed before drawing | High (a) / **Critical** (b: a crash on the main screen) | **Fixed**: the average is taken over logged days only (with an explicit `zeroIsAValue` list for the trackers where a logged zero is real — money, screen time, habits, period), a first entry reads "First entry — nothing to compare yet", and the label groups a `double` instead of parsing an `int` out of it. Tests: `format_test.dart` delta group (3 new cases) |

## 3. What the audit asserts, in code

| Assertion | Where | Machine check |
|---|---|---|
| A fresh database contains no rows at all | `test/demo_policy_test.dart` clause 1, `test/repository_test.dart` | `flutter test` |
| `lib/` never names a seeder, imports a fixture, or writes a `demo` row | `test/demo_policy_test.dart` clause 2 (scans `lib/**/*.dart`) | `flutter test` |
| The seeder switch no longer exists | clause 2, `assert app_environment.dart` contains no `TRACK_DEMO_SEED` | `flutter test` |
| Synthetic rows, if they exist from an old dev build, are labelled and removable | clause 4 | `flutter test` |
| Tracker definitions carry no statistic-shaped copy | clause 5 | `flutter test` |
| The gate refuses the removed APIs, the fake metrics, the placeholder dates | `tools/release_gate.py` P-01, P-01b, P-07, P-15, P-16, P-17 | `python3 tools/release_gate.py` → exit 0 |
| Momentum metrics cannot be produced without records | `test/momentum_engine_test.dart` (rate is `null` below 7 decided days — including the weekly review; patterns need 3 decided days on that weekday; improvement needs 7+7) | `flutter test` |
| An unlogged day cannot complete a ring or build a streak | `test/format_test.dart`, group "an unlogged day cannot supply a streak, on any tracker" | `flutter test` |
| A first entry is not compared against gap-filled zeros | `test/format_test.dart`, delta group | `flutter test` |
| A fresh install reads zero through `AppState`, not a placeholder | `test/app_state_test.dart` | `flutter test` |
| The user's export contains the routines as well as the measurements | `test/app_state_test.dart`, `test/commitment_repository_test.dart` (export group) | `flutter test` |

## 4. Residual risk

- **A user upgrading from an old development build may still hold `demo` rows.**
  They are labelled (`Sample data (not yours)` in Diagnostics), counted separately,
  removable in one tap, never counted as the user's days, and deleted wholesale by
  "Delete all data". No new build can create them.
- **The legacy habit conversion is a one-way import of *completions only*** — it
  cannot know which days an old checklist was never opened, so those days carry no
  record rather than an invented miss. `LegacyImportReport.limitation` states this in
  the app.
- **Reference data (M-14) is not user data**, but a reviewer skimming for numbers
  will find it. It is listed here so the distinction is explicit.
