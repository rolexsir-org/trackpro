#!/usr/bin/env bash
# Track Pro — Android environment sanity check.
#
# Root cause this guards: AGP 9's AndroidLocationsBuildService computes the
# Android preferences folder (the `.android` directory) from several sources
# and *fails service creation* when they disagree:
#
#   ANDROID_USER_HOME   -> the `.android` folder itself   (current, supported)
#   ANDROID_PREFS_ROOT  -> the *parent* of `.android`     (deprecated)
#   ANDROID_SDK_HOME    -> the *parent* of `.android`     (deprecated, older)
#
# If e.g. ANDROID_PREFS_ROOT=$HOME/.android (a very common copy-paste, because
# older docs describe it as "the .android path") while ANDROID_USER_HOME is
# also set — or the legacy variables simply point somewhere else than
# $HOME/.android — AGP throws AndroidLocationsException:
# "Several environment variables and/or system properties contain different
# paths to the Android Preferences folder." and every Gradle task dies before
# a single file is compiled. Nothing is wrong with the SDK or `.android`
# itself, so deleting either (a common internet suggestion) fixes nothing and
# destroys AVDs/keys. The fix is to keep exactly one source of truth:
# ANDROID_USER_HOME, and unset the deprecated variables.
#
# This script only *reports*. It never modifies the environment, deletes
# anything, or touches SDK installations. The persistent fix for fresh
# VS Code terminals lives in .vscode/settings.json (which unsets
# ANDROID_PREFS_ROOT / ANDROID_SDK_HOME and pins ANDROID_USER_HOME for the
# integrated terminal); for non-VS-Code shells see docs/RELEASE.md §7.
set -uo pipefail

fail=0

prefs_from_user_home="${ANDROID_USER_HOME:-}"
prefs_from_prefs_root="${ANDROID_PREFS_ROOT:+${ANDROID_PREFS_ROOT%/}/.android}"
prefs_from_sdk_home="${ANDROID_SDK_HOME:+${ANDROID_SDK_HOME%/}/.android}"

declare -a sources=()
[ -n "$prefs_from_user_home" ]  && sources+=("ANDROID_USER_HOME=$prefs_from_user_home")
[ -n "$prefs_from_prefs_root" ] && sources+=("ANDROID_PREFS_ROOT -> $prefs_from_prefs_root")
[ -n "$prefs_from_sdk_home" ]   && sources+=("ANDROID_SDK_HOME -> $prefs_from_sdk_home")

if [ "${#sources[@]}" -gt 0 ]; then
  echo "Android preferences folder sources:"
  printf '  %s\n' "${sources[@]}"
fi

# Every set source must resolve to the same folder.
resolved=""
for candidate in "$prefs_from_user_home" "$prefs_from_prefs_root" "$prefs_from_sdk_home"; do
  [ -z "$candidate" ] && continue
  if [ -z "$resolved" ]; then
    resolved="$candidate"
  elif [ "$candidate" != "$resolved" ]; then
    echo
    echo "ERROR: conflicting Android preferences locations (AGP will refuse to build):"
    echo "  resolved so far: $resolved"
    echo "  conflicting:     $candidate"
    fail=1
  fi
done

if [ -n "${ANDROID_PREFS_ROOT:-}" ] || [ -n "${ANDROID_SDK_HOME:-}" ]; then
  echo
  echo "Deprecated variable(s) set: ${ANDROID_PREFS_ROOT:+ANDROID_PREFS_ROOT }${ANDROID_SDK_HOME:+ANDROID_SDK_HOME}"
  echo "Both are deprecated in favour of ANDROID_USER_HOME and are the usual cause of"
  echo "the AndroidLocationsBuildService failure. Unset them (see docs/RELEASE.md §7);"
  echo "do NOT delete ~/.android or your SDK."
  # A deprecated variable that *agrees* is noise, not a build failure — warn only.
  [ "$fail" -eq 0 ] && echo "(They currently agree with ANDROID_USER_HOME, so this is a warning, not an error.)"
fi

if [ "$fail" -ne 0 ]; then
  echo
  echo "Fix (Linux/bash, persistent): put these in ~/.bashrc and remove any"
  echo "ANDROID_PREFS_ROOT / ANDROID_SDK_HOME exports:"
  echo '  export ANDROID_USER_HOME="$HOME/.android"'
  echo '  unset ANDROID_PREFS_ROOT ANDROID_SDK_HOME'
  echo "In VS Code, .vscode/settings.json in this repo already does this for"
  echo "integrated terminals — open a *new* terminal after changing it."
  exit 1
fi

echo "Android environment: OK${resolved:+ (preferences folder: $resolved)}"
