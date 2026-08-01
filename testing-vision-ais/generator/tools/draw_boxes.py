# -*- coding: utf-8 -*-
"""Podgląd: rysuje bounding boxy z ground truth na obrazku paragonu.

    python3 draw_boxes.py ../dataset PL-00002 out.png
"""
import json
import os
import sys

from PIL import Image, ImageDraw

ds, rid = sys.argv[1], sys.argv[2]
out = sys.argv[3] if len(sys.argv) > 3 else f"{rid}_boxes.png"

gt = json.load(open(os.path.join(ds, "ground_truth", f"{rid}.json"), encoding="utf-8"))
im = Image.open(os.path.join(ds, gt["render"]["image"])).convert("RGB")
d = ImageDraw.Draw(im)

for b in gt["boxes"]:
    f = b["field"] or ""
    if f.startswith("item"):
        col = (0, 160, 255)
    elif f.startswith("vat") or f.startswith("total"):
        col = (255, 60, 60)
    elif f.startswith("store"):
        col = (0, 190, 90)
    else:
        col = (255, 170, 0)
    d.polygon([tuple(p) for p in b["quad"]], outline=col)

im.save(out)
print("zapisano", out)
