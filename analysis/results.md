# Extraction results — first pass (Haiku, unverified)

Structured screening of the ranger-citing full-text corpus for papers whose
conclusions could be affected by impurity-importance bias (see
[`../plan/text-mining-plan.md`](../plan/text-mining-plan.md)). One Haiku 4.5
subagent read each paper and emitted the `analysis/extraction/<id>.json` record;
flagged = `p_affected ∧ central_to_conclusions`.

**Status: first-pass, unverified.** These are Haiku judgements. The plan's
Sonnet/Opus adversarial adjudication pass (future work) has not run — treat the
counts as a screening estimate, not confirmed findings.

## What was screened

| Set | n | use impurity importance | flagged |
|-----|---|------------------------|---------|
| Fingerprint **survivors** (full sweep) | 158 | 83 | **27 (17%)** |
| Fingerprint **rejected** (random sample) | 40 | 24 | **11 (28%)** |

## The headline finding: the p-value fingerprint has poor recall

The false-negative check was designed to measure what the fingerprint misses.
It found more than expected:

- The **rejected** sample has a *higher* flag rate (28%) than the **survivors**
  (17%). The p-value fingerprint is not just imperfect — it is roughly
  **orthogonal to (even mildly anti-correlated with) actual affected-ness.**
- Extrapolating the 28% (95% CI 16–43%) to the 615 rejected full-text papers:
  **~169 flagged papers the fingerprint dropped** (CI ~99–263), versus 27 it
  caught. Estimated **fingerprint recall ≈ 14%.**
- Estimated total affected full-text papers: **~196 of 773 (~25%, CI 16–38%).**

**Why:** the target was defined (§1 of the plan) around a *significance verdict*
— `importance_pvalues`, Altmann/Janitza, Boruta, corrected impurity. But the bias
harms **magnitude and ranking**, and the papers most exposed are those that
simply **rank features by impurity importance and build conclusions on the
ranking, with no significance machinery at all.** Those papers don't contain the
fingerprint strings. Indeed, 10 of the 27 flagged survivors have
`pvalue_method: none` (they matched only via the importance-near-p-value
proximity rule), and the flagged rejected papers are almost all bare
impurity-ranking papers. If anything, papers that *do* use Altmann/Janitza/Boruta
are slightly **more** methodologically careful.

### Implication for the plan

The p-value-centric framing produces a **high-precision, low-recall** slice — good
for finding significance-claim papers, wrong as the primary net for "conclusions
affected." To estimate true prevalence, the fingerprint should be **broadened** to
"reports impurity/Gini/MDI importance AND ranks/selects on it" (drop the
significance-verdict requirement), or replaced by a cheap Haiku relevance pass
over the full 773-paper corpus (~$24 equivalent; on subscription, one workflow).
The p-value subset remains worth reporting as its own high-confidence stratum.

## Flagged candidates

`analysis/candidates.csv` — 38 flagged papers (27 survivors + 11 rejected-sample)
with `pvalue_method`, corroboration, feature-heterogeneity, title/DOI (joined from
`corpus/manifest.csv`), and the evidence quote behind each flag.

`pvalue_method` among the 27 flagged survivors: none 10, boruta 7, altmann 5,
janitza 3, other 2.

Several flagged papers carry partial corroboration (`heldout_validation`,
`pdp_ale`) — the weakest flags, and the first the adjudication pass should
re-examine, since held-out predictive validation partly mitigates ranking bias.

## Caveats

- **Unverified Haiku first pass** — precision unknown until adjudication.
- **False-negative estimate rests on a 40-paper sample** — wide CI (16–43%).
- **Full-text only** — the 2,416 abstract-only papers are a separate, lower-power
  track not screened here.
- **Flag ≠ wrong conclusion** — it means the conclusion *could* have been affected
  and wasn't corroborated; proving impact requires re-running the study's model
  (plan §6, out of scope).
