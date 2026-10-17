#!/usr/bin/env python3
"""Import resolution + package declaration check.

Verifies that (a) every relative import in lib/ and test/ resolves to a file that
exists, and (b) every `package:` import is declared in pubspec.yaml. This catches
the exact failure mode of editing without a compiler: an import left pointing at
a deleted file.

Exit 0 when clean, 1 when something is missing.
"""
import glob
import os
import re
import sys

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(root)

pubspec = open('pubspec.yaml').read()
declared = set(re.findall(r'^\s{2}([a-z0-9_]+):', pubspec, re.M))
self_name = re.search(r'^name:\s*(\S+)', pubspec, re.M).group(1)

missing = []
undeclared = {}
for path in sorted(glob.glob('lib/**/*.dart', recursive=True)) + sorted(glob.glob('test/**/*.dart', recursive=True)):
    src = open(path).read()
    for match in re.finditer(r"import\s+'([^']+)'", src):
        target = match.group(1)
        if target.startswith('package:'):
            name = target.split('/')[0].replace('package:', '')
            if name != self_name and name not in declared:
                undeclared.setdefault(name, set()).add(path)
            continue
        if target.startswith('dart:'):
            continue
        resolved = os.path.normpath(os.path.join(os.path.dirname(path), target))
        if not os.path.exists(resolved):
            missing.append((path, target, resolved))

if missing:
    print('BROKEN IMPORTS:')
    for path, target, resolved in missing:
        print(f'  {path} -> {target}   (resolved: {resolved})')
if undeclared:
    print('PACKAGE IMPORTS NOT IN pubspec.yaml:')
    for name, users in sorted(undeclared.items()):
        print(f'  {name}: {sorted(users)}')
if not missing and not undeclared:
    print(f'imports clean: every relative import resolves, every package import is declared ({len(declared)} deps)')
    sys.exit(0)
sys.exit(1)
