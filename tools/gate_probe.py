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
APP = os.path.dirname(HERE)
ROOT = os.path.dirname(APP)
GATE = os.path.join(ROOT, 'tools', 'release_gate.py')

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
