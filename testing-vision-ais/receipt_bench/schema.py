"""Canonical receipt schema — the single source of truth for this benchmark.

We define the shape once, with Pydantic (Python's answer to zod/yup: a schema you
declare in code that both *validates* data and *emits* a JSON Schema). From that
one definition we derive two things:

  * ``ollama_format()`` — the JSON Schema handed to Ollama's ``format`` parameter,
    which constrains the model's decoding so the reply is always shaped like a
    :class:`ReceiptPred`.
  * ``parse_prediction()`` — strict validation of whatever the model returns.

The shape matches ``../return-schema.json``: a flat product list plus a grand
total, with every amount as an integer in the currency's *minor* unit (grosze,
cents) so it stays exact.
"""

from __future__ import annotations

import json
from typing import Any

from pydantic import BaseModel, ConfigDict, Field, ValidationError

CURRENCY_PATTERN = r"^[A-Z]{3}$"


class Amount(BaseModel):
    """A monetary amount in minor units (12.34 PLN -> 1234)."""

    model_config = ConfigDict(extra="forbid")

    value: int = Field(ge=0, description="Amount in the currency's minor unit, e.g. 123.45 PLN = 12345")
    currency: str = Field(pattern=CURRENCY_PATTERN, description="ISO 4217 code, e.g. PLN, EUR, USD")


class ProductPred(BaseModel):
    """A single purchased line item as read from the receipt."""

    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, description="Product name exactly as printed")
    value: int = Field(ge=0, description="Line price in minor units, e.g. 5.00 PLN = 500")
    currency: str = Field(pattern=CURRENCY_PATTERN, description="ISO 4217 code")


class ReceiptPred(BaseModel):
    """The full structured result we ask a model to produce."""

    model_config = ConfigDict(extra="forbid")

    products: list[ProductPred] = Field(min_length=1, description="Line items in order of appearance")
    total: Amount = Field(description="Grand total as read from the receipt")


# --- JSON Schema for Ollama's `format` -------------------------------------

# Keywords we drop when building the schema for Ollama. The model's decoding is
# constrained by a grammar compiled from this schema; keeping it to plain
# types + required keys (as the Go prototype did) maximises compatibility across
# models and Ollama versions. The *full* constraints still apply later, in
# parse_prediction(), when we validate the actual reply.
_STRIP_KEYS = {
    "pattern", "minLength", "maxLength", "minItems", "maxItems",
    "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum",
    "additionalProperties", "title", "description", "default", "examples",
}


def _inline(node: Any, defs: dict[str, Any]) -> Any:
    """Resolve $ref/$defs and strip constraint keywords, returning a plain,
    self-contained schema dict."""
    if isinstance(node, dict):
        if "$ref" in node:
            name = node["$ref"].split("/")[-1]
            return _inline(defs[name], defs)
        out: dict[str, Any] = {}
        for key, val in node.items():
            if key == "$defs" or key in _STRIP_KEYS:
                continue
            out[key] = _inline(val, defs)
        return out
    if isinstance(node, list):
        return [_inline(x, defs) for x in node]
    return node


def ollama_format() -> dict[str, Any]:
    """The JSON Schema for Ollama's ``format`` parameter, derived from the
    Pydantic model above."""
    schema = ReceiptPred.model_json_schema()
    defs = schema.get("$defs", {})
    return _inline(schema, defs)


# --- Validation of a model reply -------------------------------------------

def extract_json_object(text: str) -> str:
    """Best-effort: pull the first balanced ``{...}`` object out of the reply,
    tolerating markdown fences or stray prose some models add despite the
    grammar. Returns the input trimmed if no object is found."""
    text = text.strip()
    if text.startswith("```"):
        # ```json\n...\n```
        text = text.strip("`")
        nl = text.find("\n")
        if nl != -1 and text[:nl].strip().lower() in ("json", ""):
            text = text[nl + 1 :]
        text = text.strip().rstrip("`").strip()
    start = text.find("{")
    if start == -1:
        return text
    depth = 0
    in_str = False
    esc = False
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
        elif c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
    return text[start:]


def parse_prediction(raw: str) -> tuple[ReceiptPred | None, str, str | None]:
    """Parse and validate a model reply.

    Returns ``(receipt, category, error)`` where category is one of
    ``"ok"``, ``"invalid_json"`` or ``"schema_invalid"``.
    """
    candidate = extract_json_object(raw)
    try:
        data = json.loads(candidate)
    except json.JSONDecodeError as exc:
        return None, "invalid_json", f"{exc}"
    try:
        return ReceiptPred.model_validate(data), "ok", None
    except ValidationError as exc:
        return None, "schema_invalid", exc.errors(include_url=False).__repr__()
