# Syntetyczny zbiór paragonów fiskalnych (PL) — do testów OCR / parserów

300 wygenerowanych paragonów w polskim formacie fiskalnym, z pełnym ground truth:
strukturą danych, tekstem i bounding boxami dla każdej linii.

**Wszystkie sieci, NIP-y, adresy, nazwiska kasjerów i numery są fikcyjne.**
Zbiór nie zawiera żadnych prawdziwych paragonów ani danych osobowych — nadaje się
do publikowania, commitowania do repo i używania w CI.

---

## Zawartość

```
dataset/
  images/          PL-00001.jpg … PL-00300.jpg    obrazki wejściowe
  ground_truth/    PL-00001.json …                pełny ground truth (struktura + boxy)
  text/            PL-00001.txt  …                sam tekst paragonu (układ znakowy)
  index.jsonl                                     jedna linia = jeden paragon
  index.csv                                       to samo, płasko
generator/         kod generatora (catalog.py, receipt.py, render.py, generate.py)
tools/
  validate.py      walidacja spójności zbioru
  draw_boxes.py    podgląd bounding boxów na obrazku
sample_gallery.jpg podgląd 12 losowych paragonów
```

## Format ground truth

```jsonc
{
  "id": "PL-00042",
  "store": {
    "name": "PRIMO MARKET SP. Z O.O.", "short_name": "PRIMO MARKET",
    "kind": "spozywczy", "street": "ul. Polna 84", "postal_code": "31-234",
    "city": "Kraków", "nip": "6167800833",   // poprawna suma kontrolna mod 11
    "shop_no": "1003"
  },
  "receipt_no": 98077, "register_no": 17, "cashier": "Robert J.",
  "datetime": "2024-09-27T08:29:41", "currency": "PLN",

  "items": [{
    "line": 1, "name": "Mleko UHT 3,2% 1L", "qty": 2, "unit": "szt",
    "unit_price": 3.79, "discount": 0.0, "total": 7.58,
    "vat_code": "B", "vat_rate": 0.08
  }],

  "vat_summary": [
    {"code": "A", "rate": 0.23, "net": 490.09, "vat": 112.72, "gross": 602.81}
  ],
  "total_net": 536.45, "total_vat": 112.11, "total": 648.56,
  "payment_method": "KARTA PŁATNICZA", "paid": 648.56, "change": 0.0,
  "buyer_nip": null,                    // paragon-faktura uproszczona (≤450 zł)
  "loyalty_card": {"program": "…", "number": "…", "points": 177},
  "fiscal_no": "MXC31321298", "device_no": "FEA 3535887",

  "ocr_text": "…pełny tekst paragonu…",
  "boxes": [{
    "field": "total.value",           // nazwa pola albo null
    "text": "648,56",
    "box":  [412.0, 1188.3, 508.7, 1214.9],          // AABB
    "quad": [[412,1188],[508,1191],[507,1215],[411,1212]]  // po transformacji
  }],
  "render": {
    "image": "images/PL-00042.jpg", "style": "photo",
    "width_px": 781, "height_px": 1737, "width_chars": 36,
    "jpeg_quality": 71,
    "augmentations": ["zagniecenia", "obrot=-6.3st", "perspektywa", …]
  }
}
```

### Nazwy pól w `boxes`

| `field`                   | znaczenie |
|---------------------------|-----------|
| `store.name` / `.street` / `.city` / `.shop_no` / `.nip` | nagłówek sprzedawcy |
| `doc_type`                | linia „PARAGON FISKALNY" |
| `receipt_no`              | data + numer wydruku |
| `item.N.name`             | nazwa pozycji (gdy zawinięta do osobnej linii) |
| `item.N.amount`           | linia `ilość x cena … wartość KOD` |
| `item.N.line`             | pozycja zmieszczona w jednej linii |
| `item.N.discount`         | linia `OPUST` |
| `vat.X.gross` / `vat.X.vat` | podsumowanie PTU dla stawki X |
| `total_vat`, `total`      | `SUMA PTU`, `SUMA PLN` |
| `payment.paid`, `payment.change` | forma płatności, reszta |
| `cashier`, `datetime`, `fiscal_no`, `device_no`, `buyer_nip`, `loyalty.*` | stopka |

Pola z sufiksem `.value` to prawa kolumna (kwota) danej linii — np. `total` to
etykieta „SUMA PLN", a `total.value` to sama kwota. To jest to, co zwykle chcesz
porównać z wyjściem parsera.

## Co jest w środku — rozkład

| wymiar | wartości |
|---|---|
| styl | `photo` (189, zdjęcie na blacie: tło, cień, perspektywa, nierówne światło) / `scan` (111, płaskie, białe tło) |
| sieci | 11 fikcyjnych marek w 7 branżach: spożywczy, hipermarket, drogeria, budowlany, meble, apteka, elektro |
| pozycji na paragonie | 1–30 (łącznie 2324) |
| kwoty | 9,96 zł – 9 497,05 zł |
| stawki VAT | A 23%, B 8%, C 5% (kody i stawki jak w PL) |
| płatność | karta / BLIK / gotówka z resztą / bon |
| szerokość wydruku | 32–48 znaków |
| fonty | DejaVu Sans Mono, Liberation Mono (2 kroje, rozmiary 15–22 px) |
| augmentacje | obrót ±9°, perspektywa, zagniecenia papieru, wyblakły druk termiczny, nierówne oświetlenie, szum, rozmycie, zmiana kontrastu, skala szarości, JPEG q58–96, postrzępiona krawędź |

## Przypadki brzegowe, które zbiór celowo zawiera

- pozycje na wagę z ilością ułamkową (`0,847 kg x 12,99`)
- rabaty pozycyjne (`OPUST`) — wartość przy pozycji jest **przed** rabatem
- paragony z jedną pozycją i paragony na 30 pozycji (przewijają się przez wiele „ekranów")
- kwoty czterocyfrowe z separatorem tysięcy (`1 684,15`)
- polskie znaki diakrytyczne w nazwach produktów (`Ogórek`, `Świeca`, `Mydło`)
- paragon jako faktura uproszczona (`NIP NABYWCY`) przy kwocie ≤ 450 zł
- nazwy produktów zawijane do osobnej linii vs. mieszczące się w jednej
- kasa samoobsługowa jako „kasjer"

## Użycie

```bash
# walidacja spójności (arytmetyka VAT, sumy kontrolne NIP, boxy w kadrze)
python3 tools/validate.py dataset

# podgląd bounding boxów
python3 tools/draw_boxes.py dataset PL-00042 podglad.png

# wygenerowanie własnej porcji (inny seed = inny zbiór, ten sam seed = powtarzalny)
python3 generator/generate.py --n 1000 --out moj_zbior --seed 123
```

Wymagania: Python 3.9+, `pillow`, `numpy`. Fonty DejaVu / Liberation
(w Debianie: `fonts-dejavu-core`, `fonts-liberation`).

### Szybki przykład ewaluacji

```python
import json

for line in open("dataset/index.jsonl", encoding="utf-8"):
    row = json.loads(line)
    gt = json.load(open(f"dataset/{row['ground_truth']}", encoding="utf-8"))
    pred = moj_parser(f"dataset/{row['image']}")
    assert abs(pred["total"] - gt["total"]) < 0.01, row["id"]
```

## Ograniczenia — warto wiedzieć

- Tekst jest **renderowany, nie fotografowany**: brak prawdziwych artefaktów
  matrycy, ostrości pola i odbić. Model wytrenowany wyłącznie na tym zbiorze
  będzie miał lukę względem zdjęć z telefonu.
- Brak logotypów i kodów kreskowych/QR — celowo, żeby nie odwzorowywać
  prawdziwych marek. Jeśli potrzebujesz ich do testu detekcji, dołóż własne.
- Papier jest płaski: perspektywa i zagniecenia są symulowane afinicznie,
  nie ma prawdziwego zwinięcia rolki.
- Rozkład produktów i cen jest wymyślony, choć realistyczny co do rzędu wielkości
  (ceny z lat 2024–2026).

Jako uzupełnienie o realne zdjęcia warto sięgnąć po publiczne, licencjonowane
zbiory: [ICDAR 2019 SROIE](https://github.com/zzzDavid/ICDAR-2019-SROIE)
i [CORD](https://github.com/clovaai/cord) (paragony azjatyckie, ale prawdziwe
fotografie — dobry materiał na warstwę „realizmu wizualnego").
