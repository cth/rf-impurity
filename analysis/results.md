# Extraction results — full-text screen (Haiku, unverified)

Structured screening of the ranger-citing full-text corpus for papers whose
conclusions could be affected by impurity-importance bias (see
[`../plan/text-mining-plan.md`](../plan/text-mining-plan.md)). One Haiku 4.5
subagent read each paper and emitted `analysis/extraction/<id>.json`; flagged =
`p_affected ∧ central_to_conclusions`.

**Status: first-pass, unverified.** These are Haiku judgements. The plan's
Sonnet/Opus adversarial adjudication pass (future work) has not run — treat the
counts as a screening estimate, not confirmed findings.

## Coverage

Two filters were run against the 773 full-text papers:

1. **P-value fingerprint** (narrow — required a significance verdict): 158 papers.
2. **Broadened filter** (any impurity/Gini/MDI or variable/feature-importance
   mention): 524 papers.

Screened by Haiku: **544 papers** (the union). The ~230 unscreened full-text
papers did not mention
importance at all (they cite ranger for speed or prediction only) and are treated
as near-zero flag rate.

## Headline numbers (544 screened)

| | count | of screened | of impurity-users |
|---|---|---|---|
| Use impurity importance | 307 | 56% | — |
| **Flagged** (`p_affected ∧ central`) | **125** | **23%** | **41%** |

- **95% CI on the screened flag rate: 20–27%.**
- As a share of **all 773 full-text papers: ~16%.**
- **63 of 125** flagged papers have **no corroboration at all** (no permutation
  importance, SHAP, PDP/ALE, conditional importance, or held-out validation) —
  the strongest flags. The rest carry partial corroboration and are weaker.

## Why the p-value framing missed most of them

The original narrow, p-value-centric fingerprint (your initial target) caught
**27** flagged papers. The broadened screen finds **125**. The reason is stark in
the method breakdown of the 125 flagged:

| `pvalue_method` | flagged papers |
|---|---|
| **none** | **108** |
| boruta | 7 |
| altmann | 5 |
| janitza | 3 |
| other | 2 |

**86% of affected papers use no significance machinery at all** — they simply
rank features by impurity importance and build conclusions on the ranking. The
p-value fingerprint, by construction, could never see them. This confirms the
false-negative finding from the earlier 40-paper sample: significance methods
(Altmann/Janitza/Boruta) are markers of *more* careful practice, not of exposure
to the bias. The high-recall net for "conclusions affected" is bare
impurity-ranking, not p-values.

The p-value subset (17 flagged with a method) remains worth reporting as its own
higher-confidence stratum, but it is a small minority of the exposed literature.

## Flagged candidates

`analysis/candidates.csv` — **125 flagged papers** with `pvalue_method`,
corroboration, feature-heterogeneity, title/DOI (joined from
`corpus/manifest.csv`), and the evidence quote behind each flag. Sorted with the
`pvalue_method != none` (higher-confidence) papers first.

## Citation impact of flagged papers

OpenAlex `cited_by_count` for the 544 screened papers
(`analysis/citation_counts.json`):

| group | n | median cites | mean cites | max | total cites |
|-------|---|-------------|-----------|-----|-------------|
| **Flagged** | 125 | 11 | 68.7 | 4,684 | 8,591 |
| Not flagged (all screened) | 419 | 10 | 30.6 | 1,077 | 12,826 |
| Impurity-users, not flagged | 182 | 12 | 35.3 | 1,077 | 6,431 |

- **Medians are essentially equal** (11 vs 10) — a typical flagged paper is no
  more cited than a typical screened paper.
- **But the mean is ~2× higher for flagged papers, and by citation weight the
  flagged 23% of papers account for ~40% of all citations** to the screened set.
  The effect is a heavy tail: a handful of highly-cited flagged papers, led by
  one 2017 paper with **4,684 citations** (`W2588003345`), pull the flagged mean
  up. So the *reach* of the potentially-affected conclusions is concentrated in a
  few influential papers rather than spread evenly.
- Every one of the ten most-cited flagged papers has `pvalue_method: none` —
  reinforcing that the high-impact exposure is in bare impurity-ranking, not in
  the significance-method literature.

Caveat: `cited_by_count` is confounded by publication year (older papers
accumulate more), and the flag itself is an unverified Haiku judgement — the
4,684-cite outlier should be first in line for the adjudication pass, since one
false positive there dominates the citation-weighted picture.

## Caveats

- **Unverified Haiku first pass** — precision unknown until the Sonnet/Opus
  adjudication pass runs. Prioritize the 63 zero-corroboration flags.
- **Full-text only** — the 2,416 abstract-only papers are a separate, lower-power
  track, not screened here. True corpus-wide prevalence is higher than the
  full-text number alone implies only if abstracts surface additional cases;
  abstracts rarely describe importance methodology, so expect lower recall there.
- **Flag ≠ wrong conclusion** — it means the conclusion *could* have been affected
  and wasn't corroborated; proving impact requires re-running the study's model
  (plan §6, out of scope).
