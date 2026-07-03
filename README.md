# rf-impurity

When mean-decrease-in-impurity (MDI) variable importance from a random forest
misleads — and what to do instead.

Impurity importance is the default, cheap way to read a random forest, and it is
routinely eyeballed against linear-model coefficients. This repo starts from a
2022 exploratory note, **validates every claim in it with `ranger`**, and
distills the findings into a concise paper.

## Findings in one paragraph

Impurity importance orders linear effects correctly but magnifies them
super-linearly; it charges interaction effects to the interacting variables even
when those have no marginal effect; and — the key result — it **cannot
distinguish a genuinely non-linear effect from a linear effect on a skewed
feature** (the two give identical importances). The cause is that regression
trees split on variance reduction, and variance is not scale-invariant. Read
importance as an ordinal shortlist of variables worth investigating, and use
partial-dependence plots to interrogate that shortlist — never as a substitute
for effect sizes.

## Layout

| Path | What |
|------|------|
| [`paper/impurity-importance.tex`](paper/impurity-importance.tex) | The paper (LaTeX; PDF built by CI). |
| [`notebook/impurity-importance.Rmd`](notebook/impurity-importance.Rmd) | Original 2022 R Markdown note. |
| [`analysis/validate.R`](analysis/validate.R) | Reproduces every number cited in the paper. |
| [`analysis/figures.R`](analysis/figures.R) | Regenerates the figures. |
| `figures/` | Generated figures. |

## Reproduce

```
brew install r
R_LIBS_USER=./.rlib Rscript -e 'install.packages(c("ranger","tibble","pdp"), repos="https://cloud.r-project.org")'
R_LIBS_USER=./.rlib Rscript analysis/validate.R
R_LIBS_USER=./.rlib Rscript analysis/figures.R
```

Validated with `ranger` 0.18.0 / R 4.6.1.
