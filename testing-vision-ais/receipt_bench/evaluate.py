"""Score one model reply against one receipt's ground truth."""

from __future__ import annotations

from dataclasses import dataclass, field

from .dataset import ReceiptCase
from .matching import MatchResult, match_products
from .ollama import InferResult
from .schema import parse_prediction

# Hard failures — the model gave us nothing usable.
HARD_FAILURES = {"api_error", "invalid_json", "schema_invalid"}


@dataclass
class ReceiptEval:
    id: str
    model: str
    style: str
    store_kind: str
    item_count: int
    width_chars: int

    ok: bool                     # produced a schema-valid receipt
    category: str                # ok | api_error | invalid_json | schema_invalid
    issues: list[str] = field(default_factory=list)
    error: str | None = None

    total_gt: int = 0
    total_pred: int | None = None
    total_exact: bool = False
    total_abs_err: int | None = None
    total_signed_err: int | None = None

    currency_gt: str = ""
    currency_pred: str | None = None
    currency_correct: bool = False

    pred_product_count: int = 0
    pred_sum: int | None = None
    match: MatchResult | None = None
    gt_products: list[tuple[str, int]] = field(default_factory=list)
    pred_products: list[tuple[str, int]] = field(default_factory=list)

    latency_ms: float = 0.0
    prompt_tokens: int | None = None
    eval_tokens: int | None = None
    tokens_per_sec: float | None = None

    raw: str = ""


def evaluate_case(case: ReceiptCase, infer: InferResult, name_threshold: float) -> ReceiptEval:
    ev = ReceiptEval(
        id=case.id,
        model="",  # filled in by the caller
        style=case.style,
        store_kind=case.store_kind,
        item_count=case.item_count,
        width_chars=case.width_chars,
        ok=False,
        category="api_error",
        total_gt=case.total,
        currency_gt=case.currency,
        latency_ms=infer.latency_ms,
        prompt_tokens=infer.prompt_tokens,
        eval_tokens=infer.eval_tokens,
        tokens_per_sec=infer.tokens_per_sec,
        raw=infer.content,
        gt_products=[(p.name, p.value) for p in case.products],
    )

    if not infer.ok:
        ev.category = "api_error"
        ev.error = infer.error
        ev.issues = ["api_error"]
        return ev

    receipt, category, error = parse_prediction(infer.content)
    ev.category = category
    if receipt is None:
        ev.error = error
        ev.issues = [category]
        return ev

    # We have a schema-valid receipt.
    ev.ok = True

    ev.total_pred = receipt.total.value
    ev.total_signed_err = receipt.total.value - case.total
    ev.total_abs_err = abs(ev.total_signed_err)
    ev.total_exact = ev.total_abs_err == 0

    ev.currency_pred = receipt.total.currency
    ev.currency_correct = receipt.total.currency.upper() == case.currency.upper()

    ev.pred_product_count = len(receipt.products)
    ev.pred_sum = sum(p.value for p in receipt.products)
    ev.pred_products = [(p.name, p.value) for p in receipt.products]
    ev.match = match_products(case.products, receipt.products, threshold=name_threshold)

    # Quality issues (only meaningful once we have a valid receipt).
    issues: list[str] = []
    if not ev.total_exact:
        issues.append("wrong_total")
    if not ev.currency_correct:
        issues.append("wrong_currency")
    if ev.match.recall < 1.0:
        issues.append("missing_products")
    if ev.match.precision < 1.0:
        issues.append("extra_products")
    if ev.match.matched_with_price < ev.match.matched:
        issues.append("price_errors")
    ev.issues = issues
    return ev
