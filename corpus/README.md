# Corpus: works citing ranger (W2157395790)

- OpenAlex snapshot date (UTC): 2026-07-02T20:59:12Z
- Anchor id: W2157395790 (Wright & Ziegler 2017)
- Total works seen this run: 3189
- fulltext: 773
- abstract_only: 1846
- empty (no text available): 570
- failed (write errors): 0

## Layout
- `fulltext/<openalex_id>.txt` - PMC OA full text (Europe PMC)
- `abstracts/<openalex_id>.txt` - reconstructed OpenAlex abstract
- `manifest.csv` - one row per work
- `fetch_errors.log` - per-record skips/errors

## Regenerate
```
python3 analysis/fetch_corpus.py
```
The script is idempotent: it skips works already in `manifest.csv`,
so re-running resumes. Delete `corpus/` to start fresh.

Only PMC Open Access full text is redistributed (served by Europe
PMC fullTextXML). Abstracts come from OpenAlex.
