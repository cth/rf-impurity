#!/usr/bin/env python3
"""Fetch a local, reproducible corpus of works citing the ranger R package.

Anchor: OpenAlex W2157395790 (Wright & Ziegler 2017).
Pure data-fetching: pages OpenAlex, fetches Europe PMC OA full text when
available, otherwise stores the reconstructed abstract. Idempotent/resumable.

Python 3 stdlib only.
"""

import csv
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

ANCHOR_ID = "W2157395790"
UA = "rf-impurity-scoping/1.0 (mailto:christian@archontech.ai)"

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORPUS = os.path.join(REPO, "corpus")
FULLTEXT_DIR = os.path.join(CORPUS, "fulltext")
ABSTRACT_DIR = os.path.join(CORPUS, "abstracts")
MANIFEST = os.path.join(CORPUS, "manifest.csv")
ERROR_LOG = os.path.join(CORPUS, "fetch_errors.log")
README = os.path.join(CORPUS, "README.md")

OPENALEX_WORKS = "https://api.openalex.org/works"
EPMC_SEARCH = "https://www.ebi.ac.uk/europepmc/webservices/rest/search"
EPMC_BASE = "https://www.ebi.ac.uk/europepmc/webservices/rest"

SELECT = "id,doi,title,publication_year,primary_location,open_access,ids,abstract_inverted_index"

SLEEP = 0.15  # polite pause between requests


def now_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def log_error(msg):
    with open(ERROR_LOG, "a", encoding="utf-8") as f:
        f.write(f"{now_utc()}\t{msg}\n")


def http_get(url, headers=None, retries=1, timeout=60):
    """GET with one retry. Returns bytes. Raises on final failure."""
    hdrs = {"User-Agent": UA}
    if headers:
        hdrs.update(headers)
    attempt = 0
    last_exc = None
    while attempt <= retries:
        try:
            req = urllib.request.Request(url, headers=hdrs)
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read()
        except Exception as e:  # noqa: BLE001
            last_exc = e
            attempt += 1
            if attempt <= retries:
                time.sleep(1.0)
    raise last_exc


def short_id(openalex_id):
    """Turn https://openalex.org/W123 -> W123."""
    return openalex_id.rstrip("/").rsplit("/", 1)[-1]


def clean_doi(doi):
    if not doi:
        return None
    d = doi.strip()
    for pfx in ("https://doi.org/", "http://doi.org/", "doi:"):
        if d.lower().startswith(pfx):
            d = d[len(pfx):]
    return d or None


def reconstruct_abstract(inv):
    if not inv:
        return ""
    positions = []
    for word, poss in inv.items():
        for p in poss:
            positions.append((p, word))
    positions.sort(key=lambda x: x[0])
    return " ".join(w for _, w in positions)


def strip_xml(xml_text):
    txt = re.sub(r"<[^>]+>", " ", xml_text)
    txt = re.sub(r"\s+", " ", txt)
    return txt.strip()


def sha256_of(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def iter_openalex_works():
    cursor = "*"
    while cursor:
        params = {
            "filter": f"cites:{ANCHOR_ID}",
            "per_page": "200",
            "cursor": cursor,
            "select": SELECT,
        }
        url = OPENALEX_WORKS + "?" + urllib.parse.urlencode(params)
        raw = http_get(url)
        data = json.loads(raw)
        meta = data.get("meta", {})
        for w in data.get("results", []):
            yield w, meta
        cursor = meta.get("next_cursor")
        time.sleep(SLEEP)


def try_europepmc_fulltext(doi):
    """Return (pmcid, fulltext_url, plain_text) or None."""
    q = f'DOI:"{doi}"'
    url = EPMC_SEARCH + "?" + urllib.parse.urlencode(
        {"query": q, "resultType": "core", "format": "json"}
    )
    raw = http_get(url)
    data = json.loads(raw)
    results = data.get("resultList", {}).get("result", [])
    if not results:
        return None
    first = results[0]
    pmcid = first.get("pmcid")
    in_epmc = first.get("inEPMC")
    if not pmcid or in_epmc != "Y":
        return None
    ft_url = f"{EPMC_BASE}/{pmcid}/fullTextXML"
    time.sleep(SLEEP)
    xml = http_get(ft_url).decode("utf-8", errors="replace")
    plain = strip_xml(xml)
    if not plain:
        return None
    return pmcid, ft_url, plain


def load_done_ids():
    """Read existing manifest to know which ids are already processed."""
    done = set()
    if os.path.exists(MANIFEST):
        with open(MANIFEST, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                done.add(row["openalex_id"])
    return done


def main():
    os.makedirs(FULLTEXT_DIR, exist_ok=True)
    os.makedirs(ABSTRACT_DIR, exist_ok=True)

    done_ids = load_done_ids()
    manifest_exists = os.path.exists(MANIFEST)

    snapshot_date = now_utc()
    total_seen = 0
    counts = {"fulltext": 0, "abstract_only": 0, "empty": 0, "failed": 0}
    chars = {"fulltext": 0, "all": 0}

    mf = open(MANIFEST, "a", newline="", encoding="utf-8")
    writer = csv.writer(mf)
    if not manifest_exists:
        writer.writerow([
            "openalex_id", "doi", "title", "year", "venue", "track",
            "source", "fetch_ts_utc", "source_url", "sha256", "n_chars",
        ])

    try:
        for work, meta in iter_openalex_works():
            total_seen += 1
            oid = short_id(work.get("id", ""))
            if not oid:
                continue
            if oid in done_ids:
                continue

            doi = clean_doi(work.get("doi"))
            title = work.get("title") or ""
            year = work.get("publication_year") or ""
            ploc = work.get("primary_location") or {}
            src = ploc.get("source") or {}
            venue = src.get("display_name") or ""
            work_url = work.get("id", "")

            track = None
            source = None
            source_url = None
            text = None
            out_path = None

            # 1. Try full text via Europe PMC (only if DOI)
            if doi:
                try:
                    ft = try_europepmc_fulltext(doi)
                except Exception as e:  # noqa: BLE001
                    log_error(f"{oid}\tEPMC error\t{e}")
                    ft = None
                if ft:
                    _pmcid, ft_url, plain = ft
                    track = "fulltext"
                    source = "europepmc"
                    source_url = ft_url
                    text = plain
                    out_path = os.path.join(FULLTEXT_DIR, f"{oid}.txt")

            # 2. Otherwise abstract
            if text is None:
                abstract = reconstruct_abstract(
                    work.get("abstract_inverted_index")
                )
                track = "abstract_only"
                source = "openalex"
                source_url = work_url
                text = abstract
                out_path = os.path.join(ABSTRACT_DIR, f"{oid}.txt")

            try:
                with open(out_path, "w", encoding="utf-8") as f:
                    f.write(text)
            except Exception as e:  # noqa: BLE001
                log_error(f"{oid}\twrite error\t{e}")
                counts["failed"] += 1
                continue

            digest = sha256_of(text)
            n_chars = len(text)

            if track == "fulltext":
                counts["fulltext"] += 1
                chars["fulltext"] += n_chars
            elif n_chars == 0:
                counts["empty"] += 1
                log_error(f"{oid}\tempty abstract (no text available)")
            else:
                counts["abstract_only"] += 1
            chars["all"] += n_chars

            writer.writerow([
                oid, doi or "", title, year, venue, track, source,
                now_utc(), source_url, digest, n_chars,
            ])
            mf.flush()
            done_ids.add(oid)

            if total_seen % 100 == 0:
                sys.stderr.write(
                    f"seen={total_seen} ft={counts['fulltext']} "
                    f"abs={counts['abstract_only']} empty={counts['empty']} "
                    f"failed={counts['failed']}\n"
                )
                sys.stderr.flush()
    finally:
        mf.close()

    # README
    with open(README, "w", encoding="utf-8") as f:
        f.write(
            f"# Corpus: works citing ranger ({ANCHOR_ID})\n\n"
            f"- OpenAlex snapshot date (UTC): {snapshot_date}\n"
            f"- Anchor id: {ANCHOR_ID} (Wright & Ziegler 2017)\n"
            f"- Total works seen this run: {total_seen}\n"
            f"- fulltext: {counts['fulltext']}\n"
            f"- abstract_only: {counts['abstract_only']}\n"
            f"- empty (no text available): {counts['empty']}\n"
            f"- failed (write errors): {counts['failed']}\n\n"
            "## Layout\n"
            "- `fulltext/<openalex_id>.txt` - PMC OA full text (Europe PMC)\n"
            "- `abstracts/<openalex_id>.txt` - reconstructed OpenAlex abstract\n"
            "- `manifest.csv` - one row per work\n"
            "- `fetch_errors.log` - per-record skips/errors\n\n"
            "## Regenerate\n"
            "```\n"
            "python3 analysis/fetch_corpus.py\n"
            "```\n"
            "The script is idempotent: it skips works already in `manifest.csv`,\n"
            "so re-running resumes. Delete `corpus/` to start fresh.\n\n"
            "Only PMC Open Access full text is redistributed (served by Europe\n"
            "PMC fullTextXML). Abstracts come from OpenAlex.\n"
        )

    sys.stderr.write(
        f"DONE seen={total_seen} ft={counts['fulltext']} "
        f"abs={counts['abstract_only']} empty={counts['empty']} "
        f"failed={counts['failed']}\n"
    )


if __name__ == "__main__":
    main()
