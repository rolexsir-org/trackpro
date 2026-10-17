# Track Pro — build & release guide (VS Code, Linux)

This is the complete path from a fresh clone to a Play-uploadable `.aab`.
Everything here runs from the repository root in a VS Code terminal; Android
Studio is never required.

## 0. Prerequisites

| Tool | Version | Check |
|---|---|---|
| Flutter (stable) | ≥ 3.44 (Dart ≥ 3.12 — see `pubspec.lock` → `sdks:`) | `flutter --version` |
| JDK | 17 | `java -version` |
| Android SDK | Platform 36 + build-tools | `flutter doctor -v` |

`flutter doctor -v` must show no Android issues before anything below.

## 1. Setup and quality gates

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift codegen
git ls-files '*.dart' ':!:*.g.dart' | xargs dart format --output=none --set-exit-if-changed
flutter analyze
flutter test
```

All four must pass. If `database.g.dart` changed after codegen, commit it.

## 2. One-time: create and protect the upload keystore

```bash
keytool -genkey -v \
  -keystore "$HOME/keystores/trackpro-upload.jks" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Rules:

- Keep the keystore **outside** the repository (e.g. `~/keystores/`).
- Back it up to at least one offline location (password manager + encrypted drive).
  With Play App Signing, Google holds the *app* signing key and this is only the
  *upload* key — it can be reset through Play Console support if lost, but that
  takes days.
- Never commit the keystore, its passwords, or `key.properties`. All three
  patterns are git-ignored (`android/.gitignore`).

Then create `android/key.properties` (git-ignored):

```properties
storeFile=/home/YOUR_USER/keystores/trackpro-upload.jks
storePassword=********
keyAlias=upload
keyPassword=********
```

`android/app/build.gradle.kts` picks this file up automatically. If it is
absent, release builds fall back to the **debug** key: fine for CI and local
smoke tests, never uploadable to Play.

## 3. Production configuration (`--dart-define`)

Release behaviour is configured at build time, in one place
(`lib/config/app_environment.dart`). Create `release-defines.json`
(git-ignore it if you add secrets-adjacent values):

```json
{
  "TRACK_VERIFY_URL": "https://YOUR-BACKEND/billing/verify",
  "TRACK_TERMS_URL": "https://YOUR-SITE/terms",
  "TRACK_PRIVACY_URL": "https://YOUR-SITE/privacy",
  "TRACK_SUPPORT_EMAIL": "support@YOUR-SITE"
}
```

- All URLs must be HTTPS (`AppEnvironment.validate()` flags anything else).
- Without `TRACK_VERIFY_URL` the app **cannot grant Pro** — purchase
  verification fails closed by design. Deploy the verification backend first
  (see `MONETIZATION.md`).

## 4. Build the release artifacts

```bash
# Play upload artifact:
flutter build appbundle --release --dart-define-from-file=release-defines.json

# Direct-install artifact (device smoke test):
flutter build apk --release --dart-define-from-file=release-defines.json
```

Outputs:

| Artifact | Path |
|---|---|
| AAB (upload this to Play) | `build/app/outputs/bundle/release/app-release.aab` |
| APK (smoke test) | `build/app/outputs/flutter-apk/app-release.apk` |
| R8 mapping (upload with each release) | `build/app/outputs/mapping/release/mapping.txt` |

## 5. Verify before uploading

```bash
BT="$ANDROID_HOME/build-tools/$(ls $ANDROID_HOME/build-tools | sort -V | tail -1)"
"$BT/aapt2" dump badging build/app/outputs/flutter-apk/app-release.apk \
  | grep -E "^package|sdkVersion|targetSdkVersion"
#   expect: name='com.track.app' versionCode from pubspec, targetSdkVersion 36

"$BT/apksigner" verify --print-certs build/app/outputs/flutter-apk/app-release.apk
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
#   expect: YOUR upload certificate, not "Android Debug"
```

Then install and exercise on a real device:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Release-build smoke list: first launch → onboarding/Today screen; log a value;
kill + relaunch (persistence); add the widget; schedule the 9pm check-in;
start/stop a Focus session; open the paywall; Settings → export data;
dark mode. R8 problems show up **only** here, never in debug.

## 6. Versioning

Bump `version:` in `pubspec.yaml` (`1.0.0+12` → name `1.0.0`, code `12`).
Play requires a strictly increasing `versionCode` for every upload.

## 7. Troubleshooting (environment-specific)

| Symptom | Cause / fix |
|---|---|
| `flutter.sdk not set in local.properties` | Run any `flutter build …` once, or create `android/local.properties` with `flutter.sdk=/path/to/flutter`. Never commit it. |
| `pub get` fails: "requires Flutter ≥ 3.44" | Your Flutter stable is older than the lockfile. `flutter upgrade`. |
| Kotlin/Compose version error in `:app` | `org.jetbrains.kotlin.plugin.compose` must match the Kotlin version — both are pinned together in `android/settings.gradle.kts`. |
| `database.g.dart` analyzer errors | Re-run `dart run build_runner build --delete-conflicting-outputs`. |
| Widget/notifications/focus service missing **in release only** | An R8 keep rule was removed — restore `android/app/proguard-rules.pro`. |
| AAB signed with "Android Debug" | `android/key.properties` missing or unreadable (§2). |
| Gradle OOM on 8 GB machines | Lower `org.gradle.jvmargs` in `android/gradle.properties` to `-Xmx2G`. |

## 8. CI

`.github/workflows/ci.yml` runs the same gates (format, codegen freshness,
analyze, test) plus release APK/AAB builds on every push, and uploads the
artifacts. CI has **no signing secrets** — its release artifacts are
debug-signed on purpose; the Play upload is built locally per this document.
`.github/workflows/normalize.yml` (manual dispatch) runs `dart format` +
drift codegen with the real toolchain and commits the result.
