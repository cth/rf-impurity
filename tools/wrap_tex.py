#!/usr/bin/env python3
"""Wrap long lines in LaTeX source files at word boundaries.

Only splits lines longer than --maxlen; never joins lines, so diffs stay
minimal. A single newline in LaTeX is equivalent to a space, so breaking
prose, math, and table rows at spaces is semantics-preserving.

Safety rules:
  - Comment lines keep their comment prefix (indent + "% ") on every
    continuation line, so wrapped comments stay comments.
  - Never breaks inside a word (protects control sequences, URLs, ...).
    Lines with no breakable space (e.g. pandoc's \\def\\maxheight
    boilerplate) are left unchanged and reported.
  - Lines inside verbatim-like environments (verbatim, Verbatim,
    lstlisting, minted, comment) are left unchanged and reported.
  - Strips trailing whitespace; preserves leading indentation.

Idempotent: a second run changes nothing. Exits 1 if any lines still
exceed --maxlen afterwards, listing them for manual fixing.
"""

import argparse
import re
import sys

VERBATIM_BEGIN = re.compile(r"\\begin\{(verbatim\*?|Verbatim\*?|lstlisting|minted|comment)\}")
VERBATIM_END = re.compile(r"\\end\{(verbatim\*?|Verbatim\*?|lstlisting|minted|comment)\}")
PREFIX = re.compile(r"^(\s*(?:%\s?)?)")


def wrap_line(line, maxlen):
    """Return (output_lines, unfixable). Input has no trailing newline."""
    line = line.rstrip()
    if len(line) <= maxlen:
        return [line], False
    prefix = PREFIX.match(line).group(1)
    body = line[len(prefix):]
    if len(prefix) >= maxlen or not body.strip():
        return [line], True
    parts = []
    lead = prefix
    remaining = body
    while True:
        if len(lead) + len(remaining) <= maxlen:
            parts.append((lead + remaining).rstrip())
            return parts, False
        avail = maxlen - len(lead)
        window = remaining[: avail + 1]
        idx = window.rfind(" ")
        if idx <= 0:
            # No breakable space: a word longer than the available width
            # (control sequence, URL, ...). Leave the rest as-is.
            parts.append((lead + remaining).rstrip())
            return parts, True
        parts.append((lead + remaining[:idx]).rstrip())
        remaining = remaining[idx + 1 :].lstrip()
        lead = prefix
        if not remaining:
            return parts, False


def process(path, maxlen):
    with open(path, encoding="utf-8") as f:
        original = f.read()
    had_trailing_nl = original.endswith("\n")
    lines = original.splitlines()
    out = []
    wrapped = 0
    problems = []  # (lineno, length, text)
    in_verbatim = False
    for n, line in enumerate(lines, 1):
        if VERBATIM_BEGIN.search(line):
            in_verbatim = True
        if in_verbatim:
            out.append(line.rstrip())
            if len(line.rstrip()) > maxlen:
                problems.append((n, len(line.rstrip()), line.rstrip()))
            if VERBATIM_END.search(line):
                in_verbatim = False
            continue
        new_lines, unfixable = wrap_line(line, maxlen)
        if len(new_lines) > 1:
            wrapped += 1
        if unfixable:
            problems.append((n, len(line.rstrip()), line.rstrip()))
        out.extend(new_lines)
    text = "\n".join(out)
    if had_trailing_nl:
        text += "\n"
    if text != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    return wrapped, problems


def main():
    ap = argparse.ArgumentParser(description="Wrap long lines in .tex files.")
    ap.add_argument("--maxlen", type=int, default=80)
    ap.add_argument("files", nargs="+")
    args = ap.parse_args()
    total_wrapped = 0
    all_problems = {}
    for path in args.files:
        wrapped, problems = process(path, args.maxlen)
        total_wrapped += wrapped
        if problems:
            all_problems[path] = problems
        print(f"{path}: wrapped {wrapped} line(s)")
    if all_problems:
        print(f"\nwarning: lines still over {args.maxlen} chars "
              "(no breakable space; fix manually):")
        for path, problems in all_problems.items():
            for n, length, text in problems:
                print(f"{path}:{n}: {length} chars: {text}")
        return 1
    print(f"\nok: all lines <= {args.maxlen} chars ({total_wrapped} wrapped)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
