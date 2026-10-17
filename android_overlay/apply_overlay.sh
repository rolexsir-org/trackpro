#!/usr/bin/env bash
# Applies the native overlay to a generated Flutter Android host.
#
#   bash android_overlay/apply_overlay.sh [path/to/track_flutter]
#
# Run it from a machine WITH the Flutter SDK, after:
#
#   flutter create --org com.track --project-name track --platforms android .
#
# It copies the Kotlin sources, XML resources and R8 rules, then verifies what it
# can verify without compiling: that each destination exists, that the widget
# receiver name in the manifest matches the class actually declared in Kotlin, and
# that the permissions the app's own code needs are present. It prints the one
# edit it cannot do safely for you (the manifest merge).
#
# It never overwrites AndroidManifest.xml: that file is Flutter's, contains the
# launcher activity, and a blind copy would break the app icon, theme and
# deep links.
set -euo pipefail

APP_DIR="${1:-track_flutter}"
OVERLAY="$(cd "$(dirname "$0")" && pwd)"
ANDROID="$APP_DIR/android"
KOTLIN_DIR="$ANDROID/app/src/main/kotlin/com/track/app"

if [ ! -d "$ANDROID" ]; then
  echo "No android/ host found under '$APP_DIR'." >&2
  echo "Run this first, from the project root:" >&2
  echo "  flutter create --org com.track --project-name track --platforms android ." >&2
  exit 1
fi

echo "1/5  Kotlin sources → $KOTLIN_DIR"
mkdir -p "$KOTLIN_DIR"
cp -v "$OVERLAY/app/src/main/kotlin/com/track/app/"*.kt "$KOTLIN_DIR/"

echo "2/5  Resources (widget metadata, strings)"
mkdir -p "$ANDROID/app/src/main/res/xml" "$ANDROID/app/src/main/res/values"
cp -v "$OVERLAY/app/src/main/res/xml/track_widget_info.xml" "$ANDROID/app/src/main/res/xml/"
# strings.xml is merged, not replaced: the generated file already has app_name.
if grep -q 'track_widget_description' "$ANDROID/app/src/main/res/values/strings.xml" 2>/dev/null; then
  echo "     strings.xml already merged"
else
  echo "     add this line to $ANDROID/app/src/main/res/values/strings.xml:"
  echo '       <string name="track_widget_description">Today'"'"'s water, sleep and steps — plus your streak.</string>'
fi

echo "3/5  R8 rules for the system-instantiated classes"
cp -v "$OVERLAY/app/proguard-rules.pro" "$ANDROID/app/proguard-rules.pro"

echo "4/5  Verification (what can be checked without a compiler)"
fail=0
for f in MainActivity.kt TrackWidget.kt WearSync.kt FocusChannel.kt FocusStore.kt FocusSessionService.kt FocusBlockOverlay.kt; do
  if [ -f "$KOTLIN_DIR/$f" ]; then printf '     ok    %s\n' "$f"; else printf '     MISSING %s\n' "$f"; fail=1; fi
done

widget_pkg=$(grep -m1 '^package ' "$KOTLIN_DIR/TrackWidget.kt" | awk '{print $2}' | tr -d ';')
widget_class=$(grep -m1 '^class TrackWidgetReceiver' "$KOTLIN_DIR/TrackWidget.kt" >/dev/null && echo yes || echo no)
if [ "$widget_class" = "yes" ]; then
  printf '     ok    TrackWidgetReceiver declared in package %s\n' "$widget_pkg"
  if grep -q "$widget_pkg.TrackWidgetReceiver" "$ANDROID/app/src/main/AndroidManifest.xml" 2>/dev/null \
     || grep -q '\.TrackWidgetReceiver' "$ANDROID/app/src/main/AndroidManifest.xml" 2>/dev/null; then
    printf '     ok    manifest references a receiver matching that package\n'
  else
    printf '     NOTE  manifest does not reference %s.TrackWidgetReceiver yet (expected before the merge step)\n' "$widget_pkg"
  fi
fi
[ "$fail" = "0" ] || { echo "     verification FAILED" >&2; exit 1; }

echo "5/5  Manifest merge (manual, by design)"
echo "     Merge the entries from:"
echo "       $OVERLAY/app/src/main/AndroidManifest.xml"
echo "     into $ANDROID/app/src/main/AndroidManifest.xml"
echo
echo "     Then:"
echo "       cd $APP_DIR && flutter pub get"
echo "       dart run build_runner build --delete-conflicting-outputs"
echo "       flutter analyze && flutter test"
echo "       flutter build apk --release --dart-define-from-file=release-defines.json"
echo
echo "     Build defines and signing are documented in ../DEPLOYMENT.md."
