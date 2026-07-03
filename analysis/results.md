# Extraction results — full-text screen (Haiku, unverified)

Structured screening of the ranger-citing full-text corpus for papers whose
conclusions could be affected by impurity-importance bias (see
[`../plan/text-mining-plan.md`](../plan/text-mining-plan.md)). One Haiku 4.5
subagent read each paper and emitted `analysis/extraction/<id>.json`; flagged =
`p_affected ∧ central_to_conclusions`.

**Status: adjudicated.** Haiku produced the screening flags; a Sonnet
adversarial pass (prompted to *refute* each flag) then verified them. Both layers
are LLM judgements — treat the confirmed set as a strong screening estimate, not
ground truth (proving impact needs the study's data; plan §6).

## Adjudication outcome (the verified numbers)

Each of the 125 flagged papers was re-read by a Sonnet agent instructed to refute
the flag (confirm only if it uses impurity importance, the ranking is central,
AND it is not adequately corroborated). Verdicts (`analysis/adjudication/`):

| verdict | n |
|---------|---|
| **confirmed** | **55** |
| refuted | 65 |
| uncertain | 5 |

- **Haiku screen precision ≈ 55/125 = 44%** — the adversarial pass overturned a
  little over half the flags, so the raw screening counts overstate exposure by
  ~2×. Read every unadjudicated "flagged" number below with that factor in mind.
- **Verified prevalence: 55 confirmed of 544 screened full-text papers ≈ 10%**
  (~7% of all 773 full-text papers).
- **The 4,684-cite outlier `W2588003345` was CONFIRMED** — it ranks variables on
  ranger/xgboost built-in (impurity/gain) importance with no permutation, SHAP,
  Boruta, or conditional check. The confirmed set carries **6,659 citations**
  total, so the citation-weight concentration survives verification.
- Confirmed candidates: `analysis/confirmed_candidates.csv` (id, cites,
  pvalue_method, title/DOI, adjudication reason), sorted by citations.

The screening-level tables that follow (`flagged` = Haiku `p_affected ∧ central`)
are retained for the recall/method/citation/year analyses; apply the ~44%
precision factor to convert them to verified counts.

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

### Age-adjusted (citations per year)

`cited_by_count / (2026 − publication_year + 1)`, to remove the confound that
older papers accumulate more citations:

| group | n | median cites/yr | mean cites/yr | max |
|-------|---|----------------|--------------|-----|
| **Flagged** | 125 | 2.7 | 9.1 | 468.4 |
| Not flagged (all) | 419 | 2.5 | 5.6 | 119.7 |
| Impurity-users, not flagged | 182 | 2.5 | 6.0 | 119.7 |

The pattern survives age-adjustment: **medians nearly equal (2.7 vs 2.5), mean
still ~1.6× higher for flagged.** So the raw-citation gap was *not* an age
artifact — it is a genuine heavy tail. The same 2017 paper (`W2588003345`, 468
cites/yr) dominates, an order of magnitude above the next flagged paper.

Caveat: the flag itself is an unverified Haiku judgement — the 468-cites/yr
outlier should be first in line for the adjudication pass, since one false
positive there dominates the citation-weighted picture.

## Publication-year trend

Flagged papers skew slightly older (median 2022 vs 2023; Mann-Whitney z=−2.91,
**p=0.004**, but a small ~0.7-year effect). Breaking it down by year shows *why*
— and it is not a citation artifact but a shift in practice:

| year | screened | flag% | impurity-users | flag% (users) | corroboration% (users) |
|------|---------|-------|---------------|--------------|------------------------|
| 2016 | 1 | 100% | 1 | 100% | 0% |
| 2017 | 7 | 57% | 4 | 100% | 0% |
| 2018 | 7 | 43% | 6 | 50% | 50% |
| 2019 | 20 | 40% | 12 | 67% | 75% |
| 2020 | 47 | 13% | 30 | 20% | 77% |
| 2021 | 66 | 32% | 42 | 50% | 60% |
| 2022 | 94 | 26% | 59 | 41% | 61% |
| 2023 | 72 | 22% | 40 | 40% | 68% |
| 2024 | 79 | 23% | 46 | 39% | 63% |
| 2025 | 100 | 19% | 50 | 38% | 64% |
| 2026 | 51 | 10% | 17 | 29% | 82% |

Two things move together: **corroboration adoption rose** from ~0% (2016–17) to
~60–80% in recent years, and the **flag rate fell** in step (from ~100% of
impurity-users flagged in 2016–17 to ~30–40% recently). The most plausible
reading is that the field increasingly pairs impurity importance with SHAP,
permutation importance, or PDP/ALE — exactly the corroboration the flag checks
for — so newer papers are less exposed. This makes the small year difference a
symptom of improving practice, not a confound to explain away.

Caveats on this table: the 2016–19 rows have tiny n (1–20) and are noisy; 2026 is
a partial year. The monotonic-looking decline from 2020 on is the reliable part.

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
