"""Command-line entry point: generate (or load) receipts, run them through one
or more Ollama vision models, score every reply, and write a JSON + Markdown
report."""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime
from pathlib import Path

from . import aggregate, report
from .dataset import ReceiptCase, load_many, sample
from .evaluate import evaluate_case
from .generate import generate_fresh
from .ollama import OllamaClient
from .schema import ollama_format

# receipt-bench/ (the project root: parent of this package)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
# testing-vision-ais/ (holds the paragony_pl_czesc* generators)
WORKSPACE_ROOT = PROJECT_ROOT.parent

DEFAULTS = {
    "url": "http://localhost:11434",
    "models": ["gemma4:12b"],
    "report_level": "diagnostic",
    "name_threshold": 0.6,
    "seed": 42,
    "generate": 10,
    "timeout": 600.0,
    "generator_dir": str(WORKSPACE_ROOT / "paragony_pl_czesc1" / "generator"),
}


def load_config(explicit: str | None) -> dict:
    """Merge built-in defaults with an optional TOML config file."""
    cfg = dict(DEFAULTS)
    path = None
    if explicit:
        path = Path(explicit)
    elif (PROJECT_ROOT / "config.toml").exists():
        path = PROJECT_ROOT / "config.toml"
    if path:
        try:
            import tomllib
        except ModuleNotFoundError:  # pragma: no cover (py<3.11)
            print(f"warning: cannot read {path} (Python < 3.11 lacks tomllib)", file=sys.stderr)
            return cfg
        with open(path, "rb") as f:
            cfg.update(tomllib.load(f))
    return cfg


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="receipt-bench",
        description="Benchmark local Ollama vision models on synthetic PL receipts.",
    )
    p.add_argument("--config", help="TOML config file (default: ./config.toml if present)")
    p.add_argument("--models", help="comma-separated Ollama models (overrides config)")
    p.add_argument("--url", help="Ollama base URL")
    p.add_argument("--report-level", choices=report.LEVELS, help="JSON report detail")
    p.add_argument("--out", default=str(PROJECT_ROOT / "reports"), help="output directory")
    p.add_argument("--seed", type=int, help="RNG seed (generation + sampling)")
    p.add_argument("--name-threshold", type=float, help="fuzzy name-match threshold 0..1")
    p.add_argument("--timeout", type=float, help="per-request timeout, seconds")

    src = p.add_argument_group("receipt source")
    src.add_argument("--generate", type=int, metavar="N",
                     help="generate N fresh receipts with the bundled generator (default)")
    src.add_argument("--dataset", metavar="DIR[,DIR...]",
                     help="use existing dataset dir(s) instead of generating")
    src.add_argument("--sample", type=int, metavar="N",
                     help="with --dataset: randomly pick N receipts")
    src.add_argument("--generator-dir", help="path to a generator/ directory")
    src.add_argument("--limit", type=int, help="cap the number of receipts actually run")

    p.add_argument("--no-markdown", action="store_true", help="skip the Markdown report")
    p.add_argument("--print-schema", action="store_true",
                   help="print the Ollama `format` schema and exit")
    return p.parse_args(argv)


def resolve_cases(args, cfg) -> tuple[list[ReceiptCase], str]:
    """Return (cases, human-readable source description)."""
    seed = args.seed if args.seed is not None else cfg["seed"]
    if args.dataset:
        dirs = [d.strip() for d in args.dataset.split(",") if d.strip()]
        cases = load_many(dirs)
        source = f"existing: {', '.join(dirs)}"
        if args.sample:
            cases = sample(cases, args.sample, seed)
            source += f" (sampled {len(cases)})"
    else:
        n = args.generate if args.generate is not None else cfg["generate"]
        gen_dir = Path(args.generator_dir or cfg["generator_dir"])
        work = PROJECT_ROOT / "work" / f"dataset-seed{seed}-n{n}"
        print(f"Generating {n} fresh receipts (seed {seed}) via {gen_dir} ...", flush=True)
        generate_fresh(gen_dir, n, work, seed)
        from .dataset import load_dataset
        cases = load_dataset(work)
        source = f"generated: n={n} seed={seed}"

    if args.limit and args.limit < len(cases):
        cases = cases[: args.limit]
    return cases, source


def run(argv: list[str]) -> int:
    args = parse_args(argv)
    cfg = load_config(args.config)

    fmt = ollama_format()
    if args.print_schema:
        print(json.dumps(fmt, indent=2, ensure_ascii=False))
        return 0

    models = ([m.strip() for m in args.models.split(",") if m.strip()]
              if args.models else list(cfg["models"]))
    url = args.url or cfg["url"]
    level = args.report_level or cfg["report_level"]
    threshold = args.name_threshold if args.name_threshold is not None else cfg["name_threshold"]
    timeout = args.timeout if args.timeout is not None else cfg["timeout"]
    seed = args.seed if args.seed is not None else cfg["seed"]

    cases, source = resolve_cases(args, cfg)
    print(f"Loaded {len(cases)} receipts ({source}).")

    client = OllamaClient(url=url, timeout=timeout)
    available = set(client.available_models())
    if available:
        for m in models:
            if m not in available:
                print(f"  ! model '{m}' not pulled on {url} — will report as api_error",
                      file=sys.stderr)
    else:
        print(f"  ! could not query {url}/api/tags — is Ollama running?", file=sys.stderr)

    results: dict[str, list] = {}
    started = datetime.now()
    for mi, model in enumerate(models, 1):
        print(f"\n=== [{mi}/{len(models)}] {model} ===", flush=True)
        evals = []
        for ci, case in enumerate(cases, 1):
            infer = client.infer(model, case.image_path, fmt)
            ev = evaluate_case(case, infer, threshold)
            ev.model = model
            evals.append(ev)
            _print_progress(ci, len(cases), ev)
        results[model] = evals

    meta = {
        "timestamp": started.isoformat(timespec="seconds"),
        "models": models,
        "n": len(cases),
        "seed": seed,
        "dataset": source,
        "ollama_url": url,
        "report_level": level,
        "name_threshold": threshold,
    }

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    stamp = started.strftime("%Y%m%d-%H%M%S")
    json_path = out_dir / f"report-{stamp}.json"
    doc = report.build_report(level, meta, results)
    json_path.write_text(json.dumps(doc, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\nWrote {json_path}")

    if not args.no_markdown:
        md_path = out_dir / f"report-{stamp}.md"
        md_path.write_text(report.build_markdown(meta, results), encoding="utf-8")
        print(f"Wrote {md_path}")

    _print_scoreboard(results)
    return 0


def _print_progress(i: int, total: int, ev) -> None:
    head = f"  [{i}/{total}] {ev.id} ({ev.item_count} it, {ev.style})"
    if not ev.ok:
        print(f"{head} -> FAIL({ev.category})  {ev.latency_ms/1000:.1f}s", flush=True)
        return
    tot = "total OK" if ev.total_exact else f"total x ({ev.total_abs_err}gr)"
    f1 = ev.match.f1 if ev.match else 0.0
    print(f"{head} -> valid  {tot}  F1 {f1:.2f}  {ev.latency_ms/1000:.1f}s", flush=True)


def _print_scoreboard(results: dict) -> None:
    print("\n--- scoreboard ---")
    rows = []
    for model, evals in results.items():
        s = aggregate.summarize(evals)
        rows.append((s.get("name_price_f1") or 0, model, s))
    rows.sort(reverse=True, key=lambda t: t[0])
    for _, model, s in rows:
        print(f"  {model:<24} valid {_pct(s['schema_valid_rate'])}  "
              f"total_exact {_pct(s['total_exact_rate'])}  "
              f"prod_F1 {_pct(s['product_f1'])}  "
              f"name+price_F1 {_pct(s['name_price_f1'])}")


def _pct(x) -> str:
    return f"{x*100:5.1f}%" if isinstance(x, (int, float)) else "   -  "


def main() -> None:
    sys.exit(run(sys.argv[1:]))
