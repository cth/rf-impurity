# Validation of the claims in notebook/impurity-importance.Rmd
# Reproduces each experiment and prints the numbers the paper cites.
# Run: R_LIBS_USER=./.rlib Rscript analysis/validate.R

suppressMessages({
  library(tibble)
  library(ranger)
})

set.seed(1)
figdir <- "figures"
dir.create(figdir, showWarnings = FALSE)

cat("ranger version:", as.character(packageVersion("ranger")), "\n")
cat("hyperparameters: num.trees as noted per experiment; mtry, min.node.size,\n",
    "  and sample fraction at ranger defaults for regression (mtry = floor(p/3),\n",
    "  min.node.size = 5, sample.fraction = 1 with replacement). Seeds set per block.\n\n")

imp <- function(m) ranger::importance(m)
rel <- function(v) v / v[1]   # relative to first element

## ---------------------------------------------------------------------------
## Claim 1: impurity importance orders linear effects correctly, but the
##          quantities are magnified super-linearly relative to coefficients.
## ---------------------------------------------------------------------------
cat("=== Claim 1: linear effects y = a + 2b + 4c ===\n")
n <- 1000
df <- tibble(a = runif(n), b = runif(n), c = runif(n), y = a + 2*b + 4*c)

# Use plain "impurity" (the measure the prose describes) and the bias-corrected
# "impurity_corrected" the notebook code actually calls, to compare both.
m_imp  <- ranger(y ~ ., df, importance = "impurity",           num.trees = 500, seed = 1)
m_corr <- ranger(y ~ ., df, importance = "impurity_corrected", num.trees = 500, seed = 1)
cat("  OOB R^2 (impurity model):", round(m_imp$r.squared, 3), "\n")
cat("  impurity  vip a,b,c   :", round(imp(m_imp), 1), "\n")
cat("  impurity  ratio /a    :", round(rel(imp(m_imp)), 2), "  (coef ratio 1,2,4)\n")
cat("  corrected ratio /a    :", round(rel(imp(m_corr)), 2), "\n")

## The ratio above (1:2.3:7.8) falls short of the predicted 1:4:16. The cause is
## the default mtry: with p = 3, ranger's regression default is floor(p/3) = 1,
## so each node splits on the single feature it drew and weak features receive
## forced splits. Sweeping mtry brackets the prediction. Averaged over seeds so
## the comparison does not rest on one draw.
## Also swept for impurity_corrected (AIR): unlike plain impurity it is nearly
## mtry-insensitive and sits near 1:4:16 throughout, at the cost of much higher
## seed-to-seed variance -- so its single-seed ratio in Claim 1 is not readable.
cat("\n=== Claim 1a: mtry sweep, mean ratio over seeds 1-10 (target 1:4:16) ===\n")
n <- 1000
ratios <- function(meas, mt) t(sapply(1:10, function(s) {
  set.seed(s)
  d <- tibble(a = runif(n), b = runif(n), c = runif(n))
  d$y <- d$a + 2*d$b + 4*d$c
  rel(imp(ranger(y ~ ., d, importance = meas, num.trees = 500, mtry = mt, seed = s)))
}))
for (meas in c("impurity", "impurity_corrected")) {
  cat("  ", meas, "\n", sep = "")
  for (mt in 1:3) {
    R <- ratios(meas, mt)
    cat(sprintf("    mtry=%d%-30s: 1 : %.2f : %.2f   (c range %.1f-%.1f)\n", mt,
                c(" (ranger default at p=3)", "", " (= p, no split randomisation)")[mt],
                mean(R[, 2]), mean(R[, 3]), min(R[, 3]), max(R[, 3])))
  }
}
cat("  -> default mtry compresses plain impurity; AIR is mtry-insensitive but noisy\n")

## Importance tracks variance contribution beta^2 * Var(X). With all X ~ U(0,1),
## Var(X) is constant, so importance should be ~linear in beta^2. We regress
## importance on beta and on beta^2 as SEPARATE (non-nested) single-predictor
## models, so the comparison is not rigged by nesting.
cat("\n=== Claim 1b: vip vs. effect size -- importance ~ beta vs ~ beta^2 ===\n")
set.seed(43)   # matches figures.R Fig 1
n <- 1000
eff <- 1:11
cols <- lapply(eff, function(i) runif(n))
names(cols) <- letters[1:11]
X <- as_tibble(cols)
X$y <- as.matrix(X) %*% eff
m <- ranger(y ~ ., X, importance = "impurity", num.trees = 1000, seed = 43)
v <- as.numeric(imp(m))
cat("  Var(X_j) (all U(0,1)) ~ 1/12 =", round(1/12, 4), "(constant across j)\n")
cat("  R^2 imp ~ beta     :", round(summary(lm(v ~ eff))$r.squared, 3), "\n")
cat("  R^2 imp ~ beta^2   :", round(summary(lm(v ~ I(eff^2)))$r.squared, 3),
    " <-- single non-nested predictor; importance is ~linear in beta^2\n")

## Seed 43 alone is the seed Fig 1 plots. Report the spread over ten seeds so
## the beta^2-beats-beta comparison does not rest on a single favourable draw.
A <- t(sapply(1:10, function(s) {
  set.seed(s)
  cl <- lapply(eff, function(i) runif(n)); names(cl) <- letters[1:11]
  Z <- as_tibble(cl); Z$y <- as.matrix(Z) %*% eff
  vv <- as.numeric(imp(ranger(y ~ ., Z, importance = "impurity",
                              num.trees = 1000, seed = s)))
  c(summary(lm(vv ~ eff))$r.squared, summary(lm(vv ~ I(eff^2)))$r.squared)
}))
cat(sprintf("  over seeds 1-10: R^2 ~beta   mean %.3f  range %.3f-%.3f\n",
            mean(A[, 1]), min(A[, 1]), max(A[, 1])))
cat(sprintf("                   R^2 ~beta^2 mean %.3f  range %.3f-%.3f\n",
            mean(A[, 2]), min(A[, 2]), max(A[, 2])))
cat("  beta^2 is the better fit on every seed:", all(A[, 2] > A[, 1]), "\n")

## ---------------------------------------------------------------------------
## Claim 2: pure THREE-WAY parity interaction. OLS is blind even with all
##          pairwise product terms (two-way parity would be bilinear and thus
##          OLS-recoverable); RF captures it and the three interacting variables
##          outrank the independent variable c.
## ---------------------------------------------------------------------------
cat("\n=== Claim 2: three-way parity y = d/10 + (a+b+c) mod 2 ===\n")
set.seed(42); n <- 10000
ib <- function(n) round(runif(n))
df <- tibble(a = ib(n), b = ib(n), c = ib(n), d = ib(n), y = d/10 + (a + b + c) %% 2)
## sanity: two-way binary parity is exactly bilinear -> OLS+a:b fits it perfectly
two_way <- tibble(a = ib(n), b = ib(n), d = ib(n), y = d/10 + (a + b) %% 2)
cat("  [check] 2-way parity, OLS y~a+b+d+a:b R^2 :",
    round(summary(lm(y ~ a + b + d + a:b, two_way))$r.squared, 3),
    "(bilinear -> ~1, why we use 3-way)\n")
ols_pair <- lm(y ~ (a + b + c)^2 + d, df)      # all main + pairwise terms
ols_full <- lm(y ~ a * b * c + d, df)          # incl. the 3-way product
cat("  OLS R^2 (main + all pairwise) :", round(summary(ols_pair)$r.squared, 3), "\n")
cat("  OLS R^2 (incl. 3-way product) :", round(summary(ols_full)$r.squared, 3), "\n")
cat("  OLS |coef| (pairwise model)   :", round(abs(coef(ols_pair)[-1]), 3), "\n")
mrf <- ranger(y ~ a + b + c + d, df, importance = "impurity", num.trees = 500, seed = 42)
cat("  RF  OOB R^2             :", round(mrf$r.squared, 3), "\n")
v <- imp(mrf)
cat("  RF  vip a,b,c,d         :", round(v, 1), "\n")
cat("  interaction vars > d ?  :", (min(v["a"], v["b"], v["c"]) > v["d"]), "\n")

## a, b and c are exchangeable by construction, so any difference among their
## importances is sampling noise. Its size is this paper's noise floor: no
## importance gap smaller than it should be read as meaningful.
P <- t(sapply(1:10, function(s) {
  set.seed(s)
  z <- tibble(a = ib(n), b = ib(n), c = ib(n), d = ib(n))
  z$y <- z$d/10 + (z$a + z$b + z$c) %% 2
  imp(ranger(y ~ a + b + c + d, z, importance = "impurity",
             num.trees = 500, seed = s))
}))
sp <- apply(P[, 1:3], 1, function(u) 100 * (max(u) - min(u)) / min(u))
cat(sprintf("  seeds 1-10: a,b,c mean %.0f (SD %.0f)   d mean %.0f   ratio %.1fx\n",
            mean(P[, 1:3]), sd(as.vector(P[, 1:3])), mean(P[, 4]),
            mean(P[, 1:3]) / mean(P[, 4])))
cat(sprintf("  within-seed spread over exchangeable a,b,c: %.0f-%.0f%% (median %.0f%%)\n",
            min(sp), max(sp), median(sp)))
## Control: the spread above belongs to the parity design, not to MDI generally.
## Same four features, equal marginal effects instead of parity -> much tighter.
Q <- t(sapply(1:10, function(s) {
  set.seed(s)
  z <- tibble(a = ib(n), b = ib(n), c = ib(n), d = ib(n))
  z$y <- z$d/10 + (z$a + z$b + z$c)/3
  imp(ranger(y ~ a + b + c + d, z, importance = "impurity", num.trees = 500, seed = s))
}))
spq <- apply(Q[, 1:3], 1, function(u) 100 * (max(u) - min(u)) / min(u))
cat(sprintf("  [control] same features, marginal effects: %.0f-%.0f%%",
            min(spq), max(spq)), " <-- floor is design-specific\n")
cat("  min(a,b,c) > d on every seed:", all(apply(P, 1, function(u) min(u[1:3]) > u[4])), "\n")

## ---------------------------------------------------------------------------
## Claim 3: split-mechanics on sorted polynomials. Two effects, cleanly separated
##   by NORMALISING to the fraction of parent variance removed:
##   (a) raw min split-variance grows with order -- but this is a RESPONSE-SCALE
##       artifact: the normalised fraction removed is ~constant (~0.75) across
##       y = x, x^2, x^3, so "large scale wins" does NOT survive normalisation;
##   (b) what does survive is the argmin migrating toward the high-y tail
##       (500 -> 697 -> 799): higher-order responses split unevenly, needing more
##       splits down one branch.
## ---------------------------------------------------------------------------
cat("\n=== Claim 3: split mechanics on y=x, x^2, x^3 (normalised) ===\n")
n <- 1000
vos <- function(idx, y) var(y[1:idx]) + var(y[idx:length(y)])
sweep_var <- function(y) sapply(2:(n-2), function(i) vos(i, y))
x <- 1:n
frac_removed <- function(y) {           # n-weighted within-child var at best split
  sw <- sweep_var(y); i <- which.min(sw) + 1; p <- var(y)
  1 - (i/n * var(y[1:i]) + (n - i)/n * var(y[i:n])) / p
}
for (pw in 1:3) {
  y <- x^pw; sw <- sweep_var(y)
  cat(sprintf("  y=x^%d: raw min split-var=%.2e  argmin idx=%d  frac parent var removed=%.3f\n",
              pw, min(sw), which.min(sw) + 1, frac_removed(y)))
}
cat("  -> fraction removed ~constant; the real effect is argmin migration (imbalance)\n")

## ---------------------------------------------------------------------------
## Claim 4: genuine non-linear effects y = a + b^2 + c^3 -> vip(a)<vip(b)<vip(c)
## ---------------------------------------------------------------------------
cat("\n=== Claim 4: non-linear effects y = a + b^2 + c^3 ===\n")
set.seed(42); n <- 10000
df_nl <- tibble(a = 1+runif(n), b = 1+runif(n), c = 1+runif(n), y = a + b^2 + c^3)
m_nl <- ranger(y ~ ., df_nl, importance = "impurity", num.trees = 500, seed = 42)
v <- imp(m_nl)
cat("  vip a,b,c        :", round(v, 1), "\n")
cat("  vip(a)<vip(b)<vip(c)?:", (v["a"] < v["b"] && v["b"] < v["c"]), "\n")

## ---------------------------------------------------------------------------
## Claim 5 (the key one): linear effects but skewed FEATURES.
##   y = a + b + c with equal OLS coefficients, but b,c are squared/cubed uniforms.
##   RF importance is badly unequal and mimics the non-linear-effect pattern.
## ---------------------------------------------------------------------------
cat("\n=== Claim 5: equal linear coefs, skewed features ===\n")
set.seed(42); n <- 10000
df_inc <- tibble(a = 1+runif(n), b = (1+runif(n))^2, c = (1+runif(n))^3,
                 y = a + b + c)
lm_inc <- lm(y ~ ., df_inc)
cat("  OLS coefs a,b,c  :", round(coef(lm_inc)[-1], 3), "  (all ~1)\n")
m_inc <- ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500, seed = 42)
v <- imp(m_inc)
cat("  RF vip a,b,c     :", round(v, 1), "\n")
cat("  RF vip ratio /a  :", round(rel(v), 2), "\n")
cat("  -> equal linear effects, yet importance is highly unequal\n")

## split-variance sweep per feature for the skewed-feature data
vos2 <- function(idx, y) var(y[1:idx]) + var(y[idx:length(y)])
sv <- function(col) {
  o <- order(df_inc[[col]]); y <- df_inc$y[o]
  sapply(2:(n-2), function(i) vos2(i, y))
}
sa <- sv("a"); sb <- sv("b"); sc <- sv("c")
cat("  median split-var a,b,c:", round(c(median(sa), median(sb), median(sc)), 2),
    " (lower => picked earlier/more)\n")
cat("  min split-var a,b,c   :", round(c(min(sa), min(sb), min(sc)), 2), "\n")

## The confound is NOT specific to impurity: permutation importance gives the
## SAME ratios for the non-linear (Claim 4) and skewed-feature (Claim 5) worlds,
## and even standardised OLS coefficients spread -- because all three summarise
## variance contribution, which is identical across the two worlds.
cat("\n=== Claim 5b: is the spread specific to impurity importance? ===\n")
imp_nl  <- imp(ranger(y ~ ., df_nl,  importance = "impurity",    num.trees = 500, seed = 42))
per_nl  <- imp(ranger(y ~ ., df_nl,  importance = "permutation", num.trees = 500, seed = 42))
imp_inc <- imp(ranger(y ~ ., df_inc, importance = "impurity",    num.trees = 500, seed = 42))
per_inc <- imp(ranger(y ~ ., df_inc, importance = "permutation", num.trees = 500, seed = 42))
cat("  impurity    ratio /a  nl:", round(rel(imp_nl), 2), " inc:", round(rel(imp_inc), 2), "\n")
cat("  permutation ratio /a  nl:", round(rel(per_nl), 2), " inc:", round(rel(per_inc), 2),
    " <-- permutation ALSO cannot separate the two worlds\n")
std <- coef(lm_inc)[-1] * sapply(df_inc[, c("a","b","c")], sd) / sd(df_inc$y)
cat("  standardised OLS coef ratio /a (inc):", round(rel(std), 2),
    " <-- even standardised coefficients spread\n")
## Control for the Section 6 proposition: standardised OLS never sees the forest,
## so it is NOT pinned across the two worlds -- it agrees only to ~1%, two orders
## of magnitude looser than the forest-based measures.
stdz <- function(d) {
  m <- lm(y ~ ., d)
  coef(m)[-1] * sapply(d[, c("a","b","c")], sd) / sd(d$y)
}
sA <- stdz(df_nl); sB <- stdz(df_inc)
cat("  standardised OLS  nl:", round(rel(sA), 3), " inc:", round(rel(sB), 3), "\n")
cat("  max rel diff across worlds:", signif(max(abs(sA - sB)/abs(sA)), 3),
    " <-- control: not pinned by the proposition\n")

## ---------------------------------------------------------------------------
## Claim 5c: the two hypotheses of the Section 6 proposition. The identity holds
##   because (i) splits depend on a feature only through the ORDER of its values
##   and (ii) the two fits share bootstrap indices and candidate-feature draws.
##   Both are load-bearing: drop (ii) by fitting sequentially without reseeding,
##   or drop (i) via splitrule = "extratrees" (which draws thresholds uniformly
##   on the feature's value RANGE, so it does see the metric), and the identity
##   degrades from exact to ~1% and ~3% respectively.
## ---------------------------------------------------------------------------
cat("\n=== Claim 5c: hypotheses of the Section 6 proposition ===\n")
reldiff <- function(x, z) max(abs(x - z) / x)
cat("  (both hypotheses) max rel diff :",
    reldiff(imp(ranger(y ~ ., df_nl,  importance = "impurity", num.trees = 500, seed = 42)),
            imp(ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500, seed = 42))),
    " <-- exactly 0\n")
set.seed(42)   # drop (ii): sequential fits, no per-fit seed
seq_nl  <- imp(ranger(y ~ ., df_nl,  importance = "impurity", num.trees = 500))
seq_inc <- imp(ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500))
cat("  (no per-fit seed)  max rel diff :", signif(reldiff(seq_nl, seq_inc), 3), "\n")
## Control: refitting ONE world under two seeds moves the importances by more
## than the cross-world gap above, so that gap carries no residual signal.
cat("  [control] same world, seeds 42/43:",
    signif(reldiff(imp(ranger(y ~ ., df_nl, importance = "impurity", num.trees = 500, seed = 42)),
                   imp(ranger(y ~ ., df_nl, importance = "impurity", num.trees = 500, seed = 43))), 3),
    " <-- seed noise exceeds the cross-world gap\n")
et_nl  <- imp(ranger(y ~ ., df_nl,  importance = "impurity", num.trees = 500,
                     seed = 42, splitrule = "extratrees"))
et_inc <- imp(ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500,
                     seed = 42, splitrule = "extratrees"))
cat("  (extratrees)       max rel diff :", signif(reldiff(et_nl, et_inc), 3),
    " ratios", round(rel(et_nl), 2), "vs", round(rel(et_inc), 2),
    "\n                                      <-- order-only hypothesis fails\n")

## ---------------------------------------------------------------------------
## Claim 5d: global mean |SHAP| is confounded across the two worlds too, and sits
##   on the standardised-coefficient scale rather than the variance scale.
##   Optional: needs the treeshap package. Path-dependent (observational) TreeSHAP
##   reconstructs node weights from the data, so unlike impurity it is not exact
##   -- the covers differ by at most 2 observations on ~0.3% of nodes.
## ---------------------------------------------------------------------------
if (requireNamespace("treeshap", quietly = TRUE)) {
  cat("\n=== Claim 5d: mean |SHAP| across the two worlds ===\n")
  sh <- function(d) {
    m <- ranger(y ~ ., d, num.trees = 200, seed = 42)
    u <- treeshap::ranger.unify(m, d[, c("a","b","c")])
    colMeans(abs(treeshap::treeshap(u, d[1:300, c("a","b","c")],
                                    verbose = FALSE)$shaps))
  }
  g_nl <- sh(df_nl); g_inc <- sh(df_inc)
  cat("  mean|SHAP| ratio /a  nl:", round(rel(g_nl), 2),
      " inc:", round(rel(g_inc), 2), "\n")
  cat("  max rel diff between worlds:", signif(max(abs(g_nl - g_inc)/g_nl), 3),
      " <-- SHAP cannot separate them either\n")
  cat("  cf. standardised OLS ratio  :", round(rel(std), 2),
      " <-- SHAP is on the sd scale, not the variance scale\n")
} else {
  cat("\n=== Claim 5d skipped (install 'treeshap' to run the SHAP check) ===\n")
}

cat("\nAll experiments completed.\n")
