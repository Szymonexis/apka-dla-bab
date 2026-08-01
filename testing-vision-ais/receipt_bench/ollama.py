"""Thin client for a local Ollama server: send one receipt image to a vision
model and get back structured JSON, with timing and token counts."""

from __future__ import annotations

import base64
import time
from dataclasses import dataclass
from pathlib import Path

import requests

SYSTEM_PROMPT = """You are a precise receipt data extraction system. You are given a photograph of a shopping receipt. Extract every purchased product and the final total.

Respond with a single JSON object of exactly this shape:
{
  "products": [ { "name": "<string>", "value": <int>, "currency": "<ISO 4217>" } ],
  "total": { "value": <int>, "currency": "<ISO 4217>" }
}

Rules:
- "value" is the amount in MINOR currency units (grosze, cents) as an integer. 12.34 PLN -> 1234, 5.00 EUR -> 500. Never write a decimal point.
- "currency" is the ISO 4217 three-letter code (PLN, EUR, USD, GBP, ...). Infer it from currency symbols, the language, or tax labels on the receipt.
- "products" has one entry per purchased line item, with the name exactly as printed and the price actually charged for that line (after any per-line discount).
- "total" is the final amount paid printed on the receipt.
- Do not include subtotals, tax lines, change, loyalty points, or the payment method as products.
- Output only the JSON object, with no markdown fences and no commentary."""

USER_PROMPT = "Extract the receipt data from this image."


@dataclass
class InferResult:
    ok: bool
    content: str            # raw model text (empty on transport error)
    latency_ms: float       # wall-clock round trip
    prompt_tokens: int | None = None
    eval_tokens: int | None = None
    tokens_per_sec: float | None = None
    error: str | None = None  # transport/HTTP error, if any


class OllamaClient:
    def __init__(self, url: str = "http://localhost:11434", timeout: float = 600.0):
        self.url = url.rstrip("/")
        self.timeout = timeout

    def infer(self, model: str, image_path: str | Path, fmt: dict) -> InferResult:
        image_b64 = base64.b64encode(Path(image_path).read_bytes()).decode("ascii")
        payload = {
            "model": model,
            "stream": False,
            "think": False,  # skip "thinking" for a clean, fast reply
            "format": fmt,
            "options": {"temperature": 0},
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": USER_PROMPT, "images": [image_b64]},
            ],
        }
        start = time.monotonic()
        try:
            resp = requests.post(
                f"{self.url}/api/chat", json=payload, timeout=self.timeout
            )
        except requests.RequestException as exc:
            return InferResult(False, "", (time.monotonic() - start) * 1000,
                               error=f"request failed: {exc}")
        latency_ms = (time.monotonic() - start) * 1000

        if resp.status_code != 200:
            return InferResult(False, "", latency_ms,
                               error=f"HTTP {resp.status_code}: {resp.text[:300]}")
        try:
            body = resp.json()
        except ValueError as exc:
            return InferResult(False, "", latency_ms,
                               error=f"non-JSON response: {exc}")

        content = (body.get("message") or {}).get("content", "")
        eval_count = body.get("eval_count")
        eval_dur = body.get("eval_duration")  # nanoseconds
        tps = None
        if eval_count and eval_dur:
            tps = eval_count / (eval_dur / 1e9)
        return InferResult(
            ok=True,
            content=content,
            latency_ms=latency_ms,
            prompt_tokens=body.get("prompt_eval_count"),
            eval_tokens=eval_count,
            tokens_per_sec=tps,
        )

    def available_models(self) -> list[str]:
        try:
            resp = requests.get(f"{self.url}/api/tags", timeout=10)
            resp.raise_for_status()
            return [m["name"] for m in resp.json().get("models", [])]
        except requests.RequestException:
            return []
