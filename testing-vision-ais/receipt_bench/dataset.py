"""Load a generated dataset and turn its ground truth into the same canonical
shape we score model predictions against (amounts as integer minor units)."""

from __future__ import annotations

import json
import random
from dataclasses import dataclass, field
from pathlib import Path


def to_minor(amount: float) -> int:
    """Convert a major-unit float (7.58) to minor units (758), rounding safely
    around binary float error (7.58 * 100 == 757.9999...)."""
    return int(round(float(amount) * 100))


@dataclass
class GTProduct:
    name: str
    value: int  # minor units, post per-line discount (the charged price)


@dataclass
class ReceiptCase:
    """One receipt: the input image plus its canonical ground truth."""

    id: str
    image_path: Path
    currency: str
    total: int  # grand total, minor units
    products: list[GTProduct]
    # dimensions used for report breakdowns
    style: str = "unknown"
    store_kind: str = "unknown"
    item_count: int = 0
    width_chars: int = 0
    extras: dict = field(default_factory=dict)


def _case_from_gt(gt: dict, image_path: Path, rid: str) -> ReceiptCase:
    currency = gt.get("currency", "PLN")
    products = [
        GTProduct(name=it["name"], value=to_minor(it["total"]))
        for it in gt.get("items", [])
    ]
    render = gt.get("render", {})
    return ReceiptCase(
        id=rid,
        image_path=image_path,
        currency=currency,
        total=to_minor(gt["total"]),
        products=products,
        style=render.get("style", "unknown"),
        store_kind=gt.get("store", {}).get("kind", "unknown"),
        item_count=len(products),
        width_chars=render.get("width_chars", 0),
    )


def load_dataset(path: str | Path) -> list[ReceiptCase]:
    """Load every receipt from a dataset directory.

    The directory is expected to contain ``index.jsonl`` (one row per receipt);
    if absent we fall back to globbing ``ground_truth/*.json``.
    """
    root = Path(path).resolve()
    if not root.is_dir():
        raise FileNotFoundError(f"dataset directory not found: {root}")

    cases: list[ReceiptCase] = []
    index = root / "index.jsonl"
    if index.exists():
        for line in index.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line:
                continue
            row = json.loads(line)
            gt = json.loads((root / row["ground_truth"]).read_text(encoding="utf-8"))
            cases.append(_case_from_gt(gt, root / row["image"], row["id"]))
    else:
        gt_dir = root / "ground_truth"
        img_dir = root / "images"
        for gt_file in sorted(gt_dir.glob("*.json")):
            gt = json.loads(gt_file.read_text(encoding="utf-8"))
            rid = gt.get("id", gt_file.stem)
            img = img_dir / f"{rid}.jpg"
            if not img.exists():
                # honour whatever the render block records
                img = root / gt.get("render", {}).get("image", str(img))
            cases.append(_case_from_gt(gt, img, rid))

    if not cases:
        raise RuntimeError(f"no receipts found in {root}")
    return cases


def load_many(paths: list[str | Path]) -> list[ReceiptCase]:
    """Load and concatenate several dataset directories (e.g. the three
    ``paragony_pl_czesc*`` folders)."""
    out: list[ReceiptCase] = []
    for p in paths:
        out.extend(load_dataset(p))
    return out


def sample(cases: list[ReceiptCase], n: int, seed: int) -> list[ReceiptCase]:
    """Deterministically pick ``n`` receipts (or all, if fewer)."""
    if n <= 0 or n >= len(cases):
        return list(cases)
    rng = random.Random(seed)
    return rng.sample(cases, n)
