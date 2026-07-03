# When impurity importance misleads: interactions, non-linearity, and feature scale

**Christian Theil Have**

*Original note: 17 May 2022. Validated and rewritten: July 2026.*

## Abstract

Mean-decrease-in-impurity (MDI) variable importance is the default, cheapest way
to read a random forest, and it is routinely compared, informally, to the
coefficients of a linear model. This paper examines when that comparison breaks
down. Through five controlled experiments (all reproduced with `ranger`) we show
that impurity importance (i) orders linear effects correctly but magnifies them
super-linearly, (ii) charges interaction effects to the interacting variables,
even when those variables have no marginal effect at all, and (iii) — the central
result — *cannot distinguish a genuinely non-linear effect from a linear effect
acting on a skewed feature*. The two produce identical importances. The root
cause is that regression trees split on variance reduction, and variance is not
scale-invariant. We argue that impurity importance should be read as a detector
of *structure worth investigating*, not as an effect-size estimate, and that
partial-dependence plots recover the distinction that importance discards.

## 1. Background

For a random forest, the impurity importance of a feature is the total decrease
in node impurity attributable to splits on that feature, summed over all splits
and all trees. For classification the impurity is Gini; for regression there is
no class label at a node, so `ranger` (and most implementations) use **response
variance** as the impurity proxy — a split is scored by how much it reduces the
sum of within-child variances. This substitution is the source of every effect
studied here.

Impurity importance is known to be biased: it favours continuous and
high-cardinality features and inflates the importance of correlated predictors
(Strobl et al. 2007; Nembrini et al. 2018, *The revival of the Gini importance?*,
which introduces the bias-corrected "actual impurity reduction", AIR, exposed by
`ranger` as `importance = "impurity_corrected"`). The question here is narrower
and more practical: **if I line up impurity importances next to OLS
coefficients, when will I be misled?**

All experiments use `ranger` 0.18.0; the driver is
[`analysis/validate.R`](../analysis/validate.R) and figures come from
[`analysis/figures.R`](../analysis/figures.R). Unless noted, importances are the
plain `impurity` measure (the one the definition above describes); §2.1 compares
it against `impurity_corrected`.

## 2. Linear effects: right order, wrong magnitude

Data: `y = a + 2b + 4c`, with `a,b,c ~ U(0,1)`, n = 1000. OOB R² = 0.98.

Impurity importance ranks the features in the correct order, but the *ratios*
are distorted:

| feature | OLS coef | impurity vip (ratio) | impurity_corrected (ratio) |
|--------:|:--------:|:--------------------:|:--------------------------:|
| a       | 1        | 1.00                 | 1.00                       |
| b       | 2        | 2.32                 | 5.31                       |
| c       | 4        | 7.79                 | 23.1                       |

A coefficient ratio of 1:2:4 becomes an importance ratio of 1:2.3:7.8. The
magnification is **super-linear**. Extending to `y = a + 2b + 3c + … + 11k` (11
features, coefficients 1…11) and regressing importance on effect size, a linear
fit gives R² = 0.91 while a quadratic fit gives R² = 0.97 (Fig. 1). Importance
scales roughly with the *square* of the coefficient, because a feature with a
larger coefficient contributes more variance per split *and* is chosen for more
splits.

Note the bias correction makes this **worse**, not better: `impurity_corrected`
de-biases null (no-effect) features but does not restore scale-invariance among
real effects — its ratios (1:5.3:23) are more extreme than plain impurity's.

![Fig. 1](../figures/fig1_superlinear.png)

*Fig. 1 — Impurity importance vs. linear coefficient. The quadratic fit
(red) dominates the linear fit (blue dashed).*

**Takeaway.** Importance answers "which feature matters more" reliably for linear
effects, but "how much more" is not comparable to a coefficient.

## 3. Interactions are charged to the interacting variables

Data: a pure parity interaction with no marginal effects,

```
y = c/10 + ((a + b) mod 2),   a,b,c ∈ {0,1},   n = 10000.
```

`a` and `b` individually carry no information about `y`; only their parity does.
`c` has a small independent effect.

- **OLS** is blind: R² = 0.01, and the fitted coefficients for `a` and `b` are
  exactly 0 (only `c` survives, coef ≈ 0.10). A standard `a*b` product term does
  not rescue it — the interaction is non-linear (parity), not the bilinear form
  OLS interaction terms assume.
- **Random forest** captures it: OOB R² = 0.63. And the impurity importance
  loads almost entirely on the interacting variables: vip(a) = 483, vip(b) = 503,
  vip(c) = 16 (Fig. 2). The interaction variables outrank the one variable with a
  genuine marginal effect by ~30×.

![Fig. 2](../figures/fig2_interaction.png)

*Fig. 2 — Same data, two views. OLS assigns `a`,`b` zero coefficient; RF impurity
importance ranks them highest.*

**Takeaway.** A high impurity importance does **not** imply a detectable marginal
effect. This is a feature, not a bug: importance surfaces variables that matter
only in combination — precisely the ones a naive linear model drops. But it means
importance and coefficients measure different things.

## 4. Why variance-splitting favours large-scale, non-linear structure

Take a noise-free, sorted dataset and sweep every possible single split,
scoring each by the sum of within-child variances. For `y = x`, `y = x²`,
`y = x³` (x = 1…1000):

| response | min split-variance | argmin index (of 1000) |
|:--------:|:------------------:|:----------------------:|
| x        | 4.2 × 10⁴          | 500 (centre)           |
| x²       | 4.3 × 10¹⁰         | 697                    |
| x³       | 4.1 × 10¹⁶         | 799                    |

Two mechanisms compound:

1. **Scale.** The achievable variance reduction grows by orders of magnitude with
   the polynomial degree. Splits driven by high-order (large-range) structure
   dominate the split-selection criterion, and each such split books a larger
   impurity decrease.
2. **Imbalance.** For a linear response the best split is central; for higher
   orders the optimal split migrates toward the high-`y` tail (index 500 → 697 →
   799). Unbalanced splits leave more structure in the large child, so *more*
   splits are needed — and every one of them is charged to the same feature.

Variance is not scale-invariant, so whatever varies on the largest scale wins
twice.

## 5. Non-linear effects (§4 confirmed on real forests)

Data: `y = a + b² + c³`, features `~ 1+U(0,1)`, n = 10000. As predicted,
vip(a) < vip(b) < vip(c): 1780 < 8168 < 39570. Importance rises faster than the
degree of the term. A linear model still estimates non-zero coefficients here,
but they are uninterpretable — the residuals are visibly non-normal, signalling
the misspecification.

## 6. The central confound: non-linearity vs. feature scale are indistinguishable

This is the result that should change how the measure is read. Construct data
with **exactly equal linear effects**, but skewed feature *distributions*:

```
a = 1 + U,   b = (1 + U)²,   c = (1 + U)³,   y = a + b + c,   n = 10000.
```

Every feature enters `y` with coefficient 1. OLS confirms it: fitted coefficients
are 1.00, 1.00, 1.00. Each unit increase in `a`, `b`, or `c` moves `y` by one
unit — there is nothing non-linear about the *effects*.

Yet the random forest reports importances of **1780 / 8168 / 39570** — a 1:4.6:22
spread. These are not merely unequal; they are **numerically identical** to the
non-linear-effects model of §5 (Fig. 3). The forest cannot tell the two
generating processes apart, because both present the same *marginal variance
structure* to the splitting criterion: a feature whose values are spread over a
cubic range delivers the same variance-reduction opportunities whether the
cubic lives in the effect (`c³`) or in the feature (`c ~ U³`).

![Fig. 3](../figures/fig3_confound.png)

*Fig. 3 — Identical importances from two different worlds. Left: genuinely
non-linear effects. Right: linear effects on skewed features. Impurity importance
cannot distinguish them.*

A split-variance sweep on the skewed-feature data confirms the mechanism: median
achievable split-variance is lowest for `c` (4.4) and highest for `a` (9.8), so
`c` is split earlier and more often — matching the importance ranking, even
though `c`'s effect on `y` is no larger than `a`'s.

**Takeaway.** Impurity importance conflates *effect non-linearity* with *feature
skew*. A tall importance bar can mean "this feature has a strong/non-linear
effect" **or** merely "this feature has a wide/heavy-tailed distribution." The
measure alone cannot say which.

## 7. Practical guidance

1. **Read impurity importance ordinally, and only among comparable features.**
   Treat it as a ranked shortlist of variables worth investigating, not as an
   effect size. Never place its magnitudes alongside OLS coefficients as if they
   were the same currency.
2. **A high bar is a prompt, not a conclusion.** It may reflect a marginal
   effect, an interaction (§3), a non-linear effect (§5), or nothing but a skewed
   feature distribution (§6).
3. **Disambiguate with partial-dependence plots.** PDPs recover exactly what
   importance discards: in §6 the skewed-feature model's PDPs are straight lines
   while the non-linear model's curve — same importances, different shapes. PDPs
   also expose the checkerboard signature of the §3 interaction that per-feature
   importance flattens. Curvature in a PDP is a concrete cue to add a polynomial
   or interaction term back into an interpretable model.
4. **`impurity_corrected` fixes a different problem.** It removes the bias toward
   null / high-cardinality features (use it — it is the right default), but it
   does not make importances scale-comparable across real effects; if anything it
   widens the spread (§2).
5. **If you know the structure is linear, use the linear model.** Random forests
   buy you interaction- and non-linearity-detection; when there is nothing to
   detect, OLS is both more accurate and directly interpretable.

## 8. How often does this happen in practice?

To gauge whether the pitfall is real in the wild, we audited the published
literature that uses the tool most associated with these importances — the
`ranger` R package. Full method and numbers are in
[`../analysis/results.md`](../analysis/results.md); the short version:

- **Corpus.** All 3,189 works citing ranger (OpenAlex `W2157395790`), fetched via
  the OpenAlex and Europe PMC APIs; 773 have open-access full text. A versioned
  regex filter (`analysis/fingerprint.py`) kept the 524 that mention
  variable/feature/impurity importance (dropping papers that cite ranger only for
  speed or prediction); 544 were screened in total.
- **Stage 1 — screening (Claude Haiku 4.5, low effort).** One agent per paper read
  the full text and emitted a structured record. It was told the specific bias
  under audit — *impurity importance corrupts the magnitude and ranking of an
  effect, not the yes/no verdict of whether a variable is used; a significant
  importance p-value (Altmann/Janitza/Boruta) tests only that importance ≠ 0,
  which is robust* — and instructed to set the flag (`p_affected ∧
  central_to_conclusions`) true only when a paper leans on the **magnitude or
  ranking** of impurity importance for a central conclusion **without** adequate
  corroboration, where adequate corroboration = permutation importance, SHAP,
  PDP/ALE, conditional importance, or held-out validation of the *selected feature
  set* (overall model accuracy does not count). Every judgement had to quote
  supporting passages. 125 papers were flagged.
- **Stage 2 — adjudication (Claude Sonnet 5, high effort).** A second, independent
  agent re-read each flagged paper under an explicitly **adversarial** instruction:
  *your job is to refute this flag.* It confirmed only when all three held — the
  paper genuinely uses impurity (not only permutation/SHAP) importance, the
  ranking is central to a conclusion, and the ranking is not adequately
  corroborated — and was told to reach its own verdict rather than defer to
  stage 1. It returned `confirmed` / `refuted` / `uncertain` with reasons.
- **Result: 55 confirmed, 65 refuted, 5 uncertain** — the adversarial pass
  overturned ~56% of the screening flags (so stage-1 precision ≈ 44%). The 55
  confirmed are **~10% of the importance-using full-text papers** — roughly 7% of
  all full-text ranger-citing work. The full prompts, per-paper records, and
  verdicts are in `analysis/` (`extract_broad_workflow.js`,
  `adjudicate_workflow.js`, `extraction/`, `adjudication/`).
- **The exposure is not in the careful literature.** 86% of flagged papers use no
  significance machinery at all (no `importance_pvalues`, Altmann, Janitza, or
  Boruta) — they simply rank features by impurity importance. Papers that *do*
  use those methods, and the rising share (~0% → ~70% over 2016–2026) that pair
  importance with SHAP/permutation/PDP, are markedly less exposed.
- **It reaches high-impact work.** The single most-cited confirmed case is
  **SoilGrids250m** (Hengl et al., *PLoS ONE* 2017; 4,684 citations), a global
  soil-property product whose covariate ranking is read straight off
  ranger/xgboost built-in importance. Tellingly, the authors note lithology
  visibly drives predictions yet falls outside the top-15 importance list — the
  exact signature of §4/§6, a low-cardinality categorical under-weighted against
  fine-grained continuous covariates.

Caveats: these are LLM screening judgements, not audits of each study's data — a
confirmed flag means a conclusion *could* have been distorted and was not
cross-checked, not that it is wrong. Predictive accuracy, validated separately, is
unaffected. Proving a specific ranking is altered requires re-running the study's
model with an unbiased measure.

## 9. Conclusion

Impurity importance is a variance-reduction accounting, and variance is neither
scale-invariant nor able to separate an effect's shape from a feature's
distribution. Consequently it magnifies effect sizes super-linearly, attributes
interaction effects to marginally-null variables, and — most importantly —
returns identical scores for genuinely non-linear effects and for linear effects
on skewed features. Every claim in the 2022 note reproduces cleanly, and a
literature audit (§8) confirms the pitfall is not merely theoretical: ~10% of
importance-using ranger papers — including foundational, heavily-cited products —
lean on impurity rankings without the corroboration that would catch it. Used as a
*screening* tool and paired with partial-dependence plots to interrogate the
shortlist, impurity importance is valuable; read as a substitute for effect sizes,
it will mislead.

## Reproducing

```
brew install r
R_LIBS_USER=./.rlib Rscript -e 'install.packages(c("ranger","tibble","pdp"), repos="https://cloud.r-project.org")'
R_LIBS_USER=./.rlib Rscript analysis/validate.R    # prints every number cited above
R_LIBS_USER=./.rlib Rscript analysis/figures.R     # regenerates figures/
```

## References

- Nembrini, König, Wright (2018). *The revival of the Gini importance?*
  Bioinformatics 34(21). [PMC6198850](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6198850/)
- Strobl, Boulesteix, Zeileis, Hothorn (2007). *Bias in random forest variable
  importance measures.* BMC Bioinformatics.
- Scheidel (2018). *Be aware of bias in RF variable importance metrics.*
- Lee (2017). *Feature Importance Measures for Tree Models — Part I.*
