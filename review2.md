# Deep review of `paper/impurity-importance.tex`

*Claims audit + narrative evaluation, 2026-08-13. Methods: fresh run of
`analysis/validate.R` (ranger 0.18.0), independent hand-derivation of the math,
audit of the corpus/extraction/adjudication data files against every number in
Section 8, web verification of all 17 references and their in-text
attributions, plus two new targeted experiments (prediction identity across the
Section 6 worlds; TreeSHAP cover differences).*

## Verdict

The paper is in very good shape. Every number that could be checked — all five
experiments, all prevalence-pipeline counts, all references — reproduces or
verifies. The findings below are ranked by importance; only the first is
substantive.

## Claims audit

**Experiments (Sections 2–6).** `validate.R` was run end to end and every
cited number cross-checked: the 1:2.39:7.76 single-seed table, the mtry sweep
(1:2.25:7.26 / 1:3.93:15.5 / 1:4.45:19.1), the AIR ratios and their 10.2–25.9
vs 6.3–8.1 seed ranges, the β² regression (0.977, range 0.959–0.994 vs 0.907,
range 0.884–0.938, β² wins on every seed), the parity experiment (398 ± 51 vs
23, spread 7–72% median 28%, control 3–11%), the split-mechanics table (argmin
500/697/799, fraction ≈ 0.75), the 1751/8166/39632 identity, the cross-world
table (permutation 1:9.2:50.3, AIR 1:8.8:47.4 pinned at exactly 0, SHAP
1.3×10⁻⁴, standardised OLS 1.4×10⁻²), the seed sweep (exact at all 10 seeds,
45/45 pairwise-equal gaps, noise 0.1–2.7%), and extratrees (~3.3%). All match
the paper to the stated precision.

Independently re-derived and confirmed: the Gini-as-indicator-variance
identity; the variance-contribution ratio 1:9.07:48.96 for U(1,2) features
(Var = 1/12, 34/45, 457/112); Corr(X,X²) = 0.9963 and Corr(X,X³) = 0.9861
(Cov(X,X²) = 1/4, Cov(X,X³) = 23/40); √(1:9.07:48.96) = 1:3.01:7.00; the
2.98/2.99 = 0.997 and 6.88/6.98 = 0.986 reproduction of the correlation gaps.

The one number `validate.R` does not compute — TreeSHAP covers differing "by at
most two observations on 0.3% of nodes" — was verified separately: 3,926 of
1,288,646 nodes (0.30%), max absolute difference exactly 2. Worth adding to
`validate.R` so every cited number is script-backed.

**Prevalence (Section 8).** Verified against the raw JSONs, not just
`analysis/results.md`: 3,189 manifest rows; 773 fulltext files; the paper's
regex, re-implemented verbatim from the LaTeX, matches exactly 524 of 773; 544
extraction records = 524 matches + 16 `rejected_sample` + 4 `survivor`; 307
with `uses_impurity_importance`; 125 with `p_affected ∧ central`; adjudication
verdicts 55/65/5; the 40-paper probe gives exactly 24 impurity-users and 11
flags; the confirmed-set breakdown is 51 `none` + 3 `altmann` + 1 `boruta`
(51/55 = 93%); confirmed-set citation median 11, screened-set median 10, and
exactly 12 confirmed papers exceed 50 citations. 55/544 = 10.1%, 55/307 =
17.9%, 55/773 = 7.1% all check out.

**References.** All 17 bibliographic entries are correct (nit: `nembrini2018`
could add pages 3711–3718). OpenAlex `W2157395790` confirmed via the API as
Wright & Ziegler 2017, now at 3,368 citations — consistent with 3,189 at a
July 2026 snapshot. Galili & Meilijson, Bring, Hooker (including the
PDP-extrapolation claim), Apley & Zhu, and the Friedman-for-PDP cite are all
fairly attributed.

## Findings (ranked)

1. **The Proposition's conclusion overclaims, and the paper's own table shows
   it** (Section 6). "The two forests are identical tree for tree, and every
   importance derived from them coincides exactly" — but permutation
   importance, which is derived from those forests, agrees only to ~10⁻⁴ in
   the table three paragraphs below. The reason: the forests are identical as
   *partitions of the training sample*, but not as prediction functions —
   split thresholds are midpoints between adjacent in-bag values, and a value
   interior to that gap (an OOB point during permutation, or a shuffled value)
   can land on different sides of the midpoint in the two worlds, since the
   midpoint of squares is not the square of the midpoint. Empirically
   confirmed: training-set predictions differ between the two worlds (max abs
   diff 0.017) even while MDI is pinned at exactly 0. Fix by scoping the
   conclusion: the trees are identical as in-bag partitions, and every
   importance that is a functional of those partitions (MDI, AIR) coincides
   exactly. The later prose about permutation/SHAP "touching feature values at
   the thresholds" is exactly right — the Proposition statement just needs to
   stop claiming *every* importance. As written, a careful referee will notice
   the theorem is contradicted by the table below it.

2. **"OLS OOB $R^2 = 0.98$" (Section 2) mislabels the statistic.** OOB R² is a
   forest quantity; `validate.R` prints it as "OOB R^2 (impurity model)". It
   should read "RF OOB $R^2 = 0.98$".

3. **One misattribution** (Section 1): Strobl 2007 and Nembrini 2018 are
   credited with documenting that MDI "inflates correlated predictors." Both
   are about the type/cardinality bias; the correlated-predictor problem
   belongs to Strobl et al. 2008 (already cited) or Hooker et al. 2021. Move
   or drop that clause.

4. **The availability section promises "the relevance filter," but the
   broadened regex exists only in the paper text.** The repo has only the
   earlier narrow `fingerprint.py` (the p-value fingerprint, 158 survivors). A
   re-implementation of the LaTeX regexes reproduces exactly 524, so the paper
   text is a faithful spec — but the filter should live in `analysis/` as
   code.

5. **The Scornet citation could carry one more clause** (Section 1): the
   Var(f_j(X_j)) identity is a population-level result for fully developed
   trees, and Scornet explicitly cautions that empirical MDI of fully grown
   trees is inconsistent. The usage is fair, but since Section 6 leans on the
   identity for finite-sample predictions, a parenthetical "(a population
   identity, for fully developed trees)" would make it referee-proof.
   Similarly, "for totally randomized trees" would be a fair-minded addition
   to the Louppe one-liner.

6. **"a corpus median of 10" (Section 8) is ambiguous.**
   `citation_counts.json` covers only the 544 screened papers, so the
   comparison is confirmed-vs-screened, not vs the 3,189-work corpus (for
   which the repo holds no citation data). Say "screened-set median."

7. **Minor points.**
   - The Section 4 sweep scores splits by the *unweighted* sum of child
     variances while ranger's criterion is n-weighted, and `vos()` puts
     `y[idx]` in both children. Neither changes any conclusion
     (`frac_removed` is properly weighted), but the column "raw min
     split-variance" is not exactly ranger's criterion and a picky reader may
     notice.
   - Section 3: the fitted d coefficient is 0.115, so "≈0.10" reads as the
     observed value when it is the true one — "recovering the true 0.1" would
     be cleaner.
   - Section 2: "the spread is not exactly the $1:4:16$, the ratio of the
     squared coefficients that Section 1 predicts" has a grammatical stumble.
   - Section 8: "overturning roughly 56%" counts the 5 uncertain verdicts as
     overturned — defensible, but "refuted 52%, uncertain 4%" is more precise.

## Narrative

The arc is strong and unusually honest. The thesis — one identity, five
consequences — gives every section a job, and the paper repeatedly does the
thing weak papers skip: it pre-empts the deflationary reading (the mtry
explanation for the 1:2.4:7.8 gap, the seed-noise corollary for the unseeded
~1% gap, the standardised-OLS control with the closed-form Corr(b,b²) factor,
the design-specific noise floor in the parity experiment). Section 6 is the
centerpiece and earns it; the "descending strictness" table plus the OLS
control is a genuinely elegant way to identify the mechanism. The limitations
paragraph concedes exactly the right things (single-vendor adjudication, no
human ground truth, regression-only experiments vs mixed corpus).

Three narrative-level suggestions:

- **The abstract promises "five controlled experiments" and then enumerates
  three consequences (i)–(iii).** A reader who counts will stumble. Either
  enumerate five or say "a sequence of controlled experiments."
- **Section 6 is dense at exactly the point where the payoff lands.** The
  paragraph explaining why AIR is pinned (permuting commutes with monotone
  transforms) and the SHAP square-root observation are both load-bearing but
  arrive in one long run of prose between the table and the mechanism
  paragraph. One signposting sentence before the table — the table's third
  column is the evidence; the rest of the section explains its pattern —
  would let a first-time reader survive it.
- **Contrast framing.** The paper leans heavily on "not A but B"
  constructions — the title, "These are not artefacts…", "That is not a
  coincidence… but a theorem", "a response-scale artifact… two things do." A
  few of these are the thesis itself and should stay; several others could be
  stated positively and backed by the adjacent measurement, which the paper
  always has on hand. Worth one pass with that eye.

One repo-hygiene note: the "Caveats" block at the bottom of
`analysis/results.md` still says the Haiku pass is unverified, below a header
that already reports the adjudication — cosmetic, but worth cleaning since the
availability section points readers at the repo.
