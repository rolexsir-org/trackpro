#!/usr/bin/env bash
# Track Pro — full quality-gate run, in release order.
#
#   bash tools/run_gates.sh            # gates only
#   bash tools/run_gates.sh --build    # gates + release APK/AAB + artifact check
#
# Run from the repository root on a machine with Flutter stable >= 3.44,
# JDK 17 and the Android SDK (flutter doctor -v must be clean for Android).
# Every gate prints PASS or FAIL and the script exits non-zero on the first
# failure, so partial output is always trustworthy.
#
# The two Python gates run FIRST, on purpose: they need no toolchain, so a checkout
# with no Flutter installed still gets the structural half of the evidence — and both
# of them must run for the audit trail in docs/TEST_RESULTS.md to say anything true.
# `gate_probe` is the check on the checks: it breaks each rule in `release_gate` on
# purpose and requires the gate to fire, so a rule that has quietly stopped reading
# anything (which is how this repo's gate went missing once) cannot pass here.
set -uo pipefail

BUILD=0
[ "${1:-}" = "--build" ] && BUILD=1

pass=()
fail=""

gate() {
  local name="$1"; shift
  echo
  echo "=============================================================="
  echo "GATE: $name"
  echo "  \$ $*"
  echo "=============================================================="
  if "$@"; then
    echo "--> PASS: $name"
    pass+=("$name")
  else
    local code=$?
    echo "--> FAIL: $name (exit $code)"
    fail="$name"
    summary
    exit $code
  fi
}

summary() {
  echo
  echo "================= GATE SUMMARY ================="
  for p in "${pass[@]:-}"; do [ -n "$p" ] && echo "  PASS  $p"; done
  [ -n "$fail" ] && echo "  FAIL  $fail"
  echo "================================================"
}

format_check() {
  git ls-files '*.dart' ':!:*.g.dart' | xargs dart format --output=none --set-exit-if-changed
}

codegen_fresh() {
  dart run build_runner build --delete-conflicting-outputs || return 1
  if ! git diff --exit-code --stat -- lib/data/db/database.g.dart; then
    echo "database.g.dart was stale. The regenerated version is now in your"
    echo "working tree — review and commit it, then re-run this script."
    return 1
  fi
}

artifact_check() {
  local apk=build/app/outputs/flutter-apk/app-release.apk
  local aab=build/app/outputs/bundle/release/app-release.aab
  ls -la "$apk" "$aab" || return 1
  local bt="$ANDROID_HOME/build-tools/$(ls "$ANDROID_HOME/build-tools" | sort -V | tail -1)"
  "$bt/aapt2" dump badging "$apk" | grep -E "^package|sdkVersion|targetSdkVersion|application-label" || return 1
  "$bt/apksigner" verify --print-certs "$apk" || return 1
  unzip -l "$apk" | grep -q "lib/arm64-v8a/" || { echo "missing arm64-v8a"; return 1; }
  echo "AAB signer:"
  keytool -printcert -jarfile "$aab" | head -8
  echo "NOTE: if the cert says 'Android Debug', android/key.properties is not set"
  echo "      (fine for a smoke build; NOT uploadable to Play — see docs/RELEASE.md §2)."
}

gate "release gate (structural)"        python3 tools/release_gate.py
gate "gate probe (checks on the checks)" python3 tools/gate_probe.py
gate "import / member audits"           bash -c 'python3 tools/import_audit.py && python3 tools/member_audit.py && python3 tools/test_api_audit.py'
gate "flutter doctor (android toolchain)" flutter doctor -v
gate "flutter pub get"                    flutter pub get
gate "drift codegen fresh"                codegen_fresh
gate "dart format (hand-written files)"   format_check
gate "flutter analyze"                    flutter analyze
gate "flutter test"                       flutter test

if [ "$BUILD" = "1" ]; then
  gate "flutter build apk --release"        flutter build apk --release
  gate "flutter build appbundle --release"  flutter build appbundle --release
  gate "artifact identity & signing"        artifact_check
fi

summary
echo "All executed gates passed."
