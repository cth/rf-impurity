# Supplementary material

**Variable importance is variance, not effect size: a caution and a prevalence
screen.**

This archive holds the code and records behind the paper: the `ranger`
experiments, and the screen of the ranger-citing literature estimating how
often the misreading reaches published conclusions. Everything cited in the
paper is reproducible from what is here, with the one exception noted under
[Corpus](#corpus).

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

## Reproduce

Two commands reproduce the paper's two halves. Both are run from the top of
the unpacked archive.

**Controlled experiments and figures** (the `ranger` sections):

```
Rscript -e 'install.packages(c("ranger","tibble"), repos="https://cloud.r-project.org")'
# optional: "treeshap" enables the SHAP check in validate.R; "pdp" for the notebook
Rscript analysis/validate.R    # prints every number cited in those sections
Rscript analysis/figures.R     # regenerates figures/
```

**Literature screen** (the prevalence section):

```
python3 analysis/tally.py      # prints every count cited in that section
```

Validated with R 4.6.1 and `ranger` 0.18.0; `tally.py` needs Python 3.8 or
later and uses only the standard library. `validate.R` and `figures.R` write
into `figures/`; nothing else is modified.

## Layout

| Path | What |
|------|------|
| `analysis/validate.R` | Reproduces every experiment number cited in the paper. |
| `analysis/figures.R` | Regenerates the figures. |
| `analysis/tally.py` | Reproduces every count in the literature-screen section from the per-paper records. |
| `analysis/results.md` | Full literature-screen results and statistics. |
| `analysis/fetch_corpus.py` | Corpus construction and full-text retrieval. |
| `analysis/fingerprint.py`, `analysis/relevance_filter.py` | Deduplication and relevance filter. |
| `analysis/extract_*`, `analysis/adjudicate_*` | Verbatim stage-1 and stage-2 screening prompts and workflows. |
| `analysis/extraction/`, `analysis/adjudication/` | Per-paper structured records and verdicts. |
| `corpus/` | The screened corpus: manifest, abstracts, fetch log (see below). |
| `notebook/impurity-importance.Rmd` | Original 2022 R Markdown note the paper grew from. |
| `figures/` | Generated figures, as they appear in the paper. |

## Corpus

`corpus/manifest.csv` has one row per work screened, with its OpenAlex
identifier, text availability, and retrieval timestamp; `corpus/README.md`
records the snapshot date and the per-category counts. The retrieved
abstracts are included in `corpus/abstracts/`.

The retrieved **full texts are not included**. They are third-party articles
from the PMC Open Access subset under a range of licences, and this archive is
not the right vehicle for redistributing them. To restore them, run

```
python3 analysis/fetch_corpus.py
```

which refetches from Europe PMC into `corpus/fulltext/`. It is idempotent and
resumes from `manifest.csv`, so it retrieves only what is missing. `tally.py`
reads the per-paper records in `analysis/`, not the full texts, so every count
in the paper reproduces without this step.
