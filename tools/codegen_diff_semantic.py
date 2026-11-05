#!/usr/bin/env python3
"""Is the regenerated `database.g.dart` a real change, or just the formatter?

The `drift codegen fresh` gate in `tools/run_gates.sh` fails whenever a rebuild
edits the committed generated file. That failure has two very different causes:

  1. A schema change — you edited a table, so the generator emitted new columns.
     You must review the diff and commit it deliberately.
  2. A formatter migration — the Dart SDK's `dart format` changed style (the
     3.7 "tall style" reflow is why this gate went red on 2026-11-05), so the
     generator re-emitted identical code laid out differently. Committing it is
     mechanical and safe.

The gate cannot tell them apart; a human scrolling a 12,000-line diff cannot
either. This tool can. It compares the committed file against the working-tree
file after collapsing the two things a reformatter is allowed to change — all
whitespace, and a trailing comma before a closing bracket — and separately
compares the multiset of string literals, which is where SQL and column names
live and which whitespace-stripping alone would blind us to.

Exit 0 = formatting only, safe to commit. Exit 1 = a semantic change, read it.

Usage:
    python3 tools/codegen_diff_semantic.py                 # HEAD vs working tree
    python3 tools/codegen_diff_semantic.py --ref main      # compare against main
    python3 tools/codegen_diff_semantic.py --path some/other.g.dart

Self-check: `--self-test` runs the two controls this logic was validated with
(a genuine reflow must pass, a renamed column must fail) and needs no repo state.
"""
import argparse
from collections import Counter
import os
import re
import subprocess
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

WHITESPACE = re.compile(r'\s+')
# A comma immediately before a closing bracket is a trailing comma. `dart format`
# adds one to every exploded argument list, so it carries no meaning here. `>` is
# in the class because tall style explodes generic type-argument lists too, and
# the regenerated file is full of `RootTableManager<...>` and `typedef`s.
TRAILING_COMMA = re.compile(r',([)}\]>])')
STRING_LITERAL = re.compile(r"'(?:[^'\\]|\\.)*'")


def normalize(text):
    """Collapse everything a reformatter may change, keep everything it may not."""
    return TRAILING_COMMA.sub(r'\1', WHITESPACE.sub('', text))


def literals(text):
    """Sorted list of string literals, so SQL and column names are compared too."""
    return sorted(STRING_LITERAL.findall(text))


def read_ref(ref, path):
    out = subprocess.run(['git', 'show', f'{ref}:{path}'],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit(f'error: cannot read {path} at {ref}: {out.stderr.strip()}')
    return out.stdout


def read_worktree(path):
    if not os.path.exists(path):
        sys.exit(f'error: {path} does not exist in the working tree')
    with open(path) as handle:
        return handle.read()


def compare(old, new, path, ref, quiet=False):
    """Returns True when the only differences are formatting."""
    say = (lambda *a: None) if quiet else print
    clean = True

    say(f'check 1/2  whitespace + trailing commas, {path} vs {ref}')
    old_norm, new_norm = normalize(old), normalize(new)
    if old_norm == new_norm:
        say(f'  identical ({len(new_norm)} significant characters)')
    else:
        clean = False
        at = next(i for i in range(min(len(old_norm), len(new_norm)))
                  if old_norm[i] != new_norm[i])
        say(f'  DIFFERS at significant character {at}')
        say(f'    {ref}: ...{old_norm[max(0, at - 60):at + 60]}...')
        say(f'    work: ...{new_norm[max(0, at - 60):at + 60]}...')

    say('check 2/2  multiset of string literals (SQL, column names, table names)')
    old_lit, new_lit = literals(old), literals(new)
    if old_lit == new_lit:
        say(f'  identical ({len(new_lit)} literals)')
    else:
        clean = False
        # Multiset difference, so a column appearing 13 times reports once with
        # its count instead of printing the same line thirteen times.
        removed = Counter(old_lit) - Counter(new_lit)
        added = Counter(new_lit) - Counter(old_lit)
        say(f'  DIFFERS: -{sum(removed.values())} +{sum(added.values())} '
            f'across {len(removed) + len(added)} distinct literals')
        for item, count in list(removed.items())[:10]:
            say(f'    - {item}' + (f'  (x{count})' if count > 1 else ''))
        for item, count in list(added.items())[:10]:
            say(f'    + {item}' + (f'  (x{count})' if count > 1 else ''))

    return clean


def self_test():
    """The two controls this logic was validated against."""
    short = """  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
      'emoji', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
"""
    tall = """  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
"""
    renamed = short.replace("'emoji'", "'emojiRenamed'")
    # A trailing comma is not the only thing the formatter touches: an exploded
    # list of type arguments reflows too. That must also read as formatting.
    short_generic = 'typedef M = RootTableManager<A, B, C, (D, E), F>;\n'
    tall_generic = 'typedef M = RootTableManager<\n  A,\n  B,\n  C,\n  (D, E),\n  F\n>;\n'
    # `]` has to be in the trailing-comma class or an exploded `$columns` list
    # reads as a semantic change. Pinned here because it is easy to lose.
    short_list = 'List<GeneratedColumn> get $columns => [id, name, sort];\n'
    tall_list = 'List<GeneratedColumn> get $columns => [\n  id,\n  name,\n  sort,\n];\n'

    failures = []
    for name, old, new, expect_clean in (
        ('tall-style reflow', short, tall, True),
        ('exploded type arguments', short_generic, tall_generic, True),
        ('exploded list literal', short_list, tall_list, True),
        ('renamed column', short, renamed, False),
    ):
        got = compare(old, new, 'fixture', 'HEAD', quiet=True)
        ok = got is expect_clean
        print(f'  {"ok  " if ok else "FAIL"} {name}: '
              f'{"formatting-only" if got else "semantic change"}')
        if not ok:
            failures.append(name)
    return not failures


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('--path', default='lib/data/db/database.g.dart')
    parser.add_argument('--ref', default='HEAD')
    parser.add_argument('--self-test', action='store_true',
                        help='run the validation controls and exit')
    args = parser.parse_args()

    if args.self_test:
        print('self-test:')
        return 0 if self_test() else 1

    old = read_ref(args.ref, args.path)
    new = read_worktree(args.path)
    if old == new:
        print(f'{args.path} is unchanged from {args.ref}.')
        return 0

    clean = compare(old, new, args.path, args.ref)
    print()
    if clean:
        print(f'VERDICT: formatting only. Safe to commit:\n'
              f'  git add {args.path} && git commit')
        return 0
    print(f'VERDICT: semantic change in {args.path}. Review the diff before '
          f'committing; this is not a formatter reflow.')
    return 1


if __name__ == '__main__':
    sys.exit(main())
