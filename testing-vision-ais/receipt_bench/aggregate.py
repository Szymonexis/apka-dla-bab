"""Roll per-receipt evaluations up into per-model summaries and breakdowns."""

from __future__ import annotations

from collections import Counter
from typing import Callable

from .evaluate import ReceiptEval


def _mean(xs: list[float]) -> float | None:
    return sum(xs) / len(xs) if xs else None


def _percentile(xs: list[float], p: float) -> float | None:
    if not xs:
        return None
    s = sorted(xs)
    if len(s) == 1:
        return s[0]
    k = (len(s) - 1) * (p / 100.0)
    lo = int(k)
    hi = min(lo + 1, len(s) - 1)
    return s[lo] + (s[hi] - s[lo]) * (k - lo)


def _r(x: float | None, n: int = 3) -> float | None:
    return round(x, n) if x is not None else None


def item_bucket(count: int) -> str:
    if count <= 1:
        return "1"
    if count <= 5:
        return "2-5"
    if count <= 10:
        return "6-10"
    if count <= 20:
        return "11-20"
    if count <= 30:
        return "21-30"
    return "31+"


def summarize(evals: list[ReceiptEval], compact: bool = False) -> dict:
    """Aggregate a list of evaluations for a single model (or a slice of one)."""
    n = len(evals)
    valid = [e for e in evals if e.ok]
    n_ok = len(valid)

    exact = [e for e in valid if e.total_exact]
    abs_errs = [e.total_abs_err for e in valid if e.total_abs_err is not None]

    # product micro totals across valid receipts
    sum_matched = sum(e.match.matched for e in valid if e.match)
    sum_matched_price = sum(e.match.matched_with_price for e in valid if e.match)
    sum_pred = sum(e.match.pred_count for e in valid if e.match)
    sum_gt = sum(e.match.gt_count for e in valid if e.match)

    micro_p = sum_matched / sum_pred if sum_pred else 0.0
    micro_r = sum_matched / sum_gt if sum_gt else 0.0
    micro_f1 = 2 * micro_p * micro_r / (micro_p + micro_r) if (micro_p + micro_r) else 0.0
    np_p = sum_matched_price / sum_pred if sum_pred else 0.0
    np_r = sum_matched_price / sum_gt if sum_gt else 0.0
    np_f1 = 2 * np_p * np_r / (np_p + np_r) if (np_p + np_r) else 0.0
    macro_f1 = _mean([e.match.f1 for e in valid if e.match])

    summary: dict = {
        "n": n,
        "schema_valid_rate": _r(n_ok / n) if n else None,
        "total_exact_rate": _r(len(exact) / n) if n else None,
        "total_mae_grosze": _r(_mean(abs_errs), 1),
        "currency_acc": _r(sum(e.currency_correct for e in valid) / n_ok) if n_ok else None,
        "product_f1": _r(micro_f1),
        "name_price_f1": _r(np_f1),
    }
    if compact:
        return summary

    summary.update({
        "n_valid": n_ok,
        "total_exact_rate_of_valid": _r(len(exact) / n_ok) if n_ok else None,
        "total_p50_err_grosze": _r(_percentile(abs_errs, 50), 1),
        "total_p95_err_grosze": _r(_percentile(abs_errs, 95), 1),
        "product_precision": _r(micro_p),
        "product_recall": _r(micro_r),
        "product_macro_f1": _r(macro_f1),
        "price_exact_rate": _r(sum_matched_price / sum_matched) if sum_matched else None,
        "mean_pred_minus_gt_items": _r(
            _mean([e.pred_product_count - e.item_count for e in valid]), 2),
        "latency_ms": {
            "p50": _r(_percentile([e.latency_ms for e in evals], 50), 0),
            "p95": _r(_percentile([e.latency_ms for e in evals], 95), 0),
            "mean": _r(_mean([e.latency_ms for e in evals]), 0),
        },
        "tokens_per_sec_mean": _r(
            _mean([e.tokens_per_sec for e in valid if e.tokens_per_sec]), 1),
        "categories": dict(Counter(e.category for e in evals)),
    })
    return summary


def error_histogram(evals: list[ReceiptEval]) -> dict:
    """Count receipts affected by each issue tag."""
    counter: Counter = Counter()
    for e in evals:
        for issue in e.issues:
            counter[issue] += 1
    return dict(counter.most_common())


def breakdown(evals: list[ReceiptEval], key: Callable[[ReceiptEval], str]) -> dict:
    groups: dict[str, list[ReceiptEval]] = {}
    for e in evals:
        groups.setdefault(key(e), []).append(e)
    return {k: summarize(v, compact=True) for k, v in sorted(groups.items())}


def model_report(evals: list[ReceiptEval]) -> dict:
    """Diagnostic-level report body for one model."""
    return {
        "summary": summarize(evals),
        "breakdown": {
            "by_style": breakdown(evals, lambda e: e.style),
            "by_item_count": breakdown(evals, lambda e: item_bucket(e.item_count)),
            "by_store_kind": breakdown(evals, lambda e: e.store_kind),
        },
        "errors": error_histogram(evals),
    }
