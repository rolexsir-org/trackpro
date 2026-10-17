#!/usr/bin/env python3
"""A stand-in for the Dart analyzer, for environments where Flutter is unavailable.

This is **not** a type checker and must never be reported as one. It catches the
specific class of error that blind, toolchain-less editing produces: a caller
referencing a member, top-level function or class constant that the declaring file
does not define — i.e. the "it would not even compile" mistakes.

Usage:  python3 tools/static_audit.py [--root .]
Exit:   0 when clean, 1 when problems are found.
"""

import argparse
import glob
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Members provided by Flutter/third-party superclasses or generated code, which a
# text scan cannot see. Anything listed here is verified by hand instead.
KNOWN_INHERITED = {
    'AppState': {
        'notifyListeners', 'dispose', 'addListener', 'removeListener', 'toString',
    },
    'TrackDao': set(),
}
IGNORED_PREFIXES = ('_', 'this.', 'super.')


def dart_files(root):
    return sorted(glob.glob(os.path.join(root, 'lib', '**', '*.dart'), recursive=True))


# The stripper lives in its own module: the audits share it, and it has to
# understand nested interpolation (see tools/dart_source.py for why the regex
# version was wrong). Re-exported here so imports elsewhere keep working.
from dart_source import strip_comments_and_strings  # noqa: E402,F401


def collect_declarations(text):
    """Members declared in a class body, roughly by indentation."""
    out = defaultdict(set)
    class_re = re.compile(r'^\s*(?:abstract\s+)?class\s+(\w+)', re.M)
    for match in class_re.finditer(text):
        name = match.group(1)
        # Body = everything up to the next top-level `class`/`enum`/`mixin`.
        rest = text[match.end():]
        end = re.search(r'\n(?:class|enum|mixin|extension|typedef|final|void|Future)\b', rest)
        body = rest[: end.start()] if end else rest
        for decl in re.finditer(
            r'^\s{2}(?:@\w+\s+)*'
            r'(?:static\s+|final\s+|const\s+|late\s+|required\s+|covariant\s+)*'
            r'(?:[\w<>,\?\[\]\. ]+\s+)?'
            r'(get\s+)?(\w+)\s*(?:\(|=|;|\{)',
            body,
            re.M,
        ):
            out[name].add(decl.group(2))
    # Function-typed fields: `final Future<void> Function() onEnd;`. The general
    # member pattern cannot express a type containing parentheses, so a callback field
    # would otherwise read as an undeclared top-level call at every use site.
    for match in class_re.finditer(text):
        rest = text[match.end():]
        end = re.search(r'\n(?:class|enum|mixin|extension|typedef|final|void|Future)\b', rest)
        body = rest[: end.start()] if end else rest
        for decl in re.finditer(
            r'^\s{2}(?:@\w+\s+)*(?:static\s+|final\s+|const\s+|late\s+)*'
            r'[\w<>,\?\[\]\. ]*Function\([^)]*\)\s+(\w+)\s*(?:=|;)',
            body,
            re.M,
        ):
            out[match.group(1)].add(decl.group(1))

    # Class members whose return type is a record: `static ({A a, B b}) name(`.
    # The general member pattern above cannot express a type containing parentheses.
    for match in class_re.finditer(text):
        rest = text[match.end():]
        end = re.search(r'\n(?:class|enum|mixin|extension|typedef|final|void|Future)\b', rest)
        body = rest[: end.start()] if end else rest
        for decl in re.finditer(
            r'^\s{2}(?:@\w+\s+)*(?:static\s+|final\s+|const\s+|late\s+)*'
            r'\([^()]*\)\s+(\w+)\s*\(',
            body,
            re.M,
        ):
            out[match.group(1)].add(decl.group(1))

    # Top-level functions, classes, enums, typedefs and constants.
    for decl in re.finditer(r'^(?:class|enum|mixin|extension|typedef)\s+(\w+)', text, re.M):
        out['__top__'].add(decl.group(1))
    for decl in re.finditer(
        r'^(?:Future<[\w\?<>, ]+>|void|String|int|double|bool|DateTime|Duration|Set<[\w\?<>, ]+>|'
        r'List<[\w\?<>, ]+>|Map<[\w\?<>, ]+>|Iterable<[\w\?<>, ]+>|Widget|Color|Commitment|MomentumSnapshot|'
        r'RestartPlan|WeeklyReview|Improvement|CommitmentTemplate|Habit)\s+(\w+)\s*\(',
        text,
        re.M,
    ):
        out['__top__'].add(decl.group(1))
        out['__top__'].add(decl.group(1))
    # Generic top-level function declarations. A return type can nest parentheses
    # (`Future<({String? id, String label})?> pick(...)`), so the name is taken as the
    # last identifier followed by `(` on a line at column 0 that is not a type name.
    # Column 0 is this codebase's formatting contract for a declaration, and skipping
    # `final`/`const`/`late`/`var` lines keeps initialiser calls out of the set.
    type_words = {
        'Function', 'Future', 'List', 'Set', 'Map', 'Iterable', 'Duration', 'Widget',
        'Object', 'String', 'bool', 'int', 'double', 'void', 'if', 'for', 'while',
        'switch', 'return', 'case', 'assert', 'await', 'throw',
    }
    for line in text.split('\n'):
        if not line or line[0].isspace() or line.startswith(('final ', 'const ', 'late ', 'var ', 'import ')):
            continue
        names = [m.group(1) for m in re.finditer(r'([A-Za-z_]\w*)\s*\(', line) if m.group(1) not in type_words]
        if names:
            out['__top__'].add(names[-1])
    for decl in re.finditer(r'^(?:const|final)\s+[\w<>,\?\[\] ]+\s+(\w+)\s*=', text, re.M):
        out['__top__'].add(decl.group(1))
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = parser.parse_args()
    root = args.root

    files = dart_files(root)
    if not files:
        print('no Dart files found; wrong --root?')
        return 1

    declarations = defaultdict(set)
    texts = {}
    for path in files:
        text = strip_comments_and_strings(open(path, encoding='utf8').read())
        texts[path] = text
        for cls, members in collect_declarations(text).items():
            declarations[cls] |= members

    problems = []

    # 1. `state.<x>` on AppState (the app's most-used object).
    #
    # The receiver must be a bare identifier: `t.state.equals(...)` is a drift table
    # column and `native.state()` is a method call, and neither is AppState. Since the
    # check cannot see types, the contract is lexical — in `lib/`, `state` means
    # AppState. A local variable with that name anywhere in lib/ is therefore a false
    # positive by construction, so name it something else (`native`, `row`, `snap`).
    app_state_members = declarations.get('AppState', set()) | KNOWN_INHERITED['AppState']
    for path, text in texts.items():
        for match in re.finditer(r'(?<![\w.])state\.(\w+)', text):
            member = match.group(1)
            if member.startswith(IGNORED_PREFIXES):
                continue
            if member not in app_state_members:
                problems.append((path, f'state.{member}', 'AppState has no such member'))

    # 2. Static access on the app's own constant holders.
    for holder in ['TrackTheme', 'ProConfig', 'ProPlan', 'PaywallTrigger', 'DefaultTrackers',
                   'ValueValidation', 'TrackColors', 'MetricKind', 'Haptics', 'AppEnvironment',
                   'FocusEngine', 'FocusStats']:
        members = declarations.get(holder)
        if members is None:
            continue
        for path, text in texts.items():
            for match in re.finditer(rf'\b{holder}\.(\w+)', text):
                if match.group(1).startswith(IGNORED_PREFIXES):
                    continue
                if match.group(1) not in members:
                    problems.append((path, f'{holder}.{match.group(1)}', f'{holder} declares no such member'))

    # 3. Top-level function calls that look like app code but are declared nowhere.
    top = declarations.get('__top__', set())
    app_calls = set()
    for path, text in texts.items():
        for match in re.finditer(r'(?<![\w.])([a-z][A-Za-z0-9]{4,})\s*\(', text):
            app_calls.add(match.group(1))
    flutter_noise = {
        'print', 'debugPrint', 'require', 'assert', 'main', 'runApp', 'await', 'then',
        'forEach', 'where', 'map', 'reduce', 'firstWhere', 'sublist', 'clamp', 'abs',
        'tuples', 'first', 'last', 'indexWhere', 'any', 'every', 'contains', 'toList',
        'jsonEncode', 'jsonDecode', 'compute', 'unawaited', 'catchError', 'whenComplete',
        'toDouble', 'toInt', 'toString', 'padLeft', 'toStringAsFixed', 'round', 'floor',
        'ceil', 'replaceAll', 'split', 'join', 'trim', 'toLowerCase', 'toUpperCase',
        'startsWith', 'endsWith', 'indexOf', 'substring', 'addAll', 'removeWhere',
        'putIfAbsent', 'setState', 'getApplicationDocumentsDirectory', 'runZonedGuarded',
        'toIso8601String', 'parse', 'tryParse', 'fromJson', 'toJson', 'format', 'encode',
        'decode', 'now', 'of', 'maybeOf', 'iterable', 'schedule', 'cancel', 'resolve',
        'super', 'catch', 'catchError', 'when', 'switch',
        # Drift's generated column builders are injected by the code generator and
        # have no textual declaration anywhere in lib/.
        'integer', 'text', 'boolean', 'dateTime', 'real', 'blob', 'intEnum', 'references',
        'withDefault', 'generatedColumn', 'customSelect', 'selectOnly', 'select', 'update',
        'insert', 'delete', 'driftDatabase', 'driftDatabaseNative', 'table', 'columns',
        'mixin', 'uniqueKeys', 'check', 'index', 'defaultValue', 'customConstraint',
    }
    # Verified false positives: statics invoked unqualified from inside their own
    # class, and callbacks invoked through a field of the same widget.
    #   ValueValidation.boundsFor / .boundsForKind   (lib/data/value_validation.dart)
    #   Patterns.correlate                            (lib/data/insights_engine.dart)
    #   _CalorieBody.onFood / _MoodBody.onPick         (lib/screens/log_sheets.dart)
    #   combine  — the transformer passed into AppState.paired(a, b, n, combine)
    #   fromStorage — a static on the DayOutcomeText *extension*; extension members
    #                 have no class body for the declaration scanner to read, and
    #                 the hits are its own declaration line.
    VERIFIED_INTERNAL = {'boundsFor', 'boundsForKind', 'correlate', 'onFood', 'onPick', 'onRecheck', 'combine',
                         'fromStorage'}

    declared_calls = set(top)
    for members in declarations.values():
        declared_calls |= members
    suspicious = sorted(
        call for call in app_calls
        if call not in declared_calls
        and call not in VERIFIED_INTERNAL
        and call not in flutter_noise
        and not call.startswith('_')
    )
    if suspicious:
        problems.append(('<all-files>', 'undeclared top-level calls',
                         ', '.join(suspicious[:40])))

    if problems:
        print(f'{len(problems)} potential problem(s):\n')
        for path, what, why in problems:
            rel = os.path.relpath(path, root) if path.startswith(root) else path
            print(f'  {rel}: {what} — {why}')
        return 1

    print('static audit clean: no undeclared AppState members, no undeclared static '
          'constants, no undeclared top-level calls')
    return 0


if __name__ == '__main__':
    sys.exit(main())
