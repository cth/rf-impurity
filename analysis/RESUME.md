# Resuming the impurity-importance extraction pass

This note lets you (or a fresh Claude Code session) resume the LLM extraction
step of the literature audit without re-deriving state. See
[`../plan/text-mining-plan.md`](../plan/text-mining-plan.md) for the full plan.

## Where things stand

- **Corpus**: fully fetched and committed — 3,189 ranger-citing works
  (`corpus/fulltext/` = 773 full-text, `corpus/abstracts/` = 2,416), with
  `corpus/manifest.csv` (timestamps) and `corpus/README.md`.
- **Fingerprint**: `analysis/fingerprint.py` run on the 773 full-text papers →
  **158 survivors** (20.4%), listed in `corpus/fingerprint_survivors.txt`.
- **Extraction**: NOT yet complete. A workflow was started then stopped to save
  budget. `analysis/extraction/` is empty (no records written yet).

## What the extraction does

Runs one **Haiku** subagent per paper. Each reads the full text and writes a
structured record to `analysis/extraction/<openalex_id>.json` with fields:
`uses_impurity_importance`, `pvalue_method`, `interprets_magnitude_or_ranking`,
`corroboration`, `feature_heterogeneity`, `p_affected`, `central_to_conclusions`,
`evidence`. Headline candidate set = `p_affected AND central_to_conclusions`.

Input set = 158 survivors + a 40-paper random sample of fingerprint-*rejected*
full-text papers (the sample measures the filter's false-negative rate). Both
lists are frozen in `analysis/extract_input.json` (seed=42, reproducible via the
snippet in `analysis/fingerprint.py` + the sampling code below).

## How to resume (subscription, via subagents — no API key needed)

The self-contained workflow script is committed at
**`analysis/extract_workflow.js`** (file lists baked in — takes no args).

Ask Claude Code:

> Run the workflow at `analysis/extract_workflow.js`.

or, to continue the earlier run and re-use any agents that had already finished
(same session only — cross-session the cache is gone, just run fresh):

> Resume workflow scriptPath `analysis/extract_workflow.js`, resumeFromRunId
> `wf_15970f8a-bee`.

Idempotency across sessions: the script does **not** skip papers already on disk.
Before a fresh cross-session run, either (a) accept re-processing, or (b) tell
Claude to add a skip-if-`analysis/extraction/<id>.json`-exists guard to the
pipeline stage so only missing papers run.

### Cheaper options if budget is tight

- **Survivors only** — delete the `REJECTED` entries from the `items` array in
  `analysis/extract_workflow.js` (defers the FN-rate measurement). 158 agents
  instead of 198.
- **Halve the agent count** — the script currently uses a *second* agent per
  paper just to write the JSON. Fold the write into the extraction agent (give
  the extraction agent the Write tool and have it write its own record), or drop
  disk writes and aggregate from the workflow's return value.
- **Chunk it** — run the survivor list in batches (edit `SURVIVORS` to a slice),
  committing `analysis/extraction/` between batches.

Rough cost if it were metered API (Haiku 4.5): ~$4 for the 158 survivors,
~$6 for all 198. On the Team subscription it draws from quota, not a bill.

## After extraction — aggregate (no LLM, cheap)

Once `analysis/extraction/*.json` is populated, ask Claude to:

1. Build the two ranked candidate tables (full-text; abstract-only would be a
   separate later pass), columns per plan §7: id, DOI/title (join on
   `corpus/manifest.csv`), `pvalue_method`, corroboration, `p_affected`,
   `central_to_conclusions`, evidence.
2. Compute prevalence: flagged / 158 survivors, and extrapolate to the 773
   full-text cohort; report the rejected-sample false-negative count separately.
3. Write results to `analysis/results.md` (or a `paper/` section) and commit.

## Reproduce the input lists (if `analysis/extract_input.json` is ever lost)

```python
import os, random, json
random.seed(42)
allf = set(f for f in os.listdir('corpus/fulltext') if f.endswith('.txt'))
surv = set(l.strip() for l in open('corpus/fingerprint_survivors.txt') if l.strip())
sample = sorted(random.sample(sorted(allf - surv), 40))
json.dump({'survivors': sorted(surv), 'rejected_sample': sample},
          open('analysis/extract_input.json', 'w'), indent=0)
```

## Key identifiers

- ranger anchor: OpenAlex `W2157395790` (~3,189 citing works).
- Stopped run ID (same-session resume only): `wf_15970f8a-bee`.
