# -*- coding: utf-8 -*-
"""Model danych paragonu + budowa układu tekstowego (znakowego)."""

import random
from datetime import datetime, timedelta

from catalog import (VAT_RATES, STREETS, CITIES, CASHIERS, STORES)


def valid_nip(rng):
    """Generuje NIP z poprawną sumą kontrolną (algorytm mod 11)."""
    weights = [6, 5, 7, 2, 3, 4, 5, 6, 7]
    while True:
        digits = [rng.randint(1, 9)] + [rng.randint(0, 9) for _ in range(8)]
        checksum = sum(w * d for w, d in zip(weights, digits)) % 11
        if checksum != 10:
            return "".join(map(str, digits)) + str(checksum)


def money(v):
    return f"{v:,.2f}".replace(",", " ").replace(".", ",")


def round2(v):
    return int(round(v * 100)) / 100.0


def lines_to_text(lines, width):
    """Wersja czysto tekstowa (ground truth dla OCR) — układ znakowy."""
    out = []
    for text, align, _style, _field in lines:
        if isinstance(text, tuple):
            lab, val = text
            out.append(lab + " " * max(1, width - len(lab) - len(val)) + val)
        elif not text:
            out.append("")
        elif align == "c":
            out.append(" " * max(0, (width - len(text)) // 2) + text)
        elif align == "r":
            out.append(" " * max(0, width - len(text)) + text)
        else:
            out.append(text)
    return "\n".join(out)


class Receipt:
    """Jeden paragon: dane strukturalne + wyliczenia podatkowe."""

    def __init__(self, rng, idx):
        self.rng = rng
        self.idx = idx
        self.store_def = rng.choice(STORES)
        self._build_store()
        self._build_meta()
        self._build_items()
        self._build_totals()
        self._build_payment()

    # ---------------------------------------------------------------- sklep
    def _build_store(self):
        rng = self.rng
        city, postal = rng.choice(CITIES)
        self.store = {
            "name": self.store_def["name"],
            "short_name": self.store_def["short"],
            "kind": self.store_def["kind"],
            "street": f"{rng.choice(STREETS)} {rng.randint(1, 180)}"
                      + (f"/{rng.randint(1, 40)}" if rng.random() < 0.25 else ""),
            "postal_code": postal,
            "city": city,
            "nip": valid_nip(rng),
            "shop_no": f"{rng.randint(1, 1499):04d}",
        }

    # ----------------------------------------------------------- metadane
    def _build_meta(self):
        rng = self.rng
        base = datetime(2024, 1, 1, 8, 0)
        dt = base + timedelta(
            days=rng.randint(0, 940),
            hours=rng.randint(0, 13),
            minutes=rng.randint(0, 59),
            seconds=rng.randint(0, 59),
        )
        self.datetime = dt.replace(second=rng.randint(0, 59))
        self.receipt_no = rng.randint(1, 99999)
        self.register_no = rng.randint(1, 24)
        self.cashier = rng.choice(CASHIERS)
        self.fiscal_no = (
            f"{''.join(rng.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ') for _ in range(3))}"
            f"{rng.randint(10000000, 99999999)}"
        )
        # numer unikatowy kasy fiskalnej
        self.device_no = (
            f"{''.join(rng.choice('ABCDEFGHJKLMNPQRSTUVWXYZ') for _ in range(3))} "
            f"{rng.randint(1000000, 9999999)}"
        )

    # ---------------------------------------------------------------- pozycje
    def _build_items(self):
        rng = self.rng
        lo, hi = self.store_def["n_items"]
        n = rng.randint(lo, hi)
        catalog = self.store_def["catalog"]
        picked = rng.sample(catalog, min(n, len(catalog)))
        self.items = []
        for i, (name, unit, pmin, pmax) in enumerate(
                [(p[0], p[1], p[2], p[3]) for p in picked], start=1):
            vat_code = picked[i - 1][4]
            unit_price = round2(rng.uniform(pmin, pmax))
            if unit == "kg" or unit == "m2":
                qty = round(rng.uniform(0.15, 3.2), 3)
            elif rng.random() < 0.22:
                qty = rng.randint(2, 6)
            else:
                qty = 1
            total = round2(unit_price * qty)
            discount = 0.0
            if rng.random() < 0.10:
                discount = round2(total * rng.uniform(0.05, 0.35))
                total = round2(total - discount)
            self.items.append({
                "line": i,
                "name": name,
                "qty": qty,
                "unit": unit,
                "unit_price": unit_price,
                "discount": discount,
                "total": total,
                "vat_code": vat_code,
                "vat_rate": VAT_RATES[vat_code],
            })

    # ---------------------------------------------------------------- sumy
    def _build_totals(self):
        buckets = {}
        for it in self.items:
            b = buckets.setdefault(it["vat_code"], 0.0)
            buckets[it["vat_code"]] = round2(b + it["total"])
        self.vat_summary = []
        for code in sorted(buckets):
            gross = buckets[code]
            rate = VAT_RATES[code]
            net = round2(gross / (1 + rate))
            vat = round2(gross - net)
            self.vat_summary.append({
                "code": code, "rate": rate,
                "net": net, "vat": vat, "gross": gross,
            })
        self.total = round2(sum(b["gross"] for b in self.vat_summary))
        self.total_vat = round2(sum(b["vat"] for b in self.vat_summary))
        self.total_net = round2(self.total - self.total_vat)

    # ---------------------------------------------------------------- płatność
    def _build_payment(self):
        rng = self.rng
        r = rng.random()
        if r < 0.42:
            self.payment_method = "KARTA PŁATNICZA"
            self.paid = self.total
            self.change = 0.0
        elif r < 0.62:
            self.payment_method = "BLIK"
            self.paid = self.total
            self.change = 0.0
        elif r < 0.94:
            self.payment_method = "GOTÓWKA"
            step = rng.choice([10, 20, 50, 100])
            self.paid = float(int(self.total / step + 1) * step)
            self.change = round2(self.paid - self.total)
        else:
            self.payment_method = "BON / VOUCHER"
            self.paid = self.total
            self.change = 0.0

        self.loyalty_card = None
        if self.store_def["loyalty"] and rng.random() < 0.45:
            self.loyalty_card = {
                "program": self.store_def["loyalty"],
                "number": f"{rng.randint(10**11, 10**12 - 1)}",
                "points": rng.randint(1, 900),
            }
        # faktura uproszczona: paragon z NIP nabywcy do 450 PLN
        self.buyer_nip = None
        if self.total <= 450 and rng.random() < 0.12:
            self.buyer_nip = valid_nip(rng)

    # ---------------------------------------------------------------- układ
    def render_lines(self, width):
        """Zwraca listę (tekst, align, styl, pole) — układ znakowy paragonu.

        align: 'l' | 'c' | 'r'
        styl:  'normal' | 'bold' | 'big'
        pole:  nazwa pola ground-truth albo None
        """
        L = []
        add = lambda t, a="l", s="normal", f=None: L.append((t, a, s, f))
        st = self.store

        add(st["name"], "c", "bold", "store.name")
        add(f'{st["street"]}', "c", "normal", "store.street")
        add(f'{st["postal_code"]} {st["city"]}', "c", "normal", "store.city")
        add(f'Sklep nr {st["shop_no"]}', "c", "normal", "store.shop_no")
        add(f'NIP {st["nip"]}', "c", "normal", "store.nip")
        add("")
        add((self.datetime.strftime("%d-%m-%Y"),
             f"nr wydr. {self.receipt_no:06d}"), "l", "normal", "receipt_no")
        add("")
        add("PARAGON FISKALNY", "c", "big", "doc_type")
        add("")

        wrap_names = self.rng.random() < 0.55
        for it in self.items:
            qty_s = (f'{it["qty"]:g}' if isinstance(it["qty"], int)
                     else f'{it["qty"]:.3f}'.replace(".", ","))
            mid = f'{qty_s} x {money(it["unit_price"])}'
            right = f'{money(it["total"] + it["discount"])} {it["vat_code"]}'
            name = it["name"]
            if wrap_names or len(name) + len(mid) + len(right) + 2 > width:
                add(name, "l", "normal", f'item.{it["line"]}.name')
                pad = width - len(mid) - len(right)
                add(" " * 3 + mid + " " * max(1, pad - 3) + right,
                    "l", "normal", f'item.{it["line"]}.amount')
            else:
                pad = width - len(name) - len(mid) - len(right) - 1
                add(name + " " + mid + " " * max(1, pad) + right,
                    "l", "normal", f'item.{it["line"]}.line')
            if it["discount"] > 0:
                add(("  OPUST", f'-{money(it["discount"])}'),
                    "l", "normal", f'item.{it["line"]}.discount')

        add("-" * width)
        for b in self.vat_summary:
            pct = f'{int(b["rate"] * 100)}%'
            add((f'Sprzed. opod. PTU {b["code"]}', money(b["gross"])),
                "l", "normal", f'vat.{b["code"]}.gross')
            add((f'Kwota PTU {b["code"]} {pct}', money(b["vat"])),
                "l", "normal", f'vat.{b["code"]}.vat')
        add(("SUMA PTU", money(self.total_vat)), "l", "normal", "total_vat")
        add("-" * width)
        add(("SUMA PLN", money(self.total)), "l", "big", "total")
        add("")
        add((self.payment_method, money(self.paid)), "l", "normal", "payment.paid")
        if self.change > 0:
            add(("RESZTA", money(self.change)), "l", "normal", "payment.change")
        if self.buyer_nip:
            add(f"NIP NABYWCY {self.buyer_nip}", "l", "normal", "buyer_nip")
        if self.loyalty_card:
            add("")
            lc = self.loyalty_card
            add(lc["program"], "c", "normal", "loyalty.program")
            add(f'Nr karty: {lc["number"]}', "c", "normal", "loyalty.number")
            add(f'Naliczone punkty: {lc["points"]}', "c", "normal", "loyalty.points")
        add("")
        add(f'{self.register_no:03d}#{self.receipt_no:05d}  KASJER: {self.cashier}',
            "l", "normal", "cashier")
        add(self.datetime.strftime("%d-%m-%Y %H:%M"), "l", "normal", "datetime")
        add("")
        add(f'PL {self.fiscal_no}', "c", "bold", "fiscal_no")
        add(self.device_no, "c", "normal", "device_no")
        add("")
        add("DZIĘKUJEMY ZA ZAKUPY", "c", "normal", None)
        if self.rng.random() < 0.4:
            add("ZAPRASZAMY PONOWNIE", "c", "normal", None)
        return L

    # ---------------------------------------------------------------- eksport
    def to_dict(self):
        return {
            "id": f"PL-{self.idx:05d}",
            "store": self.store,
            "receipt_no": self.receipt_no,
            "register_no": self.register_no,
            "cashier": self.cashier,
            "datetime": self.datetime.isoformat(timespec="seconds"),
            "currency": "PLN",
            "items": self.items,
            "vat_summary": self.vat_summary,
            "total_net": self.total_net,
            "total_vat": self.total_vat,
            "total": self.total,
            "payment_method": self.payment_method,
            "paid": self.paid,
            "change": self.change,
            "buyer_nip": self.buyer_nip,
            "loyalty_card": self.loyalty_card,
            "fiscal_no": self.fiscal_no,
            "device_no": self.device_no,
            "item_count": len(self.items),
        }
