#!/usr/bin/env python3
"""
Relevance filter for the ranger-citing corpus (paper, Section 8, "Relevance
filter"). A full text is retained if it matches, case-insensitively, any of the
alternatives below. This is the broadened filter that superseded fingerprint.py's
p-value fingerprint; it is the regex quoted verbatim in the paper and matches
524 of the 773 full texts.

Usage: python3 analysis/relevance_filter.py corpus/fulltext [--list]
"""
import os
import re
import sys

PATTERNS = [
    r"(variable|feature|permutation|gini|impurity)\s+importance",
    r"importance\s+(score|value|ranking|measure)",
    r"mean decrease",
    r"decrease in (impurity|gini|accuracy)",
    r"\bMDI\b",
    r"\bMDA\b",
    r"\bBoruta\b",
    r"impurity[_\s]?corrected",
    r"most important (variable|feature|predictor)",
]
RELEVANT = re.compile("|".join(f"(?:{p})" for p in PATTERNS), re.IGNORECASE)


def is_relevant(text):
    return RELEVANT.search(text) is not None


def main(path, list_matches=False):
    files = sorted(f for f in os.listdir(path) if f.endswith(".txt"))
    hits = []
    for f in files:
        text = open(os.path.join(path, f), encoding="utf-8", errors="ignore").read()
        if is_relevant(text):
            hits.append(f)
    print(f"{len(hits)} of {len(files)} full texts match the relevance filter")
    if list_matches:
        print("\n".join(hits))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    main(args[0] if args else "corpus/fulltext", "--list" in sys.argv)
