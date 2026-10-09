"""LLM-backed problem generation (optional; templates are the fallback).

The model proposes a problem and a Python reference solution plus test
inputs. It is never trusted for expected outputs: those are computed by the
judge from the reference solution (verify.py). Any failure returns None.
"""
import json
import os
import re
from typing import Callable

from app.qengine.templates import TOPIC_LABELS, TOPICS, _camel
from app.qengine.types import GeneratedQuestion

DEFAULT_MODEL = "claude-sonnet-5-5"
_IDENT = re.compile(r"^[a-z_][a-z0-9_]*$")
# The reference solution is executed on the server; refuse obviously unsafe code.
_BANNED = ("import os", "import sys", "import subprocess", "import socket", "import shutil",
           "__import__", "open(", "exec(", "eval(", "input(", "from os", "from sys", "from subprocess",
           "requests", "urllib", "pathlib")

PROMPT_TEMPLATE = """You write coding-interview style practice problems for a game.
Create ONE new {difficulty} problem on the topic "{topic_label}". Be creative: avoid the most famous textbook problem.

Rules:
- The problem is solved by a single pure function with simple JSON-serializable arguments (ints, strings, bools, lists, nested lists) and a JSON-serializable return value.
- The answer must be deterministic and unique for each input (no "any valid answer" problems).
- Provide a correct Python reference solution that only uses the standard library, no I/O, no imports of os/sys/subprocess.
- Provide 6 to 8 test inputs including edge cases. Each input is the list of positional arguments. The outputs must not all be equal.

Reply with ONLY a JSON object (no prose) with these keys:
"title" (short), "topic" ("{topic}"), "prompt" (clear statement mentioning argument names), "function_name" (snake_case), "params" (list of argument names), "reference_solution" (Python source defining function_name), "inputs" (list of argument lists).
"""


def _default_complete(prompt: str) -> str | None:
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        return None
    try:
        import anthropic
    except ImportError:
        return None
    client = anthropic.Anthropic(api_key=key, timeout=30.0)
    msg = client.messages.create(
        model=os.environ.get("CODEWAR_LLM_MODEL", DEFAULT_MODEL),
        max_tokens=2500,
        messages=[{"role": "user", "content": prompt}],
    )
    return "".join(block.text for block in msg.content if getattr(block, "type", "") == "text")


def _extract_json(raw: str) -> dict | None:
    raw = raw.strip()
    fence = re.search(r"```(?:json)?\s*(.*?)```", raw, re.DOTALL)
    if fence:
        raw = fence.group(1).strip()
    start, end = raw.find("{"), raw.rfind("}")
    if start == -1 or end <= start:
        return None
    try:
        data = json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def generate_with_llm(
    difficulty: str,
    topic: str | None,
    complete: Callable[[str], str | None] | None = None,
) -> GeneratedQuestion | None:
    """Returns an (unverified) GeneratedQuestion, or None on any problem."""
    complete = complete or _default_complete
    topic_id = topic if topic in TOPICS else "arrays"
    prompt = PROMPT_TEMPLATE.format(
        difficulty=difficulty, topic=topic_id, topic_label=TOPIC_LABELS[topic_id],
    )
    try:
        raw = complete(prompt)
    except Exception:
        return None
    if not raw:
        return None
    data = _extract_json(raw)
    if data is None:
        return None
    try:
        title, text = data["title"], data["prompt"]
        fn, params = data["function_name"], data["params"]
        ref, inputs = data["reference_solution"], data["inputs"]
    except KeyError:
        return None
    if not (isinstance(title, str) and isinstance(text, str) and isinstance(fn, str)
            and isinstance(ref, str) and isinstance(params, list) and isinstance(inputs, list)):
        return None
    if not _IDENT.match(fn) or not params or not all(isinstance(p, str) and _IDENT.match(p) for p in params):
        return None
    if not inputs or not all(isinstance(a, list) and len(a) == len(params) for a in inputs):
        return None
    if any(bad in ref for bad in _BANNED) or f"def {fn}(" not in ref:
        return None
    return GeneratedQuestion(
        title=title.strip()[:80], difficulty=difficulty, topic=topic_id, prompt=text.strip(),
        params=params, entry_python=fn, entry_ts=_camel(fn), reference_solution=ref, inputs=inputs[:10],
        source="llm", tags=[TOPIC_LABELS[topic_id]],
    )
