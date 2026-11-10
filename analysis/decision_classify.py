#!/usr/bin/env python3
"""Initial classification of ranger-citing papers with an OpenRouter decision model.

Replaces the regex relevance pre-filter (analysis/relevance_filter.py) with a
typed decision call: one noul question per paper, "does this paper use or
interpret a random-forest impurity (Gini/MDI/variance) variable importance?".
Writes one JSON record per paper to --out.

Usage:
  OPENROUTER_API_KEY=... python3 analysis/decision_classify.py corpus/fulltext
  python3 analysis/decision_classify.py corpus/fulltext --dry-run
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
    "typesafe/jev-router": 0.0,  # billed at routed model's rate
    "perplexity/pplx-decider-v1.2": 0.019,
    "perplexity/pplx-decider-flash-v1.2": 0.010,
    "perplexity/pplx-decider-v1.1-27b": 0.020,
    "inception/mercury-decide": 0.020,
    "microsoft/microsoft-decision-1": 0.042,
}

QUESTION = {
    "uses_impurity_importance": {
        "type": "noul",
        "instructions": (
            "Does this paper use or interpret a random-forest impurity-based "
            "(Gini, MDI, or mean decrease in impurity/variance) variable importance?"
        ),
        "criteria": {
            "true": (
                "The paper computes, reports, ranks, or draws a conclusion from an "
                "impurity-based (Gini/MDI/variance) variable importance produced by a "
                "random forest (e.g. ranger, randomForest)."
            ),
            "false": (
                "The paper uses only permutation importance, SHAP, prediction, speed, "
                "or cites ranger without interpreting an impurity importance."
            ),
        },
    }
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


def call_model(model, text, api_key, timeout, retries):
    payload = {
        "model": model,
        "state": {"paper_text": text},
        "questions": QUESTION,
    }
    body = json.dumps(payload).encode()
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
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
        except Exception as e:  # noqa: BLE001
            last = e
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise
    raise last


def classify_file(path, out_dir, model, threshold, max_chars, api_key, timeout, retries):
    stem = os.path.splitext(os.path.basename(path))[0]
    out_path = os.path.join(out_dir, stem + ".json")
    if os.path.exists(out_path):
        try:
            with open(out_path) as f:
                rec = json.load(f)
            if "probability" in rec:
                return rec, "skipped"
        except Exception:
            pass

    text = read_text(path, max_chars)
    text_sha256 = hashlib.sha256(text.encode("utf-8", errors="ignore")).hexdigest()
    resp = call_model(model, text, api_key, timeout, retries)
    answers = resp.get("answers", {})
    ans = answers.get("uses_impurity_importance", {})
    prob = ans.get("noul")
    if prob is None:
        raise RuntimeError(f"no noul answer for {stem}: {resp}")
    rec = {
        "id": stem,
        "input_path": os.path.abspath(path),
        "input_sha256": text_sha256,
        "input_chars": len(text),
        "max_chars": max_chars,
        "model_requested": model,
        "model": resp.get("model", model),
        "probability": prob,
        "relevant": bool(prob >= threshold),
        "threshold": threshold,
        "question": QUESTION,
        "answer": ans,
        "usage": resp.get("usage", {}),
        "raw_response": resp,
        "classified_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(rec, f, indent=2)
    return rec, "done"


def estimate(files, max_chars):
    total_chars = 0
    for p in files:
        total_chars += min(os.path.getsize(p), max_chars)
    return total_chars, total_chars / 4.0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input", nargs="?", default="corpus/fulltext")
    ap.add_argument("--out", default="analysis/decision_classification")
    ap.add_argument("--model", default="typesafe/jev-1.14")
    ap.add_argument("--threshold", type=float, default=0.5)
    ap.add_argument("--max-chars", type=int, default=250000)
    ap.add_argument("--workers", type=int, default=4)
    ap.add_argument("--retries", type=int, default=5)
    ap.add_argument("--timeout", type=int, default=120)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    files = sorted(
        os.path.join(args.input, f) for f in os.listdir(args.input) if f.endswith(".txt")
    )
    if args.limit:
        files = files[: args.limit]

    price = price_for(args.model)
    chars, toks = estimate(files, args.max_chars)
    cost = toks / 1e6 * price

    print(f"files:        {len(files)}")
    print(f"model:        {args.model}")
    print(f"price:        ${price:.4f} per 1M input tokens")
    print(f"chars sent:   {chars:,}  (~{toks:,.0f} tokens at 4 chars/token)")
    print(f"est. cost:    ${cost:.4f}  (output tokens are free)")
    print(f"threshold:    {args.threshold}")
    print(f"output dir:   {os.path.join(args.out, args.model.replace("/", "_").replace("~", ""))}")

    if args.dry_run:
        return

    api_key = os.environ.get("OPENROUTER_API_KEY")
    if not api_key:
        print("ERROR: set OPENROUTER_API_KEY", file=sys.stderr)
        sys.exit(1)

    model_slug = args.model.replace("/", "_").replace("~", "")
    out_dir = os.path.join(args.out, model_slug)
    os.makedirs(out_dir, exist_ok=True)
    done = skipped = failed = 0
    total_cost = 0.0
    with ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {
            ex.submit(
                classify_file,
                p,
                out_dir,
                args.model,
                args.threshold,
                args.max_chars,
                api_key,
                args.timeout,
                args.retries,
            ): p
            for p in files
        }
        for fut in as_completed(futs):
            p = futs[fut]
            try:
                rec, status = fut.result()
                if status == "skipped":
                    skipped += 1
                else:
                    done += 1
                c = rec.get("usage", {}).get("cost")
                if c is not None:
                    total_cost += float(c)
                print(f"{os.path.basename(p)}: {rec['probability']:.3f} -> {rec['relevant']}  ({status})")
            except Exception as e:  # noqa: BLE001
                failed += 1
                print(f"{os.path.basename(p)}: ERROR {e}", file=sys.stderr)

    print(f"\ndone={done} skipped={skipped} failed={failed}")
    print(f"reported cost (sum of usage.cost): ${total_cost:.4f}")


if __name__ == "__main__":
    main()
