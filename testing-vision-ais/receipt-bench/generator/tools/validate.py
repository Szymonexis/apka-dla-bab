# -*- coding: utf-8 -*-
"""Walidacja zbioru: spójność arytmetyczna, sumy kontrolne NIP, boxy w kadrze.

    python3 validate.py ../dataset
"""
import json
import os
import sys

from PIL import Image

ds = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else "../dataset")
errors = []
n = 0


def nip_ok(nip):
    w = [6, 5, 7, 2, 3, 4, 5, 6, 7]
    if len(nip) != 10 or not nip.isdigit():
        return False
    c = sum(a * int(b) for a, b in zip(w, nip[:9])) % 11
    return c != 10 and c == int(nip[9])


def close(a, b, tol=0.011):
    return abs(a - b) <= tol


for line in open(os.path.join(ds, "index.jsonl"), encoding="utf-8"):
    row = json.loads(line)
    rid = row["id"]
    n += 1
    gt = json.load(open(os.path.join(ds, "ground_truth", f"{rid}.json"), encoding="utf-8"))

    # 1. NIP sprzedawcy
    if not nip_ok(gt["store"]["nip"]):
        errors.append(f"{rid}: błędna suma kontrolna NIP {gt['store']['nip']}")
    if gt["buyer_nip"] and not nip_ok(gt["buyer_nip"]):
        errors.append(f"{rid}: błędny NIP nabywcy")

    # 2. pozycje -> koszyki VAT
    buckets = {}
    for it in gt["items"]:
        buckets[it["vat_code"]] = round(buckets.get(it["vat_code"], 0.0) + it["total"], 2)
        exp = round(it["unit_price"] * it["qty"] - it["discount"], 2)
        if not close(exp, it["total"], 0.02):
            errors.append(f"{rid}: poz.{it['line']} {exp} != {it['total']}")
    for b in gt["vat_summary"]:
        if not close(buckets.get(b["code"], 0.0), b["gross"], 0.02):
            errors.append(f"{rid}: PTU {b['code']} brutto niezgodne")
        if not close(b["net"] + b["vat"], b["gross"]):
            errors.append(f"{rid}: PTU {b['code']} netto+vat != brutto")
        if not close(round(b["gross"] / (1 + b["rate"]), 2), b["net"]):
            errors.append(f"{rid}: PTU {b['code']} netto niezgodne ze stawką")

    # 3. sumy
    if not close(sum(b["gross"] for b in gt["vat_summary"]), gt["total"], 0.02):
        errors.append(f"{rid}: SUMA PLN niezgodna")
    if not close(gt["total_net"] + gt["total_vat"], gt["total"], 0.02):
        errors.append(f"{rid}: netto+VAT != brutto")
    if gt["payment_method"] == "GOTÓWKA" and not close(gt["paid"] - gt["total"], gt["change"]):
        errors.append(f"{rid}: reszta niezgodna")

    # 4. pliki i boxy
    ip = os.path.join(ds, gt["render"]["image"])
    if not os.path.exists(ip):
        errors.append(f"{rid}: brak obrazka")
        continue
    W, H = Image.open(ip).size
    if (W, H) != (gt["render"]["width_px"], gt["render"]["height_px"]):
        errors.append(f"{rid}: rozmiar obrazka niezgodny z metadanymi")
    out = [b for b in gt["boxes"]
           if b["box"][0] < -2 or b["box"][1] < -2 or b["box"][2] > W + 2 or b["box"][3] > H + 2]
    if out:
        errors.append(f"{rid}: {len(out)} boxów poza kadrem (np. {out[0]['text'][:25]!r})")

    # 5. kluczowe pola obecne w boxach
    fields = {b["field"] for b in gt["boxes"]}
    for req in ("store.nip", "total", "total.value", "doc_type", "datetime"):
        if req not in fields:
            errors.append(f"{rid}: brak pola {req} w boxach")

print(f"Sprawdzono {n} paragonów.")
if errors:
    print(f"BŁĘDY: {len(errors)}")
    for e in errors[:40]:
        print(" -", e)
    sys.exit(1)
print("OK — zbiór spójny.")
