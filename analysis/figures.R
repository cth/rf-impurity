# Generate the figures used in paper/. Run after/with validate.R.
# R_LIBS_USER=./.rlib Rscript analysis/figures.R
suppressMessages({ library(tibble); library(ranger) })
dir.create("figures", showWarnings = FALSE)
imp <- function(m) ranger::importance(m)

## Fig 1: importance tracks variance contribution beta^2 * Var(X). Left: vs the
## coefficient (curved). Right: vs beta^2 (near-linear) -- importance is denominated
## in squared-coefficient (variance) units, not coefficient units.
set.seed(43); n <- 1000
eff <- 1:11
X <- as_tibble(setNames(lapply(eff, function(i) runif(n)), letters[1:11]))
X$y <- as.matrix(X) %*% eff
v <- as.numeric(imp(ranger(y ~ ., X, importance = "impurity", num.trees = 1000)))
r2 <- summary(lm(v ~ I(eff^2)))$r.squared
png("figures/fig1_superlinear.png", 900, 460, res = 110)
par(mfrow = c(1, 2))
plot(eff, v, pch = 19, col = "grey20", xlab = expression("coefficient  " * beta),
     ylab = "impurity importance", main = "vs. coefficient")
lines(eff, predict(lm(v ~ eff)), col = "steelblue", lwd = 2, lty = 2)
legend("topleft", "linear fit", col = "steelblue", lty = 2, lwd = 2, bty = "n")
plot(eff^2, v, pch = 19, col = "grey20", xlab = expression("variance contribution  " * beta^2),
     ylab = "impurity importance",
     main = bquote("vs. " * beta^2 * "  (" * R^2 == .(round(r2, 2)) * ")"))
abline(lm(v ~ I(eff^2)), col = "firebrick", lwd = 2)
dev.off()

## Fig 2: three-way parity interaction - OLS (even with all pairwise terms) blind,
## RF importance loads on the three interacting variables
set.seed(42); n <- 10000; ib <- function(n) round(runif(n))
df <- tibble(a = ib(n), b = ib(n), dd = ib(n), c = ib(n), y = c/10 + (a + b + dd) %% 2)
ols <- lm(y ~ (a + b + dd)^2 + c, df)          # all main + pairwise terms
v <- imp(ranger(y ~ a + b + dd + c, df, importance = "impurity", num.trees = 500))
names(v) <- c("a","b","d","c")
png("figures/fig2_interaction.png", 900, 420, res = 110)
par(mfrow = c(1,2))
oc <- abs(coef(ols)[-1])
barplot(oc, las = 2, cex.names = 0.7, col = "grey70",
        main = "OLS |coefficient|\n(all main + pairwise terms)", ylab = "|coef|")
barplot(v, col = c("firebrick","firebrick","firebrick","grey70"),
        main = "RF impurity importance", ylab = "importance")
dev.off()

## Fig 3: the confound - non-linear effects vs linear-effects-skewed-features
set.seed(42); n <- 10000
df_nl  <- tibble(a = 1+runif(n), b = 1+runif(n), c = 1+runif(n), y = a + b^2 + c^3)
set.seed(42)
df_inc <- tibble(a = 1+runif(n), b = (1+runif(n))^2, c = (1+runif(n))^3, y = a + b + c)
v_nl  <- imp(ranger(y ~ ., df_nl,  importance = "impurity", num.trees = 500))
v_inc <- imp(ranger(y ~ ., df_inc, importance = "impurity", num.trees = 500))
png("figures/fig3_confound.png", 900, 420, res = 110)
par(mfrow = c(1,2))
barplot(v_nl,  col = "grey40", main = "Non-linear effects\ny = a + b^2 + c^3", ylab = "importance", ylim = c(0, max(v_nl,v_inc)))
barplot(v_inc, col = "steelblue", main = "Linear effects, skewed features\ny = a + b + c, b~U^2, c~U^3", ylab = "importance", ylim = c(0, max(v_nl,v_inc)))
dev.off()

cat("wrote figures/fig1_superlinear.png fig2_interaction.png fig3_confound.png\n")
