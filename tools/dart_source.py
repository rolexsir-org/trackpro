#!/usr/bin/env python3
"""Dart source pre-processing shared by the audits.

The audits are text scanners standing in for the analyzer, and every one of them
needs the same thing first: comments and string *contents* removed, so a label in
prose is not mistaken for code.

The obvious regex version of that gets one case wrong, and it matters. Given

    throw StateError('misconfigured:\\n - ${items.join('\\n - ')}');

a regex sees the literal end at the quote inside `${...}`, leaks `\\n - ')` back
into the "code" stream, and unbalances the braces — which is how a text audit
starts reporting invented problems and stops being trusted. A small scanner that
understands nesting handles it: interpolated expressions are *code*, so they are
kept (with their own literals blanked recursively), and everything else inside a
literal is discarded.

`strip_comments_and_strings` and `strip_comments` are the two public entry
points: the first is for rules about *code*, the second for rules about *shipped copy*
(they need opposite treatments of string literals, which is why there are two).
"""

from __future__ import annotations


def strip_comments_and_strings(src: str) -> str:
    """Return `src` with comments and string contents blanked out."""
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        ch = src[i]

        if ch == "/" and src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j == -1 else j
            continue
        if ch == "/" and src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j == -1 else j + 2
            continue

        if src.startswith("'''", i) or src.startswith('"""', i):
            quote = src[i : i + 3]
            i += 3
            while i < n and not src.startswith(quote, i):
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "$" and src.startswith("${", i + 1):
                    expr, i = _interpolation(src, i + 1)
                    out.append(" " + expr + " ")
                    continue
                i += 1
            i += 3
            out.append("''")
            continue

        if ch in "'\"":
            quote = ch
            i += 1
            while i < n and src[i] != quote:
                if src[i] == "\\":
                    i += 2
                    continue
                if src[i] == "$" and src.startswith("${", i + 1):
                    expr, i = _interpolation(src, i + 1)
                    out.append(" " + expr + " ")
                    continue
                i += 1
            i += 1
            if src[i - 2 : i - 1] == "\\":
                i -= 1  # an escaped quote is not the end of the literal
            out.append("''")
            continue

        out.append(ch)
        i += 1
    return "".join(out)


def _interpolation(src: str, start: int) -> tuple[str, int]:
    """Inner code of a `${...}` starting at `start`, and the index after its `}`.

    Nested string literals inside the interpolation are skipped whole so their
    braces and quotes cannot be counted as code.
    """
    depth, i, n = 0, start, len(src)
    while i < n:
        ch = src[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return strip_comments_and_strings(src[start + 1 : i]), i + 1
        elif ch in "'\"":
            quote = ch
            i += 1
            while i < n and src[i] != quote:
                i += 2 if src[i] == "\\" else 1
        i += 1
    return src[start + 1 :], n


def strip_comments(src: str) -> str:
    """Return `src` with comments removed and **string literals intact**.

    The mirror image of `strip_comments_and_strings`, and it needs the same care. The
    naive version — "delete from `//` to the end of the line" — also deletes the rest of
    every line that contains a URL, because `https://` looks exactly like a comment start.
    A copy audit that cannot see a link is worse than no audit: it reports clean. That is
    not hypothetical; `gate_probe.py` P-04 demonstrated it in this repo's own gate.

    Escapes inside literals are handled. Raw strings (`r'...'`) are handled as ordinary
    literals, so a literal backslash-quote inside one can desynchronise the scanner — the
    same limit `strip_comments_and_strings` accepts, and the reason these are audits
    rather than a parser.
    """
    out: list[str] = []
    i, n = 0, len(src)
    while i < n:
        ch = src[i]

        if ch == '/' and src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j == -1 else j  # keep the newline, so line numbers survive
            continue
        if ch == '/' and src.startswith('/*', i):
            j = src.find('*/', i + 2)
            if j == -1:
                i = n
            else:
                out.append('\n' * src.count('\n', i, j + 2))
                i = j + 2
            continue

        # Raw strings: no escape processing inside, so a `\` is just a character.
        if src.startswith(('r"""', "r'''"), i) and i + 3 < n and src[i + 1] == src[i + 2]:
            quote = src[i + 1 : i + 4]
            end = src.find(quote, i + 4)
            stop = n if end == -1 else end + 3
            out.append(src[i:stop])
            i = stop
            continue

        if src.startswith(('"""', "'''"), i):
            quote = src[i : i + 3]
            out.append(quote)
            i += 3
            while i < n and not src.startswith(quote, i):
                if src[i] == '\\':
                    out.append(src[i : i + 2])
                    i += 2
                    continue
                out.append(src[i])
                i += 1
            out.append(quote)
            i += 3
            continue

        if ch in "'\"":
            quote = ch
            out.append(ch)
            i += 1
            while i < n and src[i] != quote:
                if src[i] == '\\':
                    out.append(src[i : i + 2])
                    i += 2
                    continue
                if src[i] == '\n':
                    break  # an unterminated single-quoted literal: stop, do not eat the file
                out.append(src[i])
                i += 1
            if i < n and src[i] == quote:
                out.append(quote)
                i += 1
            continue

        out.append(ch)
        i += 1
    return ''.join(out)
