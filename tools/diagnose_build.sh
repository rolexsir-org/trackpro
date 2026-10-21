#!/usr/bin/env bash
# Track Pro — surface the real cause of `:app:compileFlutterBuildDebug` failing.
#
#   bash tools/diagnose_build.sh                 # normal
#   bash tools/diagnose_build.sh --verbose       # verbose flutter output captured too
#   bash tools/diagnose_build.sh --flutter /path/to/flutter
#
# WHY THIS EXISTS
# ---------------
# Gradle only reports the wrapper it owns:
#
#   > Task :app:compileFlutterBuildDebug FAILED
#   Execution failed for task ':app:compileFlutterBuildDebug'.
#   > Process 'command '.../flutter'' finished with non-zero exit value 1
#
# Everything that actually explains the failure — the Dart frontend error, the
# version-solving message, the missing `package_config.json` — is printed by the
# `flutter` process that Gradle invoked, *above* that line, and Android Studio
# hides it until you expand the tree node. This script runs the same build with
# the output captured, then prints only the lines that identify the cause, in
# the order Dart/Gradle produced them.
#
# It changes nothing: no codegen, no `pub upgrade`, no gradle clean. It only
# reads. Exit codes: 0 = build passed, 1 = build failed (cause printed),
# 2 = could not run the diagnostic at all (toolchain missing).
set -uo pipefail

VERBOSE=0
FLUTTER_BIN="${FLUTTER:-}"
TASK="apk"
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v) VERBOSE=1 ;;
    --flutter)    shift; FLUTTER_BIN="${1:-}" ;;
    --build|-b)   shift; TASK="${1:-apk}" ;;
    -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 2
STAMP="$(date +%Y%m%d-%H%M%S)"
LOGDIR="${TMPDIR:-/tmp}/track-build-diagnose-$STAMP"
mkdir -p "$LOGDIR"

say() { printf '\n=== %s\n' "$*"; }
hint() { printf '    -> %s\n' "$*"; }

# --------------------------------------------------------------- find flutter
if [ -z "$FLUTTER_BIN" ]; then
  FLUTTER_BIN="$(command -v flutter 2>/dev/null || true)"
fi
if [ -z "$FLUTTER_BIN" ] && [ -x "$HOME/development/flutter-sdk/bin/flutter" ]; then
  FLUTTER_BIN="$HOME/development/flutter-sdk/bin/flutter"
fi
if [ -z "$FLUTTER_BIN" ] || [ ! -x "$FLUTTER_BIN" ]; then
  say "No flutter binary found"
  hint "Pass it explicitly: bash tools/diagnose_build.sh --flutter /path/to/flutter"
  hint "Android Studio prints the same path in the failing task line, e.g."
  hint "  Process 'command '/home/rolex/development/flutter-sdk/bin/flutter'' ..."
  exit 2
fi
FLUTTER_DIR="$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd)"

echo "repository : $ROOT"
echo "flutter    : $FLUTTER_BIN  ($FLUTTER_DIR)"
echo "logs       : $LOGDIR"

# ------------------------------------------------------------------- versions
say "Toolchain as this repository expects it"
echo "pubspec requires (environment):"
sed -n '/^environment:/,/^$/p' pubspec.yaml | sed 's/^/  /'
echo "ci/workflows/ci.yml pins:"
grep -nE "FLUTTER_VERSION|flutter-version|3\.[0-9]+\.[0-9]+" ci/workflows/ci.yml 2>/dev/null | head -5 | sed 's/^/  /'
[ -f "$FLUTTER_DIR/version" ] && echo "installed flutter (version file): $(cat "$FLUTTER_DIR/version")"
if [ -d "$FLUTTER_DIR/.git" ]; then
  echo "installed flutter (git):         $(git -C "$FLUTTER_DIR" describe --tags --always 2>/dev/null)  branch=$(git -C "$FLUTTER_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)"
fi
echo "java       : $( (java -version 2>&1 | head -1) || echo '<java not on PATH — AGP 9 needs JDK 17>' )"
echo "ANDROID_HOME=${ANDROID_HOME:-<unset>}  ANDROID_USER_HOME=${ANDROID_USER_HOME:-<unset>}  ANDROID_PREFS_ROOT=${ANDROID_PREFS_ROOT:-<unset>}"

# A stale SDK is the single most common cause of this task failing while every
# Gradle-level task around it succeeds, so compare it against the pubspec floor.
version_lt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$1" ]; }
if [ -f "$FLUTTER_DIR/version" ]; then
  INSTALLED="$(tr -d '[:space:]' < "$FLUTTER_DIR/version")"
  FLOOR="$(sed -n 's/^ *flutter: *">= *\([0-9.]*\)".*/\1/p' pubspec.yaml | head -1)"
  if [ -n "$FLOOR" ]; then
    if version_lt "$INSTALLED" "$FLOOR"; then
      echo
      echo "  !! installed Flutter $INSTALLED is BELOW the pubspec floor $FLOOR."
      hint "Upgrade the SDK before anything else:"
      hint "  git -C \"$FLUTTER_DIR\" fetch --tags && git -C \"$FLUTTER_DIR\" checkout <tag of $FLOOR> && \"$FLUTTER_BIN\" --version"
      hint "  (or point --flutter at an SDK that matches; see docs/UPGRADE_2026-10-20.md)"
    fi
  fi
fi

# ---------------------------------------------------------------- pub get
say "flutter pub get (writes .dart_tool/package_config.json)"
PUBLOG="$LOGDIR/pub-get.log"
( "$FLUTTER_BIN" pub get ) > "$PUBLOG" 2>&1
pub_status=$?
tail -5 "$PUBLOG" | sed 's/^/  /'
if [ $pub_status -ne 0 ]; then
  echo
  echo "  pub get FAILED (exit $pub_status). This is the cause; the Gradle task"
  echo "  cannot start without a package config. The message above names it."
  hint "full log: $PUBLOG"
  exit 1
fi

# ---------------------------------------------------------------- the build
say "flutter build $TASK --debug  (this is the task Gradle reported as failed)"
BUILDLOG="$LOGDIR/build.log"
if [ "$VERBOSE" = "1" ]; then
  ( "$FLUTTER_BIN" build "$TASK" --debug -v ) > "$BUILDLOG" 2>&1
else
  ( "$FLUTTER_BIN" build "$TASK" --debug ) > "$BUILDLOG" 2>&1
fi
build_status=$?
echo "exit status: $build_status   (full log: $BUILDLOG)"

# --------------------------------------------------------------- extraction
say "What actually failed"
# 1) Dart frontend: file:line:col: Error: ...
mapfile -t DART_ERRORS < <(grep -E "^[^ ]*\.dart:[0-9]+:[0-9]+: (Error|Warning):" "$BUILDLOG" | head -40 | cut -c1-400)
# 2) `flutter`'s own Error: lines (pub, assemble, version checks)
mapfile -t TOOL_ERRORS < <(grep -E "^Error: |^Target .* failed|^Failed to build" "$BUILDLOG" | head -40 | cut -c1-400)
# 3) Gradle's own failure block
mapfile -t GRADLE_ERRORS < <(grep -E "^(FAILURE: Build failed|What went wrong:|Execution failed for task|Caused by:|> )" "$BUILDLOG" | head -40 | cut -c1-400)

if [ ${#DART_ERRORS[@]} -gt 0 ]; then
  printf '\n-- Dart compile errors (the real message) --\n'
  printf '%s\n' "${DART_ERRORS[@]}" | sed 's/^/  /'
fi
if [ ${#TOOL_ERRORS[@]} -gt 0 ]; then
  printf '\n-- flutter tool errors --\n'
  printf '%s\n' "${TOOL_ERRORS[@]}" | sed 's/^/  /'
fi
if [ ${#GRADLE_ERRORS[@]} -gt 0 ]; then
  printf '\n-- Gradle failure block (last 25) --\n'
  printf '%s\n' "${GRADLE_ERRORS[@]}" | tail -25 | sed 's/^/  /'
fi
if [ ${#DART_ERRORS[@]} -eq 0 ] && [ ${#TOOL_ERRORS[@]} -eq 0 ] && [ ${#GRADLE_ERRORS[@]} -eq 0 ]; then
  echo "  (no recognisable error line — printing the last 40 lines instead)"
  tail -40 "$BUILDLOG" | sed 's/^/  /'
  hint "re-run with --verbose to capture more: bash tools/diagnose_build.sh --verbose"
fi

# ------------------------------------------------------- classify & advise
if [ $build_status -ne 0 ]; then
  say "Diagnosis"
  L="$(tr '[:upper:]' '[:lower:]' < "$BUILDLOG")"
  matched=0
  note() { matched=1; echo "  [$1]"; shift; for l in "$@"; do hint "$l"; done; echo; }

  case "$L" in
    *"requires sdk version"*|*"the current dart sdk"*|*"version solving failed"*|*"is incompatible with"*)
      note "SDK / dependency solving" \
        "The Dart SDK in use does not satisfy pubspec.yaml (or a dependency's constraint)." \
        "Check the versions printed at the top of this run, then upgrade the SDK:" \
        "  docs/UPGRADE_2026-10-20.md §2 lists the pinned Flutter 3.47.7 / Dart 3.13.5 pair." ;;
  esac
  case "$L" in
    *"package_config.json"*|*"pubspec.lock is outdated"*|*"run 'flutter pub get'"*)
      note "Stale package config" \
        "pub get reported success but the generated config is out of date (hand-edited lock," \
        "or a build that started before the last pubspec change)." \
        "  rm -rf .dart_tool && flutter pub get   (then rebuild)" ;;
  esac
  case "$L" in
    *"isn't defined"*|*"is not defined"*|*"undefined name"*|*"undefined class"*|*"not a type"*|*"couldn't infer"*)
      note "Dart type/member error" \
        "A symbol used in lib/ does not exist (renamed, moved, or an import is missing)." \
        "  The file:line:col lines above name it. tools/{member,symbol_clash,import}_audit.py" \
        "  catch the resolved-name class of this bug without a compiler; run them if editing." ;;
  esac
  case "$L" in
    *"build_runner"*|*"database.g.dart"*|*"part of"*)
      note "Drift codegen out of date" \
        "database.g.dart does not match lib/data/db/database.dart." \
        "  dart run build_runner build --delete-conflicting-outputs" ;;
  esac
  case "$L" in
    *mincompilesdk*|*aarmetadata*|*"aar metadata"*|*"compile against version"*)
      note "AndroidX AAR metadata (compileSdk)" \
        "A dependency requires a higher compileSdk than the Flutter 3.47 matrix allows." \
        "  See the AndroidX ceiling note in android/app/build.gradle.kts — the fix is to hold" \
        "  the library at the API-36-compatible release, never to raise compileSdk alone." ;;
  esac
  case "$L" in
    *"builtinkotlin"*|*"kotlin gradle plugin"*|*"kgp"*|*"no longer required for kotlin support"*)
      note "Kotlin plugin / AGP 9 migration" \
        "These are deprecations, not failures, on the current matrix (AGP 9.1.0 / KGP 2.4.0 /" \
        "  android.builtInKotlin=false). The 'org.jetbrains.kotlin.android' diagnostic is" \
        "  suppressed by kotlin.suppressGradlePluginWarnings in android/gradle.properties; if it" \
        "  is back, that line or one of the two flags was removed on its own." \
        "  Do NOT flip builtInKotlin to true: :health 13.3.2 still applies KGP outright, and" \
        "  Flutter 3.47.7 rejects AGP's bundled Kotlin 2.2.10 (flutter/flutter#192167)." \
        "  The migration and its exit condition: docs/UPGRADE_2026-10-20.md §8." ;;
  esac
  case "$L" in
    *"jni"*|*"unsatisfiedlinkerror"*)
      note "Native jni / device_info_plus" \
        "If your build lists plugins that this pubspec does not declare (device_info_plus, jni)," \
        "your working tree differs from the repository — those come from somewhere else." \
        "  git status; git diff pubspec.yaml    and confirm which tree you are building." ;;
  esac
  case "$L" in
    *"ndk"*|*"ndkversion"*)
      note "NDK version" \
        "flutter.ndkVersion from the SDK does not match what is installed." \
        "  Install the NDK the SDK asks for, or pin ndkVersion explicitly in android/app/build.gradle.kts." ;;
  esac
  case "$L" in
    *"outofmemory"*|*"java heap space"*|*"metaspace"*)
      note "Gradle/JVM memory" \
        "Raise org.gradle.jvmargs in android/gradle.properties (currently -Xmx4G) or stop" \
        "  parallel workers: add org.gradle.parallel=false for the failing run." ;;
  esac

  if [ "$matched" = "0" ]; then
    echo "  No signature matched. Paste these to get help:"
    echo "    - the '-- Dart compile errors --' / '-- flutter tool errors --' blocks above"
    echo "    - the last 30 lines of $BUILDLOG"
  fi

  say "Next"
  hint "In Android Studio you can also click the '> :app:compileFlutterBuildDebug' node in"
  hint "Build Output; the hidden lines carry the same message this script extracted."
  exit 1
fi

say "Build succeeded"
hint "build/app/outputs/flutter-apk/app-debug.apk"
exit 0
