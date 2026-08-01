# receipt-bench

Benchmark lokalnych modeli vision (przez [Ollama](https://ollama.com)) na
syntetycznych polskich paragonach. Narzędzie:

1. **generuje** X paragonów (reużywa generatora z `../paragony_pl_czesc1`),
2. **wysyła** każdy obraz do modelu na Twojej maszynie (`localhost:11434`),
   prosząc o wynik w formacie z `../return-schema.json`,
3. **porównuje** odpowiedź z ground truth i **zapisuje raport** JSON (+ Markdown).

Schemat wyniku jest zdefiniowany raz, w **Pydantic** (pythonowy odpowiednik
`zod`/`yup`) — `receipt_bench/schema.py`. Z tej jednej definicji powstaje zarówno
JSON Schema podawany Ollamie w polu `format` (wymusza kształt odpowiedzi), jak i
walidacja tego, co model faktycznie zwrócił.

## Wymagania

- Ollama z pobranym modelem vision, np. `ollama pull gemma4:12b`.
- Nix — `shell.nix` daje Pythona z `pillow`, `numpy`, `pydantic`, `requests`
  oraz fonty DejaVu / Liberation (generator ma zaszyte ścieżki `/usr/share/fonts`,
  które na NixOS podstawiamy w locie).

## Uruchomienie

```sh
nix-shell                                   # python + fonty
python run.py --generate 20                 # 20 świeżych paragonów -> gemma4:12b
python run.py --generate 50 --models gemma4:12b,qwen2.5vl:7b   # kilka modeli
python -m receipt_bench --help              # wszystkie flagi
```

Domyślnie testuje modele z `config.toml` (skopiuj z `config.example.toml`),
a bez pliku — `gemma4:12b`. Raporty lądują w `reports/`.

### Zamiast generować — użyj gotowych 300

```sh
python run.py --dataset ../paragony_pl_czesc1/dataset,../paragony_pl_czesc2/dataset,../paragony_pl_czesc3/dataset --sample 30
```

## Najważniejsze flagi

| flaga | znaczenie |
|---|---|
| `--generate N` | wygeneruj N świeżych paragonów (domyślnie) |
| `--dataset DIR[,DIR]` | użyj istniejących datasetów zamiast generować |
| `--sample N` | z `--dataset`: losowo wybierz N |
| `--models a,b,c` | lista modeli Ollamy do porównania |
| `--report-level` | `summary` \| `diagnostic` (domyślnie) \| `full` |
| `--limit N` | ogranicz liczbę realnie odpytanych paragonów |
| `--seed`, `--url`, `--name-threshold`, `--timeout` | jak w configu |
| `--print-schema` | wypisz schemat `format` dla Ollamy i zakończ |

## Poziomy raportu

- **`summary`** — tablica wyników: jeden obiekt per model z nagłówkowymi KPI.
  Do szybkiego rankingu „który model wygrywa".
- **`diagnostic`** (domyślny) — podsumowanie + rozbicia po wymiarach
  (`photo`/`scan`, liczba pozycji, branża sklepu) + histogram błędów.
  Do zrozumienia *gdzie* model się psuje.
- **`full`** — to co wyżej + wpis per paragon (predykcja vs ground truth,
  diff pozycji, surowe wyjście modelu). Do debugowania konkretnych przypadków.

Obok JSON-a zawsze (chyba że `--no-markdown`) powstaje `report-*.md` — tabela
porównawcza modeli gotowa do wklejenia.

## Metryki

Per model liczone są m.in.:

- **`schema_valid_rate`** — odsetek odpowiedzi, które w ogóle przeszły walidację
  schematu (nie: „prawie JSON").
- **`total_exact_rate`** — odsetek paragonów z *dokładnie* trafioną sumą.
- **`total_mae_grosze`** — średni błąd bezwzględny sumy (w groszach) + percentyle.
- **`product_f1`** — F1 dopasowania pozycji (nazwy dopasowane rozmyciem po
  normalizacji: bez ogonków, bez interpunkcji, `SequenceMatcher`).
- **`name_price_f1`** — jw., ale pozycja liczy się tylko gdy trafiona jest też cena.
- **`currency_acc`**, **`latency` p50/p95**, **`tokens/s`**, histogram błędów
  (`wrong_total`, `missing_products`, `extra_products`, `price_errors`,
  `invalid_json`, `schema_invalid`, `api_error`).

Ground truth pochodzi z pól `items[].total` (cena po rabacie, czyli faktycznie
naliczona) i `total` z generatora; kwoty porównywane są w groszach (`int`), więc
bez błędów zmiennoprzecinkowych.

## Struktura

```
receipt_bench/
  schema.py     modele Pydantic -> JSON Schema dla Ollamy + walidacja
  generate.py   reużycie generatora paragonów (podmiana fontów pod NixOS)
  dataset.py    wczytanie datasetu -> kanoniczny ground truth (grosze)
  ollama.py     klient /api/chat (obraz + format), timing + tokeny
  matching.py   rozmyte dopasowanie pozycji -> precision/recall/F1
  evaluate.py   ocena jednego paragonu + taksonomia błędów
  aggregate.py  agregacja per model + rozbicia + percentyle
  report.py     złożenie raportu (3 poziomy) + Markdown
  cli.py        orkiestracja
run.py          skrót: python run.py ...
config.example.toml
```
