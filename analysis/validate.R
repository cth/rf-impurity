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

cat("ranger version:", as.character(packageVersion("ranger")), "\n\n")

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
m_imp  <- ranger(y ~ ., df, importance = "impurity",           num.trees = 500)
m_corr <- ranger(y ~ ., df, importance = "impurity_corrected", num.trees = 500)
cat("  OOB R^2 (impurity model):", round(m_imp$r.squared, 3), "\n")
cat("  impurity  vip a,b,c   :", round(imp(m_imp), 1), "\n")
cat("  impurity  ratio /a    :", round(rel(imp(m_imp)), 2), "  (coef ratio 1,2,4)\n")
cat("  corrected ratio /a    :", round(rel(imp(m_corr)), 2), "\n")

## Super-linear growth: y = 1a + 2b + ... + 11k, fit vip ~ effect and ~ effect^2
cat("\n=== Claim 1b: vip vs. linear effect size, linear vs quadratic fit ===\n")
n <- 1000
eff <- 1:11
cols <- lapply(eff, function(i) runif(n))
names(cols) <- letters[1:11]
X <- as_tibble(cols)
X$y <- as.matrix(X) %*% eff
m <- ranger(y ~ ., X, importance = "impurity", num.trees = 1000)
v <- imp(m)
d <- data.frame(x = eff, y = as.numeric(v))
r2lin  <- summary(lm(y ~ x, d))$r.squared
r2quad <- summary(lm(y ~ x + I(x^2), d))$r.squared
cat("  R^2 linear fit vip~effect     :", round(r2lin, 3), "\n")
cat("  R^2 quadratic fit vip~effect^2:", round(r2quad, 3), "\n")

## ---------------------------------------------------------------------------
## Claim 2: pure THREE-WAY parity interaction. OLS is blind even with all
##          pairwise product terms (two-way parity would be bilinear and thus
##          OLS-recoverable); RF captures it and the three interacting variables
##          outrank the independent variable c.
## ---------------------------------------------------------------------------
cat("\n=== Claim 2: three-way parity y = c/10 + (a+b+d) mod 2 ===\n")
set.seed(42); n <- 10000
ib <- function(n) round(runif(n))
df <- tibble(a = ib(n), b = ib(n), d = ib(n), c = ib(n), y = c/10 + (a + b + d) %% 2)
## sanity: two-way binary parity is exactly bilinear -> OLS+a:b fits it perfectly
two_way <- tibble(a = ib(n), b = ib(n), c = ib(n), y = c/10 + (a + b) %% 2)
cat("  [check] 2-way parity, OLS y~a+b+c+a:b R^2 :",
    round(summary(lm(y ~ a + b + c + a:b, two_way))$r.squared, 3),
    "(bilinear -> ~1, why we use 3-way)\n")
ols_pair <- lm(y ~ (a + b + d)^2 + c, df)      # all main + pairwise terms
ols_full <- lm(y ~ a * b * d + c, df)          # incl. the 3-way product
cat("  OLS R^2 (main + all pairwise) :", round(summary(ols_pair)$r.squared, 3), "\n")
cat("  OLS R^2 (incl. 3-way product) :", round(summary(ols_full)$r.squared, 3), "\n")
cat("  OLS |coef| (pairwise model)   :", round(abs(coef(ols_pair)[-1]), 3), "\n")
mrf <- ranger(y ~ a + b + d + c, df, importance = "impurity", num.trees = 500)
cat("  RF  OOB R^2             :", round(mrf$r.squared, 3), "\n")
v <- imp(mrf)
cat("  RF  vip a,b,d,c         :", round(v, 1), "\n")
cat("  interaction vars > c ?  :", (min(v["a"], v["b"], v["d"]) > v["c"]), "\n")

## ---------------------------------------------------------------------------
## Claim 3: variance-splitting mechanics on sorted polynomials.
##   (a) minimum split-variance grows with polynomial order
##   (b) argmin of split variance moves away from the centre for higher orders
## ---------------------------------------------------------------------------
cat("\n=== Claim 3: split-variance mechanics on y=x, x^2, x^3 ===\n")
n <- 1000
vos <- function(idx, y) var(y[1:idx]) + var(y[idx:length(y)])
sweep_var <- function(y) sapply(2:(n-2), function(i) vos(i, y))
x <- 1:n
vy1 <- sweep_var(x); vy2 <- sweep_var(x^2); vy3 <- sweep_var(x^3)
cat("  min split-variance y=x, x^2, x^3:",
    format(c(min(vy1), min(vy2), min(vy3)), scientific = TRUE, digits = 3), "\n")
cat("  argmin index (of", n, ") y=x,x^2,x^3:",
    c(which.min(vy1), which.min(vy2), which.min(vy3)) + 1, "\n")
cat("  -> min variance increases with order; argmin shifts left (unbalanced)\n")

## ---------------------------------------------------------------------------
## Claim 4: genuine non-linear effects y = a + b^2 + c^3 -> vip(a)<vip(b)<vip(c)
## ---------------------------------------------------------------------------
cat("\n=== Claim 4: non-linear effects y = a + b^2 + c^3 ===\n")
set.seed(42); n <- 10000
df_nl <- tibble(a = 1+runif(n), b = 1+runif(n), c = 1+runif(n), y = a + b^2 + c^3)
m_nl <- ranger(y ~ ., df_nl, importance = "impurity", num.trees = 500)
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
m_inc <- ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500)
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

cat("\nAll experiments completed.\n")
