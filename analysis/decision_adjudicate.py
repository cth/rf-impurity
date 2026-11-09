#!/usr/bin/env python3
"""Adjudicate stage-1 flags with an OpenRouter decision model.

For every paper flagged in analysis/extraction/*.json (p_affected &&
central_to_conclusions), ask a decision model to re-evaluate the three
conditions an adversarial adjudicator checks, plus a confirmed/refuted/uncertain
verdict. Writes one JSON per paper to --out.

Usage:
  OPENROUTER_API_KEY=... python3 analysis/decision_adjudicate.py
  python3 analysis/decision_adjudicate.py --dry-run
"""
import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

API_URL = "https://openrouter.ai/api/alpha/decisions"
MODELS_URL = "https://openrouter.ai/api/v1/models"

PRICE_PER_M = {
    "typesafe/jev-1.14": 0.042,
    "typesafe/jev-1.13": 0.042,
    "~typesafe/jev-latest": 0.042,
    "perplexity/pplx-decider-v1.2": 0.019,
    "perplexity/pplx-decider-flash-v1.2": 0.010,
    "inception/mercury-decide": 0.020,
    "microsoft/microsoft-decision-1": 0.042,
}

QUESTIONS = {
    "uses_impurity": {
        "type": "noul",
        "instructions": (
            "Does the paper genuinely use an impurity-based (Gini/MDI/variance) "
            "random-forest importance, and not solely permutation importance or SHAP?"
        ),
        "criteria": {
            "true": "An impurity/Gini/MDI/variance importance is computed or interpreted.",
            "false": "Only permutation importance, SHAP, or non-impurity measures are used.",
        },
    },
    "ranking_central": {
        "type": "noul",
        "instructions": (
            "Is the magnitude or ranking of that impurity importance central to a "
            "stated conclusion of the paper?"
        ),
        "criteria": {
            "true": "A conclusion depends on which features rank highest or on their relative magnitudes.",
            "false": "Importance is incidental, descriptive, or not tied to a conclusion.",
        },
    },
    "uncorroborated": {
        "type": "noul",
        "instructions": (
            "Is that ranking inadequately corroborated (no permutation importance, "
            "SHAP, PDP/ALE, conditional importance, or held-out validation of selected features)?"
        ),
        "criteria": {
            "true": "No adequate corroboration of the ranking is reported.",
            "false": "Adequate corroboration of the ranking is reported.",
        },
    },
    "verdict": {
        "type": "choice",
        "instructions": "Should the stage-1 flag be confirmed, refuted, or left uncertain?",
        "criteria": {
            "confirmed": "All three conditions hold: impurity importance, central ranking, inadequate corroboration.",
            "refuted": "At least one condition fails.",
            "uncertain": "The text does not settle whether the conditions hold.",
        },
    },
}


def price_for(model):
    if model in PRICE_PER_M:
        return PRICE_PER_M[model]
    try:
        with urllib.request.urlopen(MODELS_URL, timeout=30) as r:
            data = json.load(r).get("data", [])
        for m in data:
            if m.get("id") == model:
                p = m.get("pricing", {}).get("prompt")
                if p is not None:
                    return float(p) * 1e6
    except Exception:
        pass
    return 0.042


def read_text(path, max_chars):
    with open(path, encoding="utf-8", errors="ignore") as f:
        return f.read(max_chars)


def flagged_papers(extraction_dir):
    out = []
    for f in sorted(os.listdir(extraction_dir)):
        if not f.endswith(".json"):
            continue
        rec = json.load(open(os.path.join(extraction_dir, f)))
        if rec.get("p_affected") and rec.get("central_to_conclusions"):
            out.append((f[:-5], rec))
    return out


def call_model(model, state, api_key, timeout, retries):
    payload = {"model": model, "state": state, "questions": QUESTIONS}
    body = json.dumps(payload).encode()
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    last = None
    for attempt in range(retries):
        req = urllib.request.Request(API_URL, data=body, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            last = e
            if e.code in (429, 500, 502, 503, 504) and attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise
        except Exception as e:
            last = e
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise
    raise last


def adjudicate_one(item, corpus_dir, out_dir, model, max_chars, api_key, timeout, retries):
    pid, stage1 = item
    out_path = os.path.join(out_dir, pid + ".json")
    if os.path.exists(out_path):
        try:
            rec = json.load(open(out_path))
            if "verdict" in rec:
                return rec, "skipped"
        except Exception:
            pass

    path = os.path.join(corpus_dir, pid + ".txt")
    text = read_text(path, max_chars)
    state = {"paper_text": text, "stage1_record": stage1}
    resp = call_model(model, state, api_key, timeout, retries)
    answers = resp.get("answers", {})
    uses = answers.get("uses_impurity", {}).get("noul")
    central = answers.get("ranking_central", {}).get("noul")
    uncorr = answers.get("uncorroborated", {}).get("noul")
    verdict_ans = answers.get("verdict", {})
    verdict = verdict_ans.get("choice")
    prob_map = verdict_ans.get("probabilities", {})

    derived = None
    if uses is not None and central is not None and uncorr is not None:
        if uses >= 0.5 and central >= 0.5 and uncorr >= 0.5:
            derived = "confirmed"
        elif uses < 0.5 or central < 0.5 or uncorr < 0.5:
            derived = "refuted"
        else:
            derived = "uncertain"

    rec = {
        "id": pid,
        "input_path": os.path.abspath(path),
        "input_sha256": hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest(),
        "input_chars": len(text),
        "max_chars": max_chars,
        "model_requested": model,
        "model": resp.get("model", model),
        "uses_impurity_prob": uses,
        "ranking_central_prob": central,
        "uncorroborated_prob": uncorr,
        "conditions_met": bool(uses is not None and central is not None and uncorr is not None and uses >= 0.5 and central >= 0.5 and uncorr >= 0.5),
        "verdict_choice": verdict,
        "verdict_probabilities": prob_map,
        "verdict_confidence": verdict_ans.get("confidence"),
        "derived_verdict": derived,
        "threshold": 0.5,
        "answer": answers,
        "stage1_record": stage1,
        "usage": resp.get("usage", {}),
        "raw_response": resp,
        "adjudicated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(rec, f, indent=2)
    return rec, "done"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--extraction", default="analysis/extraction")
    ap.add_argument("--corpus", default="corpus/fulltext")
    ap.add_argument("--out", default="analysis/decision_adjudication")
    ap.add_argument("--model", default="typesafe/jev-1.14")
    ap.add_argument("--max-chars", type=int, default=250000)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--retries", type=int, default=5)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    items = flagged_papers(args.extraction)
    if args.limit:
        items = items[: args.limit]

    price = price_for(args.model)
    total_chars = sum(min(os.path.getsize(os.path.join(args.corpus, pid + ".txt")), args.max_chars) for pid, _ in items)
    toks = total_chars / 4.0
    cost = toks / 1e6 * price
    print(f"flagged papers: {len(items)}")
    print(f"model:          {args.model}")
    print(f"price:          ${price:.4f} per 1M input tokens")
    print(f"chars sent:     {total_chars:,}  (~{toks:,.0f} tokens)")
    print(f"est. cost:      ${cost:.4f}")

    if args.dry_run:
        return

    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        print("ERROR: set OPENROUTER_API_KEY", file=sys.stderr)
        sys.exit(1)

    model_slug = args.model.replace("/", "_").replace("~", "")
    out_dir = os.path.join(args.out, model_slug)
    os.makedirs(out_dir, exist_ok=True)
    print(f"output dir:     {out_dir}")

    done = skipped = failed = 0
    total_cost = 0.0
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {
            ex.submit(adjudicate_one, item, args.corpus, out_dir, args.model, args.max_chars, api_key, args.timeout, args.retries): item
            for item in items
        }
        for fut in as_completed(futs):
            item = futs[fut]
            try:
                rec, status = fut.result()
                if status == "skipped":
                    skipped += 1
                else:
                    done += 1
                c = rec.get("usage", {}).get("cost")
                if c is not None:
                    total_cost += float(c)
                print(f"{item[0]}: {rec['derived_verdict']} / {rec['verdict_choice']}  ({status})")
            except Exception as e:
                failed += 1
                print(f"{item[0]}: ERROR {e}", file=sys.stderr)

    print(f"\ndone={done} skipped={skipped} failed={failed}")
    print(f"reported cost: ${total_cost:.4f}")


if __name__ == "__main__":
    main()
