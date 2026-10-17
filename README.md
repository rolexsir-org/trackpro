# Track Pro

One app for everything you track daily — commitments (habits), water, mood,
expenses, sleep, calories, steps, cycle, screen time, weight — plus Focus Lock
sessions, a Glance home-screen widget, Health Connect sync (read-only: steps,
sleep, weight) and a Play Billing paywall.

- **Package:** `com.track.app` · **Dart package:** `track` · **Version:** see `pubspec.yaml` (`x.y.z+code`)
- **Platforms:** Android (primary, in `android/`), Linux desktop (dev convenience, in `linux/`)
- **Stack:** Flutter + provider · Drift (SQLite) · flutter_local_notifications · health · in_app_purchase

## Project layout

| Path | What it is |
|---|---|
| `lib/` | All Dart code. Entry point `lib/main.dart`. |
| `lib/data/db/database.dart` | Drift schema (v4). `database.g.dart` is **generated** — never edit by hand. |
| `android/` | The real Android host (Gradle, manifest, Kotlin seams, widget, Focus Lock service). |
| `android_overlay/` | **Historical.** The pre-merge overlay; superseded by `android/`. See its README. |
| `test/` | Unit/widget tests (`flutter test`). |
| `tools/` | Python text-audit gates that run without a Flutter SDK. |
| `docs/` | Audits, release guide (`RELEASE.md`), Play checklist (`PLAY_CHECKLIST.md`). |

## Prerequisites

- Flutter **stable** ≥ 3.44 / Dart ≥ 3.12 (see `pubspec.lock` → `sdks:`), on your `PATH`
- Android SDK (API 36) + JDK 17 (`flutter doctor -v` must be clean for Android)
- VS Code with the Dart & Flutter extensions (Android Studio is *not* required as an editor)

## Setup (VS Code)

```bash
git clone https://github.com/rolexsir-org/trackpro.git
cd trackpro
code .                 # open at the repository root — this IS the Flutter project root
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regenerate Drift code
```

## Quality gates (run before every push)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
git diff --exit-code -- lib/data/db/database.g.dart   # generated code must be committed fresh
git ls-files '*.dart' ':!:*.g.dart' | xargs dart format --output=none --set-exit-if-changed
flutter analyze
flutter test
```

CI (`.github/workflows/ci.yml`) runs the same gates plus
`flutter build apk --release` and `flutter build appbundle --release`.

## Run & debug

```bash
flutter run            # device/emulator; debug build
```

No `--dart-define` is needed for development. Without `TRACK_VERIFY_URL`,
purchase verification has no backend and Pro deliberately stays locked
(fail-closed; see `lib/config/app_environment.dart`).

## Release

The complete, safe release procedure — keystore creation and protection,
`android/key.properties`, required `--dart-define`s, artifact locations,
verification, and troubleshooting — is in **[docs/RELEASE.md](docs/RELEASE.md)**.
The Google Play submission checklist is in **[docs/PLAY_CHECKLIST.md](docs/PLAY_CHECKLIST.md)**.

Never commit keystores, passwords or `key.properties` (they are git-ignored).
