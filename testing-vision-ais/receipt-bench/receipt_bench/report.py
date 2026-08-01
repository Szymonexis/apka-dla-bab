"""Assemble the JSON report (at the requested detail level) and a companion
Markdown comparison table."""

from __future__ import annotations

from .aggregate import model_report, summarize
from .evaluate import ReceiptEval

LEVELS = ("summary", "diagnostic", "full")


def _fmt_money(minor: int | None) -> str:
    if minor is None:
        return "-"
    return f"{minor / 100:.2f}"


def _per_receipt(ev: ReceiptEval) -> dict:
    entry: dict = {
        "id": ev.id,
        "style": ev.style,
        "store_kind": ev.store_kind,
        "item_count": ev.item_count,
        "ok": ev.ok,
        "category": ev.category,
        "issues": ev.issues,
        "latency_ms": round(ev.latency_ms),
        "eval_tokens": ev.eval_tokens,
    }
    if ev.error:
        entry["error"] = ev.error[:500]
    if not ev.ok:
        entry["raw"] = ev.raw[:1000]
        return entry

    entry["total"] = {
        "gt": ev.total_gt,
        "pred": ev.total_pred,
        "exact": ev.total_exact,
        "abs_err": ev.total_abs_err,
    }
    entry["currency"] = {
        "gt": ev.currency_gt,
        "pred": ev.currency_pred,
        "ok": ev.currency_correct,
    }

    m = ev.match
    diffs = []
    if m:
        for pair in m.pairs:
            gt_name, gt_val = ev.gt_products[pair.gt_index]
            pr_name, pr_val = ev.pred_products[pair.pred_index]
            diffs.append({
                "gt": gt_name, "pred": pr_name,
                "name_sim": pair.name_sim,
                "gt_value": gt_val, "pred_value": pr_val,
                "price_ok": pair.price_exact,
            })
        for gi in m.unmatched_gt:
            name, val = ev.gt_products[gi]
            diffs.append({"gt": name, "pred": None, "gt_value": val, "missed": True})
        for pi in m.unmatched_pred:
            name, val = ev.pred_products[pi]
            diffs.append({"gt": None, "pred": name, "pred_value": val, "extra": True})
        entry["products"] = {
            "gt": m.gt_count,
            "pred": m.pred_count,
            "matched": m.matched,
            "f1": round(m.f1, 3),
            "name_price_f1": round(m.name_price_f1, 3),
            "price_exact_rate": round(m.price_exact_rate, 3),
            "diffs": diffs,
        }
    return entry


def build_report(level: str, meta: dict, results: dict[str, list[ReceiptEval]]) -> dict:
    """``results`` maps model name -> its per-receipt evaluations."""
    if level == "summary":
        scoreboard = []
        for model, evals in results.items():
            row = {"model": model}
            row.update(summarize(evals, compact=True))
            scoreboard.append(row)
        # rank by name_price_f1 then total_exact_rate, best first
        scoreboard.sort(
            key=lambda r: (r.get("name_price_f1") or 0, r.get("total_exact_rate") or 0),
            reverse=True,
        )
        return {"meta": meta, "scoreboard": scoreboard}

    report = {"meta": meta, "models": {m: model_report(e) for m, e in results.items()}}
    if level == "full":
        report["per_receipt"] = {
            m: [_per_receipt(e) for e in evals] for m, evals in results.items()
        }
    return report


# --- Markdown -------------------------------------------------------------

def _pct(x) -> str:
    return f"{x * 100:.1f}%" if isinstance(x, (int, float)) else "-"


def _num(x, suffix="") -> str:
    return f"{x}{suffix}" if isinstance(x, (int, float)) else "-"


def build_markdown(meta: dict, results: dict[str, list[ReceiptEval]]) -> str:
    lines = ["# Receipt extraction benchmark", ""]
    lines.append(f"- receipts: **{meta.get('n')}**  ·  seed: {meta.get('seed')}  "
                 f"·  dataset: `{meta.get('dataset')}`")
    lines.append(f"- generated: {meta.get('timestamp', '-')}  ·  ollama: `{meta.get('ollama_url')}`")
    lines.append("")

    header = ("| model | valid JSON | total exact | total MAE (gr) | "
              "product F1 | name+price F1 | currency | latency p50 |")
    sep = "|---|---|---|---|---|---|---|---|"
    lines += [header, sep]
    rows = []
    for model, evals in results.items():
        s = summarize(evals)
        rows.append((
            s.get("name_price_f1") or 0,
            f"| `{model}` | {_pct(s['schema_valid_rate'])} | {_pct(s['total_exact_rate'])} | "
            f"{_num(s['total_mae_grosze'])} | {_pct(s['product_f1'])} | "
            f"{_pct(s['name_price_f1'])} | {_pct(s['currency_acc'])} | "
            f"{_num(s['latency_ms']['p50'], ' ms')} |"
        ))
    for _, row in sorted(rows, key=lambda t: t[0], reverse=True):
        lines.append(row)

    lines.append("")
    lines.append("## Issues per model")
    lines.append("")
    from .aggregate import error_histogram
    for model, evals in results.items():
        hist = error_histogram(evals)
        detail = ", ".join(f"{k}: {v}" for k, v in hist.items()) or "none"
        lines.append(f"- `{model}` — {detail}")
    lines.append("")
    return "\n".join(lines)
