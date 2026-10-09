"""Turns a GeneratedQuestion into a judge-verified Question payload.

Expected outputs are computed by executing the reference solution through
the same judge that grades players; nothing an LLM claims about expected
values is trusted.
"""
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor

from app.judge import execute_case
from app.qengine.types import GeneratedQuestion

MIN_CASES = 3
MAX_WORKERS = 6


def build_judge_cases(entry_point: str, reference_solution: str, inputs: list[list]) -> list[dict] | None:
    """Returns [{"args": [...], "expected": value}] or None if the reference
    crashes/times out on any input, there are too few inputs, or every
    output is identical (which would make the problem trivially gameable)."""
    if len(inputs) < MIN_CASES:
        return None
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        results = list(pool.map(
            lambda args: execute_case("python", reference_solution, entry_point, args), inputs,
        ))
    if any(not r["ok"] for r in results):
        return None
    cases = [{"args": args, "expected": r["value"]} for args, r in zip(inputs, results)]
    distinct = {json.dumps(c["expected"], sort_keys=True) for c in cases}
    if len(distinct) < 2:
        return None
    return cases


def _display_input(params: list[str], args: list) -> str:
    return ", ".join(f"{name} = {json.dumps(arg)}" for name, arg in zip(params, args))


def _python_starter(gq: GeneratedQuestion) -> str:
    return (
        f"def {gq.entry_python}({', '.join(gq.params)}):\n"
        f"    # TODO: write your solution\n"
        f"    pass\n"
    )


def _ts_starter(gq: GeneratedQuestion) -> str:
    sig = ", ".join(f"{p}: any" for p in gq.params)
    return f"function {gq.entry_ts}({sig}): any {{\n  // TODO: write your solution\n}}\n"


def content_hash(gq: GeneratedQuestion) -> str:
    blob = json.dumps([gq.title, gq.prompt, gq.inputs], sort_keys=True)
    return hashlib.sha256(blob.encode()).hexdigest()


def finalize(gq: GeneratedQuestion) -> dict | None:
    """Verifies `gq` and returns Question column values (without id), or None."""
    cases = build_judge_cases(gq.entry_python, gq.reference_solution, gq.inputs)
    if cases is None:
        return None
    test_cases = [
        {"input": _display_input(gq.params, c["args"]), "expected_output": json.dumps(c["expected"])}
        for c in cases
    ]
    return {
        "title": gq.title,
        "difficulty": gq.difficulty.title(),
        "tags": gq.tags or [gq.topic.replace("-", " ").title()],
        "prompt": gq.prompt,
        "example_input": test_cases[0]["input"],
        "example_output": test_cases[0]["expected_output"],
        "starter_code": {"python": _python_starter(gq), "typescript": _ts_starter(gq)},
        "test_cases": test_cases,
        "entry_point": {"python": gq.entry_python, "typescript": gq.entry_ts},
        "judge_cases": cases,
        "source": gq.source,
        "topic": gq.topic,
        "content_hash": content_hash(gq),
        "reference_solution": gq.reference_solution,
    }
