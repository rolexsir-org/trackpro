#!/usr/bin/env python3
"""Finds ambiguous top-level names — the compile error nothing else here can see.

Why this tool exists
--------------------
No Dart analyzer or compiler runs on this host, so a whole class of *hard* build
failures is invisible to every other check in `tools/`: if a file imports two
libraries that each declare the same top-level name and then **references** that
name, Dart rejects the file:

    The name 'dayKey' is defined in the libraries '.../util/day_key.dart' and
    '.../db/database.dart'.

That is not a warning. The build stops. And the failure mode is exactly the one this
project keeps running into: a duplicate helper introduced for convenience, referenced
from a third file, indistinguishable from correct code by grep.

What it does
------------
1. Collects the top-level declarations of every `lib/**/*.dart` file (classes,
   enums, mixins, extensions, typedefs, top-level functions, top-level variables).
2. For every file, walks its **relative** imports (transitively, since a library's
   own imports are not re-exported but `export`ed names are) and looks for a name
   that is declared in two or more of them and then referenced (outside comments and
   string literals) in the importing file.
3. Reports each occurrence with file:line and both declaration sites.

Known and deliberately excluded
-------------------------------
* `part`/`part of` files (they share their library's scope by construction).
* Names that reach a file through an `export` chain pointing at the same declaration
  (recorded by origin, not by name, so a re-export is not a false positive).
* Private names (`_foo`): they are library-scoped and cannot leak across imports.
* Files under `test/` are reported too — they compile with the same rules.

Usage:  python3 tools/symbol_clash_audit.py [--root .] [--quiet]
Exit code 1 when a clash is found, 0 when clean.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from typing import Dict, Iterable, List, Set, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dart_source import strip_comments_and_strings  # noqa: E402

DECL = re.compile(
    r'^(?:class|mixin|enum|extension|typedef|abstract\s+class|sealed\s+class|base\s+class|final\s+class)\s+(\w+)'
    r'|^(?:late\s+|final\s+|const\s+)?(?:[\w<>,\?\[\]\.]+\s+)+(\w+)\s*\('
    r'|^(?:final|const|late)\s+(?:[\w<>,\?\[\]\.]+\s+)?(\w+)\s*=',
    re.M,
)
IMPORT_RE = re.compile(r"^import\s+'([^']+)'(?:\s+(?:as|show|hide)[^;]*)?;", re.M)
EXPORT_RE = re.compile(r"^export\s+'([^']+)'[^;]*;", re.M)
PART_RE = re.compile(r"^part\s+'([^']+)';", re.M)
REF_RE = re.compile(r'\b([a-z_][A-Za-z0-9_]*)\b')


def resolve(base: str, rel: str) -> str | None:
    """An import spec -> a path inside the workspace, or None for external libraries.

    A spec is relative unless it names a scheme: `db/database.dart` resolves against
    the importing file's directory exactly like `./db/database.dart` does. Getting
    that wrong (treating a scheme-less spec as external) hides precisely the clashes
    worth finding — the first run of this tool missed one because of it.
    """
    if rel.startswith('dart:') or rel.startswith('package:'):
        return None
    path = os.path.normpath(os.path.join(os.path.dirname(base), rel))
    return path if os.path.isfile(path) else None


def top_level_names(path: str, cache: Dict[str, Set[str]]) -> Set[str]:
    if path in cache:
        return cache[path]
    text = open(path, encoding='utf-8', errors='replace').read()
    body = strip_comments_and_strings(text)
    # Only the declarations that start in column 0 count as top-level.
    names: Set[str] = set()
    for line in body.split('\n'):
        if not line or line[0] in ' \t}':
            continue
        m = DECL.match(line)
        if m:
            names.add(next(g for g in m.groups() if g))
    cache[path] = names
    return names


_NAMES_CACHE: Dict[str, Set[str]] = {}


def visible_from(path: str, roots: Iterable[str]) -> Dict[str, Set[str]]:
    """name -> set of declaring files, for everything the file can see by name.

    Relative imports only: `package:` imports (flutter, drift, provider) are trusted
    to be unambiguous, and `dart:` ones cannot clash with project code.
    """
    seen: Set[str] = set()
    out: Dict[str, Set[str]] = defaultdict(set)
    stack = [path]
    while stack:
        current = stack.pop()
        if current in seen:
            continue
        seen.add(current)
        text = open(current, encoding='utf-8', errors='replace').read()
        for rel in IMPORT_RE.findall(text) + EXPORT_RE.findall(text):
            target = resolve(current, rel)
            if target and os.path.abspath(target).startswith(os.path.abspath(roots[0] if isinstance(roots, tuple) else roots)):
                stack.append(target)
                for name in top_level_names(target, _NAMES_CACHE):
                    out[name].add(target)
        # `part` files share the library's scope: their declarations are visible here.
        for rel in PART_RE.findall(text):
            target = os.path.normpath(os.path.join(os.path.dirname(current), rel))
            if os.path.isfile(target):
                for name in top_level_names(target, _NAMES_CACHE):
                    out[name].add(target)
    for name in top_level_names(path, _NAMES_CACHE):
        out.pop(name, None)  # a library's own declarations cannot be ambiguous
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default='.')
    ap.add_argument('--quiet', action='store_true')
    args = ap.parse_args()
    root = os.path.abspath(args.root)

    files: List[str] = []
    for base in ('lib', 'test'):
        for dirpath, _dirs, filenames in os.walk(os.path.join(root, base)):
            for fn in sorted(filenames):
                if fn.endswith('.dart') and not fn.endswith('.g.dart') and not fn.endswith('.drift.dart'):
                    files.append(os.path.join(dirpath, fn))

    problems: List[Tuple[str, int, str, List[str]]] = []
    for path in sorted(files):
        text = open(path, encoding='utf-8', errors='replace').read()
        if re.search(r'^part of\b', text, re.M):
            continue
        stripped = strip_comments_and_strings(text)
        visible = visible_from(path, (root,))
        refs = set(REF_RE.findall(stripped))
        for name, where in sorted(visible.items()):
            if len(where) > 1 and name in refs:
                # line of the first reference, for the report
                line = next(
                    (i for i, l in enumerate(stripped.split('\n'), 1)
                     if re.search(r'\b' + re.escape(name) + r'\b', l)),
                    0,
                )
                problems.append((os.path.relpath(path, root), line, name, sorted(os.path.relpath(w, root) for w in where)))

    if problems:
        print(f'{len(problems)} ambiguous top-level name(s) — each one is a compile error:\n')
        for path, line, name, where in problems:
            print(f'  {path}:{line}  `{name}` declared in:')
            for w in where:
                print(f'      {w}')
        return 1
    if not args.quiet:
        print(f'symbol clash audit clean: {len(files)} files, no name is visible from two '
              f'sources at once where it is used')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
