#!/usr/bin/env python3
"""Member audit — does every `Class.member` in the never-compiled code exist?

The Flutter SDK is not on this host, so nothing in `lib/` has ever been type
checked. `static_audit.py` verifies `AppState` members and a fixed list of static
constants; this audit generalises that to **every** qualified reference in the
files written since the Momentum work began, by collecting the members declared by
every class, enum and extension in `lib/` and checking each `Class.member` against
them.

It is a text audit, and it is honest about its limits:

  * It can prove a member is **missing** (a certain compile error).
  * It cannot prove a member's *type* is right, that an argument list matches, or
    that an override exists in a supertype.
  * It over-collects a little on purpose — a declaration is taken to be the last
    identifier on a line before `(`/`=`/`;`/`{` — because a false "resolved" is
    quieter than a false alarm, and false alarms are how a check gets ignored.

A file whose braces do not balance after comment and string stripping is reported
rather than skipped, so a gap in the audit cannot be mistaken for a pass.

    python3 tools/member_audit.py            # audit the focus files
    python3 tools/member_audit.py --all      # audit every file under lib/
    python3 tools/member_audit.py --json
"""
from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from static_audit import strip_comments_and_strings  # noqa: E402

# The files written during the Momentum work: nothing else here has been compiled
# either, but these are the ones with no precedent to copy from.
FOCUS = [
    "lib/screens/momentum_screen.dart",
    "lib/screens/routines_screen.dart",
    "lib/screens/today_screen.dart",
    "lib/screens/measurements_page.dart",
    "lib/screens/commitment_sheets.dart",
    "lib/screens/home_shell.dart",
    "lib/screens/settings_screen.dart",
    "lib/config/design_system.dart",
    "lib/data/momentum.dart",
    "lib/data/commitment_repository.dart",
    "lib/data/commitment_templates.dart",
    "lib/models/models.dart",
    "lib/util/day_key.dart",
    "lib/models/focus_models.dart",
    "lib/data/focus_engine.dart",
    "lib/data/focus_repository.dart",
    "lib/services/focus_platform.dart",
]

DECL = re.compile(r"\b(?:class|enum|extension|mixin)\s+([A-Z]\w*)")
# Declaration head = everything before the first `(`, `=`, `;` or `{` on the line.
HEAD = re.compile(r"^\s{2,}(.*?)(?=[(=;{]|$)")
KEYWORDS = {
    "if", "for", "while", "return", "switch", "case", "else", "assert", "await",
    "throw", "try", "catch", "finally", "do", "in", "is", "yield", "super", "this",
    "logicalOr", "collect", "void", "true", "false", "null", "new",
}
MODIFIERS = {
    "static", "final", "const", "late", "covariant", "required", "external",
    "abstract", "factory", "get", "set", "operator", "async", "sync",
}
IDENT = re.compile(r"[A-Za-z_$][\w$]*")


def _declaration_head(line: str) -> str:
    """The head of a member declaration line, or '' when the line declares nothing.

    A member's name is the last identifier before its parameter list, its initialiser
    or its terminator. Everything before it is modifiers and a type — and a *record*
    type is a parenthesised group with its own punctuation
    (`static ({List<String> a, List<String> b}) split(`), which is why this cannot
    simply take the text before the first `(`. When the text before a group holds no
    identifier but modifiers, the group is a type and is skipped.
    """
    if not HEAD.match(line):
        return ''
    i = 0
    while True:
        marks = [j for j in (line.find(ch, i) for ch in '(=;{') if j != -1]
        if not marks:
            return ''
        j = min(marks)
        head = line[i:j]
        significant = [t for t in IDENT.findall(head) if t not in MODIFIERS]
        if not significant and line[j] == '(':
            close = _matching_paren(line, j)
            if close == -1:
                return ''
            i = close + 1
            continue
        return head
    return ''


def _matching_paren(text: str, open_index: int) -> int:
    """Index of the `)` matching the `(` at `open_index`, or -1."""
    depth = 0
    for i in range(open_index, len(text)):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return i
    return -1


def _class_bodies(src: str):
    """Yield (name, body) for each `class`/`enum`/`extension`/`mixin` in `src`."""
    for m in DECL.finditer(src):
        brace = src.find("{", m.end())
        if brace == -1:
            continue  # declaration without a body (typedef-like) — nothing to collect
        depth, i = 1, brace + 1
        while i < len(src) and depth:
            ch = src[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
            i += 1
        yield m.group(1), src[brace + 1 : i - 1]


def collect_members(src: str):
    """{Class: {member, ...}} plus the set of declared type names."""
    members: dict[str, set[str]] = {}
    declared = set()
    for name, body in _class_bodies(src):
        declared.add(name)
        bag = members.setdefault(name, set())
        for line in body.splitlines():
            text = _declaration_head(line)
            if not text:
                continue
            tokens = [t for t in IDENT.findall(text) if t not in MODIFIERS]
            if not tokens:
                continue
            # `something.member(` is a call on another object, not a declaration —
            # unless the line opens with a constructor modifier, which makes the
            # part after the dot a *named constructor* (`factory X.forTesting(`).
            before = text[: text.find(tokens[-1])]
            if before.endswith("."):
                owner = IDENT.findall(before[:-1])
                # A named constructor (`TrackDatabase.forTesting(super.executor);`)
                # is a declaration when the receiver is the class being read.
                named_ctor = bool(owner) and owner[-1] == name
                if not (named_ctor or re.match(r"^(?:factory|const|late\s+final)\b", text)):
                    continue
            candidate = tokens[-1]
            if candidate in KEYWORDS or candidate in declared:
                # control keywords, and constructors which are the class itself
                if candidate != name:
                    continue
            bag.add(candidate)
        # enum values: every body line of an enum is a value list
        if "enum " + name in src or re.search(r"\benum\s+" + re.escape(name) + r"\b", src):
            vals = re.search(re.escape(name) + r"\s*\{([^}]*)\}", src)
            if vals:
                for raw in vals.group(1).split(","):
                    v = raw.strip().split("(")[0].split("=")[0].strip()
                    if v and IDENT.fullmatch(v):
                        bag.add(v)
            bag.update({"values", "name", "index"})
        # `const Foo._();` — the private constructor is a declaration too.
        for m in re.finditer(r"\b" + re.escape(name) + r"\._\s*\(", body):
            bag.add("_")
        bag.add(name)  # constructors
    return members, declared


def main() -> int:
    as_json = "--json" in sys.argv
    files = FOCUS
    if "--all" in sys.argv:
        files = []
        for root, _, names in os.walk("lib"):
            for n in sorted(names):
                if n.endswith(".dart"):
                    files.append(os.path.join(root, n).replace("\\", "/"))

    members: dict[str, set[str]] = {}
    declared: set[str] = set()
    unbalanced: list[str] = []
    for root, _, names in os.walk("lib"):
        for n in names:
            if not n.endswith(".dart"):
                continue
            path = os.path.join(root, n)
            src = strip_comments_and_strings(open(path, encoding="utf-8").read())
            if src.count("{") != src.count("}"):
                unbalanced.append(path.replace("\\", "/"))
            m, d = collect_members(src)
            declared.update(d)
            for cls, bag in m.items():
                members.setdefault(cls, set()).update(bag)

    problems, references, files_with_refs = [], 0, set()
    for path in files:
        if not os.path.exists(path):
            problems.append((path, 0, "<file missing>", "the file this audit names does not exist"))
            continue
        src = strip_comments_and_strings(open(path, encoding="utf-8").read())
        for m in re.finditer(r"\b([A-Z]\w*)\.(\w+)", src):
            cls, mem = m.group(1), m.group(2)
            if cls not in declared:
                continue  # a type from a package, or a local variable that looks urgent
            references += 1
            files_with_refs.add(path)
            if mem not in members.get(cls, set()):
                problems.append((path, src[: m.start()].count("\n") + 1, f"{cls}.{mem}", "no such member"))

    if as_json:
        print(json.dumps({
            "files": files,
            "references": references,
            "unbalanced": unbalanced,
            "problems": [{"file": f, "line": l, "ref": r, "why": w} for f, l, r, w in problems],
        }, indent=2))
        return 1 if problems else 0

    print(f"member audit: {references} qualified references checked across "
          f"{len(files_with_refs)} files, {len(declared)} types declared in lib/")
    if unbalanced:
        print("  WARNING: braces do not balance after stripping in:")
        for p in unbalanced:
            print(f"    {p}")
        print("  (declarations in those files may be under-collected, which can hide a")
        print("   missing member — check them by hand)")
    if problems:
        print(f"  {len(problems)} UNRESOLVED:")
        for f, line, ref, why in problems:
            print(f"    {f}:{line}  {ref}  ({why})")
        return 1
    print("  all resolved (text-level: proves presence, not correctness of types)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
