# `:app:compileFlutterBuildDebug` failed — how to find the cause

Recorded 2026-10-21. This document exists because the Gradle output **does not
contain the error**. It reports the wrapper it owns:

```
> Task :app:compileFlutterBuildDebug FAILED
Execution failed for task ':app:compileFlutterBuildDebug'.
> Process 'command '/home/rolex/development/flutter-sdk/bin/flutter'' finished with non-zero exit value 1
```

Everything that explains the failure is printed by that `flutter` process,
*above* those lines, and Android Studio collapses it by default. The task itself
is `flutter assemble`; `exit value 1` only means "the Dart tool said no".

**Nothing in this document is a guess about your machine that has been applied
to the repository.** The only file that changes is the diagnostic script.

---

## 1. Get the real message (one command)

```bash
bash tools/diagnose_build.sh
```

It runs the same build with the output captured and prints, in order:

1. the toolchain it actually found (Flutter/Dart version, `java -version`, the
   `ANDROID_*` variables) next to what `pubspec.yaml` and `ci/workflows/ci.yml`
   require — including a loud warning when the installed Flutter is below the
   `flutter: ">=3.47.0"` floor in `pubspec.yaml`;
2. `flutter pub get` output, and it stops there if that is what failed;
3. the **`file:line:col: Error:` lines** from the Dart frontend;
4. `flutter`'s own `Error:` / `Target … failed` lines;
5. Gradle's `What went wrong` block;
6. a classification of the failure (SDK/solving, stale package config, Dart
   member error, codegen, AAR metadata, KGP, NDK, JVM memory) with the fix.

It reads only: no `pub upgrade`, no codegen, no `gradle clean`. Options:

```bash
bash tools/diagnose_build.sh --verbose                  # capture -v output too
bash tools/diagnose_build.sh --flutter /path/to/flutter # if flutter is not on PATH
bash tools/diagnose_build.sh --build appbundle          # same diagnostic for AAB
```

## 2. Or get it from Android Studio

* Build Output → click the `>` disclosure on the **`:app:compileFlutterBuildDebug`**
  node. The hidden lines carry the same message the script extracts.
* Or from a terminal (the one Studio uses, so the same JDK/`ANDROID_HOME`) —
  the script above is exactly this, with the noise filtered.

---

## 3. What the warnings in the build output mean (and what not to do)

Your screenshot shows 14 warnings and 1 error. The 14 are not the failure:

| Warning in your output | Means | Do |
|---|---|---|
| `Deprecated 'org.jetbrains.kotlin.android' plugin usage` — in `build/reports/problems/problems-report.html` or the console | The Flutter Gradle plugin applies KGP to `:app` because the AGP 9 opt-out is active | **Fixed 2026-10-21** — that one diagnostic id is suppressed in `android/gradle.properties`, with both blockers and the removal condition recorded. See the next section. |
| `The option setting 'android.builtInKotlin=false' is deprecated` | AGP 9.0 introduced built-in Kotlin; the opt-out is legacy and disappears in AGP 10 | Expected on this matrix, and deliberately **not** suppressed: it is the deadline. Not an error. |
| `The option setting 'android.newDsl=false' is deprecated` | Same migration, new Gradle DSL | Same as above |
| `plugins that apply KGP: health` | Flutter's own compatibility notice. `health` 13.3.2 applies `kotlin-android` unconditionally — this is blocker #1 below | Upgrade `health` when it migrates; do not flip the flag first |
| `New Minor Gradle Version Available` | Gradle 9.3.1 → newer exists | Nothing; Gradle, AGP and KGP move as one set, never alone |

### Why the plugin warning is suppressed, and what removes the suppression

`kotlin.suppressGradlePluginWarnings=DeprecatedKotlinAndroidPlugin` suppresses
exactly one diagnostic (the id AndroidX suppresses in its own
`gradle.properties`). It is not a substitute for migrating — the migration is
blocked by two facts that are checked, not assumed:

1. **`health` 13.3.2 applies the Kotlin Gradle Plugin unconditionally**
   (`apply plugin: 'kotlin-android'` in its `android/build.gradle`). With
   `android.builtInKotlin=true` that application is a configuration error at
   `:health`. (Verified in the 13.3.2 tree; 13.3.2 is the newest release this
   project can pin.)
2. **Flutter 3.47.7 rejects the Kotlin version AGP 9.1.0 bundles.** Its Gradle plugin
   fails with *"Your project's Kotlin version (2.2.10) is lower than Flutter's
   minimum supported version of 2.2.20"* (`flutter/flutter#192167`). The skip
   landed in `flutter/flutter#192206`, **after** 3.47 — so this is the Flutter
   SDK's limit, not a choice this repository can make.

Remove the suppression in the same change that removes
`android.builtInKotlin=false` / `android.newDsl=false`, after `health` ships a
built-in-Kotlin release and the build runs on a Flutter that contains #192206.
`tools/release_gate.py` check **P-52** fails if the four coupled facts (the two
opt-out flags, the KGP version pin, and this suppression) stop agreeing, so the
combination cannot be half-edited into a build that fails at configuration.
`docs/UPGRADE_2026-10-20.md` §8 records the evidence and the exact edit.

One more observation from your screenshot: the plugin list includes
**`device_info_plus`** and **`jni`**, and the editor tab is
`DeviceInfoPlusPlugin.kt`. Neither appears anywhere in this repository's
`pubspec.yaml`, and `jni` is not a plugin name in this tree. If your working copy
declares them, it differs from the committed `pubspec.yaml`:

```bash
git status --short
git diff pubspec.yaml pubspec.lock
```

That matters because a failure that is not reproducible from the committed tree
cannot be diagnosed from it. If `device_info_plus` was added locally, the
failing Dart error may well be in a local file.

---

## 4. Ranked causes, with the fix for each

Ordered by how often each one produces *exactly* this shape of output
(Gradle task fails, everything around it passed).

1. **Installed Flutter is older than `pubspec.yaml` requires.**
   `environment: flutter: ">=3.47.0"`, `sdk: ">=3.13.0 <4.0.0"`. The
   `flutter_tools` Gradle plugin from an older SDK also predates AGP 9.1.
   Fix: upgrade the SDK the build uses, and re-check
   `flutter --version` (`docs/UPGRADE_2026-10-20.md` §2 has the pinned pair).
   The diagnostic prints this comparison at the top of the run.
2. **`flutter pub get` never ran (or ran against a different tree).**
   No `.dart_tool/package_config.json` → the frontend cannot resolve
   `package:flutter/…`. Fix: `flutter pub get` in the same directory the build
   runs from.
3. **Stale generated code.** `lib/data/db/database.g.dart` is a `part` of
   `database.dart`; if the tables changed, the frontend reports undefined
   members inside it. Fix: `dart run build_runner build --delete-conflicting-outputs`
   (the CI gate `drift codegen fresh` in `tools/run_gates.sh` enforces this).
4. **A Dart member/type error in a file that changed locally.** The
   `file:line:col: Error:` line names it exactly. `tools/member_audit.py`,
   `tools/symbol_clash_audit.py` and `tools/import_audit.py` catch the
   resolved-name half of this class without a compiler.
5. **AndroidX AAR metadata** (`minCompileSdk 37`): only possible if
   `android/app/build.gradle.kts` was edited to take `core-ktx 1.19.x` /
   `lifecycle 2.11.x`. The ceiling is deliberate — see the comment there.
6. **NDK mismatch** or **Gradle JVM memory**:

   ```bash
   # NDK the SDK asks for:
   grep -rn ndkVersion android/app/build.gradle.kts
   # memory: android/gradle.properties (currently -Xmx4G -XX:MaxMetaspaceSize=2G)
   ```

   For memory, add `org.gradle.parallel=false` for one run before raising it.

---

## 5. What was checked from this repository, 2026-10-21

The sandbox this was reviewed in has no Flutter/Dart SDK and no Android SDK, and
`pub.dev`, `storage.googleapis.com` and `services.gradle.org` are unreachable, so
**`flutter analyze` / `flutter test` / `flutter build` could not be executed
here** (same environment limits as `docs/UPGRADE_2026-10-20.md` §1). What *was*
executed:

| Check | Result | What it rules out |
|---|---|---|
| tree-sitter parse of all 70 `.dart` files in `lib/` + `test/` | **PASS**, 0 parse errors | Syntax damage, unclosed brackets, broken string interpolation |
| `tools/release_gate.py` | **PASS**, 52 checks | The repository's own structural rules |
| `tools/{import,member,symbol_clash,test_api,static}_audit.py` | **PASS** | Unresolved imports, undeclared members, duplicate symbols |
| call-site argument audit (arity + named/required, 2 247 call sites) | **PASS**, 0 mismatches | Wrong argument names/counts against declarations in `lib/` |
| enum-reference audit (`Enum.value` refs, switch exhaustiveness) | **PASS** | Renamed/missing enum values |
| app-symbol resolution (every uppercase name in files that import no packages) | **PASS**, 0 unresolved | Moved or renamed app classes |

So there is no static evidence of a Dart-level break in the committed tree. That
points at the toolchain or at a local difference (§3), which is precisely why
the next step is to capture the message rather than to change build files.

---

## 6. If it is still unclear

Send any one of:

* the output of `bash tools/diagnose_build.sh`;
* the lines above `Execution failed for task ':app:compileFlutterBuildDebug'`
  from the Build Output (expand the node), including `file:line:col`;
* `flutter --version`, `flutter doctor -v`, `git status --short`,
  `git diff pubspec.yaml`.

With a `file:line:col: Error:` line the fix is usually a two-line change. With
only the Gradle summary, the only honest answer is "unknown" — which is what the
previous attempt at this build produced.
