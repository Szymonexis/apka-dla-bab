# -*- coding: utf-8 -*-
"""Generuje syntetyczny zbiór paragonów w polskim formacie fiskalnym.

Użycie:
    python3 generate.py --n 300 --out ../dataset --seed 42
"""

import argparse
import json
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from receipt import Receipt, lines_to_text
from render import render_receipt, augment


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=300)
    ap.add_argument("--out", default="../dataset")
    ap.add_argument("--seed", type=int, default=42)
    args = ap.parse_args()

    out = os.path.abspath(args.out)
    img_dir = os.path.join(out, "images")
    gt_dir = os.path.join(out, "ground_truth")
    txt_dir = os.path.join(out, "text")
    for d in (img_dir, gt_dir, txt_dir):
        os.makedirs(d, exist_ok=True)

    rng = random.Random(args.seed)
    index = []

    for i in range(1, args.n + 1):
        r = Receipt(rng, i)
        width_chars = rng.choice([32, 36, 38, 40, 42, 44, 48])
        lines = r.render_lines(width_chars)
        base_img, boxes = render_receipt(lines, rng, width_chars)

        style = "scan" if rng.random() < 0.35 else "photo"
        img, boxes, applied = augment(base_img, boxes, rng, style)

        rid = f"PL-{i:05d}"
        quality = rng.randint(58, 94) if style == "photo" else rng.randint(75, 96)
        img_name = f"{rid}.jpg"
        img.save(os.path.join(img_dir, img_name), "JPEG", quality=quality)

        plain = lines_to_text(lines, width_chars)
        with open(os.path.join(txt_dir, f"{rid}.txt"), "w", encoding="utf-8") as f:
            f.write(plain)

        gt = r.to_dict()
        gt["render"] = {
            "image": f"images/{img_name}",
            "text": f"text/{rid}.txt",
            "width_px": img.width,
            "height_px": img.height,
            "width_chars": width_chars,
            "style": style,
            "jpeg_quality": quality,
            "augmentations": applied,
        }
        gt["ocr_text"] = plain
        gt["boxes"] = boxes
        with open(os.path.join(gt_dir, f"{rid}.json"), "w", encoding="utf-8") as f:
            json.dump(gt, f, ensure_ascii=False, indent=2)

        index.append({
            "id": rid,
            "image": f"images/{img_name}",
            "ground_truth": f"ground_truth/{rid}.json",
            "text": f"text/{rid}.txt",
            "store_name": r.store["name"],
            "store_kind": r.store["kind"],
            "nip": r.store["nip"],
            "datetime": gt["datetime"],
            "item_count": len(r.items),
            "total": r.total,
            "payment_method": r.payment_method,
            "style": style,
            "width_px": img.width,
            "height_px": img.height,
        })

        if i % 25 == 0:
            print(f"  {i}/{args.n}", flush=True)

    with open(os.path.join(out, "index.jsonl"), "w", encoding="utf-8") as f:
        for row in index:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    # płaski CSV — wygodny do szybkiego porównania wyniku parsera
    import csv
    with open(os.path.join(out, "index.csv"), "w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(index[0].keys()))
        w.writeheader()
        w.writerows(index)

    print(f"Gotowe: {len(index)} paragonów -> {out}")


if __name__ == "__main__":
    main()
