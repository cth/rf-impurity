#!/usr/bin/env python3
"""
Fill analysis/citation_counts.json for OpenAlex ids that lack an entry.
Ids come from the extraction records plus any list given on the command line
(JSON arrays of "W....txt" or "W...."). Batches of 50 per OpenAlex request.

Usage: python3 analysis/fetch_citations.py [ids.json ...]
"""
import json, os, sys, time, urllib.parse, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "citation_counts.json")
UA = "rf-impurity-scoping/1.0 (mailto:christian@archontech.ai)"

def wanted():
    ids = {f[:-5] for f in os.listdir(os.path.join(HERE, "extraction")) if f.endswith(".json")}
    for p in sys.argv[1:]:
        ids |= {x.replace(".txt", "") for x in json.load(open(p))}
    return ids

def fetch(batch):
    q = urllib.parse.urlencode({
        "filter": "openalex_id:" + "|".join(batch),
        "select": "id,cited_by_count,publication_year", "per-page": len(batch)})
    req = urllib.request.Request("https://api.openalex.org/works?" + q, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["results"]

def main():
    have = json.load(open(OUT)) if os.path.exists(OUT) else {}
    todo = sorted(wanted() - set(have))
    print(f"{len(have)} present, {len(todo)} to fetch")
    for i in range(0, len(todo), 50):
        for w in fetch(todo[i:i + 50]):
            have[w["id"].rsplit("/", 1)[-1]] = {"cited_by_count": w["cited_by_count"], "year": w["publication_year"]}
        time.sleep(1.0)
    json.dump(have, open(OUT, "w"), indent=1, sort_keys=True)
    missing = sorted(set(todo) - set(have))
    print(f"{len(have)} present after fetch; {len(missing)} not found: {missing[:10]}")

if __name__ == "__main__":
    main()
