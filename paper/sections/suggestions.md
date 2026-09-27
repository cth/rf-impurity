# Quirky sentences / language notes

Collected from each section .tex file.

## prevalence.tex

- "Counting SHAP as corroboration is generous."
- "Using two models from a single vendor means the adjudication is a precision filter, not an independent validation --- a different-vendor or human check would be stronger; we return to this in the limitations."
- "The $7\%$ is an unvalidated estimate; stage 2 raises precision but is not independent validation, and there is no human ground truth."
- "Every flag required a quoted passage."

## background.tex

- "Our experiments are consequences of that identity, not new biases."
- "The new contribution is thus the sharp skew-versus-nonlinearity demonstration and an estimate (Sections~\ref{sec:prevalence-method}--\ref{sec:prevalence-results}) of how often the misreading reaches published conclusions."
- "Two strands of prior work bear on this."

## nonlinear.tex

- "The draws are separate per feature: a single shared $U$ would make the three features collinear and the experiment vacuous."
- "Depth truncation is also stronger here than in Section~\ref{sec:linear}: at $\code{mtry}=p$ the weakest feature gets no splits at all out to depth $4$ (against depth $2$ for the linear design), and the ratio only settles once the trees are grown out."
- "A linear model still returns non-zero coefficients on this data, but they are uninterpretable: the residuals are visibly non-normal."
- "A non-linear feature's bar is the bar a linear feature with coefficient $\mathrm{sd}(f_j(X_j))/\mathrm{sd}(X_j)$ would produce, so a ranking mixes curvature and coefficient size without distinguishing them."

## conclusion.tex

- "Impurity importance is a useful screening tool when read as a ranked shortlist and paired with partial-dependence plots. It misleads when read as an effect size."
- "That last identity is provable, and it extends to permutation importance to four significant figures, so it is a property of variance-based measures rather than a defect of MDI."

## confound.tex

- "Take equal linear effects but skewed feature distributions:"
- "This is \textbf{not specific to impurity}, and debiasing does not touch it."
- "That spread of agreement is what identifies the mechanism."
- "What the four share is that each is a functional of the fitted model and the feature ordering, which the proposition makes identical."
- "The remedy is a shape-aware view: a partial-dependence plot, or a SHAP dependence plot, which plots each observation's SHAP value against its feature value, and the feature values do differ between the two worlds."

## variance.tex

- "Trees discard feature-distribution shape."
- "The optimal split migrates with response shape. For a linear response the best split is central; for higher orders it moves toward the high-$y$ tail ($500 \rightarrow 697 \rightarrow 799$)."
- "Neither property depends on \code{mtry}: the sweep has a single feature, and \code{mtry} decides which features compete at a node, not where a feature's best threshold falls or what the split can see."

## linear.tex

- "The strongest feature wins the root split in every tree, and overshoots."
- "shallow trees starve weak features."
- "The price is sampling variance, and it comes from that same subtraction."
- "For the weakest feature the two terms nearly cancel, leaving a small difference between two large numbers, so the ordinary noise each carries falls on a much smaller result"
- "Among identically distributed features with linear effects, importance recovers the coefficient order when the contributions are well separated, but not reliably when they are close"

## interactions.tex

- "A high importance need not imply any marginal effect."
- "A node whose single candidate is already constant becomes terminal, so paths are cut before both $a$ and $b$ have been split on."
- "At $\code{mtry} = p$ none of that randomness is injected."
- "The $\code{mtry}$ setting that results in the best OOB generalization (OOB $R^2$ $1.00$ at $\code{mtry} = p$ against $0.59$ at the default) is therefore also the one whose division of importance between $a$ and $b$ is least trustworthy."
- "Within an interacting pair, the order is not to be read --- the division of their shared credit is candidate-draw noise at the default $\code{mtry}$ and a sample-fixed bias at $\code{mtry} = p$."
