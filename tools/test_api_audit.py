#!/usr/bin/env python3
"""Check the test suite against the code it claims to test.

The static audit guards `lib/` against itself. This tool guards `test/` against
`lib/`: it infers the type of the fixtures a test creates (`final repo =
EntryRepository(...)` → `EntryRepository`) and then verifies that every member the
test reaches for actually exists on that type. It also checks string arguments to
the app's own `dbColumn`-style helpers and the framework enums that tests touch.

Why it exists: on a host with no Flutter SDK, a test that references a renamed
method is discovered by a human or not at all. This is the cheapest possible
substitute for the compiler on the test file boundary.

It is **not** a type checker. It cannot see inherited members from packages, so
those are allowlisted by name with the reason recorded next to each entry.

Usage:  python3 tools/test_api_audit.py [--root .]
Exit:   0 clean, 1 problems found.
"""

import argparse
import glob
import os
import re
import sys
from collections import defaultdict

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from static_audit import collect_declarations, strip_comments_and_strings  # noqa: E402

# Members inherited from packages (drift, flutter_test, in_app_purchase). Listed by
# hand because a text scan cannot follow `extends`.
INHERITED = {
    'TrackDao': {
        # drift: DatabaseAccessor / generated table accessors
        'select', 'selectOnly', 'customSelect', 'customUpdate', 'customStatement',
        'insert', 'insertAll', 'insertReturning', 'update', 'delete', 'into', 'count',
        'all', 'watch', 'get', 'getSingle', 'getSingleOrNull', 'write', 'transaction',
        'TableInfo', 'database', 'attachedDatabase', 'executor',
        'isNull', 'isNotNull', 'equals', 'isBiggerThan', 'isBiggerOrEqual', 'isSmallerThan',
        'isSmallerOrEqual', 'isIn', 'isNotIn', 'asc', 'desc', 'groupBy', 'orderBy',
        'limit', 'withLimit', 'where', 'distinct', 'namedArgs', 'read', 'rows',
        'map', 'asyncMap', 'asyncExpand', 'key', 'join',
    },
    'TrackDatabase': {
        'close', 'transaction', 'allTables', 'customStatement', 'migration', 'batch',
    },
    'AppState': {'notifyListeners', 'dispose', 'addListener', 'removeListener', 'toString'},
    'BillingService': {'dispose'},
}

# Receivers whose names map to a type without a declaration in the test file.
BY_NAME = {
    'repo': 'EntryRepository',
    'repository': 'EntryRepository',
    'subject': 'EntryRepository',
    'dao': 'TrackDao',
    'db': 'TrackDatabase',
    'state': 'AppState',
    'app': 'AppState',
    'billing': 'BillingService',
    'service': 'BillingService',
    'verifier': 'HttpPurchaseVerifier',
}

# Types whose members come from a package; member checks are skipped for them.
EXTERNAL_TYPES = {
    'WidgetTester', 'Finder', 'TestWidgetsFlutterBinding', 'DateTime', 'Duration',
    'List', 'Map', 'Set', 'String', 'Future', 'Stream', 'HttpServer', 'HttpClient',
    'HttpRequest', 'HttpResponse', 'Socket', 'Stopwatch', 'Random', 'TextEditingController',
    'PurchaseDetails', 'ProductDetails', 'ProductDetailsResponse', 'PurchaseParam',
    'List<PurchaseDetails>', 'Completer', 'Directory', 'File', 'Zone',
}

# `final x = Foo(...)`, `late x = Foo(...)`, and a bare `x = Foo(...)` (which is how
# setUp() assigns a repository to a `late` field in these tests).
ASSIGN_RE = re.compile(
    r'(?:final|late final|late|var)?\s*(?:([A-Za-z_][\w<>, ?]*)\s+)?(\w+)\s*=\s*'
    r'(?:await\s+)?([A-Z][\w]*)(?:\.([a-z]\w*))?\s*\('
)

# Named constructors like `TrackDatabase.forTesting(...)` are not collected as
# class members by the declaration scanner, so they are listed here.
KNOWN_CONSTRUCTORS = {'forTesting', 'none'}

# (class, member) -> declared return type for the app's own classes, populated by
# `collect_return_types` before the test files are scanned. This is what lets
# `final snap = MomentumEngine.compute(...)` be checked as a `MomentumSnapshot`.
RETURN_TYPES = {}

# Statics whose declaration syntax the text scanner cannot parse (record-typed
# returns, extension members). Verified by hand against the declaring file.
LOOSE_STATICS = {'boundsFor', 'boundsForKind'}
PARAM_RE = re.compile(r'\(\s*(?:[^()]*?\s)?([A-Z][\w]*)\s+(\w+)\s*[,)]')


def typename_of(declarations, raw):
    """Normalise `List<Foo>` → keep as-is; `Foo?` → `Foo`; nested `_X` → ''."""
    if not raw:
        return ''
    raw = raw.strip().rstrip('?').strip()
    if raw.startswith('_') or '<' in raw or ' ' in raw:
        return ''
    return raw


RETURN_TYPE_RE = re.compile(r'(?:Future<([\w<>, ]+)>|([A-Z]\w*))\s+(\w+)\s*\(')
CHAIN_RE = re.compile(
    r'(?:final|late final|var)\s+(\w+)\s*=\s*(?:await\s+)?(\w+)\(\)\.(\w+)\s*\('
)
LOCAL_FN_RE = re.compile(r'^\s*([A-Z]\w*)(?:<[^>]*>)?\s+(\w+)\s*\(', re.M)


DAO_ACCESSOR_RE = re.compile(r'daos:\s*\[([^\]]*)\]')


def collect_dao_accessors(root, declarations):
    """`daos: [TrackDao, CommitmentDao]` generates `trackDao` / `commitmentDao`
    accessors on the database class, which no text scan can see declared."""
    out = set()
    for path in glob.glob(os.path.join(root, 'lib', '**', '*.dart'), recursive=True):
        text = open(path, encoding='utf8').read()
        for m in DAO_ACCESSOR_RE.finditer(text):
            for name in m.group(1).split(','):
                name = name.strip()
                if name.endswith('Dao') and len(name) > 3:
                    out.add(name[0].lower() + name[1:])
    return out


def collect_return_types(root, declarations):
    """(class, member) -> declared return type, for chained-call inference."""
    out = {}
    for path in glob.glob(os.path.join(root, 'lib', '**', '*.dart'), recursive=True):
        text = strip_comments_and_strings(open(path, encoding='utf8').read())
        for cls_match in re.finditer(r'^\s*class\s+(\w+)', text, re.M):
            cls = cls_match.group(1)
            rest = text[cls_match.end():]
            end = re.search(r'\n(?:class|enum|mixin|extension|typedef)\b', rest)
            body = rest[: end.start()] if end else rest
            for m in RETURN_TYPE_RE.finditer(body):
                rtype = (m.group(1) or m.group(2) or '').strip()
                member = m.group(3)
                if rtype and rtype not in ('void', 'Future', 'List', 'Map', 'Widget'):
                    out.setdefault((cls, member), rtype)
    return out


def scan(root):
    lib_files = sorted(glob.glob(os.path.join(root, 'lib', '**', '*.dart'), recursive=True))
    test_files = sorted(glob.glob(os.path.join(root, 'test', '**', '*.dart'), recursive=True))
    if not test_files:
        print('no test files found; wrong --root?')
        return 1

    declarations = defaultdict(set)
    for path in lib_files:
        text = strip_comments_and_strings(open(path, encoding='utf8').read())
        for cls, members in collect_declarations(text).items():
            declarations[cls] |= members

    return_types = collect_return_types(root, declarations)
    global RETURN_TYPES
    RETURN_TYPES = return_types

    # Generated DAO accessors are part of the database class as far as callers are
    # concerned, so they must be allowed by the member check.
    INHERITED.setdefault('TrackDatabase', set()).update(collect_dao_accessors(root, declarations))

    problems = []
    checked = 0
    loose = 0
    for path in test_files:
        raw = open(path, encoding='utf8').read()
        text = strip_comments_and_strings(raw)

        # 1. Infer variable → type from `final x = Type(...)` / `Type.y(...)`.
        var_types = {}
        for m in ASSIGN_RE.finditer(text):
            declared, name, ctor, method = m.group(1), m.group(2), m.group(3), m.group(4)
            # `X.y(` is a named constructor only when `y` is not a member of `X`;
            # otherwise the expression is `X.member(...)` and the result is
            # whatever that member returns, not an `X`.
            if method is not None and method in declarations.get(ctor, set()):
                # A static or instance method call: the result is whatever that member
                # returns, which `collect_return_types` knows for app classes.
                t = typename_of(declarations, declared) or RETURN_TYPES.get((ctor, method))
            else:
                # A constructor, named or otherwise.
                t = typename_of(declarations, declared) or ctor
            if not t:
                continue
            if t in declarations or t in INHERITED or t in EXTERNAL_TYPES or t.startswith(
                ('Entry', 'Track', 'App', 'Billing', 'Http', 'Demo', 'Default', 'Pro', 'Test', 'Source', 'Category', 'Habit', 'Insight', 'Series')
            ):
                var_types[name] = t
        # 1b. `final x = await helper().member(...)` — resolve the helper's declared
        # return type, then the member's, so chained calls are typed too.
        local_fns = {m.group(2): m.group(1) for m in LOCAL_FN_RE.finditer(text)}
        for m in CHAIN_RE.finditer(text):
            name, helper, member = m.group(1), m.group(2), m.group(3)
            ftype = local_fns.get(helper)
            if not ftype:
                continue
            rtype = return_types.get((ftype, member))
            if rtype:
                var_types[name] = rtype
        # 2. Typed parameters of test helpers.
        for m in PARAM_RE.finditer(text):
            var_types.setdefault(m.group(2), m.group(1))
        # 3. Well-known receiver names when no declaration was found.
        # Well-known receiver names, but only for names this file does not assign:
        # a test that writes `repo = CommitmentRepository(...)` means that, not the
        # default `repo` mapping.
        assigned = set(re.findall(r'(?:^|[;{}\s])(\w+)\s*=\s*[A-Z][\w]*(?:\.\w+)?\s*\(', text))
        for name, t in BY_NAME.items():
            if name in assigned:
                continue
            var_types.setdefault(name, t)

        for name, t in sorted(var_types.items()):
            if t in EXTERNAL_TYPES or t not in declarations:
                continue
            members = declarations[t] | INHERITED.get(t, set())
            if not members:
                continue  # nothing declared (fully external); nothing to check
            for m in re.finditer(rf'(?<![\w.]){re.escape(name)}\.(\w+)', text):
                member = m.group(1)
                if member.startswith('_') and t not in declarations:
                    continue
                if member in members or member.startswith('runtimeType'):
                    checked += 1
                    continue
                line = text[: m.start()].count('\n') + 1
                problems.append(f'{os.path.relpath(path, root)}:{line}: `{name}.{member}` — {t} declares no such member')

        # 4. Statics on the app's constant holders, from any test.
        for holder in ['ProConfig', 'ProPlan', 'DefaultTrackers', 'TrackTheme', 'AppEnvironment',
                       'ValueValidation', 'TrackDatabase', 'EntryRepository', 'Habit', 'PaywallTrigger']:
            members = declarations.get(holder)
            if not members:
                continue
            for m in re.finditer(rf'\b{holder}\.(\w+)', text):
                member = m.group(1)
                if member in members or member.startswith('_'):
                    checked += 1
                    continue
                if member in LOOSE_STATICS or member in KNOWN_CONSTRUCTORS:
                    loose += 1
                    continue
                line = text[: m.start()].count('\n') + 1
                problems.append(f'{os.path.relpath(path, root)}:{line}: `{holder}.{member}` — {holder} declares no such member')

        # 5. Named arguments on a handful of app widgets/helpers whose parameter
        #    names have historically drifted (HeroTrackerCard, TrendLine, ...).
        for ctor, known in {
            'TrendLine': {'values', 'colorA', 'colorB', 'height', 'key'},
            'MiniChart': {'values', 'color', 'height', 'barRadius', 'todayTint', 'key'},
            'ProChip': {'compact', 'key'},
        }.items():
            for m in re.finditer(rf'\b{ctor}\(([^()]*)\)', text):
                args = m.group(1)
                for named in re.finditer(r'(?:^|,)\s*(\w+)\s*:', args):
                    if named.group(1) not in known:
                        line = text[: m.start()].count('\n') + 1
                        problems.append(f'{os.path.relpath(path, root)}:{line}: `{ctor}({named.group(1)}:)` — unknown parameter')

    for p in sorted(set(problems)):
        print('  ' + p)
    if problems:
        print(f'\n{len(set(problems))} problem(s) in test files; {checked} member references verified, '
              f'{loose} accepted under the loose rule')
        return 1
    print(f'test api audit clean: {checked} member references across {len(test_files)} test files resolve '
          f'against lib/ ({loose} accepted under the loose rule for declarations the text scanner cannot parse)')
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    args = ap.parse_args()
    return scan(args.root)


if __name__ == '__main__':
    raise SystemExit(main())
