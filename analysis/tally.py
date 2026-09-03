#!/usr/bin/env python3
"""
Recompute every count and percentage in the paper's prevalence section from
the per-paper records: analysis/extraction/*.json (stage 1, Haiku),
analysis/adjudication/*.json (stage 2, Sonnet), analysis/citation_counts.json,
and corpus/manifest.csv. Prints the pipeline table and the derived figures.

Usage: python3 analysis/tally.py
"""
import csv, json, os, statistics

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

def load(d):
    p = os.path.join(HERE, d)
    return {f[:-5]: json.load(open(os.path.join(p, f))) for f in os.listdir(p) if f.endswith(".json")}

def main():
    manifest = list(csv.DictReader(open(os.path.join(ROOT, "corpus", "manifest.csv"))))
    fulltext = {f[:-4] for f in os.listdir(os.path.join(ROOT, "corpus", "fulltext")) if f.endswith(".txt")}
    ex, ad = load("extraction"), load("adjudication")
    cites = {k: v["cited_by_count"] for k, v in json.load(open(os.path.join(HERE, "citation_counts.json"))).items()}

    screened = sorted(ex)
    uses = [k for k in screened if ex[k]["uses_impurity_importance"]]
    flagged = [k for k in screened if ex[k].get("p_affected") and ex[k].get("central_to_conclusions")]
    verdict = lambda t: [k for k in flagged if ad.get(k, {}).get("verdict") == t]
    conf, ref, unc = verdict("confirmed"), verdict("refuted"), verdict("uncertain")
    unadj = [k for k in flagged if k not in ad]

    print(f"works citing ranger (manifest rows)      {len(manifest)}")
    print(f"with open-access full text               {len(fulltext)}")
    print(f"screened (stage 1 records)               {len(screened)}   not screened: {len(fulltext - set(screened))}")
    print(f"using an impurity importance             {len(uses)}")
    print(f"flagged (stage 1)                        {len(flagged)}   not yet adjudicated: {len(unadj)}")
    print(f"  confirmed / refuted / uncertain        {len(conf)} / {len(ref)} / {len(unc)}")
    print()
    pct = lambda a, b: f"{100*a/b:.1f}%"
    print(f"confirmed / screened                     {pct(len(conf), len(screened))}")
    print(f"confirmed / impurity users               {pct(len(conf), len(uses))}   (1 in {len(uses)/len(conf):.1f})")
    print(f"confirmed / full texts                   {pct(len(conf), len(fulltext))}")
    print(f"refuted / flagged                        {pct(len(ref), len(flagged))}   uncertain / flagged {pct(len(unc), len(flagged))}")
    print(f"stage-1 precision (confirmed / flagged)  {pct(len(conf), len(flagged))}")
    nopv = [k for k in conf if ex[k].get("pvalue_method") == "none"]
    print(f"confirmed with no p-value machinery      {len(nopv)} / {len(conf)} = {pct(len(nopv), len(conf))}")
    c_conf = [cites[k] for k in conf if k in cites]; c_all = [cites[k] for k in screened if k in cites]
    print(f"citations: confirmed median {statistics.median(c_conf):.0f}, screened-set median {statistics.median(c_all):.0f}, "
          f"confirmed > 50 citations: {sum(x > 50 for x in c_conf)}   (counts known for {len(c_all)}/{len(screened)})")
    by_set = {}
    for k in screened: by_set[ex[k].get("set", "?")] = by_set.get(ex[k].get("set", "?"), 0) + 1
    print(f"\nrecords by set tag: {by_set}")

if __name__ == "__main__":
    main()
