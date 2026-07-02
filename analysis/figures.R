# Generate the figures used in paper/. Run after/with validate.R.
# R_LIBS_USER=./.rlib Rscript analysis/figures.R
suppressMessages({ library(tibble); library(ranger) })
dir.create("figures", showWarnings = FALSE)
imp <- function(m) ranger::importance(m)

## Fig 1: super-linear magnification of importance vs linear effect size
set.seed(43); n <- 1000
eff <- 1:11
X <- as_tibble(setNames(lapply(eff, function(i) runif(n)), letters[1:11]))
X$y <- as.matrix(X) %*% eff
v <- as.numeric(imp(ranger(y ~ ., X, importance = "impurity", num.trees = 1000)))
fitq <- lm(v ~ eff + I(eff^2))
png("figures/fig1_superlinear.png", 780, 560, res = 110)
plot(eff, v, pch = 19, col = "grey20", xlab = "linear coefficient (effect size)",
     ylab = "impurity importance", main = "Importance grows super-linearly in effect size")
lines(eff, coef(lm(v ~ eff))[1] + coef(lm(v ~ eff))[2]*eff, col = "steelblue", lwd = 2, lty = 2)
gx <- seq(1, 11, 0.1); lines(gx, predict(fitq, data.frame(eff = gx)), col = "firebrick", lwd = 2)
legend("topleft", c("linear fit", "quadratic fit"), col = c("steelblue","firebrick"),
       lty = c(2,1), lwd = 2, bty = "n")
dev.off()

## Fig 2: parity interaction - OLS blind, RF importance loads on interaction vars
set.seed(42); n <- 10000; ib <- function(n) round(runif(n))
df <- tibble(a = ib(n), b = ib(n), c = ib(n), y = c/10 + (a + b) %% 2)
ols <- lm(y ~ a + b + c, df)
v <- imp(ranger(y ~ a+b+c, df, importance = "impurity", num.trees = 500))
png("figures/fig2_interaction.png", 900, 420, res = 110)
par(mfrow = c(1,2))
barplot(abs(coef(ols)[-1]), col = "grey70", main = "OLS |coefficient|", ylab = "|coef|")
barplot(v, col = c("firebrick","firebrick","grey70"), main = "RF impurity importance",
        ylab = "importance")
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
