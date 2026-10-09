"""Runs player (and reference) code against test cases.

All cases of one submission run inside ONE interpreter process: starting a
process costs ~50-70 ms on Windows, far more than running a typical test, so
the old one-process-per-case design made a 6-case submission take ~0.4 s.
Each case still has its own 5 s limit and its own error; a case that hangs,
crashes the interpreter, or exits is reported alone and the remaining cases are
judged in a fresh process.
"""
import json
import os
import queue
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

TIMEOUT_S = 5  # per test case
STARTUP_SLACK_S = 3  # extra time for the very first case (interpreter start-up)

SUPPORTED_LANGUAGES = {"python", "typescript"}

# Marks result lines so anything the solution prints can never be mistaken for one.
RESULT_MARK = "\x1e"

PYTHON_HARNESS = """

import json as __json, sys as __sys, time as __time

with open(__sys.argv[1]) as __f:
    __cases = __json.load(__f)
for __i, __args in enumerate(__cases):
    __start = __time.perf_counter()
    try:
        __raw = __json.dumps({entry_point}(*__args))
        __res = {{"i": __i, "ok": True, "raw": __raw}}
    except BaseException as __e:
        __msg = str(__e).strip().splitlines()
        __res = {{"i": __i, "ok": False, "error": type(__e).__name__ + (": " + __msg[-1] if __msg else "")}}
    __res["ms"] = (__time.perf_counter() - __start) * 1000
    __sys.stdout.write("\\x1e" + __json.dumps(__res) + "\\n")
    __sys.stdout.flush()
"""

TS_HARNESS = """

import {{ readFileSync }} from "node:fs";
const __cases = JSON.parse(readFileSync(process.argv[2], "utf-8"));
for (let __i = 0; __i < __cases.length; __i++) {{
  const __start = performance.now();
  let __res: any;
  try {{
    const __raw = JSON.stringify({entry_point}(...__cases[__i]));
    __res = {{ i: __i, ok: true, raw: String(__raw) }};
  }} catch (__e: any) {{
    __res = {{ i: __i, ok: false, error: String(__e && __e.message !== undefined ? (__e.name || "Error") + ": " + __e.message : __e) }};
  }}
  __res.ms = performance.now() - __start;
  process.stdout.write("\\x1e" + JSON.stringify(__res) + "\\n");
}}
"""


def values_equal(actual, expected) -> bool:
    """Type-strict JSON equality: bool never equals a number; int/float compare by value."""
    if isinstance(actual, bool) or isinstance(expected, bool):
        return isinstance(actual, bool) and isinstance(expected, bool) and actual == expected
    if isinstance(actual, (int, float)) and isinstance(expected, (int, float)):
        return actual == expected
    if isinstance(actual, list) and isinstance(expected, list):
        return len(actual) == len(expected) and all(values_equal(a, e) for a, e in zip(actual, expected))
    if isinstance(actual, dict) and isinstance(expected, dict):
        return actual.keys() == expected.keys() and all(values_equal(actual[k], expected[k]) for k in actual)
    return type(actual) is type(expected) and actual == expected


class UnsupportedLanguageError(Exception):
    pass


def _fail(error: str, duration_ms: float = 0.0) -> dict:
    return {"ok": False, "value": None, "raw": "", "error": error, "duration_ms": duration_ms}


def _finish(res: dict) -> dict:
    """Turns one harness result line into the public result dict."""
    ms = float(res.get("ms", 0.0))
    if not res.get("ok"):
        return _fail(str(res.get("error") or "Unknown error")[:300], ms)
    raw = str(res.get("raw", ""))
    if not raw.strip():
        return _fail("(no output)", ms)
    try:
        value = json.loads(raw)
    except json.JSONDecodeError:
        return _fail(raw[:300], ms)
    return {"ok": True, "value": value, "raw": raw, "error": None, "duration_ms": ms}


def _drain(stream, sink: "queue.Queue[str | None]") -> None:
    try:
        for line in stream:
            sink.put(line)
    finally:
        sink.put(None)  # end of stream


def _tail(lines: list[str]) -> str:
    return next((l.strip() for l in reversed(lines) if l.strip()), "")


def _run_process(command: list[str], cwd: str, count: int, offset: int) -> tuple[list[dict], str, str | None]:
    """Runs one interpreter over cases [offset, offset+count).

    Returns (finished results in order, why it stopped, stderr tail) where
    `why` is "done", "timeout" (the next case hung and the process was killed)
    or "died" (the interpreter exited before finishing all cases)."""
    try:
        proc = subprocess.Popen(
            command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, cwd=cwd,
            # Fixed hash seed: set/dict iteration order is then the same on every run.
            env={**os.environ, "PYTHONHASHSEED": "0"},
        )
    except FileNotFoundError:
        raise
    out_q: "queue.Queue[str | None]" = queue.Queue()
    err_lines: list[str] = []
    threading.Thread(target=_drain, args=(proc.stdout, out_q), daemon=True).start()
    err_q: "queue.Queue[str | None]" = queue.Queue()
    threading.Thread(target=_drain, args=(proc.stderr, err_q), daemon=True).start()

    results: list[dict] = []
    why = "done"
    deadline = time.monotonic() + TIMEOUT_S + STARTUP_SLACK_S
    try:
        while len(results) < count:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                why = "timeout"
                break
            try:
                line = out_q.get(timeout=remaining)
            except queue.Empty:
                why = "timeout"
                break
            if line is None:
                why = "died"
                break
            if not line.startswith(RESULT_MARK):
                continue  # something the solution printed
            try:
                res = json.loads(line[len(RESULT_MARK):])
            except json.JSONDecodeError:
                continue
            results.append(_finish(res))
            deadline = time.monotonic() + TIMEOUT_S
    finally:
        if proc.poll() is None:
            proc.kill()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        while True:
            try:
                item = err_q.get(timeout=0.2)
            except queue.Empty:
                break
            if item is None:
                break
            err_lines.append(item)
    return results, why, _tail(err_lines) or None


def execute_many(language: str, code: str, entry_point: str, args_list: list[list]) -> list[dict]:
    """Runs `entry_point(*args)` for every args list, in order, sharing one process.

    Each result is {"ok": bool, "value": parsed JSON or None, "raw": str,
    "error": str | None, "duration_ms": float} (duration is the call itself,
    not interpreter start-up). Never raises for a crashing/hanging program,
    only for an unsupported language."""
    if language not in SUPPORTED_LANGUAGES:
        raise UnsupportedLanguageError(f"Language '{language}' is not supported by the judge.")
    total = len(args_list)
    if total == 0:
        return []

    results: list[dict] = []
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        source_path = tmp / ("solution.py" if language == "python" else "solution.ts")
        harness = PYTHON_HARNESS if language == "python" else TS_HARNESS
        source_path.write_text(code + harness.format(entry_point=entry_point))
        runtime = [sys.executable, "-S"] if language == "python" else ["node"]

        while len(results) < total:
            offset = len(results)
            cases_path = tmp / "cases.json"
            cases_path.write_text(json.dumps(args_list[offset:]))
            try:
                done, why, err = _run_process(
                    [*runtime, str(source_path), str(cases_path)], tmpdir, total - offset, offset,
                )
            except FileNotFoundError:
                results.extend(_fail(f"The {language} runtime is not available on the server.") for _ in range(total - offset))
                break
            results.extend(done)
            if len(results) >= total:
                break
            if why == "timeout":
                results.append(_fail(f"Timed out after {TIMEOUT_S}s", TIMEOUT_S * 1000.0))
            else:  # the interpreter went away before finishing
                reason = (err or "The program ended unexpectedly")[:300]
                if not done and offset == 0:
                    # Broken before running anything (syntax error, bad import...): every case fails the same way.
                    results.extend(_fail(reason) for _ in range(total - offset))
                    break
                results.append(_fail(reason))
    return results


def execute_case(language: str, code: str, entry_point: str, args: list) -> dict:
    """One call of `entry_point(*args)` (a batch of one)."""
    return execute_many(language, code, entry_point, [args])[0]


def run_case(language: str, code: str, entry_point: str, args: list, expected) -> dict:
    """Runs one test case and compares to `expected`.

    Returns {"actual": str, "passed": bool, "duration_ms": float}.
    """
    r = execute_case(language, code, entry_point, args)
    if not r["ok"]:
        return {"actual": r["error"], "passed": False, "duration_ms": r["duration_ms"]}
    return {"actual": r["raw"], "passed": values_equal(r["value"], expected), "duration_ms": r["duration_ms"]}


def run_all_cases(language: str, code: str, entry_point: str, judge_cases: list[dict]) -> list[dict]:
    """Judges every case in one process; same result shape as `run_case`."""
    runs = execute_many(language, code, entry_point, [case["args"] for case in judge_cases])
    out = []
    for case, r in zip(judge_cases, runs):
        if not r["ok"]:
            out.append({"actual": r["error"], "passed": False, "duration_ms": r["duration_ms"]})
        else:
            out.append({"actual": r["raw"], "passed": values_equal(r["value"], case["expected"]), "duration_ms": r["duration_ms"]})
    return out
