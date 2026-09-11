export const meta = {
  name: 'impurity-extraction-complement',
  description: 'Screen the 229 full-text ranger-citing papers the relevance filter rejects (Haiku 4.5, same prompt and schema as the broad pass)',
  phases: [{ title: 'Extract', detail: 'one Haiku agent per paper, then a write step' }],
}
const REPO = '/path/to/rf-impurity'  // absolute path of this repository on the machine running the workflow
const ITEMS = args  // analysis/complement_items.json (229 filter-rejected full texts)
log(`extracting ${ITEMS.length} filter-rejected full-text papers`)
const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    uses_impurity_importance: { type: 'boolean' },
    pvalue_method: { type: 'string', enum: ['none','altmann','janitza','boruta','other'] },
    interprets_magnitude_or_ranking: { type: 'boolean' },
    corroboration: { type: 'array', items: { type: 'string', enum: ['permutation','shap','pdp_ale','conditional','heldout_validation','none'] } },
    feature_heterogeneity: { type: 'array', items: { type: 'string', enum: ['mixed_types','high_cardinality','skewed','scale_mismatch','unclear'] } },
    p_affected: { type: 'boolean', description: 'Could impurity-importance bias have altered a substantive conclusion? A significant importance p-value tests only that a variable is USED (robust); the bias hits MAGNITUDE and RANKING. True only if the paper leans on magnitude/ranking without adequate corroboration.' },
    central_to_conclusions: { type: 'boolean' },
    evidence: { type: 'string', description: '2-4 sentences quoting the passages supporting the judgement.' },
  },
  required: ['uses_impurity_importance','pvalue_method','interprets_magnitude_or_ranking','corroboration','feature_heterogeneity','p_affected','central_to_conclusions','evidence'],
}
const results = await pipeline(ITEMS, async (f) => {
  const id = f.replace(/\.txt$/, '')
  const rec = await agent(
    `You are screening a scientific paper for a methods audit about random-forest impurity (Gini/MDI/variance) variable-importance bias.\n\n` +
    `Read the full text at ${REPO}/corpus/fulltext/${f} and fill the structured record.\n\n` +
    `The bias (validated findings): impurity importance magnifies effect sizes super-linearly and cannot distinguish a genuinely non-linear effect from a linear effect on a skewed feature; it attributes interaction effects to the interacting variables. ranger importance p-values (Altmann/Janitza) and Boruta test whether importance != 0 (variable is USED) - that is robust. The bias corrupts MAGNITUDE and RANKING, not the zero/non-zero call.\n\n` +
    `Set p_affected=true only when conclusions lean on the magnitude or ranking of impurity importance (e.g. "X is the most important driver", biomarker selection by rank) WITHOUT adequate corroboration (permutation importance, SHAP, PDP/ALE, conditional importance, or held-out predictive validation). If it only uses importance for a robust yes/no call, or corroborates ranking with other methods, set p_affected=false. If the paper does not use impurity importance, set uses_impurity_importance=false and p_affected=false. Ground every judgement in the text.`,
    { label: `extract:${id}`, phase: 'Extract', schema: SCHEMA, model: 'haiku', effort: 'low' }
  )
  if (!rec) return null
  const out = { id, set: 'complement', ...rec }
  await agent(
    `Write this exact JSON to ${REPO}/analysis/extraction/${id}.json (create/overwrite), then reply only "ok":\n\n${JSON.stringify(out, null, 2)}`,
    { label: `write:${id}`, phase: 'Extract', model: 'haiku', effort: 'low' }
  )
  return out
})
const recs = results.filter(Boolean)
const flagged = recs.filter(r => r.p_affected && r.central_to_conclusions)
const uses = recs.filter(r => r.uses_impurity_importance)
log(`done: ${recs.length}/${ITEMS.length} records; ${uses.length} use impurity importance; ${flagged.length} flagged`)
return { records: recs.length, missing: ITEMS.length - recs.length, uses_impurity: uses.length, flagged: flagged.map(r => r.id) }