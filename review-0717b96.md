# Paper Review: *On the misinterpretation of variable importance as effect size*

*Reviewed at commit `0717b96`, 2026-09-09. Format follows the BESSER-PEARL
research-paper-review skill (summary → consistency checks → critical analysis →
actionable feedback → top actions), with the UCSB review-instruction sections
folded in where they add something: an explicit "Possible enhancements" list
and a "Platform and workload assumptions" pass (the systems-review question of
"what hardware and workloads does this assume" translated to "what software,
defaults, and data-generating assumptions does this rest on").*

*Reviewing assumption: full research paper for a statistics/methodology
journal. The repository carries a TAS-format master
(`paper/tas/`, 25 pp.), so The American Statistician is taken as the target
venue; the main master is 13 pp. Where TAS norms matter they are named.*

*Methods: fresh end-to-end run of `analysis/validate.R` (ranger 0.18.0, R
4.6.1; 17 min 27 s; Claim 5d skipped, `treeshap` not installed);
`analysis/tally.py` over all 773 extraction and 129 adjudication records;
clean builds of both masters (0 errors, 0 undefined references, 0 LaTeX
warnings); citation and label integrity checked mechanically (all 20 bib
entries cited, all cites resolve, all `\ref`s resolve); one external check
(Galili & Meilijson's abstract, for the sentence rewritten this session);
every finding of `review-4134c3b.md` re-checked against the current text.
One commit since the last review, confined to `sections/confound.tex` and a
comment block in `validate.R`.*

---

## Summary

**Problem.** Mean-decrease-in-impurity (MDI) importance from a random forest
is routinely read as if it were an effect size comparable to a regression
coefficient. The paper argues it is a *variance contribution*,
Var(f_j(X_j)), and asks what follows from that for interpretation and how
often published work makes the misreading.

**Contributions (as claimed).** (1) Controlled demonstrations that MDI scales
with β² rather than β (Sec. 2), charges an interaction's variance to the
interacting variables (Sec. 3), and — the paper's sharpest point — gives
*provably identical* scores to a non-linear effect on a uniform feature and a
linear effect on a skewed one (Secs. 5–6), stated as a proposition with two
hypotheses and both hypotheses shown to be load-bearing. (2) Evidence that
the confound is shared by AIR, permutation importance and global mean |SHAP|,
so it is a property of marginal importance measures rather than a defect of
MDI. (3) An LLM two-stage screen of 773 open-access ranger-citing papers:
331 interpret an impurity importance, 56 are confirmed as leaning on its
magnitude or ranking without corroboration — 7% of full texts, 17% of
impurity users. (4) Section-level "Practical implications" paragraphs,
recommending shape-aware views (PDP / SHAP dependence, ALE under dependence).

**Approach.** Noiseless synthetic regressions with independent features of a
single type per experiment, so the well-documented type/cardinality bias
cannot be the explanation; ranger at defaults with mtry, depth and n swept
where they matter; a monotone-relabelling argument for Sec. 6; a Haiku 4.5
screen with an adversarial Sonnet 5 adjudication for Sec. 7.

**Key results.** 1:2.4:7.8 for coefficients 1:2:4 at the default mtry,
approaching 1:4:16 as features compete and as n grows; c gets 1% of the
importance for 1% of the variance in the parity design; 1751/8166/39632 in
both Sec. 5 and Sec. 6 worlds, exactly, with AIR also exact and permutation
/ SHAP agreeing to ~10⁻⁴; extratrees breaks the identity (1:4.9:23.7 vs
1:5.0:24.6), unseeded refits produce only seed noise; 56/331 confirmed.

**Limitations acknowledged.** Regression-only experiments; the Gini-variance
argument carries the caution to classification papers untested; screen is
model judgement with no human ground truth; open-access sample; flags are
about corroboration practice, not correctness. **Unacknowledged**: the
adversarial stage-2 prompt biases toward refutation by an unmeasured amount
(so 17% is, if anything, an undercount, but the direction is asserted rather
than measured); no related-work engagement with the linear-model
importance-decomposition literature (see W2).

---

## Numerical and consistency checks

**Sections 2–6: every cited number reproduces.** Checked against this run's
output: Sec. 2 — OOB R² 0.98; 1:2.39:7.76 and 1:6.23:25.9; mtry sweep
1:2.25:7.26 / 1:3.93:15.5 / 1:4.45:19.1; AIR 1:4.4:17.5 / 4.1:16.6 /
4.1:16.8; depth 1:12.0:58.3 (mtry = p, depth 4), 1:3.38:12.1 (mtry = 1,
depth 2); n-sweep 1:4.15:17.1, 1:4.01:16.1, 1:3.51:13.7; R² 0.98
(0.96–0.99) vs 0.91 (0.88–0.94), β² better on every seed; RSD 33/11/6%; AIR
c-ratio 10.2–25.9 vs 6.3–8.1; 3/10 perfect rankings, Spearman 0.99 for
both measures. Sec. 3 — OLS 0/0/0.101 at R² 0.01, exact with a·b; total
2525.2, c 1.02%; 451 (SD 29) vs 15, share 1.6% (= 15/(2·451+15) = 1.64%);
spreads 2–20% (median 10%) vs 1–6%; 6/6 same side, SD 0.02 → 0.005,
3–119%; OOB 1.00 vs 0.59; AIR 13.3% vs 29.1%, OOB 0.946. Sec. 4 — 500 /
697 / 799, ≈0.75. Sec. 5 — 1751/8166/39632; 1:4.58:22.4 / 8.90:47.7 /
9.63:52.8; Inf at depth 4, 1:11.5:63.5 at depth 8; β 3.01 / 7.00; Corr
0.9963 / 0.9861. Sec. 6 — permutation 1:9.2:50.3, AIR 1:8.8:47.4 exact,
standardised OLS 1:2.98:6.88 / 1:2.99:6.98, 0.014; identity exact at every
seed, 45 pairs pairwise equal; extratrees 1:4.88:23.73 vs 1:5.02:24.64.

**Section 7: every number reproduces** from `tally.py`: 3189 / 773 / 331 /
129 / 56 / 68 / 5; 7.2%, 16.9%; refuted 52.7%, uncertain 3.9%, precision
43.4%; 52/56 = 92.9%; citation medians 11 vs 10; 12 above 50. Table 1 sums
(56 + 68 + 5 = 129).

**Closed forms.** 1/12, 34/45, 457/112 → 1:9.07:48.96; β_equiv 3.01 / 7.00;
Var(c/10)/Var(y) = 0.0099; Corr gaps 2.98/2.99 = 0.997, 6.88/6.98 = 0.986 —
all match.

**Not re-verified this run.** Mean |SHAP| row (1:3.06:6.98, 1.3 × 10⁻⁴) and
the "two observations on 0.3% of nodes" TreeSHAP claim — `treeshap` absent;
last verified in `review2.md`, text unchanged since.

**This session's edit (commit `0717b96`) checked for consistency.** The
proposition's hypotheses were relabelled ((i) = shared RNG draws, (ii) =
order-only splits). Every remaining reference is consistent: `confound.tex:42`
(i) → RNG, `:50` (ii) → split search, `:85` (i) → permutation draws fixed;
`validate.R:602-608` comment matches. The Galili & Meilijson sentence now
says their result is about *predictions for new observations* and rests on
midpoint interpolation; their abstract confirms both ("predicting new
observations with values that were not seen in the training-set and are close
to the location of the split point"; midpoint recommended as the
interpolation). Accurate.

**Internal references.** All resolve. **Citations.** 20 bib entries, all
cited, none dangling; `\citet`/`\citep` used consistently.

**Acronyms.** PDP is first used at `interactions.tex:100` ("joint PDP")
without expansion; the expansion "partial-dependence plot" first appears
in the abstract and again at `confound.tex:144`, but "PDP" is never
introduced. ALE (`confound.tex:150`), OOB (`linear.tex:5`) and OLS
(`linear.tex:13`, table header) are also never expanded. MDI and AIR are.

**Text vs. its own claims — two places where a word overstates.**

- Abstract: "standardised regression coefficients spread similarly." Sec. 6's
  table has them at 1:2.98:6.88 against MDI's 1:4.7:22.6 and permutation's
  1:9.2:50.3 — a spread on the square-root scale, not a similar one. "also
  spread" or "spread too, one power lower" is what the table supports.
- Conclusion: "That last identity is provable, and it holds for permutation
  importance too." The proposition covers MDI and AIR exactly; permutation
  agrees to ~10⁻⁴ (Sec. 6 says so carefully). "holds to four figures" or
  "extends to" would keep the conclusion inside the section.

---

## Critical analysis

**Novelty — medium, honestly framed.** The paper says so itself
(`background.tex:30-38`): the β² identity is Scornet's, the type bias is
Strobl/Nembrini's; the new pieces are the exact skew-vs-nonlinearity
proposition with its falsifiable hypotheses, the measure-independence table,
and the prevalence estimate. Those are real. What is missing is the nearest
antecedent in the paper's own target venue (W2).

**Soundness — high.** The designs isolate what they claim to isolate; the
noiseless response is the right choice for the β² question and the paper
says why Scornet's fully-grown-tree warning does not apply. The proposition
is stated with hypotheses and both are shown to bite (seed sweep; extratrees).
Seed dependence is handled throughout (means over 1–10, ranges reported,
AIR's single-draw caveat repeated where it matters). Sec. 7's two-stage design
is the right shape for an LLM screen and its limitations paragraph is candid.

**Significance — high for practitioners, moderate for theory.** The
practical-implications paragraphs are the most useful part of the paper for a
TAS reader; the one-in-six figure gives the caution weight.

**Clarity — good, with residue.** The Sec. 6 restructuring this session helps:
both hypothesis paragraphs now open with what the failure costs. Several
sentences flagged in the previous review are still in place (Minor issues).

**Reproducibility — exemplary.** Every number in Secs. 2–7 comes out of two
scripts; both masters build in CI; prompts and per-paper records are in the
repo. Two gaps: the PDP claims in the Sec. 3 and Sec. 6 implications
paragraphs are not scripted (verified by hand in the last review), and the
SHAP row depends on an optional package.

**Related work — the weakest dimension.** See W2.

**Venue alignment (TAS).** Length (25 pp. in TAS format, 13 pp. in the main
master) and tone fit. The uncited TAS antecedent (W2) is the one thing a TAS
editor will notice immediately.

---

## Strengths

- **S1 — Everything reproduces.** 40-odd cited quantities across five
  experimental sections and a 773-paper screen, all regenerated from two
  scripts in this review with no discrepancy. This is well above the norm.
- **S2 — The proposition is stated so it can fail, and then it is made to
  fail.** Hypothesis (i) is dropped (unseeded refits → seed noise, shown
  pairwise over 45 seed pairs) and hypothesis (ii) is dropped (extratrees →
  3% separation). The reader is told exactly what carries the identity.
- **S3 — The confound is shown to be measure-independent with the right
  gradation.** Exact for MDI and AIR, 10⁻⁴ for permutation and SHAP,
  10⁻² for the OLS control — and the paragraph at `confound.tex:118-128`
  explains why that *spread* of agreement, rather than any single row,
  identifies the mechanism.
- **S4 — Designs that pre-empt the obvious objection.** All-continuous or
  all-binary, uncorrelated features, so the type/cardinality bias cannot be
  what is being shown.
- **S5 — Advice sits next to its evidence.** Each section ends with what a
  practitioner should do about what they just saw, and nothing is recommended
  that the paper has not measured.
- **S6 — Sec. 7's precision filter and conservatism arguments** (adversarial
  stage 2; SHAP counted as corroboration can only suppress flags) are the
  right kind of honesty about an LLM screen.

## Weaknesses

- **W1 — Sec. 7 credits permutation importance as corroboration; Sec. 6 says
  it cannot corroborate.** Carried over from the last review, still open.
  `prevalence.tex:46-48` defines corroboration to include permutation
  importance; `confound.tex:141-142` says "no marginal importance can say
  which — not plain or debiased impurity, not permutation". The paper already
  handles the identical objection for mean |SHAP| (`prevalence.tex:52-57`) by
  arguing the generous count is conservative. One clause extending that
  paragraph to permutation importance closes the gap and *strengthens* the
  conservatism claim. A referee who reads Sec. 6 first will raise this.
- **W2 — The linear-model importance-decomposition literature is absent, and
  its nearest item is a TAS paper.** Grömping (2009), *The American
  Statistician* 63(4), "Variable importance assessment in regression: linear
  regression versus random forest", compares RF importance against
  R²-decomposition importances — the direct antecedent of Secs. 2 and 5's
  "importance is variance-explained" reading, seventeen years old, in the
  target venue, uncited. Bénard, Da Veiga & Scornet's Sobol-MDA (2022) targets
  the same quantity from the permutation side and bears on Sec. 6's
  permutation row. Neither undermines the paper; both belong in the Background
  "two strands" paragraph, and their absence is the first thing a TAS
  associate editor will note. (Both were raised in the earlier panel review
  `ai-review.md` and have not been actioned.)
- **W3 — The prevalence estimate has no human anchor.** The limitations
  paragraph says so, but the headline (17%, in abstract and conclusion) is a
  two-model agreement rate with an adversarial second stage whose refutation
  bias is asserted to run one way and never measured. A small blind human
  audit — say 20 confirmed and 20 refuted, read against the three conditions
  — would turn "unvalidated estimate" into an estimate with an error bar, and
  would settle whether the adversarial prompt over-refutes. It is the single
  addition that would most change how Sec. 7 is received.
- **W4 — Regression-only experiments, classification-inclusive conclusion.**
  Sec. 7 does not record the classification/regression split of the 331, and
  the Background's Gini-as-variance identity is what carries the caution
  across; the paper says this. The proposition itself is
  classification-agnostic (order-only splitting is order-only whatever the
  impurity), so a one-block classification replication of Sec. 6 — threshold
  y at its median, `probability = TRUE` — would cost a few lines and turn the
  stated limitation into a demonstrated one.
- **W5 — Two overstatements at the paper's boundaries** (abstract's "spread
  similarly"; conclusion's "holds for permutation importance too") — detailed
  under consistency checks above. Both are fixable with one word each, and the
  abstract and conclusion are the two places a referee reads most carefully
  for claims the body does not support.
- **W6 — Wording debris from earlier rewrites, all previously flagged, all
  still present.** Sec. 5 `nonlinear.tex:36` "This is a truncation effect"
  follows an mtry-dilution paragraph and refers to depth truncation at
  mtry = p — the connective points the wrong way. Sec. 3
  `interactions.tex:59` and `:64` say the same sentence twice five lines
  apart ("every tree re-derives the same choice/allocation from the same
  data"). Sec. 6 `confound.tex:13-17`: `--` where the paper uses `---`, a
  missing "the" before "non-linear model", and a commented-out line in the
  middle of the sentence. `confound.tex:37-40` largely repeats the bridge at
  `:19-21`. `confound.tex:82` "pinned by the proposition" for four measures
  of which two are pinned approximately.

## Questions for authors

- **Q1** — Of the 331 impurity users, how many are classification models? A
  count from the extraction records (if the field exists) would let Sec. 7
  say how much of the 17% rests on the Gini-as-variance carry-over.
- **Q2** — What does the stage-2 refutation rate look like when the prompt is
  neutral rather than adversarial, on a subsample? Even 30 papers would
  bound the direction-of-bias claim.
- **Q3** — Sec. 3 says "trees grown to purity remove n Var(y) between them"
  and reports the total as 2525.2 = n Var(y); the sample n·Var(y) is 2525.9
  and min.node.size = 5 means leaves are not pure. Is the residual the
  bootstrap averaging, the node-size floor, or both? "≈" and a half-clause
  would pre-empt the question.
- **Q4** — The 'central to a stated conclusion' condition is doing most of
  the work in stage 2. How was "central" operationalised in the prompt, and
  is there an example of a paper refuted on that condition alone?

## Minor issues

- `\date{July 2026}` on the title page; the screen was extended in September
  and the method paragraph says both models were accessed in July and
  September.
- Acronyms PDP, ALE, OOB, OLS never expanded at first use (locations above).
- `interactions.tex:24` "Random Forest" capitalised; lower case elsewhere.
- `interactions.tex:33` "= n Var(y)" for 2525.2 vs 2525.9 → "≈".
- Fig. 1 caption "R² = 0.99" is the single-seed value; the text reports a
  mean of 0.98. "(seed 1)" in the caption avoids a referee's double-take.
- Sec. 7 `\section` has no `\label`; its two subsections do. Harmless, but
  Sec. 1's forward reference has to name the subsections instead of the
  section.
- Sec. 6's implications paragraph runs 18 lines against 6–8 for the other
  three; the two TreeSHAP sentences could be a footnote.
- **Repository.** `analysis/candidates.csv` (125 rows) and
  `analysis/confirmed_candidates.csv` (55 rows) date from 2026-07-03, have no
  generating script, and disagree with the records (129 / 56); Sec. 9 points
  readers at the records. Regenerate from `tally.py` or delete.
  `analysis/results.md` is a log whose body still carries 544-era numbers
  under a correct update note. `ai-review.md` at repo root is an earlier
  panel review, untracked. The Availability section could name `tally.py`
  as the one-line reproduction for Sec. 7, parallel to what it says for
  Secs. 2–6.
- **Working tree (uncommitted, not part of this review's target).** The
  title change in both masters drops `{\LARGE\bf ...}` from the TAS
  non-anonymous title block, so that variant will typeset the title at body
  size. Restore the wrapper before committing.

## Venue-specific recommendations (TAS)

- **V1** — Cite and position against Grömping (2009), TAS. An associate
  editor at the journal will know the paper.
- **V2** — TAS readers will want the one-in-six figure qualified in the
  abstract the way the Limitations qualify it: "model-judged" or "LLM-screened"
  is already there ("LLM-powered screen ... suggests"), which is good; keep
  "suggests" and resist any tightening of it.
- **V3** — The practical-implications paragraphs are the TAS-shaped part of
  the paper. Consider a two-line summary of them in the Conclusion (which
  currently ends on "It misleads when read as an effect size" without saying
  what to do instead beyond "paired with partial-dependence plots").

## Possible enhancements

Ranked by expected value against cost.

1. **Human audit of a stratified sample of adjudications** (W3). Highest
   value; a day's reading. Gives Sec. 7 an error bar and tests the
   refutation-bias direction.
2. **Classification replication of Sec. 6** (W4). One `validate.R` block;
   turns a stated limitation into a shown one. The proposition guarantees the
   result, which is the point: the reader sees it hold where the Gini
   argument was only asserted.
3. **Script the PDP claims** (Sec. 3 joint-PDP parity; Sec. 6 straight line
   vs curve) as a `validate.R` block, so the two implications paragraphs are
   backed like everything else. Verified by hand last review; ten lines of R.
4. **Report the classification/regression split** of the 331 impurity users
   from the extraction records, if the field exists (Q1).
5. **A sentence on the 249 filter-rejected papers**: 1 of 249 confirmed
   against 55 of 524 — the filter's design predicts exactly this, and saying
   so pre-empts "did screening the rest change anything?"

## Platform and workload assumptions

The systems-review question, translated. Everything here is stated somewhere
in the paper; this collects it so a reader can see what the conclusions are
conditional on.

- **Implementation.** ranger 0.18.0 only. The proposition is implementation-
  agnostic given order-only splitting, and `randomForest`, scikit-learn and
  XGBoost's exact mode all satisfy it; the *quantitative* compression figures
  (1:2.25:7.26 at default mtry, etc.) are ranger-default-specific
  (mtry = ⌊√p⌋, min.node.size = 5, bootstrap with replacement). Sec. 2 says
  so for mtry; min.node.size is never mentioned in the text.
- **Defaults as the object of study.** The paper deliberately reports what a
  user who accepts defaults sees, then sweeps. That is the right framing for
  a caution paper and it is consistent throughout.
- **Data-generating assumptions.** Noiseless y (justified against Scornet);
  independent features (justified; the PDP caveat under dependence is
  given); uniform inputs (Scornet's condition; the closed forms depend on
  it); n = 1000 / 10000 with n-sweeps where the asymptotics matter.
- **The literature "workload".** ranger-citing, open-access, Europe PMC
  full text — so life-sciences-heavy by construction. The Limitations say
  "may not generalise"; a one-line field breakdown of the 773 (OpenAlex
  supplies concepts) would let the reader judge how far.
- **Trend.** The paper's remedy is shape-aware plots. Its own Sec. 6 shows
  SHAP dependence plots separate the worlds while mean |SHAP| does not, and
  Sec. 7 finds SHAP increasingly reported. As global SHAP bar charts replace
  MDI bar charts in applied work, the misreading the paper documents migrates
  to a measure the screen currently counts as corroboration (W1's sibling,
  already conceded for SHAP at `prevalence.tex:52-57`). Worth one forward-
  looking sentence in the Conclusion.

---

## Overall assessment

**Minor revision.** The technical content is sound and — unusually — fully
reproducible from the repository; the proposition is correctly scoped and its
hypotheses are shown to be load-bearing; the prevalence screen is designed
and caveated honestly. Nothing found changes a conclusion. What stands
between this and acceptance at a venue like TAS is (a) one internal
inconsistency a referee will find (W1), (b) a related-work gap that lands in
the target journal's own back catalogue (W2), (c) two boundary overstatements
in the abstract and conclusion (W5), and (d) a layer of wording debris that
has now survived two reviews (W6). All four are hours, not days. The human
audit (W3) is the one item that would move the paper from "careful" to
"validated" and is the reviewer's strongest recommendation beyond the
required fixes.

## Top actions — start here

- **T1** — Extend the "Counting SHAP as corroboration is generous" paragraph
  (`prevalence.tex:52-57`) with one clause covering permutation importance,
  citing Sec. 6. Closes W1, strengthens the conservatism claim.
- **T2** — Add Grömping (2009) and Bénard–Da Veiga–Scornet (2022) to the
  "two strands" paragraph in Background. Closes W2 / V1.
- **T3** — Abstract: "spread similarly" → "spread too, one power lower".
  Conclusion: "holds for permutation importance too" → "extends to
  permutation importance to four significant figures". Closes W5.
- **T4** — `nonlinear.tex:36`: replace "This is a truncation effect:" with
  "Depth truncation is also stronger here than in Section 2:".
- **T5** — `interactions.tex:59`: delete "so every tree re-derives the same
  choice from the same data" (the `:64` copy does the work).
- **T6** — `confound.tex:13-17`: `--` → `---`, insert "the", remove the
  commented line. `:82` "pinned by" → "follow from".
- **T7** — Expand PDP, ALE, OOB, OLS at first use; lower-case "Random
  Forest" at `interactions.tex:24`; "=" → "≈" at `:33`.
- **T8** — `\date{July 2026}` → September; regenerate or delete the two
  stale CSVs; name `tally.py` in the Availability section.
- **T9** — Add the two PDP checks as a `validate.R` block (enhancement 3).
- **T10** — Plan the stratified human audit (enhancement 1); even a
  20 + 20 sample with a stated κ would answer the question every referee of
  Sec. 7 will ask.

## Confidence

**High** on Sections 2–6 and on Section 7's arithmetic: every number was
regenerated in this review and matched. **High** on the internal-consistency
findings: each is a pair of line references the reader can check. **Medium**
on related work: the two missing citations come from an earlier panel's
literature check, confirmed here by their absence from the bibliography; no
fresh systematic search was run. **Medium** on Section 7's substance: the
tally reproduces, but no adjudication record was re-read against its paper
this time (one was, last review). **Not verified**: the mean |SHAP| row and
the TreeSHAP node-cover claim (`treeshap` not installed; unchanged since
`review2.md`).
