#!/usr/bin/env python3
"""Proves the release gate's checks actually fire — by making each defect real.

A check that has never failed is a check nobody has tested. This script edits the
working tree to reintroduce one defect at a time, runs `tools/release_gate.py` from the
repository root, asserts that the **expected** check id fires, and restores the file
whatever happens. Any probe that does not fire is reported as a failure of the probe,
not of the code.

Nothing here is left behind: every edit is applied to a file whose bytes are held in
memory and written back in a `finally`, and the run exits non-zero if any probe failed
or if a restore failed.

Usage:
    python3 track_flutter/tools/gate_probe.py            # all probes
    python3 track_flutter/tools/gate_probe.py P-42 P-36  # selected probes
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.dirname(HERE)          # the repository root: tools/ ships inside the app tree
ROOT = APP
GATE = os.path.join(APP, 'tools', 'release_gate.py')

# (check id, description, [ (file, find, replace), ... ])
#
# A REQUIRE-style check is satisfied by the symbol existing in **any** of its listed
# paths, so a probe for one has to remove it from all of them — half a removal proves
# nothing, and the probe run learned that the hard way.
PROBES = [
    ('P-32', 'a projection read force-unwrapped', [
        ('lib/screens/detail_screen.dart',
         "final hist = state.historyOf(trackerId);",
         "final hist = state.history['water']!;"),
    ]),
    ('P-33', 'a series read with no emptiness guard', [
        ('lib/widgets/tracker_card.dart',
         "final v = values.isEmpty ? 0.0 : values.last;",
         "final v = values.last;"),
    ]),
    ('P-34', 'a control dispatching to an unrelated tab', [
        ('lib/screens/trackers_screen.dart',
         "onTap: () => openGoalsSheet(context),",
         "onTap: () => context.read<AppState>().setTab(3),"),
    ]),
    ('P-35', 'a control dispatching to an unrelated tab', [
        ('lib/screens/settings_screen.dart',
         "onTap: () => openGoalSheet(context, t),",
         "onTap: () => state.setTab(2),"),
    ]),
    ('P-36', 'a sheet closed before its write', [
        ('lib/screens/log_sheets.dart',
         "      if (!write()) {\n        showTrackToast(context, 'Nothing was saved — that value was refused.');",
         "      Navigator.of(context).pop();\n      state.log('water', 1);\n      if (!write()) {\n        showTrackToast(context, 'Nothing was saved — that value was refused.');"),
    ]),
    # A renamed symbol still contains the old name, and `writeFailure` also survives
    # inside its own documentation — so these probes replace *every* occurrence by word
    # boundary. "Removed" has to mean removed, or the probe proves nothing.
    ('P-37', 'the failed-write surface removed', [
        ('re', 'lib/state/app_state.dart', r'\bwriteFailure\b', 'lastWriteProblem'),
        ('re', 'lib/screens/home_shell.dart', r'\bwriteFailure\b', 'lastWriteProblem'),
    ]),
    ('P-38', 'the double-submit guard removed', [
        ('lib/widgets/glass.dart', 'class SubmitOnce extends StatefulWidget {', 'class SubmitTwice extends StatefulWidget {'),
    ]),
    ('P-39', 'the day-edit path removed', [
        ('re', 'lib/state/app_state.dart', r'\bsetDayValue\b', 'applyDayValue'),
    ]),
    ('P-40', 'the day-delete path removed', [
        ('re', 'lib/state/app_state.dart', r'\bclearDay\b', 'removeDayRecord'),
    ]),
    ('P-41', 'history read from the projection again', [
        ('re', 'lib/state/app_state.dart', r'\brecordedDays\b', 'historyRows'),
        ('re', 'lib/screens/detail_screen.dart', r'\brecordedDays\b', 'historyRows'),
    ]),
    ('P-43', 'a wipe that leaves the routines behind', [
        ('lib/state/app_state.dart',
         "    removed.addAll(await commitmentRepo.deleteAllUserData());",
         "    // this mutation leaves every routine in place"),
    ]),
    ('P-44', 'a wipe that cannot report its counts', [
        ('lib/state/app_state.dart',
         "  Future<Map<String, int>> reset() async {",
         "  Future<void> reset() async {"),
    ]),
    ('P-45', 'the routine tables dropped from the wipe', [
        ('lib/data/db/database.dart',
         "      removed['routine_days'] = await delete(commitmentEntries).go();",
         "      // this mutation leaves the routine day rows in place"),
    ]),
    ('P-42', 'a duplicate top-level declaration', [
        ('lib/util/format.dart',
         'String fmtValue(Tracker t, double v) {',
         'int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;  // duplicate\n\nString fmtValue(Tracker t, double v) {'),
    ]),

    # ---------------------------------------------------------------------------
    # Probes for the checks authored in the 2026-10-17 audit (the gate had gone
    # missing entirely, so nothing in it was probed). Same rule as above: an edit
    # has to make the *named* defect real, in a file the check actually reads.
    # Where a rule spans two files, the probe edits both.
    # ---------------------------------------------------------------------------
    ('P-01', 'a demo seeder reachable from the start-up path', [
        ('lib/main.dart', '  runApp(TrackApp(state: state));',
         '  await seedDemoIfEmpty();\n  runApp(TrackApp(state: state));'),
    ]),
    ('P-02', 'a test fixture imported by app code', [
        ('lib/data/entry_repository.dart', "import 'dart:convert';",
         "import 'dart:convert';\nimport '../../test/fixtures/seed_rows.dart';"),
    ]),
    ('P-03', 'a fabricated headline number in shipped copy', [
        ('lib/screens/settings_screen.dart', "                'Diagnostics',", "                '1,284 entries',"),
    ]),
    ('P-04', 'a placeholder legal URL compiled in', [
        ('lib/screens/settings_screen.dart', "                'Diagnostics',", "                'https://track.app/terms',"),
    ]),
    ('P-05', 'an unfinished-work marker in shipped code', [
        ('lib/util/format.dart', 'String fmtValue(Tracker t, double v) {',
         '// TODO: ship it\nString fmtValue(Tracker t, double v) {'),
    ]),
    ('P-06', 'the provenance label removed', [
        ('re', 'lib/data/db/database.dart', r"'Sample data \(not yours\)'", "'Imported'"),
    ]),
    ('P-07', 'a signing password written into the build file', [
        ('android/app/build.gradle.kts',
         'storePassword = keystoreProperties["storePassword"] as String',
         'storePassword = "hunter2"'),
    ]),
    ('P-08', 'the unsigned-build fallback removed', [
        ('re', 'android/app/build.gradle.kts', r'signingConfigs\.getByName\("debug"\)',
         'signingConfigs.getByName("release")'),
    ]),
    ('P-09', 'cloud backup re-enabled for the database', [
        ('android/app/src/main/AndroidManifest.xml', 'android:allowBackup="false"', 'android:allowBackup="true"'),
    ]),
    ('P-10', 'an unverified entitlement treated as Pro', [
        ('lib/config/pro_config.dart', 'if (!verified) return false;', 'if (!verified) return true;'),
    ]),
    ('P-11', 'a provisional entitlement not marked pending', [
        ('re', 'lib/config/pro_config.dart', r'\bpending: true,', 'pending: false,'),
    ]),
    ('P-12', 'a verifier wired with no backend decision', [
        ('re', 'lib/main.dart', r'AppEnvironment\.hasVerifyBackend', 'true'),
        ('re', 'lib/main.dart', r'AppEnvironment\.validate\(\)', 'const <String>[]'),
        ('re', 'test/app_environment_test.dart', r'AppEnvironment\.assertNotMisconfigured\(\);', '// removed'),
    ]),
    ('P-13', 'verification ordered before the purchase is acknowledged', [
        ('re', 'lib/services/billing_service.dart', r'await _verify\(productId:', 'await _verifyRenamed(productId:'),
    ]),
    ('P-14', 'a purchase token handed to analytics', [
        ('lib/services/billing_service.dart',
         "_analytics?.log('purchase_started', {'plan': plan.id, 'trigger': environmentLabel});",
         "_analytics?.log('purchase_started', {'plan': plan.id, 'purchaseToken': token});"),
    ]),
    ('P-15', 'a second declaration of the verifier seam', [
        ('lib/services/billing_service.dart', 'abstract class PurchaseVerifier {',
         'abstract class PurchaseVerifier {\n  Future<bool> legacy(String productId, String token, String signature);\n}\n\nabstract class PurchaseVerifier {'),
    ]),
    ('P-16', 'product ids matched by substring', [
        ('lib/config/pro_config.dart', '      if (p.id == productId) return p;',
         "      if (productId.contains('lifetime') && p.kind == PlanKind.lifetime) return p;"),
    ]),
    ('P-17', 'a refund promise the app does not grant', [
        ('lib/config/pro_config.dart', "    return 'Free today \u00b7 cancel anytime",
         "    return '14-day no-questions refunds. Free today \u00b7 cancel anytime"),
    ]),
    ('P-18', 'a manifest component with no class behind it', [
        ('re', 'android/app/src/main/kotlin/com/track/app/TrackWidget.kt',
         r'\bclass TrackWidgetReceiver ', 'class WidgetReceiverRenamed '),
    ]),
    ('P-19', 'a channel name only one side knows', [
        ('re', 'lib/services/haptics.dart', r"MethodChannel\('track/haptics'\)", "MethodChannel('track/haptics.v2')"),
    ]),
    ('P-20', 'a dynamic dependency version', [
        ('re', 'android/app/build.gradle.kts',
         r'implementation\("androidx\.glance:glance-appwidget:1\.1\.1"\)',
         'implementation("androidx.glance:glance-appwidget:1.+")'),
    ]),
    ('P-21', 'a keep rule R8 needs removed', [
        ('re', 'android/app/proguard-rules.pro',
         r'-keep class com\.track\.app\.TrackWidgetReceiver \{ \*; \}',
         '# rule removed during a tidy-up'),
    ]),
    ('P-22', 'a Glance artifact used but not declared', [
        ('re', 'android/app/build.gradle.kts',
         r'implementation\("androidx\.glance:glance-appwidget:1\.1\.1"\)',
         '// glance-appwidget arrives transitively from the Flutter plugin'),
    ]),
    ('P-23', 'an AppState constructed outside the provider', [
        ('re', 'lib/screens/today_screen.dart', r'context\.read<AppState>\(\)', 'AppState()'),
    ]),
    ('P-24', 'a listener with nothing removing it', [
        ('re', 'lib/state/app_state.dart', r'\n    billing\?\.removeListener\(_onBillingChanged\);', ''),
    ]),
    ('P-25', 'dispose removed from a class that subscribes', [
        ('re', 'lib/state/app_state.dart', r'\n  void dispose\(\) \{', '\n  void disposeNotNeeded() {'),
    ]),
    ('P-26', 'reminders synced before the notifier is alive', [
        ('lib/main.dart', '  await notifications.init();\n  await state.load();',
         '  await state.load();\n  await notifications.init();'),
    ]),
    ('P-27', 'a day window computed from 24-hour blocks', [
        ('re', 'lib/data/db/database.dart', r'\[for \(var i = days - 1; i >= 0; i--\) dayKeyFromToday\(i\)\]',
         '[for (var i = days - 1; i >= 0; i--) dayKey(DateTime.now().subtract(Duration(days: i)))]'),
    ]),
    ('P-28', 'a collection extension with no import', [
        ('re', 'lib/data/focus_repository.dart',
         r'final existing = existingMatches\.isEmpty \? null : existingMatches\.first;',
         'final existing = existingMatches.firstOrNull;'),
    ]),
    ('P-29', 'a session that never asked to block reported as failed enforcement', [
        ('re', 'lib/data/focus_engine.dart',
         r'\n    if \(!blockingRequested\) return FocusEnforcement\.timerOnly;', ''),
    ]),
    ('P-30', 'an outcome the store decided for itself', [
        ('re', 'lib/data/focus_repository.dart', r'\n      outcome: outcome,', '\n      outcome: FocusOutcome.completed,'),
    ]),
    ('P-31', 'the notification tap payload left unconsumed', [
        ('re', 'lib/screens/home_shell.dart', r'\bpendingNotificationPayload\b', 'lastTapPayload'),
    ]),
    ('P-46', 'a negative delta refused by the value validator', [
        ('lib/state/app_state.dart',
         '    final safeTotal = ValueValidation.sanitize(id, previous + delta);',
         '    final safeDelta = ValueValidation.sanitize(id, delta);\n'
         '    final safeTotal = ValueValidation.sanitize(id, previous + delta);'),
    ]),
    ('P-47', 'a write path that cannot report failure', [
        ('lib/state/app_state.dart', '  bool addExpense(double amount, String category) {',
         '  void addExpense(double amount, String category) {'),
    ]),
    ('P-48', 'a second owner for a shared metric', [
        ('lib/data/db/database.dart',
         '  Future<List<double>> series(String trackerId, {int days = 28, String? source}) async {',
         '  Future<double> averageOfLast(String trackerId, int n) async => 0;\n\n'
         '  Future<List<double>> series(String trackerId, {int days = 28, String? source}) async {'),
    ]),
    ('P-49', 'a panel that reads without ever loading', [
        ('re', 'lib/screens/detail_screen.dart', r'_load\(\) => widget\.state\.refreshRhythm\(',
         '_load() => widget.state.refreshBuckets('),
    ]),
    ('P-50', 'minutes split from an unrounded value', [
        ('re', 'lib/util/format.dart', r'final total = v\.round\(\);', 'final total = v;'),
    ]),
    ('P-51', 'a prediction from an unusable sample', [
        ('lib/data/cycle_stats.dart',
         '  bool get hasPrediction => starts.length >= 2 && shortestLength > 0;',
         '  bool get hasPrediction => starts.length >= 2;'),
    ]),
]


def run_gate() -> tuple[int, str]:
    result = subprocess.run([sys.executable, GATE], capture_output=True, text=True, cwd=ROOT)
    return result.returncode, result.stdout + result.stderr


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('ids', nargs='*', help='probe ids to run (default: all)')
    args = ap.parse_args()
    wanted = set(args.ids)

    failures = []
    for check_id, description, raw_edits in PROBES:
        # ('file', find, replace) means a plain-text edit; ('re', ...) means a regex one.
        edits = [e if len(e) == 4 else ('text',) + e for e in raw_edits]
        if wanted and check_id not in wanted:
            continue
        originals = {}
        anchors_ok = True
        for edit in edits:
            mode, rel, find, _replace = edit
            path = os.path.join(APP, rel)
            text = open(path, encoding='utf-8').read()
            hits = len(re.findall(find, text)) if mode == 're' else text.count(find)
            # A plain anchor must be unique (so exactly this defect is made real); a
            # regex edit must simply match something.
            if hits == 0 or (mode != 're' and hits != 1):
                failures.append(f'{check_id}: anchor matches {hits}x in {rel} '
                                f'(the probe must be able to make exactly this defect real)')
                anchors_ok = False
            originals[path] = text
        if not anchors_ok:
            print(f'  {check_id}  ANCHOR MISS  ({description})')
            continue
        try:
            for mode, rel, find, replace in edits:
                path = os.path.join(APP, rel)
                text = originals[path]
                broken = re.sub(find, replace, text) if mode == 're' else text.replace(find, replace)
                open(path, 'w', encoding='utf-8').write(broken)
            code, output = run_gate()
            if check_id in output and code == 1:
                print(f'  {check_id}  fires  ({description})')
            else:
                failures.append(f'{check_id}: gate did not report it (exit={code})')
                print(f'  {check_id}  DID NOT FIRE  ({description})')
                print('    ' + output.strip().replace('\n', '\n    ')[:400])
        finally:
            for path, text in originals.items():
                open(path, 'w', encoding='utf-8').write(text)
                if open(path, encoding='utf-8').read() != text:
                    failures.append(f'{check_id}: {path} was NOT restored')

    code, output = run_gate()
    if code != 0:
        failures.append(f'the gate is not clean after restore:\n{output}')

    print()
    if failures:
        print(f'gate probe: {len(failures)} problem(s)')
        for f in failures:
            print(f'  FAIL  {f}')
        return 1
    print('gate probe: every probed check fired, and the tree is clean again')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
