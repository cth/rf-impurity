# Deep review of `paper/impurity-importance.tex` at `21f5ae9`

*Claims audit + narrative evaluation, 2026-09-02. Methods: fresh end-to-end run
of `analysis/validate.R` (ranger 0.18.0, all blocks including the new
fixed-dataset bias test; Claim 5d skipped because `treeshap` is not installed),
independent hand-derivation of every closed-form quantity, one new targeted
experiment (the AIR seed-RSD claim in Section 2, which `validate.R` does not
compute), a check of every finding in `review2.md` (2026-08-13) against the
current text, and a LaTeX build (clean: no warnings, no undefined references).
Section 8's pipeline counts are unchanged since the previous review audited
them against the raw JSONs and were not re-audited.*

## Verdict

The paper has moved since the last review — the three-way parity design became
two-way, the interaction section gained a variance-decomposition derivation and
a proper bias test, and five of the earlier findings were fixed. Every number
that can be checked reproduces. What remains is one substantive problem carried
over from the last review (the Proposition still overclaims), one new tension
between Sections 2 and 7 about AIR, and a cluster of small gaps in the rewritten
Section 3. Nothing found changes a conclusion.

## Claims audit

**Section 2 (linear).** All reproduce to the stated precision: 1:2.39:7.76 and
AIR 1:6.23:25.9 (single seed); the mtry sweep 1:2.25:7.26 / 1:3.93:15.5 /
1:4.45:19.1; the depth sweep (weakest feature earns no splits at depth 2 with
mtry=p; 1:12.0:58.3 at depth 4; 1:3.38:12.1 at depth 2, mtry=1); the n sweep
(1:4.15:17.1 at 4000, 1:4.01:16.1 at 64000, 1:3.51:13.7 at mtry=1); the β²
regression (0.977 vs 0.907, ranges 0.959–0.994 vs 0.884–0.938, β² wins every
seed; figure caption's 0.99 is the single-seed value); AIR mtry-insensitivity
1:4.4:17.5 / 1:4.1:16.6 / 1:4.1:16.8; AIR's c-ratio range 10.2–25.9 vs 6.3–8.1,
with the tabled 25.9 the maximum; rank fidelity 3/10 perfect, Spearman 0.99 for
both measures at the p=11 default mtry=3.

The "33% against 11% relative SD, strongest feature steady at 6%" claim is
**not computed by `validate.R`** (its RSD line is for the 11-feature design).
Recomputed independently (seeds 1–10, n=1000, 500 trees, default mtry):
impurity RSD a,b,c = 11%, 6%, 6%; AIR = 33%, 7%, 6%. The text is exactly right.
Worth adding to the script so every cited number is script-backed.

**Section 3 (interactions).** OLS 0.000/0.000/0.101, R²=0.01, R²=1 with a×b;
total 2525.2 at mtry=3 with c at 1.02%; seeds 1–10 at mtry=1: a,b 451 (SD 29),
c 15; spread 2–20% (median 10%); control 1–6%; the bias test (6/6 same side,
forest SD 0.011–0.023 → 0.003–0.006, largest mean shift 0.013, spread 3–119%);
AIR 13.3% vs 29.1% at mtry=p, indistinguishable at mtry=1 (Wilcoxon p=0.87),
OOB R² 0.946. All match.

Hand-checked: Var(c/10)=0.0025, Var(parity)=0.25, n·Var(y)=2525, c share
0.99%, main-effects R² = Var(c/10)/Var(y) = 0.0099 (so "exactly the explained
variance of main-effects OLS" is correct as a population statement).

Two precision notes. (a) "the measured total is 2525.2 = n Var(y)": the sample
n·Var(y) is 2525.9 and the total sum of squares is 2525.6; the forest total is
an average over bootstrap samples, so ≈ is the honest sign. (b) "its importance
increases to 1.7%": the 1.7% (0.0172) is seed 42's single fit; the seed-average
figures the sentence attaches it to give 15/(2·451+15) = 1.6%.

**Section 4 (split mechanics).** 4.2e4 / 4.3e10 / 4.1e16; 0.75 / 0.76 / 0.74;
argmin 500 / 697 / 799. All match.

**Section 5 (non-linear).** 1751 < 8166 < 39632 (1:4.7:22.6); sweep
1:4.58:22.4 / 1:8.90:47.7 / 1:9.63:52.8; no splits for the weakest feature out
to depth 4; 1:11.5:63.5 at depth 8. Closed forms re-derived: E[X^m] =
(2^{m+1}−1)/(m+1) gives Var(X²) = 31/5 − 49/9 = 34/45 and Var(X³) = 127/7 −
225/16 = 457/112; ratio 1:9.07:48.96; β_equiv = √ = 3.01, 7.00; Corr(X,X²) =
0.9963, Corr(X,X³) = 0.9861. All match.

**Section 6 (confound).** Identity exact (max rel diff 0) for MDI and AIR;
permutation 1:9.2:50.3; standardised OLS 1:2.98:6.88 vs 1:2.99:6.98, gap 0.014;
2.98/2.99 = 0.997 and 6.88/6.98 = 0.986 reproduce the correlations; exact at all
10 seeds; 45/45 pairs cross-world = same-world, noise 0.1–2.7%; extratrees 3.3%
(1:4.9:23.7 vs 1:5.0:24.6). The SHAP row (1:3.06:6.98, 1.3e-4) and the "two
observations on 0.3% of nodes" claim could not be re-run here (`treeshap`
absent); they were verified in the previous review and the text is unchanged.

**Section 8 (prevalence).** Every count in the text and table (3,189 / 773 /
524 / 544 / 307 / 125 / 55 / 65 / 5; 24 and 11 of 40; 51 of 55; medians 11 vs
10; 12 over 50 citations; 10% / 18% / 7%) is identical to the version the
previous review verified against the raw JSONs. Not re-audited.

**References.** Unchanged since the last review except one addition:
`hastie2009` was added to `bibliography.bib` but its only citation is now
inside a commented-out block of `interactions.tex`, so it is dead. Either
restore an ESL citation or drop the entry.

## Status of the previous review's findings

| # | Finding (review2.md) | Status at 21f5ae9 |
|---|---|---|
| 1 | Proposition claims *every* importance coincides exactly; table shows permutation at ~1e-4 | **Open** — `confound.tex:30-31` unchanged |
| 2 | "OLS OOB R²" mislabel | Fixed ("The forest's OOB R²") |
| 3 | Strobl/Nembrini misattributed to correlated predictors | Fixed |
| 4 | Relevance-filter regex exists only in LaTeX | **Open** — `fingerprint.py` still holds the old narrow filter; the JS workflows hold prompts, not the regex |
| 5 | Scornet/Louppe qualifiers | Fixed ("totally randomised trees on categorical inputs"; "truncated (not fully grown) trees") |
| 6 | "corpus median of 10" should be "screened-set median" | **Open** — `prevalence.tex:140` |
| 7a | Section 4 sweep uses unweighted child variances | Open (harmless; `frac_removed` is weighted) |
| 7b | "≈0.10" for the d coefficient | Moot — design changed |
| 7c | "the spread is not exactly the 1:4:16, the ratio…" grammar | **Open** — `linear.tex:24` |
| 7d | "overturning roughly 56%" counts uncertain as overturned | Open — `prevalence.tex:92` |
| N1 | Abstract: "five controlled experiments" then (i)–(iii) | Open — `impurity-importance.tex:35-40` |
| N2 | Section 6 density before the table | Open |
| N3 | "not A but B" framing | Partly — several remain, incl. the title |
| H | `results.md` Caveats block says Haiku pass unverified | **Open** — `results.md:173-176` |
| T | TreeSHAP 0.3% not in `validate.R` | Open — Claim 5d comment only |

## Findings (ranked)

1. **The Proposition still overclaims** (`confound.tex:30-31`). "The two
   forests are identical tree for tree, and every importance derived from them
   coincides exactly" is contradicted by the table on line 74, where
   permutation importance — derived from those forests — agrees to ~1e-4. The
   later paragraph (lines 93–98) already gives the correct account: the trees
   are identical as *partitions of the in-bag sample*, but thresholds are
   midpoints between adjacent values and the midpoint of squares is not the
   square of the midpoint, so out-of-sample and shuffled values can fall on
   different sides. The fix is a scope change in the statement: "every
   importance that is a functional of those partitions (MDI, AIR) coincides
   exactly." A referee who reads the theorem and then the table will stop here.

2. **Section 7 recommends AIR as "the right default"; Section 2 shows it is
   3–20× noisier per seed** (`guidance.tex:30-33` vs `linear.tex:96-105`,
   `validate.R` Claim 1d). Section 2 says AIR's weakest-feature score varies 33%
   from seed to seed against 11% (recomputed: correct), that AIR ratios "are
   readable only as an average over seeds," and the 11-feature run gives AIR
   per-seed RSDs of 108% / 59% / 41% on the three weakest features. Section 7
   then says "use it — it is the right default." Both can be true — AIR is the
   right default for the *type bias* — but the guidance needs the qualifier the
   evidence demands: right default for mixed feature types, at the cost of
   substantially higher seed-to-seed variance on weak features; average over
   seeds or forests before reading a ratio.

3. **Section 3's 1.7% now arrives without its explanation** (`interactions.tex:34-36`).
   The paragraph derives c's share as exactly 1%, confirms 1.02% at mtry=3, then
   says at mtry=1 "its importance increases to 1.7% rather than 1%" and moves
   on. The truncation mechanism (a node whose only candidate is constant
   becomes terminal; the loss falls harder on the pair, whose credit needs both
   variables on one path) was cut in this revision and nothing replaced it. As
   written, the number reads as a contradiction of the derivation two sentences
   earlier. One clause restores it. See also the 1.6%/1.7% note in the audit.

4. **"Best OOB generalization" is asserted without its number**
   (`interactions.tex:77-79`). The argument's punchline — the mtry that
   generalizes best is the one whose a/b division is least trustworthy — rests
   on mtry=p having the best OOB R², which the section never states. The script
   has it: 1.000 at mtry=3 against 0.926 and 0.592. Put the two numbers in the
   sentence.

5. **Section 3 wording.**
   - `:4` "does not need to imply" → "need not imply".
   - `:31` "Note, this is exactly…" → "Note that this is…".
   - `:42` "equal marginal effects on the same three features" — c's coefficient
     is 1/10, a and b get 1/2; with the formula now shown, a reader will see the
     effects are not equal. "equal marginal effects for a and b" is what is
     meant.
   - `:61-62` "tilt" twice; the section otherwise uses "allocation"/"division".
   - `:80-81` "AIR shows improvement at mtry=p (13.3% against 29.1%)" — the
     numbers are still unlabeled (median a-vs-b spread, AIR vs plain).

6. **Section 2 wording.**
   - `:24` the grammatical stumble from the previous review is still there.
   - `:66` "for increasing larger values n" → "as n grows".
   - `:75-78` "regressing importance on β²" appears in two consecutive
     sentences.
   - `:130` "Furthermore," now opens a paragraph whose remainder is four
     commented-out lines; it compiles fine but the source is fragile.

7. **Repo hygiene.** `nonlinear.tex:1-19` still carries the previous version
   under a "delete once settled" comment; `hastie2009` is dead in the bib;
   `results.md` Caveats still say the Haiku pass is unverified; the relevance
   regex still lives only in the paper; the 33/11/6% RSDs and the TreeSHAP 0.3%
   are the two cited numbers `validate.R` does not produce. `validate.R:210`
   says the default mtry is `floor(p/3)` — ranger uses `floor(sqrt(p))` for
   regression too (the paper has this right); same value at p=3, wrong comment.

## Narrative

The two-way switch was the right call. The old three-way design needed a
pairwise-OLS foil and a four-variable figure to make its point; the new one
makes it with three bars and a one-line bilinear identity, and the reader gets a
cleaner contrast: a linear model *can* represent this interaction if told to
look for it, the forest finds it unprompted and charges it to a and b. The
variance-decomposition derivation (1% / 99%, confirmed at 1.02%) is the
strongest addition — it turns "the pair gets most of the credit" from an
observation into a prediction, and ties Section 3 to the identity the rest of
the paper runs on.

The a-vs-b bias argument is now well-evidenced but reads as two arguments
stapled together. Paragraph 4 (lines 45–69) makes the mechanistic case —
topology, the candidate draw at mtry=1, the data-driven choice at mtry=p — and
lands the bias test. Paragraph 5 (lines 77–87) then returns to Breiman and
mtry, and AIR. A reader arrives at "The mtry setting that results in the best
OOB generalization is therefore…" having been told what mtry does twice. The
Breiman quote earns its place; the sentence after it ("At mtry=p none of that
randomness is injected") is the link the "therefore" needed; but the whole
Breiman passage would sit more naturally *before* the bias test, as the reason
to expect a bias, rather than after it as a second explanation.

Section 7 is the place where a practitioner will land, and item 3 currently
tells them something Section 2 spent a page qualifying. That is the one
narrative-level fix that matters (finding 2).

The Proposition (finding 1) remains the paper's centerpiece and its one
exposed flank. Everything around it — the descending-strictness table, the
standardised-OLS control with the closed-form Corr(b,b²) gap, the seed-noise
corollary — is exactly right. The statement just needs to promise what the
table delivers.
