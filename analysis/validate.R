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
    "  and sample fraction at ranger defaults (mtry = floor(sqrt(p)),\n",
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
## the default mtry: with p = 3, ranger's default is floor(sqrt(p)) = 1,
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
## Where AIR's noise sits: seed-to-seed relative SD per feature at the default
## mtry. The subtraction nearly cancels for the weakest feature, so a's AIR is
## ~3x noisier than plain impurity's; c, where little is subtracted, is not.
for (meas in c("impurity", "impurity_corrected")) {
  M <- t(sapply(1:10, function(s) {
    set.seed(s)
    d <- tibble(a = runif(n), b = runif(n), c = runif(n))
    d$y <- d$a + 2*d$b + 4*d$c
    imp(ranger(y ~ ., d, importance = meas, num.trees = 500, seed = s))
  }))
  cat(sprintf("  %-19s seed-to-seed rel. SD a,b,c: %.0f%% %.0f%% %.0f%%\n",
              meas, 100 * sd(M[, 1]) / mean(M[, 1]), 100 * sd(M[, 2]) / mean(M[, 2]),
              100 * sd(M[, 3]) / mean(M[, 3])))
}

## Scornet proves the variance identity for truncated trees and warns that
## fully grown trees give positively biased MDI. That bias comes from fitting
## the noise term, and y here is noiseless, so it cannot bite; what a depth
## sweep shows instead is the opposite finite-sample effect: shallow trees
## starve weak features (at max.depth = 2, mtry = 3, feature a earns no splits
## at all and the ratio is infinite), and deepening converges the ratio
## downward toward 1:4:16 at mtry = p while deepening the compression at
## mtry = 1. The residual overshoot at fully grown mtry = p is finite-sample
## greediness, not Scornet's depth bias; the n sweep below shows it vanishes
## as n grows.
cat("\n=== Claim 1a-depth: max.depth sweep, mean impurity ratio over seeds 1-10 ===\n")
for (mt in c(1, 3)) for (md in c(2, 4, 8, 0)) {
  R <- t(sapply(1:10, function(s) {
    set.seed(s)
    d <- tibble(a = runif(n), b = runif(n), c = runif(n))
    d$y <- d$a + 2*d$b + 4*d$c
    rel(imp(ranger(y ~ ., d, importance = "impurity", num.trees = 500,
                   mtry = mt, max.depth = md, seed = s)))
  }))
  cat(sprintf("    mtry=%d max.depth=%-9s: 1 : %.2f : %.2f\n",
              mt, ifelse(md == 0, "unlimited", md), mean(R[, 2]), mean(R[, 3])))
}
cat("  -> truncation starves weak features; depth converges toward (mtry=p) or\n",
    "     past (mtry=1) the target. Fully-grown bias needs noise; y is noiseless\n")

## Is the residual overshoot at fully grown mtry = p a persistent property of
## greedy splitting or a finite-sample effect? Scornet's Theorem 4 is greedy
## CART with all variables in competition (mtry = p), asymptotic in n -- so if
## the overshoot is finite-sample, growing n should drive the ratio to 1:4:16.
## It does. At mtry = 1 (not covered by the theorem) the compression also
## shrinks with n, but far more slowly and is still substantial at n = 64000.
cat("\n=== Claim 1a-n: n sweep, fully grown, mean impurity ratio over seeds 1-10 ===\n")
for (mt in c(1, 3)) for (nn in c(1000, 4000, 16000, 64000)) {
  R <- t(sapply(1:10, function(s) {
    set.seed(s)
    d <- tibble(a = runif(nn), b = runif(nn), c = runif(nn))
    d$y <- d$a + 2*d$b + 4*d$c
    rel(imp(ranger(y ~ ., d, importance = "impurity", num.trees = 200,
                   mtry = mt, seed = s)))
  }))
  cat(sprintf("    mtry=%d n=%-5d: 1 : %.2f : %.2f\n",
              mt, nn, mean(R[, 2]), mean(R[, 3])))
}
cat("  -> mtry=p overshoot vanishes with n (1:4.01:16.1 at n=64000), as the\n",
    "     asymptotic theorem predicts; mtry=1 compression shrinks slowly\n",
    "     (1:3.51:13.7 at n=64000)\n")

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

## Tracking beta^2 well (Claim 1b) is not the same as ranking correctly: an R^2
## of 0.98 still leaves adjacent features free to swap. Count rank inversions
## against the true beta order. Inversions concentrate at the weak end, where
## mtry compression flattens the contributions into near-ties -- so we also
## report the weak-end separation (beta=5 vs beta=1) that ranking depends on.
## AIR is checked too: it separates the weak end much better but is far noisier
## per seed, and the two effects roughly cancel, so it ranks no better.
cat("\n=== Claim 1d: rank fidelity, 11 linear features, seeds 1-10 ===\n")
rank_check <- function(meas, mt) {
  M <- t(sapply(1:10, function(s) {
    set.seed(s)
    cl <- lapply(eff, function(i) runif(n)); names(cl) <- letters[1:11]
    Z <- as_tibble(cl); Z$y <- as.matrix(Z) %*% eff
    as.numeric(imp(ranger(y ~ ., Z, importance = meas, num.trees = 500,
                          mtry = mt, seed = s)))
  }))
  inv <- apply(M, 1, function(v) {
    r <- rank(v)
    sum(outer(seq_along(eff), seq_along(eff), function(i, j) i < j & r[i] > r[j]))
  })
  sp <- apply(M, 1, function(v) cor(v, eff, method = "spearman"))
  list(M = M, inv = inv, sp = sp)
}
for (meas in c("impurity", "impurity_corrected")) for (mt in c(3, 11)) {
  z <- rank_check(meas, mt)
  cat(sprintf("  %-19s mtry=%-2d: perfect %d/10  mean Spearman %.3f  inversions %s\n",
              meas, mt, sum(z$inv == 0), mean(z$sp), paste(z$inv, collapse = " ")))
  if (mt == 3) {
    m <- colMeans(z$M)
    cat(sprintf("      weak end (beta=1..5) %s  separation b5/b1 = %.2f (target 25)\n",
                paste(sprintf("%.0f", m[1:5]), collapse = " "), m[5] / m[1]))
    rsd <- apply(z$M, 2, function(x) 100 * sd(x) / mean(x))
    cat(sprintf("      per-seed rel. SD, beta=1,2,3: %.1f%% %.1f%% %.1f%%\n",
                rsd[1], rsd[2], rsd[3]))
  }
}
cat("  -> ranking is near-perfect but not perfect; inversions sit at the weak,\n",
    "     compressed end. AIR separates it better yet is ~20x noisier per seed,\n",
    "     so switching measure does not make the ordinal reading safe\n")

## ---------------------------------------------------------------------------
## Claim 2: pure TWO-WAY parity interaction. a and b carry no marginal effect,
##          c is the only variable that does; impurity importance is charged to
##          the interacting pair regardless. Main-effects OLS sees only c.
##          (Two-way binary parity IS bilinear, so OLS with an a:b term recovers
##          it exactly -- reported below. The claim here is about how MDI
##          allocates the interaction, not about a limit of linear models.)
## ---------------------------------------------------------------------------
cat("\n=== Claim 2: two-way parity y = c/10 + (a+b) mod 2 ===\n")
set.seed(42); n <- 10000
ib <- function(n) round(runif(n))
df <- tibble(a = ib(n), b = ib(n), c = ib(n), y = c/10 + (a + b) %% 2)
ols_main <- lm(y ~ a + b + c, df)
cat("  OLS R^2 (main effects only)   :", round(summary(ols_main)$r.squared, 3), "\n")
cat("  OLS coef a,b,c                :", round(coef(ols_main)[-1], 3), "\n")
cat("  OLS R^2 (+ a:b product)       :", round(summary(lm(y ~ a + b + c + a:b, df))$r.squared, 3),
    "(bilinear -> exactly recoverable, stated in the text)\n")
mrf <- ranger(y ~ a + b + c, df, importance = "impurity", num.trees = 500, seed = 42)
v <- imp(mrf)
cat("  RF  OOB R^2 (default mtry=1)  :", round(mrf$r.squared, 3), "\n")
cat("  RF  vip a,b,c                 :", round(v, 1), "\n")
cat("  interacting pair > c ?        :", (min(v["a"], v["b"]) > v["c"]), "\n")
## mtry: with p=3 the default mtry=floor(sqrt(p))=1 starves the interaction, since
## reaching it needs two specific splits to line up. Raising mtry recovers it.
for (mt in 1:3) {
  m <- ranger(y ~ a + b + c, df, importance = "impurity", num.trees = 500,
              mtry = mt, seed = 42)
  u <- imp(m)
  cat(sprintf("  [mtry=%d] OOB R^2 %.3f  vip %s  ratio %.1fx  total %.1f  c share %.4f\n",
              mt, m$r.squared, paste(round(u, 1), collapse = " "),
              mean(u[1:2]) / u[3], sum(u), u[3] / sum(u)))
}
## Credit follows the variance decomposition: with pure trees (mtry=3) the total
## equals n*Var(y) and c's share is Var(c/10)/Var(y) = 1%. At mtry=1 trees are
## truncated (a node whose only candidate is constant becomes terminal), the
## total drops, and the loss hits the pair harder than c (its share rises to ~1.7%).
cat(sprintf("  n*Var(y) = %.1f   Var(c/10)/Var(y) = %.4f\n", n * var(df$y), var(df$c/10) / var(df$y)))

## a and b are exchangeable by construction, so any difference between their
## importances is sampling noise. Its size is this design's noise floor: no
## importance gap smaller than it should be read as meaningful.
P <- t(sapply(1:10, function(s) {
  set.seed(s)
  z <- tibble(a = ib(n), b = ib(n), c = ib(n))
  z$y <- z$c/10 + (z$a + z$b) %% 2
  imp(ranger(y ~ a + b + c, z, importance = "impurity", num.trees = 500, seed = s))
}))
sp <- apply(P[, 1:2], 1, function(u) 100 * (max(u) - min(u)) / min(u))
cat(sprintf("  seeds 1-10: a,b mean %.0f (SD %.0f)   c mean %.0f   ratio %.1fx\n",
            mean(P[, 1:2]), sd(as.vector(P[, 1:2])), mean(P[, 3]),
            mean(P[, 1:2]) / mean(P[, 3])))
cat(sprintf("  within-seed spread over exchangeable a,b: %.0f-%.0f%% (median %.0f%%)\n",
            min(sp), max(sp), median(sp)))
cat("  min(a,b) > c on every seed:", all(apply(P, 1, function(u) min(u[1:2]) > u[3])), "\n")
## same, at mtry = 3, where the forest fits the target exactly
P3 <- t(sapply(1:10, function(s) {
  set.seed(s)
  z <- tibble(a = ib(n), b = ib(n), c = ib(n))
  z$y <- z$c/10 + (z$a + z$b) %% 2
  imp(ranger(y ~ a + b + c, z, importance = "impurity", num.trees = 500,
             mtry = 3, seed = s))
}))
cat(sprintf("  seeds 1-10 at mtry=3: a,b mean %.0f   c mean %.0f   ratio %.1fx\n",
            mean(P3[, 1:2]), mean(P3[, 3]), mean(P3[, 1:2]) / mean(P3[, 3])))
## Control: the spread above belongs to the parity design, not to MDI generally.
## Same three features, equal marginal effects instead of parity -> much tighter.
Q <- t(sapply(1:10, function(s) {
  set.seed(s)
  z <- tibble(a = ib(n), b = ib(n), c = ib(n))
  z$y <- z$c/10 + (z$a + z$b)/2
  imp(ranger(y ~ a + b + c, z, importance = "impurity", num.trees = 500, seed = s))
}))
spq <- apply(Q[, 1:2], 1, function(u) 100 * (max(u) - min(u)) / min(u))
cat(sprintf("  [control] same features, marginal effects: %.0f-%.0f%%",
            min(spq), max(spq)), " <-- floor is design-specific\n")

## --- Why the floor is higher here: where the pair's credit lands -------------
## A split on `a` above any split on `b` removes no variance; the split below
## removes all of it. So within one tree the pair's credit is winner-take-all and
## goes to whichever variable sits DEEPER. Measured on single trees at mtry=3.
first_depth <- function(m) {
  ti <- treeInfo(m, 1)
  dep <- rep(NA_integer_, nrow(ti)); dep[1] <- 0
  for (i in seq_len(nrow(ti))) {          # rows are in nodeID order, parents first
    if (!is.na(ti$leftChild[i])) {
      dep[ti$leftChild[i] + 1] <- dep[i] + 1
      dep[ti$rightChild[i] + 1] <- dep[i] + 1
    }
  }
  sapply(c("a", "b", "c"), function(v) {
    d <- dep[which(ti$splitvarName == v)]
    if (!length(d)) NA_integer_ else min(d)
  })
}
set.seed(5)
d5 <- tibble(a = ib(n), b = ib(n), c = ib(n))
d5$y <- d5$c/10 + (d5$a + d5$b) %% 2
R <- t(sapply(1:120, function(s) {
  m <- ranger(y ~ a + b + c, d5, importance = "impurity", num.trees = 1,
              mtry = 3, seed = s, keep.inbag = TRUE)
  u <- imp(m); fd <- first_depth(m)
  c(a = u[[1]], b = u[[2]], da = fd[["a"]], db = fd[["b"]], dc = fd[["c"]])
}))
R <- as.data.frame(R)
sh <- R$a / (R$a + R$b)
cat("\n  --- credit vs split depth (dataset seed 5, mtry=3, 120 single trees) ---\n")
cat("  root split variable:", paste(names(table(ifelse(R$da == 0, "a", ifelse(R$db == 0, "b", "c")))),
    table(ifelse(R$da == 0, "a", ifelse(R$db == 0, "b", "c"))), collapse = " "), "/120\n")
cat(sprintf("  a shallower than b : %3d trees   mean a-share %.3f\n", sum(R$da < R$db), mean(sh[R$da < R$db])))
cat(sprintf("  b shallower than a : %3d trees   mean a-share %.3f\n", sum(R$db < R$da), mean(sh[R$db < R$da])))
cat(sprintf("  equal depth        : %3d trees   mean a-share %.3f\n", sum(R$da == R$db), mean(sh[R$da == R$db])))
cat("  -> the pair's credit goes to whichever variable sits deeper; the one that\n",
    "     opens the pair earns ~0. Only the DIVISION between a and b is random.\n")

## Why mtry decides whether that division is noise or bias. At mtry=1 the tree
## splits on the single candidate drawn, so which variable opens the pair is set
## by the RNG and averages out. At mtry=p the node compares both and takes the
## larger empirical decrease -- a function of the training sample, so every tree
## re-derives the same choice. Switching bagging off (every tree sees the same
## data) makes the allocation fully deterministic, which bootstrap only partly
## decorrelates; hence an imbalance that more trees cannot remove.
cat("\n  --- a's share of the pair's credit, 500 trees ---\n")
cat("  data  mtry  bagging        a-share\n")
for (s in c(5, 6, 3)) {
  set.seed(s); z <- tibble(a = ib(n), b = ib(n), c = ib(n))
  z$y <- z$c/10 + (z$a + z$b) %% 2
  for (mt in c(1, 3)) for (bg in c(TRUE, FALSE)) {
    m <- if (bg) ranger(y ~ a + b + c, z, importance = "impurity", num.trees = 500,
                        mtry = mt, seed = s)
         else    ranger(y ~ a + b + c, z, importance = "impurity", num.trees = 500,
                        mtry = mt, seed = s, replace = FALSE, sample.fraction = 1)
    u <- imp(m)
    cat(sprintf("  %4d  %4d  %-12s   %.3f\n", s, mt, ifelse(bg, "on (default)", "OFF"),
                u[1] / (u[1] + u[2])))
  }
}
cat("  -> mtry=1 is unchanged by bagging (the coin was never data-driven);\n",
    "     mtry=3 collapses to 0.999 / 0.000 without it, so the tilt is the data's,\n",
    "     not the tree's -- and no number of trees averages it away:\n")
for (mt in c(1, 3)) for (nt in c(500, 4000)) {
  sp <- sapply(1:6, function(s) {
    set.seed(s); z <- tibble(a = ib(n), b = ib(n), c = ib(n))
    z$y <- z$c/10 + (z$a + z$b) %% 2
    u <- imp(ranger(y ~ a + b + c, z, importance = "impurity", num.trees = nt,
                    mtry = mt, seed = s))
    100 * abs(u[1] - u[2]) / min(u[1], u[2]) })
  cat(sprintf("     mtry=%d trees=%4d : median a-vs-b spread %5.1f%%\n", mt, nt, median(sp)))
}

## Bias, not noise: hold each dataset fixed and vary only the forest seed. If
## the imbalance were noise, independent forests would fall on either side of an
## even split and their mean would approach .5 with more trees. A bias shows as
## every forest on the same side, with the forest-to-forest SD shrinking as
## 1/sqrt(trees) while the mean stays put. The a-share is a/(a+b).
par_data <- function(s) { set.seed(s); z <- tibble(a = ib(n), b = ib(n), c = ib(n))
  z$y <- z$c/10 + (z$a + z$b) %% 2; z }
cat("\n  --- a-share of the pair's credit, mtry=3, 8 forest seeds per dataset ---\n")
cat("  data  trees  mean_a_share  sd_over_forests  all_same_side\n")
ash <- expand.grid(seed = 1:6, nt = c(500, 4000))
ash$mean <- ash$sd <- ash$same <- NA
for (i in seq_len(nrow(ash))) {
  z <- par_data(ash$seed[i])
  v <- sapply(101:108, function(rs) {
    u <- imp(ranger(y ~ a + b + c, z, importance = "impurity", num.trees = ash$nt[i],
                    mtry = 3, seed = rs))
    u[1] / (u[1] + u[2]) })
  ash$mean[i] <- mean(v); ash$sd[i] <- sd(v); ash$same[i] <- all(v > .5) || all(v < .5)
}
ash <- ash[order(ash$seed, ash$nt), ]
for (i in seq_len(nrow(ash)))
  cat(sprintf("  %4d  %5d     %.4f         %.4f          %s\n",
              ash$seed[i], ash$nt[i], ash$mean[i], ash$sd[i], ash$same[i]))
## paired change in |mean - .5| from 500 to 4000 trees, one value per dataset
dsh <- sapply(1:6, function(s) abs(ash$mean[ash$seed == s & ash$nt == 4000] - .5) -
                                abs(ash$mean[ash$seed == s & ash$nt == 500] - .5))
tt <- t.test(dsh)
cat(sprintf("  |a-share - .5| change 500->4000: mean %+.4f, 95%% CI [%.4f, %.4f], p = %.2f\n",
            mean(dsh), tt$conf.int[1], tt$conf.int[2], tt$p.value))
cat(sprintf("  forest SD ratio 500/4000 (median over datasets): %.1fx  (1/sqrt(8) predicts 2.8x)\n",
            median(ash$sd[ash$nt == 500] / ash$sd[ash$nt == 4000])))
cat(sprintf("  datasets where all 8 forests fall on the same side of .5: %d/6 at 4000 trees\n",
            sum(ash$same[ash$nt == 4000])))
cat("  per-dataset spread at 4000 trees, %:",
    paste(round(100 * abs(2 * ash$mean[ash$nt == 4000] - 1) /
                pmin(ash$mean[ash$nt == 4000], 1 - ash$mean[ash$nt == 4000])), collapse = " "),
    "\n  -> the sign is fixed by the data; more trees sharpen the imbalance, not remove it\n")

## --- Does the bias-corrected measure (AIR) rescue any of this? ---------------
## No. AIR corrects a bias BETWEEN VARIABLES OF DIFFERING TYPE (more split points
## / more categories accumulate impurity by chance) by subtracting what permuted
## pseudo-copies earn. Here both interacting variables are binary, and the problem
## is how ONE interaction's credit is divided between them -- a within-tree
## allocation, which the correction never touches.
## mean-denominated, because AIR can be negative and a min-denominated ratio would
## then be meaningless (the rest of this block uses min, as the paper does)
sp_mean <- function(u) 100 * abs(u[1] - u[2]) / mean(c(u[1], u[2]))
## 100 seeds, not 10: the mtry=1 comparison below is a NULL result, and a 10-seed
## median of this statistic is worthless -- resampling 10-seed blocks out of 100,
## it lands anywhere in 4.9-13.0 (plain) or 3.3-15.2 (AIR), and says AIR is the
## better of the two on 48% of draws. Costs ~4 min of the script's runtime.
S_AIR <- 100
cat("\n  --- AIR vs plain impurity on the parity design (seeds 1-", S_AIR, ") ---\n", sep = "")
cat("  measure              mtry   mean_a,b   mean_c   a,b>c always   spread: median   mean\n")
for (mt in c(1, 3)) {
  V <- lapply(c("impurity", "impurity_corrected"), function(meas)
    t(sapply(1:S_AIR, function(s)
      imp(ranger(y ~ a + b + c, par_data(s), importance = meas,
                 num.trees = 500, mtry = mt, seed = s)))))
  names(V) <- c("impurity", "impurity_corrected")
  for (meas in names(V)) {
    P <- V[[meas]]
    cat(sprintf("  %-19s %4d %9.1f %8.1f       %-5s         %6.2f%% %6.2f%%\n", meas, mt,
        mean(P[, 1:2]), mean(P[, 3]),
        all(apply(P, 1, function(u) min(u[1:2]) > u[3])),
        median(apply(P, 1, sp_mean)), mean(apply(P, 1, sp_mean))))
  }
  ## paired on the same datasets, so compare per seed rather than across summaries
  dd <- apply(V$impurity_corrected, 1, sp_mean) - apply(V$impurity, 1, sp_mean)
  ci <- t.test(dd)$conf.int
  cat(sprintf("    paired diff (AIR - plain): median %+6.2f  mean %+6.2f  95%% CI [%+.2f, %+.2f]  Wilcoxon p = %.1e  AIR lower on %d/%d\n",
      median(dd), mean(dd), ci[1], ci[2],
      suppressWarnings(wilcox.test(dd)$p.value), sum(dd < 0), S_AIR))
}
cat("  -> the a,b >> c result is measure-independent. At the default mtry=1 the two\n",
    "     measures are INDISTINGUISHABLE (the CI spans 0). AIR's real gap at mtry=p is\n",
    "     large and reproducible, but it is NOT the correction: under IMP_GINI_CORRECTED\n",
    "     ranger sets num_vars += getNumCols() (Tree.cpp), so the candidate pool is 2p\n",
    "     and a node often does not see both a and b -- the same decorrelation a smaller\n",
    "     mtry gives, and it costs fit the same way (OOB R^2 0.946 vs 1.000). Two checks:\n")

cat("\n  a-share of the pair's credit, mtry=3, 500 trees:\n")
cat("  measure              bagging     seed5    seed6\n")
for (meas in c("impurity", "impurity_corrected")) for (bg in c(TRUE, FALSE)) {
  o <- sapply(c(5, 6), function(s) { d <- par_data(s)
    m <- if (bg) ranger(y ~ a + b + c, d, importance = meas, num.trees = 500, mtry = 3, seed = s)
         else    ranger(y ~ a + b + c, d, importance = meas, num.trees = 500, mtry = 3, seed = s,
                        replace = FALSE, sample.fraction = 1)
    u <- imp(m); u[1] / (u[1] + u[2]) })
  cat(sprintf("  %-19s %-10s %6.3f   %6.3f\n", meas, ifelse(bg, "on", "OFF"), o[1], o[2]))
}
cat("     (with identical data in every tree plain impurity collapses to winner-take-all;\n",
    "      AIR does not, because its candidate draw is still random)\n")
cat("\n  median a-vs-b spread, mtry=3, seeds 1-6:\n")
for (meas in c("impurity", "impurity_corrected")) for (nt in c(500, 4000)) {
  v <- sapply(1:6, function(s) sp_mean(imp(ranger(y ~ a + b + c, par_data(s),
    importance = meas, num.trees = nt, mtry = 3, seed = s))))
  cat(sprintf("     %-19s trees=%4d : %5.1f%%\n", meas, nt, median(v)))
}
cat("     (more trees help under AIR and do not under plain impurity: lower rho)\n")

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

## Claim 4a: the prediction here is exact, not merely ordinal. Each feature is
## U(1,2), so E[X^m] = (2^(m+1)-1)/(m+1) gives the variance contributions in
## closed form and hence the predicted MDI ratio. The equivalent linear
## coefficient -- what beta a linear term would need to earn the same
## importance -- is sd(f(X))/sd(X), which equals the OLS slope of f(X) on X
## divided by Corr(X, f(X)); those correlations are the same ones that separate
## the two worlds under standardised OLS in Claim 5.
cat("\n=== Claim 4a: closed-form variance contributions, X ~ U(1,2) ===\n")
Em <- function(m) (2^(m + 1) - 1) / (m + 1)
Vk <- function(k) Em(2 * k) - Em(k)^2
v1 <- Vk(1); v2 <- Vk(2); v3 <- Vk(3)
cat(sprintf("  Var(X)=%.6f (1/12)  Var(X^2)=%.6f (34/45)  Var(X^3)=%.6f (457/112)\n",
            v1, v2, v3))
cat(sprintf("  predicted MDI ratio        : 1 : %.2f : %.2f\n", v2/v1, v3/v1))
cat(sprintf("  equivalent linear beta     : b^2 -> %.2f   c^3 -> %.2f\n",
            sqrt(v2/v1), sqrt(v3/v1)))
U <- 1 + runif(2e6)
for (k in c(2, 3)) {
  b_ols <- cov(U^k, U) / var(U); rho <- cor(U, U^k)
  cat(sprintf("    check X^%d: OLS slope %.4f / corr %.4f = %.4f\n",
              k, b_ols, rho, b_ols / rho))
}

## Claim 4b: mtry and truncation act here exactly as in Claim 1a/1a-depth, and
## the default-mtry compression is what puts the headline ratio at ~1:4.7:22.6,
## about half the predicted 1:9.07:48.96. Truncation starves the weak feature
## for longer than in the linear design (no splits at all out to depth 4),
## because the true contributions are spread wider.
cat("\n=== Claim 4b: mtry and depth sweeps, y = a + b^2 + c^3 ===\n")
mk_nl <- function(s) {
  set.seed(s)
  tibble(a = 1 + runif(n), b = 1 + runif(n), c = 1 + runif(n), y = a + b^2 + c^3)
}
for (mt in 1:3) {
  R <- t(sapply(1:10, function(s)
    rel(imp(ranger(y ~ ., mk_nl(s), importance = "impurity",
                   num.trees = 500, mtry = mt, seed = s)))))
  cat(sprintf("  mtry=%d            : 1 : %5.2f : %6.2f\n", mt,
              mean(R[, 2]), mean(R[, 3])))
}
for (md in c(2, 4, 8, 0)) {
  R <- t(sapply(1:10, function(s)
    rel(imp(ranger(y ~ ., mk_nl(s), importance = "impurity", num.trees = 500,
                   mtry = 3, max.depth = md, seed = s)))))
  cat(sprintf("  mtry=3 depth=%-9s: 1 : %5.2f : %6.2f\n",
              ifelse(md == 0, "unlimited", md), mean(R[, 2]), mean(R[, 3])))
}
cat("  -> Inf = weakest feature earns no splits at all at that depth\n")

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
## Debiasing does not help either: AIR subtracts the impurity a permuted copy of
## each feature would earn, and permuting commutes with monotone transforms, so
## under a shared seed the correction is pinned exactly like plain impurity.
air_nl  <- imp(ranger(y ~ ., df_nl,  importance = "impurity_corrected", num.trees = 500, seed = 42))
air_inc <- imp(ranger(y ~ ., df_inc, importance = "impurity_corrected", num.trees = 500, seed = 42))
cat("  AIR         ratio /a  nl:", round(rel(air_nl), 2), " inc:", round(rel(air_inc), 2),
    " max rel diff:", max(abs(air_nl - air_inc)/air_nl),
    " <-- debiased impurity is pinned exactly too\n")
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
## By the proposition, an unseeded cross-world pair is distributed exactly as
## refitting ONE world under two seeds, so the gap above is pure seed noise;
## this same-world pair illustrates the scale of that noise.
cat("  [control] same world, seeds 42/43:",
    signif(reldiff(imp(ranger(y ~ ., df_nl, importance = "impurity", num.trees = 500, seed = 42)),
                   imp(ranger(y ~ ., df_nl, importance = "impurity", num.trees = 500, seed = 43))), 3),
    " <-- seed noise exceeds the cross-world gap\n")
## Sweep: the corollary says fitting world B under seed s gives the SAME trees as
## world A under s, so (a) the identity should hold at every seed, and (b) the
## cross-world gap under seeds (s1, s2) should equal the same-world gap under
## (s1, s2) not just in distribution but pairwise, value for value. This is an
## implementation check on ranger (tie handling, RNG consumption), not extra
## evidence for the theorem.
sweep_seeds <- 1:10
impA <- sapply(sweep_seeds, function(s)
  imp(ranger(y ~ ., df_nl,  importance = "impurity", num.trees = 500, seed = s)))
impB <- sapply(sweep_seeds, function(s)
  imp(ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500, seed = s)))
cat("  [sweep] identity at each of seeds 1-10, max rel diff:",
    max(sapply(sweep_seeds, function(i) reldiff(impA[, i], impB[, i]))),
    " <-- exactly 0 at every seed\n")
pairs <- combn(length(sweep_seeds), 2)
d_same  <- apply(pairs, 2, function(p) reldiff(impA[, p[1]], impA[, p[2]]))
d_cross <- apply(pairs, 2, function(p) reldiff(impA[, p[1]], impB[, p[2]]))
cat("  [sweep] 45 seed pairs: cross-world == same-world pairwise?",
    identical(d_cross, d_same),
    "; seed-noise range", paste(signif(range(d_same), 2), collapse = "-"), "\n")
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
