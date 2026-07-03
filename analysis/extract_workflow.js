export const meta = {
  name: 'impurity-extraction',
  description: 'Read each ranger-citing paper and emit a structured impurity-importance risk record',
  phases: [{ title: 'Extract', detail: 'one Haiku agent per paper (158 survivors + 40 rejected-sample)' }],
}

const REPO = '/Users/christian.theilhave/code/synlang/rf-impurity'
const SURVIVORS = ["W2322754609.txt", "W2739273059.txt", "W2793997912.txt", "W2802643674.txt", "W2883457117.txt", "W2914279003.txt", "W2918306332.txt", "W2958774005.txt", "W2966489974.txt", "W2989793717.txt", "W3009545736.txt", "W3014033160.txt", "W3014109009.txt", "W3025125480.txt", "W3026957706.txt", "W3043210715.txt", "W3047740330.txt", "W3082926880.txt", "W3083382724.txt", "W3088997255.txt", "W3091827704.txt", "W3097448714.txt", "W3103885152.txt", "W3108883807.txt", "W3113122576.txt", "W3116189655.txt", "W3120988391.txt", "W3121662364.txt", "W3125721538.txt", "W3128152036.txt", "W3132721801.txt", "W3149782091.txt", "W3153034381.txt", "W3153405385.txt", "W3158585041.txt", "W3187073625.txt", "W3191008658.txt", "W3199405447.txt", "W3199509358.txt", "W3201785827.txt", "W3203874096.txt", "W3205971043.txt", "W3208089818.txt", "W3210202946.txt", "W3214635477.txt", "W3215058137.txt", "W4200535100.txt", "W4206057987.txt", "W4207046920.txt", "W4213450065.txt", "W4220673804.txt", "W4220935369.txt", "W4220970849.txt", "W4229375002.txt", "W4280496883.txt", "W4281393173.txt", "W4286247879.txt", "W4287831920.txt", "W4293047538.txt", "W4295086769.txt", "W4298144862.txt", "W4303423517.txt", "W4306673010.txt", "W4307429571.txt", "W4307650037.txt", "W4307846060.txt", "W4311438776.txt", "W4316878004.txt", "W4319592475.txt", "W4319756428.txt", "W4320494281.txt", "W4322616741.txt", "W4322763755.txt", "W4366603156.txt", "W4372330336.txt", "W4378904535.txt", "W4381051893.txt", "W4381190638.txt", "W4383724226.txt", "W4385330274.txt", "W4385406568.txt", "W4386318974.txt", "W4386945271.txt", "W4387617425.txt", "W4387949151.txt", "W4387949524.txt", "W4388570374.txt", "W4388575241.txt", "W4389274765.txt", "W4390540183.txt", "W4391092002.txt", "W4391353343.txt", "W4392639248.txt", "W4392714236.txt", "W4392966874.txt", "W4392969600.txt", "W4393112007.txt", "W4394722945.txt", "W4394855567.txt", "W4401729402.txt", "W4401944407.txt", "W4402094791.txt", "W4402411761.txt", "W4402761110.txt", "W4402900565.txt", "W4403893120.txt", "W4403917195.txt", "W4404462056.txt", "W4404489259.txt", "W4405200646.txt", "W4405237241.txt", "W4405543717.txt", "W4407053155.txt", "W4407633893.txt", "W4407763554.txt", "W4407848841.txt", "W4408188986.txt", "W4408660685.txt", "W4408669857.txt", "W4408889621.txt", "W4408948506.txt", "W4409032064.txt", "W4410052144.txt", "W4410479945.txt", "W4410521450.txt", "W4410756376.txt", "W4412136488.txt", "W4412155196.txt", "W4412363123.txt", "W4412720711.txt", "W4412896032.txt", "W4413304431.txt", "W4413489220.txt", "W4413686298.txt", "W4413759482.txt", "W4414242061.txt", "W4414578748.txt", "W4415340058.txt", "W4415431445.txt", "W4415700826.txt", "W4415724536.txt", "W4416839624.txt", "W4417151077.txt", "W4417238925.txt", "W4417409064.txt", "W4417420068.txt", "W7118262481.txt", "W7123354029.txt", "W7124919802.txt", "W7125958004.txt", "W7126431102.txt", "W7130659195.txt", "W7134238250.txt", "W7152653561.txt", "W7160133852.txt", "W7160558155.txt", "W7163581993.txt", "W7163917253.txt"]
const REJECTED = ["W2768211711.txt", "W2969695615.txt", "W2971921228.txt", "W2982481728.txt", "W2997528843.txt", "W3022771385.txt", "W3126801790.txt", "W3133381154.txt", "W3135732190.txt", "W3144751945.txt", "W3155024268.txt", "W3168330745.txt", "W3207346302.txt", "W4200529794.txt", "W4206200000.txt", "W4280621189.txt", "W4283834257.txt", "W4285729222.txt", "W4289224932.txt", "W4290851618.txt", "W4295009516.txt", "W4309173360.txt", "W4317939381.txt", "W4321851539.txt", "W4323362142.txt", "W4389886321.txt", "W4390875684.txt", "W4391052472.txt", "W4393053121.txt", "W4400007872.txt", "W4404506475.txt", "W4404738023.txt", "W4408062710.txt", "W4408957844.txt", "W4413109329.txt", "W4416214717.txt", "W4417272098.txt", "W7129410120.txt", "W7161151485.txt", "W7161252680.txt"]
const items = [
  ...SURVIVORS.map(f => ({ f, set: 'survivor' })),
  ...REJECTED.map(f => ({ f, set: 'rejected_sample' })),
]
log(`extracting ${items.length} papers (${SURVIVORS.length} survivors + ${REJECTED.length} rejected-sample)`)

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    uses_impurity_importance: { type: 'boolean', description: 'Paper reports impurity/Gini/MDI/AIR variable importance from a random forest or tree ensemble' },
    pvalue_method: { type: 'string', enum: ['none', 'altmann', 'janitza', 'boruta', 'other'], description: 'Method used to attach a significance verdict to importance' },
    interprets_magnitude_or_ranking: { type: 'boolean', description: 'Paper ranks features, selects biomarkers/drivers/predictors, or makes relative-magnitude claims based on importance' },
    corroboration: { type: 'array', items: { type: 'string', enum: ['permutation', 'shap', 'pdp_ale', 'conditional', 'heldout_validation', 'none'] }, description: 'Cross-checks present that would mitigate impurity bias' },
    feature_heterogeneity: { type: 'array', items: { type: 'string', enum: ['mixed_types', 'high_cardinality', 'skewed', 'scale_mismatch', 'unclear'] }, description: 'Amplifying conditions for the bias' },
    p_affected: { type: 'boolean', description: 'Could the impurity-importance biases have altered a substantive conclusion of THIS paper? A significant importance p-value tests only that a variable is USED (robust); the bias hits MAGNITUDE and RANKING. True only if the paper leans on magnitude/ranking without adequate corroboration.' },
    central_to_conclusions: { type: 'boolean', description: 'Is the importance ranking/magnitude central to the paper conclusions (vs a minor aside)?' },
    evidence: { type: 'string', description: '2-4 sentences quoting/paraphrasing the passages supporting p_affected and central_to_conclusions.' },
  },
  required: ['uses_impurity_importance', 'pvalue_method', 'interprets_magnitude_or_ranking', 'corroboration', 'feature_heterogeneity', 'p_affected', 'central_to_conclusions', 'evidence'],
}

const results = await pipeline(
  items,
  async (item) => {
    const id = item.f.replace(/\.txt$/, '')
    const rec = await agent(
      `You are screening a scientific paper for a methods audit about random-forest impurity (Gini/MDI/variance) variable-importance bias.\n\n` +
      `Read the full text at ${REPO}/corpus/fulltext/${item.f} and fill the structured record.\n\n` +
      `The bias you are screening for (validated findings):\n` +
      `- Impurity importance magnifies effect sizes super-linearly and cannot distinguish a genuinely non-linear effect from a linear effect on a skewed/heavy-tailed feature.\n` +
      `- It attributes interaction effects to the interacting variables even when they have no marginal effect.\n` +
      `- ranger importance p-values (Altmann/Janitza) and Boruta test whether importance != 0 (variable is USED) - that verdict is robust. The bias corrupts MAGNITUDE and RANKING, not the zero/non-zero call.\n\n` +
      `Set p_affected=true only when the paper conclusions lean on the magnitude or ranking of impurity importance (e.g. "X is the most important driver", biomarker selection by rank) WITHOUT adequate corroboration (permutation importance, SHAP, PDP/ALE, conditional importance, or held-out predictive validation). If it only uses importance for a robust yes/no call, or corroborates ranking with other methods, set p_affected=false.\n\n` +
      `If the paper does not actually use impurity importance, set uses_impurity_importance=false and p_affected=false.\n\n` +
      `Ground every judgement in the text; put supporting passages in evidence.`,
      { label: `extract:${id}`, phase: 'Extract', schema: SCHEMA, model: 'haiku', effort: 'low' }
    )
    if (!rec) return null
    const out = { id, set: item.set, ...rec }
    await agent(
      `Write this exact JSON to ${REPO}/analysis/extraction/${id}.json (create/overwrite), then reply only "ok":\n\n${JSON.stringify(out, null, 2)}`,
      { label: `write:${id}`, phase: 'Extract', model: 'haiku', effort: 'low' }
    )
    return out
  }
)

const recs = results.filter(Boolean)
const survivors = recs.filter(r => r.set === 'survivor')
const rejected = recs.filter(r => r.set === 'rejected_sample')
const flagged = survivors.filter(r => r.p_affected && r.central_to_conclusions)
const fn = rejected.filter(r => r.p_affected && r.central_to_conclusions)
log(`done: ${recs.length} records; ${flagged.length} flagged among survivors; ${fn.length} missed positives in rejected sample`)
return { total: recs.length, survivors: survivors.length, rejected_sample: rejected.length, flagged_survivors: flagged.length, false_negatives_in_sample: fn.length }
