#!/usr/bin/env python3
"""Recall-tuned regex fingerprint for the impurity-importance p-value target.

Versioned pre-pass (§4/§5 of plan/text-mining-plan.md). Deterministic and free;
its job is to produce an auditable candidate set, NOT to gate on cost. Tuned for
recall — a missed true positive is gone forever, a false positive is discarded
cheaply by the downstream Haiku extraction pass.

Usage: python3 analysis/fingerprint.py corpus/fulltext
Prints per-signal hit counts and the overall survival rate.
"""
import re, sys, os, collections

FINGERPRINT_VERSION = "2026-07-02.1"

# Keep signals — ANY match makes a paper a candidate. Case-insensitive.
KEEP = {
    "importance_pvalues": r"importance[_\s]?p[-_\s]?values?",
    "boruta":             r"\bBoruta\b",
    "altmann":            r"\bAltmann\b",
    "janitza":            r"\bJanitza\b",
    "corrected_impurity": r"impurity[_\s]?corrected|corrected impurity|actual impurity reduction",
    # variable/feature/permutation importance NEAR p-value/significance language
    "importance_near_pvalue":
        r"(variable|feature|permutation)\s+importance"
        r"(?:\W+\w+){0,8}?\W+(p[-\s]?values?|significan\w*|null distribution)"
        r"|(p[-\s]?values?|significan\w*|null distribution)"
        r"(?:\W+\w+){0,8}?\W+(variable|feature|permutation)\s+importance",
}

# Recorded but NOT gating — feed the extraction's corroboration fields.
RECORD = {
    "impurity_measure":   r"importance\s*[=:]\s*[\"']impurity",
    "shap":               r"\bSHAP\b",
    "permutation_imp":    r"permutation importance",
    "pdp_ale":            r"partial dependence|\bPDP\b|\bALE\b|accumulated local effect",
    "conditional_imp":    r"\bcforest\b|conditional (?:permutation )?importance",
}

KEEP_RE   = {k: re.compile(v, re.I) for k, v in KEEP.items()}
RECORD_RE = {k: re.compile(v, re.I) for k, v in RECORD.items()}


def scan(text):
    keep = {k: bool(rx.search(text)) for k, rx in KEEP_RE.items()}
    rec  = {k: bool(rx.search(text)) for k, rx in RECORD_RE.items()}
    return keep, rec, any(keep.values())


def main(path):
    files = [f for f in os.listdir(path) if f.endswith((".txt", ".xml"))]
    keep_hits = collections.Counter()
    rec_hits  = collections.Counter()
    survivors = []
    for f in files:
        text = open(os.path.join(path, f), encoding="utf-8", errors="ignore").read()
        keep, rec, survived = scan(text)
        for k, v in keep.items():
            if v: keep_hits[k] += 1
        for k, v in rec.items():
            if v: rec_hits[k] += 1
        if survived:
            survivors.append(f)

    n = len(files)
    print(f"fingerprint version: {FINGERPRINT_VERSION}")
    print(f"scanned: {n} files in {path}\n")
    print("KEEP signals (papers matching each):")
    for k in KEEP:
        print(f"  {keep_hits[k]:>4}  {k}")
    print(f"\nSURVIVORS (any keep signal): {len(survivors)} / {n} "
          f"= {100*len(survivors)/n:.1f}%\n")
    print("RECORD signals (corroboration present):")
    for k in RECORD:
        print(f"  {rec_hits[k]:>4}  {k}")
    with open(os.path.join(os.path.dirname(path), "fingerprint_survivors.txt"), "w") as out:
        out.write("\n".join(sorted(survivors)) + "\n")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "corpus/fulltext")
