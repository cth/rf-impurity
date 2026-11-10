# How mean |SHAP| and permutation importance allocate importance on the parity
# interaction of Section "Interactions" (paper/sections/interactions.tex),
# against MDI and AIR. Standalone companion to validate.R (Claim 2).
# Run: R_LIBS_USER=/home/cth/R/library Rscript analysis/interactions_shap_perm.R

suppressMessages({
  library(tibble)
  library(ranger)
  library(treeshap)
})

n <- 10000
ib <- function(n) round(runif(n))
par_data <- function(s) {
  set.seed(s); z <- tibble(a = ib(n), b = ib(n), c = ib(n))
  z$y <- z$c / 10 + (z$a + z$b) %% 2; z
}
imp <- function(m) ranger::importance(m)
mean_shap <- function(m, d) {   # same convention as Claim 5d (first 300 rows)
  u <- treeshap::ranger.unify(m, d[, c("a", "b", "c")])
  colMeans(abs(treeshap::treeshap(u, d[1:300, c("a", "b", "c")],
                                  verbose = FALSE)$shaps))
}
sp_mean <- function(u) 100 * abs(u[1] - u[2]) / mean(c(u[1], u[2]))

## ---------------------------------------------------------------------------
## 0. Calibration: ranger's regression permutation importance IS the OOB MSE
##    increase (verified against a hand replication below). On a noiseless
##    binary target that increase is 2 * Var(lost contribution), because
##    scrambling substitutes an independent copy: E[(X - X')^2] = 2 Var(X).
## ---------------------------------------------------------------------------
cat("=== 0. Permutation-importance scaling, marginal-effect controls ===\n")
for (fml in c("y = a", "y = c/10", "y = (a+b)/2")) {
  d <- switch(fml,
    "y = a"      = { set.seed(42); tibble(a = ib(n), b = ib(n), c = ib(n), y = a) },
    "y = c/10"   = { set.seed(42); tibble(a = ib(n), b = ib(n), c = ib(n), y = c/10) },
    "y = (a+b)/2" = { set.seed(42); tibble(a = ib(n), b = ib(n), c = ib(n), y = (a+b)/2) })
  u <- imp(ranger(y ~ a + b + c, d, importance = "permutation",
                  num.trees = 500, mtry = 3, seed = 42))
  cat(sprintf("  %-12s perm imp a,b,c: %8.4f %8.4f %8.4f\n", fml, u[1], u[2], u[3]))
}
cat("  (MSE increase = 2*Var here: 0.5, 0.005, 0.125 for a, c, a+b)\n")
## Hand replication: ranger reports the MSE increase, not a doubled value.
d <- tibble(a = ib(n), b = ib(n), c = ib(n), y = a)
m <- ranger(y ~ a + b + c, d, importance = "permutation", num.trees = 500,
            mtry = 3, seed = 42, keep.inbag = TRUE)
pall <- predict(m, data = d, predict.all = TRUE)$predictions
manual_mse <- function(j, seed = 1) {
  set.seed(seed); s0 <- s1 <- 0; cnt <- 0
  for (k in seq_along(m$inbag.counts)) {
    oob <- which(m$inbag.counts[[k]] == 0); if (!length(oob)) next
    xk <- d[oob, c("a", "b", "c")]; xk[[j]] <- sample(xk[[j]])
    pk <- predict(m, data = xk, predict.all = TRUE)$predictions[, k]
    s0 <- s0 + sum((d$y[oob] - pall[oob, k])^2)
    s1 <- s1 + sum((d$y[oob] - pk)^2); cnt <- cnt + length(oob)
  }
  (s1 - s0) / cnt
}
mm <- sapply(1:3, manual_mse)
cat(sprintf("  hand-replicated MSE increase a,b,c: %.5f %.5f %.5f\n",
            mm[1], mm[2], mm[3]))

## ---------------------------------------------------------------------------
## 1. Allocation on the parity design, dataset seed 42, 500 trees
## ---------------------------------------------------------------------------
cat("\n=== 1. Importance allocation on y = c/10 + (a+b) mod 2 (seed 42) ===\n")
d <- par_data(42)
cat("  measure         mtry        a        b        c   c-share  a/(a+b)\n")
alloc <- list()
for (mt in c(1, 3)) {
  m_imp <- ranger(y ~ a + b + c, d, importance = "impurity",
                  num.trees = 500, mtry = mt, seed = 42)
  m_cor <- ranger(y ~ a + b + c, d, importance = "impurity_corrected",
                  num.trees = 500, mtry = mt, seed = 42)
  m_per <- ranger(y ~ a + b + c, d, importance = "permutation",
                  num.trees = 500, mtry = mt, seed = 42)
  sh <- mean_shap(m_imp, d)
  cat(sprintf("  OOB R^2 (mtry=%d): impurity %.3f  AIR %.3f  permutation %.3f\n",
              mt, m_imp$r.squared, m_cor$r.squared, m_per$r.squared))
  rows <- list(MDI = imp(m_imp), AIR = imp(m_cor),
               Permutation = imp(m_per), `mean|SHAP|` = sh)
  alloc[[as.character(mt)]] <- rows
  for (nm in names(rows)) {
    u <- rows[[nm]]
    cat(sprintf("  %-14s %3d %8.3f %8.3f %8.3f   %6.3f   %.3f\n",
                nm, mt, u[1], u[2], u[3], u[3] / sum(u), u[1] / (u[1] + u[2])))
  }
}

## ---------------------------------------------------------------------------
## 2. Does the measure split the pair's credit, or credit each member fully?
##    Permutation is an MSE increase; on these binary targets that is 2x the
##    destroyed variance (block 0), so perm/2 is the variance-equivalent.
## ---------------------------------------------------------------------------
cat("\n=== 2. Per-observation units: who is credited with the interaction? ===\n")
cat("  at mtry=3 the model is exact (R^2 = 1), so the interaction variance\n",
    "  Var((a+b) mod 2) = 0.25 and Var(c/10) = 0.0025 are the targets.\n")
for (mt in c(1, 3)) {
  u <- alloc[[as.character(mt)]]
  mdi_pair <- (u$MDI[1] + u$MDI[2]) / n          # MDI splits the pair credit
  per_a    <- u$Permutation[1] / 2                # variance-equivalent (block 0)
  sh_a     <- u$`mean|SHAP|`[1]
  cat(sprintf("  mtry=%d  MDI pair/n %.4f (%.4f + %.4f)   perm_a/2 %.4f   SHAP|phi_a| %.4f\n",
              mt, mdi_pair, u$MDI[1] / n, u$MDI[2] / n, per_a, sh_a))
  cat(sprintf("          perm_a/2 / (MDI pair) = %.2f  -> permutation credits EACH member\n",
              per_a / mdi_pair))
  cat("              the FULL joint effect; summed over the pair it double-counts it\n")
  cat(sprintf("          SHAP|phi_a| / (MDI pair) = %.2f  -> each member gets half the\n",
              sh_a / mdi_pair))
  cat("              interaction's absolute deviation (phi_a + phi_b = parity - 0.5)\n")
}

## ---------------------------------------------------------------------------
## 3. Multi-seed: c-share and the a-vs-b division, seeds 1-10
## ---------------------------------------------------------------------------
cat("\n=== 3. Seeds 1-10: c-share and a/(a+b) division of the pair's credit ===\n")
cat("  measure         mtry  mean c-sh  med c-sh  mean a/(a+b)  med a-spread  outside [.45,.55]\n")
S <- 10
for (mt in c(1, 3)) {
  M <- lapply(c("impurity", "impurity_corrected", "permutation"), function(meas)
    t(sapply(1:S, function(s)
      imp(ranger(y ~ a + b + c, par_data(s), importance = meas,
                 num.trees = 500, mtry = mt, seed = s)))))
  SH <- t(sapply(1:S, function(s)
    mean_shap(ranger(y ~ a + b + c, par_data(s), importance = "impurity",
                     num.trees = 500, mtry = mt, seed = s), par_data(s))))
  names(M) <- c("impurity", "impurity_corrected", "permutation")
  V <- c(M, list(`mean|SHAP|` = SH))
  for (nm in names(V)) {
    P <- V[[nm]]
    cat(sprintf("  %-14s %3d    %.3f    %.3f      %.3f        %5.1f%%         %2d/%d\n",
                nm, mt,
                mean(P[, 3] / rowSums(P)), median(P[, 3] / rowSums(P)),
                mean(P[, 1] / (P[, 1] + P[, 2])),
                median(apply(P, 1, sp_mean)),
                sum(P[, 1] / (P[, 1] + P[, 2]) < .45 | P[, 1] / (P[, 1] + P[, 2]) > .55),
                S))
  }
}
cat("  -> MDI at mtry=3 divides the pair credit by a sample-fixed winner-take-all\n",
    "     (paper: spread 29.1%); SHAP and permutation divide it ~evenly (spread =\n",
    "     exchangeable noise only). Permutation credits each member the full joint\n",
    "     effect: summing the pair double-counts the interaction.\n")

## ---------------------------------------------------------------------------
## 4. Table-ready allocation, seed 42: ratios normalised to c
## ---------------------------------------------------------------------------
cat("\n=== 4. Allocation normalised to c (seed 42, 500 trees) ===\n")
cat("  mtry  measure          a : b : c      c-share  a/(a+b)\n")
for (mt in c(1, 3)) {
  rows <- alloc[[as.character(mt)]]
  for (nm in names(rows)) {
    u <- rows[[nm]]; r <- u / u[3]
    cat(sprintf("  %4d  %-14s %5.1f : %4.1f : 1    %.3f    %.3f\n",
                mt, nm, r[1], r[2], u[3] / sum(u), u[1] / (u[1] + u[2])))
  }
}
