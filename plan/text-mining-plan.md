# Plan: mining the literature for conclusions at risk from impurity-importance bias

**Goal.** Systematically identify published papers whose conclusions could have
been affected by the impurity-importance pitfalls documented in
[`../paper/impurity-importance.md`](../paper/impurity-importance.md):
super-linear magnification of effect size, attribution of interactions to the
interacting variables, and — most importantly — the inability to distinguish a
genuinely non-linear effect from a linear effect on a skewed feature.

**Hard caveat.** Text mining can only *flag risk*. It cannot prove a conclusion
was wrong — that requires re-running each study's model on its own data with an
unbiased importance measure (future work; see §6).

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

The extraction (§4) must capture exactly this chain:
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
| **Awareness / control** | `cites:Strobl 2007` (W1875061881) and `cites:Nembrini 2018` | Papers citing the bias literature likely mitigate → note as a mitigating signal, or use as a negative-control set |

`randomForest`/sklearn/XGBoost are deliberately de-scoped by the p-value framing —
they lack the inferential wrapper that defines the target.

### Two access tracks, reported separately

Full-text availability changes what can be extracted and how confident the flag
is, so the two are **kept as separate cohorts throughout** — separate storage,
separate statistics, separate tables. They are never pooled into one prevalence
number.

- **Full-text track** — open access via Europe PMC / PMC OA subset. The at-risk
  reasoning lives in Results/Discussion, so these get the full extraction and a
  high-confidence flag.
- **Abstract-only / paywalled track** — metadata + abstract only. Extraction is
  necessarily shallower and the flag is explicitly low-confidence. Reported in a
  separate table, clearly labelled as under-powered, never merged with full-text
  statistics.

---

## 3. Local corpus storage (reproducibility)

All fetched text is stored in the repo so the entire analysis can be **re-run
without re-fetching**, and so results are auditable.

- `corpus/fulltext/<openalex_id>.txt` (or `.xml`) — retrieved full text.
- `corpus/abstracts/<openalex_id>.txt` — abstract-only records.
- `corpus/manifest.csv` — one row per paper: OpenAlex id, DOI, title, year,
  venue, track (fulltext | abstract_only), source (europepmc / pmc / openalex),
  **fetch timestamp (UTC, ISO-8601)**, source URL, and a content hash.

The fetch timestamp is recorded per record (and a corpus-level snapshot date in
the manifest header) because OpenAlex citation sets and OA availability drift
over time; every statistic is reported against a named snapshot.

Licensing note: store only text we are permitted to redistribute (PMC OA / CC
subset). For records whose licence forbids redistribution, store the hash +
source URL + fetch timestamp rather than the text, so the fetch is reproducible
without re-hosting.

---

## 4. Extraction — structured output per paper (replaces hand-labelling)

There is **no manual gold-labelling phase** (not feasible at this scale).
Instead, every paper is processed by an LLM/agent that emits, for that paper, a
**structured record** (for aggregate statistics) plus **free-text reasoning**
(the evidence trail for each judgement). Both are stored.

Per-paper structured record (illustrative fields):

| Field | Type | Meaning |
|-------|------|---------|
| `uses_impurity_importance` | bool | impurity/Gini/AIR importance reported |
| `pvalue_method` | enum | none / altmann / janitza / boruta / other |
| `interprets_magnitude_or_ranking` | bool | ranks / selects / compares by importance |
| `corroboration` | enum-set | permutation / SHAP / PDP-ALE / conditional / heldout / none |
| `feature_heterogeneity` | enum-set | mixed-types / high-cardinality / skewed / scale-mismatch |
| **`p_affected`** | **bool** | LLM's binary verdict: could the bias have altered a conclusion? |
| **`central_to_conclusions`** | **bool** | LLM's binary verdict: is the importance ranking central to the paper's conclusions? |
| `evidence` | text | quoted spans + reasoning supporting the above |
| `track` | enum | fulltext / abstract_only |

**No composite risk model.** We deliberately avoid a fitted/weighted risk score —
it is hard to calibrate and hard to defend. The two decisive judgements are
emitted directly by the LLM as **binary indicators**: `p_affected` and
`central_to_conclusions`. The headline candidate set is simply
`p_affected AND central_to_conclusions`. All other fields are reported as
descriptive cross-tabs, not folded into a single number.

Every judgement is backed by stored `evidence` so a human can audit any flag.

### Relevance filter (documented, with measured accuracy)

A cheap rule-based prefilter (fingerprint strings of §2) narrows the corpus
before the expensive per-paper extraction. Because it gates everything
downstream, it is **documented and its accuracy is measured**:

- The filter's rules/patterns are versioned in the repo.
- Accuracy is estimated on a **stratified random sample** of papers the filter
  *kept* and *dropped*, adjudicated by the same structured-extraction step.
  Report precision (kept ∩ truly-relevant / kept) and — critically —
  the **false-negative rate** (relevant papers wrongly dropped), with CIs.
- If recall is inadequate the filter is loosened and re-measured; the report
  states the operating point used.

### Fingerprint rules

The fingerprint is a versioned, recall-tuned regex set (`analysis/fingerprint.py`).
Its job is to cut the LLM corpus cheaply and deterministically — a missed true
positive is expensive (gone forever), a false positive is cheap (the LLM discards
it), so it is a generous OR of signals, case-insensitive and separator-tolerant.
Because the locked target requires a **significance verdict** (condition 1 of §1),
it keys on the p-value machinery, not merely "uses importance".

**Keep signals (any match → candidate):**
- `importance[_\s]?p[-_\s]?values?` — ranger's `importance_pvalues()`
- `\bBoruta\b` — shadow-feature significance
- `\bAltmann\b`, `\bJanitza\b` — the two p-value methods (a citation to them counts)
- `impurity[_\s]?corrected` | `corrected impurity` | `actual impurity reduction`
- `(variable|feature|permutation)\s+importance` within ~50 chars of
  `p[-\s]?value | significan | null distribution`

**Recorded but not gating** (feed the extraction's corroboration fields):
`importance\s*=\s*["']impurity`, `SHAP`, `permutation importance`,
`partial dependence|PDP|ALE`, `cforest|conditional importance`.

Known weak spots to measure, not assume away: abstracts rarely contain these
strings (poor recall on the abstract track → send that cohort to the LLM more
liberally); bare author surnames ("Altmann") cause false positives (acceptable
under recall-first); code-free / method-unnamed papers are caught only by the
proximity rule (the recall risk the FN measurement quantifies).

---

## 5. Model cascade (who reads what)

The fingerprint is a **pre-pass for determinism and measurement, not for cost** —
reading the full-text corpus with a cheap model is inexpensive (see anchors
below), so cost is not the reason to gate. The reasons to keep the regex are that
it is deterministic (an auditable, exactly-repeatable candidate set — an LLM
filter is not), free, and the only thing whose accuracy can be *characterized* (a
rule has a measurable false-negative rate; "what the model decided that day" does
not). Extraction is therefore a **cascade**, not a single model:

| Stage | Model | Reads | Emits |
|-------|-------|-------|-------|
| 1. Fingerprint | — (regex) | all stored text | deterministic candidate set + FN sample |
| 2. Structured extraction | **Haiku 4.5** | fingerprint survivors + a random sample of the *rejected* set | the full §4 record incl. `p_affected` / `central_to_conclusions` + evidence |
| 3. Adjudication *(future work, §6)* | **Sonnet / Opus** | only the positives & borderline cases from stage 2 | confirm / refute each flag |

Rationale: "Haiku-as-filter" and "Haiku-as-extractor" collapse — once Haiku reads
the text you have paid the input cost, so Haiku *is* the reader and emits the
structured record in one pass rather than a separate gate. Running Haiku on a
random sample of fingerprint-*rejected* papers is exactly how §4's false-negative
rate is measured. The expensive model (Sonnet/Opus) sees only the shortlist.

**Cost anchors** (Haiku 4.5 $1/$5 per 1M in/out; Sonnet 5 $3/$15; Opus 4.8
$5/$25; full-text mean ~19k input tokens/paper):

| Option | Model | ~Cost |
|--------|-------|-------|
| Read **all** ~1,400 full texts | Haiku | **~$40** |
| Read all ~1,400 full texts | Sonnet | ~$110 |
| Read only fingerprint survivors (~300) | Sonnet | ~$28 |

At ~$40 to Haiku-read everything, cost does not force the fingerprint — it earns
its place on determinism and measurability alone.

---

## 5b. Pipeline summary

1. **Retrieve** `cites:ranger` from OpenAlex; resolve OA full text via Europe
   PMC; split into full-text vs. abstract-only tracks; store text + manifest with
   fetch timestamps (§3).
2. **Fingerprint** on stored text; store filter version and its measured accuracy
   (§4, §5).
3. **Haiku structured extraction** per paper — record + evidence, both stored;
   also run on a random rejected-set sample to measure the FN rate (§5).
4. **Aggregate & report** — candidate set = `p_affected ∧ central_to_conclusions`;
   descriptive cross-tabs; the two tracks reported separately.

---

## 6. Future work (explicitly out of current scope)

- **Adjudication pass** — independent/multi-model adversarial re-review of
  candidates to cut false positives.
- **Reproduction** — for papers with open data + code, re-run the model and
  compare impurity vs. permutation/SHAP importance to *demonstrate* altered
  conclusions (the only step that proves, rather than flags, impact).

---

## 7. Deliverables

- **Two ranked candidate tables** (full-text; abstract-only, labelled
  low-confidence): paper, importance method, p-value method, corroboration,
  `p_affected`, `central_to_conclusions`, evidence link, data availability.
- **Prevalence statistics**, per track separately: fraction of ranger-citing
  papers with `p_affected ∧ central_to_conclusions`, by field.
- **Relevance-filter accuracy report** (precision + false-negative rate).
- **Stored corpus** (`corpus/`) with fetch timestamps, enabling exact re-runs.
- **Negative-control set**: bias-aware papers (cite Strobl/Nembrini), for
  comparison.

## 8. Scope decisions locked

- **Fields:** all fields (citation anchor handles the breadth).
- **Access:** full-text and abstract-only/paywalled tracks reported separately,
  never pooled.
- **Labelling:** LLM/agent structured output + reasoning per paper; no manual
  gold set.
- **Scoring:** binary `p_affected` and `central_to_conclusions` indicators; no
  composite risk model.
- **Models:** regex fingerprint (determinism/measurement) → Haiku 4.5 extraction
  → Sonnet/Opus adjudication (future work); no model gates before reading.
- **Depth:** flag at scale (retrieve → filter → extract → report). Adjudication
  and reproduction are future work.
- **Reproducibility:** all fetched text stored in-repo with per-record fetch
  timestamps.

## 9. Open item

- **Pilot:** run the pipeline on a tractable slice (ranger-citing papers in the
  PMC open-access full-text subset) to validate it and measure the relevance
  filter — manual/single-process vs. a parallel multi-agent workflow (broader but
  token-heavy). Decision pending.

## Key identifiers

- ranger (Wright & Ziegler 2017): OpenAlex `W2157395790`, ~3,290 citations.
- Strobl et al. 2007 (bias): OpenAlex `W1875061881`, ~3,623 citations.
- Nembrini et al. 2018 (AIR / "revival of the Gini importance").
