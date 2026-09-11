export const meta = {
  name: 'impurity-adjudication-complement',
  description: 'Adversarially verify the 4 newly flagged filter-rejected papers (Sonnet 5, same prompt and schema as the July adjudication)',
  phases: [{ title: 'Adjudicate', detail: 'one Sonnet agent per flagged paper, prompted to refute' }],
}
const REPO = '/path/to/rf-impurity'  // absolute path of this repository on the machine running the workflow
const ITEMS = args  // analysis/complement_adjudication_input.json
log(`adjudicating ${ITEMS.length} flagged papers (highest-cited first)`)
const SCHEMA = {
  type:'object', additionalProperties:false,
  properties:{
    verdict:{type:'string', enum:['confirmed','refuted','uncertain'], description:'confirmed = the impurity-importance bias could genuinely have altered a central conclusion and it is not adequately corroborated; refuted = the flag is wrong (does not use impurity importance for its conclusions, OR ranking is adequately corroborated, OR importance is not central); uncertain = cannot tell from the text.'},
    uses_impurity_importance:{type:'boolean'},
    ranking_central:{type:'boolean', description:'Is the magnitude/ranking of impurity importance central to a conclusion?'},
    adequate_corroboration:{type:'boolean', description:'Does the paper corroborate the ranking with permutation importance, SHAP, PDP/ALE, conditional importance, or held-out predictive validation of the SELECTION (not just overall model accuracy)?'},
    reason:{type:'string', description:'2-4 sentences. You were asked to REFUTE; state what you found and why the verdict follows, citing the text.'},
  },
  required:['verdict','uses_impurity_importance','ranking_central','adequate_corroboration','reason'],
}
const results = await pipeline(ITEMS, async (it) => {
  const v = await agent(
    `You are an ADVERSARIAL verifier in a methods audit. A first-pass screen FLAGGED this paper as one whose conclusions could be affected by random-forest impurity (Gini/MDI/variance) importance bias. Your job is to try to REFUTE that flag by reading the actual paper.\n\n` +
    `Paper full text: ${REPO}/corpus/fulltext/${it.id}.txt\n` +
    `First-pass evidence for the flag: ${JSON.stringify(it.evidence)}\n` +
    `First-pass pvalue_method=${it.pvalue_method}, corroboration=${JSON.stringify(it.corroboration)}\n\n` +
    `The bias only corrupts the MAGNITUDE and RANKING of impurity importance (super-linear magnification; cannot separate a non-linear effect from a skewed feature; charges interactions to the interacting variables). It does NOT corrupt a significance verdict (importance != 0), which is robust.\n\n` +
    `A flag is CONFIRMED only if ALL hold: (1) the paper genuinely uses impurity/Gini/MDI importance (not only permutation/SHAP), (2) the magnitude or ranking of that importance is central to a stated conclusion, and (3) the ranking is NOT adequately corroborated. Adequate corroboration = permutation importance, SHAP, PDP/ALE shape, conditional importance, or held-out predictive validation of the SELECTED feature set (note: overall model accuracy/AUC on a test set does NOT validate the ranking). If any of the three fails, REFUTE. If the paper text is insufficient to tell, answer uncertain.\n\n` +
    `Read the paper and reach your own verdict; do not defer to the first-pass screen.`,
    { label:`adj:${it.id}(${it.cites}c)`, phase:'Adjudicate', schema:SCHEMA, model:'sonnet', effort:'high' }
  )
  if(!v) return null
  const out={ id:it.id, cites:it.cites, ...v }
  await agent(`Write this exact JSON to ${REPO}/analysis/adjudication/${it.id}.json (overwrite), then reply "ok":\n\n${JSON.stringify(out,null,2)}`,
    { label:`w:${it.id}`, phase:'Adjudicate', model:'haiku', effort:'low' })
  return out
})
const r=results.filter(Boolean)
const conf=r.filter(x=>x.verdict==='confirmed'), ref=r.filter(x=>x.verdict==='refuted'), unc=r.filter(x=>x.verdict==='uncertain')
log(`done: ${r.length} adjudicated - confirmed ${conf.length}, refuted ${ref.length}, uncertain ${unc.length}`)
return { adjudicated:r.length, confirmed:conf.map(x=>x.id), refuted:ref.map(x=>x.id), uncertain:unc.map(x=>x.id) }