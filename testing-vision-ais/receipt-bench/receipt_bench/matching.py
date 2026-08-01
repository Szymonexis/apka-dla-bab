"""Match predicted line items against ground-truth ones so we can score product
precision / recall / F1 and per-item price accuracy.

Names rarely match byte-for-byte (a model may drop a size suffix or mangle a
diacritic), so we normalise then compare with a fuzzy ratio, pairing items
greedily best-first, one-to-one."""

from __future__ import annotations

import unicodedata
from dataclasses import dataclass
from difflib import SequenceMatcher


def normalize(name: str) -> str:
    """Lowercase, strip diacritics and punctuation, collapse whitespace."""
    text = unicodedata.normalize("NFKD", name)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.casefold()
    text = "".join(c if c.isalnum() or c.isspace() else " " for c in text)
    return " ".join(text.split())


def name_similarity(a: str, b: str) -> float:
    return SequenceMatcher(None, normalize(a), normalize(b)).ratio()


@dataclass
class Pair:
    gt_index: int
    pred_index: int
    name_sim: float
    price_exact: bool
    price_abs_err: int  # minor units


@dataclass
class MatchResult:
    pairs: list[Pair]
    unmatched_gt: list[int]     # missed items
    unmatched_pred: list[int]   # hallucinated / extra items
    gt_count: int
    pred_count: int
    threshold: float

    # --- name-level (a pair counts if names are similar enough) ---
    @property
    def matched(self) -> int:
        return len(self.pairs)

    @property
    def precision(self) -> float:
        return self.matched / self.pred_count if self.pred_count else 0.0

    @property
    def recall(self) -> float:
        return self.matched / self.gt_count if self.gt_count else 0.0

    @property
    def f1(self) -> float:
        p, r = self.precision, self.recall
        return 2 * p * r / (p + r) if (p + r) else 0.0

    # --- name+price (a pair counts only if the price is also exact) ---
    @property
    def matched_with_price(self) -> int:
        return sum(1 for p in self.pairs if p.price_exact)

    @property
    def name_price_precision(self) -> float:
        return self.matched_with_price / self.pred_count if self.pred_count else 0.0

    @property
    def name_price_recall(self) -> float:
        return self.matched_with_price / self.gt_count if self.gt_count else 0.0

    @property
    def name_price_f1(self) -> float:
        p, r = self.name_price_precision, self.name_price_recall
        return 2 * p * r / (p + r) if (p + r) else 0.0

    @property
    def price_exact_rate(self) -> float:
        """Among name-matched pairs, the share with the exact price."""
        return self.matched_with_price / self.matched if self.matched else 0.0


def match_products(gt, pred, threshold: float = 0.6) -> MatchResult:
    """Greedily pair GT and predicted products.

    ``gt`` items expose ``.name``/``.value``; ``pred`` items likewise.
    """
    candidates: list[tuple[float, int, int]] = []
    for gi, g in enumerate(gt):
        for pi, p in enumerate(pred):
            sim = name_similarity(g.name, p.name)
            if sim >= threshold:
                candidates.append((sim, gi, pi))
    candidates.sort(reverse=True)  # best similarity first

    used_gt: set[int] = set()
    used_pred: set[int] = set()
    pairs: list[Pair] = []
    for sim, gi, pi in candidates:
        if gi in used_gt or pi in used_pred:
            continue
        used_gt.add(gi)
        used_pred.add(pi)
        err = abs(gt[gi].value - pred[pi].value)
        pairs.append(Pair(gi, pi, round(sim, 4), err == 0, err))

    pairs.sort(key=lambda p: p.gt_index)
    return MatchResult(
        pairs=pairs,
        unmatched_gt=[i for i in range(len(gt)) if i not in used_gt],
        unmatched_pred=[i for i in range(len(pred)) if i not in used_pred],
        gt_count=len(gt),
        pred_count=len(pred),
        threshold=threshold,
    )
