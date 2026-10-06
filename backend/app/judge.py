import json
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TIMEOUT_S = 5

SUPPORTED_LANGUAGES = {"python", "typescript"}

PYTHON_HARNESS = """

import json as __json, sys as __sys
with open(__sys.argv[1]) as __f:
    __args = __json.load(__f)
print(__json.dumps({entry_point}(*__args)))
"""

TS_HARNESS = """

import {{ readFileSync }} from "node:fs";
const __args = JSON.parse(readFileSync(process.argv[2], "utf-8"));
console.log(JSON.stringify({entry_point}(...__args)));
"""


class UnsupportedLanguageError(Exception):
    pass


def run_case(language: str, code: str, entry_point: str, args: list, expected) -> dict:
    """Runs one test case in a fresh subprocess.

    Returns {"actual": str, "passed": bool, "duration_ms": float}. Never
    raises for a failing/crashing/timing-out submission — only for a
    genuinely unsupported language, which the caller should turn into an
    HTTP 400 before any subprocess is spawned.
    """
    if language not in SUPPORTED_LANGUAGES:
        raise UnsupportedLanguageError(f"Language '{language}' is not supported by the judge.")

    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        args_path = tmp / "args.json"
        args_path.write_text(json.dumps(args))

        if language == "python":
            source_path = tmp / "solution.py"
            source_path.write_text(code + PYTHON_HARNESS.format(entry_point=entry_point))
            command = [sys.executable, str(source_path), str(args_path)]
        else:
            source_path = tmp / "solution.ts"
            source_path.write_text(code + TS_HARNESS.format(entry_point=entry_point))
            command = ["node", str(source_path), str(args_path)]

        start = time.monotonic()
        try:
            proc = subprocess.run(
                command, capture_output=True, text=True, timeout=TIMEOUT_S, cwd=tmpdir,
            )
        except subprocess.TimeoutExpired:
            duration_ms = (time.monotonic() - start) * 1000
            return {"actual": f"Timed out after {TIMEOUT_S}s", "passed": False, "duration_ms": duration_ms}
        duration_ms = (time.monotonic() - start) * 1000

        if proc.returncode != 0:
            error_line = next((l for l in reversed(proc.stderr.splitlines()) if l.strip()), "Unknown error")
            return {"actual": error_line[:300], "passed": False, "duration_ms": duration_ms}

        output_lines = [l for l in proc.stdout.splitlines() if l.strip()]
        if not output_lines:
            return {"actual": "(no output)", "passed": False, "duration_ms": duration_ms}

        raw = output_lines[-1]
        try:
            actual_value = json.loads(raw)
        except json.JSONDecodeError:
            return {"actual": raw[:300], "passed": False, "duration_ms": duration_ms}

        return {"actual": raw, "passed": actual_value == expected, "duration_ms": duration_ms}


def run_all_cases(language: str, code: str, entry_point: str, judge_cases: list[dict]) -> list[dict]:
    return [
        run_case(language, code, entry_point, case["args"], case["expected"])
        for case in judge_cases
    ]
