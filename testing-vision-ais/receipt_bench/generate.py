"""Generate a fresh batch of synthetic receipts by reusing the existing
generator in ``paragony_pl_czesc*/generator``.

That generator hard-codes Debian font paths (``/usr/share/fonts/...``) which do
not exist on NixOS. Rather than edit it, we resolve the DejaVu / Liberation Mono
fonts at runtime and monkey-patch ``render.FONTS`` before invoking the
generator's own ``main()``. This keeps the dataset byte-for-byte the product of
the upstream generator.
"""

from __future__ import annotations

import importlib
import os
import subprocess
import sys
from pathlib import Path

# Maps render.FONTS keys -> (env var, fontconfig query, original Debian path).
_FONT_SPECS = {
    "normal": ("RB_FONT_DEJAVU_MONO", "DejaVu Sans Mono",
               "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"),
    "bold": ("RB_FONT_DEJAVU_MONO_BOLD", "DejaVu Sans Mono:bold",
             "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"),
    "alt": ("RB_FONT_LIBERATION_MONO", "Liberation Mono",
            "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"),
    "alt_bold": ("RB_FONT_LIBERATION_MONO_BOLD", "Liberation Mono:bold",
                 "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf"),
}


def _fc_match(query: str) -> str | None:
    try:
        out = subprocess.run(
            ["fc-match", "-f", "%{file}", query],
            capture_output=True, text=True, timeout=10,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    path = out.stdout.strip()
    return path if path and os.path.exists(path) else None


def resolve_fonts() -> dict[str, str]:
    """Locate the four fonts the generator needs. Order: env var (set by
    shell.nix) -> fontconfig -> the original Debian path."""
    resolved: dict[str, str] = {}
    missing: list[str] = []
    for key, (env, query, debian) in _FONT_SPECS.items():
        path = os.environ.get(env)
        if not (path and os.path.exists(path)):
            path = _fc_match(query)
        if not (path and os.path.exists(path)):
            path = debian if os.path.exists(debian) else None
        if path:
            resolved[key] = path
        else:
            missing.append(f"{key} ({query})")
    if missing:
        raise RuntimeError(
            "Could not locate monospace fonts for the generator: "
            + ", ".join(missing)
            + ".\nEnter the dev shell (`nix-shell`) which provides DejaVu and "
            "Liberation Mono, or install fonts-dejavu-core / fonts-liberation."
        )
    return resolved


def generate_fresh(generator_dir: Path, n: int, out_dir: Path, seed: int) -> Path:
    """Produce ``n`` receipts into ``out_dir`` (images/, ground_truth/, text/,
    index.jsonl, index.csv) and return ``out_dir``."""
    generator_dir = Path(generator_dir).resolve()
    if not (generator_dir / "generate.py").exists():
        raise FileNotFoundError(f"no generate.py under {generator_dir}")

    out_dir = Path(out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    fonts = resolve_fonts()

    # Import the generator package and patch its font table before it renders.
    sys.path.insert(0, str(generator_dir))
    try:
        render = importlib.import_module("render")
        render.FONTS.update(fonts)
        gen = importlib.import_module("generate")

        argv_backup = sys.argv
        sys.argv = ["generate", "--n", str(n), "--out", str(out_dir), "--seed", str(seed)]
        try:
            gen.main()
        finally:
            sys.argv = argv_backup
    finally:
        # Leave sys.path / sys.modules tidy so repeat calls stay deterministic.
        if str(generator_dir) in sys.path:
            sys.path.remove(str(generator_dir))
        for mod in ("generate", "render", "receipt", "catalog"):
            sys.modules.pop(mod, None)

    return out_dir
