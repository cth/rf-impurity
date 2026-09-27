# Deep review of `paper/impurity-importance.tex` at `4134c3b`

*Claims audit + narrative evaluation, 2026-09-03. Methods: fresh end-to-end run
of `analysis/validate.R` (ranger 0.18.0; output identical to this morning's run
apart from the two new RSD lines), `analysis/tally.py` over all 773 records,
hand re-derivation of the closed forms, one new targeted experiment (the PDP
claims in the Section 3 and 6 implications paragraphs, which no script backs),
a check of every finding in `review-21f5ae9.md` against the current text, a
clean build of both masters (main 13 pp., TAS 25 pp.; no warnings, no orphaned
bib keys). Eleven commits since the last review: the guidance section removed,
section-level "Practical implications" paragraphs added, the Proposition
scoped, and the prevalence screen extended to all 773 full texts.*

## Verdict

Every number reproduces. The structural changes since the last review are
improvements: the Proposition now promises what its table delivers, the
guidance section's advice has moved to where its evidence is, and Section 7 no
longer depends on a relevance filter or a 20-paper historical footnote. What
remains is one consistency problem that the restructuring has made more
visible (Section 7 credits permutation importance as corroboration; Section 6
now says in so many words that it is not), one muddled connective in Section
5, and small wording debris in Sections 3 and 6 from the rewrites. Nothing
changes a conclusion.

## Claims audit

**Sections 2–6.** All numbers cited match `validate.R` to the stated
precision. Changes since the last review, re-checked: Section 3's 1.6%
(15/(2·451+15) = 1.64%), the OOB R² pair 1.00 / 0.59 (1.000 / 0.592), the
33% / 11% / 6% AIR RSDs (now computed by the script: 11/6/6 vs 33/7/6). The
bias test (6/6 same side, SD 0.011–0.023 → 0.003–0.006, spread 3–119%) and
the AIR comparison (13.3% vs 29.1%, OOB 0.946) reproduce exactly.

**New targeted experiment — the PDP claims.** Two statements added in the
implications paragraphs had no script behind them. Both hold:

- *Section 3:* "a flat one-way partial-dependence plot … the parity appears
  only in the joint PDP over (a,b)." Parity design, default mtry: one-way PDP
  over a is 0.544 / 0.556, over b 0.552 / 0.547 (flat to ±0.01; exactly flat
  at mtry = p, 0.549 / 0.549); the joint PDP is 0.367 / 0.721 / 0.738 / 0.373 —
  the parity pattern.
- *Section 6:* "the PDP of the skewed-feature world is a straight line while
  the non-linear world's curves." PDP over b at 19 matched quantile positions:
  world A quadratic coefficient 1.03 (true 1.0), p < 10⁻⁴; world B quadratic
  coefficient 0.002, p = 0.82, linear R² 0.9993.

Worth adding to `validate.R` as a block so the two paragraphs are
script-backed like everything else.

**Section 7.** `tally.py` over the 773 extraction and 129 adjudication
records: 331 / 129 / 56 / 68 / 5; 7.2% of full texts, 16.9% of impurity users;
refuted 52.7%, uncertain 3.9%, precision 43.4%; 52/56 = 92.9% with no p-value
machinery; citation medians 11 vs 10; 12 confirmed above 50 citations. Every
figure in the text and table matches. The 229 new records are tagged
`set: "complement"`; the four new flags were adjudicated under the identical
Sonnet prompt; one confirmed (W4280581368).

**Closed forms.** Var(X²) = 34/45, Var(X³) = 457/112, ratio 1:9.07:48.96,
β_equiv 3.01 / 7.00, Corr 0.9963 / 0.9861, Var(c/10)/Var(y) = 0.0099 — all
re-derived, all match.

**Not re-run.** The SHAP row (1:3.06:6.98, 1.3e-4) and the "two observations
on 0.3% of nodes" TreeSHAP claim — `treeshap` is not installed here; verified
in `review2.md`, text unchanged.

## Status of the previous review's findings

| # | Finding (review-21f5ae9.md) | Status |
|---|---|---|
| 1 | Proposition overclaims (every importance) | **Fixed** — scoped to in-bag partitions, MDI/AIR |
| 2 | Sec 7 "AIR is the right default" vs Sec 2 noise | **Fixed** — section removed; Sec 2 implications carry the qualifier |
| 3 | 1.7% without its reason | **Fixed** — 1.6% with truncation mechanism |
| 4 | "best OOB generalization" without numbers | **Fixed** |
| 5–6 | Sec 2/3 wording | **Fixed** |
| 7 | hastie2009 dead; results.md stale; regex only in LaTeX; RSD not scripted; old Sec 5 draft | **Fixed** (all five) |
| 7 | TreeSHAP 0.3% not scripted | Open |
| 7 | Sec 4 sweep unweighted (`vos`) | Open, harmless |
| — | Sec 6 `--` and missing "the" (noted in-session) | **Open** — `confound.tex:14-16` |
| — | Title's "not A but B" framing | Open (author's call) |

## Findings (ranked)

1. **Section 7 credits permutation importance as corroboration; Section 6 now
   says explicitly that it isn't** (`prevalence.tex:46-48` vs
   `confound.tex:145-147`). The method defines corroboration as "permutation
   importance, SHAP, PDP/ALE, conditional importance, or held-out validation".
   The paper then concedes that counting *SHAP* is generous, because mean |SHAP|
   carries the same confound (`:52-57`). The identical argument applies to
   permutation importance — Section 6's table pins it at ~10⁻⁴, and the
   implications paragraph says "no marginal importance can say which — not
   plain or debiased impurity, not permutation". A referee who reads the
   implications paragraph and then the screening criterion will ask why
   permutation counts. The answer is the same as for SHAP: it can only
   suppress flags, so the count is conservative. One clause in the
   "Counting SHAP as corroboration is generous" paragraph — "the same holds
   for permutation importance, which Section 6 shows is pinned by the same
   proposition" — closes it and strengthens the conservatism claim.

2. **Section 5's connective points the wrong way** (`nonlinear.tex:36`). The
   preceding paragraph explains the default-mtry shortfall as *mtry dilution*
   and shows the table. The next sentence opens "This is a truncation effect:
   at mtry = p the weakest feature gets no splits at all out to depth 4". "This"
   reads as the mtry shortfall just discussed, but the sentence is about
   *depth* truncation at mtry = p — a different setting and a different
   mechanism. The commented-out original ("Truncation bites harder here than
   in Section 2") made the transition. Something like "Depth truncation is also
   stronger here than in Section 2:" restores it.

3. **Section 3 debris from the rewrites** (`interactions.tex`).
   - `:59` "every tree re-derives the same choice from the same data" and
     `:64` "every tree re-derives the same allocation from the same data" —
     the same sentence twice, five lines apart. The second is the one doing
     work (it leads into the bias test); the first can go.
   - `:33` "the measured total is 2525.2 = n Var(y)" — sample n·Var(y) is
     2525.9 and the total sum of squares 2525.6; the forest total averages over
     bootstrap samples. ≈ is the honest sign.
   - `:24` "Random Forest" capitalised; lower case everywhere else.

4. **Section 6 debris** (`confound.tex`).
   - `:13-17` "a 1:4.7:22.6 spread -- exactly the same as non-linear model of
     Section 5": missing "the"; `--` where the paper uses `---`; the
     commented-out line between them should go.
   - `:37-40` "The mechanism is the monotone relabelling, not equality of
     variance contributions…" now largely repeats the new bridge at `:19-21`
     ("the same response vector, and each feature in the same order"). Trim
     to the one sentence the bridge doesn't say: equal variance is a
     by-product, and the argument doesn't use it.
   - `:86` "The first four are pinned by the proposition" — the Proposition
     now covers MDI and AIR exactly and the others approximately; "The first
     four follow from the proposition, in descending strictness" is what the
     paragraph then explains.
   - The implications paragraph (`:143-160`) is 18 lines against 6–8 for the
     other three; the ALE/TreeSHAP material is the bulk. It is correct as
     written (the TreeSHAP scoping was checked this session), but it is the
     one place a practitioner will skim, and the two sentences on
     path-dependent TreeSHAP could be a footnote.

5. **The one new confirmed paper illustrates a limitation the paper already
   states.** W4280581368's adjudication reason argues the ranking is suspect
   because "sex and fixation are binary/categorical while age, gap, and
   callus are continuous" — the *type* bias, which this paper deliberately
   excludes from its experiments. The three confirmation conditions (uses
   impurity, ranking central, uncorroborated) are met regardless, and the
   Limitations paragraph already says flags are about corroboration practice,
   not mechanism. No text change needed, but if a referee samples the
   confirmed set they will find reasons of this kind; the sentence at
   `prevalence.tex:128-130` is the right defence and could be a touch more
   explicit that the *mechanism* by which a ranking might be wrong is not
   adjudicated.

6. **Repo hygiene.**
   - `analysis/candidates.csv` (125 rows) and `analysis/confirmed_candidates.csv`
     (55 rows) are from 2026-07-03, have no generating script, and now
     disagree with the records (129 / 56). Since Section 7 points readers at
     "the per-paper structured records and verdicts", either regenerate them
     from `tally.py` (a `--csv` flag) or delete them.
   - `results.md`: the update note at the top is correct; the sections below
     it still carry 544-era numbers and say so. Fine as a log, but a reader
     landing mid-file will see "125 flagged" without the caveat.
   - `\date{July 2026}` on the title page; the screen was extended in
     September and the method paragraph now says so.
   - Availability section could name `tally.py` as the one-line reproduction
     for Section 7, parallel to the claim it already makes for Sections 2–6.

## Narrative

The paper reads better than it did at `21f5ae9`. Removing the guidance
section was the right call: each experimental section now ends by telling a
practitioner what to do about what they just saw, the advice is adjacent to
its evidence, and nothing in the paper recommends something the paper hasn't
measured. The four implications paragraphs are uneven in length (6, 7, 6, 18
lines) but consistent in voice.

Section 7 is simpler and more defensible: "all 773 full texts were screened"
is a sentence a referee cannot argue with, where "544 = 524 + 20 from earlier
passes" invited questions the answers to which did not matter. The one-in-six
headline survived the extension unchanged, which is itself a small robustness
result worth a clause somewhere — the confirmed rate among the 249
filter-rejected papers (1 of 249) is far below the rate among matches, as the
filter's design predicts, and saying so would pre-empt "did screening the rest
change anything?"

Two structural notes. First, Section 4 (the split-criterion mechanism) sits
after Sections 2 and 3, which already used its conclusions; its opening
"underlie the effects in the sections that follow" is now literally true for
5 and 6 only. That is a defensible ordering — the mechanism arrives just
before the two sections that need it most — but a half-sentence
acknowledging that Sections 2 and 3 were consequences of the same properties
would tie the front half to it. Second, Sections 3 and 6 both now end with an
implications paragraph followed (Section 3) or preceded (Section 6) by the
figure; putting the figure before the implications in both would make the
paragraph the last thing read in each section, which is where it belongs.

Finding 1 is the only item a referee is likely to raise unprompted; the rest
is polish.
