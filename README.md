# rf-impurity

Variable importance is variance, not effect size: a caution and a prevalence
screen.

Mean-decrease-in-impurity (MDI) importance is the default, cheap way to read a
random forest, and it is routinely misread as a per-unit effect size. This repo
holds a short paper making that case, the `ranger` experiments behind it, and a
screen of the ranger-citing literature estimating how often the misreading
reaches published conclusions.

## Findings in one paragraph

In additive models MDI estimates each feature's variance contribution,
Var(f_j(X_j)), which for a linear term is beta_j^2 * Var(X_j) (Louppe 2013,
Scornet 2023). Read as an effect size this misleads: importance grows with the
*square* of a coefficient, it assigns an interaction's variance to the
interacting variables, and it gives provably identical scores to a non-linear
effect and to a linear effect on a skewed feature. None of this is specific to
impurity; permutation importance behaves the same way, because no marginal
importance separates an effect's shape from a feature's distribution.
Partial-dependence plots do. An LLM-assisted screen of the ranger-citing
literature suggests about one in six papers that interpret an impurity ranking
rely on it without corroboration.

## Layout

| Path | What |
|------|------|
| [`paper/impurity-importance.tex`](paper/impurity-importance.tex) | The paper (LaTeX; PDF built by CI). |
| [`notebook/impurity-importance.Rmd`](notebook/impurity-importance.Rmd) | Original 2022 R Markdown note. |
| [`analysis/validate.R`](analysis/validate.R) | Reproduces every experiment number cited in the paper. |
| [`analysis/figures.R`](analysis/figures.R) | Regenerates the figures. |
| [`analysis/results.md`](analysis/results.md) | Full literature-screen results and statistics. |
| `analysis/fingerprint.py`, `analysis/extract_*`, `analysis/adjudicate_*` | Corpus filter, screening prompts, adjudication workflow. |
| `analysis/extraction/`, `analysis/adjudication/` | Per-paper structured records and verdicts. |
| `corpus/` | Fetched ranger-citing corpus (manifest + full text) with fetch timestamps. |
| `figures/` | Generated figures. |

## Reproduce

Experiments and figures:

```
brew install r
R_LIBS_USER=./.rlib Rscript -e 'install.packages(c("ranger","tibble","pdp"), repos="https://cloud.r-project.org")'
R_LIBS_USER=./.rlib Rscript analysis/validate.R
R_LIBS_USER=./.rlib Rscript analysis/figures.R
```

Validated with `ranger` 0.18.0 / R 4.6.1. The literature screen is documented in
[`analysis/results.md`](analysis/results.md) and [`analysis/RESUME.md`](analysis/RESUME.md).
