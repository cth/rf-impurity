# Plan: mining the literature for conclusions at risk from impurity-importance bias

**Goal.** Systematically identify published papers whose conclusions could have
been affected by the impurity-importance pitfalls documented in
[`../paper/impurity-importance.md`](../paper/impurity-importance.md):
super-linear magnification of effect size, attribution of interactions to the
interacting variables, and — most importantly — the inability to distinguish a
genuinely non-linear effect from a linear effect on a skewed feature.

**Hard caveat.** Text mining can only *flag risk*. It cannot prove a conclusion
was wrong — that requires re-running each study's model on its own data with an
unbiased importance measure (an optional gold tier, out of scope for the
flag-at-scale effort).

---

## 1. Target definition (p-value-centric)

The sharpest, highest-value target is **not** "any paper using random-forest
importance." It is papers that elevate impurity importance to a **significance
claim** and then build conclusions on it.

Rationale: `ranger` is the mainstream tool that turns impurity importance into an
inferential test via `importance_pvalues()` (`method="altmann"` or
`method="janitza"`; Janitza requires `impurity_corrected`/AIR). `randomForest`,
scikit-learn, and XGBoost emit a bare importance number with no inferential
wrapper. So ranger uniquely invites the move from *"feature X ranked high"* to
*"feature X is **significantly** important (p<0.05)"* — a confirmatory claim that
reads as statistical rigor and is disproportionately likely to drive a paper's
conclusions. Boruta (shadow-feature significance on the same impurity signal)
belongs in the target for the same reason.

**A paper is at risk when all of:**
1. It reports **impurity-based importance with a significance verdict** —
   `importance_pvalues`, Altmann, Janitza, "corrected impurity"/AIR, or Boruta.
2. It **interprets magnitude or ranking** — ranks features, selects
   biomarkers/drivers, or makes relative-importance claims — rather than only
   using the zero/non-zero verdict.
3. **No corroboration** — no permutation importance, SHAP, conditional
   importance, or PDP/ALE cross-check; risk selection not validated by held-out
   predictive performance.

**Amplifiers** (raise severity): heterogeneous feature scales, high-cardinality
categoricals, skewed/heavy-tailed predictors, explicit magnitude comparisons
across features.

### Honesty constraint on the flag

The Altmann/Janitza p-value tests the null *importance = 0* — i.e. **whether** a
variable is used — which is relatively robust. Our documented biases hit
**magnitude and ranking**, not the zero/non-zero verdict. So the failure mode in
these papers is usually **not** "the p-value is wrong"; it is:

1. reading a *significant* importance as an *effect size* / ranking by magnitude, and
2. a "significant **and** large" importance still cannot separate a real
   non-linear effect from a skewed feature (§6 of the paper).

The risk score must reward exactly this chain:
**impurity p-values reported → features ranked/interpreted by magnitude →
conclusions built on that ranking → no cross-check.**

---

## 2. Corpus retrieval (citation-anchored)

Citation-anchoring beats keyword seeds here: it is high-precision, enumerable,
and gives a defensible prevalence denominator.

| Tier | Anchor | Role |
|------|--------|------|
| **Core** | OpenAlex `cites:W2157395790` (ranger, Wright & Ziegler 2017; ~3,290 citing works) | High-precision backbone across all fields |
| **Fingerprint** | full-text signals: `importance_pvalues`, "Altmann", "Janitza", "corrected impurity", "Boruta" | Isolates the significance-claim subset — tighter than citing ranger alone |
| **Awareness / control** | `cites:Strobl 2007` (W1875061881) and `cites:Nembrini 2018` | Papers citing the bias literature likely mitigate → down-weight, or use as a negative-control set |

Full text via **Europe PMC / PMC open-access subset** (the at-risk reasoning
lives in Results/Discussion, not abstracts). Paywalled papers fall back to
abstract-only with a lower-confidence flag. `randomForest`/sklearn/XGBoost are
deliberately de-scoped by the p-value framing — they lack the inferential wrapper
that defines the target.

---

## 3. Pipeline

**Phase 0 — Gold set.** Hand-label ~30 papers (≈15 at-risk, ≈15 safe) to
calibrate the classifier and later report precision/recall.

**Phase 1 — Retrieve.** Pull `cites:ranger` works from OpenAlex; resolve
open-access full text via Europe PMC. Snapshot the set (date-stamped) for
reproducibility.

**Phase 2 — Relevance filter.** Rule-based prefilter on the fingerprint strings →
LLM confirms the paper actually reports impurity importance *with a significance
verdict* and interprets it.

**Phase 3 — Signal extraction** (LLM + regex over full text, per paper):
importance method; p-value method (Altmann/Janitza/Boruta); corroborating methods
present?; magnitude/ranking claims vs. verdict-only; feature heterogeneity
(mixed types, scale, skew); centrality of the ranking to the conclusions;
data/code availability.

**Phase 4 — Risk score.** `P(affected) × centrality-to-conclusions`, with the
awareness signal as a down-weight. Output a ranked, filterable table.

**Phase 5 — Adjudication.** Independent/multi-model review of top candidates,
each prompted to *argue against* the flag (adversarial verification) to cut false
positives.

**Phase 6 — Reproduce (optional gold tier, out of current scope).** For papers
with open data + code, re-run the model and compare impurity vs. permutation/SHAP
importance to *demonstrate* altered conclusions.

---

## 4. Deliverables

- **Ranked candidate table**: paper, importance method, p-value method,
  corroboration present, risk score, one-line rationale, data availability.
- **Prevalence estimate**: fraction of ranger-citing (and of the p-value-subset)
  papers at risk, by field.
- **Negative-control set**: bias-aware papers, for comparison.

## 5. Scope decisions locked

- **Fields:** all fields (citation anchor handles the breadth).
- **Depth:** flag at scale (Phases 1–5); Phase 6 reproduction deferred.
- **Target:** p-value-centric — the `cites:ranger` ∩ importance-p-value
  fingerprint, per §1.

## 6. Open item

- **Pilot:** run Phases 1–4 on a tractable slice (ranger-citing papers in the PMC
  open-access full-text subset) to validate the pipeline and refine signals —
  manual/single-process vs. a parallel multi-agent workflow (broader but
  token-heavy). Decision pending.

## Key identifiers

- ranger (Wright & Ziegler 2017): OpenAlex `W2157395790`, ~3,290 citations.
- Strobl et al. 2007 (bias): OpenAlex `W1875061881`, ~3,623 citations.
- Nembrini et al. 2018 (AIR / "revival of the Gini importance").
